import Foundation

 
 
 
 
 
 
 
 
 
extension ClientUserAgent {
     
    static func resolved(d: UserDefaults = appGroupDefaults) -> String {
        let patch = OverridePatch(
            patchJSON: FlClashRuntimeConfig.load(from: d).patchJSON
        )
        if let ua = sanitized(patch.globalUA) { return ua }
        let legacyPatch = OverridePatch(
            patchJSON: GlobalConfig.load(from: d).patchJSON
        )
        if let ua = sanitized(legacyPatch.globalUA) { return ua }
        return preset(from: d).value
    }

     
     
    static func explicitValue(
        for profile: Profile,
        runtimeOverride: OverrideSpec = FlClashRuntimeConfig.load(),
        legacyGlobalOverride: OverrideSpec = GlobalConfig.load()
    ) -> String? {
        if let runtime = sanitized(
            OverridePatch(
                patchJSON: runtimeOverride.patchJSON
            ).globalUA
        ) {
            return runtime
        }
        let effectiveGlobal = profile.migratedGlobalOverride ?? legacyGlobalOverride
        if let migrated = sanitized(
            OverridePatch(patchJSON: effectiveGlobal.patchJSON).globalUA
        ) {
            return migrated
        }
        return sanitized(OverridePatch(patchJSON: profile.override.patchJSON).globalUA)
    }

    static func resolved(
        profile: Profile,
        d: UserDefaults = appGroupDefaults,
        legacyGlobalOverride: OverrideSpec = GlobalConfig.load()
    ) -> String {
        explicitValue(
            for: profile,
            runtimeOverride: FlClashRuntimeConfig.load(from: d),
            legacyGlobalOverride: legacyGlobalOverride
        )
            ?? preset(from: d).value
    }
}
