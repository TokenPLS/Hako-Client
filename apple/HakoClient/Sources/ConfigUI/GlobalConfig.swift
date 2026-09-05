import Foundation

 
 
 
enum GlobalConfig {
    private static let key = "config.global"

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }

    static func load(from defaults: UserDefaults = appGroupDefaults) -> OverrideSpec {
        guard let data = defaults.data(forKey: key),
              let spec = try? JSONDecoder().decode(OverrideSpec.self, from: data) else {
            return OverrideSpec()
        }
        return spec
    }

    static func save(_ spec: OverrideSpec, in defaults: UserDefaults = appGroupDefaults) {
        guard let data = try? JSONEncoder().encode(spec) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(in defaults: UserDefaults = appGroupDefaults) {
        defaults.removeObject(forKey: key)
    }
}

 
 
 
 
 
 
 
 
enum FlClashRuntimeConfig {
    private static let key = "config.runtime.flclash.v1"

    static func isInitialized(
        in defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) -> Bool {
        defaults.object(forKey: key) != nil
    }

    static func load(
        from defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) -> OverrideSpec {
        stored(in: defaults) ?? OverrideSpec()
    }

    static func save(
        _ spec: OverrideSpec,
        in defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) {
        guard let data = try? JSONEncoder().encode(normalized(spec)) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    static func clear(
        in defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) {
        defaults.removeObject(forKey: key)
    }

     
     
     
     
     
    @discardableResult
    static func migrateIfNeeded(
        preferredProfile: Profile?,
        legacyGlobalOverride: OverrideSpec,
        defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) -> OverrideSpec {
        if let current = stored(in: defaults) {
            GlobalConfig.clear(in: defaults)
            return current
        }

        let migrated = migrated(
            preferredProfile: preferredProfile,
            legacyGlobalOverride: legacyGlobalOverride
        )
        save(migrated, in: defaults)
        if load(from: defaults) == migrated {
            GlobalConfig.clear(in: defaults)
        }
        return migrated
    }

     
     
    static func migrated(
        preferredProfile: Profile?,
        legacyGlobalOverride: OverrideSpec
    ) -> OverrideSpec {
        var migrated = normalized(legacyGlobalOverride)
        if let legacyProfileLayer = preferredProfile?.migratedGlobalOverride {
            migrated = overlayingGlobalFields(
                in: migrated,
                with: legacyProfileLayer
            )
        }
        if let profile = preferredProfile {
            migrated = overlayingGlobalFields(
                in: migrated,
                with: OverrideSpec(
                    patchJSON: profile.override.patchJSON
                )
            )
            if let mode = profile.outboundMode {
                var patch = OverridePatch(patchJSON: migrated.patchJSON)
                patch.mode = mode.rawValue
                migrated.patchJSON = patch.patchJSON
            }
        }
        return normalized(migrated)
    }

     

     
    static let promotionMarkerKey = "config.runtime.flclash.promotion.v1"
     
     
     
     
    static let promotionNoticeKey = "override.scope.promotion.v1.notice"
     
    static let promotedNamespaces: Set<String> = ["experimental", "profile"]

     
     
     
     
     
     
     
     
    @discardableResult
    static func promoteNamespacesIfNeeded(
        profiles: [Profile],
        activeProfileID: String?,
        defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) -> Int {
        guard defaults.object(forKey: promotionMarkerKey) == nil else { return 0 }
        let active = profiles.first { $0.id == activeProfileID }
        var runtime = load(from: defaults)
        var runtimePatch = OverridePatch(patchJSON: runtime.patchJSON)
        var promoted = false
        if let active {
            let activePatch = OverridePatch(patchJSON: active.override.patchJSON)
            for namespace in promotedNamespaces.sorted()
            where runtimePatch.retainingTopLevelKeys([namespace]).patchJSON.isEmpty
                && !activePatch.retainingTopLevelKeys([namespace]).patchJSON.isEmpty {
                runtimePatch.overlayTopLevelKeys([namespace], from: activePatch)
                promoted = true
            }
        }
         
         
         
        var discarded = 0
        for profile in profiles where profile.id != active?.id {
            let patch = OverridePatch(patchJSON: profile.override.patchJSON)
            for key in ["quic-go-disable-gso", "quic-go-disable-ecn", "dialer-ip4p-convert"]
            where (patch.experimentalGet(key) as Bool?) != nil {
                discarded += 1
            }
            if (patch.profileGet("store-fake-ip") as Bool?) != nil { discarded += 1 }
        }
        if promoted {
            runtime.patchJSON = runtimePatch.patchJSON
            save(runtime, in: defaults)
        }
        if discarded > 0 { defaults.set(discarded, forKey: promotionNoticeKey) }
        defaults.set(true, forKey: promotionMarkerKey)
        return discarded
    }

    static func replacingGlobalFields(
        in current: OverrideSpec,
        with sourcePatchJSON: String,
        keys: Set<String>
    ) -> OverrideSpec {
        var updated = normalized(current)
        var patch = OverridePatch(patchJSON: updated.patchJSON)
        patch.replaceTopLevelKeys(
            keys.intersection(OverridePatch.globalRuntimeKeys),
            with: OverridePatch(patchJSON: sourcePatchJSON)
        )
        updated.patchJSON = patch.patchJSON
        return updated
    }

    static func sanitizedProfile(_ profile: Profile) -> Profile {
        var sanitized = profile
        sanitized.override.patchJSON = OverridePatch(
            patchJSON: profile.override.patchJSON
        ).profileOwnedPatch.patchJSON
        sanitized.migratedGlobalOverride = rulesOnly(
            profile.migratedGlobalOverride
        )
        sanitized.outboundMode = nil
        return sanitized
    }

    private static func overlayingGlobalFields(
        in current: OverrideSpec,
        with source: OverrideSpec
    ) -> OverrideSpec {
        var updated = normalized(current)
        var patch = OverridePatch(patchJSON: updated.patchJSON)
        patch.overlayTopLevelKeys(
            OverridePatch.globalRuntimeKeys,
            from: OverridePatch(patchJSON: source.patchJSON)
        )
        updated.patchJSON = patch.patchJSON
        return updated
    }

    private static func normalized(_ spec: OverrideSpec) -> OverrideSpec {
        var normalized = spec
        normalized.patchJSON = OverridePatch(
            patchJSON: spec.patchJSON
        ).globalRuntimePatch.patchJSON
        normalized.disabledGlobalRules = nil
        normalized.disabledAppendRules = nil
        normalized.appendRuleComments = nil
        normalized.appendRules = []
         
         
         
        normalized.prependRules = OverrideSpec().prependRules
        return normalized
    }

     
     
     
     
     
     
     
     
     
     
     
    private static func rulesOnly(_ spec: OverrideSpec?) -> OverrideSpec? {
        guard let spec, !spec.appendRules.isEmpty else { return nil }
        return OverrideSpec(
            appendRules: spec.appendRules,
            prependRules: spec.prependRules
        )
    }

    private static func stored(
        in defaults: UserDefaults
    ) -> OverrideSpec? {
        guard let data = defaults.data(forKey: key),
              let spec = try? JSONDecoder().decode(
                  OverrideSpec.self,
                  from: data
              ) else {
            return nil
        }
        return normalized(spec)
    }
}
