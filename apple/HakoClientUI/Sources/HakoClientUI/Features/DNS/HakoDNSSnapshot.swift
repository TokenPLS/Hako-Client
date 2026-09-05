import Foundation

public enum HakoDNSTriState:
    String,
    CaseIterable,
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    case inherited
    case on
    case off

    public var id: String { rawValue }

    public var boolValue: Bool? {
        switch self {
        case .inherited:
            nil
        case .on:
            true
        case .off:
            false
        }
    }

    public init(bool: Bool?) {
        switch bool {
        case .none:
            self = .inherited
        case .some(true):
            self = .on
        case .some(false):
            self = .off
        }
    }
}

public enum HakoDNSPolicyMatchKind:
    String,
    CaseIterable,
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    case domain
    case geosite
    case ruleSet

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .domain:
            "Domain"
        case .geosite:
            "geosite"
        case .ruleSet:
            "rule-set"
        }
    }

    public var summary: String {
        switch self {
        case .domain:
            "One domain, or a wildcard such as +.example.com."
        case .geosite:
            "A category from the active GeoSite database."
        case .ruleSet:
            "A rule provider declared by this profile."
        }
    }

    public var placeholder: String {
        switch self {
        case .domain:
            "+.example.com"
        case .geosite:
            "cn"
        case .ruleSet:
            "my-rules"
        }
    }

    private var prefix: String {
        switch self {
        case .domain:
            ""
        case .geosite:
            "geosite:"
        case .ruleSet:
            "rule-set:"
        }
    }

    public static func split(
        _ key: String
    ) -> (kind: HakoDNSPolicyMatchKind, value: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        for kind in [HakoDNSPolicyMatchKind.geosite, .ruleSet]
        where trimmed.hasPrefix(kind.prefix) {
            return (
                kind,
                String(trimmed.dropFirst(kind.prefix.count))
            )
        }
        return (.domain, trimmed)
    }

    public static func key(
        kind: HakoDNSPolicyMatchKind,
        value: String
    ) -> String {
        kind.prefix
            + value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct HakoDNSPolicyEntry:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public var key: String
    public var resolvers: [String]

    public var id: String { key }

    public init(key: String, resolvers: [String]) {
        self.key = key
        self.resolvers = resolvers
    }
}

 
 
 
 
 
 
 
 
public enum HakoDNSLocalMappingEffect: Codable, Equatable, Sendable {
    case inEffect
     
    case resolvesElsewhere(actual: [String])
    case tunnelNotRunning
    case notYetApplied
    case nameNotResolved
}

public struct HakoDNSLocalMapping:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public var domain: String
    public var addresses: [String]
     
     
    public var effect: HakoDNSLocalMappingEffect?

    public var id: String { domain }

    public init(
        domain: String,
        addresses: [String],
        effect: HakoDNSLocalMappingEffect? = nil
    ) {
        self.domain = domain
        self.addresses = addresses
        self.effect = effect
    }
}

 
 
public struct HakoDNSOverrideDraft: Codable, Equatable, Sendable {
    public static let inheritedMode = "__inherited__"
    public static let dnsModes = [
        inheritedMode,
        "normal",
        "fake-ip",
        "redir-host",
    ]
    public static let fakeIPFilterModes = [
        inheritedMode,
        "blacklist",
        "whitelist",
        "rule",
    ]
    public static let cacheAlgorithms = [
        inheritedMode,
        "lru",
        "arc",
    ]

    public var overrideDNS: Bool
    public var preferH3: HakoDNSTriState
    public var ipv6: HakoDNSTriState
    public var ipv6Timeout: String
    public var useHosts: HakoDNSTriState
    public var useSystemHosts: HakoDNSTriState
    public var respectRules: HakoDNSTriState
    public var fallbackLazyQuery: HakoDNSTriState
    public var enhancedMode: String
    public var fakeIPRange: String
    public var fakeIPRange6: String
    public var fakeIPFilter: [String]
    public var fakeIPFilterMode: String
    public var fakeIPTTL: String
    public var defaultNameserver: [String]
    public var nameserverPolicy: [HakoDNSPolicyEntry]
    public var nameserver: [String]
    public var fallback: [String]
    public var proxyServerNameserver: [String]
    public var proxyServerNameserverPolicy: [HakoDNSPolicyEntry]
    public var directNameserver: [String]
    public var directNameserverFollowPolicy: HakoDNSTriState
    public var cacheAlgorithm: String
    public var cacheMaxSize: String
    public var filterGeoIP: HakoDNSTriState
    public var filterGeoIPCode: String
    public var filterGeosite: [String]
    public var filterIPCIDR: [String]
    public var filterDomain: [String]

    public init(
        overrideDNS: Bool = false,
        enhancedMode: String = HakoDNSOverrideDraft.inheritedMode,
        nameserver: [String] = [],
        nameserverPolicy: [HakoDNSPolicyEntry] = [],
        fakeIPFilter: [String] = [],
        filterGeoIP: HakoDNSTriState = .inherited,
        filterGeoIPCode: String = "",
        preferH3: HakoDNSTriState = .inherited,
        ipv6: HakoDNSTriState = .inherited,
        ipv6Timeout: String = "",
        useHosts: HakoDNSTriState = .inherited,
        useSystemHosts: HakoDNSTriState = .inherited,
        respectRules: HakoDNSTriState = .inherited,
        fallbackLazyQuery: HakoDNSTriState = .inherited,
        fakeIPRange: String = "",
        fakeIPRange6: String = "",
        fakeIPFilterMode: String =
            HakoDNSOverrideDraft.inheritedMode,
        fakeIPTTL: String = "",
        defaultNameserver: [String] = [],
        fallback: [String] = [],
        proxyServerNameserver: [String] = [],
        proxyServerNameserverPolicy: [HakoDNSPolicyEntry] = [],
        directNameserver: [String] = [],
        directNameserverFollowPolicy: HakoDNSTriState = .inherited,
        cacheAlgorithm: String =
            HakoDNSOverrideDraft.inheritedMode,
        cacheMaxSize: String = "",
        filterGeosite: [String] = [],
        filterIPCIDR: [String] = [],
        filterDomain: [String] = []
    ) {
        self.overrideDNS = overrideDNS
        self.preferH3 = preferH3
        self.ipv6 = ipv6
        self.ipv6Timeout = ipv6Timeout
        self.useHosts = useHosts
        self.useSystemHosts = useSystemHosts
        self.respectRules = respectRules
        self.fallbackLazyQuery = fallbackLazyQuery
        self.enhancedMode = enhancedMode
        self.fakeIPRange = fakeIPRange
        self.fakeIPRange6 = fakeIPRange6
        self.fakeIPFilter = fakeIPFilter
        self.fakeIPFilterMode = fakeIPFilterMode
        self.fakeIPTTL = fakeIPTTL
        self.defaultNameserver = defaultNameserver
        self.nameserverPolicy = nameserverPolicy
        self.nameserver = nameserver
        self.fallback = fallback
        self.proxyServerNameserver = proxyServerNameserver
        self.proxyServerNameserverPolicy =
            proxyServerNameserverPolicy
        self.directNameserver = directNameserver
        self.directNameserverFollowPolicy =
            directNameserverFollowPolicy
        self.cacheAlgorithm = cacheAlgorithm
        self.cacheMaxSize = cacheMaxSize
        self.filterGeoIP = filterGeoIP
        self.filterGeoIPCode = filterGeoIPCode
        self.filterGeosite = filterGeosite
        self.filterIPCIDR = filterIPCIDR
        self.filterDomain = filterDomain
    }

    public var scalarValidationError: String? {
        for (label, text) in [
            ("IPv6 timeout", ipv6Timeout),
            ("Fake-IP TTL", fakeIPTTL),
            ("Cache size", cacheMaxSize),
        ] where !text.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let value = Int(text), value >= 0 else {
                return "\(label) must be a non-negative whole number."
            }
        }
        for (label, entries) in [
            ("Nameserver policy", nameserverPolicy),
            ("Proxy-server policy", proxyServerNameserverPolicy),
        ] {
            var keys = Set<String>()
            for entry in entries {
                let key = entry.key.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !key.isEmpty,
                      keys.insert(key).inserted,
                      !entry.resolvers.isEmpty
                else {
                    return "Every \(label.lowercased()) entry needs a unique match and resolver."
                }
            }
        }
        return nil
    }

     
     
     
     
     
    public struct Inherited: Sendable, Equatable {
        public var proxyServerNameserverCount: Int

        public init(proxyServerNameserverCount: Int = 0) {
            self.proxyServerNameserverCount = proxyServerNameserverCount
        }

        public static let none = Inherited()
    }

     
     
     
     
     
    public func crossFieldValidationError(inherited: Inherited) -> String? {
        let drafted = proxyServerNameserver.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let merged = drafted.count + inherited.proxyServerNameserverCount
        if respectRules == .on, merged == 0 {
             
            return "Respect rules needs at least one proxy-server nameserver."
        }
        if !proxyServerNameserverPolicy.isEmpty, merged == 0 {
             
            return "A proxy-server policy needs at least one proxy-server nameserver."
        }
        return nil
    }
}

 
 
 
 
 
 
 
 
public enum HakoDNSRuleProviders: Equatable, Sendable {
    case unknown
     
     
     
    case known([String: String])
}

public enum HakoDNSPolicyKey {
     
     
     
     
     
     
    public static func rejectionReason(
        _ key: String,
        ruleProviders: HakoDNSRuleProviders = .unknown
    ) -> HakoDisplayText? {
         
         
         
         
         
        let raw = key
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .copy("A match is required.")
        }
         
        let lowered = raw.lowercased()
        for prefix in ["geosite:", "rule-set:"] where lowered.hasPrefix(prefix) {
            let names = String(raw.dropFirst(prefix.count))
                .split(separator: ",", omittingEmptySubsequences: false)
                .map(String.init)
            guard !names.isEmpty, names.allSatisfy({ !$0.isEmpty }) else {
                return .format("%@ needs a name after it.", [prefix])
            }
            guard prefix == "rule-set:",
                  case .known(let declared) = ruleProviders
            else { return nil }
             
            if let missing = names.first(where: { declared[$0] == nil }) {
                return .format("No rule provider named %@ is declared.", [missing])
            }
             
            if let addresses = names.first(where: { declared[$0] == "ipcidr" }) {
                return .format(
                    "%@ matches addresses, not domains, so DNS cannot use it.",
                    [addresses]
                )
            }
            return nil
        }
         
        let domains = raw
            .split(separator: ",", omittingEmptySubsequences: false)
            .map(String.init)
        guard !domains.isEmpty, domains.allSatisfy({ !$0.isEmpty }) else {
            return .copy("A match is required.")
        }
        for domain in domains where !isValidDomain(domain) {
            return .format("%@ is not a valid domain.", [domain])
        }
        return nil
    }

     
     
     
    static func isValidDomain(_ domain: String) -> Bool {
        guard !domain.isEmpty, !domain.hasSuffix(".") else { return false }
        if domain.first?.isWhitespace == true { return false }
        if domain.last?.isWhitespace == true { return false }
        let parts = domain.lowercased().split(
            separator: ".",
            omittingEmptySubsequences: false
        )
        guard parts.count > 1 else { return !parts.isEmpty && !parts[0].isEmpty }
        return parts.dropFirst().allSatisfy { !$0.isEmpty }
    }
}

public struct HakoDNSResolverPreset:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let name: String
    public let address: String
    public let bootstrapServers: [String]

    public var id: String { address }

    public init(
        name: String,
        address: String,
        bootstrapServers: [String] = []
    ) {
        self.name = name
        self.address = address
        self.bootstrapServers = bootstrapServers
    }
}

public enum HakoDNSResolverOutcome:
    Codable,
    Equatable,
    Sendable
{
    case reachable(milliseconds: Int)
    case timedOut
    case refused
    case handshakeFailed
    case invalidReply
    case notTestable(reason: String)

    public var isReachable: Bool {
        if case .reachable = self {
            true
        } else {
            false
        }
    }
}

public enum HakoDNSBootstrapAddress {
     
     
    public static func isPlainIP(_ address: String) -> Bool {
        var v4 = in_addr()
        var v6 = in6_addr()
        return address.withCString {
            inet_pton(AF_INET, $0, &v4) == 1
                || inet_pton(AF_INET6, $0, &v6) == 1
        }
    }
}

public enum HakoDNSResolverCatalog {
    public static let presets: [HakoDNSResolverPreset] =
        makePresets()

     
     
     
    public static let bootstrapPresets: [HakoDNSResolverPreset] = {
        var seen = Set<String>()
        return makePresets().flatMap { preset in
            preset.bootstrapServers.compactMap { address in
                guard HakoDNSBootstrapAddress.isPlainIP(address),
                      seen.insert(address).inserted else {
                    return nil
                }
                return HakoDNSResolverPreset(
                    name: preset.name,
                    address: address,
                    bootstrapServers: []
                )
            }
        }
    }()

    public static func ranked(
        _ presets: [HakoDNSResolverPreset],
        by results: [String: HakoDNSResolverOutcome]
    ) -> [HakoDNSResolverPreset] {
        presets.enumerated().sorted { lhs, rhs in
            let lhsDelay = measuredDelay(results[lhs.element.address])
            let rhsDelay = measuredDelay(results[rhs.element.address])
            switch (lhsDelay, rhsDelay) {
            case let (lhsDelay?, rhsDelay?) where lhsDelay != rhsDelay:
                return lhsDelay < rhsDelay
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    private static func measuredDelay(
        _ outcome: HakoDNSResolverOutcome?
    ) -> Int? {
        guard case .reachable(let milliseconds) = outcome else {
            return nil
        }
        return milliseconds
    }


     
     
     
     
     
     
     
    private static func encryptedByAddress(
        _ name: String,
        doh: String,
        dot: String
    ) -> [HakoDNSResolverPreset] {
        [
            HakoDNSResolverPreset(name: name, address: doh, bootstrapServers: []),
            HakoDNSResolverPreset(
                name: name, address: "tls://\(dot)", bootstrapServers: []
            ),
        ]
    }

    private static func encrypted(
        _ name: String,
        doh: String,
        dot: String? = nil,
        doq: String? = nil,
        bootstrap: [String]
    ) -> [HakoDNSResolverPreset] {
        var result = [
            HakoDNSResolverPreset(
                name: name,
                address: doh,
                bootstrapServers: bootstrap
            ),
        ]
        if let dot {
            result.append(
                HakoDNSResolverPreset(
                    name: name,
                    address: "tls://\(dot)",
                    bootstrapServers: bootstrap
                )
            )
        }
        if let doq {
            result.append(
                HakoDNSResolverPreset(
                    name: name,
                    address: "quic://\(doq)",
                    bootstrapServers: bootstrap
                )
            )
        }
        return result
    }

    private static func makePresets() -> [HakoDNSResolverPreset] {
        var result: [HakoDNSResolverPreset] = []
        result += encrypted(
            "AliDNS",
            doh: "https://dns.alidns.com/dns-query",
            dot: "dns.alidns.com",
            bootstrap: ["223.5.5.5", "223.6.6.6"]
        )
        result += encrypted(
            "DNSPod",
            doh: "https://doh.pub/dns-query",
            dot: "dot.pub",
            bootstrap: ["1.12.12.12", "120.53.53.53"]
        )
        result += encrypted(
            "Cloudflare",
            doh: "https://cloudflare-dns.com/dns-query",
            dot: "one.one.one.one",
            bootstrap: ["1.1.1.1", "1.0.0.1"]
        )
        result += encrypted(
            "Google",
            doh: "https://dns.google/dns-query",
            dot: "dns.google",
            bootstrap: ["8.8.8.8", "8.8.4.4"]
        )
        result += encrypted(
            "Quad9 Secure",
            doh: "https://dns.quad9.net/dns-query",
            dot: "dns.quad9.net",
            bootstrap: ["9.9.9.9", "149.112.112.112"]
        )
        result += encrypted(
            "AdGuard Default",
            doh: "https://dns.adguard-dns.com/dns-query",
            dot: "dns.adguard-dns.com",
            doq: "dns.adguard-dns.com",
            bootstrap: ["94.140.14.14", "94.140.15.15"]
        )
        result += encrypted(
            "Control D Unfiltered",
            doh: "https://freedns.controld.com/p0",
            dot: "p0.freedns.controld.com",
            doq: "p0.freedns.controld.com",
            bootstrap: ["76.76.2.0", "76.76.10.0"]
        )
        result += encrypted(
            "Mullvad Unfiltered",
            doh: "https://dns.mullvad.net/dns-query",
            dot: "dns.mullvad.net",
            bootstrap: ["194.242.2.2"]
        )
         
         
         
         
         
         
         
         
         
         
         
         
         
        result += encryptedByAddress(
            "AliDNS",
            doh: "https://223.5.5.5/dns-query",
            dot: "223.5.5.5"
        )
        result += encryptedByAddress(
            "DNSPod",
            doh: "https://1.12.12.12/dns-query",
            dot: "1.12.12.12"
        )
        result += encryptedByAddress(
            "Cloudflare",
            doh: "https://1.1.1.1/dns-query",
            dot: "1.1.1.1"
        )
        result += encryptedByAddress(
            "Google",
            doh: "https://8.8.8.8/dns-query",
            dot: "8.8.8.8"
        )
        result += encryptedByAddress(
            "Quad9 Secure",
            doh: "https://9.9.9.9/dns-query",
            dot: "9.9.9.9"
        )
        result += encryptedByAddress(
            "AdGuard Default",
            doh: "https://94.140.14.14/dns-query",
            dot: "94.140.14.14"
        )
        result += encryptedByAddress(
            "Cisco OpenDNS",
            doh: "https://208.67.222.222/dns-query",
            dot: "208.67.222.222"
        )
        result += encrypted(
            "Cisco OpenDNS",
            doh: "https://dns.opendns.com/dns-query",
            dot: "dns.opendns.com",
            bootstrap: ["208.67.222.222", "208.67.220.220"]
        )
        result += encrypted(
            "DNS4EU Unfiltered",
            doh: "https://unfiltered.joindns4.eu/dns-query",
            dot: "unfiltered.joindns4.eu",
            bootstrap: ["86.54.11.100", "86.54.11.200"]
        )
        result += encrypted(
            "Yandex Basic",
            doh: "https://common.dot.dns.yandex.net/dns-query",
            dot: "common.dot.dns.yandex.net",
            bootstrap: ["77.88.8.8", "77.88.8.1"]
        )
        return result
    }
}

 
 
 
public struct HakoDNSResolverCatalogProgress:
    Equatable,
    Sendable
{
    public let presets: [HakoDNSResolverPreset]
    public private(set) var outcomes:
        [String: HakoDNSResolverOutcome]

    public var rankedPresets: [HakoDNSResolverPreset] {
        HakoDNSResolverCatalog.ranked(
            presets,
            by: outcomes
        )
    }

    public init(
        presets: [HakoDNSResolverPreset],
        outcomes: [String: HakoDNSResolverOutcome] = [:]
    ) {
        self.presets = presets
        self.outcomes = outcomes
    }

    public mutating func record(
        address: String,
        outcome: HakoDNSResolverOutcome
    ) {
        outcomes[address] = outcome
    }
}

public enum HakoDNSSelfCheckOutcome:
    Codable,
    Equatable,
    Sendable
{
    case answered(name: String, milliseconds: Int)
    case noAnswer(detail: String)
    case notConnected

    public var isFailure: Bool {
        if case .noAnswer = self {
            true
        } else {
            false
        }
    }
}

public enum HakoDNSGeoResource: String, Codable, Sendable {
    case geoIP
    case geoSite
}

public struct HakoDNSManagementRow:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let title: String
    public let value: String

    public var id: String { title }

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }
}

 
 
 
 
 
 
public struct HakoDNSInheritedBases: Codable, Equatable, Sendable {
    public var bools: [String: InheritedBase]
    public var texts: [String: InheritedTextBase]
    public var numbers: [String: InheritedNumberBase]
    public var lists: [String: InheritedListBase]
     
     
     
     
     
     
     
     
     
     
    public var profileEnablesDNS: InheritedBase

    public init(
        bools: [String: InheritedBase] = [:],
        texts: [String: InheritedTextBase] = [:],
        numbers: [String: InheritedNumberBase] = [:],
        lists: [String: InheritedListBase] = [:],
        profileEnablesDNS: InheritedBase = .unknown
    ) {
        self.bools = bools
        self.texts = texts
        self.numbers = numbers
        self.lists = lists
        self.profileEnablesDNS = profileEnablesDNS
    }

     
     
     
     
     
    public var overridesApplyWhileToggleOff: Bool {
        if case .profile(true) = profileEnablesDNS { return false }
        return true
    }

     
     
     
     
    public static let none = HakoDNSInheritedBases()

     
     
    public static let boolKeyPaths: [String] = [
        "dns.prefer-h3", "dns.ipv6", "dns.use-hosts", "dns.use-system-hosts", "dns.respect-rules",
        "dns.fallback-lazy-query", "dns.direct-nameserver-follow-policy", "dns.fallback-filter.geoip",
    ]
    public static let textKeyPaths: [String] = [
        "dns.enhanced-mode", "dns.fake-ip-filter-mode", "dns.cache-algorithm", "dns.fake-ip-range", "dns.fake-ip-range6",
    ]
    public static let numberKeyPaths: [String] = ["dns.ipv6-timeout", "dns.fake-ip-ttl", "dns.cache-max-size"]
     
     
     
     
    public static let listKeyPaths: [String] = [
        "dns.nameserver", "dns.fallback", "dns.default-nameserver",
        "dns.proxy-server-nameserver", "dns.direct-nameserver", "dns.fake-ip-filter",
        "dns.fallback-filter.geosite", "dns.fallback-filter.ipcidr", "dns.fallback-filter.domain",
    ]

    public func bool(_ keyPath: String) -> InheritedBase { bools[keyPath] ?? .unknown }
    public func text(_ keyPath: String) -> InheritedTextBase { texts[keyPath] ?? .unknown }
    public func number(_ keyPath: String) -> InheritedNumberBase { numbers[keyPath] ?? .unknown }
    public func list(_ keyPath: String) -> InheritedListBase { lists[keyPath] ?? .unknown }
}

public struct HakoDNSSnapshot: Codable, Equatable, Sendable {
    public let profileName: String?
    public let draft: HakoDNSOverrideDraft
    public let inherited: HakoDNSInheritedBases
    public let localMappings: [HakoDNSLocalMapping]
    public let localMappingsAvailable: Bool
    public let ruleSets: [String]
    public let managementTitle: String?
    public let managementRows: [HakoDNSManagementRow]
    public let managementFooter: String?
    public let selfCheckAvailable: Bool
    public let canQueryRuntime: Bool

    public init(
        profileName: String? = nil,
        draft: HakoDNSOverrideDraft = HakoDNSOverrideDraft(),
        inherited: HakoDNSInheritedBases = .none,
        localMappings: [HakoDNSLocalMapping] = [],
        localMappingsAvailable: Bool = true,
        ruleSets: [String] = [],
        managementTitle: String? = nil,
        managementRows: [HakoDNSManagementRow] = [],
        managementFooter: String? = nil,
        selfCheckAvailable: Bool = false,
        canQueryRuntime: Bool = false
    ) {
        self.profileName = profileName
        self.draft = draft
        self.inherited = inherited
        self.localMappings = localMappings
        self.localMappingsAvailable = localMappingsAvailable
        self.ruleSets = ruleSets
        self.managementTitle = managementTitle
        self.managementRows = managementRows
        self.managementFooter = managementFooter
        self.selfCheckAvailable = selfCheckAvailable
        self.canQueryRuntime = canQueryRuntime
    }

    public static let empty = HakoDNSSnapshot()
}

public enum HakoDNSCommand: Codable, Equatable, Sendable {
    case openDNSQuery
    case saveSettings(HakoDNSOverrideDraft)
    case saveLocalMappings([HakoDNSLocalMapping])
}

public enum HakoDNSPreSaveCheck {
    public struct Verdict: Equatable, Sendable {
        public let unreachable: [String]
        public let checked: [String]

        public var allFailed: Bool {
            !checked.isEmpty && unreachable.count == checked.count
        }
    }

    public static func run(
        nameserver: [String],
        policyResolvers: [String],
        isTestable: (String) -> Bool = { _ in true },
        probe: (String) async -> HakoDNSResolverOutcome
    ) async -> Verdict {
        let candidates = (nameserver + policyResolvers)
            .map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty && isTestable($0) }
        var checked: [String] = []
        var unreachable: [String] = []
        for address in candidates where !checked.contains(address) {
            checked.append(address)
            if !(await probe(address)).isReachable {
                unreachable.append(address)
            }
        }
        return Verdict(
            unreachable: unreachable,
            checked: checked
        )
    }

    public static func warning(for verdict: Verdict) -> String? {
        guard verdict.allFailed else {
            return nil
        }
        return "None of these resolvers answered on the current network. Saving is allowed — another network may reach them — but names may not resolve until then."
    }
}
