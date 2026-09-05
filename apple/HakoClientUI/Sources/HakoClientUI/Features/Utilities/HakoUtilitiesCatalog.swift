public enum HakoUtilitiesSectionID: String, CaseIterable, Hashable, Sendable {
    case currentSession
    case networkTools
    case runtimeAndReports

    public var title: String {
        switch self {
        case .currentSession: "Current Session"
        case .networkTools: "Network Tools"
        case .runtimeAndReports: "Runtime & Reports"
        }
    }
}

public enum HakoUtilitiesDestination:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    case root
    case connections
    case requests
    case logs
    case networkQuality
    case stun
    case proxyShare
    case runtime
    case providers
    case diagnosticsInbox

    public var id: Self { self }

    public var title: String {
        switch self {
        case .root: "Utilities"
        case .connections: "Connections"
        case .requests: "Requests"
        case .logs: "Logs"
        case .networkQuality: "Network Quality"
        case .stun: "STUN & NAT"
        case .proxyShare: "LAN Proxy Share"
        case .runtime: "Core Runtime"
        case .providers: "Providers"
        case .diagnosticsInbox: "Diagnostics Inbox"
        }
    }

    public var symbol: HakoSymbol {
        switch self {
        case .root: .wrenchAndScrewdriver
        case .connections: .listTriangle
        case .requests: .listBulletRectanglePortrait
        case .logs: .textAlignleft
        case .networkQuality: .speedometer
        case .stun: .arrowTriangleSwap
        case .proxyShare: .network
        case .runtime: .cpu
        case .providers: .shippingbox
        case .diagnosticsInbox: .docTextMagnifyingglass
        }
    }

    public var accent: HakoAccentRole {
        switch self {
        case .root: .blue
        case .connections: .cyan
        case .requests: .pink
        case .logs: .purple
        case .networkQuality: .orange
        case .stun: .green
        case .proxyShare: .orange
        case .runtime: .indigo
        case .providers: .orange
        case .diagnosticsInbox: .purple
        }
    }
}

public struct HakoUtilitiesSectionDescriptor: Equatable, Sendable {
    public let id: HakoUtilitiesSectionID
    public let destinations: [HakoUtilitiesDestination]

    public init(
        id: HakoUtilitiesSectionID,
        destinations: [HakoUtilitiesDestination]
    ) {
        self.id = id
        self.destinations = destinations
    }
}

public enum HakoUtilitiesCatalog {
     
     
     
    public static let regularHubExcludes: Set<HakoUtilitiesDestination> = [
        .connections, .requests, .logs,
    ]

    public static let sections = [
        HakoUtilitiesSectionDescriptor(
            id: .currentSession,
            destinations: [.connections, .requests, .logs]
        ),
        HakoUtilitiesSectionDescriptor(
            id: .networkTools,
            destinations: [.networkQuality, .stun, .proxyShare]
        ),
        HakoUtilitiesSectionDescriptor(
            id: .runtimeAndReports,
            destinations: [.runtime, .providers, .diagnosticsInbox]
        ),
    ]
}
