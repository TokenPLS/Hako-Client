public enum HakoHomeSection:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    case common
    case adjust

    public var id: Self { self }

    public var title: String {
        switch self {
        case .common: "General"
        case .adjust: "Override"
        }
    }
}

public enum HakoHomeCard:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    case routing
    case proxies
    case rules
    case traffic
    case externalIP
    case lanIP

    public var id: Self { self }

    public var title: String {
        switch self {
        case .routing: "Outbound Mode"
        case .proxies: "Proxies"
        case .rules: "Rules"
        case .traffic: "Traffic"
        case .externalIP: "External IP"
        case .lanIP: "LAN IP"
        }
    }

    public var symbol: HakoSymbol {
        switch self {
        case .routing: .arrowTriangleBranch
        case .proxies: .serverRack
        case .rules: .ruleDomain
        case .traffic: .waveformPathEcg
        case .externalIP: .globe
        case .lanIP: .point3ConnectedTrianglepathDotted
        }
    }
}

public enum HakoHomeCatalog {
    public static let defaultCards: [HakoHomeCard] = [
        .routing, .proxies, .rules, .traffic,
    ]
    public static let requiredCards: [HakoHomeCard] = [
        .routing, .proxies, .rules,
    ]
    public static let optionalCards: [HakoHomeCard] = [
        .traffic, .externalIP, .lanIP,
    ]

    public static func normalized(_ cards: [HakoHomeCard]) -> [HakoHomeCard] {
        var seen = Set<HakoHomeCard>()
        var result = cards.filter { seen.insert($0).inserted }
        for card in requiredCards where seen.insert(card).inserted {
            result.append(card)
        }
        return result
    }
}

public enum HakoHomeAdjustmentAction:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    case customNodes
    case proxyChains
    case routingRules
    case connection
    case proxySources
    case ruleSets
    case advancedOverrides
    case rawFields

    public var id: Self { self }

    public var title: String {
        switch self {
        case .customNodes: "Custom Nodes"
        case .proxyChains: "Proxy Chains"
        case .routingRules: "Routing Rules"
        case .connection: "Sniffer & NTP"
        case .proxySources: "Proxy Sources"
        case .ruleSets: "Rule Sets"
        case .advancedOverrides: "Advanced Overrides"
        case .rawFields: "Raw Fields"
        }
    }
}

public enum HakoHomeAdjustmentModule:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    case nodes
    case rules
    case network
    case resources
    case advancedOverrides

    public var id: String {
        switch self {
        case .advancedOverrides: "advanced"
        default: rawValue
        }
    }

    public var title: String {
        switch self {
        case .nodes: "Proxy Overrides"
        case .rules: "Personal Rules"
        case .network: "Profile Network"
        case .resources: "Resources"
        case .advancedOverrides: "Advanced"
        }
    }

    public var subtitle: String {
        switch self {
        case .nodes: "Custom nodes and proxy chains for this profile"
        case .rules: "Rules layered over this profile's subscription"
        case .network: "Profile-specific traffic recognition and time sync"
        case .resources: "Proxy sources and rule sets used by this profile"
        case .advancedOverrides: "Scripts, custom overrides, and long-tail core fields"
        }
    }

    public var symbol: HakoSymbol {
        switch self {
        case .nodes: .serverRack
        case .rules: .ruleDomain
        case .network: .network
        case .resources: .shippingbox
        case .advancedOverrides: .curlybraces
        }
    }

    public var accent: HakoAccentRole {
        switch self {
        case .nodes: .green
        case .rules: .indigo
        case .network: .teal
        case .resources: .orange
        case .advancedOverrides: .purple
        }
    }

    public var actions: [HakoHomeAdjustmentAction] {
        switch self {
        case .nodes: [.customNodes, .proxyChains]
        case .rules: [.routingRules]
        case .network: [.connection]
        case .resources: [.proxySources, .ruleSets]
        case .advancedOverrides: [.advancedOverrides, .rawFields]
        }
    }
}
