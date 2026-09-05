import Foundation

 
 
 
 
 
enum GeoResource: String, CaseIterable, Identifiable {
    case geoip
    case geosite
    case mmdb
    case asn

    var id: String { rawValue }

     
    var title: String {
        switch self {
        case .geoip: return "GEOIP"
        case .geosite: return "GEOSITE"
        case .mmdb: return "MMDB"
        case .asn: return "ASN"
        }
    }

     
    var fileName: String {
        switch self {
        case .geoip: return "GeoIP.dat"
        case .geosite: return "GeoSite.dat"
        case .mmdb: return "geoip.metadb"
        case .asn: return "ASN.mmdb"
        }
    }

     
    var planKind: String { rawValue }

    var defaultURL: String {
         
         
         
        let base = "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest"
        switch self {
        case .geoip: return "\(base)/geoip.dat"
        case .geosite: return "\(base)/geosite.dat"
        case .mmdb: return "\(base)/geoip.metadb"
        case .asn: return "\(base)/GeoLite2-ASN.mmdb"
        }
    }
}

 
 
enum GeoResourceSettings {
    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }

    private static func urlKey(_ resource: GeoResource) -> String {
        "geo.url.\(resource.rawValue)"
    }
    static let autoUpdateKey = "geo.autoUpdate"
    static let intervalKey = "geo.autoUpdateIntervalHours"
    private static let lastSyncKey = "geo.lastSyncAt"

    static func url(for resource: GeoResource,
                    from defaults: UserDefaults = appGroupDefaults) -> String {
        guard let stored = defaults.string(forKey: urlKey(resource)),
              isValidURL(stored) else {
            return resource.defaultURL
        }
        return stored
    }

     
    @discardableResult
    static func setURL(_ raw: String, for resource: GeoResource,
                       in defaults: UserDefaults = appGroupDefaults) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            defaults.removeObject(forKey: urlKey(resource))
            return true
        }
        guard isValidURL(trimmed) else { return false }
        defaults.set(trimmed, forKey: urlKey(resource))
        return true
    }

    static func isValidURL(_ raw: String) -> Bool {
        guard let components = URLComponents(string: raw) else { return false }
         
         
        let scheme = components.scheme?.lowercased()
        return (scheme == "https" || scheme == "http") && !(components.host ?? "").isEmpty
    }

     

    static func autoUpdateEnabled(from defaults: UserDefaults = appGroupDefaults) -> Bool {
        defaults.bool(forKey: autoUpdateKey)
    }

    static func autoUpdateIntervalHours(from defaults: UserDefaults = appGroupDefaults) -> Int {
        let stored = defaults.integer(forKey: intervalKey)
        return stored > 0 ? stored : 24
    }

    static func setAutoUpdate(enabled: Bool, intervalHours: Int,
                              in defaults: UserDefaults = appGroupDefaults) {
        defaults.set(enabled, forKey: autoUpdateKey)
        defaults.set(max(1, intervalHours), forKey: intervalKey)
    }

    static func lastSync(from defaults: UserDefaults = appGroupDefaults) -> Date? {
        defaults.object(forKey: lastSyncKey) as? Date
    }

    static func recordSync(at date: Date = Date(),
                           in defaults: UserDefaults = appGroupDefaults) {
        defaults.set(date, forKey: lastSyncKey)
    }

    static func isAutoUpdateDue(enabled: Bool, intervalHours: Int,
                                lastSync: Date?, now: Date) -> Bool {
        guard enabled else { return false }
        guard let lastSync else { return true }
        return lastSync.addingTimeInterval(TimeInterval(intervalHours) * 3600) <= now
    }
}

 
enum GeoResourceInventory {
    struct Entry {
        let resource: GeoResource
        let sizeBytes: Int?
        let updatedAt: Date?
    }

    static func scan(homeDir: URL) -> [Entry] {
        GeoResource.allCases.map { resource in
            let url = homeDir.appendingPathComponent(resource.fileName)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) else {
                return Entry(resource: resource, sizeBytes: nil, updatedAt: nil)
            }
            return Entry(resource: resource,
                         sizeBytes: (attributes[.size] as? NSNumber)?.intValue,
                         updatedAt: attributes[.modificationDate] as? Date)
        }
    }
}
