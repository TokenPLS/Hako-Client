import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoTunnelRouteShaping {
    public static let hideVPNIconKey = "vpn.tunnel.hideVPNIcon"
    public static let homeKitCompatibilityKey = "vpn.tunnel.homeKitCompatibility"

    public struct Switches: Equatable, Sendable {
        public var hideVPNIcon: Bool
        public var homeKitCompatibility: Bool

        public init(hideVPNIcon: Bool = false, homeKitCompatibility: Bool = false) {
            self.hideVPNIcon = hideVPNIcon
            self.homeKitCompatibility = homeKitCompatibility
        }

         
        public static func read(from defaults: UserDefaults?) -> Switches {
            Switches(
                hideVPNIcon: defaults?.bool(forKey: hideVPNIconKey) ?? false,
                homeKitCompatibility: defaults?.bool(forKey: homeKitCompatibilityKey) ?? false
            )
        }
    }

    public struct V4: Equatable, Sendable {
        public let address: String
        public let mask: String
        public init(address: String, mask: String) {
            self.address = address
            self.mask = mask
        }
    }

    public struct V6: Equatable, Sendable {
        public let address: String
        public let prefix: Int
        public init(address: String, prefix: Int) {
            self.address = address
            self.prefix = prefix
        }
    }

     
    public static let v4SplitTable: [V4] = [
        V4(address: "1.0.0.0", mask: "255.0.0.0"),
        V4(address: "2.0.0.0", mask: "254.0.0.0"),
        V4(address: "4.0.0.0", mask: "252.0.0.0"),
        V4(address: "8.0.0.0", mask: "248.0.0.0"),
        V4(address: "16.0.0.0", mask: "240.0.0.0"),
        V4(address: "32.0.0.0", mask: "224.0.0.0"),
        V4(address: "64.0.0.0", mask: "192.0.0.0"),
        V4(address: "128.0.0.0", mask: "128.0.0.0"),
    ]

     
    public static let v6SplitTable: [V6] = [
        V6(address: "100::", prefix: 8),
        V6(address: "200::", prefix: 7),
        V6(address: "400::", prefix: 6),
        V6(address: "800::", prefix: 5),
        V6(address: "1000::", prefix: 4),
        V6(address: "2000::", prefix: 3),
        V6(address: "4000::", prefix: 2),
        V6(address: "8000::", prefix: 1),
    ]

     
    public static let v4IconHole = V4(address: "0.0.0.0", mask: "255.255.255.254")
    public static let v6IconHole = V6(address: "::", prefix: 127)

     
     
    public static func usesSplitTable(strictRoute: Bool, switches: Switches) -> Bool {
        strictRoute || switches.homeKitCompatibility
    }

     
     
    public static func v4Excluded(_ configured: [V4], includedIsEmpty: Bool, switches: Switches) -> [V4] {
        guard switches.hideVPNIcon, !includedIsEmpty, !configured.contains(v4IconHole) else { return configured }
        return configured + [v4IconHole]
    }

    public static func v6Excluded(_ configured: [V6], includedIsEmpty: Bool, switches: Switches) -> [V6] {
        guard switches.hideVPNIcon, !includedIsEmpty, !configured.contains(v6IconHole) else { return configured }
        return configured + [v6IconHole]
    }
}
