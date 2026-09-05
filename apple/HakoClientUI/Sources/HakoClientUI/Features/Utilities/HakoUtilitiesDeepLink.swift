import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoUtilitiesDeepLink {
     
     
     
     
     
    public static func presented(
        for destination: HakoUtilitiesDestination
    ) -> HakoUtilitiesDestination? {
        destination == .root ? nil : destination
    }

     
     
     
     
     
     
    public static let dismissed: HakoUtilitiesDestination = .root
}
