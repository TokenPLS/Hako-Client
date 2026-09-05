import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
final class BackgroundAssertionCoalescer {
    typealias Cancel = () -> Void

    init(
        linger: TimeInterval,
        begin: @escaping () -> Bool,
        end: @escaping () -> Void,
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Cancel
    ) {
        self.linger = linger
        self.begin = begin
        self.end = end
        self.schedule = schedule
    }

    func acquire() {
        var beginNow = false
        lock.lock()
        holders += 1
        cancelPendingEnd?()
        cancelPendingEnd = nil
        if !held && !expired {
            held = true
            beginNow = true
        }
        lock.unlock()
        guard beginNow else { return }
        if !begin() {
            lock.lock()
            held = false
            lock.unlock()
        }
    }

    func release() {
        var armLinger = false
        lock.lock()
        holders = max(0, holders - 1)
        if holders == 0 {
             
             
            expired = false
            armLinger = held
        }
        lock.unlock()
        guard armLinger else { return }
        let cancel = schedule(linger) { [weak self] in self?.lingerElapsed() }
        lock.lock()
        if holders == 0 && held && cancelPendingEnd == nil {
            cancelPendingEnd = cancel
            lock.unlock()
        } else {
             
             
            lock.unlock()
            cancel()
        }
    }

     
     
     
     
    func expire() {
        var endNow = false
        lock.lock()
        if held {
            held = false
            endNow = true
            expired = holders > 0
        }
        cancelPendingEnd?()
        cancelPendingEnd = nil
        lock.unlock()
        if endNow { end() }
    }

    private func lingerElapsed() {
        var endNow = false
        lock.lock()
        cancelPendingEnd = nil
        if holders == 0 && held {
            held = false
            endNow = true
        }
        lock.unlock()
        if endNow { end() }
    }

    private let lock = NSLock()
    private var holders = 0
    private var held = false
    private var expired = false
    private var cancelPendingEnd: Cancel?

    private let linger: TimeInterval
    private let begin: () -> Bool
    private let end: () -> Void
    private let schedule: (TimeInterval, @escaping () -> Void) -> Cancel
}
