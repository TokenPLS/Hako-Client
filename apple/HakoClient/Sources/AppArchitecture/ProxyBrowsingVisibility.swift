import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxyBrowsingVisibility {

    enum Mode: Equatable {
        case rule
        case global
        case direct

         
         
         
         
         
        init(coreValue: String) {
            switch coreValue.lowercased() {
            case "global": self = .global
            case "direct": self = .direct
            default: self = .rule
            }
        }
    }

     
     
    static let kernelGlobalGroupName = "GLOBAL"

     
     
     
     
     
     
     
     
     
     
     
     
     
    static func standaloneNodes<Node>(
        _ nodes: [Node],
        mode: Mode
    ) -> [Node] {
        mode == .direct ? [] : nodes
    }

     
     
     
     
     
     
     
    static func groups<Group>(
        _ groups: [Group],
        mode: Mode,
        name: (Group) -> String,
        isHidden: (Group) -> Bool
    ) -> [Group] {
        switch mode {
        case .direct:
            return []
        case .global:
            return groups.filter { !isHidden($0) }
        case .rule:
            return groups.filter { group in
                guard !isHidden(group) else { return false }
                 
                 
                 
                 
                 
                 
                 
                 
                 
                return name(group) != kernelGlobalGroupName
            }
        }
    }
}
