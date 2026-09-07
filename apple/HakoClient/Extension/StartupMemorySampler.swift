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
    func schedule(interval: TimeInterval) { source.schedule(deadline: .now() + interval, repeating: interval) }
    func setEventHandler(_ handler: @escaping @Sendable () -> Void) { source.setEventHandler(handler: handler) }
    func resume() { source.resume() }
    func cancel() { source.cancel() }
}

struct StartupSamplingDependencies: Sendable {
    var footprint: @Sendable () -> Int64 = { HakoMemoryFootprint() }
    var readPage: StartupPhasePager.Reader = StartupPhaseBindingReader.read
    var makeChannel: @Sendable (URL, DispatchQueue) -> StartupLogChannel = { StartupLogChannel(url: $0, queue: $1) }
    var reportTermination: @Sendable (String) -> Void = { text in
        Logger(subsystem: "org.example.hako.demo.extension", category: "memsample").info("\(text, privacy: .public)")
    }
}

 
 
final class StartupMemorySampler: @unchecked Sendable {
    static let shared = StartupMemorySampler()
    struct Token: Equatable, Sendable { fileprivate let id = UUID() }
    enum FinishReason: Sendable {
        case completed, stopped(String), failed(String)
        fileprivate var detail: String {
            switch self { case .completed: return "observation-complete"; case let .stopped(s), let .failed(s): return s }
        }
        fileprivate var label: String {
            switch self { case .completed: return "observation-complete"; case .stopped: return "stopped"; case .failed: return "failed" }
        }
    }
    private enum Phase { case sampling, tailEnded, finishing, finished, retired }
    private struct Event {
        let kind: StartupLogLocalKind
        let text: String?
        let prefix: String
        let at: Date
    }
     
     
    private struct PumpSnapshot {
        let committed: Int
        let pending: String?
        let localPending: Int
        let phasePending: Bool
        let sourceCalls: Int
        let sinkAttempts: Int
        let windowConfirmed: Bool
        let incomplete: Bool
        let through: String?
        let read: String?
        let confirmed: String?
        let confirmedDiagnostic: Int64
        init(_ driver: StartupLogDriverSnapshot, _ phase: StartupPhasePagingSnapshot?) {
            committed = driver.committedUnits; pending = driver.pendingID
            localPending = driver.localPendingIDs.count; phasePending = driver.phasePendingID != nil
            sourceCalls = driver.sourceCalls; sinkAttempts = driver.sinkAttempts
            windowConfirmed = driver.phaseWindowConfirmed; incomplete = driver.incomplete
            through = driver.terminalThrough; read = phase?.readCursor; confirmed = phase?.confirmedCursor
            confirmedDiagnostic = phase?.confirmedDiagnosticRevision ?? 0
        }
    }
    private final class Session: @unchecked Sendable {
        let token: Token
        let driver: StartupLogDriver
         
         
        var phase = Phase.sampling
        var pumpActive = false
        var summaryReported = false
        var lastPump: PumpSnapshot?
        var timer: (any StartupSamplingTimer)?
        var events: [Event] = []
        var counts: [StartupLogLocalKind: Int] = [:]
        var reservedBytes = 0
        var reservedUnits = 0
        var discardedEvents = 0
        var rejectedEvents = 0
        var initial: StartupPhasePage?
        var initialReady = false
        var terminal: StartupPhasePage?
        var terminalReady = false
        var terminalDriven = false
        var terminalEvents: [Event] = []
        var captureStartedAt: Date?
        var captureCompletedAt: Date?
        var stopRequestedAt: Date?
         
        var pager: StartupPhasePager?
        var pagerInitialized = false
        var ticks = 0
        var peak: Int64 = 0
        init(token: Token, driver: StartupLogDriver) { self.token = token; self.driver = driver }
    }

    private let queue: DispatchQueue
    private let metadataQueue: DispatchQueue
    private let dependencies: StartupSamplingDependencies
    private let limits: StartupLogDriverLimits
    private let makeTimer: @Sendable (DispatchQueue) -> any StartupSamplingTimer
    private let controlLock = NSLock()
    private var current: Session?
    private var channel: StartupLogChannel?
    private var pumpQueued = false

    init(queue: DispatchQueue = DispatchQueue(label: "network.hako.memsample", qos: .utility),
         metadataQueue: DispatchQueue = DispatchQueue(label: "network.hako.startup-capture", qos: .utility),
         dependencies: StartupSamplingDependencies = .init(), limits: StartupLogDriverLimits = .init(),
         makeTimer: @escaping @Sendable (DispatchQueue) -> any StartupSamplingTimer = { DispatchStartupSamplingTimer(queue: $0) }) {
        self.queue = queue; self.metadataQueue = metadataQueue; self.dependencies = dependencies
        self.limits = limits; self.makeTimer = makeTimer
    }

    func begin(container: URL) -> Token {
        let token = Token()
        let url = container.standardizedFileURL.resolvingSymlinksInPath()
            .appendingPathComponent(MemorySampleLog.extensionFileName)
        let captured = DispatchSemaphore(value: 0)
        let at = Date()
        let setup: ((any StartupSamplingTimer)?, Bool, String?) = locked {
            let previous = current
            let timer = previous?.timer; previous?.timer = nil; previous?.phase = .retired
            if let channel, channel.url != url {
                channel.retireCurrent(); current = nil
                return (timer, false, retirementReport(previous))
            }
            if channel == nil { channel = dependencies.makeChannel(url, queue) }
            guard let channel else { return (timer, false, retirementReport(previous)) }
            let session = Session(token: token, driver: channel.begin(owner: token.id, limits: limits))
            current = session
            _ = reserve(session, kind: .begin, text: "begin", at: at)
             
            metadataQueue.async { [self, session] in
                let result = session.driver.captureInitial { try dependencies.readPage(.init(cursor: "", throughCursor: "", maxBytes: 0)) }
                let page = decodeCapture(result)
                locked {
                    session.initial = page; session.initialReady = true
                    if page == nil { session.driver.markIncomplete() }
                    if current === session { schedulePump() }
                }
                captured.signal()
            }
            return (timer, true, retirementReport(previous))
        }
        setup.0?.cancel()
        if let report = setup.2 { dependencies.reportTermination(report) }
        guard setup.1 else {
            dependencies.reportTermination("startup sampling rejected a changed canonical log URL")
            return token
        }
         
         
        captured.wait()
        return token
    }

    func note(_ text: String, token: Token?) { offer(.note, text: text, token: token) }
    func mark(_ phase: String, token: Token?) { offer(.checkpoint, text: phase, token: token) }
    private func offer(_ kind: StartupLogLocalKind, text: String, token: Token?) {
        locked {
            guard let s = active(token) else { return }
            if reserve(s, kind: kind, text: text, at: Date()) { schedulePump() }
        }
    }

    func finish(token: Token?, reason: FinishReason) {
        let at = Date()
        let ending: (Session, (any StartupSamplingTimer)?)? = locked {
            guard let s = active(token) else { return nil }
            if case .completed = reason {
                guard s.phase == .sampling else { return nil }
                s.phase = .tailEnded
                _ = reserve(s, kind: .tailReason, text: reason.detail, at: at)
                _ = reserve(s, kind: .tailPeak, text: "peak", at: at)
                schedulePump()
            } else {
                s.phase = .finishing
                _ = s.driver.beginFinish()  
                if !s.events.isEmpty { s.discardedEvents += s.events.count; s.driver.markIncomplete(); s.events.removeAll() }
                s.stopRequestedAt = at
                 
                let text = reason.detail
                if text.utf8.count <= limits.maxUnitBytes - 128 {
                    _ = reserve(s, kind: .finishReason, text: text, prefix: reason.label + ": ", at: at)
                } else { s.rejectedEvents += 1; s.driver.markIncomplete() }
                _ = reserve(s, kind: .finishSample, text: reason.label, at: at)
                _ = reserve(s, kind: .finishPeak, text: "peak", at: at)
                metadataQueue.async { [self, s] in
                    let result = s.driver.captureTerminal {
                        locked { s.captureStartedAt = Date() }
                        return try dependencies.readPage(.init(cursor: "", throughCursor: "", maxBytes: 0))
                    }
                    let page = decodeCapture(result)
                    locked {
                        s.captureCompletedAt = Date(); s.terminal = page; s.terminalReady = true
                        if page == nil { s.driver.markIncomplete() }
                        if current === s { schedulePump() }
                    }
                }
            }
            let timer = s.timer; s.timer = nil
            return (s, timer)
        }
        guard let (s, timer) = ending else { return }
        timer?.cancel()
        let detail = reason.detail
        let report = detail.utf8.count <= limits.maxUnitBytes - 128
            ? reason.label + ": " + detail : reason.label + ": reason exceeds log unit limit"
        dependencies.reportTermination("startup sampling \(s.token.id): \(report)")
    }

     
     
    private func reserve(_ s: Session, kind: StartupLogLocalKind, text: String?, prefix: String = "", at: Date) -> Bool {
        let size = (text?.utf8.count ?? 0) + prefix.utf8.count
        let count = s.counts[kind, default: 0]
        let cap: Int
        switch kind { case .periodic: cap = limits.periodicUnits; case .note: cap = limits.noteUnits
        case .checkpoint: cap = limits.checkpointUnits; default: cap = 1 }
        guard size <= limits.maxUnitBytes - 128, count < cap,
              s.reservedUnits < limits.localUnits - (kind.terminal ? 0 : 3),
              size + 128 <= limits.localBytes - s.reservedBytes else { s.rejectedEvents = min(s.rejectedEvents, Int.max - 1) + 1; s.driver.markIncomplete(); return false }
        s.reservedUnits += 1; s.reservedBytes += size + 128; s.counts[kind] = count + 1
        let event = Event(kind: kind, text: text, prefix: prefix, at: at)
        if kind.terminal { s.terminalEvents.append(event) } else { s.events.append(event) }
        return true
    }

    private func schedulePump() {
        guard !pumpQueued else { return }
        pumpQueued = true
        queue.async { [self] in pump() }
    }

    private func pump() {
        let session = locked { () -> Session? in
            pumpQueued = false
            guard let s = current else { return nil }
            s.pumpActive = true
            return s
        }
        guard let s = session else { return }
         
         
        defer { finishPump(s) }
        let initial = locked { (s.initialReady, s.initial) }
        guard initial.0 else { return }
        if !s.pagerInitialized {
            s.pagerInitialized = true
            if let page = initial.1 { s.pager = StartupPhasePager(owner: s.token.id, initial: page, limits: limits, reader: dependencies.readPage) }
            installTimer(s)
        }
        var hasNormalEvents = false
        while let event = locked({ () -> Event? in
            guard current === s, s.phase == .sampling || s.phase == .tailEnded, !s.events.isEmpty else { return nil }
            return s.events.removeFirst()
        }) {
            hasNormalEvents = true
            materialize(event, s)
        }
         
         
         
        if hasNormalEvents {
            _ = s.driver.driveNormal(phaseStep: s.pager.map { pager in { pager.step($0) } })
        }
        let terminal = locked { () -> (StartupPhasePage?, [Event])? in
            guard current === s, s.phase == .finishing, s.terminalReady, !s.terminalDriven else { return nil }
            s.terminalDriven = true
            let events = s.terminalEvents; s.terminalEvents.removeAll()
            return (s.terminal, events)
        }
        if let (capture, events) = terminal {
            if let capture, let target = s.pager?.beginTerminal(capture) { _ = s.driver.adoptTerminalWindow(target) }
            else { s.driver.markIncomplete() }
            for event in events { materialize(event, s) }
            let result = s.driver.driveTerminal(phaseStep: s.pager.map { pager in { pager.step($0) } })
            let snapshot = PumpSnapshot(s.driver.snapshot(), s.pager?.snapshot)
            let report = locked { () -> String? in
                if current === s { s.phase = .finished }
                return claimSummary(s, snapshot: snapshot, result: String(describing: result), finalCounters: true)
            }
            if let report { dependencies.reportTermination(report) }
        }
    }

    private func finishPump(_ s: Session) {
         
         
        let snapshot = PumpSnapshot(s.driver.snapshot(), s.pager?.snapshot)
        let report = locked { () -> String? in
            s.lastPump = snapshot
            s.pumpActive = false
            guard s.phase == .retired else { return nil }
            return claimSummary(s, snapshot: snapshot, result: "retired", finalCounters: true)
        }
        if let report { dependencies.reportTermination(report) }
    }

     
     
    private func retirementReport(_ s: Session?) -> String? {
        guard let s, !s.pumpActive else { return nil }
        return claimSummary(s, snapshot: s.lastPump, result: "retired", finalCounters: false)
    }

    private func claimSummary(_ s: Session, snapshot: PumpSnapshot?, result: String, finalCounters: Bool) -> String? {
        guard !s.summaryReported else { return nil }
        s.summaryReported = true
        let retired = s.phase == .retired
        let incomplete = (snapshot?.incomplete ?? true) || !(snapshot?.windowConfirmed ?? false)
            || !s.events.isEmpty || !s.terminalEvents.isEmpty || s.discardedEvents > 0 || s.rejectedEvents > 0
        let through = snapshot?.through ?? s.terminal?.headCursor ?? "none"
        let read = snapshot?.read ?? s.initial?.nextCursor ?? "none"
        let confirmed = snapshot?.confirmed ?? s.initial?.nextCursor ?? "none"
        let counterPoint = finalCounters ? "final-pump" : (snapshot == nil ? "not-started" : "last-completed-pump")
         
         
        return "startup sampling \(s.token.id) drain=\(retired ? "retired" : result) incomplete=\(incomplete) committed=\(snapshot?.committed ?? 0) pending=\(snapshot?.pending ?? "none") localPending=\(snapshot?.localPending ?? 0) phasePending=\(snapshot?.phasePending ?? false) terminalPending=\(s.terminalEvents.count) rawPending=\(s.events.count) sourceCalls=\(snapshot?.sourceCalls ?? 0) sinkAttempts=\(snapshot?.sinkAttempts ?? 0) counters=\(counterPoint) through=\(through) read=\(read) confirmed=\(confirmed) confirmedDiagnostic=\(snapshot?.confirmedDiagnostic ?? 0) reservedUnits=\(s.reservedUnits) reservedBytes=\(s.reservedBytes) rejected=\(s.rejectedEvents) discarded=\(s.discardedEvents) stopRequested=\(s.stopRequestedAt?.timeIntervalSince1970 ?? 0) captureStarted=\(s.captureStartedAt?.timeIntervalSince1970 ?? 0) captureCompleted=\(s.captureCompletedAt?.timeIntervalSince1970 ?? 0) captureReady=\(s.terminalReady)"
    }

    private func materialize(_ event: Event, _ s: Session) {
        guard accepts(s, terminal: event.kind.terminal) else { s.driver.markIncomplete(); return }
        let line: String
        switch event.kind {
        case .note, .tailReason, .finishReason:
            line = "    " + MemorySampleLog.noteLine(at: event.at, text: event.prefix + (event.text ?? ""))
        case .tailPeak, .finishPeak:
            line = MemorySampleLog.line(at: event.at, footprintBytes: s.peak, phase: "peak")
        default:
            let fp = dependencies.footprint()
            guard accepts(s, terminal: event.kind.terminal) else { s.driver.markIncomplete(); return }
            s.peak = max(s.peak, fp)
            line = MemorySampleLog.line(at: event.at, footprintBytes: fp, phase: event.text)
        }
        if s.driver.offerLocal(event.kind, bytes: Data((line + "\n").utf8)) == nil { s.driver.markIncomplete() }
    }

    private func installTimer(_ s: Session) {
        guard locked({ current === s && s.phase == .sampling }) else { return }
        let timer = makeTimer(queue)
        timer.schedule(interval: 0.01)
        timer.setEventHandler { [weak self, weak s] in if let self, let s { self.tick(s) } }
        timer.resume()
        let installed = locked { () -> Bool in
            guard current === s, s.phase == .sampling else { return false }
            s.timer = timer; return true
        }
        if !installed { timer.cancel() }
    }
    private func tick(_ s: Session) {
        let timer = locked { current === s && s.phase == .sampling ? s.timer : nil }
        guard let timer else { return }
        s.ticks += 1
        locked {
            guard current === s, s.phase == .sampling else { return }
            _ = reserve(s, kind: .periodic, text: nil, at: Date()); schedulePump()
        }
        if s.ticks == 300 { timer.schedule(interval: 0.2) }
        if s.ticks == 360 { timer.schedule(interval: 1) }
        if s.ticks >= 375 { finish(token: s.token, reason: .completed) }
    }
    private func decodeCapture(_ result: Result<Data, StartupLogReadFailure>) -> StartupPhasePage? {
        guard case let .success(bytes) = result else { return nil }
        return try? StartupPhasePage.capture(bytes, limit: limits.pageBytes)
    }
    private func active(_ token: Token?) -> Session? {
        guard let token, let s = current, s.token == token, s.phase == .sampling || s.phase == .tailEnded else { return nil }
        return s
    }
    private func accepts(_ s: Session, terminal: Bool) -> Bool {
        locked { current === s && (terminal ? s.phase == .finishing : s.phase == .sampling || s.phase == .tailEnded) }
    }
    private func locked<T>(_ body: () -> T) -> T { controlLock.lock(); defer { controlLock.unlock() }; return body() }
}
