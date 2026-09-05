import Foundation

struct LegacyGlobalConfigMigrationPlan: Equatable {
    static let currentVersion = 1

    let version: Int
    let profiles: [Profile]

    init(profiles: [Profile]) {
        version = Self.currentVersion
        self.profiles = profiles
    }
}

enum LegacyGlobalConfigMigrationBlocker: Equatable {
    case sourceUnavailable(profileIndex: Int)
    case conflictingState(profileIndex: Int)
    case runtimeGenerationFailed(profileIndex: Int)
    case semanticMismatch(profileIndex: Int)
    case legacyOverrideReappeared
    case storageUnavailable
    case commitFailed
    case rollbackFailed

    var userMessage: String {
        switch self {
        case .sourceUnavailable:
            return "A configuration source is unavailable. Sync or restore it, then retry the upgrade."
        case .conflictingState:
            return "A partial settings upgrade was detected. Restore the previous profile data, then retry."
        case .runtimeGenerationFailed:
            return "A profile could not be prepared with its current settings. Review that profile, then retry."
        case .semanticMismatch:
            return "The upgraded settings would change a profile's runtime behavior, so nothing was changed."
        case .legacyOverrideReappeared:
            return "An older settings writer restored app-wide overrides after the upgrade. Review the backup or settings source, then retry."
        case .storageUnavailable:
            return "Profile storage is unavailable. Reopen the app after the device is unlocked, then retry."
        case .commitFailed:
            return "The settings upgrade could not be saved. Your previous settings were restored."
        case .rollbackFailed:
            return "The settings upgrade was interrupted and automatic recovery could not be confirmed. Do not change profiles until you restore a backup."
        }
    }
}

enum LegacyGlobalConfigMigrationDryRunResult: Equatable {
    case notNeeded
    case ready(LegacyGlobalConfigMigrationPlan)
    case blocked(LegacyGlobalConfigMigrationBlocker)

    var userMessage: String {
        switch self {
        case .notNeeded, .ready:
            return ""
        case .blocked(let blocker):
            return blocker.userMessage
        }
    }
}

 
 
 
 
 
 
 
 
enum LegacyGlobalConfigMigrationDryRun {
    static func run(
        profiles: [Profile],
        legacyGlobalOverride: OverrideSpec,
        sourceYAML: (Profile) -> String?,
        profileScript: (String?, String, String) throws -> String,
        configScript: (String, String) throws -> String,
         
         
         
         
         
         
        postMergeScript: (String?, String, String) throws -> String = {
            try ScriptLibrary.apply(id: $0, to: $1, profileName: $2)
        }
    ) -> LegacyGlobalConfigMigrationDryRunResult {
        guard !isIdentity(legacyGlobalOverride) else { return .notNeeded }

        var candidates: [Profile] = []
        candidates.reserveCapacity(profiles.count)

        for (index, profile) in profiles.enumerated() {
            guard profile.migratedGlobalOverride == nil else {
                return .blocked(.conflictingState(profileIndex: index))
            }
            guard let source = sourceYAML(profile) else {
                return .blocked(.sourceUnavailable(profileIndex: index))
            }

            var candidate = profile
            candidate.migratedGlobalOverride = legacyGlobalOverride

            let currentRuntime: String
            let candidateRuntime: String
            do {
                currentRuntime = try ProfileRuntimeConfigBuilder.build(
                    raw: source,
                    profile: profile,
                    globalOverride: legacyGlobalOverride,
                    profileScript: profileScript,
                    configScript: configScript,
                    postMergeScript: postMergeScript
                )
                candidateRuntime = try ProfileRuntimeConfigBuilder.build(
                    raw: source,
                    profile: candidate,
                    globalOverride: OverrideSpec(),
                    profileScript: profileScript,
                    configScript: configScript,
                    postMergeScript: postMergeScript
                )
            } catch {
                return .blocked(.runtimeGenerationFailed(profileIndex: index))
            }

            do {
                guard try canonicalRuntime(currentRuntime)
                    == canonicalRuntime(candidateRuntime) else {
                    return .blocked(.semanticMismatch(profileIndex: index))
                }
            } catch {
                return .blocked(.runtimeGenerationFailed(profileIndex: index))
            }

             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            candidates.append(candidate)
        }

        return .ready(LegacyGlobalConfigMigrationPlan(profiles: candidates))
    }

    private static func isIdentity(_ spec: OverrideSpec) -> Bool {
        spec.patchJSON.isEmpty && spec.appendRules.isEmpty
    }

    private static func canonicalRuntime(_ yaml: String) throws -> Data {
        let json = try ConfigTransforms.yamlToJSON(yaml)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

enum LegacyGlobalConfigMigrationResult: Equatable {
    case notNeeded
    case migrated(profileCount: Int)
    case recovered(profileCount: Int)
    case blocked(LegacyGlobalConfigMigrationBlocker)

    var userMessage: String {
        switch self {
        case .notNeeded, .migrated, .recovered:
            return ""
        case .blocked(let blocker):
            return blocker.userMessage
        }
    }
}

 
 
 
 
enum LegacyGlobalConfigMigrationMetadata {
    private static let completedVersionKey = "config.global.profileMigrationVersion"

    static func completedVersion(in defaults: UserDefaults) -> Int? {
        defaults.object(forKey: completedVersionKey) as? Int
    }

    static func saveCompletedVersion(_ version: Int?, in defaults: UserDefaults) {
        if let version {
            defaults.set(version, forKey: completedVersionKey)
        } else {
            defaults.removeObject(forKey: completedVersionKey)
        }
    }
}

 
 
 
 
 
 
 
 
 
 
enum LegacyGlobalConfigMigrationCoordinator {
    static func run(
        profiles: [Profile],
        legacyGlobalOverride: OverrideSpec,
        completedVersion: Int?,
        sourceYAML: (Profile) -> String?,
        profileScript: (String?, String, String) throws -> String,
        configScript: (String, String) throws -> String,
        saveProfiles: ([Profile]) throws -> Void,
        saveGlobalOverride: (OverrideSpec) throws -> Void,
        saveCompletedVersion: (Int?) throws -> Void
    ) -> LegacyGlobalConfigMigrationResult {
        let currentVersion = LegacyGlobalConfigMigrationPlan.currentVersion
        let legacyIsIdentity = isIdentity(legacyGlobalOverride)

        if let completedVersion, completedVersion >= currentVersion {
            guard legacyIsIdentity else {
                return .blocked(.legacyOverrideReappeared)
            }
            return .notNeeded
        }

        let migratedIndices = profiles.indices.filter {
            profiles[$0].migratedGlobalOverride != nil
        }

        if legacyIsIdentity {
            if migratedIndices.isEmpty {
                return commit(
                    originalProfiles: profiles,
                    originalGlobalOverride: legacyGlobalOverride,
                    originalCompletedVersion: completedVersion,
                    targetProfiles: nil,
                    shouldWriteGlobalOverride: false,
                    success: .notNeeded,
                    saveProfiles: saveProfiles,
                    saveGlobalOverride: saveGlobalOverride,
                    saveCompletedVersion: saveCompletedVersion
                )
            }
            guard migratedIndices.count == profiles.count else {
                let firstPending = profiles.indices.first {
                    profiles[$0].migratedGlobalOverride == nil
                } ?? 0
                return .blocked(.conflictingState(profileIndex: firstPending))
            }
            return commit(
                originalProfiles: profiles,
                originalGlobalOverride: legacyGlobalOverride,
                originalCompletedVersion: completedVersion,
                targetProfiles: nil,
                shouldWriteGlobalOverride: false,
                success: .recovered(profileCount: profiles.count),
                saveProfiles: saveProfiles,
                saveGlobalOverride: saveGlobalOverride,
                saveCompletedVersion: saveCompletedVersion
            )
        }

        if !migratedIndices.isEmpty {
            guard migratedIndices.count == profiles.count else {
                let firstPending = profiles.indices.first {
                    profiles[$0].migratedGlobalOverride == nil
                } ?? 0
                return .blocked(.conflictingState(profileIndex: firstPending))
            }
            guard let firstConflict = profiles.indices.first(where: {
                profiles[$0].migratedGlobalOverride != legacyGlobalOverride
            }) else {
                return commit(
                    originalProfiles: profiles,
                    originalGlobalOverride: legacyGlobalOverride,
                    originalCompletedVersion: completedVersion,
                    targetProfiles: nil,
                    shouldWriteGlobalOverride: true,
                    success: .recovered(profileCount: profiles.count),
                    saveProfiles: saveProfiles,
                    saveGlobalOverride: saveGlobalOverride,
                    saveCompletedVersion: saveCompletedVersion
                )
            }
            return .blocked(.conflictingState(profileIndex: firstConflict))
        }

        switch LegacyGlobalConfigMigrationDryRun.run(
            profiles: profiles,
            legacyGlobalOverride: legacyGlobalOverride,
            sourceYAML: sourceYAML,
            profileScript: profileScript,
            configScript: configScript
        ) {
        case .notNeeded:
             
            return .notNeeded
        case .blocked(let blocker):
            return .blocked(blocker)
        case .ready(let plan):
            return commit(
                originalProfiles: profiles,
                originalGlobalOverride: legacyGlobalOverride,
                originalCompletedVersion: completedVersion,
                targetProfiles: plan.profiles,
                shouldWriteGlobalOverride: true,
                success: .migrated(profileCount: plan.profiles.count),
                saveProfiles: saveProfiles,
                saveGlobalOverride: saveGlobalOverride,
                saveCompletedVersion: saveCompletedVersion
            )
        }
    }

    static func run(
        workingDirectory: URL,
        defaults: UserDefaults = GlobalConfig.appGroupDefaults,
        profileScript: (String?, String, String) throws -> String = {
            try ScriptLibrary.apply(id: $0, to: $1, profileName: $2)
        },
        configScript: (String, String) throws -> String = {
            try ScriptSettings.apply(toConfigYAML: $0, profileName: $1)
        }
    ) -> LegacyGlobalConfigMigrationResult {
        let profileStore = ProfileStore(
            fileURL: workingDirectory.appendingPathComponent("store/profiles.json")
        )
        let profiles = profileStore.load()
        return run(
            profiles: profiles,
            legacyGlobalOverride: GlobalConfig.load(from: defaults),
            completedVersion: LegacyGlobalConfigMigrationMetadata.completedVersion(in: defaults),
            sourceYAML: { profile in
                guard isSafeProfileID(profile.id) else { return nil }
                return try? String(
                    contentsOf: workingDirectory.appendingPathComponent(
                        "store/\(profile.id)/source.yaml"
                    ),
                    encoding: .utf8
                )
            },
            profileScript: profileScript,
            configScript: configScript,
            saveProfiles: profileStore.save,
            saveGlobalOverride: { override in
                if isIdentity(override) {
                    GlobalConfig.clear(in: defaults)
                } else {
                    GlobalConfig.save(override, in: defaults)
                }
            },
            saveCompletedVersion: {
                LegacyGlobalConfigMigrationMetadata.saveCompletedVersion($0, in: defaults)
            }
        )
    }

    private static func commit(
        originalProfiles: [Profile],
        originalGlobalOverride: OverrideSpec,
        originalCompletedVersion: Int?,
        targetProfiles: [Profile]?,
        shouldWriteGlobalOverride: Bool,
        success: LegacyGlobalConfigMigrationResult,
        saveProfiles: ([Profile]) throws -> Void,
        saveGlobalOverride: (OverrideSpec) throws -> Void,
        saveCompletedVersion: (Int?) throws -> Void
    ) -> LegacyGlobalConfigMigrationResult {
        do {
            if let targetProfiles { try saveProfiles(targetProfiles) }
            if shouldWriteGlobalOverride { try saveGlobalOverride(OverrideSpec()) }
            try saveCompletedVersion(LegacyGlobalConfigMigrationPlan.currentVersion)
            return success
        } catch {
            do {
                try saveCompletedVersion(originalCompletedVersion)
                try saveGlobalOverride(originalGlobalOverride)
                try saveProfiles(originalProfiles)
            } catch {
                return .blocked(.rollbackFailed)
            }
            return .blocked(.commitFailed)
        }
    }

    private static func isIdentity(_ spec: OverrideSpec) -> Bool {
        spec.patchJSON.isEmpty && spec.appendRules.isEmpty
    }

    private static func isSafeProfileID(_ id: String) -> Bool {
        guard !id.isEmpty, id != ".", id != ".." else { return false }
        return id.rangeOfCharacter(
            from: CharacterSet(charactersIn: "/\\:\0")
        ) == nil
    }
}

struct LegacyGlobalScriptState: Equatable {
    var enabled: Bool
    var body: String
}

enum LegacyGlobalScriptMigrationPhase: String, Equatable {
    case committing
    case invalid
}

struct LegacyGlobalScriptMigrationPlan: Equatable {
    static let currentVersion = 1
    static let scriptID = "hako.migration.global-post-merge.v1"

    let profiles: [Profile]
    let scripts: [ConfigScript]

    static func script(body: String) -> ConfigScript {
        ConfigScript(
            id: scriptID,
            label: "Migrated Global Script",
            body: body
        )
    }
}

enum LegacyGlobalScriptMigrationBlocker: Equatable {
    case sourceUnavailable(profileIndex: Int)
    case conflictingProfile(profileIndex: Int)
    case libraryCollision
    case runtimeGenerationFailed(profileIndex: Int)
    case semanticMismatch(profileIndex: Int)
    case legacyWriterReappeared
    case invalidPhase
    case storageUnavailable
    case commitFailed
    case rollbackFailed

    var userMessage: String {
        switch self {
        case .sourceUnavailable:
            return "A configuration source is unavailable. Sync or restore it, then retry the script upgrade."
        case .conflictingProfile:
            return "A profile already owns a post-processing script. Review that profile before retrying the upgrade."
        case .libraryCollision:
            return "A script library conflict prevents the settings upgrade. Rename the conflicting script, then retry."
        case .runtimeGenerationFailed:
            return "A profile could not be prepared with its current script. Review that profile, then retry."
        case .semanticMismatch:
            return "The upgraded script would change a profile's runtime behavior, so nothing was changed."
        case .legacyWriterReappeared:
            return "An older settings writer restored the app-wide script after the upgrade. Review the restored settings, then retry."
        case .invalidPhase:
            return "The previous script upgrade state is invalid. Restore a backup before changing profiles."
        case .storageUnavailable:
            return "Profile storage is unavailable. Reopen the app after the device is unlocked, then retry."
        case .commitFailed:
            return "The script upgrade could not be saved. Your previous settings were restored."
        case .rollbackFailed:
            return "The script upgrade was interrupted and automatic recovery could not be confirmed. Restore a backup before changing profiles."
        }
    }
}

enum LegacyGlobalScriptMigrationDryRunResult: Equatable {
    case notNeeded
    case ready(LegacyGlobalScriptMigrationPlan)
    case blocked(LegacyGlobalScriptMigrationBlocker)
}

enum LegacyGlobalScriptMigrationResult: Equatable {
    case notNeeded
    case migrated(profileCount: Int)
    case recovered(profileCount: Int)
    case blocked(LegacyGlobalScriptMigrationBlocker)

    var userMessage: String {
        switch self {
        case .notNeeded, .migrated, .recovered:
            return ""
        case .blocked(let blocker):
            return blocker.userMessage
        }
    }
}

 
 
 
enum LegacyGlobalScriptMigrationDryRun {
    static func run(
        profiles: [Profile],
        legacyScript: LegacyGlobalScriptState,
        scripts: [ConfigScript],
        sourceYAML: (Profile) -> String?,
        profileScript: (String?, String, String) throws -> String,
        applyScript: (String, String, String) throws -> String
    ) -> LegacyGlobalScriptMigrationDryRunResult {
        guard legacyScript.enabled else { return .notNeeded }
        guard !scripts.contains(where: {
            $0.id == LegacyGlobalScriptMigrationPlan.scriptID
        }) else {
            return .blocked(.libraryCollision)
        }

        var candidates: [Profile] = []
        candidates.reserveCapacity(profiles.count)
        for (index, profile) in profiles.enumerated() {
            guard profile.postMergeScriptID == nil else {
                return .blocked(.conflictingProfile(profileIndex: index))
            }
            guard let source = sourceYAML(profile) else {
                return .blocked(.sourceUnavailable(profileIndex: index))
            }
            var candidate = profile
            candidate.postMergeScriptID = LegacyGlobalScriptMigrationPlan.scriptID

            let currentRuntime: String
            let candidateRuntime: String
            do {
                currentRuntime = try ProfileRuntimeConfigBuilder.build(
                    raw: source,
                    profile: profile,
                    globalOverride: OverrideSpec(),
                    profileScript: profileScript,
                    configScript: { yaml, name in
                        try applyScript(legacyScript.body, yaml, name)
                    }
                )
                candidateRuntime = try ProfileRuntimeConfigBuilder.build(
                    raw: source,
                    profile: candidate,
                    globalOverride: OverrideSpec(),
                    profileScript: profileScript,
                    configScript: { yaml, _ in yaml },
                    postMergeScript: { id, yaml, name in
                        guard id == LegacyGlobalScriptMigrationPlan.scriptID else {
                            return yaml
                        }
                        return try applyScript(legacyScript.body, yaml, name)
                    }
                )
            } catch {
                return .blocked(.runtimeGenerationFailed(profileIndex: index))
            }

            do {
                guard try canonicalRuntime(currentRuntime)
                    == canonicalRuntime(candidateRuntime) else {
                    return .blocked(.semanticMismatch(profileIndex: index))
                }
            } catch {
                return .blocked(.runtimeGenerationFailed(profileIndex: index))
            }
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            candidates.append(candidate)
        }

        return .ready(LegacyGlobalScriptMigrationPlan(
            profiles: candidates,
            scripts: scripts + [LegacyGlobalScriptMigrationPlan.script(body: legacyScript.body)]
        ))
    }

    private static func canonicalRuntime(_ yaml: String) throws -> Data {
        let json = try ConfigTransforms.yamlToJSON(yaml)
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

enum LegacyGlobalScriptMigrationMetadata {
    private static let completedVersionKey = "config.global.profileScriptMigrationVersion"
    private static let phaseKey = "config.global.profileScriptMigrationPhase"

    static func completedVersion(in defaults: UserDefaults) -> Int? {
        defaults.object(forKey: completedVersionKey) as? Int
    }

    static func saveCompletedVersion(_ version: Int?, in defaults: UserDefaults) {
        if let version {
            defaults.set(version, forKey: completedVersionKey)
        } else {
            defaults.removeObject(forKey: completedVersionKey)
        }
    }

    static func phase(in defaults: UserDefaults) -> LegacyGlobalScriptMigrationPhase? {
        guard let raw = defaults.string(forKey: phaseKey) else { return nil }
        return LegacyGlobalScriptMigrationPhase(rawValue: raw) ?? .invalid
    }

    static func savePhase(
        _ phase: LegacyGlobalScriptMigrationPhase?,
        in defaults: UserDefaults
    ) {
        if let phase {
            defaults.set(phase.rawValue, forKey: phaseKey)
        } else {
            defaults.removeObject(forKey: phaseKey)
        }
    }
}

 
 
 
enum LegacyGlobalScriptMigrationCoordinator {
    static func run(
        profiles: [Profile],
        legacyScript: LegacyGlobalScriptState,
        scripts: [ConfigScript],
        completedVersion: Int?,
        phase: LegacyGlobalScriptMigrationPhase?,
        sourceYAML: (Profile) -> String?,
        profileScript: (String?, String, String) throws -> String,
        applyScript: (String, String, String) throws -> String,
        saveProfiles: ([Profile]) throws -> Void,
        saveScripts: ([ConfigScript]) throws -> Void,
        saveLegacyScript: (LegacyGlobalScriptState) throws -> Void,
        saveCompletedVersion: (Int?) throws -> Void,
        savePhase: (LegacyGlobalScriptMigrationPhase?) throws -> Void
    ) -> LegacyGlobalScriptMigrationResult {
        let currentVersion = LegacyGlobalScriptMigrationPlan.currentVersion
        if phase == .invalid {
            return .blocked(.invalidPhase)
        }

        if let completedVersion, completedVersion >= currentVersion {
            guard !legacyScript.enabled else {
                return .blocked(.legacyWriterReappeared)
            }
            guard phase == nil else {
                return clearCompletedPhase(
                    profileCount: profiles.count,
                    savePhase: savePhase
                )
            }
            return .notNeeded
        }

        if phase == .committing {
            return recover(
                profiles: profiles,
                legacyScript: legacyScript,
                scripts: scripts,
                completedVersion: completedVersion,
                sourceYAML: sourceYAML,
                profileScript: profileScript,
                applyScript: applyScript,
                saveProfiles: saveProfiles,
                saveScripts: saveScripts,
                saveLegacyScript: saveLegacyScript,
                saveCompletedVersion: saveCompletedVersion,
                savePhase: savePhase
            )
        }

        guard legacyScript.enabled else {
            guard profiles.allSatisfy({ $0.postMergeScriptID
                != LegacyGlobalScriptMigrationPlan.scriptID }) else {
                return .blocked(.conflictingProfile(profileIndex: firstMigratedIndex(in: profiles)))
            }
            guard !scripts.contains(where: {
                $0.id == LegacyGlobalScriptMigrationPlan.scriptID
            }) else {
                return .blocked(.libraryCollision)
            }
            return commit(
                originalProfiles: profiles,
                originalLegacyScript: legacyScript,
                originalScripts: scripts,
                originalCompletedVersion: completedVersion,
                originalPhase: phase,
                targetProfiles: nil,
                targetScripts: nil,
                shouldDisableLegacyScript: false,
                success: .notNeeded,
                saveProfiles: saveProfiles,
                saveScripts: saveScripts,
                saveLegacyScript: saveLegacyScript,
                saveCompletedVersion: saveCompletedVersion,
                savePhase: savePhase
            )
        }

        switch LegacyGlobalScriptMigrationDryRun.run(
            profiles: profiles,
            legacyScript: legacyScript,
            scripts: scripts,
            sourceYAML: sourceYAML,
            profileScript: profileScript,
            applyScript: applyScript
        ) {
        case .notNeeded:
            return .notNeeded
        case .blocked(let blocker):
            return .blocked(blocker)
        case .ready(let plan):
            return commit(
                originalProfiles: profiles,
                originalLegacyScript: legacyScript,
                originalScripts: scripts,
                originalCompletedVersion: completedVersion,
                originalPhase: phase,
                targetProfiles: plan.profiles,
                targetScripts: plan.scripts,
                shouldDisableLegacyScript: true,
                success: .migrated(profileCount: plan.profiles.count),
                saveProfiles: saveProfiles,
                saveScripts: saveScripts,
                saveLegacyScript: saveLegacyScript,
                saveCompletedVersion: saveCompletedVersion,
                savePhase: savePhase
            )
        }
    }

    static func run(
        workingDirectory: URL,
        defaults: UserDefaults = ScriptSettings.appGroupDefaults,
        profileScript: (String?, String, String) throws -> String = {
            try ScriptLibrary.apply(id: $0, to: $1, profileName: $2)
        },
         
         
         
         
        applyScript: (String, String, String) throws -> String = {
            try ScriptSettings.apply(body: $0, toConfigYAML: $1, profileName: $2)
        }
    ) -> LegacyGlobalScriptMigrationResult {
        let store = ProfileStore(
            fileURL: workingDirectory.appendingPathComponent("store/profiles.json")
        )
        let profiles = store.load()
        return run(
            profiles: profiles,
            legacyScript: LegacyGlobalScriptState(
                enabled: ScriptSettings.enabled(from: defaults),
                body: ScriptSettings.body(from: defaults)
            ),
            scripts: ScriptLibrary.load(from: defaults),
            completedVersion: LegacyGlobalScriptMigrationMetadata.completedVersion(in: defaults),
            phase: LegacyGlobalScriptMigrationMetadata.phase(in: defaults),
            sourceYAML: { profile in
                guard isSafeProfileID(profile.id) else { return nil }
                return try? String(
                    contentsOf: workingDirectory.appendingPathComponent(
                        "store/\(profile.id)/source.yaml"
                    ),
                    encoding: .utf8
                )
            },
            profileScript: profileScript,
            applyScript: applyScript,
            saveProfiles: store.save,
            saveScripts: { ScriptLibrary.save($0, in: defaults) },
            saveLegacyScript: {
                ScriptSettings.save(enabled: $0.enabled, body: $0.body, in: defaults)
            },
            saveCompletedVersion: {
                LegacyGlobalScriptMigrationMetadata.saveCompletedVersion($0, in: defaults)
            },
            savePhase: {
                LegacyGlobalScriptMigrationMetadata.savePhase($0, in: defaults)
            }
        )
    }

    private static func recover(
        profiles: [Profile],
        legacyScript: LegacyGlobalScriptState,
        scripts: [ConfigScript],
        completedVersion: Int?,
        sourceYAML: (Profile) -> String?,
        profileScript: (String?, String, String) throws -> String,
        applyScript: (String, String, String) throws -> String,
        saveProfiles: ([Profile]) throws -> Void,
        saveScripts: ([ConfigScript]) throws -> Void,
        saveLegacyScript: (LegacyGlobalScriptState) throws -> Void,
        saveCompletedVersion: (Int?) throws -> Void,
        savePhase: (LegacyGlobalScriptMigrationPhase?) throws -> Void
    ) -> LegacyGlobalScriptMigrationResult {
        let migrated = profiles.indices.filter {
            profiles[$0].postMergeScriptID == LegacyGlobalScriptMigrationPlan.scriptID
        }
        let otherWriter = profiles.indices.first {
            profiles[$0].postMergeScriptID != nil
                && profiles[$0].postMergeScriptID != LegacyGlobalScriptMigrationPlan.scriptID
        }
        if let otherWriter {
            return .blocked(.conflictingProfile(profileIndex: otherWriter))
        }
        guard migrated.isEmpty || migrated.count == profiles.count else {
            return .blocked(.conflictingProfile(
                profileIndex: profiles.indices.first {
                    profiles[$0].postMergeScriptID == nil
                } ?? 0
            ))
        }

        let plannedScript = LegacyGlobalScriptMigrationPlan.script(body: legacyScript.body)
        let existing = scripts.first { $0.id == LegacyGlobalScriptMigrationPlan.scriptID }
        if let existing, existing != plannedScript {
            return .blocked(.libraryCollision)
        }
        if !legacyScript.enabled && (migrated.isEmpty || existing == nil) {
            return .blocked(.invalidPhase)
        }

        if migrated.count == profiles.count {
            let targetScripts = existing == nil ? scripts + [plannedScript] : nil
            return commit(
                originalProfiles: profiles,
                originalLegacyScript: legacyScript,
                originalScripts: scripts,
                originalCompletedVersion: completedVersion,
                originalPhase: .committing,
                targetProfiles: nil,
                targetScripts: targetScripts,
                shouldDisableLegacyScript: legacyScript.enabled,
                success: .recovered(profileCount: profiles.count),
                saveProfiles: saveProfiles,
                saveScripts: saveScripts,
                saveLegacyScript: saveLegacyScript,
                saveCompletedVersion: saveCompletedVersion,
                savePhase: savePhase
            )
        }

        guard legacyScript.enabled else {
            return .blocked(.invalidPhase)
        }
        guard existing == nil else {
            return .blocked(.invalidPhase)
        }
        switch LegacyGlobalScriptMigrationDryRun.run(
            profiles: profiles,
            legacyScript: legacyScript,
            scripts: scripts,
            sourceYAML: sourceYAML,
            profileScript: profileScript,
            applyScript: applyScript
        ) {
        case .notNeeded:
            return .blocked(.invalidPhase)
        case .blocked(let blocker):
            return .blocked(blocker)
        case .ready(let plan):
            return commit(
                originalProfiles: profiles,
                originalLegacyScript: legacyScript,
                originalScripts: scripts,
                originalCompletedVersion: completedVersion,
                originalPhase: .committing,
                targetProfiles: plan.profiles,
                targetScripts: plan.scripts,
                shouldDisableLegacyScript: true,
                success: .recovered(profileCount: plan.profiles.count),
                saveProfiles: saveProfiles,
                saveScripts: saveScripts,
                saveLegacyScript: saveLegacyScript,
                saveCompletedVersion: saveCompletedVersion,
                savePhase: savePhase
            )
        }
    }

    private static func commit(
        originalProfiles: [Profile],
        originalLegacyScript: LegacyGlobalScriptState,
        originalScripts: [ConfigScript],
        originalCompletedVersion: Int?,
        originalPhase: LegacyGlobalScriptMigrationPhase?,
        targetProfiles: [Profile]?,
        targetScripts: [ConfigScript]?,
        shouldDisableLegacyScript: Bool,
        success: LegacyGlobalScriptMigrationResult,
        saveProfiles: ([Profile]) throws -> Void,
        saveScripts: ([ConfigScript]) throws -> Void,
        saveLegacyScript: (LegacyGlobalScriptState) throws -> Void,
        saveCompletedVersion: (Int?) throws -> Void,
        savePhase: (LegacyGlobalScriptMigrationPhase?) throws -> Void
    ) -> LegacyGlobalScriptMigrationResult {
        do {
            try savePhase(.committing)
            if let targetProfiles { try saveProfiles(targetProfiles) }
            if let targetScripts { try saveScripts(targetScripts) }
            if shouldDisableLegacyScript {
                try saveLegacyScript(.init(enabled: false, body: originalLegacyScript.body))
            }
            try saveCompletedVersion(LegacyGlobalScriptMigrationPlan.currentVersion)
            try savePhase(nil)
            return success
        } catch {
            do {
                try saveCompletedVersion(originalCompletedVersion)
                try saveLegacyScript(originalLegacyScript)
                try saveScripts(originalScripts)
                try saveProfiles(originalProfiles)
                try savePhase(originalPhase)
            } catch {
                return .blocked(.rollbackFailed)
            }
            return .blocked(.commitFailed)
        }
    }

    private static func clearCompletedPhase(
        profileCount: Int,
        savePhase: (LegacyGlobalScriptMigrationPhase?) throws -> Void
    ) -> LegacyGlobalScriptMigrationResult {
        do {
            try savePhase(nil)
            return .recovered(profileCount: profileCount)
        } catch {
            return .blocked(.commitFailed)
        }
    }

    private static func firstMigratedIndex(in profiles: [Profile]) -> Int {
        profiles.indices.first {
            profiles[$0].postMergeScriptID == LegacyGlobalScriptMigrationPlan.scriptID
        } ?? 0
    }

    private static func isSafeProfileID(_ id: String) -> Bool {
        guard !id.isEmpty, id != ".", id != ".." else { return false }
        return id.rangeOfCharacter(
            from: CharacterSet(charactersIn: "/\\:\0")
        ) == nil
    }
}

struct LegacyClientSettingsMigrationResult: Equatable {
    let globalConfig: LegacyGlobalConfigMigrationResult
    let globalScript: LegacyGlobalScriptMigrationResult?

    var userMessage: String {
        if !globalConfig.userMessage.isEmpty { return globalConfig.userMessage }
        return globalScript?.userMessage ?? ""
    }
}
