import Foundation

 
 
 
 
 
enum LocalDefaultProfileProvisioner {
    static let profileID = "d0000000-0000-4000-8000-000000000001"
    static let fileName = "Clash Direct.yaml"

    static func provisionIfNeeded(
        store: ProfileStore,
        workingDirectory: URL
    ) throws {
        var profiles = store.load()
        let needsProfile = !profiles.contains { $0.id == profileID }
        if needsProfile {
            profiles.append(Profile(
                id: profileID,
                label: "Direct",
                source: .file(fileName),
                autoUpdate: false,
                updateIntervalHours: 24,
                subscriptionInfo: nil,
                selectedMap: [:],
                override: OverrideSpec(),
                activeRevision: nil,
                order: (profiles.map(\.order).max() ?? -1) + 1,
                lastUpdatedAt: nil
            ))
        }

        let source = sourceURL(workingDirectory: workingDirectory)
        let expectedSource = Data(DirectProfileTemplate.yaml.utf8)
        if (try? Data(contentsOf: source)) != expectedSource {
            try FileManager.default.createDirectory(
                at: source.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try expectedSource.write(
                to: source,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        }
        if needsProfile {
            try store.save(profiles)
        }
    }

    static func sourceURL(workingDirectory: URL) -> URL {
        workingDirectory
            .appendingPathComponent("store/\(profileID)", isDirectory: true)
            .appendingPathComponent("source.yaml")
    }
}

 
 
 
enum BundledProfileProvisioner {
    static let legacyFileName = "bundled config.yaml"
    static let automaticUpdateIntervalHours = 12
    private static let legacyProfileIDPrefix = "bundled-subscription-"

    enum ProvisioningError: LocalizedError {
        case invalidSubscriptionURL

        var errorDescription: String? {
            switch self {
            case .invalidSubscriptionURL:
                return "Bundled subscription must be a valid HTTPS URL."
            }
        }
    }

    static func source(subscriptionURLText: String?) throws -> Profile.Source {
        guard let text = subscriptionURLText?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else {
            return .file(legacyFileName)
        }

        guard let components = URLComponents(string: text),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil
        else {
            throw ProvisioningError.invalidSubscriptionURL
        }
        return .url(text)
    }

     
     
    static func repairExistingProfile(
        store: ProfileStore,
        workingDirectory: URL,
        bundledYAML: String,
        subscriptionURLText: String?,
        credentials: CredentialStore = CredentialStore()
    ) throws {
        let bundledSource = try source(subscriptionURLText: subscriptionURLText)
        var profiles = store.load()
        var changed = false

        for index in profiles.indices {
            guard profiles[index].source == .file(legacyFileName) else { continue }

            let sidecar = workingDirectory
                .appendingPathComponent("store/\(profiles[index].id)", isDirectory: true)
                .appendingPathComponent("source.yaml")
            if !FileManager.default.fileExists(atPath: sidecar.path) {
                try FileManager.default.createDirectory(
                    at: sidecar.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try Data(bundledYAML.utf8).write(
                    to: sidecar,
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                )
            }

            if case .url = bundledSource {
                profiles[index].source = bundledSource
                profiles[index].autoUpdate = true
                profiles[index].updateIntervalHours = automaticUpdateIntervalHours
                changed = true
            }
        }

        if changed {
            try store.save(profiles)
        }
    }

     
     
     
     
    static func provisionProfiles(
        store: ProfileStore,
        workingDirectory: URL,
        bundledYAML: String,
        subscriptionURLTexts: [String],
        credentials: CredentialStore = CredentialStore()
    ) throws {
        let texts = subscriptionURLTexts.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        try repairExistingProfile(
            store: store,
            workingDirectory: workingDirectory,
            bundledYAML: bundledYAML,
            subscriptionURLText: texts.first,
            credentials: credentials
        )

        let sources: [Profile.Source]
        if texts.isEmpty {
            sources = [.file(legacyFileName)]
        } else {
            sources = try texts.map { try source(subscriptionURLText: $0) }
        }

        var profiles = store.load()
        var changed = false
        for (offset, source) in sources.enumerated() {
            let sequence = offset + 1
            let stableID = String(
                format: "b0000000-0000-4000-8000-%012d",
                sequence
            )
            let label = sequence == 1 ? "Bundled" : "Bundled \(sequence)"

             
             
             
            let legacyID = "\(legacyProfileIDPrefix)\(sequence)"
            let beforeLegacyMigration = profiles.count
            profiles.removeAll { $0.id == legacyID }
            if profiles.count != beforeLegacyMigration { changed = true }

            let duplicates = profiles.indices.filter { profiles[$0].source == source }
            if duplicates.count > 1 {
                 
                 
                 
                 
                let survivor = duplicates.max { lhs, rhs in
                    duplicatePriority(profiles[lhs], stableID: stableID)
                        < duplicatePriority(profiles[rhs], stableID: stableID)
                }!
                let survivorID = profiles[survivor].id
                profiles.removeAll { $0.source == source && $0.id != survivorID }
                changed = true
            }

            let profileIndex: Int
            if let existing = profiles.firstIndex(where: { $0.source == source }) {
                profileIndex = existing
            } else if let existing = profiles.firstIndex(where: { $0.id == stableID }) {
                profiles[existing].source = source
                profiles[existing].autoUpdate = {
                    if case .url = source { return true }
                    return false
                }()
                profiles[existing].updateIntervalHours = automaticUpdateIntervalHours
                changed = true
                profileIndex = existing
            } else {
                let nextOrder = (profiles.map(\.order).max() ?? -1) + 1
                profiles.append(Profile(
                    id: stableID,
                    label: label,
                    source: source,
                    autoUpdate: {
                        if case .url = source { return true }
                        return false
                    }(),
                    updateIntervalHours: automaticUpdateIntervalHours,
                    subscriptionInfo: nil,
                    selectedMap: [:],
                    override: OverrideSpec(),
                    activeRevision: nil,
                    order: nextOrder,
                    lastUpdatedAt: nil
                ))
                changed = true
                profileIndex = profiles.count - 1
            }

            if sequence == 1 {
                try writeSidecarIfMissing(
                    bundledYAML,
                    profileID: profiles[profileIndex].id,
                    workingDirectory: workingDirectory
                )
                let sidecar = workingDirectory
                    .appendingPathComponent(
                        "store/\(profiles[profileIndex].id)",
                        isDirectory: true
                    )
                    .appendingPathComponent("source.yaml")
            }
        }
        if changed { try store.save(profiles) }
    }

    private static func duplicatePriority(_ profile: Profile, stableID: String) -> Int {
        if profile.activeRevision != nil { return 2 }
        if profile.id == stableID { return 1 }
        return 0
    }

     
     
    static func provisionExistingProfileIfNeeded(
        container: URL,
        bundle: Bundle = .main
    ) throws {
        guard let configURL = bundle.url(forResource: "config", withExtension: "yaml") else {
            return
        }
        let bundledYAML = try String(contentsOf: configURL, encoding: .utf8)
        let working = container.appendingPathComponent("working", isDirectory: true)
        let store = ProfileStore(
            fileURL: working.appendingPathComponent("store/profiles.json")
        )
        try provisionProfiles(
            store: store,
            workingDirectory: working,
            bundledYAML: bundledYAML,
            subscriptionURLTexts: subscriptionURLTexts(in: bundle)
        )
    }

    static func bundledSource(bundle: Bundle = .main) throws -> Profile.Source {
        try source(subscriptionURLText: subscriptionURLTexts(in: bundle).first)
    }

     
     
     
    static func bundledSequence(
        for source: Profile.Source,
        subscriptionURLTexts: [String]
    ) -> Int? {
        let texts = subscriptionURLTexts.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        let sources: [Profile.Source]
        if texts.isEmpty {
            sources = [.file(legacyFileName)]
        } else {
            sources = texts.compactMap { try? self.source(subscriptionURLText: $0) }
        }
        return sources.firstIndex(of: source).map { $0 + 1 }
    }

    static func bundledSequence(
        for source: Profile.Source,
        bundle: Bundle = .main
    ) -> Int? {
        bundledSequence(for: source, subscriptionURLTexts: subscriptionURLTexts(in: bundle))
    }

    private static func subscriptionURLTexts(in bundle: Bundle) -> [String] {
        let resources = (bundle.urls(forResourcesWithExtension: "url", subdirectory: nil) ?? [])
            .compactMap { url -> (Int, URL)? in
                let name = url.deletingPathExtension().lastPathComponent
                if name == "subscription" { return (1, url) }
                guard name.hasPrefix("subscription-"),
                      let sequence = Int(name.dropFirst("subscription-".count)),
                      sequence > 1 else { return nil }
                return (sequence, url)
            }
            .sorted { $0.0 < $1.0 }
        return resources.compactMap { try? String(contentsOf: $0.1, encoding: .utf8) }
    }

    private static func writeSidecarIfMissing(
        _ yaml: String,
        profileID: String,
        workingDirectory: URL
    ) throws {
        let sidecar = workingDirectory
            .appendingPathComponent("store/\(profileID)", isDirectory: true)
            .appendingPathComponent("source.yaml")
        guard !FileManager.default.fileExists(atPath: sidecar.path) else { return }
        try FileManager.default.createDirectory(
            at: sidecar.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(yaml.utf8).write(
            to: sidecar,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

}
