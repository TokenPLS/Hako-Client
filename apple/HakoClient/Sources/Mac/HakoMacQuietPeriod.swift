import Foundation

 
 
 
 
 
 
 
@MainActor
final class HakoMacQuietPeriod {
     
    typealias Schedule = (_ delay: TimeInterval, _ fire: @escaping () -> Void) -> () -> Void

    private let seconds: TimeInterval
    private let schedule: Schedule
    private var cancelPending: (() -> Void)?
    private var generation = 0

    init(seconds: TimeInterval, schedule: @escaping Schedule = HakoMacQuietPeriod.mainQueue) {
        self.seconds = seconds
        self.schedule = schedule
    }

     
     
    func request(_ work: @escaping @MainActor () -> Void) {
        cancelPending?()
        generation &+= 1
        let mine = generation
        cancelPending = schedule(seconds) { [weak self] in
            guard let self, self.generation == mine else { return }
            self.cancelPending = nil
            work()
        }
    }

    func cancel() {
        cancelPending?()
        cancelPending = nil
        generation &+= 1
    }

    nonisolated static func mainQueue(_ delay: TimeInterval, _ fire: @escaping () -> Void) -> () -> Void {
        let item = DispatchWorkItem(block: fire)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return { item.cancel() }
    }
}
