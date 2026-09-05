import Foundation
import HakoClientKit

 
 
 
 
 
 
 
 
 
struct HakoTVSubscription: Codable, Equatable, Identifiable {
     
     
     
    let requestURL: URL
    let name: String
     
     
     
    let updatedAt: Date?

    init(requestURL: URL, name: String, updatedAt: Date? = nil) {
        self.requestURL = requestURL
        self.name = name
        self.updatedAt = updatedAt
    }

     
     
    var id: URL { requestURL }

     
     
    var displayURL: URL { requestURL }

     
    var title: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return displayURL.host ?? displayURL.absoluteString
    }
}

 
 
enum HakoTVSubscriptionEditError: Error, Equatable, LocalizedError {
     
    case addressAlreadyRemembered(String)

     
     
     
    var errorDescription: String? {
        switch self {
        case .addressAlreadyRemembered(let name):
            String(localized: "This address is already in the list, as “\(name)”.")
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVSubscriptionStore {
    static let key = "hako.tv.subscriptions"
    static let currentKey = "hako.tv.subscriptions.current"

    private let defaults: UserDefaults
    private(set) var subscriptions: [HakoTVSubscription]
     
     
    private var chosenID: HakoTVSubscription.ID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([HakoTVSubscription].self, from: data) {
             
             
             
             
            var seen = Set<HakoTVSubscription.ID>()
            subscriptions = decoded.filter { seen.insert($0.id).inserted }
        } else {
            subscriptions = []
        }
        chosenID = defaults.string(forKey: Self.currentKey).flatMap(URL.init(string:))
    }

     
     
    var current: HakoTVSubscription? {
        subscriptions.first { $0.id == chosenID } ?? subscriptions.last
    }

     
     
     
     
     
    mutating func add(urlString: String, name: String) throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw ProfileValidationError.invalidRemoteURL
        }
        _ = try Profile.RemoteSource(requestURL: url)
        if let index = subscriptions.firstIndex(where: { $0.id == url }) {
            let typedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !typedName.isEmpty {
                subscriptions[index] = HakoTVSubscription(
                    requestURL: url, name: name, updatedAt: subscriptions[index].updatedAt
                )
            }
        } else {
            subscriptions.append(HakoTVSubscription(requestURL: url, name: name))
        }
        chosenID = url
        persist()
    }

     
     
    mutating func use(_ id: HakoTVSubscription.ID) {
        guard subscriptions.contains(where: { $0.id == id }) else { return }
        chosenID = id
        persist()
    }

     
     
     
    mutating func rename(_ id: HakoTVSubscription.ID, to name: String) {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        let existing = subscriptions[index]
        subscriptions[index] = HakoTVSubscription(
            requestURL: existing.requestURL,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: existing.updatedAt
        )
        persist()
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    mutating func edit(_ id: HakoTVSubscription.ID, name: String, urlString: String) throws -> Bool {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return false }
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw ProfileValidationError.invalidRemoteURL
        }
        _ = try Profile.RemoteSource(requestURL: url)
        guard url != subscriptions[index].requestURL else {
            rename(id, to: name)
            return false
        }
        if let other = subscriptions.first(where: { $0.id == url }) {
            throw HakoTVSubscriptionEditError.addressAlreadyRemembered(other.title)
        }
        subscriptions[index] = HakoTVSubscription(
            requestURL: url,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: nil
        )
        if chosenID == id { chosenID = url }
        persist()
        return true
    }

     
     
    mutating func markUpdated(_ id: HakoTVSubscription.ID, at date: Date) {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        let existing = subscriptions[index]
        subscriptions[index] = HakoTVSubscription(requestURL: existing.requestURL, name: existing.name, updatedAt: date)
        persist()
    }

     
     
    mutating func remove(_ id: HakoTVSubscription.ID) {
        guard let index = subscriptions.firstIndex(where: { $0.id == id }) else { return }
        subscriptions.remove(at: index)
        if chosenID == id { chosenID = nil }
        persist()
    }

     
     
     
     
     
     
    static func stageFixture() -> HakoTVSubscriptionStore {
        let suite = "hako.tv.stage.subscriptions"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        var store = HakoTVSubscriptionStore(defaults: defaults)
        try? store.add(urlString: "https://sub.example.com/clash/home", name: "Home")
        try? store.add(urlString: "https://example.net/api/v1/client/subscribe", name: "")
        try? store.add(urlString: "https://backup.example.com/sub", name: "Backup line")
        store.use(URL(string: "https://sub.example.com/clash/home")!)
        return store
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(subscriptions) {
            defaults.set(data, forKey: Self.key)
        }
        if let chosenID {
            defaults.set(chosenID.absoluteString, forKey: Self.currentKey)
        } else {
            defaults.removeObject(forKey: Self.currentKey)
        }
    }
}

 
 
 
 
 
enum HakoTVSubscriptionUpdatedWords {
    static func text(updatedAt: Date?, now: Date = Date()) -> String {
        guard let updatedAt else {
            return String(localized: "Not yet updated")
        }
        if now.timeIntervalSince(updatedAt) < 60 {
            return String(localized: "Updated just now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return String(localized: "Updated \(formatter.localizedString(for: updatedAt, relativeTo: now))")
    }
}
