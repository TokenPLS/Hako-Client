import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct LegacySettingsAttention: Equatable, Identifiable {
    enum Kind: Equatable {
         
         
        case legacyConfigReappeared
        case legacyScriptReappeared
         
        case semanticMismatch(profileID: String?, label: String?)
         
        case partialUpgrade(profileID: String?, label: String?)
         
        case sourceUnavailable(profileID: String?, label: String?)
         
        case profileNotPreparable(profileID: String?, label: String?)
         
        case scriptOwnedByProfile(profileID: String?, label: String?)
         
        case scriptLibraryCollision
         
        case scriptStateInvalid
         
        case commitFailed
         
         
        case rollbackFailed
    }

    struct Action: Equatable, Identifiable {
        let id: String
        let title: HakoDisplayText
        let resolution: LegacySettingsResolution
        let destructive: Bool
    }

    let kind: Kind
    let message: HakoDisplayText
    let actions: [Action]
     
    let emphasised: Bool

     
     
     
    var id: String {
        switch kind {
        case .legacyConfigReappeared: return "config.reappeared"
        case .legacyScriptReappeared: return "script.reappeared"
        case .semanticMismatch(let id, _): return "config.mismatch.\(id ?? "?")"
        case .partialUpgrade(let id, _): return "config.partial.\(id ?? "?")"
        case .sourceUnavailable(let id, _): return "source.\(id ?? "?")"
        case .profileNotPreparable(let id, _): return "prepare.\(id ?? "?")"
        case .scriptOwnedByProfile(let id, _): return "script.owned.\(id ?? "?")"
        case .scriptLibraryCollision: return "script.collision"
        case .scriptStateInvalid: return "script.invalid"
        case .commitFailed: return "commit"
        case .rollbackFailed: return "rollback"
        }
    }

     
    var snapshot: HakoMoreAttention {
        HakoMoreAttention(
            id: id,
            message: message,
            actions: actions.map {
                HakoMoreAttentionAction(id: $0.id, title: $0.title, destructive: $0.destructive)
            },
            emphasised: emphasised
        )
    }

     

     
     
     
    static func make(
        from result: LegacyClientSettingsMigrationResult,
        profiles: [Profile],
        defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) -> LegacySettingsAttention? {
        let attention: LegacySettingsAttention?
        if case .blocked(let blocker) = result.globalConfig {
            attention = make(configBlocker: blocker, profiles: profiles)
        } else if case .blocked(let blocker)? = result.globalScript {
            attention = make(scriptBlocker: blocker, profiles: profiles)
        } else {
            attention = nil
        }
        guard let attention else { return nil }
        if LegacySettingsAcknowledgement.isAcknowledged(attention.id, in: defaults) { return nil }
        return attention
    }

    private static func profile(_ index: Int, in profiles: [Profile]) -> (id: String?, label: String?) {
        guard profiles.indices.contains(index) else { return (nil, nil) }
        return (profiles[index].id, profiles[index].label)
    }

    private static func make(configBlocker: LegacyGlobalConfigMigrationBlocker, profiles: [Profile]) -> LegacySettingsAttention? {
        switch configBlocker {
        case .storageUnavailable:
             
            return nil
        case .sourceUnavailable(let index):
            let p = profile(index, in: profiles)
            return .init(kind: .sourceUnavailable(profileID: p.id, label: p.label),
                         message: .format("The profile %@ has no local copy, so its settings could not be checked.", [p.label ?? "?"]),
                         actions: [open(p.id)], emphasised: false)
        case .legacyOverrideReappeared:
            return .init(kind: .legacyConfigReappeared,
                         message: .copy("A previous version's app-wide settings are present alongside the current ones."),
                         actions: [
                            .init(id: "use-previous", title: .copy("Use Previous"), resolution: .useLegacyConfig, destructive: false),
                            .init(id: "discard-previous", title: .copy("Discard Previous"), resolution: .discardLegacyConfig, destructive: true),
                         ], emphasised: false)
        case .semanticMismatch(let index):
            let p = profile(index, in: profiles)
            return .init(kind: .semanticMismatch(profileID: p.id, label: p.label),
                         message: .format("Carrying the settings over would change how the profile %@ runs.", [p.label ?? "?"]),
                         actions: [
                            .init(id: "show-profile", title: .copy("Show Profile"), resolution: .openProfile(id: p.id), destructive: false),
                            .init(id: "keep-as-is", title: .copy("Keep As Is"), resolution: .acknowledge, destructive: false),
                         ], emphasised: false)
        case .conflictingState(let index):
            let p = profile(index, in: profiles)
            return .init(kind: .partialUpgrade(profileID: p.id, label: p.label),
                         message: .format("The settings carry-over stopped partway; the profile %@ is still on the previous layout.", [p.label ?? "?"]),
                         actions: [
                            .init(id: "finish", title: .copy("Finish Carry-over"), resolution: .finishConfigUpgrade, destructive: false),
                            .init(id: "undo", title: .copy("Undo Carry-over"), resolution: .undoConfigUpgrade, destructive: true),
                         ], emphasised: false)
        case .runtimeGenerationFailed(let index):
            let p = profile(index, in: profiles)
            return .init(kind: .profileNotPreparable(profileID: p.id, label: p.label),
                         message: .format("The profile %@ could not be prepared with its settings.", [p.label ?? "?"]),
                         actions: [open(p.id)], emphasised: false)
        case .commitFailed:
            return .init(kind: .commitFailed,
                         message: .copy("The settings carry-over could not be saved; the previous settings are back in place."),
                         actions: [ok], emphasised: false)
        case .rollbackFailed:
            return .init(kind: .rollbackFailed,
                         message: .copy("The settings carry-over was interrupted and could not be undone automatically. Restore a backup before changing profiles."),
                         actions: [ok], emphasised: true)
        }
    }

    private static func make(scriptBlocker: LegacyGlobalScriptMigrationBlocker, profiles: [Profile]) -> LegacySettingsAttention? {
        switch scriptBlocker {
        case .storageUnavailable:
            return nil
        case .sourceUnavailable(let index):
            let p = profile(index, in: profiles)
            return .init(kind: .sourceUnavailable(profileID: p.id, label: p.label),
                         message: .format("The profile %@ has no local copy, so its settings could not be checked.", [p.label ?? "?"]),
                         actions: [open(p.id)], emphasised: false)
        case .conflictingProfile(let index):
            let p = profile(index, in: profiles)
            return .init(kind: .scriptOwnedByProfile(profileID: p.id, label: p.label),
                         message: .format("The profile %@ already has a post-processing script, so the previous version's script was not carried over.", [p.label ?? "?"]),
                         actions: [open(p.id), .init(id: "discard-script", title: .copy("Discard Previous Script"), resolution: .discardLegacyScript, destructive: true)],
                         emphasised: false)
        case .libraryCollision:
            return .init(kind: .scriptLibraryCollision,
                         message: .copy("A script in the library uses the name reserved for the previous version's script."),
                         actions: [.init(id: "show-scripts", title: .copy("Show Scripts"), resolution: .openScripts, destructive: false),
                                   .init(id: "discard-script", title: .copy("Discard Previous Script"), resolution: .discardLegacyScript, destructive: true)],
                         emphasised: false)
        case .runtimeGenerationFailed(let index):
            let p = profile(index, in: profiles)
            return .init(kind: .profileNotPreparable(profileID: p.id, label: p.label),
                         message: .format("The profile %@ could not be prepared with the previous version's script.", [p.label ?? "?"]),
                         actions: [open(p.id), .init(id: "discard-script", title: .copy("Discard Previous Script"), resolution: .discardLegacyScript, destructive: true)],
                         emphasised: false)
        case .semanticMismatch(let index):
            let p = profile(index, in: profiles)
            return .init(kind: .semanticMismatch(profileID: p.id, label: p.label),
                         message: .format("Carrying the script over would change how the profile %@ runs.", [p.label ?? "?"]),
                         actions: [.init(id: "show-profile", title: .copy("Show Profile"), resolution: .openProfile(id: p.id), destructive: false),
                                   .init(id: "keep-as-is", title: .copy("Keep As Is"), resolution: .acknowledge, destructive: false)],
                         emphasised: false)
        case .legacyWriterReappeared:
            return .init(kind: .legacyScriptReappeared,
                         message: .copy("A previous version's app-wide script is present alongside the current one."),
                         actions: [.init(id: "use-previous", title: .copy("Use Previous"), resolution: .useLegacyScript, destructive: false),
                                   .init(id: "discard-previous", title: .copy("Discard Previous"), resolution: .discardLegacyScript, destructive: true)],
                         emphasised: false)
        case .invalidPhase:
            return .init(kind: .scriptStateInvalid,
                         message: .copy("The previous script carry-over left an unknown state."),
                         actions: [.init(id: "retry", title: .copy("Retry"), resolution: .retryScriptUpgrade, destructive: false)],
                         emphasised: false)
        case .commitFailed:
            return .init(kind: .commitFailed,
                         message: .copy("The script carry-over could not be saved; the previous settings are back in place."),
                         actions: [ok], emphasised: false)
        case .rollbackFailed:
            return .init(kind: .rollbackFailed,
                         message: .copy("The script carry-over was interrupted and could not be undone automatically. Restore a backup before changing profiles."),
                         actions: [ok], emphasised: true)
        }
    }

    private static func open(_ profileID: String?) -> Action {
        .init(id: "show-profile", title: .copy("Show Profile"), resolution: .openProfile(id: profileID), destructive: false)
    }
    private static let ok = Action(id: "ok", title: .copy("OK"), resolution: .acknowledge, destructive: false)
}

 
 
enum LegacySettingsResolution: Equatable {
    case openProfile(id: String?)
    case openScripts
    case acknowledge
    case useLegacyConfig
    case discardLegacyConfig
    case finishConfigUpgrade
    case undoConfigUpgrade
    case useLegacyScript
    case discardLegacyScript
    case retryScriptUpgrade
}

 
 
enum LegacySettingsAcknowledgement {
    static let key = "config.global.migrationAttentionAcknowledged"
    static func isAcknowledged(_ id: String, in defaults: UserDefaults) -> Bool {
        (defaults.stringArray(forKey: key) ?? []).contains(id)
    }
    static func acknowledge(_ id: String, in defaults: UserDefaults) {
        var ids = defaults.stringArray(forKey: key) ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        defaults.set(ids, forKey: key)
    }
}

 
 
 
enum LegacySettingsResolver {
    static func perform(
        _ resolution: LegacySettingsResolution,
        attentionID: String,
        workingDirectory: URL,
        defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) -> LegacyClientSettingsMigrationResult? {
        let profileStore = ProfileStore(fileURL: workingDirectory.appendingPathComponent("store/profiles.json"))
        switch resolution {
        case .openProfile, .openScripts:
            return nil
        case .acknowledge:
            LegacySettingsAcknowledgement.acknowledge(attentionID, in: defaults)
            return nil
        case .useLegacyConfig:
             
             
             
             
            let legacy = GlobalConfig.load(from: defaults)
            let legacyPatch = OverridePatch(patchJSON: legacy.patchJSON)
            let keys = Set(legacyPatch.topLevelKeys).intersection(OverridePatch.globalRuntimeKeys)
            if !keys.isEmpty {
                let updated = FlClashRuntimeConfig.replacingGlobalFields(
                    in: FlClashRuntimeConfig.load(from: defaults), with: legacy.patchJSON, keys: keys
                )
                FlClashRuntimeConfig.save(updated, in: defaults)
            }
            LegacyGlobalConfigMigrationMetadata.saveCompletedVersion(nil, in: defaults)
            return rerun(workingDirectory: workingDirectory, defaults: defaults)
        case .discardLegacyConfig:
            GlobalConfig.clear(in: defaults)
            LegacyGlobalConfigMigrationMetadata.saveCompletedVersion(LegacyGlobalConfigMigrationPlan.currentVersion, in: defaults)
            return rerun(workingDirectory: workingDirectory, defaults: defaults)
        case .finishConfigUpgrade:
             
             
            var profiles = profileStore.load()
            let carried = profiles.compactMap(\.migratedGlobalOverride).first ?? GlobalConfig.load(from: defaults)
            for index in profiles.indices where profiles[index].migratedGlobalOverride == nil {
                profiles[index].migratedGlobalOverride = carried
            }
            try? profileStore.save(profiles)
            return rerun(workingDirectory: workingDirectory, defaults: defaults)
        case .undoConfigUpgrade:
            var profiles = profileStore.load()
            for index in profiles.indices { profiles[index].migratedGlobalOverride = nil }
            try? profileStore.save(profiles)
            LegacyGlobalConfigMigrationMetadata.saveCompletedVersion(nil, in: defaults)
            return rerun(workingDirectory: workingDirectory, defaults: defaults)
        case .useLegacyScript:
            LegacyGlobalScriptMigrationMetadata.saveCompletedVersion(nil, in: defaults)
            LegacyGlobalScriptMigrationMetadata.savePhase(nil, in: defaults)
            return rerun(workingDirectory: workingDirectory, defaults: defaults)
        case .discardLegacyScript:
            ScriptSettings.save(enabled: false, body: "", in: defaults)
            LegacyGlobalScriptMigrationMetadata.savePhase(nil, in: defaults)
            LegacyGlobalScriptMigrationMetadata.saveCompletedVersion(LegacyGlobalScriptMigrationPlan.currentVersion, in: defaults)
            return rerun(workingDirectory: workingDirectory, defaults: defaults)
        case .retryScriptUpgrade:
            LegacyGlobalScriptMigrationMetadata.savePhase(nil, in: defaults)
            return rerun(workingDirectory: workingDirectory, defaults: defaults)
        }
    }

     
    static func rerun(workingDirectory: URL, defaults: UserDefaults) -> LegacyClientSettingsMigrationResult {
        let config = LegacyGlobalConfigMigrationCoordinator.run(workingDirectory: workingDirectory, defaults: defaults)
        guard config.userMessage.isEmpty else { return .init(globalConfig: config, globalScript: nil) }
        return .init(globalConfig: config, globalScript: LegacyGlobalScriptMigrationCoordinator.run(workingDirectory: workingDirectory, defaults: defaults))
    }
}
