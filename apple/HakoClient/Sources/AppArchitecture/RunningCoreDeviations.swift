import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum RunningCoreDeviations {

     
     
     
     
     
     
     
     
    static func fields(for capabilities: [ConfigurationCapabilityID]) -> [String] {
        capabilities
            .flatMap { capability in
                ConfigurationSurfaceCatalog.configCapabilities
                    .first { $0.id == capability }?.sourceKeys ?? []
            }
            .flatMap { [$0, $0 + "."] }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    static func report(
        profile: Profile,
        sidecarYAML: String?,
        locale: Locale,
        appWide: OverrideSpec = GlobalConfig.load(),
        runtime: OverrideSpec = FlClashRuntimeConfig.load()
    ) -> ConfigDeviationReport? {
        guard let sidecarYAML else { return nil }
        guard let finished = try? ProfileRuntimeConfigBuilder.buildProductionStages(
            raw: sidecarYAML, profile: profile,
            runtimeOverride: runtime, globalOverride: appWide, applyProxyChain: false
        ).finished() else { return nil }
        guard let report = try? ConfigTransforms.configDeviations(
            configContent: finished,
            targetProfile: hakoAppleRuntimeProfile.rawValue
        ) else { return nil }

         
         
         
         
         
        guard let handed = handedToCore(
            profile: profile, sidecarYAML: sidecarYAML, appWide: appWide, runtime: runtime
        ) else {
            return report
        }
        let mine = ClientDocumentDeviations.rows(
            written: sidecarYAML, running: handed, locale: locale
        )
         
         
         
        let spoken = Set(report.deviations.map(\.configKey))

         
         
         
         
         
         
         
         
        let platformDecides = Self.keysThePlatformDecides()
        let reconciled = mine.map { row -> ConfigDeviation in
            guard platformDecides.contains(row.configKey) else { return row }
            var fixed = row
            fixed.isAppWide = false
            fixed.forceUnrecoverable()
            return fixed
        }
        return report.appending(reconciled.filter { !spoken.contains($0.configKey) })
    }

     
     
     
    static func keysThePlatformDecides() -> Set<String> {
        let bare = """
        mode: direct
        proxies: []
        proxy-groups: []
        rules:
            - MATCH,DIRECT
        """
        guard let report = try? ConfigTransforms.configDeviations(
            configContent: bare, targetProfile: hakoAppleRuntimeProfile.rawValue
        ) else { return [] }
        return Set(
            report.deviations
                .filter { $0.category == .forced && !$0.recoverable }
                .map(\.configKey)
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func baseDocument(profile: Profile, sidecarYAML: String?) -> String? {
        guard let sidecarYAML else { return nil }
        var bare = profile
        bare.override = OverrideSpec()
        return try? ProfileRuntimeConfigBuilder.buildProductionStages(
            raw: sidecarYAML, profile: bare, applyProxyChain: false
        ).afterClientTransforms
    }

     
     
     
     
     
     
     
     
     
     
     
     
    static func handedToCore(
        profile: Profile,
        sidecarYAML: String,
        appWide: OverrideSpec = GlobalConfig.load(),
        runtime: OverrideSpec = FlClashRuntimeConfig.load()
    ) -> String? {
        var bare = profile
        bare.override = OverrideSpec()
        return try? ProfileRuntimeConfigBuilder.buildProductionStages(
            raw: sidecarYAML, profile: bare,
            runtimeOverride: runtime, globalOverride: appWide, applyProxyChain: false
        ).finished()
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    static func activeProfileReport(locale: Locale = .current) -> ConfigDeviationReport? {
        guard let container = HakoAppIdentifiers.appGroupContainer,
              let store = try? ConfigResourceStore(containerURL: container),
              let identity = try? store.activeIdentity(),
              let profile = ProfileStore(
                  fileURL: container
                      .appendingPathComponent("working/store/profiles.json")
              ).load().first(where: { $0.id == identity.profileID })
        else { return nil }
        return report(profile: profile, sidecarYAML: sidecarYAML(for: profile), locale: locale)
    }

     
     
     
    static func sidecarYAML(for profile: Profile) -> String? {
        guard let container = HakoAppIdentifiers.appGroupContainer else { return nil }
        return try? String(
            contentsOf: container.appendingPathComponent("working/store/\(profile.id)/source.yaml"),
            encoding: .utf8
        )
    }

     
     
     
    static func key(profile: Profile, sidecarYAML: String?) -> String {
        "\(profile.id)|\(profile.override.patchJSON.count)|\(profile.override.patchJSON.hashValue)|\(sidecarYAML?.count ?? 0)"
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func taskKey(for profile: Profile) -> String {
        var stamp = "absent"
        if let container = HakoAppIdentifiers.appGroupContainer {
            let path = container
                .appendingPathComponent("working/store/\(profile.id)/source.yaml")
                .path
            var status = stat()
            if stat(path, &status) == 0 {
                stamp = "\(status.st_size)|\(status.st_mtimespec.tv_sec).\(status.st_mtimespec.tv_nsec)"
            }
        }
        return "\(profile.id)|\(profile.override.patchJSON.count)|\(profile.override.patchJSON.hashValue)|\(stamp)"
    }
}
