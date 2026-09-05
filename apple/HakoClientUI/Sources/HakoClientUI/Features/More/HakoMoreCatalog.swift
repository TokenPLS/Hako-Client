public enum HakoMoreSectionID: String, CaseIterable, Hashable, Sendable {
    case dataAndResources
    case connectionBehavior
    case coreSettings
    case integrations
    case clientPreferences
    case about

    public var title: String {
        switch self {
        case .dataAndResources: "Data & Resources"
        case .connectionBehavior: "Connection Behavior"
        case .coreSettings: "Core Settings"
        case .integrations: "Integrations"
        case .clientPreferences: "App Settings"
        case .about: "About"
        }
    }
}

public enum HakoMoreDestination:
    String,
    CaseIterable,
    Codable,
    Hashable,
    Identifiable,
    Sendable
{
    case root
    case geoResources
    case backupRestore
    case onDemand
    case tunnel
    case systemIntegrations
    case dnsOnly
    case dnsAndHosts
    case tunnelAndRoutes
    case coreBehavior
    case clientSettings
    case appearance
    case about
    case developer

    public var id: Self { self }

    public var title: String {
        switch self {
        case .root: "More"
        case .geoResources: "Geo Resources"
        case .backupRestore: "Backup & Restore"
        case .onDemand: "On Demand"
        case .tunnel: "Tunnel"
        case .systemIntegrations: "Shortcuts & Controls"
        case .dnsOnly: "DNS-only"
        case .dnsAndHosts: "DNS"
        case .tunnelAndRoutes: "Tunnel & Routes"
        case .coreBehavior: "Core Behavior"
        case .clientSettings: "Client Settings"
        case .appearance: "Appearance"
        case .about: "About Clash"
        case .developer: "Developer"
        }
    }

    public var symbol: HakoSymbol {
        switch self {
        case .root: .ellipsisCircle
        case .geoResources: .globeAsiaAustralia
        case .backupRestore: .arrowClockwiseIcloud
        case .onDemand: .appBadgeCheckmarkFill
        case .tunnel: .arrowLeftAndRightSquareFill
        case .systemIntegrations: .arrowTriangleSwap
        case .dnsOnly: .lockShield
        case .dnsAndHosts: .dnsDomain
        case .tunnelAndRoutes: .globeBadgeChevronBackward
        case .coreBehavior: .gearshape2
        case .clientSettings: .gearshape
        case .appearance: .circleLefthalfFilled
        case .about: .infoCircle
        case .developer: .wrenchAndScrewdriver
        }
    }

    public var accent: HakoAccentRole {
        switch self {
        case .root: .blue
        case .geoResources: .green
        case .backupRestore: .teal
        case .onDemand: .cyan
        case .tunnel: .blue
        case .systemIntegrations: .indigo
        case .dnsOnly: .teal
        case .dnsAndHosts: .blue
        case .tunnelAndRoutes: .teal
        case .coreBehavior: .purple
        case .clientSettings: .purple
        case .appearance: .indigo
        case .about: .blue
        case .developer: .orange
        }
    }
}

public struct HakoMoreSectionDescriptor: Equatable, Sendable {
    public let id: HakoMoreSectionID
    public let destinations: [HakoMoreDestination]

    public init(
        id: HakoMoreSectionID,
        destinations: [HakoMoreDestination]
    ) {
        self.id = id
        self.destinations = destinations
    }
}

public enum HakoMoreCatalog {
     
     
     
     
    private static var connectionBehaviorDestinations: [HakoMoreDestination] {
        [.onDemand, .tunnel, .dnsOnly]
    }

     
     
     
     
     
     
     
     
     
     
    public static let regularHubExcludes: Set<HakoMoreDestination> = [
        .about,
    ]

    public static let sections = [
         
         
        HakoMoreSectionDescriptor(
            id: .coreSettings,
            destinations: [.dnsAndHosts, .tunnelAndRoutes, .coreBehavior]
        ),
         
         
         
         
         
         
        HakoMoreSectionDescriptor(
            id: .dataAndResources,
            destinations: [.geoResources]
        ),
        HakoMoreSectionDescriptor(
            id: .connectionBehavior,
            destinations: connectionBehaviorDestinations
        ),
        HakoMoreSectionDescriptor(
            id: .integrations,
            destinations: [.systemIntegrations]
        ),
        HakoMoreSectionDescriptor(
            id: .clientPreferences,
            destinations: [.clientSettings, .appearance]
        ),
        HakoMoreSectionDescriptor(
            id: .about,
            destinations: [.about]
        ),
    ]
}
