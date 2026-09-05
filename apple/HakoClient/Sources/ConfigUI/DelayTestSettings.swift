import Foundation

 
 
 
 
enum DelayTestSettings {
    static let defaultURL = "https://www.gstatic.com/generate_204"
    static let key = "nodes.delayTestURL"

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }

    static func url(from defaults: UserDefaults = appGroupDefaults) -> String {
        guard let stored = defaults.string(forKey: key), isValid(stored) else {
            return defaultURL
        }
        return stored
    }

     
     
    @discardableResult
    static func setURL(_ raw: String, in defaults: UserDefaults = appGroupDefaults) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: key)
            return true
        }
        guard isValid(trimmed) else { return false }
        defaults.set(trimmed, forKey: key)
        return true
    }

     
     
     
     
     
     
     
     
    static func isValid(_ raw: String) -> Bool {
        guard let components = URLComponents(string: raw) else { return false }
        let scheme = components.scheme?.lowercased()
        return (scheme == "https" || scheme == "http")
            && !(components.host ?? "").isEmpty
    }
}
