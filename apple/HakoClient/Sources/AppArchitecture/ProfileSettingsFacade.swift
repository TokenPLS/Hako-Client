import Foundation

enum ProfilePostMergeScriptOwnershipError: LocalizedError, Equatable {
    case duplicateWriters

    var errorDescription: String? {
        switch self {
        case .duplicateWriters:
            return "Migrate the previous app-wide script before enabling a profile script."
        }
    }
}

 
 
 
enum ProfilePostMergeScriptOwnershipPolicy {
    static func validate(
        postMergeScriptID: String?,
        legacyGlobalScriptEnabled: Bool
    ) throws {
        guard postMergeScriptID == nil || !legacyGlobalScriptEnabled else {
            throw ProfilePostMergeScriptOwnershipError.duplicateWriters
        }
    }
}

 
 
 
 
 
struct ProfileSettingsSnapshot: Equatable {
    var override: OverrideSpec
    var overwriteMode: Profile.OverwriteMode?
    var selectedScriptID: String?
    var postMergeScriptID: String?
    var customOverwrite: CustomOverwriteSpec?
    var proxyChain: ProxyChainSpec?
    var legacyRelayMigrations: [LegacyRelayMigration]?
    var migratedGlobalOverride: OverrideSpec?
    var outboundMode: Profile.OutboundMode?
}

protocol ProfileSettingsAccessing {
    func snapshot(for profile: Profile) -> ProfileSettingsSnapshot
    func applying(
        _ settings: ProfileSettingsSnapshot,
        to profile: Profile
    ) -> Profile
}

 
 
 
 
 
 
struct ProfileSettingsFacade: ProfileSettingsAccessing {
    func snapshot(for profile: Profile) -> ProfileSettingsSnapshot {
        ProfileSettingsSnapshot(
            override: profile.override,
            overwriteMode: profile.overwriteMode,
            selectedScriptID: profile.selectedScriptID,
            postMergeScriptID: profile.postMergeScriptID,
            customOverwrite: profile.customOverwrite,
            proxyChain: profile.proxyChain,
            legacyRelayMigrations: profile.legacyRelayMigrations,
            migratedGlobalOverride: profile.migratedGlobalOverride,
            outboundMode: profile.outboundMode
        )
    }

    func applying(
        _ settings: ProfileSettingsSnapshot,
        to profile: Profile
    ) -> Profile {
        var updated = profile
        updated.override = settings.override
        updated.overwriteMode = settings.overwriteMode
        updated.selectedScriptID = settings.selectedScriptID
        updated.postMergeScriptID = settings.postMergeScriptID
        updated.customOverwrite = settings.customOverwrite
        updated.proxyChain = settings.proxyChain
        updated.legacyRelayMigrations = settings.legacyRelayMigrations
        updated.migratedGlobalOverride = settings.migratedGlobalOverride
        updated.outboundMode = settings.outboundMode
        return updated
    }
}
