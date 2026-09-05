import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxyEditorFieldUnits {
     
     
     
     
     
    static func unit(forKey key: String) -> String? {
        switch key {
        case "up", "down": "Mbps"
         
         
         
        case "hop-interval", "idle-session-timeout": "s"
         
         
         
         
        case "mtu", "obfs-min-packet-size", "obfs-max-packet-size": "bytes"
        default: nil
        }
    }

     
     
     
    static func displayUnit(forKey key: String, value: String) -> String? {
        guard let unit = unit(forKey: key) else { return nil }
        return value.contains(where: \.isLetter) ? nil : unit
    }
}
