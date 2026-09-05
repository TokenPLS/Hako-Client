import Foundation

enum NodeBrowseStyle: String, CaseIterable, Identifiable {
    case tabs
    case list

    var id: String { rawValue }
    var title: String { self == .tabs ? "Tabs" : "List" }
}

enum NodeDensity: String, CaseIterable, Identifiable {
    case loose
    case standard
    case tight

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var minimumCardWidth: Double {
        switch self {
        case .loose: return 260
        case .standard: return 160
        case .tight: return 108
        }
    }

    var rowPadding: Double {
        switch self {
        case .loose: return 8
        case .standard: return 3
        case .tight: return 0
        }
    }
}

enum NodeIconStyle: String, CaseIterable, Identifiable {
    case none
    case standard
    case iconOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .standard: return "Standard"
        case .iconOnly: return "Icon Only"
        }
    }
}

enum NodeCardSize: String, CaseIterable, Identifiable {
    case expanded
    case compact
    case minimal

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct NodePresentationSettings: Equatable {
    var browseStyle: NodeBrowseStyle = .tabs
    var density: NodeDensity = .standard
    var iconStyle: NodeIconStyle = .standard
    var cardSize: NodeCardSize = .expanded

    private enum Key {
        static let browseStyle = "nodes.presentation.browseStyle"
        static let density = "nodes.presentation.density"
        static let iconStyle = "nodes.presentation.iconStyle"
        static let cardSize = "nodes.presentation.cardSize"
    }

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }

    static func load(from defaults: UserDefaults = appGroupDefaults) -> NodePresentationSettings {
        NodePresentationSettings(
            browseStyle: defaults.string(forKey: Key.browseStyle)
                .flatMap(NodeBrowseStyle.init(rawValue:)) ?? .tabs,
            density: defaults.string(forKey: Key.density)
                .flatMap(NodeDensity.init(rawValue:)) ?? .standard,
            iconStyle: defaults.string(forKey: Key.iconStyle)
                .flatMap(NodeIconStyle.init(rawValue:)) ?? .standard,
            cardSize: defaults.string(forKey: Key.cardSize)
                .flatMap(NodeCardSize.init(rawValue:)) ?? .expanded
        )
    }

    func save(in defaults: UserDefaults = appGroupDefaults) {
        defaults.set(browseStyle.rawValue, forKey: Key.browseStyle)
        defaults.set(density.rawValue, forKey: Key.density)
        defaults.set(iconStyle.rawValue, forKey: Key.iconStyle)
        defaults.set(cardSize.rawValue, forKey: Key.cardSize)
    }
}

enum ProxyTypePresentation {
    static func title(for rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "?" ? "Proxy" : trimmed
    }

    static func symbol(for rawValue: String) -> HakoSymbol {
        let value = rawValue.lowercased()
        if value.contains("direct") { return .arrowLeftArrowRight }
        if value.contains("reject") { return .xmarkOctagonFill }
        if value.contains("selector") || value == "select"
            || value.contains("urltest") || value.contains("url-test")
            || value.contains("fallback") || value.contains("loadbalance")
            || value.contains("load-balance") {
            return .point3ConnectedTrianglepathDotted
        }
        if value.contains("trojan") || value.contains("tls") || value.contains("anytls") {
            return .lockShield
        }
        if value.contains("shadow") || value == "ss" { return .shieldFill }
        if value.contains("http") { return .globeAsiaAustralia }
        if value.contains("socks") { return .network }
        if value.contains("wireguard") || value.contains("hysteria") || value.contains("tuic") {
            return .boltHorizontalCircle
        }
        return .network
    }
}

enum TrafficStatisticsSettings {
    static let key = "traffic.onlyStatisticsProxy"

    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }

    static func onlyProxy(from defaults: UserDefaults = appGroupDefaults) -> Bool {
        defaults.bool(forKey: key)
    }

    static func setOnlyProxy(_ enabled: Bool, in defaults: UserDefaults = appGroupDefaults) {
        defaults.set(enabled, forKey: key)
    }
}
