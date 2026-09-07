import Foundation

struct StartupPhaseReadRequest: Sendable {
    let cursor: String
    let throughCursor: String
    let maxBytes: Int
}

 
 
struct StartupPhasePage: Decodable, Sendable {
    struct Record: Decodable, Sendable { let sequence: Int64; let line: String }
    struct Diagnostic: Decodable, Sendable, Equatable {
        let revision: Int64
        let path: String
        let error: String
        let recordSequence: Int64
    }
    let schemaVersion: Int
    let status: String
    let epoch: String
    let from: Int64
    let next: Int64
    let head: Int64
    let through: Int64
    let beginCursor: String
    let nextCursor: String
    let headCursor: String
    let throughCursor: String
    let records: [Record]
    let diagnosticRevision: Int64
    let diagnostic: Diagnostic?

    enum Invalid: Error { case envelope, capture, cursor, window, records, diagnostic }
    static func decode(_ data: Data, limit: Int) throws -> Self {
        guard data.count <= limit else { throw Invalid.envelope }
        let p = try JSONDecoder().decode(Self.self, from: data)
        guard p.schemaVersion == 1, p.status == "ok", !p.epoch.isEmpty,
              p.epoch.utf8.count <= 128,
              p.from >= 0, p.from <= p.next, p.next <= p.through, p.through <= p.head,
              p.records.count <= 256, p.diagnosticRevision >= 0,
              !p.beginCursor.isEmpty, !p.nextCursor.isEmpty, !p.headCursor.isEmpty, !p.throughCursor.isEmpty,
              p.next - p.from == Int64(p.records.count) else { throw Invalid.envelope }
        guard p.next != p.head || p.nextCursor == p.headCursor,
              p.next != p.through || p.nextCursor == p.throughCursor else { throw Invalid.cursor }
        for (i, record) in p.records.enumerated() {
            guard record.sequence == p.from + Int64(i) + 1 else { throw Invalid.records }
        }
        if let d = p.diagnostic {
            guard d.revision == p.diagnosticRevision, d.recordSequence >= 0 else { throw Invalid.diagnostic }
        }
        return p
    }
    static func capture(_ data: Data, limit: Int) throws -> Self {
        let p = try decode(data, limit: limit)
        guard p.from == p.head, p.next == p.head, p.through == p.head, p.records.isEmpty else {
            throw Invalid.capture
        }
        return p
    }
}

struct StartupPhasePagingSnapshot {
    let issue: String?
    let readCursor: String
    let confirmedCursor: String
    let confirmedSequence: Int64
    let observedDiagnosticRevision: Int64
    let confirmedDiagnosticRevision: Int64
    let pendingRecords: Int
    let throughCursor: String?
}

 
 
final class StartupPhasePager {
    typealias Reader = @Sendable (StartupPhaseReadRequest) throws -> Data
    private struct PendingPage {
        let page: StartupPhasePage
        let terminal: Bool
        var index = 0
        var diagnosticDone = false
    }
    private let owner: UUID
    private let pageBytes: Int
    private let maxUnitBytes: Int
    private let reader: Reader
    private let epoch: String
    private let baselineSequence: Int64
    private var readSequence: Int64
    private var readCursor: String
    private var confirmedCursor: String
    private var confirmedSequence: Int64
    private var observedDiagnosticRevision: Int64
    private var confirmedDiagnosticRevision: Int64 = 0
    private var pending: PendingPage?
    private var unit: StartupLogUnit?
    private var issue: String?
    private var terminalTarget: StartupLogTerminalWindow?
    private var terminalWindowRead = false
     
     
    private var terminalDiagnostic: StartupPhasePage.Diagnostic?
    private var terminalDiagnosticConfirmed = true

    init(owner: UUID, initial: StartupPhasePage, limits: StartupLogDriverLimits, reader: @escaping Reader) {
        self.owner = owner; self.reader = reader
        pageBytes = limits.pageBytes; maxUnitBytes = limits.maxUnitBytes
        epoch = initial.epoch; baselineSequence = initial.next
        readSequence = initial.next; confirmedSequence = initial.next
        readCursor = initial.nextCursor; confirmedCursor = initial.nextCursor
        observedDiagnosticRevision = initial.diagnosticRevision
    }

    @discardableResult
    func beginTerminal(_ capture: StartupPhasePage) -> StartupLogTerminalWindow? {
        guard terminalTarget == nil, capture.epoch == epoch, capture.head >= readSequence else {
            issue = "terminal-window-changed"; return nil
        }
        let target = StartupLogTerminalWindow(owner: owner, epoch: epoch,
            throughCursor: capture.headCursor, throughSequence: capture.head)
        terminalTarget = target
        observedDiagnosticRevision = max(observedDiagnosticRevision, capture.diagnosticRevision)
        if let diagnostic = capture.diagnostic,
           diagnostic.recordSequence > baselineSequence, diagnostic.recordSequence <= capture.head,
           diagnostic.revision > confirmedDiagnosticRevision {
            terminalDiagnostic = diagnostic
            terminalDiagnosticConfirmed = false
        }
        return target
    }

    var snapshot: StartupPhasePagingSnapshot {
        .init(issue: issue, readCursor: readCursor, confirmedCursor: confirmedCursor,
              confirmedSequence: confirmedSequence, observedDiagnosticRevision: observedDiagnosticRevision,
              confirmedDiagnosticRevision: confirmedDiagnosticRevision,
              pendingRecords: pending.map { $0.page.records.count - $0.index } ?? 0,
              throughCursor: terminalTarget?.throughCursor)
    }

    func step(_ access: StartupLogSourceAccess) -> StartupLogPhaseStepResult {
        guard issue == nil else { return .sourceBlocked }
        if let unit { return unit.committed ? fail("unreleased-ack") : .unit(unit) }
        if pending == nil {
            if let target = terminalTarget, terminalWindowRead, terminalDiagnosticConfirmed,
               confirmedSequence == target.throughSequence, confirmedCursor == target.throughCursor {
                return .windowComplete(.init(window: target, confirmedCursor: confirmedCursor,
                                              confirmedSequence: confirmedSequence))
            }
            let request = StartupPhaseReadRequest(cursor: readCursor,
                throughCursor: terminalTarget?.throughCursor ?? "", maxBytes: pageBytes)
            let bytes: Data
            switch access.read({ try reader(request) }) {
            case let .success(data): bytes = data
            case .failure(.budget): return .budgetYield
            case .failure(.inactive): return .sourceBlocked  
            case .failure: return fail("source-error")
            }
            do {
                let p = try StartupPhasePage.decode(bytes, limit: pageBytes)
                guard p.epoch == epoch, p.from == readSequence,
                      p.next != p.from || p.nextCursor == request.cursor,
                      p.next == p.from || p.nextCursor != request.cursor else { return fail("cursor-discontinuity") }
                if let target = terminalTarget {
                    guard p.throughCursor == target.throughCursor, p.through == target.throughSequence else {
                        return fail("terminal-window-changed")
                    }
                    terminalWindowRead = true
                }
                guard !p.records.isEmpty || p.from == p.through else { return fail("no-progress") }
                readCursor = p.nextCursor; readSequence = p.next
                observedDiagnosticRevision = max(observedDiagnosticRevision, p.diagnosticRevision)
                pending = PendingPage(page: p, terminal: terminalTarget != nil)
            } catch { return fail("invalid-page") }
        }
        guard let held = pending else { return .idle }
        if held.index < held.page.records.count {
            let record = held.page.records[held.index]
             
            guard record.line.utf8.count <= maxUnitBytes - 5 else { return fail("sink-unit-too-large") }
            let next = StartupLogUnit(owner: owner, id: "record/\(epoch)/\(record.sequence)",
                bytes: Data(("    " + record.line + "\n").utf8)) { [weak self] in
                    guard let self else { return }
                    self.confirmedSequence = record.sequence
                    self.pending?.index += 1
                    if let p = self.pending, p.index == p.page.records.count {
                        self.confirmedCursor = p.page.nextCursor
                    }
                    self.unit = nil
                }
            unit = next; return .unit(next)
        }
        if held.terminal {
             
             
            if !terminalDiagnosticConfirmed, let d = terminalDiagnostic,
               d.recordSequence <= confirmedSequence {
                return diagnosticUnit(d)
            }
        } else if !held.diagnosticDone, let d = held.page.diagnostic,
                  d.revision > confirmedDiagnosticRevision, d.recordSequence > baselineSequence,
                  d.recordSequence <= held.page.next,
                  d.recordSequence <= (terminalTarget?.throughSequence ?? held.page.through) {
             
             
            return diagnosticUnit(d)
        }
        pending = nil
         
         
        if terminalTarget != nil { return .progress }
        return .idle
    }

    private func diagnosticUnit(_ d: StartupPhasePage.Diagnostic) -> StartupLogPhaseStepResult {
        guard d.path.utf8.count <= maxUnitBytes, d.error.utf8.count <= maxUnitBytes - d.path.utf8.count,
              d.path.utf8.count + d.error.utf8.count <= maxUnitBytes - 128 else {
            return fail("sink-diagnostic-too-large")
        }
        let text = "    core-diag revision=\(d.revision) sequence=\(d.recordSequence) path=\(d.path) error=\(d.error)\n"
        let next = StartupLogUnit(owner: owner, id: "diagnostic/\(epoch)/\(d.revision)", bytes: Data(text.utf8)) { [weak self] in
            guard let self else { return }
            self.confirmedDiagnosticRevision = max(self.confirmedDiagnosticRevision, d.revision)
            if self.terminalDiagnostic == d { self.terminalDiagnosticConfirmed = true }
            self.pending?.diagnosticDone = true
            self.unit = nil
        }
        unit = next
        return .unit(next)
    }

    private func fail(_ reason: String) -> StartupLogPhaseStepResult {
        issue = reason; return .sourceBlocked
    }
}
