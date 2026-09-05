#if canImport(UIKit)
import UIKit

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ConfigStoreSuspensionShield {
    static func install() {
        ConfigResourceStore.suspensionShield = SuspensionShield(
            begin: { holder.coalescer.acquire(); return nil },
            end: { _ in holder.coalescer.release() }
        )
    }

    private static let holder = AssertionHolder()

     
    private final class AssertionHolder {
        lazy var coalescer = BackgroundAssertionCoalescer(
            linger: 2,
            begin: { [weak self] in self?.beginTask() ?? false },
            end: { [weak self] in self?.endTask() },
            schedule: { [queue] delay, work in
                let item = DispatchWorkItem(block: work)
                queue.asyncAfter(deadline: .now() + delay, execute: item)
                return { item.cancel() }
            }
        )

        private func beginTask() -> Bool {
            let began = UIApplication.shared.beginBackgroundTask(
                withName: "ConfigResourceStore.flock"
            ) { [weak self] in
                 
                 
                self?.coalescer.expire()
            }
            lock.lock()
            identifier = began
            lock.unlock()
            return began != .invalid
        }

        private func endTask() {
            lock.lock()
            let ended = identifier
            identifier = .invalid
            lock.unlock()
            guard ended != .invalid else { return }
            UIApplication.shared.endBackgroundTask(ended)
        }

        private let lock = NSLock()
        private var identifier: UIBackgroundTaskIdentifier = .invalid
        private let queue = DispatchQueue(label: "network.hako.shield")
    }
}
#endif
