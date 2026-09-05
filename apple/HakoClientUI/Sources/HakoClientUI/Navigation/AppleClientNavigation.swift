 
 
 
 
 
public enum AppleClientDestination: Hashable, Sendable {
    public typealias UtilitiesDestination = HakoUtilitiesDestination
    public typealias MoreDestination = HakoMoreDestination

    case home
    case profiles
    case profileImport
    case profileDetail(id: String)
    case proxies
    case rules
    case activeRules
    case dnsQuery
    case configuration
    case utilities(UtilitiesDestination)
    case more(MoreDestination)

     
     
    public static let catalogDestinations: [Self] = [
        .profiles,
        .proxies,
        .rules,
        .configuration,
    ]
        + HakoUtilitiesCatalog.sections
            .flatMap(\.destinations)
            .map(Self.utilities)
        + HakoMoreCatalog.sections
            .flatMap(\.destinations)
            .map(Self.more)

     
     
     
     
     
     
     
    public var root: HakoRootDestination {
        switch self {
        case .home, .configuration:
            .home
        case .proxies:
            .proxies
         
         
        case .rules, .activeRules:
            .rules
        case .profiles, .profileImport, .profileDetail:
            .profiles
         
         
         
        case .dnsQuery:
            .more
        case .utilities(let destination):
            switch destination {
             
             
             
            case .connections: .connections
            case .requests: .requests
            case .logs: .logs
             
             
            case .root, .networkQuality,
                 .stun, .proxyShare, .runtime, .diagnosticsInbox:
                .utilities
            case .providers: .utilities
            }
        case .more(let destination):
            switch destination {
            case .about: .about
             
             
             
             
             
             
             
             
             
             
             
            case .root, .dnsAndHosts, .geoResources, .backupRestore,
                 .onDemand, .tunnel, .systemIntegrations, .dnsOnly,
                 .tunnelAndRoutes, .coreBehavior, .clientSettings,
                 .appearance, .developer:
                .more
            }
        }
    }

     
     
     
     
     
     
    public var isRoot: Bool {
        self == root.productDestination
    }

    public var title: String {
        switch self {
        case .home:
            HakoRootDestination.home.title
        case .profiles:
            "Profiles"
        case .profileImport:
             
             
            "Add Profile"
        case .profileDetail:
            "Profile"
        case .proxies:
            "Proxies"
        case .rules:
            "Rules"
        case .activeRules:
            "Active Rules"
        case .dnsQuery:
            "DNS Query"
        case .configuration:
            "Configuration"
        case .utilities(let destination):
            destination.title
        case .more(let destination):
            destination.title
        }
    }
}

public extension HakoRootDestination {
     
     
     
     
    var productDestination: AppleClientDestination {
        switch self {
        case .home: .home
        case .proxies: .proxies
        case .rules: .rules
        case .connections: .utilities(.connections)
        case .requests: .utilities(.requests)
        case .logs: .utilities(.logs)
        case .profiles: .profiles
        case .dns: .more(.dnsAndHosts)
        case .utilities: .utilities(.root)
        case .more: .more(.root)
        case .about: .more(.about)
        }
    }
}

 
 
 
 
 
public struct AppleClientNavigationState: Equatable, Sendable {
    public private(set) var selectedRoot: HakoRootDestination
    public private(set) var path: [AppleClientDestination]

    public init(
        selectedRoot: HakoRootDestination = .home,
        path: [AppleClientDestination] = []
    ) {
        self.selectedRoot = selectedRoot
        self.path = []
        _ = replacePath(path)
    }

    public var destination: AppleClientDestination {
        path.last ?? selectedRoot.productDestination
    }

    public mutating func selectRoot(_ root: HakoRootDestination) {
        selectedRoot = root
        path.removeAll()
    }

    public mutating func navigate(to destination: AppleClientDestination) {
        guard !destination.isRoot else {
            selectRoot(destination.root)
            return
        }
        selectedRoot = destination.root
        path = [destination]
    }

    public mutating func push(_ destination: AppleClientDestination) {
        guard !destination.isRoot else {
            selectRoot(destination.root)
            return
        }
        if selectedRoot != destination.root {
            selectedRoot = destination.root
            path.removeAll()
        }
        path.append(destination)
    }

    public mutating func pop() {
        guard !path.isEmpty else {
            return
        }
        path.removeLast()
    }

    @discardableResult
    public mutating func replacePath(
        _ newPath: [AppleClientDestination]
    ) -> Bool {
        guard let first = newPath.first else {
            path.removeAll()
            return true
        }
        guard !first.isRoot,
              newPath.allSatisfy({
                  !$0.isRoot && $0.root == first.root
              })
        else {
            return false
        }
        selectedRoot = first.root
        path = newPath
        return true
    }

    public mutating func popToRoot() {
        path.removeAll()
    }
}
