import CryptoKit
import Foundation
import Hako

 
 
 
 
 
 
 
enum HakoTVCore {
    private static var setupContainer: URL?

    static func ensureSetup(container: URL) throws {
        if setupContainer == container { return }
        let options = HakoSetupOptions()
        options.basePath = container.path
        options.workingPath = container.appendingPathComponent("working").path
        options.tempPath = container.appendingPathComponent("temp").path
        options.timeZone = TimeZone.current.identifier
        options.logMaxLines = 100
         
         
        options.disablePersistentCache = true
         
         
         
        options.systemDNSServerLines = HakoSystemResolverLines()
        var error: NSError?
        HakoSetup(options, &error)
        if let error { throw error }
        setupContainer = container
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
final class HakoTVConfigPipeline {
    enum Phase: Equatable {
        case downloading
        case preparing
        case publishing
    }

    struct Activation: Equatable {
        let profileID: String
        let revision: String
        let finalYAML: String
        let providerCount: Int
        let warnings: [String]
        let userInfo: String?
         
         
        let panelName: String?
         
        let catalog: HakoTVProviderCatalog
    }

    enum PipelineError: LocalizedError {
        case invalidConfiguration(String)
        case planRejected([String])
        case preflightFailed(String)
        case publishFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration(let reason):
                return String(localized: "The profile is not something the tunnel can read: \(reason)")
            case .planRejected(let reasons):
                let joined = reasons.joined(separator: "; ")
                return String(localized: "The configuration was refused: \(joined)")
            case .preflightFailed(let reason):
                return String(localized: "The configuration failed the tunnel's check: \(reason)")
            case .publishFailed(let reason):
                return String(localized: "The configuration could not be saved on this Apple TV: \(reason)")
            }
        }
    }

    let container: URL
    let session: URLSession

     
     
     
     
     
    let defaults: UserDefaults
    private let setupCore: (URL) throws -> Void

    init(
        container: URL,
        session: URLSession = HakoTVNetwork.session,
        defaults: UserDefaults = ClientUserAgent.appGroupDefaults,
        setupCore: @escaping (URL) throws -> Void = HakoTVCore.ensureSetup
    ) {
        self.defaults = defaults
        self.setupCore = setupCore
        self.container = container
        self.session = session
    }

     
     
    static func profileID(for subscription: HakoTVSubscription) -> String {
        let digest = SHA256.hash(data: Data(subscription.requestURL.absoluteString.utf8))
        let bytes = Array(digest.prefix(16))
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        return uuid.uuidString.lowercased()
    }

    var userAgent: String {
        HakoTVSubscriptionFetcher.userAgent(defaults: defaults)
    }

    private func prepareEnvironment() throws {
        let working = container.appendingPathComponent("working", isDirectory: true)
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
        try setupCore(container)
        try BundledGeodataProvisioner.seedAllMissing(into: working)
    }

    func activate(
        subscription: HakoTVSubscription,
        progress: @escaping (Phase) -> Void
    ) async throws -> Activation {
        try prepareEnvironment()

        let profileID = Self.profileID(for: subscription)
        let sourceYAML: String
        let userInfo: String?
        let panelName: String?
        if let restored = HakoTVRestoredDocuments.read(container: container, profileID: profileID) {
             
             
             
            sourceYAML = restored
            userInfo = nil
            panelName = nil
        } else {
            progress(.downloading)
            let fetched = try await HakoTVSubscriptionFetcher.fetch(
                subscription.requestURL,
                session: session,
                userAgent: userAgent
            )
            sourceYAML = fetched.yaml
            userInfo = fetched.userInfo
            panelName = fetched.panelName
        }
         
         
         
        try Task.checkCancellation()

        return try await prepare(sourceYAML: sourceYAML, profileID: profileID,
                                 userInfo: userInfo, panelName: panelName, progress: progress)
    }

     
     
    func recoverRules(expected: ActiveConfigurationPointer,
                      loadedHashes: [String: String]? = nil,
                      verify: (@MainActor ([String: String]) async throws -> Bool)? = nil) async throws -> Activation? {
        let store = try ConfigResourceStore(containerURL: container)
        guard try store.activeIdentity() == expected,
              let directory = store.providersDirectory(profileID: expected.profileID, revision: expected.revision),
              let record = HakoTVRuleRecovery.read(from: directory) else { return nil }
         
        try prepareEnvironment()
        let plan = try ConfigTransforms.planResources(mergedYAML: record.sourceYAML)
        var snapshots = try HakoTVRuleRecovery.snapshots(sourceYAML: record.sourceYAML, plan: plan,
                                                       container: container, profileID: expected.profileID,
                                                       loadedHashes: loadedHashes)
         
        for provider in plan.providers where provider.kind == "rule" {
            let key = HakoTVProviderMaterializer.resourceKey(for: provider)
            if snapshots[key] == nil, record.hashes[key] != nil,
               let data = try? Data(contentsOf: directory.appendingPathComponent(provider.path)) {
                snapshots[key] = data
            }
        }
        guard HakoTVRuleRecovery.hashes(snapshots) != record.hashes else { return nil }
        if let verify {
            let hashes = snapshots.mapValues { HakoTVRuleRecovery.md5($0) }
            guard try await verify(hashes) else { return nil }
        }
        return try await prepare(sourceYAML: record.sourceYAML, profileID: expected.profileID,
                                 userInfo: nil, panelName: nil, expected: expected,
                                 existingProxyDirectory: directory, snapshots: snapshots, progress: { _ in })
    }

    private func prepare(sourceYAML: String, profileID: String, userInfo: String?, panelName: String?,
                         expected: ActiveConfigurationPointer? = nil, existingProxyDirectory: URL? = nil,
                         snapshots suppliedSnapshots: [String: Data]? = nil,
                         progress: @escaping (Phase) -> Void) async throws -> Activation {
        progress(.preparing)
        do {
            try ConfigTransforms.validateSource(sourceYAML)
        } catch {
            throw PipelineError.invalidConfiguration(error.localizedDescription)
        }
        let plan: RemoteResourcePlan
        do {
            plan = try ConfigTransforms.planResources(mergedYAML: sourceYAML)
        } catch {
            throw PipelineError.invalidConfiguration(error.localizedDescription)
        }
        guard plan.errors.isEmpty else {
            throw PipelineError.planRejected(plan.errors.map { "\($0.field): \($0.reason)" })
        }
         
         
        let ageSecretKeys: [String: String]
        do {
            ageSecretKeys = try ConfigTransforms.providerAgeSecretKeys(mergedYAML: sourceYAML)
        } catch {
            throw PipelineError.invalidConfiguration(error.localizedDescription)
        }

        let snapshots = try suppliedSnapshots ?? HakoTVRuleRecovery.snapshots(
            sourceYAML: sourceYAML, plan: plan, container: container, profileID: profileID)
        let runtimeSource = try HakoTVRuleRecovery.confinedSource(
            sourceYAML, plan: plan, container: container, profileID: profileID)
        let store = try ConfigResourceStore(containerURL: container)
        let candidate = try store.beginCandidate(profileID: profileID)
        do {
            let materialized = try await HakoTVProviderMaterializer.materialize(
                plan: plan,
                candidate: candidate,
                session: session,
                userAgent: userAgent,
                ageSecretKeys: ageSecretKeys,
                ruleSnapshots: snapshots,
                existingProxyDirectory: existingProxyDirectory
            )
            try Task.checkCancellation()
            let finalYAML = try ConfigTransforms.finalize(
                mergedYAML: runtimeSource,
                providerPaths: materialized.paths,
                providerReadPaths: materialized.readPaths
            )
            if plan.providers.contains(where: { $0.kind == "rule" }) {
                try HakoTVRuleRecovery(sourceYAML: sourceYAML, hashes: HakoTVRuleRecovery.hashes(snapshots))
                    .write(to: candidate.stagingProvidersDirectory)
            }
            let outcome = PreflightService.check(finalYAML: finalYAML)
            guard outcome.ok else {
                throw PipelineError.preflightFailed(outcome.errorMessage ?? "preflight failed")
            }
            GeoSiteCompiler.prepare(finalYAML: finalYAML)
            GeoSiteCompiler.prepareRulePayloads(in: candidate.stagingProvidersDirectory, plan: plan)
            GeoIPCompiler.prepare(finalYAML: finalYAML)
            GeoIPCompiler.prepareRulePayloads(
                in: candidate.stagingProvidersDirectory,
                plan: plan,
                geodataMode: GeoIPCompiler.geodataModeEnabled(in: finalYAML)
            )

             
             
            try Task.checkCancellation()
            progress(.publishing)
            do {
                if let expected {
                    _ = try store.publishAndActivateIfCurrentMatches(candidate, finalData: Data(finalYAML.utf8), expectedActive: expected)
                } else {
                    _ = try store.publishAndActivate(candidate, finalData: Data(finalYAML.utf8))
                }
            } catch {
                throw PipelineError.publishFailed(error.localizedDescription)
            }
             
             
            if expected == nil {
                ProviderStagingPublisher.publish(
                    finalYAML: finalYAML,
                    providerCount: plan.providers.count,
                    compileRuleSets: false
                )
            }
             
             
            return Activation(
                profileID: profileID,
                revision: candidate.revision,
                finalYAML: finalYAML,
                providerCount: plan.providers.count,
                warnings: materialized.warnings,
                userInfo: userInfo,
                panelName: panelName,
                catalog: materialized.catalog
            )
        } catch {
            try? store.discard(candidate)
            throw error
        }
    }
}

 
 
struct HakoTVRuleRecovery: Codable {
    static let fileName = "tv-rule-source.json"
     
    static let maximumCacheBytes = 16 * 1024 * 1024
    let sourceYAML: String
    let hashes: [String: String]

    var hasUnexpandedRoutes: Bool {
        guard let json = try? ConfigTransforms.yamlToJSON(sourceYAML),
              let root = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let tun = root["tun"] as? [String: Any],
              let plan = try? ConfigTransforms.planResources(mergedYAML: sourceYAML) else { return false }
        let names = Set((tun["route-address-set"] as? [String] ?? []) + (tun["route-exclude-address-set"] as? [String] ?? []))
        return plan.providers.contains {
            $0.kind == "rule" && $0.behavior == "ipcidr" && names.contains($0.name)
                && hashes[HakoTVProviderMaterializer.resourceKey(for: $0)] == nil
        }
    }

    func write(to directory: URL) throws {
        try JSONEncoder().encode(self).write(to: directory.appendingPathComponent(Self.fileName), options: .atomic)
    }

    static func read(from directory: URL) -> Self? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(fileName)) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func hashes(_ snapshots: [String: Data]) -> [String: String] {
        snapshots.mapValues { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
    }

    static func cacheURL(for provider: RemoteResourcePlan.Provider, sourceYAML: String,
                         container: URL, profileID: String) throws -> URL {
        try cacheURLs(sourceYAML: sourceYAML, plan: .init(providers: [provider]),
                      container: container, profileID: profileID)[HakoTVProviderMaterializer.resourceKey(for: provider)]!
    }

    static func cacheURLs(sourceYAML: String, plan: RemoteResourcePlan,
                          container: URL, profileID: String) throws -> [String: URL] {
        let json = try ConfigTransforms.yamlToJSON(sourceYAML)
        let root = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] ?? [:]
        var urls: [String: URL] = [:]
        for provider in plan.providers where provider.kind == "rule" {
            let section = "rule-providers"
            var definition = (root[section] as? [String: [String: Any]])?[provider.name] ?? [:]
            definition.removeValue(forKey: "path")
             
             
            let identity: [String: Any] = ["profile": profileID, "kind": provider.kind,
                                         "name": provider.name, "definition": definition,
                                         "globalUA": root["global-ua"] ?? ""]
            let data = try JSONSerialization.data(withJSONObject: identity, options: [.sortedKeys])
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            urls[HakoTVProviderMaterializer.resourceKey(for: provider)] =
                container.appendingPathComponent("working/tv-rule-cache/\(hash)")
        }
        return urls
    }

    static func confinedSource(_ source: String, plan: RemoteResourcePlan,
                               container: URL, profileID: String) throws -> String {
        var sections: [String: [String: [String: String]]] = [:]
        let urls = try cacheURLs(sourceYAML: source, plan: plan, container: container, profileID: profileID)
        for provider in plan.providers where provider.kind == "rule" {
            let section = "rule-providers"
            guard let url = urls[HakoTVProviderMaterializer.resourceKey(for: provider)] else { continue }
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            sections[section, default: [:]][provider.name] = ["path": url.path]
        }
        guard !sections.isEmpty else { return source }
        let patch = try JSONSerialization.data(withJSONObject: ["patch": sections], options: [.sortedKeys])
        return try ConfigTransforms.mergeOverride(raw: source, overrideJSON: String(decoding: patch, as: UTF8.self))
    }

    static func snapshots(sourceYAML: String, plan: RemoteResourcePlan,
                          container: URL, profileID: String,
                          loadedHashes: [String: String]? = nil) throws -> [String: Data] {
        var snapshots: [String: Data] = [:]
        let urls = try cacheURLs(sourceYAML: sourceYAML, plan: plan, container: container, profileID: profileID)
        for provider in plan.providers where provider.kind == "rule" {
            guard let url = urls[HakoTVProviderMaterializer.resourceKey(for: provider)] else { continue }
            let limit = provider.maximumBytes > 0
                ? Int(min(Int64(maximumCacheBytes), provider.maximumBytes)) : maximumCacheBytes
            guard let data = stableBytes(at: url, maximumBytes: limit) else { continue }
            if let loadedHashes, loadedHashes[provider.name] != md5(data) { continue }
             
            guard (try? HakoTVProviderMaterializer.coreInspector(provider.kind, provider.behavior, provider.format, data)) != nil else { continue }
            snapshots[HakoTVProviderMaterializer.resourceKey(for: provider)] = data
        }
        return snapshots
    }

    static func md5(_ data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

     
     
    private static func stableBytes(at url: URL, maximumBytes: Int) -> Data? {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var before = stat()
        guard fstat(fd, &before) == 0, before.st_mode & S_IFMT == S_IFREG,
              before.st_size > 0, before.st_size <= maximumBytes else { return nil }
        guard let data = try? handle.read(upToCount: maximumBytes + 1),
              data.count == before.st_size else { return nil }
        var after = stat()
        guard fstat(fd, &after) == 0, before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec else { return nil }
        return data
    }
}
