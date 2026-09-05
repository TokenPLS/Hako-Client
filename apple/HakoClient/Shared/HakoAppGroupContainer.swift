import Foundation

 
 
extension HakoAppIdentifiers {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static let appGroupContainer: URL? = {
        let root = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
#if os(tvOS)
        return root?
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
#else
        return root
#endif
    }()
}
