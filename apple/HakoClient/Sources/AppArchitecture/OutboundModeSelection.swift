import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum OutboundModeSelection {

     
     
     
     
     
     
     
     
     
     
     
     
    static func changesNothing(
        requested: Profile.OutboundMode,
        stored: Profile.OutboundMode,
        running: String?
    ) -> Bool {
        guard stored == requested else { return false }
        guard let running else { return true }
        return running.lowercased() == requested.rawValue
    }
}
