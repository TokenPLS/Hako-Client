import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum LocalNetworkPermission {
     
     
     
    static let defaultsKey = "core.allow-lan-permitted"

     
     
     
     
     
    static func isPermitted(_ defaults: UserDefaults?) -> Bool {
        defaults?.bool(forKey: defaultsKey) ?? false
    }

    static func setPermitted(_ permitted: Bool, in defaults: UserDefaults?) {
        defaults?.set(permitted, forKey: defaultsKey)
    }
}
