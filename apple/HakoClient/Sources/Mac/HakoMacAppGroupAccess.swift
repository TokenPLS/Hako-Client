import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum HakoMacAppGroupAccess {
     
     
     
     
     
     
    static func readableContainer() -> URL? {


        guard let container = HakoAppIdentifiers.appGroupContainer else {
            return nil
        }
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: container.path,
            isDirectory: &isDirectory
        )
        guard exists, isDirectory.boolValue else { return nil }
        guard FileManager.default.isReadableFile(atPath: container.path) else {
            return nil
        }
        return container
    }
}
