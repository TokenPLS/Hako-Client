import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
struct HakoMacMenuProxyCatalog: Equatable {
    struct Group: Equatable, Identifiable {
        let name: String
        let members: [String]
         
         
        let now: String
         
         
        var type: String = ""
         
         
        var latency: [String: HakoProxyLatencyState] = [:]
         
         
         
         
         
         
         
         
         
         
        var pinsOnRepick = false
        var id: String { name }
    }

    let groups: [Group]

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func make(
        groups: [ProxyGroup],
        mode: ProxyBrowsingVisibility.Mode,
        delays: [String: Int] = [:],
        testing: Set<String> = []
    ) -> HakoMacMenuProxyCatalog {
        let visible = ProxyBrowsingVisibility.groups(
            groups,
            mode: mode,
            name: \.name,
            isHidden: \.hidden
        )
        return HakoMacMenuProxyCatalog(
            groups: visible.compactMap { group in
                guard group.acceptsMemberChoice, !group.members.isEmpty else {
                    return nil
                }
                var latency: [String: HakoProxyLatencyState] = [:]
                for member in group.members {
                    if testing.contains(member) {
                        latency[member] = .testing
                    } else if let delay = delays[member] {
                        latency[member] = delay > 0
                            ? .measured(milliseconds: delay)
                            : .failed
                    } else {
                        latency[member] = .untested
                    }
                }
                return Group(
                    name: group.name,
                    members: group.members,
                    now: group.now,
                    type: group.type,
                    latency: latency,
                    pinsOnRepick: ProxyGroupControlKind(rawType: group.type)
                        == .automatic
                )
            }
        )
    }
}
