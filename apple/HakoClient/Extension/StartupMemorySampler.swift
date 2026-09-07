import Foundation
import Hako
import os

protocol StartupSamplingTimer: AnyObject, Sendable {
    func schedule(interval: TimeInterval)
    func setEventHandler(_ handler: @escaping @Sendable () -> Void)
    func resume()
    func cancel()
}

private final class DispatchStartupSamplingTimer: StartupSamplingTimer, @unchecked Sendable {
    private let source: DispatchSourceTimer
    init(queue: DispatchQueue) { source = DispatchSource.makeTimerSource(queue: queue) }
    func schedule(interval: TimeInterval) {
        source.schedule(deadline: .now() + interval, repeating: interval)
    }
    func setEventHandler(_ handler: @escaping @Sendable () -> Void) {
        source.setEventHandler(handler: handler)
    }
    func resume() { source.resume() }
    func cancel() { source.cancel() }
}

struct StartupSamplingDependencies: Sendable {
     
    var beforeBoundaryAppend: @Sendable () -> Void = {}
    var footprint: @Sendable () -> Int64 = { HakoMemoryFootprint() }
    var trace: @Sendable () -> String = { HakoStartupPhaseTrace() }
    var diagnostic: @Sendable () -> String = { HakoStartupPhaseDiagnostic() }
    var append: @Sendable (String, URL, Int) -> Void = { line, url, maxBytes in
        MemorySampleLog.append(line, to: url, maxBytes: maxBytes)
    }
    var reportTermination: @Sendable (String) -> Void = { text in
        Logger(subsystem: "org.example.hako.demo.extension", category: "memsample")
            .info("\(text, privacy: .public)")
    }
}

 
 
 
final class StartupMemorySampler: @unchecked Sendable {
    static let shared = StartupMemorySampler()

    struct Token: Equatable, Sendable {
        fileprivate let id = UUID()
    }

    enum FinishReason: Sendable {
        case completed
        case stopped(String)
        case failed(String)

        fileprivate var description: String {
            switch self {
            case .completed: return "observation-complete"
            case let .stopped(reason): return "stopped: " + reason
            case let .failed(reason): return "failed: " + reason
            }
        }
        fileprivate var finalSamplePhase: String? {
            switch self {
            case .completed: return nil  
            case .stopped: return "stopped"
            case .failed: return "failed"
            }
        }
    }

    private enum Phase { case sampling, tailEnded, finishing, finished }
    private enum Access { case periodic, active, terminal, completed }
    private final class Session: @unchecked Sendable {
        let token = Token()
        let url: URL
        let beganAt: Date
         
        var phase = Phase.sampling
        var timer: (any StartupSamplingTimer)?
         
        var separatorAttempted = false
        var ticks = 0
        var peak: Int64 = 0
        var drainedCorePhases = 0
        var lastCoreDiagnostic = ""
        init(container: URL, at: Date) {
            url = container.appendingPathComponent(MemorySampleLog.extensionFileName)
            beganAt = at
        }
    }

    private static let maxBytes = 512 * 1024
    private let queue: DispatchQueue
    private let dependencies: StartupSamplingDependencies
    private let makeTimer: @Sendable (DispatchQueue) -> any StartupSamplingTimer
     
     
    private let controlLock = NSLock()
    private var current: Session?

    init(
        queue: DispatchQueue = DispatchQueue(label: "network.hako.memsample", qos: .utility),
        dependencies: StartupSamplingDependencies = StartupSamplingDependencies(),
        makeTimer: @escaping @Sendable (DispatchQueue) -> any StartupSamplingTimer = { DispatchStartupSamplingTimer(queue: $0) }
    ) {
        self.queue = queue
        self.dependencies = dependencies
        self.makeTimer = makeTimer
    }

    func begin(container: URL) -> Token {
         
        let session = Session(container: container, at: Date())
        let previousTimer = withControlLock {
            let old = current?.timer
            current?.timer = nil
            current?.phase = .finished
            current = session
            return old
        }
        previousTimer?.cancel()
        queue.async { [weak self] in self?.beginOnQueue(session) }
        return session.token
    }

    func note(_ text: String, token: Token?) {
        guard let session = activeSession(token) else { return }
        let at = Date()
        queue.async { [weak self] in
            self?.append("    " + MemorySampleLog.noteLine(at: at, text: text), session, access: .active)
        }
    }

    func mark(_ phase: String, token: Token?) {
        guard let session = activeSession(token) else { return }
        let at = Date()
        queue.async { [weak self] in self?.sample(session, phase: phase, at: at, allowing: .active) }
    }

     
     
     
    func finish(token: Token?, reason: FinishReason) {
        let ending: (Session, (any StartupSamplingTimer)?)? = withControlLock {
            guard let token, let session = current,
                  session.token == token,
                  session.phase == .sampling || session.phase == .tailEnded else { return nil }
            if case .completed = reason {
                guard session.phase == .sampling else { return nil }
                 
                 
                session.phase = .tailEnded
            } else {
                session.phase = .finishing
            }
            let timer = session.timer
            session.timer = nil
            return (session, timer)
        }
        guard let (session, timer) = ending else { return }
        timer?.cancel()
         
        dependencies.reportTermination("startup sampling \(session.token.id): \(reason.description)")
        let at = Date()
        queue.async { [weak self] in self?.finishOnQueue(session, reason: reason, at: at) }
    }

    private func beginOnQueue(_ session: Session) {
        guard accepts(session, access: .periodic) else { return }
        ensureLaunchBoundary(session, access: .periodic)
        guard accepts(session, access: .periodic) else { return }
        let timer = makeTimer(queue)
        timer.schedule(interval: 0.01)
        timer.setEventHandler { [weak self, weak session] in
            guard let self, let session else { return }
            self.tick(session)
        }
         
         
        timer.resume()
        let installed = withControlLock {
            guard current === session, session.phase == .sampling else { return false }
            session.timer = timer
            return true
        }
        guard installed else { timer.cancel(); return }
        sample(session, phase: "begin", at: session.beganAt, allowing: .periodic)
    }

    private func tick(_ session: Session) {
        guard accepts(session, access: .periodic) else { return }
        session.ticks += 1
        sample(session, phase: nil, at: Date(), allowing: .periodic)
        let timer = withControlLock {
            current === session && session.phase == .sampling ? session.timer : nil
        }
        guard let timer else { return }
        if session.ticks == 300 { timer.schedule(interval: 0.2) }
        if session.ticks == 360 { timer.schedule(interval: 1) }
        if session.ticks >= 375 { finish(token: session.token, reason: .completed) }
    }

    private func finishOnQueue(_ session: Session, reason: FinishReason, at: Date) {
        let access: Access = reason.finalSamplePhase == nil ? .completed : .terminal
        guard accepts(session, access: access) else { return }
        ensureLaunchBoundary(session, access: access)
        append("    " + MemorySampleLog.noteLine(at: at, text: reason.description), session, access: access)
        if let phase = reason.finalSamplePhase {
            sample(session, phase: phase, at: at, allowing: .terminal)
        }
        append(MemorySampleLog.line(at: at, footprintBytes: session.peak, phase: "peak"), session, access: access)
        if case .terminal = access {
            withControlLock {
                if current === session, session.phase == .finishing { session.phase = .finished }
            }
        }
    }

    private func sample(_ session: Session, phase: String?, at: Date, allowing state: Access) {
        guard accepts(session, access: state) else { return }
        drainCorePhases(session, allowing: state)
        guard accepts(session, access: state) else { return }
        let footprint = dependencies.footprint()
        guard accepts(session, access: state) else { return }
        session.peak = max(session.peak, footprint)
        append(MemorySampleLog.line(at: at, footprintBytes: footprint, phase: phase), session, access: state)
    }

    private func drainCorePhases(_ session: Session, allowing state: Access) {
        guard accepts(session, access: state) else { return }
         
        let trace = dependencies.trace()
        guard accepts(session, access: state) else { return }
        let diagnostic = "core-diag lines=\(trace.isEmpty ? 0 : trace.split(separator: "\n").count) "
            + dependencies.diagnostic()
        guard accepts(session, access: state) else { return }
        if diagnostic != session.lastCoreDiagnostic {
            session.lastCoreDiagnostic = diagnostic
            append("    " + diagnostic, session, access: state)
        }
        guard !trace.isEmpty else { return }
        let lines = trace.split(separator: "\n").map(String.init)
        guard lines.count > session.drainedCorePhases else { return }
        for line in lines[session.drainedCorePhases...] {
            guard accepts(session, access: state) else { return }
            append("    " + line, session, access: state)
        }
         
         
        session.drainedCorePhases = lines.count
    }

    private func append(_ line: String, _ session: Session, access: Access) {
        guard accepts(session, access: access) else { return }
         
         
        dependencies.append(line, session.url, Self.maxBytes)
    }

    private func ensureLaunchBoundary(_ session: Session, access: Access) {
        guard !session.separatorAttempted, accepts(session, access: access) else { return }
        dependencies.beforeBoundaryAppend()
         
         
         
         
        dependencies.append("--- launch ---", session.url, Self.maxBytes)
        session.separatorAttempted = true  
    }

    private func activeSession(_ token: Token?) -> Session? {
        withControlLock {
            guard let token, let session = current,
                  session.token == token,
                  session.phase == .sampling || session.phase == .tailEnded else { return nil }
            return session
        }
    }

    private func accepts(_ session: Session, access: Access) -> Bool {
        withControlLock {
            guard current === session else { return false }
            switch access {
            case .periodic: return session.phase == .sampling
            case .active: return session.phase == .sampling || session.phase == .tailEnded
            case .terminal: return session.phase == .finishing
            case .completed: return session.phase == .tailEnded
            }
        }
    }

    private func withControlLock<T>(_ body: () -> T) -> T {
        controlLock.lock()
        defer { controlLock.unlock() }
        return body()
    }
}
