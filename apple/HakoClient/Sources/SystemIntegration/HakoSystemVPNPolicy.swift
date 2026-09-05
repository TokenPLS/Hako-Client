import Foundation

 
 
 
 
 
 
 
 
enum HakoSystemVPNPolicy {
    enum Command: Equatable {
        case start
        case stop
         
         
        case unchanged
    }

     
     
    static func isActive(_ status: String) -> Bool {
        ["connected", "connecting", "reasserting"].contains(status.lowercased())
    }

    static func command(
        for action: HakoSystemRoute.VPNAction,
        isActive: Bool
    ) -> Command {
        switch action {
         
         
        case .connect:
            return isActive ? .unchanged : .start
         
         
         
         
        case .disconnect:
            return .stop
        case .toggle:
            return isActive ? .stop : .start
        }
    }

     
     
     
     
     
     
     
    static func controlSnapshot(status: String, isLoaded: Bool) -> Bool? {
        guard isLoaded else { return nil }
        return isActive(status)
    }
}
