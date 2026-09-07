import Foundation

struct ConnectionSamplingGate {
    private(set) var lastSequence: UInt64 = 0
    private var nextDeadline: UInt64 = 0
    let interval: UInt64 = 1_000_000_000

    mutating func accept(sequence: UInt64, observedAt: UInt64, now: UInt64, immediate: Bool = false) -> Bool {
        guard sequence > lastSequence, observedAt <= now, now - observedAt <= interval,
              immediate || now >= nextDeadline else { return false }
        lastSequence = sequence
        nextDeadline = now.addingReportingOverflow(interval).overflow ? .max : now + interval
        return true
    }

    mutating func resume() { nextDeadline = 0; lastSequence = 0 }
}

struct ConnectionObservation<Value> {
    let value: Value
    let sequence: UInt64
    let observedAt: UInt64
    let observedDate: Date
    let transportGeneration: UInt64
    let runtimeIdentity: String?
    func age(at now: UInt64) -> UInt64 { now >= observedAt ? now - observedAt : .max }
}

enum ConnectionTransportEvent {
    case connected
    case disconnected(String)
    case snapshot(String)
}

protocol ConnectionSourceTransport: AnyObject {
    func connect() throws
    func close()
    func snapshot() throws -> String
    func closeConnection(_ id: String) throws
    func closeConnections() throws
}

 
 
final class ConnectionTransportBox: @unchecked Sendable {
    let value: ConnectionSourceTransport
    init(_ value: ConnectionSourceTransport) { self.value = value }
}

private struct ConnectionReceipt {
    let sequence: UInt64
    let uptime: UInt64
    let date: Date
}

private final class ConnectionReceiptClock: @unchecked Sendable {
    private let lock = NSLock()
    private var sequence: UInt64 = 0
    let now: () -> UInt64
    init(now: @escaping () -> UInt64) { self.now = now }
    func receipt() -> ConnectionReceipt {
        lock.lock(); defer { lock.unlock() }
        sequence &+= 1
        return ConnectionReceipt(sequence: sequence, uptime: now(), date: Date())
    }
    func current() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        return sequence
    }
}

 
 
private final class ConnectionMailbox<Value>: @unchecked Sendable {
    struct Item {
        let event: ConnectionTransportEvent
        let receipt: ConnectionReceipt
        let bytes: Int
    }
    enum Decoded {
        case connected
        case disconnected(String)
        case snapshot(Value, ConnectionReceipt)
        case gap(Int, String)
    }
    private let lock = NSLock()
    private var queue: [Item] = []
    private var byteCount = 0
    private var control: Item?
    private var dropped = 0
    private var closed = false
    private var worker: Task<Void, Never>?
    private let clock: ConnectionReceiptClock
    private let parse: (String) -> Value?
    private let consume: @MainActor (Decoded) -> Void
    private let maxFrames: Int
    private let maxBytes: Int
    private var lastText: String?
    private var lastValue: Value?

    init(clock: ConnectionReceiptClock, maxFrames: Int, maxBytes: Int,
         parse: @escaping (String) -> Value?, consume: @escaping @MainActor (Decoded) -> Void) {
        self.clock = clock; self.maxFrames = maxFrames; self.maxBytes = maxBytes
        self.parse = parse; self.consume = consume
    }

    func enqueue(_ event: ConnectionTransportEvent) {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return }
        let receipt = clock.receipt()
        let bytes: Int
        if case let .snapshot(text) = event { bytes = text.utf8.count } else { bytes = 0 }
        if case .snapshot = event {
            if bytes > maxBytes {
                dropped += 1
            } else {
            while queue.count >= maxFrames || byteCount + bytes > maxBytes {
                let removed = queue.removeFirst()
                byteCount -= removed.bytes
                dropped += 1
            }
            queue.append(Item(event: event, receipt: receipt, bytes: bytes))
                byteCount += bytes
            }
        } else {
             
            control = Item(event: event, receipt: receipt, bytes: 0)
        }
        if worker == nil {
            worker = Task.detached { [self] in await drain() }
        }
    }

    private func next() -> (Item?, Int)? {
        lock.lock(); defer { lock.unlock() }
        if closed { queue.removeAll(); byteCount = 0; dropped = 0; control = nil; lastText = nil; lastValue = nil }
        if let item = control { control = nil; return (item, 0) }
        if dropped > 0 {
            let count = dropped; dropped = 0
            return (nil, count)
        }
        guard !queue.isEmpty else { worker = nil; return nil }
        let item = queue.removeFirst(); byteCount -= item.bytes
        return (item, 0)
    }

    private func drain() async {
        while let (item, gaps) = next() {
            if gaps > 0 { await consume(.gap(gaps, "Connection decoder queue overflow")); continue }
            guard let item else { continue }
            switch item.event {
            case .connected: await consume(.connected)
            case let .disconnected(message): await consume(.disconnected(message))
            case let .snapshot(text):
                let value: Value?
                if text == lastText {
                    value = lastValue
                } else {
                    value = parse(text)
                    lastText = text
                    lastValue = value
                }
                if let value { await consume(.snapshot(value, item.receipt)) }
                else { await consume(.gap(1, "Invalid connections snapshot")) }
            }
        }
    }

    func finish() -> Task<Void, Never>? {
        lock.lock(); defer { lock.unlock() }
        closed = true; queue.removeAll(); byteCount = 0; dropped = 0; control = nil
        if worker == nil { lastText = nil; lastValue = nil }
        return worker
    }
}

@MainActor
final class ConnectionSourceLease {
    private var releaseBody: (() -> Void)?
    init(_ release: @escaping () -> Void) { releaseBody = release }
    func release() { releaseBody?(); releaseBody = nil }
    deinit {
        if let body = releaseBody { Task { @MainActor in body() } }
    }
}

 
 
@MainActor
final class ConnectionObservationSource<Value> {
    typealias Factory = (@escaping (ConnectionTransportEvent) -> Void) throws -> ConnectionSourceTransport
    enum Event {
        case frame(ConnectionObservation<Value>)
        case state(connected: Bool, error: String)
        case gap(count: Int, reason: String)
        case runtimeChanged
    }
    private struct Subscriber {
        let id: UUID
        let diagnostic: Bool
        let receive: (Event) -> Void
        var gate = ConnectionSamplingGate()
    }
    private struct Attempt {
        let generation: UInt64
        let client: ConnectionTransportBox
        let mailbox: ConnectionMailbox<Value>
        let connect: Task<Void, Never>
    }

    private let factory: Factory
    private let parse: (String) -> Value?
    private let clock: ConnectionReceiptClock
    private let schedulesTicks: Bool
    private let requiresRuntimeIdentification: Bool
    enum RuntimeConfirmationState { case noOwner, unconfirmedOwner, confirmedOwner }
    private var confirmingOwnerID: UUID?
    private var confirmedOwnerID: UUID?
    private var unconfirmedFrames = 0
    private var diagnosticOwnerID: UUID? { subscribers.first(where: \.diagnostic)?.id }
    var runtimeConfirmationState: RuntimeConfirmationState {
        guard let owner = diagnosticOwnerID else { return .noOwner }
        return confirmedOwnerID == owner ? .confirmedOwner : .unconfirmedOwner
    }
    private var canPublishHistory: Bool {
        !requiresRuntimeIdentification || runtimeConfirmationState == .confirmedOwner
    }
    private let maxFrames: Int
    private let maxBytes: Int
    private var subscribers: [Subscriber] = []
    private var attempt: Attempt?
    private var cleanup: Task<Void, Never>?
    private var pendingStart: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var mutation: UInt64 = 0
    private var pendingMutations = 0
    private var refreshRequest: UInt64 = 0
    private var historyFloor: UInt64 = 0
    private var identityFloor: UInt64 = 0
    private var lastDecodedSequence: UInt64 = 0
    private var closingIDs: Set<String> = []
    private var closingAll = false
    private(set) var latest: ConnectionObservation<Value>?
    private(set) var runtimeIdentity: String?
    private(set) var connected = false
    private(set) var gapCount = 0
    var consumerCount: Int { subscribers.count }
    var hasHistoryTimer: Bool { timer != nil }

    init(now: @escaping () -> UInt64 = { DispatchTime.now().uptimeNanoseconds },
         schedulesTicks: Bool = true, requiresRuntimeIdentification: Bool = false, maxFrames: Int = 8, maxBytes: Int = 4 * 1_024 * 1_024,
         parse: @escaping (String) -> Value?, factory: @escaping Factory) {
        clock = ConnectionReceiptClock(now: now)
        self.schedulesTicks = schedulesTicks
        self.requiresRuntimeIdentification = requiresRuntimeIdentification
        self.maxFrames = max(1, maxFrames); self.maxBytes = max(1, maxBytes)
        self.parse = parse; self.factory = factory
    }

    func acquire(diagnostic: Bool = false, receive: @escaping (Event) -> Void) -> ConnectionSourceLease {
        let id = UUID()
        subscribers.append(Subscriber(id: id, diagnostic: diagnostic, receive: receive))
        receive(.state(connected: connected, error: ""))
        if let latest, !diagnostic { publishHistory(latest, only: id, immediate: true) }
        startIfNeeded()
        return ConnectionSourceLease { [self] in release(id) }
    }

    private func release(_ id: UUID) {
        let previousOwner = diagnosticOwnerID
        subscribers.removeAll { $0.id == id }
        if previousOwner != diagnosticOwnerID { revokeRuntimeConfirmation() }
        if subscribers.isEmpty { stopAttempt() }
        else if !subscribers.contains(where: { !$0.diagnostic }) { timer?.cancel(); timer = nil }
    }

    func identifyRuntime(_ identity: String) {
        guard !identity.isEmpty else { return }
         
         
        if requiresRuntimeIdentification {
            guard let owner = confirmingOwnerID, owner == diagnosticOwnerID else { return }
            confirmedOwnerID = owner
        }
        if unconfirmedFrames > 1 {
            broadcast(.gap(count: unconfirmedFrames - 1, reason: "Runtime identity was not yet confirmed"))
        }
        unconfirmedFrames = 0
        guard identity != runtimeIdentity else { return }
        let replacingKnownRuntime = runtimeIdentity != nil
        runtimeIdentity = identity
        identityFloor = clock.current()
        invalidateHistory()
        if replacingKnownRuntime { broadcast(.runtimeChanged) }
    }

    func reportDiagnosticGap(reason: String, invalidateLatest: Bool = true) {
        gapCount += 1
        if invalidateLatest { invalidateHistory() }
        broadcast(.gap(count: 1, reason: reason))
    }

     
    func tick() {
        if let latest { publishHistory(latest) }
    }

    private func isHistoryEligible(_ frame: ConnectionObservation<Value>) -> Bool {
        pendingMutations == 0 && canPublishHistory &&
        frame.transportGeneration == generation && frame.runtimeIdentity == runtimeIdentity &&
        frame.sequence > historyFloor
    }

    private func publishHistory(_ frame: ConnectionObservation<Value>, only id: UUID? = nil, immediate: Bool = false) {
        guard isHistoryEligible(frame) else { return }
        let ids = subscribers.filter { !$0.diagnostic && (id == nil || $0.id == id) }.map(\.id)
        for subscriberID in ids {
             
             
            guard isHistoryEligible(frame) else { return }
            guard let index = subscribers.firstIndex(where: { $0.id == subscriberID }) else { continue }
            if subscribers[index].gate.accept(sequence: frame.sequence, observedAt: frame.observedAt,
                                               now: clock.now(), immediate: immediate) {
                let receive = subscribers[index].receive
                receive(.frame(frame))
                guard isHistoryEligible(frame) else { return }
            }
        }
        ensureHistoryTimer()
    }

    private func ensureHistoryTimer() {
        guard schedulesTicks, timer == nil, attempt != nil,
              let latest, isHistoryEligible(latest),
              subscribers.contains(where: { !$0.diagnostic }) else { return }
         
         
        timer = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
                self?.tick()
            }
        }
    }

    private func broadcast(_ event: Event) {
         
        var diagnosticReceivedGap = false
        let callbacks = subscribers.filter { subscriber in
            if case .gap = event, subscriber.diagnostic {
                defer { diagnosticReceivedGap = true }
                return !diagnosticReceivedGap
            }
            return true
        }.map(\.receive)
        for receive in callbacks { receive(event) }
    }

    private func startIfNeeded() {
        guard attempt == nil, pendingStart == nil, !subscribers.isEmpty else { return }
        if let cleanup {
            let token = generation
            pendingStart = Task { [weak self] in
                await cleanup.value
                guard !Task.isCancelled, let self, token == self.generation else { return }
                self.cleanup = nil; self.pendingStart = nil
                self.startIfNeeded()
            }
            return
        }
        generation &+= 1
        let token = generation
        let mailbox = ConnectionMailbox<Value>(clock: clock, maxFrames: maxFrames, maxBytes: maxBytes, parse: parse) {
            [weak self] event in self?.consume(event, generation: token)
        }
        do {
            let box = ConnectionTransportBox(try factory { mailbox.enqueue($0) })
            let connect = Task.detached { [weak self] in
                do { try box.value.connect() }
                catch { await self?.connectionFailed(error.localizedDescription, generation: token) }
            }
            attempt = Attempt(generation: token, client: box, mailbox: mailbox, connect: connect)
        } catch {
            broadcast(.state(connected: false, error: error.localizedDescription))
        }
    }

    private func consume(_ event: ConnectionMailbox<Value>.Decoded, generation token: UInt64) {
        guard token == generation, attempt != nil else { return }
        switch event {
        case .connected:
            connected = true
            broadcast(.state(connected: true, error: ""))
        case let .disconnected(message):
            connectionFailed(message, generation: token)
        case let .gap(count, reason):
            gapCount += count
            invalidateHistory()
            broadcast(.gap(count: count, reason: reason))
        case let .snapshot(value, receipt):
            guard receipt.sequence > lastDecodedSequence else { return }
            lastDecodedSequence = receipt.sequence
            guard receipt.sequence > identityFloor else {
                reportDiagnosticGap(reason: "Queued frame predates runtime confirmation", invalidateLatest: false)
                return
            }
            if !connected {
                connected = true
                broadcast(.state(connected: true, error: ""))
            }
            let frame = ConnectionObservation(value: value, sequence: receipt.sequence,
                observedAt: receipt.uptime, observedDate: receipt.date,
                transportGeneration: token, runtimeIdentity: runtimeIdentity)
             
             
            confirmedOwnerID = nil
            let owner = subscribers.first(where: \.diagnostic)
            confirmingOwnerID = owner?.id
            owner?.receive(.frame(frame))
            confirmingOwnerID = nil
            guard token == generation else { return }
            if !canPublishHistory {
                gapCount += 1
                unconfirmedFrames += 1
                if unconfirmedFrames == 1 {
                    revokeRuntimeConfirmation()
                    broadcast(.gap(count: 1, reason: "Awaiting verified runtime identity; observations incomplete"))
                }
                return
            }
            guard receipt.sequence > historyFloor, pendingMutations == 0,
                  latest == nil || receipt.sequence > latest!.sequence else { return }
            latest = frame
             
            for id in subscribers.filter({ !$0.diagnostic && $0.gate.lastSequence == 0 }).map(\.id) {
                publishHistory(frame, only: id, immediate: true)
            }
        }
    }

    private func revokeRuntimeConfirmation() {
        confirmingOwnerID = nil
        confirmedOwnerID = nil
        guard requiresRuntimeIdentification else { return }
        invalidateHistory()
        timer?.cancel(); timer = nil
        for index in subscribers.indices { subscribers[index].gate.resume() }
    }

    private func invalidateHistory() {
        latest = nil
        historyFloor = clock.current()
        refreshRequest &+= 1
    }

    private func connectionFailed(_ message: String, generation token: UInt64) {
        guard token == generation else { return }
        stopAttempt()
        broadcast(.state(connected: false, error: message))
        let barrier = cleanup
        let restartGeneration = generation
        pendingStart = Task { [weak self] in
            await barrier?.value
            do { try await Task.sleep(nanoseconds: 1_000_000_000) } catch { return }
            guard !Task.isCancelled, let self, restartGeneration == self.generation else { return }
            self.cleanup = nil; self.pendingStart = nil
            self.startIfNeeded()
        }
    }

    private func stopAttempt() {
        generation &+= 1
        timer?.cancel(); timer = nil
        pendingStart?.cancel(); pendingStart = nil
        connected = false
        revokeRuntimeConfirmation()
        unconfirmedFrames = 0
        invalidateHistory()
        for index in subscribers.indices { subscribers[index].gate.resume() }
        guard let old = attempt else { return }
        attempt = nil
        let drain = old.mailbox.finish()
        let previous = cleanup
        cleanup = Task.detached {
            await previous?.value
            old.client.value.close()
            await old.connect.value
            old.client.value.close()
            await drain?.value
        }
    }

    func waitForStop() async { await cleanup?.value }

    func refresh() async throws {
        guard let attempt, pendingMutations == 0, canPublishHistory else { return }
        refreshRequest &+= 1
        let request = refreshRequest
        let version = mutation
        let receiptBefore = clock.current()
        let box = attempt.client
        let token = generation
        let parse = self.parse
        let value = try await Task.detached { () throws -> Value in
            let raw = try box.value.snapshot()
            guard let value = parse(raw) else {
                throw NSError(domain: "Hako.Connections", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid connections snapshot"])
            }
            return value
        }.value
        guard token == generation, request == refreshRequest, version == mutation,
              pendingMutations == 0, canPublishHistory else { return }
         
        guard receiptBefore == clock.current() else {
            if let latest { publishHistory(latest, immediate: true) }
            return
        }
        let receipt = clock.receipt()
        let frame = ConnectionObservation(value: value, sequence: receipt.sequence, observedAt: receipt.uptime,
            observedDate: receipt.date, transportGeneration: token, runtimeIdentity: runtimeIdentity)
        latest = frame
        publishHistory(frame, immediate: true)
    }

    func close(_ id: String?) async throws {
        guard let attempt, !closingAll else { return }
        if let id {
            guard closingIDs.insert(id).inserted else { return }
        } else {
            guard closingIDs.isEmpty else { return }
            closingAll = true
        }
        mutation &+= 1; pendingMutations += 1; invalidateHistory()
        let token = generation
        defer {
            pendingMutations -= 1
            if let id { closingIDs.remove(id) } else { closingAll = false }
            if token == generation { invalidateHistory() }
        }
        let box = attempt.client
        try await Task.detached {
            if let id { try box.value.closeConnection(id) } else { try box.value.closeConnections() }
        }.value
        guard token == generation else { return }
    }
}
