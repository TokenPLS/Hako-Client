import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
final class TunnelRequestCoalescer {
     
     
     
     
     
    nonisolated static let defaultGestureWindow: TimeInterval = 0.5

     
     
     
     
     
     
     
     
     
     
    nonisolated static let defaultSettlingWindow: TimeInterval = 2

    private var inFlight: Task<Bool, Never>?
    private var lastPress: Date?
    private var lastResult = false
    private let pressWindow: () -> TimeInterval
    private let isSettling: () -> Bool
    private let settlingWindow: TimeInterval
    private let now: () -> Date

    init(
        gestureWindow: @escaping () -> TimeInterval = { TunnelRequestCoalescer.defaultGestureWindow },
        isSettling: @escaping () -> Bool = { false },
        settlingWindow: TimeInterval = TunnelRequestCoalescer.defaultSettlingWindow,
        now: @escaping () -> Date = Date.init
    ) {
        self.pressWindow = gestureWindow
        self.isSettling = isSettling
        self.settlingWindow = settlingWindow
        self.now = now
    }

     
     
     
    var isBusy: Bool { inFlight != nil }

    private func currentWindow() -> TimeInterval {
        isSettling() ? max(pressWindow(), settlingWindow) : pressWindow()
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    enum Origin {
        case gesture
        case programmatic
    }

    @discardableResult
    func run(
        origin: Origin = .gesture,
        _ work: @escaping @MainActor () async -> Bool
    ) async -> Bool {
        let pressedAt = now()
        let insideGesture = origin == .gesture && (lastPress.map {
            pressedAt.timeIntervalSince($0) < currentWindow()
        } ?? false)
        lastPress = pressedAt

        if let existing = inFlight {
            let result = await existing.value
             
             
            lastPress = now()
            return result
        }
        if insideGesture {
            return lastResult
        }

        let task = Task<Bool, Never> { @MainActor in await work() }
        inFlight = task
        let result = await task.value
         
         
        lastPress = now()
        lastResult = result
         
         
         
        if inFlight == task {
            inFlight = nil
        }
        return result
    }
}
