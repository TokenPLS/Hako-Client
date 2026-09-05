import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 
 
 
enum HakoMacMenuPrimaryRow: Equatable {
     
    case intent(AppleClientConnectionIntent)
     
    case cancelStart
     
    case none

    static func resolve(
        phase: AppleClientConnectionPhase,
        intent: AppleClientConnectionIntent?
    ) -> HakoMacMenuPrimaryRow {
        if let intent { return .intent(intent) }
        switch phase {
        case .preparing: return .cancelStart
        case .disconnected, .connected, .disconnecting, .unavailable: return .none
        }
    }
}
