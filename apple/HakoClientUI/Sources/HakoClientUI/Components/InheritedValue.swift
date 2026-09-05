import Foundation

 
public enum InheritedSource: Equatable, Codable, Sendable {
     
    case override
     
    case profile
     
     
     
    case overall
     
    case upstreamDefault
     
     
     
     
    case unknown
}

 
 
 
 
 
 
public enum InheritedBase: Equatable, Codable, Sendable {
     
    case profile(Bool)
     
    case overall(Bool)
     
    case unset
     
    case unknown

    public var value: Bool? {
        switch self {
        case .profile(let v), .overall(let v): return v
        case .unset, .unknown: return nil
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
public enum UpstreamBoolDefault {
    public static let table: [String: PinnedDefault<Bool>] = [
        "ipv6": .init(true),                           
         
         
         
         
         
         
         
         
         
         
         
        "unified-delay": .init(true, owner: .hako, upstreamValue: false),
        "tcp-concurrent": .init(false),
        "disable-keep-alive": .init(false),
        "ntp.enable": .init(false),
        "sniffer.enable": .init(false),
        "sniffer.force-dns-mapping": .init(true),      
        "sniffer.parse-pure-ip": .init(true),
        "sniffer.override-destination": .init(true),   
        "tun.strict-route": .init(false),
        "tun.endpoint-independent-nat": .init(false),
        "experimental.quic-go-disable-gso": .init(false),
        "experimental.quic-go-disable-ecn": .init(true),   
        "experimental.dialer-ip4p-convert": .init(false),
         
         
         
         
         
         
         
         
         
        "profile.store-fake-ip": .init(true, owner: .hako, upstreamValue: false),
         
        "dns.prefer-h3": .init(false),
        "dns.ipv6": .init(false),
        "dns.use-hosts": .init(true),
        "dns.use-system-hosts": .init(true),
        "dns.respect-rules": .init(false),
        "dns.fallback-lazy-query": .init(false),
        "dns.direct-nameserver-follow-policy": .init(false),
        "dns.fallback-filter.geoip": .init(true),       
    ]

     
     
     
     
    public static func value(for keyPath: String) -> Bool {
        guard let value = table[keyPath]?.value else {
            preconditionFailure("no upstream default pinned for \(keyPath) — add it to UpstreamBoolDefault.table")
        }
        return value
    }

     
     
    public static func pinned(for keyPath: String) -> PinnedDefault<Bool> {
        guard let pinned = table[keyPath] else {
            preconditionFailure("no upstream default pinned for \(keyPath) — add it to UpstreamBoolDefault.table")
        }
        return pinned
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct InheritedBool: Equatable {
     
    public let base: InheritedBase
     
    public let override: Bool?
     
    public let upstreamDefault: Bool
     
     
     
    public let defaultOwner: UpstreamDefaultOwner

    public init(base: InheritedBase, override: Bool?, upstreamDefault: Bool) {
        self.base = base
        self.override = override
        self.upstreamDefault = upstreamDefault
        defaultOwner = .mihomo
    }

     
     
    public init(base: InheritedBase, override: Bool?, upstreamDefault pinned: PinnedDefault<Bool>) {
        self.base = base
        self.override = override
        upstreamDefault = pinned.value ?? false
        defaultOwner = pinned.owner
    }

    public var resolved: Bool {
        override ?? base.value ?? upstreamDefault
    }

    public var source: InheritedSource {
        if override != nil { return .override }
        switch base {
        case .profile: return .profile
        case .overall: return .overall
        case .unset: return .upstreamDefault
        case .unknown: return .unknown
        }
    }

     
     
     
    public var inherited: Bool {
        base.value ?? upstreamDefault
    }

     
     
     
     
     
     
     
     
     

     
     
    public var profileDisagrees: Bool {
        guard let override, case .profile(let v) = base else { return false }
        return v != override
    }

     
     
     
     
     
     
     
    public var adoptProfileValueTitle: HakoDisplayText { .copy("Use the profile's value") }

     
     
     
     
     
     

     
     
    public var primaryTitle: HakoDisplayText {
        if case .unknown = source { return .copy("Not read yet") }
        return .copy(Self.word(resolved))
    }

     
    public var sourceLine: HakoDisplayText {
        switch source {
        case .profile:
            return .copy("From profile")
        case .overall:
            return .copy("Same as overall")
        case .upstreamDefault:
            return defaultOwner.sourceCopy
        case .unknown:
            return .copy("Profile not read")
        case .override:
            switch base {
            case .profile(let v):
                return .formatCopy("Overridden · profile says %@", [Self.word(v)])
            case .overall(let v):
                return .formatCopy("Overridden · overall is %@", [Self.word(v)])
            case .unset:
                return .copy("Overridden · not in profile")
            case .unknown:
                return .copy("Overridden · profile not read")
            }
        }
    }

     
     
     
     
     
     
     
     
    public var followTitle: HakoDisplayText {
        switch base {
        case .overall:
            return .formatCopy("Same as overall (%@)", [Self.word(inherited)])
        case .profile:
            return .formatCopy("Follow profile (%@)", [Self.word(inherited)])
        case .unset:
            return defaultOwner.followBoolCopy(Self.word(inherited))
        case .unknown:
            return .copy("Clear this override")
        }
    }

    public static func word(_ value: Bool) -> String {
        value ? "On" : "Off"
    }

}


 

 
 
 
 
 
 
 
 
 
 
 
public enum UpstreamDefaultOwner: Equatable, Codable, Sendable {
    case mihomo, hako, sing

     
     
     
     
    public var sourceCopy: HakoDisplayText {
        switch self {
        case .mihomo: return .copy("Core default")
        case .hako: return .copy("App default")
        case .sing: return .copy("Stack default")
        }
    }

     
     
     
    public func sentinelCopy(empty: Bool) -> HakoDisplayText {
        switch (self, empty) {
        case (.mihomo, false): return .copy("Core default · 0 in profile means default")
        case (.mihomo, true): return .copy("Core default · empty in profile means default")
        case (.hako, false): return .copy("App default · 0 in profile means default")
        case (.hako, true): return .copy("App default · empty in profile means default")
        case (.sing, false): return .copy("Stack default · 0 in profile means default")
        case (.sing, true): return .copy("Stack default · empty in profile means default")
        }
    }

     
     
     
     
     
     
    public func followBoolCopy(_ word: String) -> HakoDisplayText {
        switch self {
        case .mihomo: return .formatCopy("Follow core default (%@)", [word])
        case .hako: return .formatCopy("Follow app default (%@)", [word])
        case .sing: return .formatCopy("Follow stack default (%@)", [word])
        }
    }

    public func followCopy(_ value: String?) -> HakoDisplayText {
        switch (self, value) {
        case (.mihomo, let v?): return .format("Follow core default (%@)", [v])
        case (.mihomo, nil): return .copy("Follow core default")
        case (.hako, let v?): return .format("Follow app default (%@)", [v])
        case (.hako, nil): return .copy("Follow app default")
        case (.sing, let v?): return .format("Follow stack default (%@)", [v])
        case (.sing, nil): return .copy("Follow stack default")
        }
    }
}

 
 
 
 
 
public struct PinnedDefault<Value: Equatable & Sendable>: Equatable, Sendable {
    public let value: Value?
    public let owner: UpstreamDefaultOwner
     
     
     
     
     
     
     
    public let sentinelMeansDefault: Bool
     
     
     
     
    public let upstreamValue: Value?
    public init(
        _ value: Value?,
        owner: UpstreamDefaultOwner = .mihomo,
        sentinelMeansDefault: Bool = false,
        upstreamValue: Value? = nil
    ) {
        self.value = value
        self.owner = owner
        self.sentinelMeansDefault = sentinelMeansDefault
        self.upstreamValue = upstreamValue
    }
}

 

 
public enum InheritedTextBase: Equatable, Codable, Sendable {
    case profile(String)
     
     
     
    case profileUsesDefault
    case unset
     
    case unknown
    public var value: String? { if case .profile(let v) = self { return v }; return nil }
}

 
 
 
 
 
 
 
 
public struct InheritedText: Equatable {
    public let base: InheritedTextBase
    public let override: String?
    public let pinned: PinnedDefault<String>

     
     
    public init(base: InheritedTextBase, override: String?, upstreamDefault pinned: PinnedDefault<String>) {
        self.base = base
        self.override = override
        self.pinned = pinned
    }
    public var upstreamDefault: String? { pinned.value }
    public var defaultOwner: UpstreamDefaultOwner { pinned.owner }

     
     
     
     
     
    public var effectiveOverride: String? {
        guard let override else { return nil }
        if override.isEmpty, pinned.sentinelMeansDefault { return nil }
        return override
    }

    public var resolved: String? { effectiveOverride ?? base.value ?? upstreamDefault }
    public var inherited: String? { base.value ?? upstreamDefault }

     
     
     
    public var profileDisagrees: Bool {
        guard let effectiveOverride else { return false }
        switch base {
        case .profile(let v): return v != effectiveOverride
        case .profileUsesDefault: return effectiveOverride != upstreamDefault
        case .unset, .unknown: return false
        }
    }

    public var adoptProfileValueTitle: HakoDisplayText { .copy("Use the profile's value") }

    public var source: InheritedSource {
        if effectiveOverride != nil { return .override }
        if case .profile = base { return .profile }
        if case .unknown = base { return .unknown }
        return .upstreamDefault
    }

    public var primaryTitle: HakoDisplayText {
        if case .unknown = source { return .copy("Not read yet") }
        return resolved.map(HakoDisplayText.verbatim) ?? defaultOwner.sourceCopy
    }

    public var sourceLine: HakoDisplayText {
         
         
        if let typed = typedSentinelLine { return typed }
        switch source {
        case .profile: return .copy("From profile")
        case .overall: return .copy("Same as overall")
        case .upstreamDefault:
            if case .profileUsesDefault = base { return defaultOwner.sentinelCopy(empty: true) }
            return defaultOwner.sourceCopy
        case .unknown:
            return .copy("Profile not read")
        case .override:
            if case .profile(let v) = base { return .format("Overridden · profile says %@", [v]) }
            if case .unknown = base { return .copy("Overridden · profile not read") }
            return .copy("Overridden · not in profile")
        }
    }

     
     
     
    private var typedSentinelLine: HakoDisplayText? {
        guard override != nil, effectiveOverride == nil else { return nil }
        return resolved.map { .format("Empty means default · now %@", [$0]) } ?? .copy("Empty means default")
    }

     
     
     
    public var emptyHint: String {
        if case .unknown = base { return "" }
        return inherited ?? ""
    }

    public var followTitle: HakoDisplayText {
        switch base {
        case .profile(let v): return .format("Follow profile (%@)", [v])
        case .unset, .profileUsesDefault: return defaultOwner.followCopy(upstreamDefault)
        case .unknown: return .copy("Clear this override")
        }
    }

}

public enum InheritedNumberBase: Equatable, Codable, Sendable {
    case profile(Int)
     
     
    case profileUsesDefault
    case unset
     
    case unknown
    public var value: Int? { if case .profile(let v) = self { return v }; return nil }
}

 
public struct InheritedNumber: Equatable {
    public let base: InheritedNumberBase
    public let override: Int?
    public let pinned: PinnedDefault<Int>

    public init(base: InheritedNumberBase, override: Int?, upstreamDefault pinned: PinnedDefault<Int>) {
        self.base = base
        self.override = override
        self.pinned = pinned
    }
    public var upstreamDefault: Int? { pinned.value }
    public var defaultOwner: UpstreamDefaultOwner { pinned.owner }

     
     
     
     
    public var effectiveOverride: Int? {
        guard let override else { return nil }
        if override == 0, pinned.sentinelMeansDefault { return nil }
        return override
    }

    public var resolved: Int? { effectiveOverride ?? base.value ?? upstreamDefault }
    public var inherited: Int? { base.value ?? upstreamDefault }

     
    public var profileDisagrees: Bool {
        guard let effectiveOverride else { return false }
        switch base {
        case .profile(let v): return v != effectiveOverride
        case .profileUsesDefault: return effectiveOverride != upstreamDefault
        case .unset, .unknown: return false
        }
    }

    public var adoptProfileValueTitle: HakoDisplayText { .copy("Use the profile's value") }

    public var source: InheritedSource {
        if effectiveOverride != nil { return .override }
        if case .profile = base { return .profile }
        if case .unknown = base { return .unknown }
        return .upstreamDefault
    }

    public var primaryTitle: HakoDisplayText {
        if case .unknown = source { return .copy("Not read yet") }
        return resolved.map { .verbatim(String($0)) } ?? defaultOwner.sourceCopy
    }

    public var sourceLine: HakoDisplayText {
         
        if let typed = typedSentinelLine { return typed }
        switch source {
        case .profile: return .copy("From profile")
        case .overall: return .copy("Same as overall")
        case .upstreamDefault:
            if case .profileUsesDefault = base { return defaultOwner.sentinelCopy(empty: false) }
            return defaultOwner.sourceCopy
        case .unknown:
            return .copy("Profile not read")
        case .override:
            if case .profile(let v) = base { return .format("Overridden · profile says %@", [String(v)]) }
            if case .unknown = base { return .copy("Overridden · profile not read") }
            return .copy("Overridden · not in profile")
        }
    }

     
     
     
    private var typedSentinelLine: HakoDisplayText? {
        guard override != nil, effectiveOverride == nil else { return nil }
        return resolved.map { .format("0 means default · now %@", [String($0)]) } ?? .copy("0 means default")
    }

    public var emptyHint: String {
        if case .unknown = base { return "" }
        return inherited.map(String.init) ?? ""
    }

    public var followTitle: HakoDisplayText {
        switch base {
        case .profile(let v): return .format("Follow profile (%@)", [String(v)])
        case .unset, .profileUsesDefault: return defaultOwner.followCopy(upstreamDefault.map(String.init))
        case .unknown: return .copy("Clear this override")
        }
    }

}


 
 
 
 
 
 
public enum UpstreamTextDefault {
    public static let table: [String: PinnedDefault<String>] = [
        "log-level": PinnedDefault("info"),                  
        "geosite-matcher": PinnedDefault("succinct", sentinelMeansDefault: true),  
        "ntp.server": PinnedDefault("time.apple.com"),       
        "ntp.dialer-proxy": PinnedDefault(nil, sentinelMeansDefault: true),  
         
        "dns.enhanced-mode": PinnedDefault("redir-host"),                    
        "dns.fake-ip-filter-mode": PinnedDefault("blacklist"),               
         
        "dns.cache-algorithm": PinnedDefault("lru", sentinelMeansDefault: true),
        "dns.fake-ip-range": PinnedDefault("198.18.0.1/16"),                 
         
        "dns.fake-ip-range6": PinnedDefault(nil, sentinelMeansDefault: true),
    ]
    public static func pinned(for keyPath: String) -> PinnedDefault<String> {
        guard let entry = table[keyPath] else {
            preconditionFailure("no upstream default pinned for \(keyPath) — add it to UpstreamTextDefault.table")
        }
        return entry
    }
    public static func value(for keyPath: String) -> String? { pinned(for: keyPath).value }
}

 
 
 
 
public enum UpstreamNumberDefault {
    public static let table: [String: PinnedDefault<Int>] = [
         
         
        "keep-alive-idle": PinnedDefault(300, owner: .hako, sentinelMeansDefault: true),
        "keep-alive-interval": PinnedDefault(75, owner: .hako, sentinelMeansDefault: true),
        "ntp.port": PinnedDefault(123),                          
        "ntp.interval": PinnedDefault(30),                       
         
         
         
        "dns.ipv6-timeout": PinnedDefault(100),                  
         
        "dns.fake-ip-ttl": PinnedDefault(1, sentinelMeansDefault: true),
         
        "dns.cache-max-size": PinnedDefault(4096, sentinelMeansDefault: true),
         
         
         
         
        "tun.udp-timeout": PinnedDefault(300, owner: .sing, sentinelMeansDefault: true),
    ]
    public static func pinned(for keyPath: String) -> PinnedDefault<Int> {
        guard let entry = table[keyPath] else {
            preconditionFailure("no upstream default pinned for \(keyPath) — add it to UpstreamNumberDefault.table")
        }
        return entry
    }
    public static func value(for keyPath: String) -> Int? { pinned(for: keyPath).value }
}
