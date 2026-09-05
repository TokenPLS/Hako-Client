import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
final class RuntimeIdentityCache {
    init(
        ttl: TimeInterval,
        now: @escaping () -> Date = Date.init,
        load: @escaping () -> NodesRuntimeIdentity?
    ) {
        self.ttl = ttl
        self.now = now
        self.load = load
    }

    func current() -> NodesRuntimeIdentity? {
        lock.lock()
        defer { lock.unlock() }
        if let cached, now().timeIntervalSince(cached.at) < ttl {
            return cached.value
        }
        guard let fresh = load() else {
            cached = nil
            return nil
        }
        cached = (now(), fresh)
        return fresh
    }

     
    func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }

    private let lock = NSLock()
    private var cached: (at: Date, value: NodesRuntimeIdentity)?
    private let ttl: TimeInterval
    private let now: () -> Date
    private let load: () -> NodesRuntimeIdentity?
}
