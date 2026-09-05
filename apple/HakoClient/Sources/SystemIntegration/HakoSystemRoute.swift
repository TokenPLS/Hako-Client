import Foundation

enum HakoSystemRoute: Equatable, Sendable {
    enum VPNAction: String, CaseIterable, Sendable {
        case connect
        case disconnect
        case toggle
    }

    enum RoutingMode: String, CaseIterable, Sendable {
        case rule
        case global
        case direct
    }

    enum Destination: String, CaseIterable, Sendable {
        case overview
        case profiles
        case nodes
        case logs
        case tools
        case home
        case proxies
        case utilities
        case more
    }

    case vpn(VPNAction)
    case mode(RoutingMode)
    case open(Destination)

    var url: URL {
        let pair: (host: String, value: String)
        switch self {
        case .vpn(let action): pair = ("vpn", action.rawValue)
        case .mode(let mode): pair = ("mode", mode.rawValue)
        case .open(let destination): pair = ("open", destination.rawValue)
        }
        var components = URLComponents()
        components.scheme = "hako"
        components.host = pair.host
        components.path = "/\(pair.value)"
         
         
        return components.url!
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "hako",
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil,
              let host = components.host?.lowercased() else { return nil }
        let values = components.path.split(separator: "/", omittingEmptySubsequences: true)
        guard values.count == 1 else { return nil }
        let value = String(values[0]).lowercased()

        switch host {
        case "vpn":
            guard let action = VPNAction(rawValue: value) else { return nil }
            self = .vpn(action)
        case "mode":
            guard let mode = RoutingMode(rawValue: value) else { return nil }
            self = .mode(mode)
        case "open":
            guard let destination = Destination(rawValue: value) else { return nil }
            self = .open(destination)
        default:
            return nil
        }
    }
}

extension Notification.Name {
    static let hakoSystemActionQueued = Notification.Name("HakoSystemActionQueued")
     
     
     
    static let hakoProfileStoreReplaced = Notification.Name("HakoProfileStoreReplaced")
}

 
 
 
struct HakoSystemHandoff {
    static let appGroupIdentifier = HakoAppIdentifiers.appGroup
    static let controlKind = "org.example.hako.vpn-control"

     
     
     
     
     
     
     
     
     
     
    static let controlSymbolName = "hako.cat.fill"

    private enum Key {
        static let pendingRoute = "system.pendingRoute"
        static let pendingRouteAt = "system.pendingRouteAt"
        static let vpnSnapshotActive = "system.vpnSnapshotActive"
    }

     
     
     
     
     
     
     
     
    static let pendingRouteLifetime: TimeInterval = 120

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter

    init(
        defaults: UserDefaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard,
        notificationCenter: NotificationCenter = .default
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    func enqueue(_ route: HakoSystemRoute, at date: Date = Date()) {
        defaults.set(route.url.absoluteString, forKey: Key.pendingRoute)
        defaults.set(date.timeIntervalSinceReferenceDate, forKey: Key.pendingRouteAt)
        notificationCenter.post(name: .hakoSystemActionQueued, object: nil)
    }

    func consume(now: Date = Date()) -> HakoSystemRoute? {
        guard let raw = defaults.string(forKey: Key.pendingRoute) else { return nil }
        let queuedAt = defaults.object(forKey: Key.pendingRouteAt) as? TimeInterval
         
         
        defaults.removeObject(forKey: Key.pendingRoute)
        defaults.removeObject(forKey: Key.pendingRouteAt)
         
         
        guard let queuedAt else { return nil }
         
         
        let age = abs(now.timeIntervalSinceReferenceDate - queuedAt)
        guard age <= Self.pendingRouteLifetime else { return nil }
        guard let url = URL(string: raw) else { return nil }
        return HakoSystemRoute(url: url)
    }

    var isVPNSnapshotActive: Bool {
        defaults.bool(forKey: Key.vpnSnapshotActive)
    }

    func setVPNSnapshot(active: Bool) {
        defaults.set(active, forKey: Key.vpnSnapshotActive)
    }
}

 
 
 
 
 
 
 
enum HakoSystemActionDispatch {
    static var handoff = HakoSystemHandoff()

    static func enqueue(_ route: HakoSystemRoute) {
        handoff.enqueue(route)
    }
}
