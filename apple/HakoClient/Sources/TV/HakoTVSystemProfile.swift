import Foundation
import NetworkExtension

 
 
 
 
 
 
 
 
@MainActor
protocol HakoTVSystemProfile: AnyObject {
    var isEnabled: Bool { get set }
    var isOnDemandEnabled: Bool { get set }
    var onDemandRules: [NEOnDemandRule]? { get set }
    var localizedDescription: String? { get set }
    var protocolConfiguration: NEVPNProtocol? { get set }
    var status: NEVPNStatus { get }
    var vpnConnection: NEVPNConnection? { get }
    func saveToPreferences() async throws
    func loadFromPreferences() async throws
    func startVPNTunnel() throws
    func stopVPNTunnel()
}

extension NETunnelProviderManager: HakoTVSystemProfile {
    var status: NEVPNStatus { connection.status }
    var vpnConnection: NEVPNConnection? { connection }
    func startVPNTunnel() throws { try connection.startVPNTunnel() }
    func stopVPNTunnel() { connection.stopVPNTunnel() }
}
