import CryptoKit
import Foundation

struct ExternalResourceImportFile: Equatable {
    let fileName: String
    let data: Data
}

struct PreparedExternalResourceImport {
    let yaml: String
    let references: [ProfileExternalResourceReference]
    let publicResources: [String: Data]
}

enum ProfileExternalResourceError: LocalizedError, Equatable {
    case missingSelection(field: String)
    case ambiguousSelection(field: String)
    case emptyResource(field: String)
    case resourceTooLarge(field: String)
    case resourceIsNotText(field: String)
    case storedResourceMissing(field: String)
    case storedResourceChanged(field: String)
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .missingSelection(let field):
            return "Select the file referenced by \(field) together with the YAML configuration."
        case .ambiguousSelection(let field):
            return "More than one selected file could satisfy \(field). Keep only the intended file and try again."
        case .emptyResource(let field):
            return "The selected file for \(field) is empty."
        case .resourceTooLarge(let field):
            return "The selected file for \(field) exceeds Hako’s 16 MB safety limit."
        case .resourceIsNotText(let field):
            return "The selected file for \(field) is not UTF-8 text."
        case .storedResourceMissing(let field):
            return "The saved resource for \(field) is missing. Re-import the profile and its resource files."
        case .storedResourceChanged(let field):
            return "The saved resource reference for \(field) no longer matches this configuration. Re-import the intended file."
        case .invalidConfiguration:
            return "The configuration resource structure is invalid."
        }
    }
}

enum ProfileExternalResourceImporter {
     
    static let maximumResourceBytes = Int.max

    static func prepare(
        yaml: String,
        profileID: String,
        source: IOSExternalResourceSource,
        files: [ExternalResourceImportFile],
        existingReferences: [ProfileExternalResourceReference] = [],
        existingPublicResources: [String: Data] = [:]
    ) throws -> PreparedExternalResourceImport {
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard var root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw ProfileExternalResourceError.invalidConfiguration
        }
        let findings = IOSExternalResourceCatalog.inspect(root: root, source: source)
        if let blocked = findings.first(where: { finding in
            switch finding.resolution {
            case .localImportRequired, .managedRuntimeStateRequired:
                return false
            case .subscriptionCannotReadFile, .fileProviderUnavailable,
                 .bundleArchiveRequired:
                return true
            }
        }) {
            throw blocked
        }

        let requirements = IOSExternalResourceCatalog.requirements(root: root)
            .filter {
                $0.capability.disposition == .publicFileOrInline
                    || $0.capability.disposition == .secretFileOrInline
            }
        guard source == .localFile || requirements.isEmpty else {
            if let finding = findings.first { throw finding }
            throw ProfileExternalResourceError.invalidConfiguration
        }

        let filesByBasename = Dictionary(grouping: files) {
            basename($0.fileName).lowercased()
        }
        var references: [ProfileExternalResourceReference] = []
        var publicResources: [String: Data] = [:]
        var proxies = root["proxies"] as? [[String: Any]] ?? []
        var changedYAML = false

        for requirement in requirements {
            let field = requirement.capability.fieldPath.joined(separator: ".")
            let name = basename(requirement.rawValue).lowercased()
            let candidates = filesByBasename[name] ?? []
            guard candidates.count <= 1 else {
                throw ProfileExternalResourceError.ambiguousSelection(field: field)
            }
            let expectedReference = reference(
                profileID: profileID,
                requirement: requirement
            )
            let selected: ExternalResourceImportFile
            if let candidate = candidates.first {
                selected = candidate
            } else if requirement.capability.confidentiality == .publicData,
                      existingReferences.contains(expectedReference),
                      let data = existingPublicResources[expectedReference.storageKey] {
                selected = ExternalResourceImportFile(
                    fileName: name,
                    data: data
                )
            } else {
                throw ProfileExternalResourceError.missingSelection(field: field)
            }
            guard !selected.data.isEmpty else {
                throw ProfileExternalResourceError.emptyResource(field: field)
            }
            guard selected.data.count <= maximumResourceBytes else {
                throw ProfileExternalResourceError.resourceTooLarge(field: field)
            }
             
             
             
            let decodedText = String(data: selected.data, encoding: .utf8)
            if requirement.expectedFormat != "mrs", decodedText == nil {
                throw ProfileExternalResourceError.resourceIsNotText(field: field)
            }

            switch requirement.capability.confidentiality {
            case .publicData:
                let reference = expectedReference
                if let previous = publicResources[reference.storageKey],
                   previous != selected.data {
                    throw ProfileExternalResourceError.ambiguousSelection(field: field)
                }
                publicResources[reference.storageKey] = selected.data
                references.append(reference)
            case .secret:
                guard let text = decodedText else {
                    throw ProfileExternalResourceError.resourceIsNotText(field: field)
                }
                guard let index = proxies.firstIndex(where: {
                    ($0["name"] as? String) == requirement.proxyName
                }) else {
                    throw ProfileExternalResourceError.invalidConfiguration
                }
                var proxy: Any = proxies[index]
                guard IOSExternalResourceCatalog.set(
                    text,
                    at: requirement.capability.fieldPath,
                    in: &proxy
                ), let dictionary = proxy as? [String: Any] else {
                    throw ProfileExternalResourceError.invalidConfiguration
                }
                proxies[index] = dictionary
                changedYAML = true
            case .runtimeState:
                break
            }
        }

        let preparedYAML: String
        if changedYAML {
            root["proxies"] = proxies
            let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
            preparedYAML = try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
        } else {
            preparedYAML = yaml
        }
        return PreparedExternalResourceImport(
            yaml: preparedYAML,
            references: Array(Set(references)).sorted { $0.storageKey < $1.storageKey },
            publicResources: publicResources
        )
    }

    static func reference(
        profileID: String,
        requirement: IOSExternalResourceRequirement
    ) -> ProfileExternalResourceReference {
        let identity = ([
            profileID,
            requirement.capability.id,
            requirement.proxyName,
        ] + requirement.capability.fieldPath).joined(separator: "\u{0}")
        return ProfileExternalResourceReference(
            capabilityID: requirement.capability.id,
            proxy: requirement.proxyName,
            fieldPath: requirement.capability.fieldPath,
            sourceValueSHA256: sha256(Data(requirement.rawValue.utf8)),
            storageKey: "resource-\(sha256(Data(identity.utf8)).prefix(32))"
        )
    }

    private static func basename(_ value: String) -> String {
        let normalized = value.replacingOccurrences(of: "\\", with: "/")
        return normalized.split(separator: "/").last.map(String.init) ?? normalized
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum ProfileExternalResourceStore {
    static func replace(
        _ resources: [String: Data],
        profileID: String,
        coreHomeDir: URL,
        fileManager: FileManager = .default
    ) throws {
        let profileDirectory = coreHomeDir
            .appendingPathComponent("store/\(profileID)", isDirectory: true)
        try fileManager.createDirectory(
            at: profileDirectory,
            withIntermediateDirectories: true
        )
        let target = profileDirectory.appendingPathComponent("resources", isDirectory: true)
        let token = UUID().uuidString.lowercased()
        let staging = profileDirectory.appendingPathComponent(".resources-\(token)", isDirectory: true)
        let previous = profileDirectory.appendingPathComponent(".resources-old-\(token)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
        do {
            for key in resources.keys.sorted() {
                guard key.hasPrefix("resource-"),
                      !key.contains("/"),
                      let data = resources[key],
                      !data.isEmpty,
                      data.count <= ProfileExternalResourceImporter.maximumResourceBytes else {
                    throw ProfileExternalResourceError.invalidConfiguration
                }
                try data.write(
                    to: staging.appendingPathComponent(key),
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                )
            }
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var protectedStaging = staging
            try protectedStaging.setResourceValues(values)

            let hadTarget = fileManager.fileExists(atPath: target.path)
            if hadTarget { try fileManager.moveItem(at: target, to: previous) }
            do {
                try fileManager.moveItem(at: staging, to: target)
                if hadTarget { try? fileManager.removeItem(at: previous) }
            } catch {
                if hadTarget,
                   !fileManager.fileExists(atPath: target.path),
                   fileManager.fileExists(atPath: previous.path) {
                    try? fileManager.moveItem(at: previous, to: target)
                }
                throw error
            }
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }
}

enum ProfileExternalResourceMaterializer {
    static func materialize(
        yaml: String,
        profile: Profile,
        coreHomeDir: URL,
        candidate: ConfigurationCandidate,
        fileManager: FileManager = .default
    ) throws -> String {
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard var root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw ProfileExternalResourceError.invalidConfiguration
        }
        var proxies = root["proxies"] as? [[String: Any]] ?? []
        for index in proxies.indices
        where (proxies[index]["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "tailscale" {
            guard let proxyName = proxies[index]["name"] as? String,
                  !proxyName.isEmpty else {
                throw ProfileExternalResourceError.invalidConfiguration
            }
            let proxyDigest = ProfileExternalResourceImporter.sha256(
                Data(proxyName.utf8)
            ).prefix(24)
            let stateDirectory = coreHomeDir
                .appendingPathComponent("store/\(profile.id)/runtime/tailscale/\(proxyDigest)",
                                      isDirectory: true)
            try fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
            proxies[index]["state-dir"] = stateDirectory.path
        }
        root["proxies"] = proxies
        let references = profile.externalResources ?? []
        let requirements = IOSExternalResourceCatalog.requirements(root: root)
        let stagingResources = candidate.stagingDirectory
            .appendingPathComponent("resources", isDirectory: true)
        let publishedResources = candidate.publishedDirectory
            .appendingPathComponent("resources", isDirectory: true)
        var createdResourcesDirectory = false

         
         
         
         
         
         
         
        func materializedPublicPath(
            for requirement: IOSExternalResourceRequirement
        ) throws -> String? {
            let valueDigest = ProfileExternalResourceImporter.sha256(
                Data(requirement.rawValue.utf8)
            )
            guard let reference = references.first(where: {
                $0.capabilityID == requirement.capability.id
                    && $0.proxy == requirement.proxyName
                    && $0.fieldPath == requirement.capability.fieldPath
                    && $0.sourceValueSHA256 == valueDigest
            }) else {
                return nil
            }
            let source = coreHomeDir
                .appendingPathComponent("store/\(profile.id)/resources/\(reference.storageKey)")
            guard let data = try? Data(contentsOf: source, options: [.mappedIfSafe]),
                  !data.isEmpty,
                  data.count <= ProfileExternalResourceImporter.maximumResourceBytes else {
                return nil
            }
            if !createdResourcesDirectory {
                try fileManager.createDirectory(
                    at: stagingResources,
                    withIntermediateDirectories: true
                )
                createdResourcesDirectory = true
            }
            try data.write(
                to: stagingResources.appendingPathComponent(reference.storageKey),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            return publishedResources.appendingPathComponent(reference.storageKey).path
        }

        for requirement in requirements {
            let field = requirement.capability.fieldPath.joined(separator: ".")
            if requirement.capability.section != .proxy {
                guard requirement.capability.disposition == .publicFileOrInline else {
                    continue
                }
                let key = requirement.capability.section == .proxyProvider
                    ? "proxy-providers"
                    : "rule-providers"
                guard var providers = root[key] as? [String: Any],
                      var provider = providers[requirement.proxyName] as? [String: Any]
                else { throw ProfileExternalResourceError.invalidConfiguration }
                if let path = try materializedPublicPath(for: requirement) {
                    provider["path"] = path
                    providers[requirement.proxyName] = provider
                    root[key] = providers
                }
                continue
            }
            guard let index = proxies.firstIndex(where: {
                ($0["name"] as? String) == requirement.proxyName
            }) else { throw ProfileExternalResourceError.invalidConfiguration }
            var proxy: Any = proxies[index]

            switch requirement.capability.disposition {
            case .managedRuntimeState:
                let proxyDigest = ProfileExternalResourceImporter.sha256(
                    Data(requirement.proxyName.utf8)
                ).prefix(24)
                let stateDirectory = coreHomeDir
                    .appendingPathComponent("store/\(profile.id)/runtime/tailscale/\(proxyDigest)",
                                          isDirectory: true)
                try fileManager.createDirectory(
                    at: stateDirectory,
                    withIntermediateDirectories: true
                )
                guard IOSExternalResourceCatalog.set(
                    stateDirectory.path,
                    at: requirement.capability.fieldPath,
                    in: &proxy
                ) else { throw ProfileExternalResourceError.invalidConfiguration }
            case .publicFileOrInline:
                if let path = try materializedPublicPath(for: requirement) {
                    guard IOSExternalResourceCatalog.set(
                        path,
                        at: requirement.capability.fieldPath,
                        in: &proxy
                    ) else { throw ProfileExternalResourceError.invalidConfiguration }
                }
            case .secretFileOrInline, .secretInlineOnly, .fileProviderUnavailable, .bundleArchiveMember:
                 
                 
                break
            }
            guard let dictionary = proxy as? [String: Any] else {
                throw ProfileExternalResourceError.invalidConfiguration
            }
            proxies[index] = dictionary
        }

        root["proxies"] = proxies
        let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        return try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
    }

    private static func source(for source: Profile.Source) -> IOSExternalResourceSource {
        switch source {
        case .url: return .subscription
        case .file: return .localFile
        case .clipboard: return .clipboard
        }
    }
}
