import Foundation

enum PipelineError: LocalizedError {
    case planRejected([RemoteResourcePlan.Failure])
    case externalResources([IOSExternalResourceFinding])
    case sourceUnavailable(String)
    case notModifiedWithoutActive
    case preflightFailed(String)
    case providerNotFound(String)
     
     
     
     
     
     
    case activationReadback

    var errorDescription: String? {
        switch self {
        case .planRejected(let failures):
            return failures.map { "\($0.field): \($0.reason)" }.joined(separator: "; ")
        case .externalResources(let findings):
            return findings.compactMap(\.errorDescription).joined(separator: " ")
        case .sourceUnavailable(let reason):
            return reason
        case .notModifiedWithoutActive:
            return "The subscription was not modified, but this profile has no active revision."
        case .preflightFailed(let reason):
            return "Configuration validation failed: \(reason)"
        case .providerNotFound(let name):
            return "Provider '\(name)' is no longer present in this profile."
        case .activationReadback:
            return "The activated revision could not be read back after publication."
        }
    }
}

struct ProviderRuntimeUpdate: Equatable {
    let name: String
    let kind: String
    let payload: Data
}

struct ProviderRefreshResult: Equatable {
    let pointer: ActiveConfigurationPointer
     
     
    let runtimeUpdate: ProviderRuntimeUpdate?
}

private struct ProfilePublicationResult {
    let pointer: ActiveConfigurationPointer
    let runtimeUpdates: [String: ProviderRuntimeUpdate]
     
     
     
    var firstLoadPending: [String] = []
}

 
 
 
 
enum ProfileRuntimeConfigBuilder {
    static func buildProduction(
        raw: String,
        profile: Profile,
        runtimeOverride: OverrideSpec = FlClashRuntimeConfig.load(),
        applyProviderDefinitions: Bool = true,
        applyProxyChain: Bool = true,
        applyLegacyRelayMigration: Bool = true
    ) throws -> String {
        try buildProductionStages(
            raw: raw,
            profile: profile,
            runtimeOverride: runtimeOverride,
            applyProviderDefinitions: applyProviderDefinitions,
            applyProxyChain: applyProxyChain,
            applyLegacyRelayMigration: applyLegacyRelayMigration
        ).finished()
    }

     
     
     
     
     
     
     
     
    static func buildProductionStages(
        raw: String,
        profile: Profile,
        runtimeOverride: OverrideSpec = FlClashRuntimeConfig.load(),
        globalOverride: OverrideSpec = GlobalConfig.load(),
        applyProviderDefinitions: Bool = true,
        applyProxyChain: Bool = true,
        applyLegacyRelayMigration: Bool = true
    ) throws -> RuntimeBuildStages {
        try ProfilePostMergeScriptOwnershipPolicy.validate(
            postMergeScriptID: profile.postMergeScriptID,
            legacyGlobalScriptEnabled: ScriptSettings.enabled()
        )
        return try buildStages(
            raw: raw,
            profile: profile,
            globalOverride: globalOverride,
            runtimeOverride: runtimeOverride,
            profileScript: { try ScriptLibrary.apply(id: $0, to: $1, profileName: $2) },
            configScript: { try ScriptSettings.apply(toConfigYAML: $0, profileName: $1) },
            postMergeScript: { try ScriptLibrary.apply(id: $0, to: $1, profileName: $2) },
            applyProviderDefinitions: applyProviderDefinitions,
            applyProxyChain: applyProxyChain,
            applyLegacyRelayMigration: applyLegacyRelayMigration
        )
    }

     
     
     
     
     
    static func udpFallbackGuardInput(
        raw: String,
        profile: Profile,
        runtimeOverride: OverrideSpec = FlClashRuntimeConfig.load()
    ) throws -> ConfigTransforms.UDPFallbackGuardInput {
        try ConfigTransforms.udpFallbackGuardInput(
            buildProductionStages(
                raw: raw, profile: profile, runtimeOverride: runtimeOverride
            ).beforeClientRuntimePolicy
        )
    }

     
     
     
     
     
     
     
     
    struct RuntimeBuildStages {
         
         
        let afterClientTransforms: String
         
         
        let beforeClientRuntimePolicy: String
         
        let udpFallback: UDPFallbackPolicy

         
        func finished() throws -> String {
            try ConfigTransforms.applyClientRuntimePolicy(
                beforeClientRuntimePolicy,
                udpFallback: udpFallback
            )
        }
    }

    static func build(
        raw: String,
        profile: Profile,
        globalOverride: OverrideSpec,
        runtimeOverride: OverrideSpec = OverrideSpec(),
        profileScript: (String?, String, String) throws -> String,
        configScript: (String, String) throws -> String,
        postMergeScript: (String?, String, String) throws -> String = { _, yaml, _ in yaml },
        applyProviderDefinitions: Bool = true,
        applyProxyChain: Bool = true,
        applyLegacyRelayMigration: Bool = true
    ) throws -> String {
        try buildStages(
            raw: raw,
            profile: profile,
            globalOverride: globalOverride,
            runtimeOverride: runtimeOverride,
            profileScript: profileScript,
            configScript: configScript,
            postMergeScript: postMergeScript,
            applyProviderDefinitions: applyProviderDefinitions,
            applyProxyChain: applyProxyChain,
            applyLegacyRelayMigration: applyLegacyRelayMigration
        ).finished()
    }

    static func buildStages(
        raw: String,
        profile: Profile,
        globalOverride: OverrideSpec,
        runtimeOverride: OverrideSpec = OverrideSpec(),
         
         
         
         
        profileScript: (String?, String, String) throws -> String,
        configScript: (String, String) throws -> String,
        postMergeScript: (String?, String, String) throws -> String = { _, yaml, _ in yaml },
        applyProviderDefinitions: Bool = true,
        applyProxyChain: Bool = true,
        applyLegacyRelayMigration: Bool = true
    ) throws -> RuntimeBuildStages {
        let profileWorking: String
        switch profile.overwriteMode ?? .standard {
        case .standard:
            var spec = profile.override
             
             
             
            spec.patchJSON = OverridePatch(
                patchJSON: spec.patchJSON
            ).profileOwnedPatch.patchJSON
             
             
            let muted = Set(spec.disabledAppendRules ?? [])
            spec.appendRules.removeAll { muted.contains($0) }
            spec.appendRules = try resolvedFallbackTargets(
                spec.appendRules, mergedInto: raw
            )
            profileWorking = try ConfigTransforms.mergeOverride(
                raw: raw,
                overrideJSON: overrideJSON(from: spec)
            )
        case .script:
            profileWorking = try profileScript(profile.selectedScriptID, raw, profile.label)
        case .custom:
            profileWorking = try (profile.customOverwrite ?? CustomOverwriteSpec())
                .applyForFinalRuntimeMigration(to: raw)
        }

        var effectiveGlobal = profile.migratedGlobalOverride ?? globalOverride
         
         
         
         
         
         
         
         
        if (profile.overwriteMode ?? .standard) != .standard {
            effectiveGlobal.appendRules = []
        }
        let disabledRules = Set(profile.override.disabledGlobalRules ?? [])
        effectiveGlobal.appendRules.removeAll { disabledRules.contains($0) }
        effectiveGlobal.appendRules = try resolvedFallbackTargets(
            effectiveGlobal.appendRules, mergedInto: profileWorking
        )
        let merged = try ConfigTransforms.mergeOverride(
            raw: profileWorking,
            overrideJSON: overrideJSON(from: effectiveGlobal)
        )
        let profileScripted = try postMergeScript(
            profile.postMergeScriptID, merged, profile.label
        )
        let scripted = try configScript(profileScripted, profile.label)
        let trimmed = try applyClientTransforms(
            to: scripted,
            profile: profile,
            applyProviderDefinitions: applyProviderDefinitions,
            applyProxyChain: applyProxyChain,
            applyLegacyRelayMigration: applyLegacyRelayMigration
        )

        var effectiveRuntime = runtimeOverride
        var runtimePatch = OverridePatch(
            patchJSON: effectiveRuntime.patchJSON
        ).globalRuntimePatch
         
         
         
         
         
         
         
        if runtimeOverride.dnsOverridesProfiles != true,
           runtimePatch.hasDNSOverride,
           Self.hasEnabledOwnDNS(yaml: trimmed) {
            runtimePatch.clearDNS()
        }
         
         
        if runtimePatch.mode == nil, let legacyMode = profile.outboundMode {
            runtimePatch.mode = legacyMode.rawValue
        }
        effectiveRuntime.patchJSON = runtimePatch.patchJSON
        let disabledRuntimeRules = Set(
            profile.override.disabledGlobalRules ?? []
        )
        effectiveRuntime.appendRules.removeAll {
            disabledRuntimeRules.contains($0)
        }
        effectiveRuntime.appendRules = try resolvedFallbackTargets(
            effectiveRuntime.appendRules,
            mergedInto: trimmed
        )
        let runtimeApplied = try ConfigTransforms.mergeOverride(
            raw: trimmed,
            overrideJSON: overrideJSON(from: effectiveRuntime)
        )
        return RuntimeBuildStages(
            afterClientTransforms: trimmed,
            beforeClientRuntimePolicy: runtimeApplied,
            udpFallback: UDPFallbackSettings.resolved(
                profile: profile.udpFallbackPolicy,
                global: UDPFallbackSettings.policy()
            )
        )
    }

     
     
     
     
     
     
     
     
     
     
    static func applyClientTransforms(
        to scripted: String,
        profile: Profile,
        applyProviderDefinitions: Bool = true,
        applyProxyChain: Bool = true,
        applyLegacyRelayMigration: Bool = true
    ) throws -> String {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        var document = try ConfigTransforms.ParsedDocument(yaml: scripted)
        var touched = false
        if applyProviderDefinitions {
            let spec = profile.providerDefinitions ?? ProfileProviderDefinitionSpec()
            if !spec.isEmpty {
                try spec.apply(to: &document.root)
                touched = true
            }
        }
        let materialized = try CustomNodesGroupMaterializer.applyReportingChange(
            to: &document.root
        )
        touched = touched || materialized
        let overrides = profile.proxyNodeOverrides ?? ProxyNodeOverrideSpec()
        if !overrides.isEmpty {
            try overrides.apply(to: &document.root)
            touched = true
        }
        if applyProxyChain {
            let chain = profile.proxyChain ?? ProxyChainSpec()
            if !chain.assignments.isEmpty {
                try chain.apply(to: &document.root)
                touched = true
            }
        }
        if applyLegacyRelayMigration {
            touched = try LegacyRelayMigrationEngine.apply(
                profile.legacyRelayMigrations ?? [],
                to: &document.root
            ) || touched
        }
        touched = try (profile.memoryTrim ?? MemoryTrimSpec())
            .apply(to: &document.root) || touched
         
         
         
         
        var trimmed = touched ? try document.serialized() : scripted
        if profile.dnsBootstrapInsurance == true {
            trimmed = try ConfigTransforms.applyDNSBootstrapInsurance(trimmed)
        }
         
         
         
         
         
        return trimmed
    }

     
     
     
     
     
    static func runtimePreview(
        raw: String,
        profile: Profile,
        runtimeOverride: OverrideSpec = FlClashRuntimeConfig.load()
    ) throws -> String {
        try buildProduction(
            raw: raw,
            profile: profile,
            runtimeOverride: runtimeOverride
        )
    }

     
     
     
     
     
     
    static func resolvedFallbackTargets(
        _ rules: [String],
        mergedInto yaml: String
    ) throws -> [String] {
        let needsResolution = rules.contains {
            StructuredRule.parse($0)?.target == "MATCH"
        }
        guard needsResolution else { return rules }
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any],
              let sourceRules = root["rules"] as? [Any] else { return rules }
        let fallback = sourceRules.lazy
            .reversed()
            .compactMap { entry -> String? in
                guard let line = entry as? String,
                      let parsed = StructuredRule.parse(line),
                      parsed.action == .match, !parsed.target.isEmpty,
                      parsed.target != "MATCH" else { return nil }
                return parsed.target
            }
            .first
        guard let fallback else { return rules }
        return rules.map { rule in
            guard var parsed = StructuredRule.parse(rule),
                  parsed.target == "MATCH" else { return rule }
            parsed.target = fallback
            return parsed.rawValue
        }
    }

     
    static func hasEnabledOwnDNS(yaml: String) -> Bool {
        guard let json = try? ConfigTransforms.yamlToJSON(yaml),
              let value = try? JSONSerialization.jsonObject(
                with: Data(json.utf8)
              ),
              let root = value as? [String: Any],
              let dns = root["dns"] as? [String: Any] else {
            return false
        }
        return (dns["enable"] as? Bool) == true
    }

    private static func overrideJSON(from spec: OverrideSpec) throws -> String {
        if spec.patchJSON.isEmpty && spec.appendRules.isEmpty { return "" }
        var payload: [String: Any] = [:]
        if !spec.patchJSON.isEmpty {
            payload["patch"] = try JSONSerialization.jsonObject(
                with: Data(spec.patchJSON.utf8)
            )
        }
        if !spec.appendRules.isEmpty {
            payload["appendRules"] = spec.appendRules
            payload["prependRules"] = spec.prependRules
        }
        let data = try JSONSerialization.data(withJSONObject: payload)
        return String(data: data, encoding: .utf8) ?? ""
    }

}

 
 
 
 
 
final class ProfileActivationCoordinator {
     
     
     
     
    private(set) var firstLoadPendingOfLastPublication: [String] = []
     
     
     
     
     
    static let maxProviderBytes = Int.max
    static let maxGeodataBytes = Int.max

    private let store: ConfigResourceStore
    private let profileStore: ProfileStore
    private let credentials: CredentialStore
    private let coreHomeDir: URL
     
     
     
    private let compileRuleSets: Bool
     
     
    private let deferRuleSetCompilation: Bool
    private let stagingPublisher: (String, Int, Bool) -> Void
    private let scheduleDeferredCompilation: (@escaping () -> Void) -> Void

     
     
     
    static let deferredCompilationQueue = DispatchQueue(
        label: "network.hako.provider-staging.compile", qos: .utility
    )

     
     
     
     
     
     
     
    private func publishStaging(finalYAML: String, providerCount: Int) {
        guard compileRuleSets, deferRuleSetCompilation else {
            stagingPublisher(finalYAML, providerCount, compileRuleSets)
            return
        }
        stagingPublisher(finalYAML, providerCount, false)
        let staged = try? store.activeIdentity()
        let store = self.store
        let publish = self.stagingPublisher
        scheduleDeferredCompilation {
            guard (try? store.activeIdentity()) == staged else { return }
            publish(finalYAML, providerCount, true)
        }
    }
    private let activationFetchBudget: ProviderFetchBudget
     
     
     
    private var activationReuseSource = "unset"
    private let globalOverride: () -> OverrideSpec
    private let runtimeOverride: () -> OverrideSpec
    private let profileScript: (String?, String, String) throws -> String
    private let configScript: (String, String) throws -> String
    private let postMergeScript: (String?, String, String) throws -> String
    private let activator: (URL) throws -> Void
    private let subscriptions: SubscriptionManager
    private let materializer: ProviderMaterializer
    private let geodata: GeodataManager
    private let preflight: (String) -> PreflightOutcome
    private let now: () -> Date
     
     
     
     
    private let log: (String) -> Void

    init(store: ConfigResourceStore, profileStore: ProfileStore,
         credentials: CredentialStore, downloader: HTTPFetching,
         coreHomeDir: URL,
          
          
          
          
          
          
          
         compileRuleSets: Bool = false,
          
          
          
          
          
          
          
          
          
          
         deferRuleSetCompilation: Bool = false,
          
          
          
         activationFetchBudget: ProviderFetchBudget = .activation,
         globalOverride: @escaping () -> OverrideSpec = { GlobalConfig.load() },
         runtimeOverride: @escaping () -> OverrideSpec = {
             FlClashRuntimeConfig.load()
         },
         profileScript: @escaping (String?, String, String) throws -> String = {
             try ScriptLibrary.apply(id: $0, to: $1, profileName: $2)
         },
         configScript: @escaping (String, String) throws -> String = {
             try ScriptSettings.apply(toConfigYAML: $0, profileName: $1)
         },
         postMergeScript: @escaping (String?, String, String) throws -> String = {
             try ScriptLibrary.apply(id: $0, to: $1, profileName: $2)
         },
         activator: @escaping (URL) throws -> Void,
         preflight: @escaping (String) -> PreflightOutcome = {
             PreflightService.check(finalYAML: $0)
         },
          
         stagingPublisher: @escaping (String, Int, Bool) -> Void = {
             ProviderStagingPublisher.publish(
                 finalYAML: $0, providerCount: $1, compileRuleSets: $2
             )
         },
          
          
         scheduleDeferredCompilation: @escaping (@escaping () -> Void) -> Void = {
             ProfileActivationCoordinator.deferredCompilationQueue.async(execute: $0)
         },
         now: @escaping () -> Date = Date.init,
         log: @escaping (String) -> Void = {
             HakoLogStore.shared.append($0, stream: .app)
         }) {
        self.store = store
        self.profileStore = profileStore
        self.credentials = credentials
        self.coreHomeDir = coreHomeDir
        self.compileRuleSets = compileRuleSets
        self.deferRuleSetCompilation = deferRuleSetCompilation
        self.stagingPublisher = stagingPublisher
        self.scheduleDeferredCompilation = scheduleDeferredCompilation
        self.activationFetchBudget = activationFetchBudget
        self.globalOverride = globalOverride
        self.runtimeOverride = runtimeOverride
        self.profileScript = profileScript
        self.configScript = configScript
        self.postMergeScript = postMergeScript
        self.activator = activator
        self.subscriptions = SubscriptionManager(downloader: downloader, credentials: credentials)
        self.materializer = ProviderMaterializer(downloader: downloader, credentials: credentials)
        self.geodata = GeodataManager(downloader: downloader)
        self.preflight = preflight
        self.now = now
        self.log = log
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    private struct FailureRecord {
         
         
         
         
        let stage: String
        let error: String
        let cancelled: Bool

        init(_ error: Error) {
            cancelled = error is CancellationError
            switch error {
            case let pipeline as PipelineError:
                switch pipeline {
                case .sourceUnavailable: (stage, self.error) = ("source", "sourceUnavailable")
                case .notModifiedWithoutActive:
                    (stage, self.error) = ("source", "notModifiedWithoutActive")
                case .planRejected: (stage, self.error) = ("plan", "planRejected")
                case .providerNotFound: (stage, self.error) = ("plan", "providerNotFound")
                case .externalResources: (stage, self.error) = ("resources", "externalResources")
                case .preflightFailed: (stage, self.error) = ("preflight", "preflightFailed")
                case .activationReadback: (stage, self.error) = ("publish", "activationReadback")
                }
            case is CancellationError:
                (stage, self.error) = ("cancelled", "CancellationError")
            default:
                 
                 
                (stage, self.error) = ("unknown", String(describing: type(of: error)))
            }
        }
    }

     
     
     
     
     
    private func record(_ error: Error, profile: Profile, since start: Date) {
        let record = FailureRecord(error)
        let millis = Int((now().timeIntervalSince(start) * 1000).rounded())
        var line = "profile activation \(record.cancelled ? "cancelled" : "failed")  "
            + "id=\(profile.id) stage=\(record.stage) "
            + "error=\(record.error) after=\(millis)ms"
         
         
        if !record.cancelled {
            let reason = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
            if !reason.isEmpty {
                 
                 
                 
                 
                let bounded = reason.count > 400
                    ? String(reason.prefix(400)) + "…(truncated)"
                    : reason
                line += "  reason=\(bounded)"
            }
        }
        log(line)
    }

    @discardableResult
    func activate(profile: Profile, sourceYAML: String?) async throws -> ActiveConfigurationPointer {
         
         
         
        let startedAt = now()
        do {
            let pointer = try await activateResolved(
                profile: profile, sourceYAML: sourceYAML, forceFreshFetch: false
            )
             
             
            log("profile activated  id=\(profile.id) rev=\(pointer.revision)")
            return pointer
        } catch let original {
             
             
             
             
             
             
            guard !(original is CancellationError), sourceYAML != nil,
                  case .url = profile.source else {
                record(original, profile: profile, since: startedAt)
                throw original
            }
            var healed = profile
            healed.usesLocalSourceOverride = false
            do {
                let pointer = try await activateResolved(
                    profile: healed, sourceYAML: nil, forceFreshFetch: true
                )
                 
                 
                 
                 
                 
                log(
                    "profile activated  id=\(profile.id) rev=\(pointer.revision) "
                        + "healed=refetched"
                )
                return pointer
            } catch is CancellationError {
                record(CancellationError(), profile: profile, since: startedAt)
                throw CancellationError()
            } catch {
                 
                record(original, profile: profile, since: startedAt)
                throw original
            }
        }
    }

    private func activateResolved(
        profile: Profile,
        sourceYAML: String?,
        forceFreshFetch: Bool
    ) async throws -> ActiveConfigurationPointer {
        var fetchedInfo: SubscriptionInfo?
        var fetchedETag: String?
        var fetchedLastModified: String?
        let raw: String
        if let sourceYAML {
            raw = sourceYAML
        } else {
            guard case .url = profile.source else {
                throw PipelineError.sourceUnavailable(
                    "profile '\(profile.label)' has no stored YAML and no subscription URL")
            }
            if let fetched = try await subscriptions.fetch(
                profile: profile,
                useConditionalValidators: !forceFreshFetch
            ) {
                raw = fetched.yaml
                fetchedInfo = fetched.subscriptionInfo
                fetchedETag = fetched.etag
                fetchedLastModified = fetched.lastModified
            } else {
                 
                 
                var checked = profile
                checked.lastUpdatedAt = Date()
                try? profileStore.upsert(checked)
                 
                if let current = try store.activePointer(), current.profileID == profile.id {
                    return current
                }

                 
                 
                 
                 
                 
                 
                 
                if !forceFreshFetch, let cached = try? String(
                    contentsOf: sidecarURL(profileID: profile.id),
                    encoding: .utf8
                ), !cached.isEmpty {
                    raw = cached
                } else if let fetched = try await subscriptions.fetch(
                    profile: profile,
                    useConditionalValidators: false
                ) {
                    raw = fetched.yaml
                    fetchedInfo = fetched.subscriptionInfo
                    fetchedETag = fetched.etag
                    fetchedLastModified = fetched.lastModified
                } else {
                    throw PipelineError.notModifiedWithoutActive
                }
            }
        }

         
         
         
         
        try ConfigTransforms.validateSource(raw)
        let prepared = try prepareConfig(raw: raw, profile: profile)
         
         
         
         
         
         
        let (reusableProviders, reuseSource) = reusableProvidersDirectory(for: profile)
        activationReuseSource = reuseSource
        let pointer = try await buildPublishActivate(
            profile: profile,
            merged: prepared,
            reuseDir: reusableProviders,
            reuseDirIsOwnRevision: reuseSource.hasPrefix("own"),
             
             
             
             
            fetchBudget: activationFetchBudget
        ).pointer
        ProviderFirstLoadRetry.noteActivation(
            pending: firstLoadPendingOfLastPublication, profileID: profile.id
        )

         
         
         
         
        var updated = profile
        updated.activeRevision = pointer.revision
        if sourceYAML == nil { updated.lastUpdatedAt = Date() }   
        if let fetchedInfo { updated.subscriptionInfo = fetchedInfo }
        if sourceYAML == nil {
            updated.subscriptionETag = fetchedETag ?? updated.subscriptionETag
            updated.subscriptionLastModified = fetchedLastModified ?? updated.subscriptionLastModified
        }
        try profileStore.upsert(updated)
         
         
         
        try writeSourceSidecar(raw, profileID: profile.id)
        return pointer
    }

     
     
     
     
     
     
    @discardableResult
    func regenerateRuntime(
        profile: Profile,
        storedSourceYAML: String,
        sourceIsStoredSidecar: Bool = true,
        replacing previousRuntime: ActiveConfigurationPointer
    ) async throws -> ActiveConfigurationPointer {
        try ConfigTransforms.validateSource(storedSourceYAML)
        let prepared = try prepareConfig(raw: storedSourceYAML, profile: profile)
         
         
         
         
        let (reusableProviders, reuseSource) = reusableProvidersDirectory(for: profile)
        activationReuseSource = reuseSource
        let pointer = try await buildPublishActivate(
            profile: profile,
            merged: prepared,
            reuseDir: reusableProviders,
            reuseDirIsOwnRevision: reuseSource.hasPrefix("own"),
            replacing: previousRuntime,
            fetchBudget: activationFetchBudget
        ).pointer
        ProviderFirstLoadRetry.noteActivation(
            pending: firstLoadPendingOfLastPublication, profileID: profile.id
        )

        var updated = profile
        updated.activeRevision = pointer.revision
         
         
         
        try? profileStore.upsert(updated)
        if !sourceIsStoredSidecar {
             
             
             
            try? writeSourceSidecar(storedSourceYAML, profileID: profile.id)
        }
        return pointer
    }

     
     
     
     
     
    @discardableResult
    func refreshProvider(
        named name: String, profile: Profile,
        fetchBudget: ProviderFetchBudget = .patient
    ) async throws -> ProviderRefreshResult {
        guard let raw = try? String(contentsOf: sidecarURL(profileID: profile.id),
                                    encoding: .utf8) else {
            throw PipelineError.sourceUnavailable(
                "profile '\(profile.label)' has no cached source; update the profile once first")
        }
         
        try ConfigTransforms.validateSource(raw)
        let merged = try prepareConfig(raw: raw, profile: profile)

         
        var reuseDir: URL?
        if let pointer = try? store.activePointer(), pointer.profileID == profile.id {
            reuseDir = try? store.activeProvidersDirectory()
        }

        let publication = try await buildPublishActivate(
            profile: profile, merged: merged,
            reuseDir: reuseDir, forceRefresh: [name],
            fetchBudget: fetchBudget)
        var updated = profile
        updated.activeRevision = publication.pointer.revision
        try? profileStore.upsert(updated)
        return ProviderRefreshResult(
            pointer: publication.pointer,
            runtimeUpdate: publication.runtimeUpdates[name]
        )
    }

     
     
     
     
     
     
     
     
    func refreshPendingProviders(
        profile: Profile, names: [String], fetchBudget: ProviderFetchBudget
    ) async throws -> (pointer: ActiveConfigurationPointer,
                       runtimeUpdates: [String: ProviderRuntimeUpdate],
                       stillPending: [String]) {
        guard let raw = try? String(contentsOf: sidecarURL(profileID: profile.id),
                                    encoding: .utf8) else {
            throw PipelineError.sourceUnavailable(
                "profile '\(profile.label)' has no cached source; update the profile once first")
        }
        try ConfigTransforms.validateSource(raw)
        let merged = try prepareConfig(raw: raw, profile: profile)
        var reuseDir: URL?
        if let pointer = try? store.activePointer(), pointer.profileID == profile.id {
            reuseDir = try? store.activeProvidersDirectory()
        }
        let publication = try await buildPublishActivate(
            profile: profile, merged: merged,
            reuseDir: reuseDir,
            fetchBudget: fetchBudget,
            capturePayloads: Set(names))
        var updated = profile
        updated.activeRevision = publication.pointer.revision
        try? profileStore.upsert(updated)
        return (publication.pointer,
                publication.runtimeUpdates.filter { names.contains($0.key) },
                publication.firstLoadPending.filter { names.contains($0) })
    }

     
     
     
     
     
     
     
     
     
     
     
    func refreshProviders(
        named names: [String],
        profile: Profile,
        fetchBudget: ProviderFetchBudget = .patient
    ) async throws -> (pointer: ActiveConfigurationPointer,
                       runtimeUpdates: [String: ProviderRuntimeUpdate]) {
        guard let raw = try? String(contentsOf: sidecarURL(profileID: profile.id),
                                    encoding: .utf8) else {
            throw PipelineError.sourceUnavailable(
                "profile '\(profile.label)' has no cached source; update the profile once first")
        }
        try ConfigTransforms.validateSource(raw)
        let merged = try prepareConfig(raw: raw, profile: profile)
        var reuseDir: URL?
        if let pointer = try? store.activePointer(), pointer.profileID == profile.id {
            reuseDir = try? store.activeProvidersDirectory()
        }
        let publication = try await buildPublishActivate(
            profile: profile, merged: merged,
            reuseDir: reuseDir, forceRefresh: Set(names),
            fetchBudget: fetchBudget)
        var updated = profile
        updated.activeRevision = publication.pointer.revision
        try? profileStore.upsert(updated)
        return (publication.pointer,
                publication.runtimeUpdates.filter { names.contains($0.key) })
    }

    @discardableResult
    func sideLoadProvider(
        named name: String,
        data: Data,
        profile: Profile
    ) async throws -> ProviderRefreshResult {
        guard let raw = try? String(
            contentsOf: sidecarURL(profileID: profile.id),
            encoding: .utf8
        ) else {
            throw PipelineError.sourceUnavailable(
                "profile '\(profile.label)' has no cached source; update the profile once first"
            )
        }
         
        try ConfigTransforms.validateSource(raw)
        let merged = try prepareConfig(raw: raw, profile: profile)
        var reuseDir: URL?
        if let pointer = try? store.activePointer(), pointer.profileID == profile.id {
            reuseDir = try? store.activeProvidersDirectory()
        }
        let publication = try await buildPublishActivate(
            profile: profile,
            merged: merged,
            reuseDir: reuseDir,
            providerOverrides: [name: data]
        )
        var updated = profile
        updated.activeRevision = publication.pointer.revision
        try? profileStore.upsert(updated)
        return ProviderRefreshResult(
            pointer: publication.pointer,
            runtimeUpdate: publication.runtimeUpdates[name]
        )
    }

     
     
     
     
     
     
     
    private func prepareConfig(raw: String, profile: Profile) throws -> String {
        let runtime = try ProfileRuntimeConfigBuilder.build(
            raw: raw,
            profile: profile,
            globalOverride: globalOverride(),
            runtimeOverride: runtimeOverride(),
            profileScript: profileScript,
            configScript: configScript,
             
             
             
             
             
             
             
             
             
            postMergeScript: postMergeScript
        )
        noteExternalResources(in: runtime, profile: profile)
        return runtime
    }

     
     
     
     
     
     
     
    static func providerAgeSecretKeys(in mergedYAML: String) throws -> [String: String] {
        let json = try ConfigTransforms.yamlToJSON(mergedYAML)
        guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let providers = root["proxy-providers"] as? [String: Any] else {
            return [:]
        }
        var keys: [String: String] = [:]
        for (name, raw) in providers {
            guard let definition = raw as? [String: Any],
                  (definition["type"] as? String)?.lowercased() == "http",
                  let key = definition["age-secret-key"] as? String,
                  !key.isEmpty else { continue }
            keys["proxy:\(name)"] = key
        }
        return keys
    }

     
     
     
     
     
     
     
     
     
     
     
    private func noteExternalResources(in yaml: String, profile: Profile) {
        guard let runtimeJSON = try? ConfigTransforms.yamlToJSON(yaml),
              let runtimeRoot = try? JSONSerialization.jsonObject(
                  with: Data(runtimeJSON.utf8)
              ) as? [String: Any] else { return }
        let source: IOSExternalResourceSource
        switch profile.source {
        case .url: source = .subscription
        case .file: source = .localFile
        case .clipboard: source = .clipboard
        }
        var externalResources = IOSExternalResourceCatalog.inspect(
            root: runtimeRoot,
            source: source
        )
         
         
        externalResources.removeAll { $0.resolution == .managedRuntimeStateRequired }
        let requirements = IOSExternalResourceCatalog.requirements(root: runtimeRoot)
        let references = profile.externalResources ?? []
        var allowed: [String: Int] = [:]
        for requirement in requirements
        where requirement.capability.disposition == .publicFileOrInline {
            let digest = ProfileExternalResourceImporter.sha256(
                Data(requirement.rawValue.utf8)
            )
            if references.contains(where: {
                $0.capabilityID == requirement.capability.id
                    && $0.proxy == requirement.proxyName
                    && $0.fieldPath == requirement.capability.fieldPath
                    && $0.sourceValueSHA256 == digest
            }) {
                allowed[requirement.capability.id, default: 0] += 1
            }
        }
        externalResources.removeAll { finding in
            guard (finding.resolution == .localImportRequired
                    || finding.resolution == .subscriptionCannotReadFile),
                  let count = allowed[finding.capabilityID], count > 0 else {
                return false
            }
            allowed[finding.capabilityID] = count - 1
            return true
        }
        for finding in externalResources {
            log("external resource left to the kernel  id=\(profile.id) capability=\(finding.capabilityID) resolution=\(finding.resolution)")
        }
    }

     
     
     
     
     
     
     
     
     
     
     
    private func reusableProvidersDirectory(for profile: Profile) -> (URL?, String) {
        if let revision = profile.activeRevision,
           let own = store.providersDirectory(profileID: profile.id, revision: revision),
           FileManager.default.fileExists(atPath: own.path) {
            return (own, "own(\(fileCount(in: own)))")
        }
        if let newest = store.newestProvidersDirectory(profileID: profile.id) {
            return (newest, "newest(\(fileCount(in: newest)))")
        }
        if let active = try? store.activeProvidersDirectory() {
            return (active, "active(\(fileCount(in: active)))")
        }
        return (nil, "none")
    }

    private func fileCount(in directory: URL) -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path))?.count ?? -1
    }

    private func buildPublishActivate(
        profile: Profile, merged: String,
        reuseDir: URL? = nil,
        reuseDirIsOwnRevision: Bool = true,
        forceRefresh: Set<String> = [],
        providerOverrides: [String: Data] = [:],
        replacing previousRuntime: ActiveConfigurationPointer? = nil,
        fetchBudget: ProviderFetchBudget = .patient,
         
         
         
         
        capturePayloads: Set<String> = []
    ) async throws -> ProfilePublicationResult {
        let candidate = try store.beginCandidate(profileID: profile.id)
        let previous: ActiveConfigurationPointer?
        var runtimeUpdates: [String: ProviderRuntimeUpdate] = [:]
        do {
            let materializedMerged = try ProfileExternalResourceMaterializer.materialize(
                yaml: merged,
                profile: profile,
                coreHomeDir: coreHomeDir,
                candidate: candidate
            )
            let plan = try ConfigTransforms.planResources(mergedYAML: materializedMerged)
            guard plan.errors.isEmpty else {
                throw PipelineError.planRejected(plan.errors)
            }
            let ageSecretKeys = try Self.providerAgeSecretKeys(in: materializedMerged)
             
             
             
             
             
            for provider in plan.providers where provider.kind == "proxy" {
                if let resourceKey = provider.resourceKey {
                    try? credentials.remove("provider.age.\(profile.id).\(resourceKey)")
                }
            }
            let requestedProviders = forceRefresh.union(Set(providerOverrides.keys)).union(capturePayloads)
            for name in requestedProviders
            where !plan.providers.contains(where: { $0.name == name }) {
                throw PipelineError.providerNotFound(name)
            }
            let stages = ActivationStopwatch()
            let materialized = try await materializer.materializeDetailed(
                plan: plan,
                into: candidate.stagingProvidersDirectory,
                publishedProvidersDir: candidate.publishedProvidersDirectory,
                maxBytesEach: Self.maxProviderBytes,
                reuseDir: reuseDir,
                reuseDirIsOwnRevision: reuseDirIsOwnRevision,
                forceRefresh: forceRefresh,
                ageSecretKeys: ageSecretKeys,
                localOverrides: providerOverrides,
                captureRefreshedPayloads: requestedProviders,
                userAgent: ClientUserAgent.resolved(
                    configYAML: materializedMerged,
                    fallback: ClientUserAgent.resolved(profile: profile)
                ),
                fetchBudget: fetchBudget
            )
            firstLoadPendingOfLastPublication = materialized.firstLoadPending
            let providerPaths = materialized.paths
            let providerKinds = Dictionary(
                uniqueKeysWithValues: plan.providers.map { ($0.name, $0.kind) }
            )
            runtimeUpdates = Dictionary(
                uniqueKeysWithValues: materialized.refreshedPayloads.compactMap { name, payload in
                    guard let kind = providerKinds[name] else { return nil }
                    return (name, ProviderRuntimeUpdate(name: name, kind: kind, payload: payload))
                }
            )
            let providerReadPaths = Dictionary(uniqueKeysWithValues: plan.providers.map {
                ($0.name, candidate.stagingProvidersDirectory.appendingPathComponent($0.path).path)
            })
             
             
            let reusedEntries = reuseDir.flatMap {
                ProviderCatalog.load(providersDir: $0)
            }?.entries ?? []
            var subscriptionInfo = Dictionary(
                uniqueKeysWithValues: reusedEntries
                    .compactMap { entry in
                        entry.subscriptionInfo.map { (entry.name, $0) }
                    }
            )
            var lastUpdatedAt: [String: Date] = [:]
            for entry in reusedEntries {
                if let timestamp = entry.lastUpdatedAt {
                    lastUpdatedAt[entry.name] = timestamp
                } else if let reuseDir,
                          let attributes = try? FileManager.default.attributesOfItem(
                            atPath: reuseDir.appendingPathComponent(entry.path).path
                          ),
                          let timestamp = attributes[.modificationDate] as? Date {
                     
                     
                    lastUpdatedAt[entry.name] = timestamp
                }
            }
            let refreshedAt = now()
            for name in materialized.refreshedNames {
                lastUpdatedAt[name] = refreshedAt
                subscriptionInfo.removeValue(forKey: name)
                if let header = materialized.subscriptionUserInfo[name],
                   let parsed = SubscriptionInfo.parse(header: header) {
                    subscriptionInfo[name] = parsed
                }
            }
            try ProviderCatalog.from(
                plan: plan,
                entryCounts: materialized.entryCounts,
                subscriptionInfo: subscriptionInfo,
                lastUpdatedAt: lastUpdatedAt,
                loadFailures: Dictionary(
                    materialized.validationWarnings.map { ($0.provider, $0.reason) },
                    uniquingKeysWith: { first, _ in first }
                ),
                payloadSourceURLs: materialized.payloadSourceURLs
            ).write(providersDir: candidate.stagingProvidersDirectory)
            stages.mark(
                "providers",
                count: plan.providers.count,
                detail: "reused=\(materialized.reusedCount) fetched=\(materialized.fetchedCount) "
                    + "from=\(activationReuseSource)"
                     
                     
                     
                    + (materialized.staleFallbacks.isEmpty
                        ? ""
                        : " kept-old=\(materialized.staleFallbacks.count)")
            )
            try await geodata.stage(
                plan: plan,
                homeDir: coreHomeDir,
                maxBytesEach: Self.maxGeodataBytes,
                preferBundled: true
            )

            stages.mark("geodata")
            let finalYAML = try ConfigTransforms.finalize(
                mergedYAML: materializedMerged,
                providerPaths: providerPaths,
                providerReadPaths: providerReadPaths)

            stages.mark("finalize")
            let outcome = preflight(finalYAML)
            stages.mark("preflight")
            guard outcome.ok else {
                throw PipelineError.preflightFailed(outcome.errorMessage ?? "preflight failed")
            }

             
             
             
             
             
             
             
             
             
             
            GeoSiteCompiler.prepare(finalYAML: finalYAML)
             
             
             
             
             
             
            GeoSiteCompiler.prepareRulePayloads(
                in: candidate.stagingProvidersDirectory,
                plan: plan
            )
             
             
             
             
             
             
             
             
             
             
             
            GeoIPCompiler.prepare(finalYAML: finalYAML)
            GeoIPCompiler.prepareRulePayloads(
                in: candidate.stagingProvidersDirectory,
                plan: plan,
                geodataMode: GeoIPCompiler.geodataModeEnabled(in: finalYAML)
            )
            stages.mark("geosite")
            stages.report()

            if let previousRuntime {
                previous = try store.publishAndActivateIfCurrentMatches(
                    candidate,
                    finalData: Data(finalYAML.utf8),
                    expectedActive: previousRuntime
                )
            } else {
                previous = try store.publishAndActivate(
                    candidate,
                    finalData: Data(finalYAML.utf8)
                )
            }
             
             
             
             
            publishStaging(finalYAML: finalYAML, providerCount: plan.providers.count)
             
             
             
             
            if let intentJSON = outcome.intentJSON {
                PublishedTunIntent.publish(
                    intentJSON: intentJSON,
                    defaults: UserDefaults(suiteName: HakoAppIdentifiers.appGroup)
                )
            }
        } catch {
             
            try? store.discard(candidate)
            throw error
        }

        do {
            try activator(store.activeConfigURL)
        } catch {
            try? store.restoreActive(previous)
            throw error
        }

        return ProfilePublicationResult(
            pointer: ActiveConfigurationPointer(
                profileID: profile.id,
                revision: candidate.revision
            ),
            runtimeUpdates: runtimeUpdates
        )
    }

     
     
    private func sidecarURL(profileID: String) -> URL {
        coreHomeDir.appendingPathComponent("store/\(profileID)/source.yaml")
    }


    private func writeSourceSidecar(_ yaml: String, profileID: String) throws {
        let url = sidecarURL(profileID: profileID)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(yaml.utf8).write(
            to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

}
