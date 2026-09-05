import Foundation
import HakoClientUI
import HakoMacClient

 
 
 
 
 
 
 
struct HakoMacSystemRoutePlan: Equatable {
     
    var destination: HakoMacSecondaryDestination?
    var command: HakoSystemVPNPolicy.Command?
    var mode: AppleClientOutboundMode?

    static func plan(
        for route: HakoSystemRoute,
        isActive: Bool
    ) -> HakoMacSystemRoutePlan {
        switch route {
        case .vpn(let action):
            return HakoMacSystemRoutePlan(
                destination: nil,
                command: HakoSystemVPNPolicy.command(for: action, isActive: isActive),
                mode: nil
            )
        case .mode(let mode):
            let outbound: AppleClientOutboundMode
            switch mode {
            case .rule: outbound = .rule
            case .global: outbound = .global
            case .direct: outbound = .direct
            }
            return HakoMacSystemRoutePlan(destination: nil, command: nil, mode: outbound)
        case .open(let destination):
            let secondary: HakoMacSecondaryDestination?
            switch destination {
            case .overview, .home: secondary = nil
            case .profiles: secondary = .profiles
            case .nodes, .proxies: secondary = .proxies
            case .logs: secondary = .utility(.logs)
            case .tools, .utilities: secondary = .utility(.root)
            case .more: secondary = .more(.root)
            }
            return HakoMacSystemRoutePlan(destination: secondary, command: nil, mode: nil)
        }
    }
}
