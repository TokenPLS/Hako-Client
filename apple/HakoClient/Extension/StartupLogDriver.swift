import Foundation

struct StartupLogWorkBudget: Equatable, Sendable {
    var sourceCalls: Int
    var sourceBytes: Int
    var sinkAttempts: Int
    var sinkBytes: Int

    fileprivate var values: [Int] { [sourceCalls, sourceBytes, sinkAttempts, sinkBytes] }
    fileprivate func subtracting(_ other: Self) -> Self {
        .init(sourceCalls: sourceCalls - other.sourceCalls, sourceBytes: sourceBytes - other.sourceBytes,
              sinkAttempts: sinkAttempts - other.sinkAttempts, sinkBytes: sinkBytes - other.sinkBytes)
    }
    fileprivate mutating func takeSource(_ bytes: Int) -> Bool {
        guard sourceCalls > 0, bytes >= 0, bytes <= sourceBytes else { return false }
        sourceCalls -= 1; sourceBytes -= bytes; return true
    }
    fileprivate mutating func takeSink(_ bytes: Int) -> Bool {
        guard sinkAttempts > 0, bytes > 0, bytes <= sinkBytes else { return false }
        sinkAttempts -= 1; sinkBytes -= bytes; return true
    }
}

 
struct StartupLogDriverLimits: Sendable {
    var maxFileBytes = 512 * 1024
    var recoveryBytesPerAttempt = 512 * 1024
    var maxUnitBytes = 64 * 1024
    var pageBytes = 64 * 1024
    var localUnits = 512
    var localBytes = 256 * 1024
    var periodicUnits = 375
    var noteUnits = 64
    var checkpointUnits = 64
    var lifetime = StartupLogWorkBudget(sourceCalls: 512, sourceBytes: 32 * 1024 * 1024,
                                        sinkAttempts: 2048, sinkBytes: 16 * 1024 * 1024)
    var normal = StartupLogWorkBudget(sourceCalls: 1, sourceBytes: 64 * 1024,
                                      sinkAttempts: 8, sinkBytes: 256 * 1024)
    var terminal = StartupLogWorkBudget(sourceCalls: 4, sourceBytes: 256 * 1024,
                                        sinkAttempts: 16, sinkBytes: 256 * 1024)
    var terminalAttemptsPerUnit = 3

    fileprivate func validate() {
        precondition(maxFileBytes > 0 && maxUnitBytes > 0 && maxUnitBytes <= maxFileBytes)
        precondition(pageBytes > 0 && recoveryBytesPerAttempt > 0)
        precondition(localUnits >= 3 && localBytes > 0 && periodicUnits >= 0 && noteUnits >= 0 && checkpointUnits >= 0)
        precondition(terminalAttemptsPerUnit > 0)
        for budget in [lifetime, normal, terminal] {
            precondition(budget.values.allSatisfy { $0 >= 0 })
            precondition(budget.sourceCalls <= Int.max - budget.sinkAttempts)
        }
        precondition(zip(lifetime.values, terminal.values).allSatisfy { $0 >= $1 })
        precondition(recoveryBytesPerAttempt <= Int.max / max(1, lifetime.sinkAttempts))
    }
}

enum StartupLogLocalKind: Hashable, Sendable {
    case begin, periodic, checkpoint, note, tailReason, tailPeak, finishReason, finishSample, finishPeak
    var terminal: Bool {
        switch self { case .finishReason, .finishSample, .finishPeak: return true; default: return false }
    }
    fileprivate func id(_ ordinal: Int) -> String {
        switch self {
        case .begin: return "sample/begin"
        case .periodic: return "sample/tick/\(ordinal)"
        case .checkpoint: return "checkpoint/\(ordinal)"
        case .note: return "note/\(ordinal)"
        case .tailReason: return "tail/reason"
        case .tailPeak: return "tail/peak"
        case .finishReason: return "finish/reason"
        case .finishSample: return "finish/sample"
        case .finishPeak: return "finish/peak"
        }
    }
}

 
 
 
final class StartupLogUnit {
    let owner: UUID
    let id: String
    let bytes: Data
    fileprivate let didCommit: () -> Void
    fileprivate var intent = MemorySampleLog.UnitIntent.append
    fileprivate(set) var committed = false
    fileprivate var terminalAttempts = 0
    init(owner: UUID, id: String, bytes: Data, didCommit: @escaping () -> Void = {}) {
        self.owner = owner; self.id = id; self.bytes = bytes; self.didCommit = didCommit
    }
}

 
 
 
final class StartupLogChannel: @unchecked Sendable {
    let url: URL
    let queue: DispatchQueue
    fileprivate let control = NSLock()
    fileprivate let writer: MemorySampleLog.UnitWriter
    fileprivate weak var current: StartupLogDriver?
    private var scheduled: (StartupLogDriver, Bool, StartupLogDriver.PhaseStep?)?
    private var pumpQueued = false

    init(url: URL, io: any MemoryLogFileIO = MemoryLogSystemIO(),
         queue: DispatchQueue = DispatchQueue(label: "network.hako.startup-log", qos: .utility)) {
        self.url = url.standardizedFileURL; self.queue = queue
        writer = MemorySampleLog.UnitWriter(url: self.url, io: io)
    }
    func begin(owner: UUID = UUID(), limits: StartupLogDriverLimits = .init()) -> StartupLogDriver {
        limits.validate()
        control.lock(); defer { control.unlock() }
         
        current?.state = .retired
        let driver = StartupLogDriver(channel: self, owner: owner, limits: limits)
        current = driver
        writer.activate(owner)
        return driver
    }
    func retireCurrent() {
        locked {
            guard let driver = current else { return }
            driver.state = .retired
            writer.revoke(driver.owner)
        }
    }
    fileprivate func locked<T>(_ body: () -> T) -> T {
        control.lock(); defer { control.unlock() }; return body()
    }
    fileprivate func schedule(_ driver: StartupLogDriver, terminal: Bool, phaseStep: StartupLogDriver.PhaseStep?) {
        let enqueue: Bool = locked {
            guard current === driver, driver.state == (terminal ? .finishing : .active) else { return false }
            scheduled = (driver, terminal, phaseStep)
            guard !pumpQueued else { return false }
            pumpQueued = true; return true
        }
        if enqueue {
            queue.async { [self] in
                let work = locked { () -> (StartupLogDriver, Bool, StartupLogDriver.PhaseStep?)? in
                    let next = scheduled; scheduled = nil; pumpQueued = false; return next
                }
                guard let (driver, terminal, step) = work else { return }
                _ = driver.drive(terminal: terminal, phaseStep: step)
                 
            }
        }
    }
}

enum StartupLogReadFailure: Error, Equatable { case inactive, budget, source, oversized, alreadyCaptured }
enum StartupLogDriveResult: Equatable { case idle, yielded, budget, inactive, terminalComplete, terminalIncomplete }
struct StartupLogTerminalWindow: Equatable {
    let owner: UUID
    let epoch: String
    let throughCursor: String
    let throughSequence: Int64
}
struct StartupLogPhaseCompletion {
    let window: StartupLogTerminalWindow
    let confirmedCursor: String
    let confirmedSequence: Int64
}
enum StartupLogPhaseStepResult {
    case unit(StartupLogUnit)
    case progress, idle, awaitingUnit
    case sourceBlocked, budgetYield
     
    case windowComplete(StartupLogPhaseCompletion)
}

struct StartupLogDriverSnapshot {
    let state: String
    let boundaryCommitted: Bool
    let pendingID: String?
    let pendingIntent: String?
    let localPendingIDs: [String]
    let phasePendingID: String?
    let admittedLocalUnits: Int
    let admittedLocalBytes: Int
    let rejected: Int
    let committedUnits: Int
    let sourceCalls: Int
    let sourceBytes: Int
    let sinkAttempts: Int
    let sinkBytes: Int
    let recoveryAllowance: Int
    let terminalThrough: String?
    let phaseWindowConfirmed: Bool
    let incomplete: Bool
}

 
 
final class StartupLogSourceAccess {
    fileprivate let driver: StartupLogDriver
    fileprivate let terminal: Bool
    fileprivate var remaining: StartupLogWorkBudget
    fileprivate var valid = true
    fileprivate init(_ driver: StartupLogDriver, terminal: Bool, budget: StartupLogWorkBudget) {
        self.driver = driver; self.terminal = terminal; remaining = budget
    }
    func read(_ body: () throws -> Data) -> Result<Data, StartupLogReadFailure> {
        dispatchPrecondition(condition: .onQueue(driver.channel.queue))
        return driver.read(terminal: terminal, turn: self, capture: false, body)
    }
}

 
 
final class StartupLogDriver: @unchecked Sendable {
    typealias PhaseStep = (StartupLogSourceAccess) -> StartupLogPhaseStepResult
    fileprivate enum State: String { case active, finishing, finished, retired }
    let owner: UUID
    fileprivate let channel: StartupLogChannel
    let limits: StartupLogDriverLimits
     
    fileprivate var state = State.active
    private var local: [StartupLogUnit] = []
    private var accepted: [StartupLogLocalKind: Int] = [:]
    private var admittedLocalUnits = 0
    private var admittedLocalBytes = 0
    private var rejected = 0
    private var incomplete = false
    private var normalRemaining: StartupLogWorkBudget
    private var terminalRemaining: StartupLogWorkBudget
    private var initialCaptured = false
    private var terminalCaptured = false
    private var terminalCaptureSucceeded = false
    private var terminalWindow: StartupLogTerminalWindow?
    private var terminalDriven = false
    private var sourceCalls = 0
    private var sourceBytes = 0
    private var sinkAttempts = 0
    private var sinkBytes = 0
     
    private let boundary: StartupLogUnit
    private var phase: StartupLogUnit?
    private var fence: StartupLogUnit?
    private var preferPhase = false
    private var committedUnits = 0
    private var phaseWindowConfirmed = false

    fileprivate init(channel: StartupLogChannel, owner: UUID, limits: StartupLogDriverLimits) {
        self.channel = channel; self.owner = owner; self.limits = limits
        normalRemaining = limits.lifetime.subtracting(limits.terminal)
        terminalRemaining = limits.terminal
        boundary = StartupLogUnit(owner: owner, id: "launch/boundary", bytes: Data("--- launch ---\n".utf8))
    }
    private func admits(_ terminal: Bool) -> Bool {
        channel.current === self && state == (terminal ? .finishing : .active)
    }
    private func reject() { rejected = min(rejected, Int.max - 1) + 1; incomplete = true }

    func markIncomplete() { channel.locked { incomplete = true } }

     
     
     
    @discardableResult
    func offerLocal(_ kind: StartupLogLocalKind, bytes: Data) -> String? {
        channel.locked {
            guard admits(kind.terminal) else { return nil }
            let count = accepted[kind, default: 0]
            let cap: Int
            switch kind {
            case .periodic: cap = limits.periodicUnits
            case .note: cap = limits.noteUnits
            case .checkpoint: cap = limits.checkpointUnits
            default: cap = 1
            }
            let slotCap = limits.localUnits - (kind.terminal ? 0 : 3)
            guard count < cap, !bytes.isEmpty, bytes.count <= limits.maxUnitBytes,
                  admittedLocalUnits < slotCap,
                  bytes.count <= limits.localBytes - admittedLocalBytes else { reject(); return nil }
            let id = kind.id(count + 1)
            accepted[kind] = count + 1; admittedLocalUnits += 1; admittedLocalBytes += bytes.count
            local.append(StartupLogUnit(owner: owner, id: id, bytes: bytes))
            return id
        }
    }
     
     
     
    @discardableResult
    func offerPhase(_ unit: StartupLogUnit) -> Bool {
        dispatchPrecondition(condition: .onQueue(channel.queue))
        guard channel.locked({ channel.current === self && (state == .active || state == .finishing) }) else { return false }
        if let phase { return phase === unit }
        guard unit.owner == owner, !unit.committed, !unit.bytes.isEmpty,
              unit.bytes.count <= limits.maxUnitBytes, unit.id.utf8.count <= 256,
              unit.id.hasPrefix("record/") || unit.id.hasPrefix("diagnostic/") else {
            channel.locked { reject() }; return false
        }
        phase = unit; return true
    }
    @discardableResult
    func beginFinish() -> Bool {
        channel.locked {
            guard admits(false) else { return false }
            state = .finishing; return true
        }
    }
    func requestNormalDrive(phaseStep: PhaseStep? = nil) {
        channel.schedule(self, terminal: false, phaseStep: phaseStep)
    }
     
     
    func requestTerminalDrive(phaseStep: PhaseStep? = nil) {
        channel.schedule(self, terminal: true, phaseStep: phaseStep)
    }
    func captureInitial(_ body: () throws -> Data) -> Result<Data, StartupLogReadFailure> {
        read(terminal: false, turn: nil, capture: true, body)
    }
    func captureTerminal(_ body: () throws -> Data) -> Result<Data, StartupLogReadFailure> {
        read(terminal: true, turn: nil, capture: true, body)
    }
     
     
    @discardableResult
    func adoptTerminalWindow(_ window: StartupLogTerminalWindow) -> Bool {
        channel.locked {
            guard admits(true), terminalCaptureSucceeded, terminalWindow == nil,
                  window.owner == owner, !window.epoch.isEmpty, !window.throughCursor.isEmpty,
                  window.throughSequence >= 0,
                  window.epoch.utf8.count <= limits.pageBytes,
                  window.throughCursor.utf8.count <= limits.pageBytes - window.epoch.utf8.count else {
                incomplete = true; return false
            }
            terminalWindow = window; return true
        }
    }
    fileprivate func read(terminal: Bool, turn: StartupLogSourceAccess?, capture: Bool,
                          _ body: () throws -> Data) -> Result<Data, StartupLogReadFailure> {
        let denial: StartupLogReadFailure? = channel.locked {
            guard admits(terminal), turn?.valid != false else { return .inactive }
            if capture {
                if terminal ? terminalCaptured : initialCaptured { return .alreadyCaptured }
                if terminal { terminalCaptured = true } else { initialCaptured = true }
            }
            var pool = terminal ? terminalRemaining : normalRemaining
            var allocation = turn?.remaining ?? pool
            guard pool.takeSource(limits.pageBytes), allocation.takeSource(limits.pageBytes) else {
                incomplete = true; return .budget
            }
            if terminal { terminalRemaining = pool } else { normalRemaining = pool }
            turn?.remaining = allocation
            sourceCalls += 1; sourceBytes += limits.pageBytes
            return nil
        }
        if let denial { return .failure(denial) }
         
        let response = Result { try body() }
        return channel.locked {
            guard admits(terminal) else { incomplete = true; return .failure(.inactive) }
            switch response {
            case let .success(bytes):
                guard bytes.count <= limits.pageBytes else { incomplete = true; return .failure(.oversized) }
                if capture && terminal { terminalCaptureSucceeded = true }
                return .success(bytes)
            case .failure: incomplete = true; return .failure(.source)
            }
        }
    }

    @discardableResult
    func driveNormal(phaseStep: PhaseStep? = nil) -> StartupLogDriveResult {
        drive(terminal: false, phaseStep: phaseStep)
    }
    @discardableResult
    func driveTerminal(phaseStep: PhaseStep? = nil) -> StartupLogDriveResult {
        drive(terminal: true, phaseStep: phaseStep)
    }
    fileprivate func drive(terminal: Bool, phaseStep: PhaseStep?) -> StartupLogDriveResult {
        dispatchPrecondition(condition: .onQueue(channel.queue))
        let allowed = channel.locked { () -> Bool in
            guard admits(terminal), !terminal || !terminalDriven else { return false }
            if terminal { terminalDriven = true }; return true
        }
        guard allowed else { return .inactive }
        let access = StartupLogSourceAccess(self, terminal: terminal, budget: terminal ? limits.terminal : limits.normal)
        defer { channel.locked { access.valid = false } }
        var phaseIdle = false
         
         
        var phaseSteps = access.remaining.sourceCalls + access.remaining.sinkAttempts
        while channel.locked({ admits(terminal) }) {
            let unit: StartupLogUnit
            if !boundary.committed { unit = boundary }
            else if let fence { unit = fence }
            else {
                let head = channel.locked { local.first }
                if phase == nil, !phaseIdle, let phaseStep, preferPhase || head == nil {
                    guard phaseSteps > 0 else {
                        if terminal { channel.locked { incomplete = true }; return endTerminal() }
                        return .budget
                    }
                    phaseSteps -= 1
                    let result = phaseStep(access)
                     
                     
                    guard channel.locked({ admits(terminal) }) else { break }
                    switch result {
                    case let .unit(next): if !offerPhase(next) { phaseIdle = true }
                    case .progress:
                        if head == nil { continue }
                    case .idle:
                        if terminal { channel.locked { incomplete = true } }
                        phaseIdle = true
                    case .sourceBlocked, .awaitingUnit:
                        channel.locked { incomplete = true }; phaseIdle = true
                    case .budgetYield:
                        if terminal { channel.locked { incomplete = true } }
                        phaseIdle = true
                    case let .windowComplete(proof):
                        let matches = channel.locked {
                            terminal && terminalWindow == proof.window && proof.window.owner == owner &&
                            proof.confirmedCursor == proof.window.throughCursor &&
                            proof.confirmedSequence == proof.window.throughSequence
                        }
                        if matches { phaseWindowConfirmed = true }
                        else { channel.locked { incomplete = true } }
                        phaseIdle = true
                    }
                }
                if let phase, preferPhase || head == nil { unit = phase }
                else if let head { unit = head }
                else if let phase { unit = phase }
                else { return terminal ? endTerminal() : .idle }
            }
            let charged = channel.locked { () -> Bool in
                guard admits(terminal) else { return false }
                if terminal, unit.terminalAttempts >= limits.terminalAttemptsPerUnit { incomplete = true; return false }
                var pool = terminal ? terminalRemaining : normalRemaining
                var allocation = access.remaining
                guard pool.takeSink(unit.bytes.count), allocation.takeSink(unit.bytes.count) else { return false }
                if terminal { terminalRemaining = pool; unit.terminalAttempts += 1 } else { normalRemaining = pool }
                access.remaining = allocation
                sinkAttempts += 1; sinkBytes += unit.bytes.count
                return true
            }
            guard charged else {
                if terminal { channel.locked { incomplete = true }; return endTerminal() }
                return channel.locked({ admits(false) }) ? .budget : .inactive
            }
            fence = unit
            let outcome = channel.writer.submit(.init(owner: owner, unitID: unit.id, bytes: unit.bytes,
                intent: unit.intent, isBoundary: unit === boundary, maxFileBytes: limits.maxFileBytes,
                maxRecoveryBytes: limits.recoveryBytesPerAttempt))
            switch outcome {
            case .committed:
                unit.committed = true; committedUnits += 1; fence = nil
                if phase === unit { phase = nil; preferPhase = false }
                else if unit !== boundary {
                    channel.locked { precondition(local.first === unit); local.removeFirst() }
                    preferPhase = true
                }
                 
                unit.didCommit()
            case .retryableClean: unit.intent = .append
            case .uncertain: unit.intent = .reconcile
            }
            if outcome != .committed, !terminal { return .yielded }
        }
        return .inactive
    }
    private func endTerminal() -> StartupLogDriveResult {
        channel.locked {
            guard admits(true) else { return .inactive }
            incomplete = incomplete || !boundary.committed || fence != nil || phase != nil || !local.isEmpty || !phaseWindowConfirmed
            state = .finished
            channel.writer.revoke(owner)
            return incomplete ? .terminalIncomplete : .terminalComplete
        }
    }
    func snapshot() -> StartupLogDriverSnapshot {
        dispatchPrecondition(condition: .onQueue(channel.queue))
        return channel.locked {
            .init(state: state.rawValue, boundaryCommitted: boundary.committed, pendingID: fence?.id,
                  pendingIntent: fence.map { $0.intent == .append ? "append" : "reconcile" },
                  localPendingIDs: local.map(\.id), phasePendingID: phase?.id,
                  admittedLocalUnits: admittedLocalUnits, admittedLocalBytes: admittedLocalBytes,
                  rejected: rejected, committedUnits: committedUnits, sourceCalls: sourceCalls,
                  sourceBytes: sourceBytes, sinkAttempts: sinkAttempts, sinkBytes: sinkBytes,
                  recoveryAllowance: sinkAttempts * limits.recoveryBytesPerAttempt,
                  terminalThrough: terminalWindow?.throughCursor, phaseWindowConfirmed: phaseWindowConfirmed,
                   
                  incomplete: incomplete || (state == .retired && (!boundary.committed || fence != nil || phase != nil || !local.isEmpty || !phaseWindowConfirmed)))
        }
    }
}
