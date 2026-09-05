import Foundation

 
 
 
 
 
 
 
public enum InheritedListBase: Equatable, Codable, Sendable {
     
    case profile([String])
     
    case unset
     
     
     
     
    case unknown

    public var values: [String] {
        switch self {
        case .profile(let entries): return entries
        case .unset, .unknown: return []
        }
    }
}

 
 
 
 
 
 
 
 
 
public enum UpstreamListDefault {
     
     
     
     
    public static let table: [String: PinnedDefault<[String]>] = [
        "tun.route-address": PinnedDefault([]),
        "tun.route-exclude-address": PinnedDefault([]),
        "tun.route-address-set": PinnedDefault([]),
        "tun.route-exclude-address-set": PinnedDefault([]),
        "tun.inet6-address": PinnedDefault(["fdfe:dcba:9876::1/126"]),    
        "tun.loopback-address": PinnedDefault([]),
         
         
         
        "dns.nameserver": PinnedDefault(["https://doh.pub/dns-query", "tls://223.5.5.5:853"]),
        "dns.default-nameserver": PinnedDefault(["114.114.114.114", "223.5.5.5", "8.8.8.8", "1.0.0.1"]),
        "dns.fake-ip-filter": PinnedDefault(["dns.msftnsci.com", "www.msftnsci.com", "www.msftconnecttest.com"]),
        "dns.fallback": PinnedDefault([]),
        "dns.proxy-server-nameserver": PinnedDefault([]),
        "dns.direct-nameserver": PinnedDefault([]),
        "dns.fallback-filter.geosite": PinnedDefault([]),
        "dns.fallback-filter.ipcidr": PinnedDefault([]),
        "dns.fallback-filter.domain": PinnedDefault([]),
         
         
         
        "sniffer.force-domain": PinnedDefault([]),
        "sniffer.skip-domain": PinnedDefault([]),
        "sniffer.skip-src-address": PinnedDefault([]),
        "sniffer.skip-dst-address": PinnedDefault([]),
        "sniffer.port-whitelist": PinnedDefault([]),
        "sniffer.sniffing": PinnedDefault([]),
    ]

    public static func pinned(for keyPath: String) -> PinnedDefault<[String]> {
        guard let entry = table[keyPath] else {
            preconditionFailure("no upstream default pinned for \(keyPath) — add it to UpstreamListDefault.table")
        }
        return entry
    }
    public static func value(for keyPath: String) -> [String] { pinned(for: keyPath).value ?? [] }
}

public struct InheritedList: Equatable {
    public let base: InheritedListBase
     
    public let override: [String]?
     
     
     
     
    public let pinned: PinnedDefault<[String]>

    public init(base: InheritedListBase, override: [String]?, upstreamDefault pinned: PinnedDefault<[String]>) {
        self.base = base
        self.override = override
        self.pinned = pinned
    }
     
     
    public var upstreamDefault: [String] { pinned.value ?? [] }
    public var defaultOwner: UpstreamDefaultOwner { pinned.owner }

    public var resolved: [String] {
        if let override { return override }
        switch base {
        case .profile(let entries): return entries
        case .unset, .unknown: return upstreamDefault
        }
    }

     
    public var inherited: [String] {
        switch base {
        case .profile(let entries): return entries
        case .unset, .unknown: return upstreamDefault
        }
    }

     
     
     
    public var profileDisagrees: Bool {
        guard let override, case .profile(let entries) = base else { return false }
        return entries != override
    }

    public var adoptProfileValueTitle: HakoDisplayText { .copy("Use the profile's value") }

    public var source: InheritedSource {
        if override != nil { return .override }
        switch base {
        case .profile: return .profile
        case .unset: return .upstreamDefault
        case .unknown: return .unknown
        }
    }

     
    public var primaryTitle: HakoDisplayText {
        if case .unknown = source { return .copy("Not read yet") }
        return .format("%@ entries", [String(resolved.count)])
    }

     
    public var sourceLine: HakoDisplayText {
        switch source {
        case .profile:
            return .format("From profile · %@ entries", [String(base.values.count)])
        case .upstreamDefault, .overall:
             
             
            return defaultOwner.listSourceCopy(entries: upstreamDefault.count)
        case .unknown:
             
             
             
            return .copy("Profile not read")
        case .override:
            switch base {
            case .profile(let entries):
                return .format("Overridden · profile has %@ entries", [String(entries.count)])
            case .unset:
                return .copy("Overridden · not in profile")
            case .unknown:
                return .copy("Overridden · profile not read")
            }
        }
    }

     
     
     
     
     
     
    public var followTitle: HakoDisplayText {
        switch base {
        case .profile:
            return .format("Follow profile (%@ entries)", [String(inherited.count)])
        case .unset:
            return defaultOwner.listFollowCopy(entries: inherited.count)
        case .unknown:
             
             
            return .copy("Follow profile")
        }
    }
}

 
 
 
 
extension UpstreamDefaultOwner {
    public func listSourceCopy(entries: Int) -> HakoDisplayText {
        switch self {
        case .mihomo: return .format("Core default · %@ entries", [String(entries)])
        case .hako: return .format("App default · %@ entries", [String(entries)])
        case .sing: return .format("Stack default · %@ entries", [String(entries)])
        }
    }
    public func listFollowCopy(entries: Int) -> HakoDisplayText {
        switch self {
        case .mihomo: return .format("Follow core default (%@ entries)", [String(entries)])
        case .hako: return .format("Follow app default (%@ entries)", [String(entries)])
        case .sing: return .format("Follow stack default (%@ entries)", [String(entries)])
        }
    }
}
