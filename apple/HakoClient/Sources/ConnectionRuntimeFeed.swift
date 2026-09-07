import Foundation
import Hako

enum ConnectionObservationPauseReason: String, Codable {
    case noForegroundScene = "no-foreground-ios-scene"
    case controlDisconnected = "control-disconnected"
}

@MainActor
final class ConnectionDiagnosticLease {
    private var finish: ((ConnectionObservationPauseReason) -> Void)?
    private let defaultReason: ConnectionObservationPauseReason
    init(defaultReason: ConnectionObservationPauseReason, finish: @escaping (ConnectionObservationPauseReason) -> Void) {
        self.defaultReason = defaultReason; self.finish = finish
    }
    func release(reason: ConnectionObservationPauseReason? = nil) {
        let action = finish; finish = nil; action?(reason ?? defaultReason)
    }
    deinit {
        let action = finish, reason = defaultReason
        Task { @MainActor in action?(reason) }
    }
}

struct ConnectionDiagnosticContext {
    let route: RuntimeRouteContext
    let confirmedAt: UInt64
}

 
 
@MainActor
final class ConnectionRuntimeFeed {
    static let shared = ConnectionRuntimeFeed(source: makeSource(requiresRuntimeIdentification: true))
    let source: ConnectionObservationSource<[HakoConnection]>
    let routeProjector: RuntimeRouteEvidenceProjector
    let routeJournal: RuntimeRouteEvidenceJournal
    let runtimeIdentityCache: RuntimeIdentityCache

    private struct DiagnosticSink {
        let id: UUID
        let sceneManaged: Bool
        let context: () -> ConnectionDiagnosticContext?
        let receive: ([String]) -> Void
    }
    private var sinks: [DiagnosticSink] = []
    private var diagnosticLease: ConnectionSourceLease?
    private var acceptedContext: ConnectionDiagnosticContext?
    private struct ObservationPause {
        let id: String
        let start: Date
        let reason: ConnectionObservationPauseReason
    }
    private var observationPause: ObservationPause?
    private var journalTask: Task<Void, Never>?
    private let now: () -> Date

    init(source: ConnectionObservationSource<[HakoConnection]>,
         projector: RuntimeRouteEvidenceProjector = RuntimeRouteEvidenceProjector(),
         journal: RuntimeRouteEvidenceJournal = RuntimeRouteEvidenceJournal(fileURL: RuntimeRouteEvidenceJournal.defaultFileURL()),
         runtimeIdentityCache: RuntimeIdentityCache? = nil, now: @escaping () -> Date = Date.init) {
        self.source = source
        self.now = now
        routeProjector = projector
        routeJournal = journal
        self.runtimeIdentityCache = runtimeIdentityCache ?? RuntimeIdentityCache(ttl: 5) { NodesRuntimeIdentity.load() }
    }

    func acquireDiagnostics(sceneManaged: Bool = false, context: @escaping () -> ConnectionDiagnosticContext?,
                            receive: @escaping ([String]) -> Void) -> ConnectionDiagnosticLease {
        let id = UUID()
        sinks.append(DiagnosticSink(id: id, sceneManaged: sceneManaged, context: context, receive: receive))
        if diagnosticLease == nil {
            diagnosticLease = source.acquire(diagnostic: true) { [weak self] event in
                guard let self else { return }
                switch event {
                case let .frame(frame): self.project(frame)
                case let .gap(count, reason):
                    let line = "connections diagnostic gap: \(count) frame(s); \(reason)"
                    self.fanOut([line])
                    HakoLogStore.shared.append(line, stream: .app, level: .warning)
                default: break
                }
            }
        }
        return ConnectionDiagnosticLease(defaultReason: sceneManaged ? .noForegroundScene : .controlDisconnected) { [self] reason in
            sinks.removeAll { $0.id == id }
            guard sinks.isEmpty else { return }
            diagnosticLease?.release(); diagnosticLease = nil
             
            guard sceneManaged, observationPause == nil, let acceptedContext else { return }
            let pause = ObservationPause(id: UUID().uuidString, start: now(), reason: reason)
            observationPause = pause
            appendJournal([boundary(.observationsPaused, pause: pause, context: acceptedContext.route, at: pause.start)])
        }
    }

    private func boundary(_ kind: RuntimeRouteEvidence.Kind, pause: ObservationPause,
                          context: RuntimeRouteContext, at: Date) -> RuntimeRouteEvidence {
        RuntimeRouteEvidence(kind: kind, timestamp: at, profilePointerID: context.profileID,
            profilePointerRevision: context.profileRevision, coreProcessIdentifier: context.coreProcessIdentifier,
            coreStartTimeUnix: context.coreStartTimeUnix, mode: context.mode,
            observationPauseID: pause.id, observationPauseStartedAt: pause.start, observationPauseReason: pause.reason)
    }

    private func appendJournal(_ evidence: [RuntimeRouteEvidence]) {
        guard !evidence.isEmpty else { return }
        let previous = journalTask, journal = routeJournal
        journalTask = Task {
            await previous?.value
            try? await journal.append(evidence)
        }
    }

    func waitForJournalWrites() async { await journalTask?.value }

    private func project(_ frame: ConnectionObservation<[HakoConnection]>) {
         
         
        guard let context = sinks.compactMap({ $0.context() })
            .filter({
                $0.route.coreProcessIdentifier > 0 && $0.route.coreStartTimeUnix > 0 &&
                !$0.route.profileID.isEmpty && $0.route.profileID != "unavailable" &&
                !$0.route.profileRevision.isEmpty && $0.route.profileRevision != "unavailable"
            })
            .max(by: { $0.confirmedAt < $1.confirmedAt }) else { return }
        if let acceptedContext,
           (context.route.coreProcessIdentifier != acceptedContext.route.coreProcessIdentifier ||
            context.route.coreStartTimeUnix != acceptedContext.route.coreStartTimeUnix),
           context.confirmedAt < acceptedContext.confirmedAt { return }
        let sceneManaged = sinks.contains(where: \.sceneManaged)
        if !sceneManaged { acceptedContext = context }
        source.identifyRuntime(context.route.generationKey)
         
         
        guard frame.runtimeIdentity == context.route.generationKey else {
            source.reportDiagnosticGap(reason: "Frame crossed a runtime confirmation boundary")
            return
        }
         
        if sceneManaged {
            guard source.isEligibleForDiagnosticProjection(frame) else { return }
            acceptedContext = context
        }
        var evidence: [RuntimeRouteEvidence] = []
        if let pause = observationPause {
            evidence.append(boundary(.observationsResumed, pause: pause, context: context.route, at: frame.observedDate))
            observationPause = nil
        }
        evidence += routeProjector.project(connections: frame.value, context: context.route,
                                           observedAt: frame.observedDate)
        guard !evidence.isEmpty else { return }
        appendJournal(evidence)
        fanOut(evidence.compactMap { try? $0.logLine() })
    }

    private func fanOut(_ lines: [String]) {
        let receivers = sinks.map(\.receive)
        for receive in receivers { receive(lines) }
    }

    static func makeSource(
        socketPath: @escaping () -> String? = defaultConnectionsSocketPath,
        clientFactory: @escaping ConnectionsClientFactory = makeNativeConnectionsClient,
        requiresRuntimeIdentification: Bool = false
    ) -> ConnectionObservationSource<[HakoConnection]> {
        ConnectionObservationSource(requiresRuntimeIdentification: requiresRuntimeIdentification, parse: ConnectionsParser.parseValid) { receive in
            guard let path = socketPath() else {
                throw NSError(domain: "Hako.Connections", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "App Group unavailable"])
            }
            return try clientFactory(path, Handler(receive: receive))
        }
    }

    private final class Handler: NSObject, HakoClashAPIClientHandlerProtocol {
        let receive: (ConnectionTransportEvent) -> Void
        init(receive: @escaping (ConnectionTransportEvent) -> Void) { self.receive = receive }
        func connected() { receive(.connected) }
        func disconnected(_ message: String?) { receive(.disconnected(message ?? "Connections stream disconnected")) }
        func writeConnections(_ message: String?) { receive(.snapshot(message ?? "")) }
        func writeTraffic(_: String?) {}
        func writeMemory(_: String?) {}
        func writeLogs(_: String?) {}
        func writeMode(_: String?) {}
    }
}
