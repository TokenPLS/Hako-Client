import Foundation

 
 
 
 
struct PlatformConfigIntent: Decodable, Equatable {
     
     
     
     
    let tunRestartFingerprint: String
    let strictRoute: Bool
    let includedRouteCount: Int
    let excludedRouteCount: Int
    let hasLegacyIncludedRoutes: Bool
    let hasLegacyExcludedRoutes: Bool
}

 
enum ActivationDecision: Equatable {
    case start     
    case reload    
    case restart   

    static func decide(current: PlatformConfigIntent?, next: PlatformConfigIntent,
                       tunnelUp: Bool) -> ActivationDecision {
        guard tunnelUp else { return .start }
        guard let current else { return .restart }
        return current == next ? .reload : .restart
    }
}
