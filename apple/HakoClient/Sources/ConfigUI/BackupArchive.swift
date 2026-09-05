import Foundation

enum BackupRestoreScope: String, CaseIterable, Identifiable {
    case profilesOnly
    case allData

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profilesOnly: return "Profiles only"
        case .allData: return "All data"
        }
    }
}

struct BackupRestoreResult: Equatable {
    let importedProfiles: Int
    let totalProfiles: Int
    let scope: BackupRestoreScope
}

struct BackupRestorePreview: Equatable {
    struct Change: Equatable, Identifiable {
        enum Kind: String, Equatable {
            case added
            case updated
            case unchanged
            case removed

            var title: String { rawValue.capitalized }
        }

        let profileID: String
        let label: String
        let kind: Kind
        var id: String { "\(kind.rawValue):\(profileID)" }
    }

    let changes: [Change]
    let totalProfilesAfterRestore: Int
    let globalConfigChanges: Bool
    let referencedScriptCount: Int
    let omittedRemoteSourceCount: Int
     
     
     
     
    var rebindRequiredProviderCount: Int = 0

    var addedCount: Int { count(.added) }
    var updatedCount: Int { count(.updated) }
    var unchangedCount: Int { count(.unchanged) }
    var removedCount: Int { count(.removed) }

    private func count(_ kind: Change.Kind) -> Int {
        changes.filter { $0.kind == kind }.count
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct BackupArchive: Codable, Equatable {
    static let currentSchemaVersion = 5

    var schemaVersion = BackupArchive.currentSchemaVersion
    var profiles: [Profile]
    var sidecars: [String: String]    
     
     
     
    var publicResources: [String: [String: Data]]
    var globalConfig: OverrideSpec
     
     
    var runtimeConfig: OverrideSpec?
     
     
     
     
    var configurationModelVersion: Int?
     
     
     
    var scripts: [ConfigScript]
     
     
     
    var scriptConfigurationModelVersion: Int?
     
     
    var omittedRemoteSourceCount: Int

    enum BackupError: Error, Equatable {
         
         
        case incompleteProfiles([String])
        case unsupportedSchema(Int)
        case unsupportedConfigurationModel(Int)
        case incompatibleConfigurationModel
        case conflictingConfigurationModel
        case configurationMigrationBlocked(LegacyGlobalConfigMigrationBlocker)
        case unsupportedScriptConfigurationModel(Int)
        case incompatibleScriptConfigurationModel
        case conflictingScriptConfigurationModel
        case missingReferencedScript
        case scriptCollision
        case invalidScript
        case unsafeProfileID(String)
        case rollbackFailed
    }

    init(
        profiles: [Profile],
        sidecars: [String: String],
        publicResources: [String: [String: Data]] = [:],
        globalConfig: OverrideSpec,
        runtimeConfig: OverrideSpec? = nil,
        configurationModelVersion: Int? = nil,
        scripts: [ConfigScript] = [],
        scriptConfigurationModelVersion: Int? = nil,
        omittedRemoteSourceCount: Int = 0
    ) {
        self.profiles = profiles
        self.sidecars = sidecars
        self.publicResources = publicResources
        self.globalConfig = globalConfig
        self.runtimeConfig = runtimeConfig
        self.configurationModelVersion = configurationModelVersion
        self.scripts = scripts
        self.scriptConfigurationModelVersion = scriptConfigurationModelVersion
        self.omittedRemoteSourceCount = omittedRemoteSourceCount
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case profiles
        case sidecars
        case publicResources
        case globalConfig
        case runtimeConfig
        case configurationModelVersion
        case scripts
        case scriptConfigurationModelVersion
        case omittedRemoteSourceCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        profiles = try container.decode([Profile].self, forKey: .profiles)
        sidecars = try container.decode([String: String].self, forKey: .sidecars)
        publicResources = try container.decodeIfPresent(
            [String: [String: Data]].self,
            forKey: .publicResources
        ) ?? [:]
        globalConfig = try container.decode(OverrideSpec.self, forKey: .globalConfig)
        runtimeConfig = try container.decodeIfPresent(
            OverrideSpec.self,
            forKey: .runtimeConfig
        )
        configurationModelVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .configurationModelVersion
        )
        scripts = try container.decodeIfPresent(
            [ConfigScript].self,
            forKey: .scripts
        ) ?? []
        scriptConfigurationModelVersion = try container.decodeIfPresent(
            Int.self,
            forKey: .scriptConfigurationModelVersion
        )
        omittedRemoteSourceCount = try container.decodeIfPresent(
            Int.self,
            forKey: .omittedRemoteSourceCount
        ) ?? 0
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return try encoder.encode(try sanitizedForPortableStorage())
    }

    static func decode(_ data: Data) throws -> BackupArchive {
        let archive = try JSONDecoder().decode(BackupArchive.self, from: data)
        guard archive.schemaVersion <= currentSchemaVersion else {
            throw BackupError.unsupportedSchema(archive.schemaVersion)
        }
        return try archive.sanitizedForPortableStorage()
    }

     

    static func collect(
        workingDir: URL,
        defaults: UserDefaults = GlobalConfig.appGroupDefaults,
        credentials: CredentialStore = CredentialStore()
    ) throws -> BackupArchive {
        let profileStore = ProfileStore(
            fileURL: workingDir.appendingPathComponent("store/profiles.json"))
        var profiles = profileStore.load()
        var sidecars: [String: String] = [:]
        var publicResources: [String: [String: Data]] = [:]
        var incomplete: [String] = []
        for index in profiles.indices where isSafeProfileID(profiles[index].id) {
            let profile = profiles[index]
            let sidecar = workingDir.appendingPathComponent("store/\(profile.id)/source.yaml")
            let storedSource = try? String(contentsOf: sidecar, encoding: .utf8)
            if storedSource == nil, case .url = profile.source {
                 
                 
                 
                 
                incomplete.append(profile.label)
            }
            if let yaml = storedSource {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                sidecars[profile.id] = yaml
            }
             
             
             
             
            profiles[index].providerDefinitionCredentials = nil
            let resources = collectPublicResources(
                profile: profile,
                workingDir: workingDir
            )
            publicResources[profile.id] = resources.data
            profiles[index].externalResources = resources.references.isEmpty
                ? nil : resources.references
        }
        let globalConfig = GlobalConfig.load(from: defaults)
        let completedVersion = LegacyGlobalConfigMigrationMetadata.completedVersion(
            in: defaults
        )
        let scriptVersion = LegacyGlobalScriptMigrationMetadata.completedVersion(
            in: defaults
        )
        if let scriptVersion,
           scriptVersion <= 0
            || scriptVersion > LegacyGlobalScriptMigrationPlan.currentVersion {
            throw BackupError.unsupportedScriptConfigurationModel(scriptVersion)
        }
        if LegacyGlobalScriptMigrationMetadata.phase(in: defaults) != nil
            || (scriptVersion != nil && ScriptSettings.enabled(from: defaults)) {
            throw BackupError.conflictingScriptConfigurationModel
        }
        if profiles.contains(where: { $0.postMergeScriptID != nil }),
           scriptVersion == nil {
            throw BackupError.conflictingScriptConfigurationModel
        }
        let portableScripts = try portableScripts(
            referencedBy: profiles,
            from: ScriptLibrary.load(from: defaults),
            requireSelfContained: true
        )
        guard incomplete.isEmpty else {
            throw BackupError.incompleteProfiles(incomplete)
        }
        return BackupArchive(
            profiles: profiles,
            sidecars: sidecars,
            publicResources: publicResources,
            globalConfig: globalConfig,
            runtimeConfig: FlClashRuntimeConfig.load(from: defaults),
            configurationModelVersion: isIdentity(globalConfig)
                ? completedVersion : nil,
            scripts: portableScripts,
            scriptConfigurationModelVersion: scriptVersion
        )
    }

     
     
     
     
     
     
     
     
     
    private func sanitizedForPortableStorage() throws -> BackupArchive {
        var copy = self
        var sanitizedProfiles = copy.profiles
        var sanitizedSidecars: [String: String] = [:]
        var omittedRemoteSources = 0
        for (profileID, yaml) in copy.sidecars where Self.isSafeProfileID(profileID) {
            sanitizedSidecars[profileID] = yaml
        }
         
         
         
         
         
         
        _ = omittedRemoteSources
         
         
         
         
         
         
        copy.profiles = sanitizedProfiles
        copy.sidecars = sanitizedSidecars
        let portableResources = copy.publicResources
        copy.publicResources = Self.sanitizePublicResources(
            portableResources,
            profiles: &copy.profiles
        )

        if var runtimeConfig = copy.runtimeConfig {
            runtimeConfig = FlClashRuntimeConfig.replacingGlobalFields(
                in: runtimeConfig,
                with: runtimeConfig.patchJSON,
                keys: OverridePatch.globalRuntimeKeys
            )
            copy.runtimeConfig = runtimeConfig
        }
        if copy.schemaVersion >= 4,
           copy.profiles.contains(where: { $0.postMergeScriptID != nil }),
           copy.scriptConfigurationModelVersion == nil {
            throw BackupError.conflictingScriptConfigurationModel
        }
        copy.scripts = try Self.portableScripts(
            referencedBy: copy.profiles,
            from: copy.scripts,
            requireSelfContained: copy.schemaVersion >= 4
        )
        _ = try copy.scriptConfigurationModel()
        return copy
    }

     
     
     
     
     
    private static func portableScripts(
        referencedBy profiles: [Profile],
        from scripts: [ConfigScript],
        requireSelfContained: Bool
    ) throws -> [ConfigScript] {
        var orderedIDs: [String] = []
        var seen: Set<String> = []
        for profile in profiles {
            for id in [profile.selectedScriptID, profile.postMergeScriptID].compactMap({ $0 })
            where seen.insert(id).inserted {
                orderedIDs.append(id)
            }
        }

         
         
         
         
         
         
        let referenced = seen
        for script in scripts where seen.insert(script.id).inserted {
            orderedIDs.append(script.id)
        }

         
         
         
         
         
        return try orderedIDs.compactMap { id in
            let isReferenced = referenced.contains(id)
            let matches = scripts.filter { $0.id == id }
            guard let script = matches.first else {
                if requireSelfContained, isReferenced {
                    throw BackupError.missingReferencedScript
                }
                return nil
            }
            guard matches.count == 1,
                  isValidPortableScriptIdentity(script) else {
                if isReferenced { throw BackupError.invalidScript }
                return nil
            }
             
             
             
             
             
            return script
        }
    }

    private static func isValidPortableScriptIdentity(_ script: ConfigScript) -> Bool {
        let idBytes = script.id.lengthOfBytes(using: .utf8)
        let labelBytes = script.label.lengthOfBytes(using: .utf8)
        let bodyBytes = script.body.lengthOfBytes(using: .utf8)
        return idBytes > 0
            && idBytes <= 256
            && labelBytes <= 1_024
            && bodyBytes <= 1_048_576
            && script.id.rangeOfCharacter(from: .controlCharacters) == nil
    }

    private enum ConfigurationModel: Equatable {
        case legacyGlobal
        case profileScoped(version: Int)
    }

    private enum ScriptConfigurationModel: Equatable {
        case legacyGlobal
        case profileScoped(version: Int)
    }

    private struct ScriptRestorePlan {
        let targetScripts: [ConfigScript]
        let targetVersion: Int?
        let shouldDisableLegacyWriter: Bool
        let profileIDsRequiringPreflight: Set<String>
    }

    private struct RestorePreparation {
        let payload: BackupArchive
        let importedProfiles: [Profile]
        let importedIDs: Set<String>
        let existingProfiles: [Profile]
        let restoredProfiles: [Profile]
        let affectedProfileIDs: Set<String>
        let targetGlobalConfig: OverrideSpec
        let targetRuntimeConfig: OverrideSpec
        let targetConfigurationVersion: Int?
        let targetScripts: [ConfigScript]
        let targetScriptConfigurationVersion: Int?
        let shouldDisableLegacyScript: Bool
        let profileIDsRequiringPreflight: Set<String>
    }

     
     
     
    func preview(
        workingDir: URL,
        scope: BackupRestoreScope = .allData,
        defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) throws -> BackupRestorePreview {
        let preparation = try prepareRestore(
            workingDir: workingDir,
            scope: scope,
            defaults: defaults
        )
        let payload = preparation.payload
        let existing = preparation.existingProfiles
        let existingByID = Dictionary(
            existing.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var changes: [BackupRestorePreview.Change] = []

        for restored in preparation.restoredProfiles
        where preparation.affectedProfileIDs.contains(restored.id) {
            guard let local = existingByID[restored.id] else {
                changes.append(.init(
                    profileID: restored.id,
                    label: restored.label,
                    kind: .added
                ))
                continue
            }
            let localSource = Self.sourceYAML(
                workingDir: workingDir,
                profileID: restored.id
            )
            let targetSource = targetSourceYAML(
                for: restored.id,
                preparation: preparation,
                workingDir: workingDir
            )
            let localResources = Self.collectPublicResources(
                profile: local,
                workingDir: workingDir
            ).data
            let targetResources = preparation.importedIDs.contains(restored.id)
                ? payload.publicResources[restored.id] ?? [:]
                : localResources
            let kind: BackupRestorePreview.Change.Kind =
                local == restored
                    && localSource == targetSource
                    && localResources == targetResources
                ? .unchanged : .updated
            changes.append(.init(
                profileID: restored.id,
                label: restored.label,
                kind: kind
            ))
        }

        do {
            changes.append(contentsOf: existing.compactMap { local in
                guard !preparation.importedIDs.contains(local.id) else { return nil }
                return .init(profileID: local.id, label: local.label, kind: .removed)
            })
        }

        let currentGlobalConfig = GlobalConfig.load(from: defaults)
        let currentRuntimeConfig = FlClashRuntimeConfig.load(
            from: defaults
        )
        let currentConfigurationVersion =
            LegacyGlobalConfigMigrationMetadata.completedVersion(in: defaults)
        return BackupRestorePreview(
            changes: changes,
            totalProfilesAfterRestore: preparation.restoredProfiles.count,
            globalConfigChanges: scope == .allData
                && (
                    currentGlobalConfig != preparation.targetGlobalConfig
                        || currentRuntimeConfig
                            != preparation.targetRuntimeConfig
                        || currentConfigurationVersion
                            != preparation.targetConfigurationVersion
                ),
            referencedScriptCount: payload.scripts.count,
            omittedRemoteSourceCount: payload.omittedRemoteSourceCount,
            rebindRequiredProviderCount: payload.sidecars.values.reduce(into: 0) {
                $0 += Self.rebindRequiredProviders(in: $1)
            }
        )
    }

     
     
     
     
     
    static func rebindRequiredProviders(in sidecar: String) -> Int {
        guard let json = try? ConfigTransforms.yamlToJSON(sidecar),
              let root = try? JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any]
        else { return 0 }
        return ["proxy-providers", "rule-providers"].reduce(into: 0) { total, key in
            guard let providers = root[key] as? [String: Any] else { return }
            total += providers.values.filter {
                ($0 as? [String: Any])?["hako-rebind-required"] as? Bool == true
            }.count
        }
    }

     
     
     
     
     
     
    @discardableResult
    func restore(
        workingDir: URL,
        scope: BackupRestoreScope = .allData,
        defaults: UserDefaults = GlobalConfig.appGroupDefaults,
        profileScript: (String?, String, String) throws -> String = {
            try ScriptLibrary.apply(id: $0, to: $1, profileName: $2)
        },
        configScript: (String, String) throws -> String = {
            try ScriptSettings.apply(toConfigYAML: $0, profileName: $1)
        },
        credentials: CredentialStore = CredentialStore()
    ) throws -> BackupRestoreResult {
        let preparation = try prepareRestore(
            workingDir: workingDir,
            scope: scope,
            defaults: defaults
        )
        if !preparation.profileIDsRequiringPreflight.isEmpty {
            try verifyRestoredProfilesCanBeGenerated(
                preparation,
                workingDir: workingDir,
                profileScript: profileScript,
                configScript: configScript
            )
        }
        let payload = preparation.payload
        let importedProfiles = preparation.importedProfiles
        let importedIDs = preparation.importedIDs
        let profileURL = workingDir.appendingPathComponent("store/profiles.json")
        let profileStore = ProfileStore(fileURL: profileURL)
        let existing = preparation.existingProfiles
        var restoredProfiles = preparation.restoredProfiles

        let affectedIDs = importedIDs.union(existing.map(\.id))
        let snapshot = try RestoreSnapshot(
            workingDir: workingDir,
            profileURL: profileURL,
            affectedProfileIDs: affectedIDs.filter(Self.isSafeProfileID),
            defaults: defaults
        )
        defer { snapshot.discard() }

        do {
            ScriptLibrary.save(preparation.targetScripts, in: defaults)
            if scope == .allData {
                if preparation.shouldDisableLegacyScript {
                    ScriptSettings.save(
                        enabled: false,
                        body: ScriptSettings.body(from: defaults),
                        in: defaults
                    )
                }
                LegacyGlobalScriptMigrationMetadata.saveCompletedVersion(
                    preparation.targetScriptConfigurationVersion,
                    in: defaults
                )
                LegacyGlobalScriptMigrationMetadata.savePhase(nil, in: defaults)
            }
            let fileManager = FileManager.default
            let storeDir = workingDir.appendingPathComponent("store", isDirectory: true)
            for profile in importedProfiles {
                let directory = storeDir.appendingPathComponent(profile.id, isDirectory: true)
                let sourceURL = directory.appendingPathComponent("source.yaml")
                if let yaml = payload.sidecars[profile.id] {
                    try fileManager.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true
                    )
                     
                     
                     
                     
                    try Data(yaml.utf8).write(
                        to: sourceURL,
                        options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                    )
                } else if fileManager.fileExists(atPath: sourceURL.path) {
                    try fileManager.removeItem(at: sourceURL)
                }
                try ProfileExternalResourceStore.replace(
                    payload.publicResources[profile.id] ?? [:],
                    profileID: profile.id,
                    coreHomeDir: workingDir
                )
            }
            try profileStore.save(restoredProfiles)
            for profile in existing where !importedIDs.contains(profile.id)
                && Self.isSafeProfileID(profile.id) {
                let directory = storeDir.appendingPathComponent(
                    profile.id,
                    isDirectory: true
                )
                if fileManager.fileExists(atPath: directory.path) {
                    try fileManager.removeItem(at: directory)
                }
            }
            if scope == .allData {
                if Self.isIdentity(preparation.targetGlobalConfig) {
                    GlobalConfig.clear(in: defaults)
                } else {
                    GlobalConfig.save(preparation.targetGlobalConfig, in: defaults)
                }
                 
                 
                 
                 
                 
                 
                 
                 
                ModeIntentClock.stamped {
                    FlClashRuntimeConfig.save(
                        preparation.targetRuntimeConfig,
                        in: defaults
                    )
                }
                LegacyGlobalConfigMigrationMetadata.saveCompletedVersion(
                    preparation.targetConfigurationVersion,
                    in: defaults
                )
            }
        } catch {
            do {
                try snapshot.rollback(defaults: defaults)
            } catch {
                throw BackupError.rollbackFailed
            }
            throw error
        }

        return BackupRestoreResult(
            importedProfiles: importedProfiles.count,
            totalProfiles: restoredProfiles.count,
            scope: scope
        )
    }

    private func prepareRestore(
        workingDir: URL,
        scope: BackupRestoreScope,
        defaults: UserDefaults
    ) throws -> RestorePreparation {
        let payload = try preparedForRestore()
        let archiveModel = try payload.configurationModel()
        let profileStore = ProfileStore(
            fileURL: workingDir.appendingPathComponent("store/profiles.json")
        )
        let existing = profileStore.load()
        let imported = payload.profiles
        let importedIDs = Set(imported.map(\.id))
         
         
         
         
         
        var restored: [Profile] = imported
        let scriptPlan = try prepareScriptRestore(
            payload: payload,
            importedProfiles: imported,
            restoredProfiles: restored,
            scope: scope,
            defaults: defaults
        )

        let currentVersion = LegacyGlobalConfigMigrationPlan.currentVersion
        let localVersion = LegacyGlobalConfigMigrationMetadata.completedVersion(
            in: defaults
        )
        let localUsesProfiles = (localVersion ?? 0) >= currentVersion
        let localGlobal = GlobalConfig.load(from: defaults)
        let localRuntime = FlClashRuntimeConfig.load(from: defaults)
        let archivedRuntime = payload.runtimeConfig
            ?? FlClashRuntimeConfig.migrated(
                preferredProfile: imported.first,
                legacyGlobalOverride: payload.globalConfig
            )
        let targetRuntime = scope == .allData
            ? archivedRuntime : localRuntime
        var runtimePreflightIDs =
            scriptPlan.profileIDsRequiringPreflight
        if targetRuntime != localRuntime {
            runtimePreflightIDs.formUnion(restored.map(\.id))
        }

        if !localUsesProfiles {
            if case .profileScoped = archiveModel {
                throw BackupError.incompatibleConfigurationModel
            }
            return RestorePreparation(
                payload: payload,
                importedProfiles: imported,
                importedIDs: importedIDs,
                existingProfiles: existing,
                restoredProfiles: restored,
                affectedProfileIDs: affectedIDs(
                    importedIDs: importedIDs,
                    existing: existing
                ),
                targetGlobalConfig: scope == .allData
                    ? payload.globalConfig : localGlobal,
                targetRuntimeConfig: targetRuntime,
                targetConfigurationVersion: localVersion,
                targetScripts: scriptPlan.targetScripts,
                targetScriptConfigurationVersion: scriptPlan.targetVersion,
                shouldDisableLegacyScript: scriptPlan.shouldDisableLegacyWriter,
                profileIDsRequiringPreflight:
                    runtimePreflightIDs
            )
        }

         
         
         
        if scope == .profilesOnly, !Self.isIdentity(localGlobal) {
            throw BackupError.conflictingConfigurationModel
        }

        var affected = affectedIDs(
            importedIDs: importedIDs,
            existing: existing
        )
        var profileIDsRequiringPreflight =
            runtimePreflightIDs
        if scope == .allData, case .legacyGlobal = archiveModel {
            affected.formUnion(restored.map(\.id))
            profileIDsRequiringPreflight.formUnion(restored.map(\.id))
             
             
             
             
             
             
             
            let legacyRuleLayer = OverrideSpec(
                appendRules: payload.globalConfig.appendRules,
                prependRules: payload.globalConfig.prependRules
            )
            restored = restored.map {
                var profile = $0
                profile.migratedGlobalOverride = legacyRuleLayer
                return profile
            }
        }
        restored = restored.map(FlClashRuntimeConfig.sanitizedProfile)

        return RestorePreparation(
            payload: payload,
            importedProfiles: imported,
            importedIDs: importedIDs,
            existingProfiles: existing,
            restoredProfiles: restored,
            affectedProfileIDs: affected,
            targetGlobalConfig: scope == .allData ? OverrideSpec() : localGlobal,
            targetRuntimeConfig: targetRuntime,
            targetConfigurationVersion: localVersion,
            targetScripts: scriptPlan.targetScripts,
            targetScriptConfigurationVersion: scriptPlan.targetVersion,
            shouldDisableLegacyScript: scriptPlan.shouldDisableLegacyWriter,
            profileIDsRequiringPreflight: profileIDsRequiringPreflight
        )
    }

    private func configurationModel() throws -> ConfigurationModel {
        let currentVersion = LegacyGlobalConfigMigrationPlan.currentVersion
        if let version = configurationModelVersion {
            guard version > 0, version <= currentVersion else {
                throw BackupError.unsupportedConfigurationModel(version)
            }
            guard Self.isIdentity(globalConfig) else {
                throw BackupError.conflictingConfigurationModel
            }
            return .profileScoped(version: version)
        }

        let hasProfileScopedLayer = profiles.contains {
            $0.migratedGlobalOverride != nil
        }
        if schemaVersion <= 2, hasProfileScopedLayer {
            guard Self.isIdentity(globalConfig) else {
                throw BackupError.conflictingConfigurationModel
            }
             
             
             
            return .profileScoped(version: currentVersion)
        }
        if schemaVersion >= 3, hasProfileScopedLayer {
            throw BackupError.conflictingConfigurationModel
        }
        return .legacyGlobal
    }

    private func prepareScriptRestore(
        payload: BackupArchive,
        importedProfiles: [Profile],
        restoredProfiles: [Profile],
        scope: BackupRestoreScope,
        defaults: UserDefaults
    ) throws -> ScriptRestorePlan {
        guard LegacyGlobalScriptMigrationMetadata.phase(in: defaults) == nil else {
            throw BackupError.conflictingScriptConfigurationModel
        }
        let archiveModel = try payload.scriptConfigurationModel()
        var targetScripts = ScriptLibrary.load(from: defaults)
        for imported in payload.scripts {
            if let existing = targetScripts.first(where: { $0.id == imported.id }) {
                guard existing == imported else {
                    throw BackupError.scriptCollision
                }
            } else {
                targetScripts.append(imported)
            }
        }
        try Self.validateScriptReferences(
            in: importedProfiles,
            scripts: targetScripts
        )
        try Self.validateScriptReferences(
            in: restoredProfiles,
            scripts: targetScripts
        )

        let currentVersion = LegacyGlobalScriptMigrationPlan.currentVersion
        let localVersion = LegacyGlobalScriptMigrationMetadata.completedVersion(
            in: defaults
        )
        let localUsesProfiles = (localVersion ?? 0) >= currentVersion
        let legacyWriterEnabled = ScriptSettings.enabled(from: defaults)
        let targetVersion: Int?
        let shouldDisableLegacyWriter: Bool
        switch archiveModel {
        case .profileScoped(let archiveVersion):
            guard localUsesProfiles else {
                throw BackupError.incompatibleScriptConfigurationModel
            }
            if scope == .profilesOnly, legacyWriterEnabled {
                throw BackupError.conflictingScriptConfigurationModel
            }
            targetVersion = scope == .allData
                ? max(localVersion ?? 0, archiveVersion)
                : localVersion
            shouldDisableLegacyWriter = scope == .allData && legacyWriterEnabled
        case .legacyGlobal:
            guard !localUsesProfiles || !legacyWriterEnabled else {
                throw BackupError.conflictingScriptConfigurationModel
            }
            targetVersion = localVersion
            shouldDisableLegacyWriter = false
        }

        var preflightIDs = Set(importedProfiles.compactMap { profile -> String? in
            profile.selectedScriptID != nil || profile.postMergeScriptID != nil
                ? profile.id : nil
        })
        if shouldDisableLegacyWriter {
            preflightIDs.formUnion(restoredProfiles.map(\.id))
        }
        return ScriptRestorePlan(
            targetScripts: targetScripts,
            targetVersion: targetVersion,
            shouldDisableLegacyWriter: shouldDisableLegacyWriter,
            profileIDsRequiringPreflight: preflightIDs
        )
    }

    private func scriptConfigurationModel() throws -> ScriptConfigurationModel {
        let currentVersion = LegacyGlobalScriptMigrationPlan.currentVersion
        if let version = scriptConfigurationModelVersion {
            guard version > 0, version <= currentVersion else {
                throw BackupError.unsupportedScriptConfigurationModel(version)
            }
            return .profileScoped(version: version)
        }
        if profiles.contains(where: { $0.postMergeScriptID != nil }) {
            guard schemaVersion <= 3 else {
                throw BackupError.conflictingScriptConfigurationModel
            }
             
             
             
            return .profileScoped(version: currentVersion)
        }
        return .legacyGlobal
    }

    private static func validateScriptReferences(
        in profiles: [Profile],
        scripts: [ConfigScript]
    ) throws {
        guard profiles.allSatisfy({ profile in
            [profile.selectedScriptID, profile.postMergeScriptID]
                .compactMap { $0 }
                .allSatisfy { id in scripts.filter { $0.id == id }.count == 1 }
        }) else {
            throw BackupError.missingReferencedScript
        }
    }

    private func verifyRestoredProfilesCanBeGenerated(
        _ preparation: RestorePreparation,
        workingDir: URL,
        profileScript: (String?, String, String) throws -> String,
        configScript: (String, String) throws -> String,
    ) throws {
        let targetScriptIDs = Set(preparation.targetScripts.map(\.id))
        let applyProfileScript: (String?, String, String) throws -> String = { id, yaml, name in
            guard let id else { return try profileScript(nil, yaml, name) }
            guard targetScriptIDs.contains(id) else {
                return try profileScript(id, yaml, name)
            }
            return try ScriptLibrary.apply(
                id: id,
                to: yaml,
                scripts: preparation.targetScripts,
                profileName: name
            )
        }
        for (index, profile) in preparation.restoredProfiles.enumerated()
        where preparation.profileIDsRequiringPreflight.contains(profile.id) {
            guard let source = targetSourceYAML(
                for: profile.id,
                preparation: preparation,
                workingDir: workingDir
            ) else {
                throw BackupError.configurationMigrationBlocked(
                    .sourceUnavailable(profileIndex: index)
                )
            }
            let runtime: String
             
             
             
             
             
             
             
             
            var asRestored = profile
            asRestored.proxyCredentials = nil
            asRestored.sourceCredentials = nil
            asRestored.sourceCredentialsRedacted = false
            do {
                runtime = try ProfileRuntimeConfigBuilder.build(
                    raw: source,
                    profile: asRestored,
                    globalOverride: OverrideSpec(),
                    runtimeOverride:
                        preparation.targetRuntimeConfig,
                    profileScript: applyProfileScript,
                    configScript: { yaml, name in
                        guard !preparation.shouldDisableLegacyScript else {
                            return yaml
                        }
                        return try configScript(yaml, name)
                    },
                    postMergeScript: applyProfileScript
                )
            } catch {
                throw BackupError.configurationMigrationBlocked(
                    .runtimeGenerationFailed(profileIndex: index)
                )
            }
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            _ = runtime
        }
    }

    private func targetSourceYAML(
        for profileID: String,
        preparation: RestorePreparation,
        workingDir: URL
    ) -> String? {
        if preparation.importedIDs.contains(profileID) {
             
             
             
            return preparation.payload.sidecars[profileID]
        }
        return Self.sourceYAML(workingDir: workingDir, profileID: profileID)
    }

    private func affectedIDs(
        importedIDs: Set<String>,
        existing: [Profile]
    ) -> Set<String> {
        importedIDs.union(existing.map(\.id))
    }

    private func preparedForRestore() throws -> BackupArchive {
        var payload = try sanitizedForPortableStorage()
         
         
        var unique: [Profile] = []
        for profile in payload.profiles {
            guard Self.isSafeProfileID(profile.id) else {
                throw BackupError.unsafeProfileID(profile.id)
            }
            if let index = unique.firstIndex(where: { $0.id == profile.id }) {
                unique[index] = profile
            } else {
                unique.append(profile)
            }
        }
        payload.profiles = unique
        payload.sidecars = payload.sidecars.filter { profileID, _ in
            Self.isSafeProfileID(profileID) && unique.contains(where: { $0.id == profileID })
        }
        payload.publicResources = payload.publicResources.filter { profileID, _ in
            Self.isSafeProfileID(profileID) && unique.contains(where: { $0.id == profileID })
        }
        return payload
    }

    private static func collectPublicResources(
        profile: Profile,
        workingDir: URL
    ) -> (references: [ProfileExternalResourceReference], data: [String: Data]) {
        var references: [ProfileExternalResourceReference] = []
        var data: [String: Data] = [:]
        for reference in profile.externalResources ?? []
        where isPublicReference(reference) && isSafeStorageKey(reference.storageKey) {
            let url = workingDir.appendingPathComponent(
                "store/\(profile.id)/resources/\(reference.storageKey)"
            )
            guard let bytes = try? Data(contentsOf: url),
                  isSafePublicResource(bytes) else { continue }
            references.append(reference)
            data[reference.storageKey] = bytes
        }
        return (references, data)
    }

    private static func sanitizePublicResources(
        _ resources: [String: [String: Data]],
        profiles: inout [Profile]
    ) -> [String: [String: Data]] {
        var sanitized: [String: [String: Data]] = [:]
        for index in profiles.indices where isSafeProfileID(profiles[index].id) {
            let profileID = profiles[index].id
            let candidates = resources[profileID] ?? [:]
            var keptReferences: [ProfileExternalResourceReference] = []
            var keptData: [String: Data] = [:]
            for reference in profiles[index].externalResources ?? []
            where isPublicReference(reference) && isSafeStorageKey(reference.storageKey) {
                guard let bytes = candidates[reference.storageKey],
                      isSafePublicResource(bytes) else { continue }
                keptReferences.append(reference)
                keptData[reference.storageKey] = bytes
            }
            profiles[index].externalResources = keptReferences.isEmpty
                ? nil : keptReferences
            if !keptData.isEmpty { sanitized[profileID] = keptData }
        }
        return sanitized
    }

    private static func isPublicReference(_ reference: ProfileExternalResourceReference) -> Bool {
        IOSExternalResourceCatalog.entries.contains {
            $0.id == reference.capabilityID
                && $0.disposition == .publicFileOrInline
                && $0.confidentiality == .publicData
        }
    }

    private static func isSafeStorageKey(_ key: String) -> Bool {
        key.hasPrefix("resource-") && !key.contains("/") && !key.contains("\\")
    }

    private static func isSafePublicResource(_ data: Data) -> Bool {
        guard !data.isEmpty,
              data.count <= ProfileExternalResourceImporter.maximumResourceBytes,
              let text = String(data: data, encoding: .utf8) else { return false }
        let upper = text.uppercased()
        return upper.contains("-----BEGIN CERTIFICATE-----")
            && !upper.contains("PRIVATE KEY-----")
            && !upper.contains("OPENVPN STATIC KEY")
    }

    private static func sourceYAML(workingDir: URL, profileID: String) -> String? {
        guard isSafeProfileID(profileID) else { return nil }
        return try? String(
            contentsOf: workingDir.appendingPathComponent("store/\(profileID)/source.yaml"),
            encoding: .utf8
        )
    }

     
     
     
     
    private final class RestoreSnapshot {
        private let fileManager = FileManager.default
        private let workingDir: URL
        private let profileURL: URL
        private let root: URL
        private let affectedProfileIDs: [String]
        private let originalProfileData: Data?
        private let originalProfileFileExisted: Bool
        private let originalGlobalConfig: OverrideSpec
        private let originalRuntimeConfig: OverrideSpec
        private let originalRuntimeConfigInitialized: Bool
        private let originalConfigurationVersion: Int?
        private let originalScripts: [ConfigScript]
        private let originalLegacyScript: LegacyGlobalScriptState
        private let originalScriptConfigurationVersion: Int?
        private let originalScriptMigrationPhase: LegacyGlobalScriptMigrationPhase?

        init(
            workingDir: URL,
            profileURL: URL,
            affectedProfileIDs: Set<String>,
            defaults: UserDefaults
        ) throws {
            self.workingDir = workingDir
            self.profileURL = profileURL
            self.affectedProfileIDs = affectedProfileIDs.sorted()
            originalProfileFileExisted = FileManager.default.fileExists(atPath: profileURL.path)
            originalProfileData = originalProfileFileExisted
                ? try Data(contentsOf: profileURL)
                : nil
            originalGlobalConfig = GlobalConfig.load(from: defaults)
            originalRuntimeConfig = FlClashRuntimeConfig.load(
                from: defaults
            )
            originalRuntimeConfigInitialized =
                FlClashRuntimeConfig.isInitialized(in: defaults)
            originalConfigurationVersion =
                LegacyGlobalConfigMigrationMetadata.completedVersion(in: defaults)
            originalScripts = ScriptLibrary.load(from: defaults)
            originalLegacyScript = LegacyGlobalScriptState(
                enabled: ScriptSettings.enabled(from: defaults),
                body: ScriptSettings.body(from: defaults)
            )
            originalScriptConfigurationVersion =
                LegacyGlobalScriptMigrationMetadata.completedVersion(in: defaults)
            originalScriptMigrationPhase =
                LegacyGlobalScriptMigrationMetadata.phase(in: defaults)
            root = workingDir.appendingPathComponent(
                ".restore-transaction-\(UUID().uuidString.lowercased())",
                isDirectory: true
            )
            do {
                try FileManager.default.createDirectory(
                    at: root,
                    withIntermediateDirectories: true,
                    attributes: [
                        .protectionKey:
                            FileProtectionType.completeUntilFirstUserAuthentication
                    ]
                )
                let storeDir = workingDir.appendingPathComponent("store", isDirectory: true)
                for id in self.affectedProfileIDs {
                    let source = storeDir.appendingPathComponent(id, isDirectory: true)
                    guard FileManager.default.fileExists(atPath: source.path) else { continue }
                    try FileManager.default.copyItem(
                        at: source,
                        to: root.appendingPathComponent(id, isDirectory: true)
                    )
                }
            } catch {
                try? FileManager.default.removeItem(at: root)
                throw error
            }
        }

        func rollback(defaults: UserDefaults) throws {
            let storeDir = workingDir.appendingPathComponent("store", isDirectory: true)
            try fileManager.createDirectory(at: storeDir, withIntermediateDirectories: true)
            for id in affectedProfileIDs {
                let target = storeDir.appendingPathComponent(id, isDirectory: true)
                if fileManager.fileExists(atPath: target.path) {
                    try fileManager.removeItem(at: target)
                }
                let saved = root.appendingPathComponent(id, isDirectory: true)
                if fileManager.fileExists(atPath: saved.path) {
                    try fileManager.copyItem(at: saved, to: target)
                }
            }
            if let originalProfileData {
                try originalProfileData.write(
                    to: profileURL,
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                )
            } else if originalProfileFileExisted == false,
                      fileManager.fileExists(atPath: profileURL.path) {
                try fileManager.removeItem(at: profileURL)
            }
            GlobalConfig.save(originalGlobalConfig, in: defaults)
             
             
             
             
             
            ModeIntentClock.stamped {
                if originalRuntimeConfigInitialized {
                    FlClashRuntimeConfig.save(
                        originalRuntimeConfig,
                        in: defaults
                    )
                } else {
                    FlClashRuntimeConfig.clear(in: defaults)
                }
            }
            LegacyGlobalConfigMigrationMetadata.saveCompletedVersion(
                originalConfigurationVersion,
                in: defaults
            )
            ScriptLibrary.save(originalScripts, in: defaults)
            ScriptSettings.save(
                enabled: originalLegacyScript.enabled,
                body: originalLegacyScript.body,
                in: defaults
            )
            LegacyGlobalScriptMigrationMetadata.saveCompletedVersion(
                originalScriptConfigurationVersion,
                in: defaults
            )
            LegacyGlobalScriptMigrationMetadata.savePhase(
                originalScriptMigrationPhase,
                in: defaults
            )
        }

        func discard() {
            try? fileManager.removeItem(at: root)
        }
    }

    private static func isSafeProfileID(_ id: String) -> Bool {
        guard !id.isEmpty, id != ".", id != ".." else { return false }
        guard id.lowercased() != "profiles.json" else { return false }
        return id.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\:\0")) == nil
    }

    private static func isIdentity(_ spec: OverrideSpec) -> Bool {
        spec.patchJSON.isEmpty && spec.appendRules.isEmpty
    }
}

extension BackupArchive.BackupError: LocalizedError {
    var errorDescription: String? {
        switch self {
                case .incompleteProfiles(let labels):
            return "%@ could not be backed up completely: a saved credential is missing. Re-enter it, then back up again."
                .replacingOccurrences(of: "%@", with: labels.joined(separator: ", "))
case .unsupportedSchema(let version):
            return "Backup schema \(version) is newer than this app supports."
        case .unsupportedConfigurationModel:
            return "This backup uses a newer configuration ownership model. Update Clash before restoring it."
        case .incompatibleConfigurationModel:
            return "This backup was created after settings moved into each profile. Open the new Clash interface before restoring it."
        case .conflictingConfigurationModel:
            return "The backup contains both app-wide and profile-owned settings, so it was not restored."
        case .configurationMigrationBlocked(let blocker):
            return blocker.userMessage
        case .unsupportedScriptConfigurationModel:
            return "This backup uses a newer script ownership model. Update Clash before restoring it."
        case .incompatibleScriptConfigurationModel:
            return "This backup uses profile-owned scripts. Open the new Clash interface before restoring it."
        case .conflictingScriptConfigurationModel:
            return "The backup and this device disagree about script ownership, so nothing was changed."
        case .missingReferencedScript:
            return "A profile references a script that is not available in this portable backup."
        case .scriptCollision:
            return "A different local script already uses an imported script identity. Rename it before restoring."
        case .invalidScript:
            return "The backup contains invalid or duplicate script metadata."
        case .unsafeProfileID:
            return "The backup contains an unsafe profile identifier."
        case .rollbackFailed:
            return "Restore failed and the previous local state could not be fully recovered."
        }
    }
}
