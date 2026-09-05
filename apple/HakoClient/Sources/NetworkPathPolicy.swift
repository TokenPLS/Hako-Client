import Combine
import Foundation
import HakoClientUI
import Network

enum NetworkPathStatus: String, Codable, Equatable {
    case unknown
    case satisfied
    case unsatisfied
    case requiresConnection
}

enum NetworkPathInterfaceKind: String, Codable, Equatable {
    case wifi
    case cellular
    case wiredEthernet
    case loopback
    case other
    case unknown

    var title: String {
        switch self {
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        case .wiredEthernet: return "Ethernet"
        case .loopback: return "Loopback"
        case .other: return "Other"
        case .unknown: return "Unknown"
        }
    }
}

 
 
 
struct NetworkPathSnapshot: Codable, Equatable {
    var status: NetworkPathStatus
    var interface: NetworkPathInterfaceKind
    var isExpensive: Bool
    var isConstrained: Bool
    var supportsIPv4: Bool
    var supportsIPv6: Bool
    var supportsDNS: Bool
    var observedAt: Date

    init(
        status: NetworkPathStatus = .unknown,
        interface: NetworkPathInterfaceKind = .unknown,
        isExpensive: Bool = false,
        isConstrained: Bool = false,
        supportsIPv4: Bool = false,
        supportsIPv6: Bool = false,
        supportsDNS: Bool = false,
        observedAt: Date = Date()
    ) {
        self.status = status
        self.interface = interface
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
        self.supportsIPv4 = supportsIPv4
        self.supportsIPv6 = supportsIPv6
        self.supportsDNS = supportsDNS
        self.observedAt = observedAt
    }

    init(path: NWPath, observedAt: Date = Date()) {
        switch path.status {
        case .satisfied: status = .satisfied
        case .unsatisfied: status = .unsatisfied
        case .requiresConnection: status = .requiresConnection
        @unknown default: status = .unknown
        }
        interface = Self.interfaceKind(for: path)
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        supportsIPv4 = path.supportsIPv4
        supportsIPv6 = path.supportsIPv6
        supportsDNS = path.supportsDNS
        self.observedAt = observedAt
    }

     
     
     
    func summaryKeys() -> [String] {
        var parts = [interface.title]
        if isConstrained { parts.append("Low Data") }
        if isExpensive { parts.append("Metered") }
        switch (supportsIPv4, supportsIPv6) {
        case (true, true): parts.append("IPv4 + IPv6")
        case (true, false): parts.append("IPv4-only")
        case (false, true): parts.append("IPv6-only")
        case (false, false): parts.append("No IP route")
        }
        parts.append(supportsDNS ? "DNS" : "No DNS")
        return parts
    }

    func summary(locale: Locale) -> String {
        summaryKeys()
            .map { HakoCopy.string($0, locale: locale) }
            .joined(separator: " · ")
    }

    private static func interfaceKind(for path: NWPath) -> NetworkPathInterfaceKind {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
        if path.usesInterfaceType(.loopback) { return .loopback }
        if path.usesInterfaceType(.other) { return .other }
        return .unknown
    }
}

struct NetworkPathPolicySettings: Equatable {
    static let allowExpensiveUpdatesKey = "network.policy.allowExpensiveUpdates"
    static let allowConstrainedUpdatesKey = "network.policy.allowConstrainedUpdates"

    var allowExpensiveUpdates: Bool
    var allowConstrainedUpdates: Bool

    init(
         
         
         
         
         
         
         
         
        allowExpensiveUpdates: Bool = true,
        allowConstrainedUpdates: Bool = true
    ) {
        self.allowExpensiveUpdates = allowExpensiveUpdates
        self.allowConstrainedUpdates = allowConstrainedUpdates
    }

     
    private static func stored(
        _ key: String,
        in defaults: UserDefaults
    ) -> Bool? {
        defaults.object(forKey: key) == nil ? nil : defaults.bool(forKey: key)
    }

    static func load(
        from defaults: UserDefaults = GlobalConfig.appGroupDefaults
    ) -> NetworkPathPolicySettings {
         
         
         
         
         
         
        NetworkPathPolicySettings(
            allowExpensiveUpdates: stored(allowExpensiveUpdatesKey, in: defaults) ?? true,
            allowConstrainedUpdates: stored(allowConstrainedUpdatesKey, in: defaults) ?? true
        )
    }

    func save(in defaults: UserDefaults = GlobalConfig.appGroupDefaults) {
        defaults.set(allowExpensiveUpdates, forKey: Self.allowExpensiveUpdatesKey)
        defaults.set(allowConstrainedUpdates, forKey: Self.allowConstrainedUpdatesKey)
    }
}

enum NetworkPathPolicyAction: Equatable {
    case allow
    case confirm
    case deferOperation
    case block
}

struct NetworkPathPolicyDecision: Equatable {
    let action: NetworkPathPolicyAction
    let title: String
    let message: String

    var id: String { "\(action)-\(title)-\(message)" }
}

extension NetworkPathPolicyDecision: Identifiable {}

enum NetworkPathPolicy {
    static func automaticRefresh(
        snapshot: NetworkPathSnapshot,
        settings: NetworkPathPolicySettings
    ) -> NetworkPathPolicyDecision {
        if let unavailable = unavailableDecision(snapshot, action: .deferOperation) {
            return unavailable
        }
        if snapshot.isConstrained, !settings.allowConstrainedUpdates {
            return NetworkPathPolicyDecision(
                action: .deferOperation,
                title: "Low Data Mode",
                message: "Automatic subscription and resource updates wait until Low Data Mode is no longer active."
            )
        }
        if snapshot.isExpensive, !settings.allowExpensiveUpdates {
            return NetworkPathPolicyDecision(
                action: .deferOperation,
                title: "Metered Network",
                message: "Automatic subscription and resource updates wait for an unmetered network."
            )
        }
        return NetworkPathPolicyDecision(
            action: .allow,
            title: "Updates Allowed",
            message: snapshot.supportsIPv4
                ? "The current path can run automatic updates."
                : "The IPv6-only path can run automatic updates using system DNS and NAT64 when needed."
        )
    }

     
     
    static func fullTransfer(snapshot: NetworkPathSnapshot) -> NetworkPathPolicyDecision {
        if let unavailable = unavailableDecision(snapshot, action: .block) {
            return unavailable
        }
        if snapshot.isConstrained || snapshot.isExpensive {
            let condition: String
            switch (snapshot.isConstrained, snapshot.isExpensive) {
            case (true, true): condition = "Low Data Mode is active on a metered network"
            case (true, false): condition = "Low Data Mode is active"
            case (false, true): condition = "the current network may charge for data"
            case (false, false): condition = "the current network is restricted"
            }
            return NetworkPathPolicyDecision(
                action: .confirm,
                title: "Use This Network?",
                message: "\(condition). A full test can open many connections and transfer significant data."
            )
        }
        return NetworkPathPolicyDecision(
            action: .allow,
            title: "Network Available",
            message: snapshot.supportsIPv4
                ? "The current path is ready."
                : "The current path is IPv6-only; Clash uses system DNS/NAT64 for compatible destinations."
        )
    }

    private static func unavailableDecision(
        _ snapshot: NetworkPathSnapshot,
        action: NetworkPathPolicyAction
    ) -> NetworkPathPolicyDecision? {
        guard snapshot.status == .satisfied else {
            return NetworkPathPolicyDecision(
                action: action,
                title: "Network Unavailable",
                message: snapshot.status == .unknown
                    ? "Clash has not received a usable network path yet. Try again after the network status appears."
                    : "Connect to a usable network and try again."
            )
        }
        guard snapshot.supportsIPv4 || snapshot.supportsIPv6 else {
            return NetworkPathPolicyDecision(
                action: action,
                title: "No IP Route",
                message: "The current path cannot route IPv4 or IPv6 traffic."
            )
        }
        guard snapshot.supportsDNS else {
            return NetworkPathPolicyDecision(
                action: action,
                title: "DNS Unavailable",
                message: "The current path has no system DNS service, so Clash will not start a hostname-based batch operation."
            )
        }
        return nil
    }
}

 
 
final class NetworkPathObserver: ObservableObject {
    static let shared = NetworkPathObserver()

    @Published private(set) var snapshot: NetworkPathSnapshot

    private let monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "org.example.hako.path-policy", qos: .utility)

    init(initialSnapshot: NetworkPathSnapshot? = nil, startMonitoring: Bool = true) {
        if let initialSnapshot {
            snapshot = initialSnapshot
            monitor = nil
            return
        }


        snapshot = NetworkPathSnapshot()
        guard startMonitoring else {
            monitor = nil
            return
        }
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let value = NetworkPathSnapshot(path: path)
            DispatchQueue.main.async { self?.snapshot = value }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor?.cancel()
    }
}

 
 
enum NetworkPathProbe {
    static func current(timeout: TimeInterval = 2) async -> NetworkPathSnapshot {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let receiver = OneShotReceiver(continuation: continuation, monitor: monitor)
            monitor.pathUpdateHandler = { path in
                receiver.resolve(NetworkPathSnapshot(path: path))
            }
            monitor.start(queue: DispatchQueue.global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                receiver.resolve(NetworkPathSnapshot())
            }
        }
    }

    private final class OneShotReceiver: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<NetworkPathSnapshot, Never>?
        private let monitor: NWPathMonitor

        init(
            continuation: CheckedContinuation<NetworkPathSnapshot, Never>,
            monitor: NWPathMonitor
        ) {
            self.continuation = continuation
            self.monitor = monitor
        }

        func resolve(_ snapshot: NetworkPathSnapshot) {
            lock.lock()
            let continuation = self.continuation
            self.continuation = nil
            lock.unlock()
            guard let continuation else { return }
            monitor.pathUpdateHandler = nil
            monitor.cancel()
            continuation.resume(returning: snapshot)
        }
    }
}
