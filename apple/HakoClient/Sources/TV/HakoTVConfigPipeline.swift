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

    init(
        container: URL,
        session: URLSession = HakoTVNetwork.session,
        defaults: UserDefaults = ClientUserAgent.appGroupDefaults
    ) {
        self.defaults = defaults
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

    func activate(
        subscription: HakoTVSubscription,
        progress: @escaping (Phase) -> Void
    ) async throws -> Activation {
        let working = container.appendingPathComponent("working", isDirectory: true)
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)
        try HakoTVCore.ensureSetup(container: container)
        try BundledGeodataProvisioner.seedAllMissing(into: working)

        progress(.downloading)
        let fetched = try await HakoTVSubscriptionFetcher.fetch(
            subscription.requestURL,
            session: session,
            userAgent: userAgent
        )
         
         
         
        try Task.checkCancellation()

        progress(.preparing)
        do {
            try ConfigTransforms.validateSource(fetched.yaml)
        } catch {
            throw PipelineError.invalidConfiguration(error.localizedDescription)
        }
        let plan: RemoteResourcePlan
        do {
            plan = try ConfigTransforms.planResources(mergedYAML: fetched.yaml)
        } catch {
            throw PipelineError.invalidConfiguration(error.localizedDescription)
        }
        guard plan.errors.isEmpty else {
            throw PipelineError.planRejected(plan.errors.map { "\($0.field): \($0.reason)" })
        }

        let store = try ConfigResourceStore(containerURL: container)
        let profileID = Self.profileID(for: subscription)
        let candidate = try store.beginCandidate(profileID: profileID)
        do {
            let materialized = try await HakoTVProviderMaterializer.materialize(
                plan: plan,
                candidate: candidate,
                session: session,
                userAgent: userAgent
            )
            try Task.checkCancellation()
            let finalYAML = try ConfigTransforms.finalize(
                mergedYAML: fetched.yaml,
                providerPaths: materialized.paths,
                providerReadPaths: materialized.readPaths
            )
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
                _ = try store.publishAndActivate(candidate, finalData: Data(finalYAML.utf8))
            } catch {
                throw PipelineError.publishFailed(error.localizedDescription)
            }
             
             
            ProviderStagingPublisher.publish(
                finalYAML: finalYAML,
                providerCount: plan.providers.count,
                compileRuleSets: false
            )
            return Activation(
                profileID: profileID,
                revision: candidate.revision,
                finalYAML: finalYAML,
                providerCount: plan.providers.count,
                warnings: materialized.warnings,
                userInfo: fetched.userInfo,
                catalog: materialized.catalog
            )
        } catch {
            try? store.discard(candidate)
            throw error
        }
    }
}
