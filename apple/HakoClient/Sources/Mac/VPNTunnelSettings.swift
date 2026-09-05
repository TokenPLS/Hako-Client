import Foundation
import NetworkExtension

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct VPNTunnelSettings: Equatable {
    var enforceRoutes = false
    var includeAllNetworks = false
    var includeLocalNetworks = true
    var includeAPNs = false
     
     
    var hideVPNIcon = false
     
     
     
     
    var homeKitCompatibility = false

    enum Key {
        static let enforceRoutes = "vpn.tunnel.enforceRoutes"
        static let includeAllNetworks = "vpn.tunnel.includeAllNetworks"
        static let includeLocalNetworks = "vpn.tunnel.includeLocalNetworks"
        static let includeAPNs = "vpn.tunnel.includeAPNs"
        static let hideVPNIcon = "vpn.tunnel.hideVPNIcon"
        static let homeKitCompatibility = "vpn.tunnel.homeKitCompatibility"
    }

    static func load(from defaults: UserDefaults) -> Self {
        VPNTunnelSettings(
            enforceRoutes: defaults.bool(forKey: Key.enforceRoutes),
            includeAllNetworks: defaults.bool(forKey: Key.includeAllNetworks),
             
             
             
            includeLocalNetworks: defaults.object(forKey: Key.includeLocalNetworks)
                as? Bool ?? true,
            includeAPNs: defaults.bool(forKey: Key.includeAPNs),
            hideVPNIcon: defaults.bool(forKey: Key.hideVPNIcon),
            homeKitCompatibility: defaults.bool(forKey: Key.homeKitCompatibility)
        )
    }

     
     
     
     
    var apnsSwitchIsEnabled: Bool { includeAllNetworks }

     
     
     
     
    func localNetworksSwitchIsEnabled(configurationStrictRoute: Bool) -> Bool {
        includeAllNetworks || enforceRoutes || configurationStrictRoute
    }

    func save(to defaults: UserDefaults) {
        defaults.set(enforceRoutes, forKey: Key.enforceRoutes)
        defaults.set(includeAllNetworks, forKey: Key.includeAllNetworks)
        defaults.set(includeLocalNetworks, forKey: Key.includeLocalNetworks)
        defaults.set(includeAPNs, forKey: Key.includeAPNs)
        defaults.set(hideVPNIcon, forKey: Key.hideVPNIcon)
        defaults.set(homeKitCompatibility, forKey: Key.homeKitCompatibility)
    }
}

 
 
 
 
struct VPNRoutingPolicy: Equatable {
    let includeAllNetworks: Bool
    let excludeLocalNetworks: Bool
    let enforceRoutes: Bool
    let excludeCellularServices: Bool
    let excludeAPNs: Bool
    let excludeDeviceCommunication: Bool

    init(
        tunnel: VPNTunnelSettings = VPNTunnelSettings(),
        configurationStrictRoute: Bool = false,
        preserveDevelopmentDeviceCommunication: Bool = Self.defaultDevelopmentDeviceCommunication
    ) {
        includeAllNetworks = tunnel.includeAllNetworks
        excludeLocalNetworks = !tunnel.includeLocalNetworks
        enforceRoutes = tunnel.enforceRoutes || configurationStrictRoute
         
        excludeCellularServices = true
        excludeAPNs = !tunnel.includeAPNs
         
         
         
         
         
         
        excludeDeviceCommunication = includeAllNetworks
            || (enforceRoutes && preserveDevelopmentDeviceCommunication)
    }

    private init(
        includeAllNetworks: Bool,
        excludeLocalNetworks: Bool,
        enforceRoutes: Bool,
        excludeCellularServices: Bool,
        excludeAPNs: Bool,
        excludeDeviceCommunication: Bool
    ) {
        self.includeAllNetworks = includeAllNetworks
        self.excludeLocalNetworks = excludeLocalNetworks
        self.enforceRoutes = enforceRoutes
        self.excludeCellularServices = excludeCellularServices
        self.excludeAPNs = excludeAPNs
        self.excludeDeviceCommunication = excludeDeviceCommunication
    }

    private static let defaultDevelopmentDeviceCommunication = false


     
     
     
     
    func apply(to tunnelProtocol: NETunnelProviderProtocol) {
        tunnelProtocol.includeAllNetworks = includeAllNetworks
        tunnelProtocol.excludeLocalNetworks = excludeLocalNetworks
        tunnelProtocol.enforceRoutes = enforceRoutes
        if #available(macOS 13.3, *) {
            tunnelProtocol.excludeCellularServices = excludeCellularServices
            tunnelProtocol.excludeAPNs = excludeAPNs
        }
        if #available(macOS 14.4, *) {
            tunnelProtocol.excludeDeviceCommunication = excludeDeviceCommunication
        }
    }

     
     
     
     
    static func installed(from tunnelProtocol: NETunnelProviderProtocol) -> Self {
        var excludeCellularServices = true
        var excludeAPNs = true
        var excludeDeviceCommunication = true
        if #available(macOS 13.3, *) {
            excludeCellularServices = tunnelProtocol.excludeCellularServices
            excludeAPNs = tunnelProtocol.excludeAPNs
        }
        if #available(macOS 14.4, *) {
            excludeDeviceCommunication = tunnelProtocol.excludeDeviceCommunication
        }
        return Self(
            includeAllNetworks: tunnelProtocol.includeAllNetworks,
            excludeLocalNetworks: tunnelProtocol.excludeLocalNetworks,
            enforceRoutes: tunnelProtocol.enforceRoutes,
            excludeCellularServices: excludeCellularServices,
            excludeAPNs: excludeAPNs,
            excludeDeviceCommunication: excludeDeviceCommunication
        )
    }
}
