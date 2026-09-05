import Darwin
import Foundation

 
 
 
enum NodeSwitchSettings {
    static let key = "nodes.autoCloseOnSwitch"

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }

    static func autoCloseOnSwitch(from defaults: UserDefaults = appGroupDefaults) -> Bool {
        defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }

    static func setAutoCloseOnSwitch(_ enabled: Bool,
                                     in defaults: UserDefaults = appGroupDefaults) {
        defaults.set(enabled, forKey: key)
    }
}

 
 
enum IntranetAddress {
    static func current() -> String? {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return nil }
        defer { freeifaddrs(pointer) }

        var fallback: String?
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = entry.pointee
            guard let addr = interface.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET),
                  (Int32(interface.ifa_flags) & IFF_LOOPBACK) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                              &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let name = String(cString: interface.ifa_name)
            let address = String(cString: host)
            if name == "en0" { return address }
            if fallback == nil, !name.hasPrefix("utun") { fallback = address }
        }
        return fallback
    }
}

 
 
 
 
enum UDPFallbackSettings {
    static let key = "udp.fallbackPolicy"

     
     
    static let fallbackDefault: UDPFallbackPolicy = .quic

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }

     
     
    static func policy(
        from defaults: UserDefaults = appGroupDefaults
    ) -> UDPFallbackPolicy {
        guard let raw = defaults.string(forKey: key),
              let parsed = UDPFallbackPolicy(rawValue: raw)
        else { return fallbackDefault }
        return parsed
    }

    static func setPolicy(
        _ policy: UDPFallbackPolicy,
        in defaults: UserDefaults = appGroupDefaults
    ) {
        defaults.set(policy.rawValue, forKey: key)
    }

     
    static func resolved(
        profile: UDPFallbackPolicy?,
        global: UDPFallbackPolicy
    ) -> UDPFallbackPolicy {
        profile ?? global
    }
}
