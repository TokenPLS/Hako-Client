import Foundation

 
 
enum ProxySort: String, CaseIterable, Identifiable {
    case none
    case delay
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Default"
        case .delay: return "Delay"
        case .name: return "Name"
        }
    }

    func apply(members: [String], delays: [String: Int]) -> [String] {
        switch self {
        case .none:
            return members
        case .delay:
            return members.sorted { a, b in
                let da = delays[a] ?? -1
                let db = delays[b] ?? -1
                let testedA = da > 0
                let testedB = db > 0
                if testedA != testedB { return testedA }
                if testedA, da != db { return da < db }
                return a.localizedStandardCompare(b) == .orderedAscending
            }
        case .name:
            return members.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        }
    }

     

    private static let key = "nodes.sort"

    static func load(from defaults: UserDefaults = appGroupDefaults) -> ProxySort {
        defaults.string(forKey: key).flatMap(ProxySort.init(rawValue:)) ?? .none
    }

    func save(in defaults: UserDefaults = ProxySort.appGroupDefaults) {
        defaults.set(rawValue, forKey: Self.key)
    }

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }
}
