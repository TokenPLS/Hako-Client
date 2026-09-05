import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ReloadRefusal {

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func isRaceWithActivation(_ reason: String?) -> Bool {
        guard let reason, !reason.isEmpty else { return false }
        let text = reason.lowercased()
        return text.contains("silent") || text.contains("service not running")
    }
}
