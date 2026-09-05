 
 
 
 
 
 
public enum HakoRootSidebarGroup: String, CaseIterable, Hashable, Sendable {
     
     
    case primary
    case session
    case configuration
     
     
     
     
    case hub
     
    case footer

     
     
     
     
     
     
     
    public var title: String? {
        switch self {
        case .primary, .hub, .footer: nil
        case .session: "Session"
         
         
         
        case .configuration: "sidebar.band.configuration"
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
public enum HakoRootDestination: String, CaseIterable, Hashable, Identifiable, Sendable {
    case home

     
     
     
     
     
     
    case proxies
    case rules
    case connections
    case requests
    case logs

    case profiles
    case dns

     
     
     
     
     
     
     
    case utilities
    case more

    case about

    public var id: Self { self }

    public var group: HakoRootSidebarGroup {
        switch self {
        case .home: .primary
        case .proxies, .rules, .connections, .requests, .logs: .session
        case .profiles: .configuration
         
         
        case .dns: .configuration
        case .utilities, .more: .hub
        case .about: .footer
        }
    }

    public static func rows(
        in group: HakoRootSidebarGroup
    ) -> [HakoRootDestination] {
        allCases.filter { $0.group == group }
    }

     
     
     
     
     
     
     
    public static let pendingShellHoist: Set<HakoRootDestination> = []

     
     
     
     
     
     
     
     
     
     
    public static let notOnTheRail: Set<HakoRootDestination> = [.dns]

    public static var sidebarRows: [HakoRootDestination] {
        allCases.filter { !pendingShellHoist.contains($0) && !notOnTheRail.contains($0) }
    }

    public static func sidebarRows(
        in group: HakoRootSidebarGroup
    ) -> [HakoRootDestination] {
        rows(in: group).filter {
            !pendingShellHoist.contains($0) && !notOnTheRail.contains($0)
        }
    }

    public var title: String {
        switch self {
        case .home: "Home"
        case .proxies: "Proxies"
        case .rules: "Rules"
        case .connections: "Connections"
        case .requests: "Requests"
        case .logs: "Logs"
        case .profiles: "Profiles"
         
         
         
         
        case .dns: "DNS"
        case .utilities: "Utilities"
        case .more: "More"
        case .about: "About"
        }
    }

    public var symbol: HakoSymbol {
        switch self {
        case .home: .catCircleFill
        case .proxies: .serverRack
        case .rules: .ruleDomain
         
         
        case .connections: .listTriangle
        case .requests: .listBulletRectanglePortrait
        case .logs: .textAlignleft
         
         
        case .profiles: .trayFullFill
         
         
        case .dns: .dnsDomain
        case .utilities: .briefcaseCircleFill
        case .more: .ellipsisCircleFill
        case .about: .infoCircle
        }
    }
}

public enum HakoPresentationClass: String, CaseIterable, Sendable {
    case compactTouch
    case regularTouch
    case desktop
    case television
}

public enum HakoRootNavigationStyle: String, Sendable {
    case bottomTabs
    case fixedSidebar
    case televisionFocus
}

public enum HakoContentWidthClass: String, Sendable {
    case compact
    case regular
    case television
}

public enum HakoSurfaceTreatment: String, Sendable {
    case nativeGlassWhenAvailable
    case focusNative
    case stableGrouped
}

 
 
 
public struct HakoPresentationPolicy: Equatable, Sendable {
    public let presentationClass: HakoPresentationClass
    public let rootNavigation: HakoRootNavigationStyle
    public let contentWidth: HakoContentWidthClass
    public let primaryPageTreatment: HakoSurfaceTreatment
    public let secondaryPageTreatment: HakoSurfaceTreatment
    public let allowsUserSidebarCollapse: Bool

    public static func `for`(_ presentationClass: HakoPresentationClass) -> Self {
        switch presentationClass {
        case .compactTouch:
            Self(
                presentationClass: presentationClass,
                rootNavigation: .bottomTabs,
                contentWidth: .compact,
                primaryPageTreatment: .nativeGlassWhenAvailable,
                secondaryPageTreatment: .stableGrouped,
                allowsUserSidebarCollapse: false
            )
        case .regularTouch, .desktop:
            Self(
                presentationClass: presentationClass,
                rootNavigation: .fixedSidebar,
                contentWidth: .regular,
                primaryPageTreatment: .nativeGlassWhenAvailable,
                secondaryPageTreatment: .stableGrouped,
                allowsUserSidebarCollapse: false
            )
        case .television:
            Self(
                presentationClass: presentationClass,
                rootNavigation: .televisionFocus,
                contentWidth: .television,
                primaryPageTreatment: .focusNative,
                secondaryPageTreatment: .stableGrouped,
                allowsUserSidebarCollapse: false
            )
        }
    }
}
