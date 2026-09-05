import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ActiveConfigurationText {
    private struct Entry {
        let pointer: ActiveConfigurationPointer
        let text: String
    }

     
     
     
    private static let lock = NSLock()
    private static var entry: Entry?

     
     
     
     
     
     
     
    static func current() -> String? {
        guard let container = HakoAppIdentifiers.appGroupContainer,
            let store = try? ConfigResourceStore(containerURL: container),
            let pointer = try? store.activeIdentity()
        else { return nil }

        lock.lock()
        if let cached = entry, cached.pointer == pointer {
            defer { lock.unlock() }
            return cached.text
        }
        lock.unlock()

         
         
         
         
         
        guard let text = try? store.loadCurrent().text else { return nil }
        lock.lock()
        entry = Entry(pointer: pointer, text: text)
        lock.unlock()
        return text
    }

     
     
     
    static func invalidate() {
        lock.lock()
        entry = nil
        lock.unlock()
    }
}
