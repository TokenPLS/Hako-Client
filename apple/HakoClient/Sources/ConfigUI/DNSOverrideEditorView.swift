import Foundation
import HakoClientUI

enum DNSConfigurationFieldCatalog {
    static let allKeys: Set<String> = [
        "enable", "prefer-h3", "ipv6", "ipv6-timeout", "use-hosts",
        "use-system-hosts", "respect-rules", "nameserver", "fallback",
        "fallback-filter", "fallback-lazy-query", "listen",
        "listen-routing-mark", "enhanced-mode", "fake-ip-range",
        "fake-ip-range6", "fake-ip-filter", "fake-ip-filter-mode",
        "fake-ip-ttl", "default-nameserver", "cache-algorithm",
        "cache-max-size", "nameserver-policy",
        "proxy-server-nameserver",
        "proxy-server-nameserver-policy", "direct-nameserver",
        "direct-nameserver-follow-policy",
    ]

    static let iOSManagedKeys: Set<String> = [
        "enable", "listen", "listen-routing-mark",
    ]

    static let editableKeys = allKeys.subtracting(iOSManagedKeys)
}

typealias DNSOverrideTriState = HakoDNSTriState

 
 
 
struct DNSOverrideDraft {
    static let inheritedMode = HakoDNSOverrideDraft.inheritedMode
    static let policySeparator = " | "

     

     
     
     
     
     
     
     
     
     
    static let boolKeyPaths = HakoDNSInheritedBases.boolKeyPaths
    static let textKeyPaths = HakoDNSInheritedBases.textKeyPaths
    static let numberKeyPaths = HakoDNSInheritedBases.numberKeyPaths
    static let listKeyPaths = HakoDNSInheritedBases.listKeyPaths

     
     
     
     
    func listOverride(for keyPath: String) -> [String]? {
        let entries: [String]
        switch keyPath {
        case "dns.nameserver": entries = nameserver
        case "dns.fallback": entries = fallback
        case "dns.default-nameserver": entries = defaultNameserver
        case "dns.proxy-server-nameserver": entries = proxyServerNameserver
        case "dns.direct-nameserver": entries = directNameserver
        case "dns.fake-ip-filter": entries = fakeIPFilter
        case "dns.fallback-filter.geosite": entries = filterGeosite
        case "dns.fallback-filter.ipcidr": entries = filterIPCIDR
        case "dns.fallback-filter.domain": entries = filterDomain
        default: return nil
        }
        return entries.isEmpty ? nil : entries
    }

    mutating func setListOverride(_ value: [String]?, for keyPath: String) {
        let entries = value ?? []
        switch keyPath {
        case "dns.nameserver": nameserver = entries
        case "dns.fallback": fallback = entries
        case "dns.default-nameserver": defaultNameserver = entries
        case "dns.proxy-server-nameserver": proxyServerNameserver = entries
        case "dns.direct-nameserver": directNameserver = entries
        case "dns.fake-ip-filter": fakeIPFilter = entries
        case "dns.fallback-filter.geosite": filterGeosite = entries
        case "dns.fallback-filter.ipcidr": filterIPCIDR = entries
        case "dns.fallback-filter.domain": filterDomain = entries
        default: break
        }
    }

    func boolOverride(for keyPath: String) -> Bool? {
        triState(for: keyPath)?.boolValue
    }

    mutating func setBoolOverride(_ value: Bool?, for keyPath: String) {
        let state = HakoDNSTriState(bool: value)
        switch keyPath {
        case "dns.prefer-h3": preferH3 = state
        case "dns.ipv6": ipv6 = state
        case "dns.use-hosts": useHosts = state
        case "dns.use-system-hosts": useSystemHosts = state
        case "dns.respect-rules": respectRules = state
        case "dns.fallback-lazy-query": fallbackLazyQuery = state
        case "dns.direct-nameserver-follow-policy": directNameserverFollowPolicy = state
        case "dns.fallback-filter.geoip": filterGeoIP = state
        default: break
        }
    }

     
     
     
    func textOverride(for keyPath: String) -> String? {
        switch keyPath {
        case "dns.enhanced-mode": return Self.optionalChoice(enhancedMode)
        case "dns.fake-ip-filter-mode": return Self.optionalChoice(fakeIPFilterMode)
        case "dns.cache-algorithm": return Self.optionalChoice(cacheAlgorithm)
        case "dns.fake-ip-range": return Self.optionalText(fakeIPRange)
        case "dns.fake-ip-range6": return Self.optionalText(fakeIPRange6)
        default: return nil
        }
    }

    mutating func setTextOverride(_ value: String?, for keyPath: String) {
        switch keyPath {
        case "dns.enhanced-mode": enhancedMode = value ?? Self.inheritedMode
        case "dns.fake-ip-filter-mode": fakeIPFilterMode = value ?? Self.inheritedMode
        case "dns.cache-algorithm": cacheAlgorithm = value ?? Self.inheritedMode
        case "dns.fake-ip-range": fakeIPRange = value ?? ""
        case "dns.fake-ip-range6": fakeIPRange6 = value ?? ""
        default: break
        }
    }

    func numberOverride(for keyPath: String) -> Int? {
        switch keyPath {
        case "dns.ipv6-timeout": return Self.optionalInt(ipv6Timeout)
        case "dns.fake-ip-ttl": return Self.optionalInt(fakeIPTTL)
        case "dns.cache-max-size": return Self.optionalInt(cacheMaxSize)
        default: return nil
        }
    }

    mutating func setNumberOverride(_ value: Int?, for keyPath: String) {
        let text = value.map(String.init) ?? ""
        switch keyPath {
        case "dns.ipv6-timeout": ipv6Timeout = text
        case "dns.fake-ip-ttl": fakeIPTTL = text
        case "dns.cache-max-size": cacheMaxSize = text
        default: break
        }
    }

    private func triState(for keyPath: String) -> HakoDNSTriState? {
        switch keyPath {
        case "dns.prefer-h3": return preferH3
        case "dns.ipv6": return ipv6
        case "dns.use-hosts": return useHosts
        case "dns.use-system-hosts": return useSystemHosts
        case "dns.respect-rules": return respectRules
        case "dns.fallback-lazy-query": return fallbackLazyQuery
        case "dns.direct-nameserver-follow-policy": return directNameserverFollowPolicy
        case "dns.fallback-filter.geoip": return filterGeoIP
        default: return nil
        }
    }

    private let sourcePatchJSON: String
    var overrideDNS: Bool
    var preferH3: DNSOverrideTriState
    var ipv6: DNSOverrideTriState
    var ipv6Timeout: String
    var useHosts: DNSOverrideTriState
    var useSystemHosts: DNSOverrideTriState
    var respectRules: DNSOverrideTriState
    var fallbackLazyQuery: DNSOverrideTriState
    var enhancedMode: String
    var fakeIPRange: String
    var fakeIPRange6: String
    var fakeIPFilter: [String]
    var fakeIPFilterMode: String
    var fakeIPTTL: String
    var defaultNameserver: [String]
    var nameserverPolicy: [KeyValueListEditor.Entry]
    var nameserver: [String]
    var fallback: [String]
    var proxyServerNameserver: [String]
    var proxyServerNameserverPolicy: [KeyValueListEditor.Entry]
    var directNameserver: [String]
    var directNameserverFollowPolicy: DNSOverrideTriState
    var cacheAlgorithm: String
    var cacheMaxSize: String
    var filterGeoIP: DNSOverrideTriState
    var filterGeoIPCode: String
    var filterGeosite: [String]
    var filterIPCIDR: [String]
    var filterDomain: [String]

    init(patchJSON: String, dnsOverridesProfiles: Bool = false) {
        sourcePatchJSON = patchJSON
        let patch = OverridePatch(patchJSON: patchJSON)
         
         
         
         
        overrideDNS = dnsOverridesProfiles
        preferH3 = DNSOverrideTriState(
            bool: patch.dnsGet("prefer-h3")
        )
        ipv6 = DNSOverrideTriState(
            bool: patch.dnsGet("ipv6")
        )
        ipv6Timeout = Self.string(
            patch.dnsGet("ipv6-timeout") as Int?
        )
        useHosts = DNSOverrideTriState(
            bool: patch.dnsGet("use-hosts")
        )
        useSystemHosts = DNSOverrideTriState(
            bool: patch.dnsGet("use-system-hosts")
        )
        respectRules = DNSOverrideTriState(
            bool: patch.dnsGet("respect-rules")
        )
        fallbackLazyQuery = DNSOverrideTriState(
            bool: patch.dnsGet("fallback-lazy-query")
        )
        enhancedMode =
            patch.dnsGet("enhanced-mode") ?? Self.inheritedMode
        fakeIPRange = patch.dnsGet("fake-ip-range") ?? ""
        fakeIPRange6 = patch.dnsGet("fake-ip-range6") ?? ""
        fakeIPFilter = patch.dnsGet("fake-ip-filter") ?? []
        fakeIPFilterMode =
            patch.dnsGet("fake-ip-filter-mode")
            ?? Self.inheritedMode
        fakeIPTTL = Self.string(
            patch.dnsGet("fake-ip-ttl") as Int?
        )
        defaultNameserver =
            patch.dnsGet("default-nameserver") ?? []
        nameserverPolicy = Self.policyEntries(
            patch.dnsPolicyEntries("nameserver-policy")
        )
        nameserver = patch.dnsGet("nameserver") ?? []
        fallback = patch.dnsGet("fallback") ?? []
        proxyServerNameserver =
            patch.dnsGet("proxy-server-nameserver") ?? []
        proxyServerNameserverPolicy = Self.policyEntries(
            patch.dnsPolicyEntries(
                "proxy-server-nameserver-policy"
            )
        )
        directNameserver =
            patch.dnsGet("direct-nameserver") ?? []
        directNameserverFollowPolicy = DNSOverrideTriState(
            bool:
                patch.dnsGet(
                    "direct-nameserver-follow-policy"
                )
        )
        cacheAlgorithm =
            patch.dnsGet("cache-algorithm")
            ?? Self.inheritedMode
        cacheMaxSize = Self.string(
            patch.dnsGet("cache-max-size") as Int?
        )
        filterGeoIP = DNSOverrideTriState(
            bool: patch.fallbackFilterGet("geoip")
        )
        filterGeoIPCode =
            patch.fallbackFilterGet("geoip-code") ?? ""
        filterGeosite =
            patch.fallbackFilterGet("geosite") ?? []
        filterIPCIDR =
            patch.fallbackFilterGet("ipcidr") ?? []
        filterDomain =
            patch.fallbackFilterGet("domain") ?? []
    }

    func buildPatchJSON() -> String {
        var patch = OverridePatch(
            patchJSON: sourcePatchJSON
        )
         
         
         
         
        patch.dnsSet("enable", nil as Bool?)
        patch.dnsSet("listen", nil as String?)
        patch.dnsSet("listen-routing-mark", nil as Int?)
        patch.dnsSet("prefer-h3", preferH3.boolValue)
        patch.dnsSet("ipv6", ipv6.boolValue)
        patch.dnsSet(
            "ipv6-timeout",
            Self.optionalInt(ipv6Timeout)
        )
        patch.dnsSet("use-hosts", useHosts.boolValue)
        patch.dnsSet(
            "use-system-hosts",
            useSystemHosts.boolValue
        )
        patch.dnsSet(
            "respect-rules",
            respectRules.boolValue
        )
        patch.dnsSet(
            "fallback-lazy-query",
            fallbackLazyQuery.boolValue
        )
        patch.dnsSet(
            "enhanced-mode",
            Self.optionalChoice(enhancedMode)
        )
        patch.dnsSet(
            "fake-ip-range",
            Self.optionalText(fakeIPRange)
        )
        patch.dnsSet(
            "fake-ip-range6",
            Self.optionalText(fakeIPRange6)
        )
        patch.dnsSet(
            "fake-ip-filter",
            fakeIPFilter.isEmpty ? nil : fakeIPFilter
        )
        patch.dnsSet(
            "fake-ip-filter-mode",
            Self.optionalChoice(fakeIPFilterMode)
        )
        patch.dnsSet(
            "fake-ip-ttl",
            Self.optionalInt(fakeIPTTL)
        )
        patch.dnsSet(
            "default-nameserver",
            defaultNameserver.isEmpty
                ? nil
                : defaultNameserver
        )
        patch.setDNSPolicy(
            "nameserver-policy",
            Self.policyOrdered(nameserverPolicy)
        )
        patch.dnsSet(
            "nameserver",
            nameserver.isEmpty ? nil : nameserver
        )
        patch.dnsSet(
            "fallback",
            fallback.isEmpty ? nil : fallback
        )
        patch.dnsSet(
            "proxy-server-nameserver",
            proxyServerNameserver.isEmpty
                ? nil
                : proxyServerNameserver
        )
        patch.setDNSPolicy(
            "proxy-server-nameserver-policy",
            Self.policyOrdered(
                proxyServerNameserverPolicy
            )
        )
        patch.dnsSet(
            "direct-nameserver",
            directNameserver.isEmpty
                ? nil
                : directNameserver
        )
        patch.dnsSet(
            "direct-nameserver-follow-policy",
            directNameserverFollowPolicy.boolValue
        )
        patch.dnsSet(
            "cache-algorithm",
            Self.optionalChoice(cacheAlgorithm)
        )
        patch.dnsSet(
            "cache-max-size",
            Self.optionalInt(cacheMaxSize)
        )
        patch.fallbackFilterSet(
            "geoip",
            filterGeoIP.boolValue
        )
        patch.fallbackFilterSet(
            "geoip-code",
            Self.optionalText(filterGeoIPCode)
        )
        patch.fallbackFilterSet(
            "geosite",
            filterGeosite.isEmpty ? nil : filterGeosite
        )
        patch.fallbackFilterSet(
            "ipcidr",
            filterIPCIDR.isEmpty ? nil : filterIPCIDR
        )
        patch.fallbackFilterSet(
            "domain",
            filterDomain.isEmpty ? nil : filterDomain
        )
        return patch.patchJSON
    }

    var sharedDraft: HakoDNSOverrideDraft {
        var result = HakoDNSOverrideDraft()
        result.overrideDNS = overrideDNS
        result.preferH3 = preferH3
        result.ipv6 = ipv6
        result.ipv6Timeout = ipv6Timeout
        result.useHosts = useHosts
        result.useSystemHosts = useSystemHosts
        result.respectRules = respectRules
        result.fallbackLazyQuery = fallbackLazyQuery
        result.enhancedMode = enhancedMode
        result.fakeIPRange = fakeIPRange
        result.fakeIPRange6 = fakeIPRange6
        result.fakeIPFilter = fakeIPFilter
        result.fakeIPFilterMode = fakeIPFilterMode
        result.fakeIPTTL = fakeIPTTL
        result.defaultNameserver = defaultNameserver
        result.nameserverPolicy = nameserverPolicy.map {
            HakoDNSPolicyEntry(
                key: $0.key,
                resolvers: Self.policyServers($0.value)
            )
        }
        result.nameserver = nameserver
        result.fallback = fallback
        result.proxyServerNameserver = proxyServerNameserver
        result.proxyServerNameserverPolicy =
            proxyServerNameserverPolicy.map {
                HakoDNSPolicyEntry(
                    key: $0.key,
                    resolvers:
                        Self.policyServers($0.value)
                )
            }
        result.directNameserver = directNameserver
        result.directNameserverFollowPolicy =
            directNameserverFollowPolicy
        result.cacheAlgorithm = cacheAlgorithm
        result.cacheMaxSize = cacheMaxSize
        result.filterGeoIP = filterGeoIP
        result.filterGeoIPCode = filterGeoIPCode
        result.filterGeosite = filterGeosite
        result.filterIPCIDR = filterIPCIDR
        result.filterDomain = filterDomain
        return result
    }

    mutating func apply(_ value: HakoDNSOverrideDraft) {
        let previousNameserverPolicy = nameserverPolicy
        let previousProxyPolicy = proxyServerNameserverPolicy

        overrideDNS = value.overrideDNS
        preferH3 = value.preferH3
        ipv6 = value.ipv6
        ipv6Timeout = value.ipv6Timeout
        useHosts = value.useHosts
        useSystemHosts = value.useSystemHosts
        respectRules = value.respectRules
        fallbackLazyQuery = value.fallbackLazyQuery
        enhancedMode = value.enhancedMode
        fakeIPRange = value.fakeIPRange
        fakeIPRange6 = value.fakeIPRange6
        fakeIPFilter = value.fakeIPFilter
        fakeIPFilterMode = value.fakeIPFilterMode
        fakeIPTTL = value.fakeIPTTL
        defaultNameserver = value.defaultNameserver
        nameserverPolicy = value.nameserverPolicy.map { entry in
            Self.policyEntry(
                key: entry.key,
                resolvers: entry.resolvers,
                valueWasArray:
                    previousNameserverPolicy.first { previous in
                        previous.key == entry.key
                    }?.valueWasArray ?? false
            )
        }
        nameserver = value.nameserver
        fallback = value.fallback
        proxyServerNameserver = value.proxyServerNameserver
        proxyServerNameserverPolicy =
            value.proxyServerNameserverPolicy.map { entry in
                Self.policyEntry(
                    key: entry.key,
                    resolvers: entry.resolvers,
                    valueWasArray:
                        previousProxyPolicy.first { previous in
                            previous.key == entry.key
                        }?.valueWasArray ?? false
                )
            }
        directNameserver = value.directNameserver
        directNameserverFollowPolicy =
            value.directNameserverFollowPolicy
        cacheAlgorithm = value.cacheAlgorithm
        cacheMaxSize = value.cacheMaxSize
        filterGeoIP = value.filterGeoIP
        filterGeoIPCode = value.filterGeoIPCode
        filterGeosite = value.filterGeosite
        filterIPCIDR = value.filterIPCIDR
        filterDomain = value.filterDomain
    }

    private static func string(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    private static func optionalInt(
        _ value: String
    ) -> Int? {
        Int(
            value.trimmingCharacters(in: .whitespaces)
        )
    }

    private static func optionalText(
        _ value: String
    ) -> String? {
        let result = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return result.isEmpty ? nil : result
    }

    private static func optionalChoice(
        _ value: String
    ) -> String? {
        value == inheritedMode
            ? nil
            : optionalText(value)
    }

    private static func policyEntries(
        _ entries: [(key: String, value: OrderedJSON)]?
    ) -> [KeyValueListEditor.Entry] {
        (entries ?? []).compactMap { key, value in
            switch value {
            case .string(let text):
                KeyValueListEditor.Entry(
                    key: key,
                    value: text
                )
            case .array(let items):
                KeyValueListEditor.Entry(
                    key: key,
                    value: items.compactMap {
                        if case .string(let text) = $0 {
                            return text
                        }
                        return nil
                    }.joined(separator: policySeparator),
                    valueWasArray: true
                )
            default:
                nil
            }
        }
    }

    private static func policyServers(
        _ value: String
    ) -> [String] {
        value.components(separatedBy: policySeparator)
            .map {
                $0.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            }
            .filter { !$0.isEmpty }
    }

    private static func policyEntry(
        key: String,
        resolvers: [String],
        valueWasArray: Bool
    ) -> KeyValueListEditor.Entry {
        KeyValueListEditor.Entry(
            key: key,
            value: resolvers.joined(
                separator: policySeparator
            ),
            valueWasArray:
                valueWasArray || resolvers.count > 1
        )
    }

    private static func policyOrdered(
        _ entries: [KeyValueListEditor.Entry]
    ) -> [(key: String, value: OrderedJSON)]? {
        var result: [(key: String, value: OrderedJSON)] = []
        var seen = Set<String>()
        for entry in entries {
            let key = entry.key.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let resolvers = policyServers(entry.value)
            guard !key.isEmpty,
                  !resolvers.isEmpty,
                  seen.insert(key).inserted
            else {
                continue
            }
            let value: OrderedJSON =
                entry.valueWasArray || resolvers.count > 1
                ? .array(resolvers.map(OrderedJSON.string))
                : .string(resolvers[0])
            result.append((key, value))
        }
        return result.isEmpty ? nil : result
    }
}
