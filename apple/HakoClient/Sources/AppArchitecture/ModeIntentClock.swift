import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ModeIntentClock {
    private static let lock = NSLock()
    private static var value: UInt64 = 0

    static var sequence: UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

     
     
    @discardableResult
    static func next() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        value &+= 1
        return value
    }

     
    static func isCurrent(_ stamp: UInt64) -> Bool {
        stamp == sequence
    }

     
     
     
     
     
     
     
    static func stamped(_ write: () -> Void) {
        if Thread.isMainThread {
            write()
            next()
        } else {
            DispatchQueue.main.sync {
                write()
                next()
            }
        }
    }
}
