import Foundation
import HakoClientUI

typealias HomeSection = HakoClientUI.HakoHomeSection
typealias HomeFavoriteCard = HakoClientUI.HakoHomeCard
typealias HomeAdjustmentModule = HakoClientUI.HakoHomeAdjustmentModule

typealias HakoCopy = HakoClientUI.HakoCopy

 
 
 
 
enum ConfigurationProductSurface: String, Equatable, Sendable {
    case homeGeneral
    case homeOverride
    case proxies
    case utilities
    case more
    case homeFinalConfiguration
}

enum ConfigurationCapabilityID: String, CaseIterable, Sendable {
    case mode
    case dnsAndHosts
    case routingRules
    case proxiesAndGroups
    case proxySources
    case ruleSets
    case tunnelAndAddressing
    case trafficRecognition
    case timeSynchronization
    case advancedRuntime
    case advancedTrust
    case geoData
    case automaticRuntimeAdaptations
    case localProxyListeners
    case externalController
    case unsupportedInboundServers
    case unsupportedPlatformServices
}

struct ConfigurationCapabilityPlacement: Equatable, Sendable {
    let id: ConfigurationCapabilityID
    let title: String
    let sourceKeys: [String]
    let surface: ConfigurationProductSurface
    let rationale: String
}

enum ConfigurationSurfaceCatalog {
     
     
     
     
     
    static let configCapabilities: [ConfigurationCapabilityPlacement] = [
        .init(
            id: .mode,
            title: "Mode & Route",
            sourceKeys: ["mode"],
            surface: .homeGeneral,
            rationale: "A frequent app-wide runtime decision."
        ),
        .init(
            id: .dnsAndHosts,
            title: "DNS & Local Mapping",
            sourceKeys: ["dns", "hosts"],
            surface: .more,
            rationale: "FlClash-compatible app-wide DNS and hosts live in Core Settings."
        ),
        .init(
            id: .routingRules,
            title: "Rules",
            sourceKeys: ["rules", "sub-rules"],
            surface: .homeOverride,
            rationale: "These fields change how the current profile routes traffic."
        ),
        .init(
            id: .proxiesAndGroups,
            title: "Proxies",
            sourceKeys: ["proxies", "proxy-groups"],
            surface: .proxies,
            rationale: "Configured policy groups and nodes are always browsable; connection adds live runtime state."
        ),
        .init(
            id: .proxySources,
            title: "Proxy Sources",
            sourceKeys: ["proxy-providers"],
            surface: .homeOverride,
            rationale: "The source belongs to this profile; its live health remains read-only in Utilities."
        ),
        .init(
            id: .ruleSets,
            title: "Rule Sets",
            sourceKeys: ["rule-providers"],
            surface: .homeOverride,
            rationale: "Rule-set materialization and update policy are profile configuration."
        ),
        .init(
            id: .tunnelAndAddressing,
            title: "Tunnel & Routes",
            sourceKeys: ["tun"],
            surface: .more,
            rationale: "FlClash-compatible app-wide TUN and route coverage live in Core Settings."
        ),
        .init(
            id: .trafficRecognition,
            title: "Traffic Recognition",
            sourceKeys: ["sniffer"],
            surface: .homeOverride,
            rationale: "Sniffing changes rule matching and therefore belongs beside profile networking."
        ),
        .init(
            id: .timeSynchronization,
            title: "Time Synchronization",
            sourceKeys: ["ntp"],
            surface: .homeOverride,
            rationale: "Core network-time offsets are profile networking; changing the Apple system clock remains unavailable."
        ),
        .init(
            id: .advancedRuntime,
            title: "Core Behavior",
            sourceKeys: [
                "ipv6", "unified-delay", "log-level",
                "geosite-matcher", "tcp-concurrent",
                "global-ua", "keep-alive-idle", "keep-alive-interval",
                "disable-keep-alive",
            ],
            surface: .more,
            rationale: "Low-frequency app-wide runtime behavior lives in Core Settings."
        ),
        .init(
            id: .advancedTrust,
            title: "Trust & Experimental",
            sourceKeys: ["tls", "experimental"],
            surface: .homeOverride,
            rationale: "Sensitive and experimental fields stay behind the advanced fallback."
        ),
        .init(
            id: .geoData,
            title: "Geo Data",
            sourceKeys: [
                "geox-url", "geo-auto-update", "geo-update-interval",
            ],
            surface: .more,
            rationale: "GeoIP, GeoSite, ASN, and MMDB assets are shared across profiles."
        ),
        .init(
            id: .automaticRuntimeAdaptations,
            title: "Client-managed Runtime",
            sourceKeys: [
                "geodata-loader", "geodata-mode", "etag-support",
                "profile",
            ],
            surface: .homeFinalConfiguration,
            rationale: "iOS fixes the memory-safe Geo loader, pins the GeoIP data mode, and performs conditional HTTP updates in the Client instead of exposing ineffective Core toggles."
        ),
        .init(
            id: .localProxyListeners,
            title: "Local Proxy & Inbound Servers",
            sourceKeys: [
                "port", "socks-port", "mixed-port", "inbound-tfo", "inbound-mptcp",
                "allow-lan", "bind-address", "authentication",
                "skip-auth-prefixes", "lan-allowed-ips", "lan-disallowed-ips",
                 
                 
                 
                 
                "ss-config", "vmess-config", "tuic-server", "listeners", "tunnels",
            ],
            surface: .utilities,
            rationale: "The core opens the listener the profile asks for. Only allow-lan needs a decision from the reader, because only it moves the listener off 127.0.0.1, so LAN Proxy Share carries the switch and the other ten arrive unconditionally."
        ),
        .init(
            id: .externalController,
            title: "External Controller",
            sourceKeys: [
                "external-controller", "external-controller-tls",
                "external-controller-cors", "external-controller-unix",
                "secret", "external-doh-server",
            ],
            surface: .homeFinalConfiguration,
            rationale: "Runs as written. This entry called the family inert while that was true, and it stopped being true the night the core wired the address to route.ReCreateServer — a sentence describing behaviour a build no longer has is the defect this surface exists to prevent."
        ),
        .init(
            id: .unsupportedInboundServers,
            title: "Redirection Ports",
            sourceKeys: ["redir-port", "tproxy-port"],
            surface: .homeFinalConfiguration,
            rationale: "The two upstream itself refuses here: redirection reads /dev/pf, which the sandbox does not have, and transparent proxying returns \"not supported\" off Linux. The inbound servers that used to sit beside them — ss-config, vmess-config, tuic-server, listeners, tunnels — are the reader\'s to configure: upstream runs them and the platform allows them, and this app deciding otherwise was answering a question about somebody else\'s device."
        ),
        .init(
            id: .unsupportedPlatformServices,
            title: "Platform-only Services",
            sourceKeys: [
                "find-process-mode",
                "external-controller-pipe", "external-controller-routing-mark",
                "external-ui", "external-ui-name", "external-ui-url",
                "interface-name", "routing-mark",
                "global-client-fingerprint", "iptables", "clash-for-android",
            ],
            surface: .homeFinalConfiguration,
            rationale: "Desktop/router services are disclosed in iOS Changes and never presented as working controls."
        ),
    ]

    static func placement(
        for id: ConfigurationCapabilityID
    ) -> ConfigurationCapabilityPlacement? {
        configCapabilities.first { $0.id == id }
    }
}

struct ProfileFinalConfigurationDisclosure: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
     
     
     
     
    var strippedKeys: [String] = []
}

 
 
 
 
struct ProfileFinalConfigurationSnapshot: Equatable, Sendable {
    let sourceText: String?
    let effectiveText: String?
    let fixedItems: [ProfileFinalConfigurationDisclosure]
    let unsupportedItems: [ProfileFinalConfigurationDisclosure]
    let adaptedItems: [ProfileFinalConfigurationDisclosure]

    static func make(
        sourceYAML: String?,
        effectiveYAML: String?
    ) -> ProfileFinalConfigurationSnapshot {
        let sourceText = presentedText(sourceYAML)
        let effectiveText = presentedText(effectiveYAML)
        let source = object(sourceText)
        let effective = object(effectiveText)

        return ProfileFinalConfigurationSnapshot(
            sourceText: sourceText,
            effectiveText: effectiveText,
            fixedItems: fixedDisclosures,
            unsupportedItems: unsupportedDisclosures(in: source),
            adaptedItems: adaptedDisclosures(source: source, effective: effective)
        )
    }

#if os(macOS)
     
     
     
     
     
     
    private static let fixedDisclosures: [ProfileFinalConfigurationDisclosure] = [
        .init(
            id: "network-extension",
            title: "Packet Tunnel",
            detail: "The connection is started and stopped by the macOS Network Extension."
        ),
         
         
         
         
         
         
        .init(
            id: "dns-interception",
            title: "DNS Interception",
            detail: "DNS interception runs inside the packet tunnel. A profile that sets dns.listen gets that listener too, opened exactly as written; only its Linux routing mark is zeroed."
        ),
        .init(
            id: "fake-ip-storage",
            title: "Fake-IP Persistence",
            detail: "Fake-IP persistence is on by default, so mappings survive Core reloads; a profile that sets profile.store-fake-ip to false is honoured."
        ),
        .init(
            id: "geodata-loader",
            title: "Geo Data Loader",
            detail: "Clash reads Geo data with the standard filesystem loader on macOS; the memory-conservative mode is an iOS memory-budget measure."
        ),
        .init(
            id: "client-resource-updates",
            title: "Resource Updates",
            detail: "Clash downloads subscriptions, providers and Geo data in the Client with conditional HTTP and last-known-good recovery; the packet-tunnel Core does not perform background downloads."
        ),
         
         
         
         
         
         
         
         
         
         
        .init(
            id: "external-controller",
            title: "External Controller & Web UI",
            detail: "The API listens at the configured address, TLS included, with the profile's secret and CORS rules applied, and the web UI is served — downloaded only if the app has not already placed it. Configuration writes stay with the app: the API serves reads, proxy selection and connection close."
        ),
    ]
#else
    private static let fixedDisclosures: [ProfileFinalConfigurationDisclosure] = [
        .init(
            id: "network-extension",
            title: "Packet Tunnel",
            detail: "The connection is started and stopped by iOS Network Extension."
        ),
        .init(
            id: "dns-interception",
            title: "DNS Interception",
             
             
             
             
             
            detail: "DNS interception runs inside the packet tunnel. A profile that sets dns.listen gets that listener too, opened exactly as written; only its Linux routing mark is zeroed."
        ),
        .init(
            id: "tunnel-stack",
            title: "Tunnel Stack",
             
             
             
             
             
             
             
             
            detail: "Clash picks its own packet stack for the Apple tunnel; a profile that sets tun.stack to system, gvisor, or mixed is honoured, and leaving it out is the usual choice."
        ),
        .init(
            id: "fake-ip-storage",
            title: "Fake-IP Persistence",
             
             
             
             
             
            detail: "Fake-IP persistence is on by default, so mappings survive Core reloads; a profile that sets profile.store-fake-ip to false is honoured."
        ),
        .init(
            id: "geodata-loader",
            title: "Geo Data Loader",
            detail: "Clash always uses the memory-conservative, memory-mapped loader on iOS so large GeoIP and GeoSite databases stay off the app heap."
        ),
        .init(
            id: "client-resource-updates",
            title: "Resource Updates",
            detail: "Clash downloads subscriptions, providers and Geo data in the Client with conditional HTTP and last-known-good recovery; the packet-tunnel Core does not perform background downloads."
        ),
        .init(
            id: "external-controller",
            title: "External Controller & Web UI",
             
             
             
             
             
             
             
             
             
             
            detail: "The API listens at the configured address, TLS included, with the profile's secret and CORS rules applied, and the web UI is served — downloaded only if the app has not already placed it. Configuration writes stay with the app: the API serves reads, proxy selection and connection close."
        ),
    ]
#endif

     
     
     
     
     
     
     
     
    private static var inboundKeys: Set<String> {
        ConfigTransforms.iosUnsupportedTopLevelKeys.intersection([
            "port", "socks-port", "redir-port", "tproxy-port", "mixed-port",
            "ss-config", "vmess-config", "inbound-tfo", "inbound-mptcp",
            "tuic-server", "allow-lan", "bind-address", "authentication",
            "skip-auth-prefixes", "lan-allowed-ips", "lan-disallowed-ips",
            "listeners", "tunnels",
        ])
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private static let deadControllerSpellings: Set<String> = [
        "external-controller-pipe", "external-controller-routing-mark",
    ]

    private static let platformRoutingKeys: Set<String> = [
        "interface-name", "routing-mark",
    ]

    private static let platformServiceKeys: Set<String> = [
        "iptables", "clash-for-android",
    ]

    private static func unsupportedDisclosures(
        in source: [String: Any]
    ) -> [ProfileFinalConfigurationDisclosure] {
        var result: [ProfileFinalConfigurationDisclosure] = []
        let keys = Set(source.keys)

        if !keys.isDisjoint(with: inboundKeys) {
            result.append(.init(
                id: "inbound-servers",
                title: "Redirection Ports",
                detail: "Redirection ports are removed from the runtime config, because Clash itself refuses them here too: the redirect listener needs a system facility an app on Apple is not allowed to open. Every other inbound field runs — listeners, tunnels and the protocol servers included — and LAN Proxy Share carries the allow-lan switch.",
                strippedKeys: keys.intersection(inboundKeys).sorted()
            ))
        }
#if !os(macOS)
         
         
         
         
        if keys.contains("find-process-mode") {
            result.append(.init(
                id: "process-lookup",
                title: "Process Lookup",
                detail: "A packet tunnel cannot attribute traffic to ordinary app processes. Process matching is disabled."
            ))
        }
#endif
        if !keys.isDisjoint(with: deadControllerSpellings) {
            result.append(.init(
                id: "external-control",
                title: "External Controller Spellings",
                detail: "Two spellings do not apply on this platform: the Windows named pipe is removed, and the routing mark is a Linux-only socket option that stays in the file and does nothing.",
                 
                 
                strippedKeys: keys.intersection(deadControllerSpellings)
                    .intersection(ConfigTransforms.iosUnsupportedTopLevelKeys).sorted()
            ))
        }
        if !keys.isDisjoint(with: platformRoutingKeys) {
            result.append(.init(
                id: "platform-routing",
                title: "Platform Routing Fields",
                detail: "Top-level interface names and Linux routing marks are not applied. Apple selects physical egress through Network Extension and its current network path.",
                strippedKeys: keys.intersection(platformRoutingKeys).sorted()
            ))
        }
        if keys.contains("global-client-fingerprint") {
            result.append(.init(
                id: "obsolete-global-fingerprint",
                title: "Global Client Fingerprint Is Obsolete",
                 
                 
                 
                 
                 
                 
                 
                detail: "Clash dropped this field upstream: the core logs an error and ignores it, on every platform, and your file is left as written. Set client-fingerprint on an individual proxy when that protocol supports it."
            ))
        }
        if !keys.isDisjoint(with: platformServiceKeys) {
            result.append(.init(
                id: "platform-services",
                title: "Router & Android Services",
                detail: "Fields meant for a Linux firewall or for Clash on Android stay in your file and do nothing here.",
                strippedKeys: keys.intersection(platformServiceKeys).sorted()
            ))
        }
        return result
    }

    private static func adaptedDisclosures(
        source: [String: Any],
        effective: [String: Any]
    ) -> [ProfileFinalConfigurationDisclosure] {
        var result: [ProfileFinalConfigurationDisclosure] = []

        if differs(path: ["dns", "enable"], source: source, effective: effective) {
            result.append(.init(
                id: "dns-service",
                title: "DNS Service Enabled",
                detail: "Clash enables the DNS engine required by the packet tunnel."
            ))
        }
        if value(path: ["dns", "listen-routing-mark"], in: source) != nil {
             
             
             
             
             
            result.append(.init(
                id: "dns-listener",
                title: "DNS Listener Mark Removed",
                detail: "The DNS listener opens as written; only its Linux socket mark is dropped, because socket marks are a Linux facility that Apple does not have."
            ))
        }
        if differs(path: ["tun", "enable"], source: source, effective: effective)
            || differs(path: ["tun", "stack"], source: source, effective: effective)
            || differs(path: ["tun", "dns-hijack"], source: source, effective: effective) {
            result.append(.init(
                id: "packet-tunnel",
                title: "Packet Tunnel Normalized",
                 
                 
                 
                detail: "Tunnel ownership and DNS interception are normalized for Apple's packet-flow contract."
            ))
        }
        if differs(path: ["profile", "store-fake-ip"], source: source, effective: effective) {
            result.append(.init(
                id: "fake-ip-persistence",
                title: "Fake-IP Storage Enabled",
                detail: "Clash keeps Fake-IP mappings stable across reloads and restarts."
            ))
        }
        if containsHTTPProvider(source) && !containsHTTPProvider(effective) {
            result.append(.init(
                id: "provider-materialization",
                title: "Remote Providers Materialized",
                detail: "The client downloaded remote provider data into the immutable profile revision before Core started."
            ))
        }
        return result
    }

    private static func presentedText(_ yaml: String?) -> String? {
        guard let yaml, !yaml.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
         
         
        return yaml
    }

    private static func object(_ yaml: String?) -> [String: Any] {
        guard let yaml,
              let json = try? ConfigTransforms.yamlToJSON(yaml),
              let value = try? JSONSerialization.jsonObject(with: Data(json.utf8)),
              let root = value as? [String: Any] else {
            return [:]
        }
        return root
    }

    private static func value(path: [String], in root: [String: Any]) -> Any? {
        var current: Any = root
        for component in path {
            guard let dictionary = current as? [String: Any],
                  let next = dictionary[component] else {
                return nil
            }
            current = next
        }
        return current
    }

    private static func differs(
        path: [String],
        source: [String: Any],
        effective: [String: Any]
    ) -> Bool {
        canonical(value(path: path, in: source)) != canonical(value(path: path, in: effective))
    }

    private static func canonical(_ value: Any?) -> Data? {
        guard let value, JSONSerialization.isValidJSONObject(["value": value]) else { return nil }
        return try? JSONSerialization.data(withJSONObject: ["value": value], options: [.sortedKeys])
    }

    private static func containsHTTPProvider(_ root: [String: Any]) -> Bool {
        guard let providers = root["proxy-providers"] as? [String: Any] else { return false }
        return providers.values.contains { value in
            guard let provider = value as? [String: Any] else { return false }
            return (provider["type"] as? String)?.lowercased() == "http"
        }
    }
}

struct HomeFavoriteCardPreferences {
    static let key = "home.favorite.cards.v3"
     
    static let legacyKeyV2 = "home.favorite.cards.v2"
     
     
    static let legacyKey = "home.favorite.cards.v1"
     
     
    static let defaultCards = HakoClientUI.HakoHomeCatalog.defaultCards
     
     
    static let requiredCards = HakoClientUI.HakoHomeCatalog.requiredCards
    static let optionalCards = HakoClientUI.HakoHomeCatalog.optionalCards

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [HomeFavoriteCard] {
        if let raw = defaults.array(forKey: Self.key) as? [String] {
            let cards = Self.normalized(Self.decode(raw))
            if cards.map(\.rawValue) != raw {
                save(cards)
            }
            return cards
        }
        if let raw = defaults.array(forKey: Self.legacyKeyV2) as? [String] {
             
             
            var cards = Self.decode(raw)
            if !cards.contains(.traffic) { cards.append(.traffic) }
            cards = Self.normalized(cards)
            save(cards)
            return cards
        }
        if let legacyRaw = defaults.array(forKey: Self.legacyKey) as? [String] {
            var cards = Self.decode(legacyRaw)
             
             
             
            if let anchor = cards.firstIndex(of: .routing) {
                cards.insert(contentsOf: [.proxies, .rules], at: anchor + 1)
                if !cards.contains(.traffic) { cards.append(.traffic) }
            }
            cards = Self.normalized(cards)
            save(cards)
            return cards
        }
        return Self.defaultCards
    }

    private static func decode(_ raw: [String]) -> [HomeFavoriteCard] {
        var seen = Set<HomeFavoriteCard>()
        return raw.compactMap(HomeFavoriteCard.init(rawValue:)).filter {
            seen.insert($0).inserted
        }
    }

    private static func normalized(
        _ cards: [HomeFavoriteCard]
    ) -> [HomeFavoriteCard] {
        HakoClientUI.HakoHomeCatalog.normalized(cards)
    }

    func save(_ cards: [HomeFavoriteCard]) {
        let values = Self.normalized(cards).map(\.rawValue)
        defaults.set(values, forKey: Self.key)
    }
}

typealias HomeRecoveryMode = HakoClientUI.HakoHomeRecoveryMode
typealias HomeConnectionPhase =
    HakoClientUI.HakoHomeConnectionPhase
typealias HomePrimaryAction = HakoClientUI.HakoHomePrimaryAction
typealias HomeConnectionIssue = HakoClientUI.HakoHomeConnectionIssue
typealias HomeConnectionFacts = HakoClientUI.HakoHomeConnectionFacts
typealias HomeConnectionPresentation =
    HakoClientUI.HakoHomeConnectionPresentation
typealias HomeConnectionPresenter =
    HakoClientUI.HakoHomeConnectionPresenter
