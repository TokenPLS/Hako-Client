import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
public final class ConnectionRequestCoalescer {
    private var inFlight: Task<Bool, Never>?
    private var lastPress: Date?
    private var lastResult = false
    private let pressWindow: () -> TimeInterval
    private let isSettling: () -> Bool
    private let settlingWindow: TimeInterval
    private let now: () -> Date

    public init(
        gestureWindow: @escaping () -> TimeInterval,
        isSettling: @escaping () -> Bool = { false },
        settlingWindow: TimeInterval = 2,
        now: @escaping () -> Date = Date.init
    ) {
        self.pressWindow = gestureWindow
        self.isSettling = isSettling
        self.settlingWindow = settlingWindow
        self.now = now
    }

     
     
     
     
     
     
     
     
     
     
    private func gestureWindow() -> TimeInterval {
        isSettling() ? max(pressWindow(), settlingWindow) : pressWindow()
    }

     
     
     
     
     
     
     
     
    @discardableResult
    public func run(_ work: @escaping @Sendable () async -> Bool) async -> Bool {
        let pressedAt = now()
        let insideGesture = lastPress.map {
            pressedAt.timeIntervalSince($0) < gestureWindow()
        } ?? false
        lastPress = pressedAt

        if let existing = inFlight {
            let result = await existing.value
             
             
            lastPress = max(lastPress ?? now(), now())
            return result
        }
        if insideGesture {
            return lastResult
        }

        let task = Task<Bool, Never> { await work() }
        inFlight = task
        let result = await task.value
         
         
        lastPress = now()
        lastResult = result
         
         
        if inFlight == task {
            inFlight = nil
        }
        return result
    }

     
     
     
    public var isBusy: Bool { inFlight != nil }
}
