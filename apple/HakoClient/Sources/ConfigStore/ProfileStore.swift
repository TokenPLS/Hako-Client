import Foundation

 
final class ProfileStore {
    private static let writeOptions: Data.WritingOptions =
        [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    private let fileURL: URL
    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

     
     
     
     
     
     
    enum State: Equatable {
        case missing
        case unreadable
        case readable([Profile])
    }

    enum StoreError: LocalizedError, Equatable {
        case unreadableStore

        var errorDescription: String? {
            switch self {
            case .unreadableStore:
                return "The profile list could not be read, so it was left untouched. Restore from a backup, or remove the app's data to start over."
            }
        }
    }

    func state() -> State {
        guard fileManager.fileExists(atPath: fileURL.path) else { return .missing }
        guard let data = try? Data(contentsOf: fileURL) else { return .unreadable }
         
         
        guard !data.isEmpty,
              let profiles = try? JSONDecoder().decode([Profile].self, from: data)
        else { return .unreadable }
        return .readable(profiles)
    }

    func load() -> [Profile] {
        if case .readable(let profiles) = state() { return profiles }
        return []
    }

    func save(_ profiles: [Profile]) throws {
         
         
        if case .unreadable = state() { throw StoreError.unreadableStore }
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(profiles)
        try data.write(to: fileURL, options: Self.writeOptions)
    }

    func upsert(_ profile: Profile) throws {
        var profiles = load()
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
        } else {
            profiles.append(profile)
        }
        try save(profiles)
    }

    func remove(id: String) throws {
        try save(load().filter { $0.id != id })
    }
}

 
 
 
 
 
 
 
enum PersonalRulePlacementMigration {
    static let completedKey = "hako.migration.personal-rule-placement.v1"

    static func runIfNeeded(store: ProfileStore, defaults: UserDefaults) {
        guard !defaults.bool(forKey: completedKey) else { return }
        let profiles = store.load()
        let repaired = profiles.map { profile -> Profile in
            guard !profile.override.prependRules else { return profile }
            var profile = profile
            profile.override.prependRules = true
            return profile
        }
        if repaired != profiles {
             
             
            guard (try? store.save(repaired)) != nil else { return }
        }
        defaults.set(true, forKey: completedKey)
    }
}
