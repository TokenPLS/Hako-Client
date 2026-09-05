import Foundation

struct FetchedConfig {
    let yaml: String
     
     
    let rawSource: Data
    let etag: String?
    let lastModified: String?
    let subscriptionInfo: SubscriptionInfo?
     
     
     
    var suggestedName: String? = nil

    init(
        yaml: String,
        rawSource: Data? = nil,
        etag: String?,
        lastModified: String?,
        subscriptionInfo: SubscriptionInfo?,
        suggestedName: String? = nil
    ) {
        self.yaml = yaml
        self.rawSource = rawSource ?? Data(yaml.utf8)
        self.etag = etag
        self.lastModified = lastModified
        self.subscriptionInfo = subscriptionInfo
        self.suggestedName = suggestedName
    }
}

enum SubscriptionError: Error, Equatable {
    case notARemoteSource
    case badURL
    case notUTF8
}

 
 
 
 
final class SubscriptionManager {
     
    static let maxConfigBytes = Int.max

    private let downloader: HTTPFetching
    private let credentials: CredentialStore
    private let userAgent: () -> String

    init(downloader: HTTPFetching, credentials: CredentialStore,
         userAgent: @escaping () -> String = { ClientUserAgent.resolved() }) {
        self.downloader = downloader
        self.credentials = credentials
        self.userAgent = userAgent
    }

    func fetch(
        profile: Profile,
        etag: String? = nil,
        lastModified: String? = nil,
        useConditionalValidators: Bool = true
    ) async throws -> FetchedConfig? {
        guard case .url(let urlString) = profile.source else {
            throw SubscriptionError.notARemoteSource
        }
        guard var components = URLComponents(string: urlString),
              components.scheme != nil,
              components.host != nil else {
            throw SubscriptionError.badURL
        }
         
         
        let basicUser = components.user
        let basicPassword = components.password ?? ""
        components.user = nil
        components.password = nil
        guard let url = components.url else { throw SubscriptionError.badURL }
        var request = URLRequest(url: url)
         
         
        request.setValue(
            ClientUserAgent.explicitValue(for: profile) ?? userAgent(),
            forHTTPHeaderField: "User-Agent"
        )
         
         
         
         
         
         
         
         
        let labelStillAuto = !ProfileLabelPolicy.isUserAssigned(profile)
         
         
         
         
         
         
        for (field, value) in Self.conditionalHeaders(
            profile: profile,
            etag: etag,
            lastModified: lastModified,
            useConditionalValidators: useConditionalValidators,
            labelStillAuto: labelStillAuto
        ) {
            request.setValue(value, forHTTPHeaderField: field)
        }
        if let token = credentials.get("sub.token.\(profile.id)"),
           let tokenString = String(data: token, encoding: .utf8) {
            request.setValue("Bearer \(tokenString)", forHTTPHeaderField: "Authorization")
        } else if let basicUser {
            let encoded = Data("\(basicUser):\(basicPassword)".utf8).base64EncodedString()
            request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }
        let result: DownloadResult
        do {
            result = try await fetch(request)
        } catch DownloadError.badStatus(let status)
            where (300...399).contains(status)
                && request.value(forHTTPHeaderField: "User-Agent")
                    != ClientUserAgent.Preset.flclash.value {
             
             
             
            var compatibilityRequest = request
            compatibilityRequest.setValue(
                ClientUserAgent.Preset.flclash.value,
                forHTTPHeaderField: "User-Agent"
            )
            result = try await fetch(compatibilityRequest)
        }
        if result.notModified { return nil }
        let yaml = try ProxyImportBridge.derivedSubscriptionYAML(from: result.data)
        return FetchedConfig(yaml: yaml, rawSource: result.data, etag: result.etag,
                             lastModified: result.lastModified,
                             subscriptionInfo: result.subscriptionUserInfo.flatMap(SubscriptionInfo.parse(header:)),
                             suggestedName: Self.suggestedName(
                                fromContentDisposition: result.contentDisposition
                             ))
    }

     
     
     
    static func suggestedName(fromContentDisposition header: String?) -> String? {
        guard let header else { return nil }
        var candidate: String?
        for part in header.split(separator: ";") {
            let piece = part.trimmingCharacters(in: .whitespaces)
            if piece.lowercased().hasPrefix("filename*=") {
                var value = String(piece.dropFirst("filename*=".count))
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                let parts = value.split(
                    separator: "'", maxSplits: 2, omittingEmptySubsequences: false
                )
                if parts.count == 3 {
                    value = String(parts[2])
                }
                candidate = value.removingPercentEncoding ?? value
                break
            }
            if candidate == nil, piece.lowercased().hasPrefix("filename=") {
                candidate = String(piece.dropFirst("filename=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        guard var name = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        for suffix in [".yaml", ".yml"] where name.lowercased().hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
        }
        return name.isEmpty ? nil : String(name.prefix(80))
    }

    private func fetch(_ request: URLRequest) async throws -> DownloadResult {
        try await downloader.fetch(
            request,
            maxBytes: Self.maxConfigBytes,
            redirectPolicy: .followAcrossOrigins(maxHops: 5)
        )
    }
}

enum SubscriptionSourceRefreshResult: Equatable {
    case updated
    case unchanged
}

 
 
 
 
enum SubscriptionSourceRefresher {
    static func refresh(
        profile: Profile,
        manager: SubscriptionManager,
        profileStore: ProfileStore,
        credentials: CredentialStore,
        workingDirectory: URL,
        now: Date = Date()
    ) async throws -> SubscriptionSourceRefreshResult {
        var updated = profile
         
         
         
         
         
         
         
         
        let sourceURL = workingDirectory
            .appendingPathComponent("store/\(profile.id)/source.yaml")
         
         
         
         
         
         
        let hasLocalSource = Self.hasUsableSource(at: sourceURL)
        guard let fetched = try await manager.fetch(
            profile: profile,
            useConditionalValidators: hasLocalSource
        ) else {
            updated.lastUpdatedAt = now
             
             
             
             
             
            updated.labelIsUserAssigned = ProfileLabelPolicy.isUserAssigned(profile)
            try profileStore.upsert(updated)
            return .unchanged
        }

        try Task.checkCancellation()
        try ConfigTransforms.validateSource(fetched.yaml)
         
         
         
         
        _ = try ProfileRuntimeConfigBuilder.runtimePreview(
            raw: fetched.yaml,
            profile: updated
        )
         
         
         
         
         
         
         
         
        let legacyCredentials = (profile.proxyCredentials ?? [])
            + (profile.sourceCredentials ?? [])
        updated.proxyCredentials = nil
        updated.sourceCredentials = nil
        updated.sourceCredentialsRedacted = false
        updated.usesLocalSourceOverride = false
        updated.subscriptionInfo = fetched.subscriptionInfo ?? profile.subscriptionInfo
         
         
         
         
         
        let nameIsUserAssigned = ProfileLabelPolicy.isUserAssigned(profile)
        if let suggested = fetched.suggestedName, !suggested.isEmpty,
           !nameIsUserAssigned {
            updated.label = ProfileLabelPolicy.deduplicate(
                suggested,
                existing: profileStore.load()
                    .filter { $0.id != profile.id }
                    .map(\.label)
            )
        }
         
         
         
         
        updated.labelIsUserAssigned = nameIsUserAssigned
        updated.subscriptionETag = fetched.etag ?? updated.subscriptionETag
        updated.subscriptionLastModified =
            fetched.lastModified ?? updated.subscriptionLastModified
        updated.lastUpdatedAt = now

         
         
         
         
         
        let sidecar = ProfileSourceStore.runnableURL(
            workingDirectory: workingDirectory, profileID: profile.id
        )
        let previousSource = try? String(contentsOf: sidecar, encoding: .utf8)
        let previousCapture = ProfileSourceStore.snapshot(
            workingDirectory: workingDirectory, profileID: profile.id
        )
        let heldBack = SubscriptionUpdateSuppression.suppressed(
            previousYAML: previousSource,
            newYAML: fetched.yaml,
            appPatchJSON: FlClashRuntimeConfig.load().patchJSON
        )
        updated.suppressedUpdates = heldBack.isEmpty ? nil : heldBack
        do {
             
             
            try profileStore.upsert(updated)
             
             
             
            try ProfileSourceStore.store(
                document: fetched.yaml,
                derivedFrom: fetched.rawSource,
                workingDirectory: workingDirectory,
                profileID: profile.id
            )
        } catch {
            try? profileStore.upsert(profile)
            ProfileSourceStore.restore(
                previousCapture,
                workingDirectory: workingDirectory,
                profileID: profile.id
            )
            throw error
        }

         
         
         
         
        try? ProxyCredentialVault.remove(legacyCredentials, store: credentials)
        return .updated
    }
}


extension SubscriptionManager {
     
     
     
     
     
     
     
     
    static func conditionalHeaders(
        profile: Profile,
        etag: String? = nil,
        lastModified: String? = nil,
        useConditionalValidators: Bool,
        labelStillAuto: Bool = false
    ) -> [String: String] {
        let showingLocalEdit = profile.usesLocalSourceOverride == true
        guard useConditionalValidators, !labelStillAuto, !showingLocalEdit else {
            return [:]
        }
        var headers: [String: String] = [:]
        if let etag = etag ?? profile.subscriptionETag {
            headers["If-None-Match"] = etag
        }
        if let lastModified = lastModified ?? profile.subscriptionLastModified {
            headers["If-Modified-Since"] = lastModified
        }
        return headers
    }
}


extension SubscriptionSourceRefresher {
     
    static func hasUsableSource(at url: URL) -> Bool {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
