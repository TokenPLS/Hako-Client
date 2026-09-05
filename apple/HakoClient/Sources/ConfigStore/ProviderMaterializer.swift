import Foundation
import Hako

enum MaterializeError: Error, Equatable {
    case badURL(provider: String)
    case ageKeyMissing(provider: String)
    case ageDecryptFailed(provider: String)
    case unsafePath(provider: String)
    case unsafeHeader(provider: String)
}

 
 
 
 
 
 
 
 
struct ProviderDownloadFailure: Error {
    let provider: String
    let url: String?
    let underlying: Error
}

 
 
 
 
struct ProviderValidationFailure: Error {
    let provider: String
    let underlying: Error
}

 
 
 
 
struct ProviderDownloadFailuresError: Error {
    let failures: [ProviderDownloadFailure]
}

 
 
 
 
 
 
 
struct ProviderValidationWarning: Equatable {
     
     
     
     
    static let clientAuthoredReason = "the core could not read this rule set"

    let provider: String
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    let reason: String
}

 
enum ProviderFetchBudget: Equatable {
     
     
    case patient
     
    case quick
     
     
     
     
     
     
     
     
    case activation
}

 
 
 
struct ProviderFetchDeferred: LocalizedError, Equatable {
    let provider: String
    var errorDescription: String? {
        "Not downloaded yet; Clash fetches it in the background after the switch."
    }
}

struct ProviderMaterializationResult: Equatable {
    let paths: [String: String]
    let entryCounts: [String: Int]
    let subscriptionUserInfo: [String: String]
    let refreshedNames: Set<String>
     
     
     
     
    let refreshedPayloads: [String: Data]
     
    var validationWarnings: [ProviderValidationWarning] = []
     
     
     
    var reusedCount: Int = 0
    var fetchedCount: Int = 0
     
     
     
    var firstLoadPending: [String] = []
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    var payloadSourceURLs: [String: String] = [:]
     
     
     
     
     
     
     
    var staleFallbacks: [String] = []
}

 
 
 
 
 
 
 
 
final class ProviderMaterializer {
    static let ageArmorPrefix = "-----BEGIN AGE ENCRYPTED FILE-----"

    typealias AgeDecryptor = (_ payload: Data, _ key: String, _ provider: String) throws -> Data

    private static let writeOptions: Data.WritingOptions =
        [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    private let downloader: HTTPFetching
     
     
     
    private let quickDownloader: HTTPFetching
    private let credentials: CredentialStore
    private let decryptor: AgeDecryptor

    init(downloader: HTTPFetching, credentials: CredentialStore,
         quickDownloader: HTTPFetching? = nil,
         decryptor: @escaping AgeDecryptor = { payload, key, provider in
              
              
             var error: NSError?
             guard let decrypted = HakoDecryptAgeForIOS(payload, key, &error) else {
                 throw error ?? MaterializeError.ageDecryptFailed(provider: provider)
             }
             return decrypted
         }) {
        self.downloader = downloader
        self.quickDownloader = quickDownloader
            ?? (downloader is ResourceDownloader ? ResourceDownloader.quick() : downloader)
        self.credentials = credentials
        self.decryptor = decryptor
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func slimmedForRuntime(kind: String, payload: Data) -> Data {
        guard kind == "proxy" else { return payload }
         
         
         
         
         
         
         
         
        if payload.starts(with: Data(#"{"proxies":"#.utf8)) {
            guard let object = try? JSONSerialization.jsonObject(
                      with: payload
                  ) as? [String: Any],
                  let proxies = object["proxies"] as? [Any], !proxies.isEmpty,
                  let slim = try? JSONSerialization.data(
                      withJSONObject: ["proxies": proxies],
                      options: [.withoutEscapingSlashes, .sortedKeys]
                  )
            else { return payload }
            return slim
        }
        guard let text = String(data: payload, encoding: .utf8),
              let json = try? ConfigTransforms.yamlToJSON(text),
              let object = try? JSONSerialization.jsonObject(
                  with: Data(json.utf8)
              ) as? [String: Any],
              let proxies = object["proxies"] as? [Any],
              !proxies.isEmpty,
               
               
               
               
               
               
               
               
              let slim = try? JSONSerialization.data(
                  withJSONObject: ["proxies": proxies],
                  options: [.withoutEscapingSlashes, .sortedKeys]
              )
        else { return payload }
        return slim
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private static func bytesOnDiskStillAnswerFor(
        _ provider: RemoteResourcePlan.Provider,
        record: ProviderCatalog.Entry?
    ) -> Bool {
        guard let record else { return true }
         
         
         
         
         
         
        guard let recorded = record.payloadURL else { return false }
         
         
         
         
         
         
         
         
         
         
         
         
         
        return recorded == provider.url
    }

     
     
     
     
    func materialize(plan: RemoteResourcePlan, into providersDir: URL,
                     publishedProvidersDir: URL,
                     maxBytesEach: Int,
                     reuseDir: URL? = nil,
                     reuseDirIsOwnRevision: Bool = true,
                     forceRefresh: Set<String> = [],
                     ageSecretKeys: [String: String] = [:],
                     userAgent: String? = nil) async throws -> [String: String] {
        try await materializeDetailed(
            plan: plan,
            into: providersDir,
            publishedProvidersDir: publishedProvidersDir,
            maxBytesEach: maxBytesEach,
            reuseDir: reuseDir,
            reuseDirIsOwnRevision: reuseDirIsOwnRevision,
            forceRefresh: forceRefresh,
            ageSecretKeys: ageSecretKeys,
            userAgent: userAgent
        ).paths
    }

     
     
     
    func materializeDetailed(
        plan: RemoteResourcePlan,
        into providersDir: URL,
        publishedProvidersDir: URL,
        maxBytesEach: Int,
        reuseDir: URL? = nil,
         
         
         
         
         
         
         
         
         
         
        reuseDirIsOwnRevision: Bool = true,
        forceRefresh: Set<String> = [],
         
         
         
         
         
         
        ageSecretKeys: [String: String] = [:],
        localOverrides: [String: Data] = [:],
        captureRefreshedPayloads: Set<String> = [],
        userAgent: String? = nil,
        fetchBudget: ProviderFetchBudget = .patient
    ) async throws -> ProviderMaterializationResult {
        var mapping: [String: String] = [:]
        var entryCounts: [String: Int] = [:]
        var subscriptionUserInfo: [String: String] = [:]
        var refreshedNames: Set<String> = []
        var refreshedPayloads: [String: Data] = [:]
        var validationWarnings: [ProviderValidationWarning] = []
        var reusedCount = 0
        var fetchedCount = 0
        var payloadSourceURLs: [String: String] = [:]
        var staleFallbackNames: [String] = []
        guard !plan.providers.isEmpty else {
            return ProviderMaterializationResult(
                paths: mapping,
                entryCounts: entryCounts,
                subscriptionUserInfo: subscriptionUserInfo,
                refreshedNames: refreshedNames,
                refreshedPayloads: refreshedPayloads
            )
        }
        try FileManager.default.createDirectory(at: providersDir, withIntermediateDirectories: true)
        var downloadFailures: [ProviderDownloadFailure] = []

         
        let reusableCatalog = reuseDir
            .flatMap { ProviderCatalog.load(providersDir: $0) }
        let knownVerdicts: [String: ProviderCatalog.Entry] = reusableCatalog
            .map { catalog in
                Dictionary(catalog.entries.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
            } ?? [:]
         
         
         
         
         
         
         
        let recordFor: [String: ProviderCatalog.Entry] = reusableCatalog
            .map { catalog in
                Dictionary(catalog.entries.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
            } ?? [:]

         
         
         
        var requests: [Int: URLRequest] = [:]
        var onHand: [Int: AcquiredPayload] = [:]
         
         
        var keptBytes: [Int: AcquiredPayload] = [:]
        for (index, provider) in plan.providers.enumerated() {
            guard !provider.path.isEmpty,
                  provider.path != ".",
                  provider.path != "..",
                  URL(fileURLWithPath: provider.path).lastPathComponent == provider.path,
                  !provider.path.contains("/") && !provider.path.contains("\\") else {
                throw MaterializeError.unsafePath(provider: provider.name)
            }
            guard let url = URL(string: provider.url) else {
                throw MaterializeError.badURL(provider: provider.name)
            }
             
             
             
             
             
            if let local = localOverrides[provider.name] {
                guard local.count <= maxBytesEach else {
                    throw DownloadError.tooLarge(local.count)
                }
                onHand[index] = AcquiredPayload(
                    data: local, refreshed: true, subscriptionUserInfo: nil, failure: nil)
                continue
            }
            if let reuseDir, !forceRefresh.contains(provider.name) {
                let source = reuseDir.appendingPathComponent(provider.path)
                guard Self.bytesOnDiskStillAnswerFor(
                    provider, record: recordFor[provider.path]
                ) else {
                     
                     
                     
                     
                     
                     
                     
                     
                    if reuseDirIsOwnRevision,
                       let kept = try? Data(contentsOf: source),
                       kept.count <= maxBytesEach
                    {
                        keptBytes[index] = AcquiredPayload(
                            data: kept, reusedFrom: source, refreshed: false,
                            subscriptionUserInfo: nil, failure: nil)
                    }
                    var request = URLRequest(url: Self.stripUserinfo(from: url))
                    if let authorization = Self.basicAuthorization(from: url) {
                        request.setValue(authorization, forHTTPHeaderField: "Authorization")
                    }
                    try applyHeaders(provider.headers, to: &request, provider: provider.name)
                    if request.value(forHTTPHeaderField: "User-Agent") == nil {
                        request.setValue(
                            userAgent ?? ClientUserAgent.resolved(),
                            forHTTPHeaderField: "User-Agent"
                        )
                    }
                    if let auth = credentials.get("provider.auth.\(provider.name)"),
                       let authString = String(data: auth, encoding: .utf8) {
                        request.setValue(authString, forHTTPHeaderField: "Authorization")
                    }
                    requests[index] = request
                    continue
                }
                if let reused = try? Data(contentsOf: source), reused.count <= maxBytesEach {
                     
                    onHand[index] = AcquiredPayload(
                        data: reused, reusedFrom: source, refreshed: false,
                        subscriptionUserInfo: nil, failure: nil)
                    continue
                }
            }
             
             
             
             
             
            var request = URLRequest(url: Self.stripUserinfo(from: url))
            if let authorization = Self.basicAuthorization(from: url) {
                request.setValue(authorization, forHTTPHeaderField: "Authorization")
            }
            try applyHeaders(provider.headers, to: &request, provider: provider.name)
            if request.value(forHTTPHeaderField: "User-Agent") == nil {
                request.setValue(
                    userAgent ?? ClientUserAgent.resolved(),
                    forHTTPHeaderField: "User-Agent"
                )
            }
            if let auth = credentials.get("provider.auth.\(provider.name)"),
               let authString = String(data: auth, encoding: .utf8) {
                request.setValue(authString, forHTTPHeaderField: "Authorization")
            }
            requests[index] = request
        }

         
         
         
         
         
        let payloads = try await acquirePayloads(
            plan: plan,
            requests: requests,
            onHand: onHand,
            maxBytesEach: maxBytesEach,
            budget: fetchBudget
        )
        var firstLoadPendingNames: [String] = []

         
         
         
        for (index, provider) in plan.providers.enumerated() {
            guard var acquired = payloads[index] else { continue }
            var fellBack = false
            if acquired.failure != nil, let kept = keptBytes[index] {
                fellBack = true
                 
                 
                 
                 
                acquired = kept
            }
            if let failure = acquired.failure, failure.underlying is ProviderFetchDeferred {
                 
                 
                 
                 
                 
                validationWarnings.append(ProviderValidationWarning(
                    provider: provider.name,
                    reason: failure.underlying.localizedDescription
                ))
                firstLoadPendingNames.append(provider.name)
                continue
            }
            if let failure = acquired.failure {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                guard provider.kind == "rule",
                      !forceRefresh.contains(provider.name)
                else {
                    downloadFailures.append(failure)
                    continue
                }
                validationWarnings.append(ProviderValidationWarning(
                    provider: provider.name,
                    reason: failure.underlying is ProviderFetchDeferred
                        ? failure.underlying.localizedDescription
                        : failure.url.map {
                            "download failed (\($0)): \(failure.underlying.localizedDescription)"
                        } ?? "download failed: \(failure.underlying.localizedDescription)"
                ))
                let target = providersDir.appendingPathComponent(provider.path)
                try Data().write(to: target, options: Self.writeOptions)
                mapping[provider.name] = publishedProvidersDir
                    .appendingPathComponent(provider.path).path
                firstLoadPendingNames.append(provider.name)
                continue
            }
            guard let payload = acquired.data else { continue }
            if acquired.reusedFrom != nil {
                reusedCount += 1
                 
                 
                 
                 
                 
                if let known = recordFor[provider.path]?.payloadURL {
                    payloadSourceURLs[provider.path] = known
                }
                if fellBack { staleFallbackNames.append(provider.name) }
            } else {
                fetchedCount += 1
                payloadSourceURLs[provider.path] = provider.url
            }
            if acquired.refreshed {
                refreshedNames.insert(provider.name)
            }
            if let header = acquired.subscriptionUserInfo {
                subscriptionUserInfo[provider.name] = header
            }
            let data = Self.slimmedForRuntime(
                kind: provider.kind,
                payload: try decryptIfArmored(payload, provider: provider, ageSecretKeys: ageSecretKeys)
            )
             
             
             
             
             
             
             
             
             
            var validationError: NSError?
            var counted = 0
            var readable: Bool
            if acquired.reusedFrom != nil,
               data == acquired.data,
               let known = knownVerdicts[provider.name],
               known.url == provider.url {
                readable = known.loadFailure == nil
                counted = known.count ?? 0
                if let failure = known.loadFailure {
                    validationError = NSError(
                        domain: "HakoClient.Provider", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: failure])
                }
            } else {
                readable = HakoInspectProviderForIOS(
                    provider.kind,
                    provider.behavior,
                    provider.format,
                    data,
                    &counted,
                    &validationError
                )
            }
            if !readable {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                validationWarnings.append(ProviderValidationWarning(
                    provider: provider.name,
                    reason: (validationError as Error?)?.localizedDescription
                        ?? ProviderValidationWarning.clientAuthoredReason
                ))
            }
            let count: Int? = readable ? counted : nil
            let target = providersDir.appendingPathComponent(provider.path)
             
             
             
            if let source = acquired.reusedFrom, data == acquired.data,
               (try? FileManager.default.copyItem(at: source, to: target)) != nil {
                 
            } else {
                try data.write(to: target, options: Self.writeOptions)
            }
            mapping[provider.name] = publishedProvidersDir
                .appendingPathComponent(provider.path).path
            entryCounts[provider.name] = count
            if captureRefreshedPayloads.contains(provider.name),
               refreshedNames.contains(provider.name) {
                refreshedPayloads[provider.name] = data
            }
        }
        if !downloadFailures.isEmpty {
            throw ProviderDownloadFailuresError(failures: downloadFailures)
        }
        return ProviderMaterializationResult(
            paths: mapping,
            entryCounts: entryCounts,
            subscriptionUserInfo: subscriptionUserInfo,
            refreshedNames: refreshedNames,
            refreshedPayloads: refreshedPayloads,
            validationWarnings: validationWarnings,
            reusedCount: reusedCount,
            fetchedCount: fetchedCount,
            firstLoadPending: firstLoadPendingNames,
            payloadSourceURLs: payloadSourceURLs,
            staleFallbacks: staleFallbackNames
        )
    }

     
     
    static func stripUserinfo(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user != nil || components.password != nil else {
            return url
        }
        components.user = nil
        components.password = nil
        return components.url ?? url
    }

     
    static func basicAuthorization(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let user = components.user else { return nil }
        let pair = "\(user):\(components.password ?? "")"
        guard let encoded = pair.data(using: .utf8)?.base64EncodedString() else { return nil }
        return "Basic \(encoded)"
    }

     
    private struct AcquiredPayload {
        let data: Data?
         
         
        var reusedFrom: URL? = nil
         
         
        let refreshed: Bool
        let subscriptionUserInfo: String?
        let failure: ProviderDownloadFailure?
    }

     
     
     
     
     
    private static let concurrentFetches = 6
     
     
     
    private static let quickConcurrentFetches = 12

    private func acquirePayloads(
        plan: RemoteResourcePlan,
        requests: [Int: URLRequest],
        onHand: [Int: AcquiredPayload],
        maxBytesEach: Int,
        budget: ProviderFetchBudget = .patient
    ) async throws -> [Int: AcquiredPayload] {
        let fetcher: HTTPFetching = budget == .patient ? downloader : quickDownloader
        var acquired = onHand
        var toFetch: [(index: Int, request: URLRequest, name: String, url: String?)] = []
        for (index, provider) in plan.providers.enumerated() {
            guard acquired[index] == nil, let request = requests[index] else { continue }
            if budget == .activation {
                 
                 
                 
                acquired[index] = AcquiredPayload(
                    data: nil, refreshed: false, subscriptionUserInfo: nil,
                    failure: ProviderDownloadFailure(
                        provider: provider.name, url: provider.url,
                        underlying: ProviderFetchDeferred(provider: provider.name)
                    )
                )
                continue
            }
            toFetch.append((index, request, provider.name, provider.url))
        }
        guard !toFetch.isEmpty else { return acquired }

        try await withThrowingTaskGroup(of: (Int, AcquiredPayload).self) { group in
            var next = 0
            let inFlight = min(budget == .patient ? Self.concurrentFetches : Self.quickConcurrentFetches, toFetch.count)
            func start(_ item: (index: Int, request: URLRequest, name: String, url: String?)) {
                group.addTask { [fetcher] in
                    let result: DownloadResult
                    do {
                         
                         
                         
                         
                         
                        result = try await fetcher.fetch(
                            item.request,
                            maxBytes: maxBytesEach,
                            redirectPolicy: .followAcrossOrigins(maxHops: 5)
                        )
                    } catch {
                         
                         
                         
                         
                         
                        return (item.index, AcquiredPayload(
                            data: nil, refreshed: false, subscriptionUserInfo: nil,
                            failure: ProviderDownloadFailure(
                                provider: item.name, url: item.url, underlying: error
                            )
                        ))
                    }
                     
                     
                     
                    guard result.data.count <= maxBytesEach else {
                        throw DownloadError.tooLarge(result.data.count)
                    }
                    return (item.index, AcquiredPayload(
                        data: result.data,
                        refreshed: true,
                        subscriptionUserInfo: result.subscriptionUserInfo,
                        failure: nil
                    ))
                }
            }
            while next < inFlight {
                start(toFetch[next])
                next += 1
            }
            for try await (index, payload) in group {
                acquired[index] = payload
                if next < toFetch.count {
                    start(toFetch[next])
                    next += 1
                }
            }
        }
        return acquired
    }

     
     
     
     
    private func decryptIfArmored(_ data: Data, provider: RemoteResourcePlan.Provider,
                                  ageSecretKeys: [String: String]) throws -> Data {
        guard data.starts(with: Data(Self.ageArmorPrefix.utf8)) else { return data }
        guard let resourceKey = provider.resourceKey,
              let key = ageSecretKeys[resourceKey], !key.isEmpty else {
            throw MaterializeError.ageKeyMissing(provider: provider.name)
        }
        return try decryptor(data, key, provider.name)
    }

    private func applyHeaders(
        _ headers: [String: [String]],
        to request: inout URLRequest,
        provider: String
    ) throws {
         
         
         
        let forbidden = Set([
            "host", "content-length", "transfer-encoding", "connection",
            "proxy-authorization", "proxy-connection", "upgrade",
        ])
        let allowedName = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        for (name, values) in headers {
            guard !name.isEmpty,
                  name.unicodeScalars.allSatisfy({ allowedName.contains($0) }),
                  !forbidden.contains(name.lowercased()),
                  !values.isEmpty,
                   
                   
                  values.allSatisfy({ !$0.unicodeScalars.contains(where: { $0 == "\r" || $0 == "\n" }) }) else {
                throw MaterializeError.unsafeHeader(provider: provider)
            }
            request.setValue(values.joined(separator: ", "), forHTTPHeaderField: name)
        }
    }
}
