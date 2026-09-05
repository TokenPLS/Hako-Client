import Combine
#if os(macOS)
 
 
import Hako
#endif
import HakoClientUI

 
 
 
 
 
 
 
 
struct HakoCoreRefusal: Error {}
import SwiftUI
import UniformTypeIdentifiers

 
 
 
private actor LocalProfilePreviewCache {
    static let shared = LocalProfilePreviewCache()

    private var values: [String: String] = [:]

    func text(for profile: Profile, container: URL?) -> String? {
        guard let source = activeRevisionSource(for: profile, container: container)
            ?? sidecarSource(for: profile, container: container)
        else { return nil }
        return text(for: source)
    }

     
     
     
    func exportText(for profile: Profile, container: URL?) -> String? {
        guard let source = sidecarSource(for: profile, container: container)
            ?? activeRevisionSource(for: profile, container: container)
        else { return nil }
        return text(for: source)
    }

     
     
     
     
     
    private func text(
        for source: (cacheKey: String, cacheNamespace: String, yaml: String)
    ) -> String? {
        if let cached = values[source.cacheKey] { return cached }
        let staleKeys = values.keys.filter {
            $0 != source.cacheKey && $0.hasPrefix("\(source.cacheNamespace)|")
        }
        staleKeys.forEach { values.removeValue(forKey: $0) }
        values[source.cacheKey] = source.yaml
        return source.yaml
    }

    private func activeRevisionSource(
        for profile: Profile,
        container: URL?
    ) -> (cacheKey: String, cacheNamespace: String, yaml: String)? {
        guard let container else { return nil }

        if let revision = profile.activeRevision,
           let stored = try? ConfigResourceStore(containerURL: container)
               .loadConfiguration(profileID: profile.id, revision: revision),
           let yaml = stored.text {
            let namespace = "revision|\(profile.id)"
            return ("\(namespace)|\(revision)", namespace, yaml)
        }

        return nil
    }

    private func sidecarSource(
        for profile: Profile,
        container: URL?
    ) -> (cacheKey: String, cacheNamespace: String, yaml: String)? {
        guard let container else { return nil }
        let sidecar = container
            .appendingPathComponent("working/store/\(profile.id)/source.yaml")
        guard let yaml = try? String(contentsOf: sidecar, encoding: .utf8) else { return nil }
        let attributes = try? FileManager.default.attributesOfItem(atPath: sidecar.path)
        let size = (attributes?[.size] as? NSNumber)?.int64Value ?? Int64(yaml.utf8.count)
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let namespace = "source|\(profile.id)"
        return ("\(namespace)|\(sidecar.path)|\(size)|\(modified)", namespace, yaml)
    }
}

 
 
@MainActor
final class ProfilesViewModel: ObservableObject {
     
     
     
    var resourceStoreForHomeTally: ConfigResourceStore? {
        container.flatMap { try? ConfigResourceStore(containerURL: $0) }
    }

    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var activeProfileID: String?
    @Published private(set) var busyProfileID: String?
     
     
     
     
     
     
    @Published private(set) var isActivating = false
     
     
     
    @Published private(set) var activationAppliesToTunnel: Bool?
     
     
     
    @Published private(set) var statusMessage: HakoDisplayText = .copy("")
    @Published private(set) var notices: [String] = []
    @Published private(set) var planErrors: [String] = []
    @Published private(set) var lastFailure: ConfigurationFailure?
    @Published private(set) var batchReport: BatchUpdateReport?
    @Published private(set) var isBatchSyncing = false

     
     
     
     
    private var baseYAMLCache: [String: (key: String, value: String?)] = [:]
    private var projectedYAMLCache: [String: (key: String, value: String?)] = [:]
     
     
     
    private var effectiveYAMLCache: [String: (key: String, value: String?)] = [:]
     
     
     
     
     
     
    private var sourceYAMLCache: [String: String?] = [:]

    private let vpn: VPNController
    private let credentials: CredentialStore
    private let container: URL?
    private let runtimeDefaults: UserDefaults
    private let sourceWriter: (String, Profile, URL) throws -> Void
    private let makeProfileID: () -> String
    private var activationTask: Task<Void, Never>?
     
    private var pendingRestage: Task<Void, Never>?
    private var pendingActivation: ActivationRequest?
    private var batchTask: Task<Void, Never>?
    private var batchRunID: UUID?
    private(set) var storeReplacementObserver: NSObjectProtocol?
    private var selectionObserver: NSObjectProtocol?
     
     
     
    private static let batchItemLimit: TimeInterval = 45
    private var failedOperation: FailedOperation?
    private var automaticSelectionAttempts: Set<String> = []

    var isActivationInFlight: Bool { activationAppliesToTunnel != nil }

    private struct ActivationRequest {
        let profile: Profile
        let applyToTunnel: Bool
        let preferCachedSource: Bool
    }

    private enum FailedOperation {
        case sync(String)
        case activation(String)
    }

    init(
        vpn: VPNController,
        container: URL? = HakoAppIdentifiers.appGroupContainer,
        credentials: CredentialStore = CredentialStore(),
        sourceWriter: ((String, Profile, URL) throws -> Void)? = nil,
        makeProfileID: @escaping () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.vpn = vpn
        self.container = container
        self.runtimeDefaults = vpn.clientPreferences
        self.credentials = credentials
        self.sourceWriter = sourceWriter ?? Self.writeSourceYAML
        self.makeProfileID = makeProfileID
         
         
         
         
        widgetFactsSubscription = Publishers.CombineLatest($activeProfileID, $profiles)
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] activeID, profiles in
                guard let self else { return }
                let active = profiles.first { $0.id == activeID }
                HakoWidgetFactsPublisher.publish(activeLabel: active?.label) { [weak self] in
                    guard let self, let active else { return nil }
                    return self.sourceYAML(for: active)
                }
            }
    }

    private var widgetFactsSubscription: AnyCancellable?

    deinit {
         
         
         
         
        if let storeReplacementObserver {
            NotificationCenter.default.removeObserver(storeReplacementObserver)
        }
        if let selectionObserver {
            NotificationCenter.default.removeObserver(selectionObserver)
        }
    }

    private var workingDir: URL? { container?.appendingPathComponent("working") }
    private var profileStore: ProfileStore? {
        workingDir.map { ProfileStore(fileURL: $0.appendingPathComponent("store/profiles.json")) }
    }

     
     
     
     
    private func observeStoreReplacement() {
        guard storeReplacementObserver == nil else { return }
        storeReplacementObserver = NotificationCenter.default.addObserver(
            forName: .hakoProfileStoreReplaced,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.load()
        }
         
         
         
         
        selectionObserver = NotificationCenter.default.addObserver(
            forName: .hakoProfileSelectionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.load()
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func applyProfileNow(_ profileID: String) {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == profileID })
        else { return }
        let action = ProfileSettingsRestagePolicy.action(
            profileID: profileID,
            activeProfileID: activeProfileID,
            vpnStatus: vpn.status
        )
        guard action != .persistOnly else { return }
        startActivation(
            latest,
            applyToTunnel: action == .restageAndApply,
            preferCachedSource: true,
            because: HakoPerf.Reason.readerTappedApply
        )
    }

    private func scheduleRestage(_ profile: Profile, applyToTunnel: Bool) {
        pendingRestage?.cancel()
        let request = (profile, applyToTunnel)
        pendingRestage = Task { [weak self] in
             
             
             
             
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.pendingRestage = nil
            self.startActivation(
                request.0,
                applyToTunnel: request.1,
                preferCachedSource: true,
                because: HakoPerf.Reason.editSettled
            )
        }
    }

    func load() {
         
         
         
         
        forgetCachedSource()
        let loadBegan = DispatchTime.now().uptimeNanoseconds
        defer {
            HakoPerf.span(
                "profiles.load",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - loadBegan
                ) / 1_000_000,
                detail: "profiles=\(profiles.count)"
            )
        }
         
         
         
         
         
        derivedModeMemo = nil
        observeStoreReplacement()
        guard let profileStore else { return }
         
         
         
         
         
        if let workingDir {
            PlaintextSourceMigration.run(
                profileStore: profileStore,
                workingDir: workingDir,
                credentials: credentials
            )
        }
        if let container, !false {
            do {
                try LocalDefaultProfileProvisioner.provisionIfNeeded(
                    store: profileStore,
                    workingDirectory: container.appendingPathComponent("working")
                )
                try BundledProfileProvisioner.provisionExistingProfileIfNeeded(
                    container: container
                )
                 
                 
                 
                 
                try CorpusProfileSeeder.seedIfRequested(
                    store: profileStore,
                    workingDirectory: container.appendingPathComponent("working")
                )
                 
                 
                 
                if let documents = try? FileManager.default.url(
                    for: .documentDirectory, in: .userDomainMask,
                    appropriateFor: nil, create: false
                ) {
                    RuleProviderCompileProbe.runIfRequested(documents: documents)
                }
            } catch {
                recordFailure(error, context: .localImport, operation: nil,
                              preservesLastKnownGood: false)
            }
        }
         
         
         
        let loaded = profileStore.load().sorted {
            ($0.order, $0.id) < ($1.order, $1.id)
        }
        if let container {
             
             
             
            activeProfileID = (
                try? ConfigResourceStore(
                    containerURL: container
                ).activeIdentity()
            )?.profileID
        }
        let preferred = loaded.first {
            $0.id == activeProfileID
        } ?? loaded.first
        _ = FlClashRuntimeConfig.migrateIfNeeded(
            preferredProfile: preferred,
            legacyGlobalOverride: GlobalConfig.load(
                from: runtimeDefaults
            ),
            defaults: runtimeDefaults
        )
         
         
        _ = FlClashRuntimeConfig.promoteNamespacesIfNeeded(
            profiles: loaded,
            activeProfileID: activeProfileID,
            defaults: runtimeDefaults
        )
        let sanitized = loaded.map(
            FlClashRuntimeConfig.sanitizedProfile
        )
        if sanitized != loaded {
            do {
                try profileStore.save(sanitized)
            } catch {
                recordFailure(
                    error,
                    context: .activation,
                    operation: nil,
                    preservesLastKnownGood: true
                )
            }
        }
        profiles = sanitized
    }

     

    func add(
        label: String,
        source: Profile.Source,
        rawYAML: String?,
        resourceFiles: [ExternalResourceImportFile] = []
    ) {
        guard let profileStore, let workingDir else { return }
         
         
         
         
         
        let uniqueLabel = ProfileLabelPolicy.deduplicate(
            ProfileLabelPolicy.name(given: label, for: source),
            existing: profiles.map(\.label)
        )
        var profile = Profile(
            id: makeProfileID(), label: uniqueLabel,
             
             
             
            labelIsUserAssigned: !label
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            source: source,
            autoUpdate: { if case .url = source { return true } else { return false } }(),
            updateIntervalHours: 12, subscriptionInfo: nil, selectedMap: [:],
            override: OverrideSpec(), activeRevision: nil,
            order: (profiles.map(\.order).max() ?? -1) + 1,
            lastUpdatedAt: nil)
        do {
            if let rawYAML {
                try ConfigTransforms.validateSource(rawYAML)
                let prepared = try ProfileExternalResourceImporter.prepare(
                    yaml: rawYAML,
                    profileID: profile.id,
                    source: externalResourceSource(source),
                    files: resourceFiles
                )
                try ProfileExternalResourceStore.replace(
                    prepared.publicResources,
                    profileID: profile.id,
                    coreHomeDir: workingDir
                )
                profile.externalResources = prepared.references.isEmpty
                    ? nil : prepared.references
                try profileStore.upsert(profile)
                 
                try cacheSourceYAML(prepared.yaml, for: profile)
            } else {
                try profileStore.upsert(profile)
                if case .url = source {
                     
                     
                     
                     
                     
                     
                     
                    load()
                    if let stored = profiles.first(where: { $0.id == profile.id }) {
                        sync(stored)
                    }
                    return
                }
            }
        } catch {
            let failure = ConfigurationFailureClassifier.classify(
                error,
                context: .localImport,
                preservesLastKnownGood: false
            )
            planErrors = failure.map { [$0.localizedDescription] } ?? []
            statusMessage = failure.map { .copy($0.title) } ?? "Profile was not added"
            try? profileStore.remove(id: profile.id)
            try? FileManager.default.removeItem(
                at: workingDir.appendingPathComponent("store/\(profile.id)")
            )
            return
        }
        load()
    }

    @discardableResult
    func addDirectProfile() -> Profile? {
        let label = uniqueCopyLabel(base: "Local Profile", suffix: "")
        add(
            label: label,
            source: .clipboard,
            rawYAML: DirectProfileTemplate.yaml
        )
        return profiles.first { $0.label == label }
    }

     
     
     
    func selectSoleProfileIfNeeded() {
        guard let id = ProfileCenterPolicy.automaticSelectionID(
            profiles: profiles,
            activeProfileID: activeProfileID
        ), automaticSelectionAttempts.insert(id).inserted,
              let profile = profiles.first(where: { $0.id == id }) else { return }
        select(profile)
    }

     
     
    func select(_ profile: Profile) {
        guard profile.id != activeProfileID else { return }
         
         
         
         
         
         
         
        startActivation(
            profile,
            applyToTunnel: ProfileSelectionRuntimePolicy.shouldApplyToTunnel(
                vpnStatus: vpn.status
            ),
            preferCachedSource: true
,
            because: HakoPerf.Reason.profileSelected
        )
    }

     
     
     
     
    func selectAndWait(
        _ profile: Profile, force: Bool = false
    ) async -> Bool {
         
         
         
         
         
        guard force || profile.id != activeProfileID else { return true }
        startActivation(
            profile,
            applyToTunnel: ProfileSelectionRuntimePolicy.shouldApplyToTunnel(
                vpnStatus: vpn.status
            ),
            preferCachedSource: true
        )
        await waitForPendingActivation()
        return activeProfileID == profile.id && lastFailure == nil
    }

     
     
     
    func stripSourceCredentials(_ profile: Profile) throws {
        guard let profileStore else {
            throw PipelineError.sourceUnavailable("the shared profile store is unavailable")
        }
        guard let latest = profileStore.load().first(where: { $0.id == profile.id }),
              let stripped = ProfileMetadataUpdate.strippingSourceCredentials(
                from: latest
              ) else {
            return
        }
        try profileStore.upsert(stripped)
        statusMessage = "Stored link credentials removed"
        load()
    }

     
     
    func saveMemoryTrim(_ profile: Profile) {
        guard let profileStore else { return }
        try? profileStore.upsert(profile)
        load()
    }

    func saveDNSBootstrapInsurance(_ profile: Profile) {
        guard let profileStore else { return }
        try? profileStore.upsert(profile)
        load()
    }

    func updateMetadata(
        _ profile: Profile,
        label: String,
        subscriptionURL: String?,
        autoUpdate: Bool,
        updateIntervalHours: Int
    ) throws {
        guard let profileStore else {
            throw PipelineError.sourceUnavailable("the shared profile store is unavailable")
        }
        do {
            let updated = try ProfileMetadataUpdate.apply(
                to: profile,
                label: label,
                subscriptionURL: subscriptionURL,
                autoUpdate: autoUpdate,
                updateIntervalHours: updateIntervalHours,
                existingLabels: Set(
                    profiles.filter { $0.id != profile.id }.map(\.label)
                )
            )
            try profileStore.upsert(updated)
            statusMessage = .format("%@ saved", [updated.label])
            clearFailure()
            load()
            if ProfileMetadataUpdate.shouldResyncAfterSourceChange(
                previous: profile, updated: updated
            ) {
                sync(profiles.first(where: { $0.id == updated.id }) ?? updated)
            }
        } catch {
            recordFailure(
                error,
                context: .localImport,
                operation: nil,
                preservesLastKnownGood: true
            )
            throw error
        }
    }

     
     
     
     
     
     
     
     
     
     
    @discardableResult
    func duplicate(_ profile: Profile) async -> Profile? {
        guard let profileStore, let workingDir else { return nil }
        let id = makeProfileID()
        let label = uniqueCopyLabel(base: profile.label, suffix: " Copy")
        let sourceWriter = sourceWriter
        do {
            let prepared = try await Task.detached(priority: .userInitiated) {
                guard let hydrated = Self.sidecarYAML(for: profile, workingDir: workingDir) else {
                    throw PipelineError.sourceUnavailable(
                        "the saved source for this profile is unavailable"
                    )
                }
                let resources = try Self.duplicateResourceFiles(
                    sourceYAML: hydrated,
                    profile: profile,
                    dataByKey: Self.externalResourceData(for: profile, workingDir: workingDir)
                )
                let prepared = try ProfileExternalResourceImporter.prepare(
                    yaml: hydrated,
                    profileID: id,
                    source: .localFile,
                    files: resources
                )
                try ProfileExternalResourceStore.replace(
                    prepared.publicResources,
                    profileID: id,
                    coreHomeDir: workingDir
                )
                return prepared
            }.value

            var copy = Profile(
                id: id,
                label: label,
                source: .file(safeProfileFileName(label)),
                autoUpdate: false,
                updateIntervalHours: profile.updateIntervalHours,
                subscriptionInfo: nil,
                selectedMap: profile.selectedMap,
                currentGroupName: profile.currentGroupName,
                unfoldedGroups: profile.unfoldedGroups,
                override: profile.override,
                activeRevision: nil,
                order: profile.order + 1,
                lastUpdatedAt: nil,
                subscriptionETag: nil,
                subscriptionLastModified: nil,
                usesLocalSourceOverride: true,
                selectedScriptID: profile.selectedScriptID,
                overwriteMode: profile.overwriteMode,
                customOverwrite: profile.customOverwrite,
                proxyChain: profile.proxyChain,
                legacyRelayMigrations: profile.legacyRelayMigrations,
                proxyCredentials: nil,
                sourceCredentials: nil,
                sourceCredentialsRedacted: nil,
                externalResources: prepared.references.isEmpty ? nil : prepared.references,
                migratedGlobalOverride: profile.migratedGlobalOverride,
                outboundMode: profile.outboundMode
            )
             
             
             
             
             
             
             
            copy.postMergeScriptID = profile.postMergeScriptID
            copy.proxyNodeOverrides = profile.proxyNodeOverrides
             
             
            copy.providerDefinitions = profile.providerDefinitions
             
             
            copy.subscriptionInfo = nil
             
             
             
             
             
             
             
            var stored = profileStore.load()
            for index in stored.indices where stored[index].id != copy.id && stored[index].order >= copy.order {
                stored[index].order += 1
            }
            stored.removeAll { $0.id == copy.id }
            stored.append(copy)
            let sidecarCopy = copy
            try await Task.detached(priority: .userInitiated) {
                try sourceWriter(prepared.yaml, sidecarCopy, workingDir)
            }.value
            try profileStore.save(stored)
            statusMessage = .format("%@ created", [copy.label])
            clearFailure()
            load()
            return profiles.first(where: { $0.id == copy.id }) ?? copy
        } catch {
            try? profileStore.remove(id: id)
            try? FileManager.default.removeItem(
                at: workingDir.appendingPathComponent("store/\(id)")
            )
            recordFailure(
                error,
                context: .localImport,
                operation: nil,
                preservesLastKnownGood: true
            )
            load()
            return nil
        }
    }

    func installSubscription(_ rawURL: String) {
        if let existing = profiles.first(where: {
            if case let .url(url) = $0.source { return url == rawURL }
            return false
        }) {
            statusMessage = .format("Subscription already exists; syncing %@…", [existing.label])
            sync(existing)
            return
        }
        add(label: "", source: .url(rawURL), rawYAML: nil)
        if let added = profiles.first(where: {
            if case let .url(url) = $0.source { return url == rawURL }
            return false
        }) {
            sync(added)
        }
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            delete(profiles[index])
        }
    }

    func delete(_ profile: Profile) {
        guard let profileStore else { return }
        guard ProfileCenterPolicy.canDelete(
            profileID: profile.id,
            activeProfileID: activeProfileID
        ) else {
            statusMessage = profile.id == LocalDefaultProfileProvisioner.profileID
                ? "Direct is Clash's system fallback and cannot be deleted"
                : "Switch to another profile before deleting"
            return
        }
        let clearsOwnedFailure = failureProfile?.id == profile.id
        do {
             
             
             
             
             
             
             
            try profileStore.remove(id: profile.id)
            if let workingDir {
                try? FileManager.default.removeItem(
                    at: workingDir.appendingPathComponent("store/\(profile.id)")
                )
            }
            try ProxyCredentialVault.remove(
                profile.proxyCredentials ?? [],
                store: credentials
            )
             
             
            try ProxyCredentialVault.remove(
                profile.sourceCredentials ?? [],
                store: credentials
            )
            try ProviderDefinitionCredentialVault.remove(
                profile.providerDefinitionCredentials ?? [],
                store: credentials
            )
            if clearsOwnedFailure {
                clearFailure()
            }
            statusMessage = .format("%@ deleted", [profile.label])
        } catch {
            statusMessage = .format("%@ could not be deleted", [profile.label])
            planErrors = [error.localizedDescription]
        }
        load()
    }

     

    func update(_ profile: Profile) {
        guard let profileStore else { return }
        try? profileStore.upsert(profile)
        load()
    }

     
     
     
     
     
     
     
     
     
    func renameProxyNode(profileID: String, from old: String, to new: String) throws {
        guard let profileStore,
              var latest = profileStore.load().first(where: { $0.id == profileID })
        else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
        var unusedPayload: [[String: Any]] = []
        ProxyNodeRename.apply(
            from: old, to: new, profile: &latest, customPayload: &unusedPayload
        )
        try profileStore.upsert(latest)
        load()
    }

     
     
    func updateRules(_ draft: ProfileRulesDraft) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == draft.profileID }) else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
        try updateConfiguration(draft.applying(to: latest))
    }

     
     
     
    func updateDNS(_ draft: ProfileDNSDraft) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == draft.profileID }) else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
        try updateGlobalConfiguration(
            draft.applying(to: latest),
            replacing: ["dns"],
            configureSpec: { spec in
                spec.dnsOverridesProfiles = draft.dnsOverridesProfiles
            }
        )
    }

     
    func updateHosts(_ draft: ProfileHostsDraft) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == draft.profileID }) else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
        try updateGlobalConfiguration(
            draft.applying(to: latest),
            replacing: ["hosts"]
        )
    }

     
     
    func updateNetwork(_ draft: ProfileNetworkDraft) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == draft.profileID }) else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
        let updated = FlClashRuntimeConfig.sanitizedProfile(
            try draft.applying(to: latest)
        )
        try updateConfiguration(updated)
    }

     
    func updateGlobalNetwork(_ draft: ProfileNetworkDraft) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == draft.profileID }) else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
        try updateGlobalConfiguration(
            draft.applyingGlobalRuntime(
                to: settingsProfile(for: latest)
            ),
            replacing: OverridePatch.networkRuntimeKeys
        )
    }

     
     
    func updateGlobalRuntimeTrust(
        _ draft: ProfileRuntimeTrustDraft
    ) throws {
        guard let profileStore,
              let latest = profileStore.load().first(
                  where: { $0.id == draft.profileID }
              ) else {
            throw PipelineError.sourceUnavailable(
                "the profile is no longer available"
            )
        }
        let projected = try draft.applyingGlobalRuntime(
            to: settingsProfile(for: latest)
        )
        var candidate = latest
        candidate.override.patchJSON = projected.override.patchJSON
        try updateGlobalConfiguration(
            candidate,
            replacing: OverridePatch.runtimeTrustKeys
        )
    }

     
     
     
     
     
    func adoptHeldBackUpdate(_ profile: Profile, keyPath: String) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == profile.id }),
              let item = latest.suppressedUpdates?.first(where: { $0.keyPath == keyPath })
        else { return }
        var patch = OverridePatch(patchJSON: settingsProfile(for: latest).override.patchJSON)
        switch item.change {
        case .removed:
            patch.setValue(nil, at: item.components)
        case .added, .changed:
            guard let text = item.newValue,
                  let value = try? JSONSerialization.jsonObject(
                      with: Data(text.utf8), options: [.fragmentsAllowed]
                  )
            else { return }
            patch.setValue(value, at: item.components)
        }
        var candidate = latest
        candidate.override.patchJSON = patch.patchJSON
        candidate.suppressedUpdates = latest.suppressedUpdates?.filter { $0.keyPath != keyPath }
        if candidate.suppressedUpdates?.isEmpty == true { candidate.suppressedUpdates = nil }
        try updateGlobalConfiguration(candidate, replacing: [item.topLevelKey])
    }

     
    func dismissHeldBackUpdates(_ profile: Profile) throws {
        guard let profileStore,
              var latest = profileStore.load().first(where: { $0.id == profile.id })
        else { return }
        latest.suppressedUpdates = nil
        try profileStore.upsert(latest)
        load()
    }

     
     
    func updateGlobalCoreBehavior(
        network: ProfileNetworkDraft,
        runtime: ProfileRuntimeTrustDraft
    ) throws {
        guard network.profileID == runtime.profileID,
              let profileStore,
              let latest = profileStore.load().first(
                  where: { $0.id == network.profileID }
              ) else {
            throw PipelineError.sourceUnavailable(
                "the profile is no longer available"
            )
        }
        let projected = settingsProfile(for: latest)
        let networkApplied = try network.applyingGlobalRuntime(
            to: projected
        )
        let runtimeApplied = try runtime.applyingGlobalRuntime(
            to: networkApplied
        )
        var candidate = latest
        candidate.override.patchJSON =
            runtimeApplied.override.patchJSON
        try updateGlobalConfiguration(
            candidate,
            replacing:
                OverridePatch.networkRuntimeKeys
                .union(OverridePatch.runtimeTrustKeys)
        )
    }

     
    func updateRoutePreset(_ draft: ProfileRoutePresetDraft) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == draft.profileID }) else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
        try updateGlobalConfiguration(
            draft.applying(to: latest),
            replacing: ["tun"]
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func updateOutboundMode(
        profileID: String,
        mode: Profile.OutboundMode,
        kernelCarriesTheChange: Bool = true
    ) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == profileID }) else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
        var projected = settingsProfile(for: latest)
        var patch = OverridePatch(
            patchJSON: projected.override.patchJSON
        )
        patch.mode = mode.rawValue
        projected.override.patchJSON = patch.patchJSON
        try updateGlobalConfiguration(
            projected,
            replacing: ["mode"],
            runtimeAlreadyCarriesChange: kernelCarriesTheChange
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func restageForClientRuntimeSetting() {
        guard let id = activeProfileID,
              let profile = profiles.first(where: { $0.id == id })
        else { return }
        switch ProfileSettingsRestagePolicy.action(
            profileID: id,
            activeProfileID: activeProfileID,
            vpnStatus: vpn.status
        ) {
        case .persistOnly:
            break
        case .restageOnly:
            startActivation(profile, applyToTunnel: false, preferCachedSource: true, because: HakoPerf.Reason.clientRuntimeSetting)
        case .restageAndApply:
            startActivation(profile, applyToTunnel: true, preferCachedSource: true)
        }
    }

     
     
     
     
     
     
     
     
     
     
    func updateProxySelection(
        profileID: String,
        group: String,
        member: String,
        catalog: ProxiesOverviewModel? = nil
    ) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == profileID }) else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
         
         
         
         
        let catalog = try catalog ?? {
            let projected = cachedUIProjectedYAML(for: latest)
                ?? CustomNodesGroupMaterializer.projectForUI(sourceYAML: sourceYAML(for: latest), profile: latest)
                ?? sourceYAML(for: latest)
            return ProxiesOverviewModel.make(
                sourceYAML: projected,
                selectedMap: latest.selectedMap
            )
        }()
        let isGlobal = group == GlobalProxySelectionPolicy.groupName
        if isGlobal {
             
             
             
            let known = catalog.proxies.contains { $0.name == member }
                || catalog.groups.contains { $0.name == member }
            guard known else {
                throw PipelineError.sourceUnavailable("the selected proxy is no longer available")
            }
        } else {
            guard let targetGroup = catalog.groups.first(where: { $0.name == group }),
                  ProxyGroupControlKind(rawType: targetGroup.type).acceptsMemberChoice,
                  targetGroup.members.contains(where: { $0.name == member }) else {
                throw PipelineError.sourceUnavailable("the selected proxy is no longer available")
            }
        }
        var updated = latest
        updated.selectedMap[group] = member
        updated.currentGroupName = group
        try profileStore.upsert(updated)
         
         
         
         
         
        if let index = profiles.firstIndex(where: { $0.id == updated.id }) {
            profiles[index] = updated
        } else {
            load()
        }
    }

     
     
     
     
     
     
    private var derivedModeMemo:
        (profileID: String, patchJSON: String, mode: Profile.OutboundMode)?

     
     
     
    func outboundMode(for profile: Profile) -> Profile.OutboundMode {
        let runtime = FlClashRuntimeConfig.load(
            from: runtimeDefaults
        )
        if let raw = OverridePatch(
            patchJSON: runtime.patchJSON
        ).mode,
           let mode = Profile.OutboundMode(
               rawValue: raw.lowercased()
           ) {
            return mode
        }
        if let memo = derivedModeMemo,
           memo.profileID == profile.id,
           memo.patchJSON == profile.override.patchJSON {
            return memo.mode
        }
        guard let raw = runtimeSourceYAML(for: profile),
              let generated = try? ProfileRuntimeConfigBuilder.buildProduction(
                raw: raw,
                profile: profile,
                runtimeOverride: runtime
              ),
              let json = try? ConfigTransforms.yamlToJSON(generated),
              let decoded = try? JSONSerialization.jsonObject(with: Data(json.utf8)),
              let object = decoded as? [String: Any],
              let rawMode = object["mode"] as? String,
              let mode = Profile.OutboundMode(rawValue: rawMode.lowercased()) else {
            derivedModeMemo = (profile.id, profile.override.patchJSON, .rule)
            return .rule
        }
        derivedModeMemo = (profile.id, profile.override.patchJSON, mode)
        return mode
    }

     
     
     
     
    func settingsProfile(for profile: Profile) -> Profile {
        var projected = FlClashRuntimeConfig.sanitizedProfile(
            profile
        )
        var patch = OverridePatch(
            patchJSON: projected.override.patchJSON
        )
        let runtime = FlClashRuntimeConfig.load(
            from: runtimeDefaults
        )
        patch.overlayTopLevelKeys(
            OverridePatch.globalRuntimeKeys,
            from: OverridePatch(patchJSON: runtime.patchJSON)
        )
        projected.override.patchJSON = patch.patchJSON
        projected.override.dnsOverridesProfiles = runtime.dnsOverridesProfiles
        projected.outboundMode = OverridePatch(
            patchJSON: runtime.patchJSON
        ).mode.flatMap(Profile.OutboundMode.init(rawValue:))
        return projected
    }

     
     
    func updateProxyChains(_ draft: ProfileProxyChainDraft) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == draft.profileID }) else {
            throw PipelineError.sourceUnavailable("the profile is no longer available")
        }
        let updated = try draft.applying(to: latest)
        if let rawYAML = runtimeSourceYAML(for: latest) {
            do {
                _ = try ProfileRuntimeConfigBuilder.runtimePreview(
                    raw: rawYAML,
                    profile: updated
                )
            } catch let error as LegacyRelayMigrationError {
                 
                 
                 
                 
                guard draft.removesLegacyRelayConfirmation(
                    requiredBy: error,
                    from: latest
                ) else {
                    throw error
                }
            }
        } else if !draft.proxyChain.isEmpty || !draft.legacyRelayMigrations.isEmpty {
            throw PipelineError.sourceUnavailable(
                "Sync or prepare this profile before configuring proxy chains."
            )
        }
        try updateConfiguration(updated)
    }

     
     
     
     
     
     
     
     
     
     
    nonisolated(unsafe) var runtimePreviewValidator: @Sendable (String, Profile) throws -> Void = {
        raw, profile in
        _ = try ProfileRuntimeConfigBuilder.runtimePreview(raw: raw, profile: profile)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    nonisolated static func refusalBelongsToActivation(_ message: String) -> Bool {
        message.contains("is remote (HTTP)")
    }

    nonisolated(unsafe) var coreAcceptsDocument: @Sendable (String, URL) throws -> Void = {
        document, container in
         
         
         
         
         
#if os(macOS)
         
         
         
         
        let setup = HakoSetupOptions()
        setup.basePath = container.path
        setup.workingPath = container.appendingPathComponent("working").path
        setup.tempPath = container.appendingPathComponent("temp").path
        setup.timeZone = TimeZone.current.identifier
        setup.logMaxLines = 100
        setup.runtimeProfile = "macosPacketTunnel"
        setup.disablePersistentCache = true
        var setupError: NSError?
        HakoSetup(setup, &setupError)
        if let setupError { throw setupError }

        var error: NSError?
        guard HakoCheckConfig(document, &error) else {
             
             
             
             
             
             
             
            throw error ?? HakoCoreRefusal()
        }
#else
        _ = try AppConfigurationPreflight.validate(
            document,
            container: container,
            fallbackCode: 2
        )
#endif
    }

     
     
     
     
     
     
     
    func updateProxyNode(originalJSON: String, editedJSON: String) async throws {
        guard let profileStore,
              let profileID = activeProfileID ?? ProfileCenterPolicy.automaticSelectionID(
                profiles: profiles,
                activeProfileID: nil
              ),
              let latest = profileStore.load().first(where: { $0.id == profileID }) else {
            throw PipelineError.sourceUnavailable("there is no selected profile to edit")
        }
        let storedSource = sidecarYAML(for: latest)
        guard ProxyNodeEditPolicy.isEditable(hasStoredSource: storedSource != nil),
              let sourceYAML = storedSource else {
            throw PipelineError.sourceUnavailable(
                ProxyNodeEditPolicy.unavailableReason
            )
        }

        let original = try Self.proxyMapping(from: originalJSON)
        let edited = try Self.proxyMapping(from: editedJSON)
        guard let name = original["name"] as? String,
              !name.isEmpty,
              edited["name"] as? String == name,
              edited["type"] as? String == original["type"] as? String else {
            throw ProxyNodeOverrideError.invalidConfiguration
        }

         
         
         
         
        let originalMapping = try Self.onlyProxy(in: Self.singleProxyYAML(original))
        let editedMapping = try Self.onlyProxy(in: Self.singleProxyYAML(edited))
        var patch = Self.mergePatch(from: originalMapping, to: editedMapping)
        patch.removeValue(forKey: "name")
        patch.removeValue(forKey: "type")
        let patchData = try JSONSerialization.data(
            withJSONObject: patch,
            options: [.sortedKeys]
        )
        let patchJSON = String(decoding: patchData, as: UTF8.self)

        var updated = latest
        var nodeOverrides = updated.proxyNodeOverrides ?? ProxyNodeOverrideSpec()
        nodeOverrides.setPatch(patchJSON, for: name)
        updated.proxyNodeOverrides = nodeOverrides.isEmpty ? nil : nodeOverrides

         
         
        let validate = runtimePreviewValidator
        let candidate = updated
        try await Task.detached(priority: .userInitiated) {
            try validate(sourceYAML, candidate)
        }.value
        try updateConfiguration(updated, stagesToCore: false)
    }

     
     
    func proxyNodeOverridePatch(named name: String) -> String? {
        guard let profileStore,
              let profileID = activeProfileID ?? ProfileCenterPolicy.automaticSelectionID(
                profiles: profiles,
                activeProfileID: nil
              ),
              let latest = profileStore.load().first(where: { $0.id == profileID }) else {
            return nil
        }
        return latest.proxyNodeOverrides?.patch(for: name)
    }

     
     
    func removeProxyNodeOverride(named name: String) throws {
        guard let profileStore,
              let profileID = activeProfileID ?? ProfileCenterPolicy.automaticSelectionID(
                profiles: profiles,
                activeProfileID: nil
              ),
              let latest = profileStore.load().first(where: { $0.id == profileID }) else {
            throw PipelineError.sourceUnavailable("there is no selected profile to edit")
        }
        var updated = latest
        var nodeOverrides = updated.proxyNodeOverrides ?? ProxyNodeOverrideSpec()
        nodeOverrides.removePatch(for: name)
        updated.proxyNodeOverrides = nodeOverrides.isEmpty ? nil : nodeOverrides
        try updateConfiguration(updated, stagesToCore: false)
    }

    private static func proxyMapping(from json: String) throws -> [String: Any] {
        guard let mapping = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw ProxyNodeOverrideError.invalidConfiguration
        }
        return mapping
    }

    private static func singleProxyYAML(_ mapping: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: ["proxies": [mapping]],
            options: [.sortedKeys]
        )
        return try ConfigTransforms.jsonToYAML(String(decoding: data, as: UTF8.self))
    }

    private static func onlyProxy(in yaml: String) throws -> [String: Any] {
        let json = try ConfigTransforms.yamlToJSON(yaml)
        guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any],
              let mapping = (root["proxies"] as? [[String: Any]])?.first else {
            throw ProxyNodeOverrideError.invalidConfiguration
        }
        return mapping
    }

    private static func mergePatch(
        from original: [String: Any],
        to edited: [String: Any]
    ) -> [String: Any] {
        var patch: [String: Any] = [:]
        for key in Set(original.keys).union(edited.keys) {
            guard let editedValue = edited[key] else {
                patch[key] = NSNull()
                continue
            }
            guard let originalValue = original[key] else {
                 
                 
                 
                 
                if editedValue is NSNull { continue }
                patch[key] = editedValue
                continue
            }
            if let oldObject = originalValue as? [String: Any],
               let newObject = editedValue as? [String: Any] {
                let nested = mergePatch(from: oldObject, to: newObject)
                if !nested.isEmpty { patch[key] = nested }
            } else if !jsonValuesEqual(originalValue, editedValue) {
                patch[key] = editedValue
            }
        }
        return patch
    }

    private static func jsonValuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        guard JSONSerialization.isValidJSONObject([lhs]),
              JSONSerialization.isValidJSONObject([rhs]),
              let left = try? JSONSerialization.data(withJSONObject: [lhs], options: [.sortedKeys]),
              let right = try? JSONSerialization.data(withJSONObject: [rhs], options: [.sortedKeys])
        else { return false }
        return left == right
    }

     
     
     
     
    func updateAdvancedOverrides(_ draft: ProfileAdvancedOverridesDraft) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == draft.profileID }) else {
            throw ProfileAdvancedOverridesError.profileChanged
        }

        let availableScriptIDs = Set(ScriptLibrary.load().map(\.id))
        let updated = try draft.applying(
            to: latest,
            availableScriptIDs: availableScriptIDs
        )
        let profileOwned = FlClashRuntimeConfig.sanitizedProfile(updated)
        if let rawYAML = runtimeSourceYAML(for: latest) {
            do {
                _ = try ProfileRuntimeConfigBuilder.runtimePreview(
                    raw: rawYAML,
                    profile: profileOwned,
                    runtimeOverride: FlClashRuntimeConfig.load(
                        from: runtimeDefaults
                    )
                )
            } catch {
                 
                 
                 
                 
                 
                throw ProfileAdvancedOverridesError.validationFailed(
                    reason: (error as NSError).localizedDescription
                )
            }
        }
        try updateConfiguration(profileOwned)
    }

     
     
     
     
    func providerDefinitionsDraft(for profile: Profile) throws -> ProfileProviderDefinitionsDraft {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == profile.id }) else {
            throw ProfileProviderDefinitionError.profileChanged
        }
        let baseline = try providerDefinitionsBaseline(for: latest)
        return try ProfileProviderDefinitionsDraft(
            profile: latest,
            baselineYAML: baseline
        )
    }

     
     
     
     
     
    func providerDefinitionsDraftAsync(
        for profile: Profile
    ) async throws -> ProfileProviderDefinitionsDraft {
        guard let latest = profiles.first(where: { $0.id == profile.id }),
              let raw = runtimeSourceYAML(for: latest) else {
            throw ProfileResourceSummaryError.sourceUnavailable
        }
        return try await Self.providerDraft(profile: latest, raw: raw)
    }

    struct ProviderDraftKey: Equatable {
        let profile: Profile
        let raw: String
    }

     
     
     
     
     
     
    @MainActor
    static let lastProviderDraft = HakoLastPreparation<
        ProviderDraftKey, Result<ProfileProviderDefinitionsDraft, ProfileProviderDefinitionError>
    >()

    @MainActor
    static func prewarmProviderDraft(profile: Profile, raw: String) async {
        _ = try? await providerDraft(profile: profile, raw: raw)
    }

    @MainActor
    static func providerDraft(
        profile latest: Profile, raw: String
    ) async throws -> ProfileProviderDefinitionsDraft {
        let key = ProviderDraftKey(profile: latest, raw: raw)
        let outcome = await lastProviderDraft.value(for: key) {
            let began = DispatchTime.now().uptimeNanoseconds
            let made: Result<ProfileProviderDefinitionsDraft, ProfileProviderDefinitionError> =
                await Task.detached(priority: .userInitiated) {
                    do {
                        let baseline = try ProfileRuntimeConfigBuilder.buildProduction(
                            raw: raw,
                            profile: latest,
                            applyProviderDefinitions: false
                        )
                        return .success(
                            try ProfileProviderDefinitionsDraft(
                                profile: latest,
                                baselineYAML: baseline
                            )
                        )
                    } catch {
                        return .failure(.invalidConfiguration)
                    }
                }.value
            HakoPerf.span(
                "providers.draft.prepare",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail: "yamlBytes=\(raw.utf8.count)"
            )
            return made
        }
        return try outcome.get()
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func updateCustomNodePayload(
        _ definitionJSON: String?, for profileID: String
    ) throws {
        guard let profileStore,
              let latest = profileStore.load().first(where: { $0.id == profileID })
        else { throw ProfileProviderDefinitionError.profileChanged }

        var spec = latest.providerDefinitions ?? ProfileProviderDefinitionSpec()
        let name = CustomNodePayload.providerName
        if let json = definitionJSON {
            if let at = spec.proxyProviders.firstIndex(where: { $0.name == name }) {
                spec.proxyProviders[at].definitionJSON = json
            } else {
                spec.proxyProviders.append(
                    ProfileProviderDefinitionMutation(name: name, definitionJSON: json)
                )
            }
        } else {
            spec.proxyProviders.removeAll { $0.name == name }
        }

        var updated = latest
        updated.providerDefinitions = spec.isEmpty ? nil : spec

         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        let began = DispatchTime.now().uptimeNanoseconds
        defer {
            HakoPerf.span(
                "save.customNodePayload",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail: "providers=\(spec.proxyProviders.count)"
            )
        }
         
         
         
         
        try updateConfiguration(updated, stagesToCore: false)
    }

    func updateProviderDefinitions(_ draft: ProfileProviderDefinitionsDraft) throws {
        guard let profileStore, let workingDir,
              let latest = profileStore.load().first(where: { $0.id == draft.profileID }) else {
            throw ProfileProviderDefinitionError.profileChanged
        }
        let baseline = try providerDefinitionsBaseline(for: latest)
        var updated = try draft.applying(
            to: latest,
            currentBaselineYAML: baseline
        )
        guard let raw = runtimeSourceYAML(for: latest) else {
            throw ProfileResourceSummaryError.sourceUnavailable
        }
        let previousResources = externalResourceData(for: latest)

        do {
            let generated = try ProfileRuntimeConfigBuilder.buildProduction(
                raw: raw,
                profile: updated
            )
            let json = try ConfigTransforms.yamlToJSON(generated)
            guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                    as? [String: Any] else {
                throw ProfileProviderDefinitionError.invalidConfiguration
            }
            try replaceProviderResources(
                draft: draft,
                latest: latest,
                updated: &updated,
                runtimeRoot: root,
                previousResources: previousResources,
                workingDir: workingDir
            )
            try updateConfiguration(updated)
        } catch let bounded as ProfileProviderDefinitionError {
            try? ProfileExternalResourceStore.replace(
                previousResources,
                profileID: latest.id,
                coreHomeDir: workingDir
            )
            throw bounded
        } catch {
            try? ProfileExternalResourceStore.replace(
                previousResources,
                profileID: latest.id,
                coreHomeDir: workingDir
            )
             
             
             
             
             
             
             
             
             
             
             
             
             
            throw ProfileProviderDefinitionError.buildRefused(
                error.localizedDescription
            )
        }
    }

    private func replaceProviderResources(
        draft: ProfileProviderDefinitionsDraft,
        latest: Profile,
        updated: inout Profile,
        runtimeRoot root: [String: Any],
        previousResources: [String: Data],
        workingDir: URL
    ) throws {
        let providerCapabilityPrefixes = ["proxy-provider.", "rule-provider."]
        var references = (latest.externalResources ?? []).filter { reference in
            !providerCapabilityPrefixes.contains(where: reference.capabilityID.hasPrefix)
        }
        var resources: [String: Data] = [:]
        for reference in references {
            guard let data = previousResources[reference.storageKey] else {
                throw ProfileExternalResourceError.storedResourceMissing(
                    field: reference.fieldPath.joined(separator: ".")
                )
            }
            resources[reference.storageKey] = data
        }

        let requirements = IOSExternalResourceCatalog.requirements(root: root).filter {
            $0.capability.section == .proxyProvider
                || $0.capability.section == .ruleProvider
        }
        for requirement in requirements {
            let kind: ProfileProviderKind = requirement.capability.section == .proxyProvider
                ? .proxy : .rule
            let reference = ProfileExternalResourceImporter.reference(
                profileID: latest.id,
                requirement: requirement
            )
            let data: Data
            if let selected = draft.managedFile(for: requirement.proxyName, kind: kind) {
                let selectedName = selected.fileName.lowercased()
                let requiredName = requirement.rawValue
                    .replacingOccurrences(of: "\\", with: "/")
                    .split(separator: "/")
                    .last
                    .map(String.init)?.lowercased() ?? ""
                guard selectedName == requiredName else {
                    throw ProfileProviderDefinitionError.missingManagedFile
                }
                data = selected.data
            } else if (latest.externalResources ?? []).contains(reference),
                      let existing = previousResources[reference.storageKey] {
                data = existing
            } else {
                throw ProfileProviderDefinitionError.missingManagedFile
            }
            references.append(reference)
            resources[reference.storageKey] = data
        }
        updated.externalResources = references.isEmpty
            ? nil : Array(Set(references)).sorted { $0.storageKey < $1.storageKey }

        try ProfileExternalResourceStore.replace(
            resources,
            profileID: latest.id,
            coreHomeDir: workingDir
        )
    }

    private func providerDefinitionsBaseline(for profile: Profile) throws -> String {
        guard let raw = runtimeSourceYAML(for: profile) else {
            throw ProfileResourceSummaryError.sourceUnavailable
        }
        do {
            return try ProfileRuntimeConfigBuilder.buildProduction(
                raw: raw,
                profile: profile,
                applyProviderDefinitions: false
            )
        } catch {
             
             
             
             
             
            throw ProfileProviderDefinitionError.buildRefused(
                error.localizedDescription
            )
        }
    }

     
     
     
     
     
    private func updateGlobalConfiguration(
        _ candidate: Profile,
        replacing keys: Set<String>,
        configureSpec: ((inout OverrideSpec) -> Void)? = nil,
        runtimeAlreadyCarriesChange: Bool = false
    ) throws {
        guard let profileStore else {
            throw PipelineError.sourceUnavailable(
                "the shared profile store is unavailable"
            )
        }
        let previousProfiles = profileStore.load()
        guard let candidateIndex = previousProfiles.firstIndex(
            where: { $0.id == candidate.id }
        ) else {
            throw PipelineError.sourceUnavailable(
                "the profile is no longer available"
            )
        }

        let previousRuntime = FlClashRuntimeConfig.load(
            from: runtimeDefaults
        )
        var updatedRuntime = FlClashRuntimeConfig.replacingGlobalFields(
            in: previousRuntime,
            with: candidate.override.patchJSON,
            keys: keys
        )
        configureSpec?(&updatedRuntime)
        let sanitizedCandidate = FlClashRuntimeConfig.sanitizedProfile(
            candidate
        )
        var updatedProfiles = previousProfiles
        updatedProfiles[candidateIndex] = sanitizedCandidate

        var validationIDs: Set<String> = [candidate.id]
        if let activeProfileID {
            validationIDs.insert(activeProfileID)
        }
        for profile in updatedProfiles where validationIDs.contains(
            profile.id
        ) {
            guard let rawYAML = runtimeSourceYAML(for: profile) else {
                continue
            }
            let preview = try ProfileRuntimeConfigBuilder.runtimePreview(
                raw: rawYAML,
                profile: profile,
                runtimeOverride: updatedRuntime
            )
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            if let container {
                do {
                    try coreAcceptsDocument(preview, container)
                } catch let refusal where Self.refusalBelongsToActivation(
                    refusal.localizedDescription
                ) {
                     
                }
            }
        }

        do {
            try profileStore.save(updatedProfiles)
            FlClashRuntimeConfig.save(
                updatedRuntime,
                in: runtimeDefaults
            )
            guard FlClashRuntimeConfig.load(
                from: runtimeDefaults
            ) == updatedRuntime else {
                throw PipelineError.preflightFailed(
                    "the app-wide runtime preference could not be persisted"
                )
            }
        } catch {
            try? profileStore.save(previousProfiles)
            FlClashRuntimeConfig.save(
                previousRuntime,
                in: runtimeDefaults
            )
            recordFailure(
                error,
                context: .activation,
                operation: .activation(candidate.id),
                preservesLastKnownGood: true
            )
            throw error
        }

        statusMessage = "Runtime settings saved for all profiles"
        clearFailure()
        load()

        guard let activeProfileID,
              let active = updatedProfiles.first(
                  where: { $0.id == activeProfileID }
              ) else {
            return
        }
        switch ProfileSettingsRestagePolicy.action(
            profileID: active.id,
            activeProfileID: activeProfileID,
            vpnStatus: vpn.status,
            runtimeAlreadyCarriesChange: runtimeAlreadyCarriesChange
        ) {
        case .persistOnly:
            break
        case .restageOnly:
            startActivation(
                active,
                applyToTunnel: false,
                preferCachedSource: true,
                because: HakoPerf.Reason.globalConfiguration
            )
        case .restageAndApply:
            startActivation(
                active,
                applyToTunnel: true,
                preferCachedSource: true
            )
        }
    }

     
     
     
    private func updateConfiguration(
        _ profile: Profile,
        stagesToCore: Bool = true,
        caller: StaticString = #function
    ) throws {
        let funnelBegan = DispatchTime.now().uptimeNanoseconds
        defer {
            HakoPerf.span(
                "save.updateConfiguration",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - funnelBegan
                ) / 1_000_000,
                detail: "profile=\(profile.id)"
            )
        }
        guard let profileStore else {
            throw PipelineError.sourceUnavailable("the shared profile store is unavailable")
        }
        let action = ProfileSettingsRestagePolicy.action(
            profileID: profile.id,
            activeProfileID: activeProfileID,
            vpnStatus: vpn.status
        )
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         

        do {
            try profileStore.upsert(profile)
            statusMessage = .format("%@ saved", [profile.label])
            clearFailure()
            load()
             
             
             
             
             
             
             
             
             
             
             
            switch stagesToCore ? action : .persistOnly {
            case .persistOnly:
                break
            case .restageOnly:
                HakoPerf.note("stage.requested from=\(caller)")
                scheduleRestage(profile, applyToTunnel: false)
            case .restageAndApply:
                HakoPerf.note("stage.requested from=\(caller)")
                scheduleRestage(profile, applyToTunnel: true)
            }
        } catch {
            recordFailure(
                error,
                context: .activation,
                operation: .activation(profile.id),
                preservesLastKnownGood: true
            )
            throw error
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func updateEdited(
        _ profile: Profile,
        sourceYAML: String?,
        resourceFiles: [ExternalResourceImportFile] = [],
        disablingAutoUpdate: Bool = false
    ) async throws {
        guard let profileStore, let workingDir else { return }
        let previous = profileStore.load().first(where: { $0.id == profile.id }) ?? profile
        let previousSource = sidecarYAML(for: previous)
        let previousResources = externalResourceData(for: previous)
        var updated = ProfileMetadataUpdate.normalizingSourceChange(
            previous: previous, updated: profile
        )
        if let sourceYAML {
             
             
             
             
             
             
             
            let hydrated = sourceYAML
            let resourceSource = externalResourceSource(previous.source)
            let containerForCore = container
            let coreGate = coreAcceptsDocument
            let committed = updated
            let prepared = try await Task
                .detached(priority: .userInitiated) {
                     
                     
                     
                     
                     
                     
                     
                     
                    try ConfigTransforms.validateSource(hydrated)
                    if let container = containerForCore {
                        do {
                            try coreGate(hydrated, container)
                        } catch let refusal where Self.refusalBelongsToActivation(
                            refusal.localizedDescription
                        ) {
                             
                             
                             
                             
                             
                             
                        }
                    }
                    let prepared = try ProfileExternalResourceImporter.prepare(
                        yaml: hydrated,
                        profileID: previous.id,
                        source: resourceSource,
                        files: resourceFiles,
                        existingReferences: previous.externalResources ?? [],
                        existingPublicResources: previousResources
                    )
                     
                     
                     
                     
                    _ = try ProfileRuntimeConfigBuilder.runtimePreview(
                        raw: prepared.yaml,
                        profile: committed
                    )
                    return prepared
                }.value
            do {
                try ProfileExternalResourceStore.replace(
                    prepared.publicResources,
                    profileID: previous.id,
                    coreHomeDir: workingDir
                )
                updated.externalResources = prepared.references.isEmpty
                    ? nil : prepared.references
                updated.usesLocalSourceOverride = true
                if disablingAutoUpdate, case .url = updated.source {
                    updated.autoUpdate = false
                }
                 
                 
                 
                 
                 
                 
                 
                try profileStore.upsert(updated)
                 
                try cacheSourceYAML(prepared.yaml, for: updated)
            } catch {
                try? profileStore.upsert(previous)
                try? ProfileExternalResourceStore.replace(
                    previousResources,
                    profileID: previous.id,
                    coreHomeDir: workingDir
                )
                restoreSourceYAML(previousSource, for: previous)
                throw error
            }
        } else {
            try profileStore.upsert(updated)
        }
        load()
         
         
         
         
        if updated.id == activeProfileID {
            let republished = updated
            Task { _ = await selectAndWait(republished, force: true) }
        }
        if ProfileMetadataUpdate.shouldResyncAfterSourceChange(
            previous: previous, updated: updated
        ) {
            sync(profiles.first(where: { $0.id == updated.id }) ?? updated)
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func baseYAML(for profile: Profile) -> String? {
        let key = projectionKey(for: profile)
        if let cached = baseYAMLCache[profile.id], cached.key == key {
            return cached.value
        }
        let value = RunningCoreDeviations.baseDocument(
            profile: profile,
            sidecarYAML: sourceYAML(for: profile)
        ) ?? uiProjectedYAML(for: profile)
        baseYAMLCache[profile.id] = (key, value)
        return value
    }

     
     
     
    func cachedUIProjectedYAML(for profile: Profile) -> String? {
        let key = projectionKey(for: profile)
        if let cached = projectedYAMLCache[profile.id], cached.key == key {
            return cached.value
        }
        return nil
    }

     
     
     
     
    func uiProjectionInputs(for profile: Profile) -> (key: String, sourceYAML: String?) {
        (projectionKey(for: profile), sourceYAML(for: profile))
    }

     
     
    func rememberUIProjectedYAML(_ value: String?, key: String, for profile: Profile) {
        projectedYAMLCache[profile.id] = (key, value)
    }

    func uiProjectedYAML(for profile: Profile) -> String? {
        let key = projectionKey(for: profile)
        if let cached = projectedYAMLCache[profile.id], cached.key == key {
            return cached.value
        }
        let value = CustomNodesGroupMaterializer.projectForUI(
            sourceYAML: sourceYAML(for: profile),
            profile: profile
        )
        projectedYAMLCache[profile.id] = (key, value)
        return value
    }

     
     
     
     
     
     
     
     
     
     
     
    func effectiveYAML(for profile: Profile) -> String? {
        let key = effectiveYAMLKey(for: profile)
        if let cached = effectiveYAMLCache[profile.id], cached.key == key {
            return cached.value
        }
        let value = previewText(for: profile)
        effectiveYAMLCache[profile.id] = (key, value)
        return value
    }

    private func effectiveYAMLKey(for profile: Profile) -> String {
        var parts = [projectionKey(for: profile)]
         
         
         
        if let encoded = try? JSONEncoder().encode(FlClashRuntimeConfig.load()) {
            parts.append("\(encoded.hashValue)")
        }
        parts.append(profile.postMergeScriptID ?? "-")
        parts.append(ScriptSettings.enabled() ? "script" : "-")
        return parts.joined(separator: "|")
    }

    private func projectionKey(for profile: Profile) -> String {
        var parts: [String] = [profile.id]
        if let workingDir {
            let sidecar = workingDir
                .appendingPathComponent("store/\(profile.id)/source.yaml")
            let attributes = try? FileManager.default
                .attributesOfItem(atPath: sidecar.path)
            let size = (attributes?[.size] as? NSNumber)?.intValue ?? -1
            let modified = (attributes?[.modificationDate] as? Date)?
                .timeIntervalSince1970 ?? -1
            parts.append("\(size)|\(modified)")
             
             
             
            parts.append(profile.activeRevision ?? "-")
        }
        parts.append(profile.lastUpdatedAt.map { "\($0.timeIntervalSince1970)" } ?? "-")
        parts.append(profile.override.patchJSON ?? "-")
        if let definitions = profile.providerDefinitions,
           let encoded = try? JSONEncoder().encode(definitions) {
            parts.append("\(encoded.hashValue)")
        }
         
         
         
         
         
        parts.append(profile.sourceCredentialsRedacted == true ? "1" : "0")
        let references = (profile.sourceCredentials ?? [])
            + (profile.proxyCredentials ?? [])
        if !references.isEmpty,
           let encoded = try? JSONEncoder().encode(references) {
            parts.append("\(encoded.hashValue)")
             
             
             
             
            if profile.sourceCredentialsRedacted == true {
                parts.append("\(credentialFingerprint(for: references))")
            }
        }
         
         
         
        if let overrides = profile.proxyNodeOverrides,
           let encoded = try? JSONEncoder.sortedKeys.encode(overrides) {
            parts.append("o:\(encoded.count)|\(encoded.hashValue)")
        }
        if let chain = profile.proxyChain,
           let encoded = try? JSONEncoder.sortedKeys.encode(chain) {
            parts.append("c:\(encoded.count)|\(encoded.hashValue)")
        }
        return parts.joined(separator: "\u{1}")
    }

     
     
     
     
     
    private func credentialFingerprint(
        for references: [ProxyCredentialReference]
    ) -> Int {
        var hasher = Hasher()
        for key in references.map(\.key).sorted() {
            hasher.combine(key)
            hasher.combine(credentials.get(key) ?? Data())
        }
        return hasher.finalize()
    }

    func move(from source: IndexSet, to destination: Int) {
        guard let profileStore else { return }
        profiles = ProfileReorder.apply(profiles, from: source, to: destination)
        try? profileStore.save(profiles)
        load()
    }

     
    private var tunnelIsRunning: Bool {
        vpn.status == "connected" || vpn.status == "reasserting"
    }

     
     
     
    func sync(_ profile: Profile) {
        if profile.id == activeProfileID {
             
             
             
             
             
             
            startActivation(profile, applyToTunnel: tunnelIsRunning, because: HakoPerf.Reason.profileSync)
            return
        }
        guard case .url = profile.source else { return }
        clearFailure()
        statusMessage = .format("Syncing %@…", [profile.label])
        Task { [weak self] in
            guard let self else { return }
            let subscriptions = SubscriptionManager(
                downloader: ResourceDownloader(), credentials: self.credentials)
            do {
                guard let profileStore = self.profileStore,
                      let workingDir = self.workingDir else {
                    throw PipelineError.sourceUnavailable(
                        "the shared profile store is unavailable"
                    )
                }
                let result = try await SubscriptionSourceRefresher.refresh(
                    profile: profile,
                    manager: subscriptions,
                    profileStore: profileStore,
                    credentials: self.credentials,
                    workingDirectory: workingDir
                )
                self.load()
                let heldBack = self.profiles.first(where: { $0.id == profile.id })?.suppressedUpdates?.count ?? 0
                self.statusMessage = result == .unchanged
                    ? .format("%@ is up to date", [profile.label])
                    : heldBack > 0
                        ? .format("%@ synced · %@ change(s) held back by your settings", [profile.label, String(heldBack)])
                        : .format("%@ synced", [profile.label])
                self.clearFailure()
            } catch {
                self.recordFailure(
                    error,
                    context: .subscription,
                    operation: .sync(profile.id)
                )
            }
        }
    }

     
     
     
     
     
     
    static func subscriptionProfiles(in profiles: [Profile]) -> [Profile] {
        profiles.filter {
            if case .url = $0.source { return true }
            return false
        }
    }

     
    var hasSubscriptionProfile: Bool {
        !Self.subscriptionProfiles(in: profiles).isEmpty
    }

     
     
    var isSyncingAll: Bool { batchTask != nil }

    func syncAll() {
        guard batchTask == nil else { return }
        let candidates = Self.subscriptionProfiles(in: profiles)
        batchReport = BatchUpdateReport(
            title: "Profile Sync",
            expectedCount: candidates.count
        )
        guard !candidates.isEmpty else { return }
        isBatchSyncing = true
        clearFailure()
        let runID = UUID()
        batchRunID = runID
        batchTask = Task { [weak self] in
            guard let self else { return }
            for profile in candidates {
                guard self.batchRunID == runID else { return }
                if Task.isCancelled {
                    self.markBatchCancelled()
                    break
                }
                self.busyProfileID = profile.id
                self.statusMessage = .format("Syncing %@…", [profile.label])
                do {
                     
                     
                     
                     
                     
                    let state = try await withThrowingTaskGroup(
                        of: BatchUpdateState.self
                    ) { group in
                        group.addTask { try await self.performBatchSync(profile) }
                        group.addTask {
                            try await Task.sleep(
                                nanoseconds: UInt64(Self.batchItemLimit * 1_000_000_000)
                            )
                            throw URLError(.timedOut)
                        }
                        defer { group.cancelAll() }
                        guard let first = try await group.next() else {
                            throw URLError(.timedOut)
                        }
                        return first
                    }
                    guard self.batchRunID == runID else { return }
                    self.recordBatchItem(
                        id: profile.id,
                        label: profile.label,
                        state: state,
                        message: state == .unchanged
                            ? "Already up to date."
                            : "The validated source was saved."
                    )
                } catch is CancellationError {
                    guard self.batchRunID == runID else { return }
                    self.markBatchCancelled()
                    break
                } catch {
                    guard self.batchRunID == runID else { return }
                    self.recordBatchFailure(error, profile: profile)
                }
                self.busyProfileID = nil
                self.load()
            }
            guard self.batchRunID == runID else { return }
            self.busyProfileID = nil
            self.isBatchSyncing = false
            self.batchRunID = nil
            self.batchTask = nil
            self.load()
            if let report = self.batchReport {
                 
                 
                 
                 
                 
                self.statusMessage = report.wasCancelled
                    ? "Profile sync cancelled"
                    : "Profile sync finished"
            }
        }
    }

    func cancelBatchSync() {
        guard let task = batchTask else { return }
         
         
         
         
         
         
        batchRunID = nil
        batchTask = nil
        task.cancel()
        busyProfileID = nil
        isBatchSyncing = false
        markBatchCancelled()
        statusMessage = "Profile sync cancelled"
    }

    func dismissBatchReport() {
         
         
         
         
        if isBatchSyncing {
            cancelBatchSync()
        }
        batchReport = nil
    }

    func retryBatchItem(id: String) {
        guard batchTask == nil,
              let profile = profiles.first(where: { $0.id == id }) else { return }
        isBatchSyncing = true
        let runID = UUID()
        batchRunID = runID
        batchTask = Task { [weak self] in
            guard let self else { return }
            self.busyProfileID = profile.id
            do {
                let state = try await self.performBatchSync(profile)
                guard self.batchRunID == runID else { return }
                self.recordBatchItem(
                    id: profile.id,
                    label: profile.label,
                    state: state,
                    message: state == .unchanged
                        ? "Already up to date."
                        : "The validated source was saved."
                )
            } catch is CancellationError {
                guard self.batchRunID == runID else { return }
                self.markBatchCancelled()
            } catch {
                guard self.batchRunID == runID else { return }
                self.recordBatchFailure(error, profile: profile)
            }
            guard self.batchRunID == runID else { return }
            self.busyProfileID = nil
            self.isBatchSyncing = false
            self.batchRunID = nil
            self.batchTask = nil
            self.load()
            self.drainPendingActivation()
        }
    }

     
     
     
     
     
     
     
     
     
     
    private func performBatchSync(_ profile: Profile) async throws -> BatchUpdateState {
        try Task.checkCancellation()

        let subscriptions = SubscriptionManager(
            downloader: ResourceDownloader(),
            credentials: credentials
        )
        guard let profileStore, let workingDir else {
            throw PipelineError.sourceUnavailable("the shared profile store is unavailable")
        }
        let result = try await SubscriptionSourceRefresher.refresh(
            profile: profile,
            manager: subscriptions,
            profileStore: profileStore,
            credentials: credentials,
            workingDirectory: workingDir
        )
        let state: BatchUpdateState = result == .unchanged ? .unchanged : .updated

        if state == .updated, profile.id == activeProfileID, tunnelIsRunning {
            try await republishToRunningTunnel(profile)
        }
        return state
    }

     
     
     
     
     
     
    private func republishToRunningTunnel(_ profile: Profile) async throws {
        guard let container,
              let store = try? ConfigResourceStore(containerURL: container) else {
            throw PipelineError.sourceUnavailable(
                "the shared configuration store is unavailable"
            )
        }
        let coordinator = vpn.activationCoordinator(store: store, container: container)
        _ = try await coordinator.activate(
            profile: profile,
            sourceYAML: try storedSourceYAML(for: profile)
        )
        guard let activeYAML = try store.loadCurrent().text else { return }
         
         
         
         
        let preflight = await Task.detached(priority: .userInitiated) { () -> ([String], PreflightOutcome) in
            (
                (try? ConfigTransforms.planResources(mergedYAML: activeYAML).notices) ?? [],
                PreflightService.check(finalYAML: activeYAML)
            )
        }.value
        notices = preflight.0
        let outcome = preflight.1
        if let intentJSON = outcome.intentJSON,
           let intent = try? JSONDecoder().decode(
            PlatformConfigIntent.self,
            from: Data(intentJSON.utf8)
           ) {
            await vpn.applyActiveConfiguration(nextIntent: intent)
        }
    }

    private func recordBatchFailure(_ error: Error, profile: Profile) {
        let context: ConfigurationFailureContext = profile.id == activeProfileID
            ? .activation : .subscription
        guard let failure = ConfigurationFailureClassifier.classify(
            error,
            context: context,
            preservesLastKnownGood: true
        ) else { return }
        recordBatchItem(
            id: profile.id,
            label: profile.label,
            state: .failed,
            message: failure.message,
            failure: failure
        )
    }

    private func recordBatchItem(
        id: String,
        label: String,
        state: BatchUpdateState,
        message: String?,
        failure: ConfigurationFailure? = nil
    ) {
        guard var report = batchReport else { return }
        report.wasCancelled = false
        report.record(BatchUpdateItem(
            id: id,
            label: label,
            state: state,
            message: message,
            failure: failure
        ))
        batchReport = report
    }

    private func markBatchCancelled() {
        guard var report = batchReport else { return }
        report.wasCancelled = true
        batchReport = report
    }

    func previewText(for profile: Profile) -> String? {
         
         
         
         
         
        if let container,
           let revision = profile.activeRevision,
           let loaded = try? ConfigResourceStore(containerURL: container)
               .loadConfiguration(profileID: profile.id, revision: revision) {
            return loaded.text
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        guard let source = try? hydratedSourceYAML(for: profile) else {
            return sidecarYAML(for: profile)
        }
         
         
        return (try? ProfileRuntimeConfigBuilder.buildProduction(
            raw: source,
            profile: profile
        )) ?? source
    }

     
     
     
     
     
     
     
    func loadCachedPreviewText(for profileID: String) async -> String? {
        guard let profile = profiles.first(where: { $0.id == profileID }) else { return nil }
        return previewText(for: profile)
    }

     
     
    func loadCachedExportDocument(for profileID: String) async -> (String, String)? {
        guard let profile = profiles.first(where: { $0.id == profileID }) else { return nil }
        guard let text = capturedSourceText(for: profile) else { return nil }
        let name = profile.label.isEmpty ? "profile" : profile.label
        return ("\(name).yaml", text)
    }

     
     
    func exportDocument(for profile: Profile) -> (String, String)? {
        let name = profile.label.isEmpty ? "profile" : profile.label
        if let captured = capturedSourceText(for: profile) {
            return ("\(name).yaml", captured)
        }
        guard let text = previewText(for: profile) else { return nil }
        return ("\(name).yaml", text)
    }

    func subscriptionLink(for profile: Profile) -> String? {
        if case .url(let url) = profile.source { return url }
        return nil
    }

     
     
     
     
    private func forgetCachedSource(_ id: String? = nil) {
        if let id { sourceYAMLCache[id] = nil } else { sourceYAMLCache.removeAll() }
    }

    private func sidecarURL(for profile: Profile) -> URL? {
        workingDir?.appendingPathComponent("store/\(profile.id)/source.yaml")
    }

     
     
    func sourceLocation(for profile: Profile) -> URL? { sidecarURL(for: profile) }

     
     
    func loadSourceYAML(for profile: Profile) async -> String? {
        if let cached = sourceYAMLCache[profile.id] { return cached }
        guard let url = sidecarURL(for: profile) else { return sourceYAML(for: profile) }
        let value = await Task.detached(priority: .userInitiated) {
            try? String(contentsOf: url, encoding: .utf8)
        }.value
        sourceYAMLCache[profile.id] = value
        return value
    }

    func sourceYAML(for profile: Profile) -> String? {
         
         
         
         
        if let cached = sourceYAMLCache[profile.id] { return cached }
        let value = (try? hydratedSourceYAML(for: profile)) ?? sidecarYAML(for: profile)
        sourceYAMLCache[profile.id] = value
        return value
    }

     
     
     
     
     
     
     
     
     
     
    func capturedSourceText(for profile: Profile) -> String? {
        guard let workingDir else { return sourceYAML(for: profile) }
        return ProfileSourceStore.capturedText(
            workingDirectory: workingDir, profileID: profile.id
        ) ?? sourceYAML(for: profile)
    }

     
     
    func hasEditableSource(for profile: Profile) -> Bool {
        guard let workingDir else { return false }
        let sidecar = workingDir.appendingPathComponent("store/\(profile.id)/source.yaml")
        return FileManager.default.fileExists(atPath: sidecar.path)
    }

    func runtimeSourceYAML(for profile: Profile) -> String? {
        sidecarYAML(for: profile)
    }

     
     
     
     
     
     
     
    func udpFallbackGuardInput(for profile: Profile) async -> ConfigTransforms.UDPFallbackGuardInput? {
        guard let raw = runtimeSourceYAML(for: profile) else { return nil }
        return await Task.detached(priority: .userInitiated) {
            try? ProfileRuntimeConfigBuilder.udpFallbackGuardInput(raw: raw, profile: profile)
        }.value
    }

     
     
     
     
    private func sidecarYAML(for profile: Profile) -> String? {
        guard let workingDir else { return nil }
        let sidecar = workingDir.appendingPathComponent("store/\(profile.id)/source.yaml")
        return try? String(contentsOf: sidecar, encoding: .utf8)
    }

    private func cacheSourceYAML(_ yaml: String, for profile: Profile) throws {
        forgetCachedSource(profile.id)
        guard let workingDir else { throw PipelineError.sourceUnavailable(profile.label) }
        try sourceWriter(yaml, profile, workingDir)
    }

     
     
     
     
     
     
    private static func writeSourceYAML(
        _ yaml: String,
        _ profile: Profile,
        _ workingDir: URL
    ) throws {
        let sidecar = workingDir.appendingPathComponent("store/\(profile.id)/source.yaml")
        try FileManager.default.createDirectory(
            at: sidecar.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(yaml.utf8).write(
            to: sidecar,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

    private func restoreSourceYAML(_ yaml: String?, for profile: Profile) {
        guard let workingDir else { return }
        let sidecar = workingDir.appendingPathComponent("store/\(profile.id)/source.yaml")
        if let yaml {
            try? Self.writeSourceYAML(yaml, profile, workingDir)
        } else {
            try? FileManager.default.removeItem(at: sidecar)
        }
    }

    private func externalResourceData(for profile: Profile) -> [String: Data] {
        guard let workingDir else { return [:] }
        return Self.externalResourceData(for: profile, workingDir: workingDir)
    }

     
     
    nonisolated private static func externalResourceData(
        for profile: Profile,
        workingDir: URL
    ) -> [String: Data] {
        Dictionary(uniqueKeysWithValues: (profile.externalResources ?? []).compactMap { reference in
            let url = workingDir.appendingPathComponent(
                "store/\(profile.id)/resources/\(reference.storageKey)"
            )
            return (try? Data(contentsOf: url)).map { (reference.storageKey, $0) }
        })
    }

     
    nonisolated private static func sidecarYAML(for profile: Profile, workingDir: URL) -> String? {
        let sidecar = workingDir.appendingPathComponent("store/\(profile.id)/source.yaml")
        return try? String(contentsOf: sidecar, encoding: .utf8)
    }

    private func hydratedSourceYAML(for profile: Profile) throws -> String {
        guard let yaml = sidecarYAML(for: profile) else {
            throw PipelineError.sourceUnavailable(
                "the saved source for this profile is unavailable"
            )
        }
         
        return yaml
    }

     
     
    nonisolated private static func duplicateResourceFiles(
        sourceYAML: String,
        profile: Profile,
        dataByKey: [String: Data]
    ) throws -> [ExternalResourceImportFile] {
        let json = try ConfigTransforms.yamlToJSON(sourceYAML)
        guard let root = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw ProfileExternalResourceError.invalidConfiguration
        }
        var filesByName: [String: Data] = [:]
        for requirement in IOSExternalResourceCatalog.requirements(root: root)
            where requirement.capability.confidentiality == .publicData {
            let sourceDigest = ProfileExternalResourceImporter.sha256(
                Data(requirement.rawValue.utf8)
            )
            guard let reference = (profile.externalResources ?? []).first(where: {
                $0.capabilityID == requirement.capability.id
                    && $0.proxy == requirement.proxyName
                    && $0.fieldPath == requirement.capability.fieldPath
                    && $0.sourceValueSHA256 == sourceDigest
            }), let data = dataByKey[reference.storageKey] else {
                throw ProfileExternalResourceError.storedResourceMissing(
                    field: requirement.capability.fieldPath.joined(separator: ".")
                )
            }
            let fileName = requirement.rawValue
                .replacingOccurrences(of: "\\", with: "/")
                .split(separator: "/")
                .last
                .map(String.init) ?? requirement.rawValue
            if let previous = filesByName[fileName.lowercased()], previous != data {
                throw ProfileExternalResourceError.ambiguousSelection(
                    field: requirement.capability.fieldPath.joined(separator: ".")
                )
            }
            filesByName[fileName.lowercased()] = data
        }
        return filesByName.keys.sorted().compactMap { name in
            filesByName[name].map { ExternalResourceImportFile(fileName: name, data: $0) }
        }
    }

    private func uniqueCopyLabel(base: String, suffix: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let root = (trimmed.isEmpty ? "Profile" : trimmed) + suffix
        let existing = Set(profiles.map { $0.label.localizedLowercase })
        if !existing.contains(root.localizedLowercase) { return root }
        var index = 2
        while existing.contains("\(root) \(index)".localizedLowercase) { index += 1 }
        return "\(root) \(index)"
    }

    private func safeProfileFileName(_ label: String) -> String {
        let unsafe = CharacterSet(charactersIn: "/\\:")
        let sanitized = label.components(separatedBy: unsafe).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = String((sanitized.isEmpty ? "Profile" : sanitized).prefix(80))
        return "\(stem).yaml"
    }

    private func externalResourceSource(_ source: Profile.Source) -> IOSExternalResourceSource {
        switch source {
        case .url: return .subscription
        case .file: return .localFile
        case .clipboard: return .clipboard
        }
    }

     

     
     
     
     
     
     
     
    func startActivation(
        _ profile: Profile,
        applyToTunnel: Bool = true,
        preferCachedSource: Bool = false,
        because reason: String = "unspecified"
    ) {
         
         
         
        HakoPerf.note(
            "activation.requested by=\(reason) applyToTunnel=\(applyToTunnel)"
        )


        let request = ActivationRequest(
            profile: profile,
            applyToTunnel: applyToTunnel,
            preferCachedSource: preferCachedSource
        )
        clearFailure()
        guard activationTask == nil else {
             
             
             
            pendingActivation = request
            return
        }
         
         
         
         
         
        guard busyProfileID == nil else {
            pendingActivation = request
            statusMessage = .format(
                "%@ will switch when the current update finishes.",
                [request.profile.label]
            )
            return
        }
        runActivation(request)
    }

    private func runActivation(_ request: ActivationRequest) {
        activationAppliesToTunnel = request.applyToTunnel
        isActivating = true
        activationTask = Task { [weak self] in
            guard let self else { return }
            await self.activate(
                request.profile,
                applyToTunnel: request.applyToTunnel,
                preferCachedSource: request.preferCachedSource
            )
            self.activationTask = nil
            if let pending = self.pendingActivation {
                self.pendingActivation = nil
                 
                 
                 
                self.runActivation(pending)
            } else {
                self.activationAppliesToTunnel = nil
                self.isActivating = false
            }
        }
    }

     
     
     
    private func drainPendingActivation() {
        guard activationTask == nil, busyProfileID == nil,
              let pending = pendingActivation else { return }
        pendingActivation = nil
        runActivation(pending)
    }

    func cancelActivation() {
        pendingActivation = nil
        activationTask?.cancel()
    }

     
     
     
    func waitForPendingActivation() async {
        while let task = activationTask {
            await task.value
        }
    }

    var failureProfile: Profile? {
        guard let failedOperation else { return nil }
        let id: String
        switch failedOperation {
        case .sync(let profileID), .activation(let profileID): id = profileID
        }
        return profiles.first { $0.id == id }
    }

    func retryLastFailure() {
        guard let failedOperation,
              let profile = failureProfile else { return }
        switch failedOperation {
        case .sync:
            sync(profile)
        case .activation:
            startActivation(profile)
        }
    }

    private func activate(
        _ profile: Profile,
        applyToTunnel: Bool,
        preferCachedSource: Bool
    ) async {
        guard let container, busyProfileID == nil else { return }
        busyProfileID = profile.id
        statusMessage = .format("Preparing %@…", [profile.label])
        notices = []
        planErrors = []
        defer { busyProfileID = nil }
        var pipelineSucceeded = false
        do {
            let store = try ConfigResourceStore(containerURL: container)
            let coordinator = vpn.activationCoordinator(store: store, container: container)
            let sourceYAML = try storedSourceYAML(
                for: profile,
                preferCachedSource: preferCachedSource
            )
             
             
             
             
             
             
             
            _ = try await Task.detached(priority: .userInitiated) {
                try await coordinator.activate(
                    profile: profile, sourceYAML: sourceYAML
                )
            }.value

            let activeYAML = try store.loadCurrent().text ?? ""
            statusMessage = .format("%@ staged; applying to tunnel…", [profile.label])
             
            let preflight = await Task.detached(priority: .userInitiated) { () -> ([String], PreflightOutcome) in
                (
                    (try? ConfigTransforms.planResources(mergedYAML: activeYAML).notices) ?? [],
                    PreflightService.check(finalYAML: activeYAML)
                )
            }.value
            notices = preflight.0
            let outcome = preflight.1
            if applyToTunnel,
               let intentJSON = outcome.intentJSON,
               let intent = try? JSONDecoder().decode(PlatformConfigIntent.self,
                                                      from: Data(intentJSON.utf8)) {
                await vpn.applyActiveConfiguration(nextIntent: intent)
            }
            statusMessage = applyToTunnel
                ? .format("%@ is active", [profile.label])
                : .format("%@ saved for the next connection", [profile.label])
            clearFailure()
            pipelineSucceeded = true
        } catch is CancellationError {
            statusMessage = "Update cancelled"
            clearFailure()
        } catch let PipelineError.planRejected(failures) {
            planErrors = failures.map { "\($0.field): \($0.reason)" }
            recordFailure(
                PipelineError.planRejected(failures),
                context: .activation,
                operation: .activation(profile.id)
            )
        } catch {
            recordFailure(
                error,
                context: .activation,
                operation: .activation(profile.id)
            )
        }
        load()
         
         
         
         
         
        if pipelineSucceeded, lastFailure == nil, activeProfileID != profile.id {
            recordFailure(
                PipelineError.activationReadback,
                context: .activation,
                operation: .activation(profile.id)
            )
        }
    }

    private func clearFailure() {
        lastFailure = nil
        failedOperation = nil
        planErrors = []
    }

     
     
     
     
     
     
     
     
    func dismissFailure() {
        clearFailure()
    }

    private func recordFailure(
        _ error: Error,
        context: ConfigurationFailureContext,
        operation: FailedOperation?,
        preservesLastKnownGood: Bool = true
    ) {
        guard let failure = ConfigurationFailureClassifier.classify(
            error,
            context: context,
            preservesLastKnownGood: preservesLastKnownGood
        ) else {
            clearFailure()
            return
        }
        lastFailure = failure
        failedOperation = operation
        statusMessage = .copy(failure.title)
    }

     
     
    private func storedSourceYAML(
        for profile: Profile,
        preferCachedSource: Bool = false
    ) throws -> String? {
        if case .url = profile.source,
           profile.usesLocalSourceOverride != true,
           !preferCachedSource {
            return nil
        }
        guard let workingDir else { throw PipelineError.sourceUnavailable(profile.label) }
        let sidecar = workingDir.appendingPathComponent("store/\(profile.id)/source.yaml")
        if preferCachedSource,
           case .url = profile.source,
           !FileManager.default.fileExists(atPath: sidecar.path) {
             
             
            return nil
        }
        guard let yaml = try? String(contentsOf: sidecar, encoding: .utf8) else {
            if case .url = profile.source {
                 
                 
                 
                return nil
            }
            throw PipelineError.sourceUnavailable(
                "original YAML for '\(profile.label)' is gone; re-add the profile")
        }
        return yaml
    }
}


 
struct ConfigTextDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.yaml, .plainText]

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
