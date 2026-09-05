import Foundation
import Hako

 
 
 
 
 
 
 
 
 
 
 
enum SideUpdateDeferral {
    static func isDeferred(_ error: Error) -> Bool {
        (error as NSError).localizedDescription
            .hasPrefix(HakoSideUpdateDeferredPrefix)
    }

     
     
    static func displayMessage(_ error: Error) -> String {
        let text = (error as NSError).localizedDescription
        guard text.hasPrefix(HakoSideUpdateDeferredPrefix) else { return text }
        return String(text.dropFirst(HakoSideUpdateDeferredPrefix.count))
    }
}
