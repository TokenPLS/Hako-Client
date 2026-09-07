import Foundation
import Hako

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
    let runtimeIdentityCache = RuntimeIdentityCache(ttl: 5) { NodesRuntimeIdentity.load() }

    private struct DiagnosticSink {
        let id: UUID
        let context: () -> ConnectionDiagnosticContext?
        let receive: ([String]) -> Void
    }
    private var sinks: [DiagnosticSink] = []
    private var diagnosticLease: ConnectionSourceLease?
    private var acceptedContext: ConnectionDiagnosticContext?

    init(source: ConnectionObservationSource<[HakoConnection]>,
         projector: RuntimeRouteEvidenceProjector = RuntimeRouteEvidenceProjector(),
         journal: RuntimeRouteEvidenceJournal = RuntimeRouteEvidenceJournal(fileURL: RuntimeRouteEvidenceJournal.defaultFileURL())) {
        self.source = source
        routeProjector = projector
        routeJournal = journal
    }

    func acquireDiagnostics(context: @escaping () -> ConnectionDiagnosticContext?,
                            receive: @escaping ([String]) -> Void) -> ConnectionSourceLease {
        let id = UUID()
        sinks.append(DiagnosticSink(id: id, context: context, receive: receive))
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
        return ConnectionSourceLease { [self] in
            sinks.removeAll { $0.id == id }
            if sinks.isEmpty { diagnosticLease?.release(); diagnosticLease = nil }
        }
    }

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
        acceptedContext = context
        source.identifyRuntime(context.route.generationKey)
         
         
        guard frame.runtimeIdentity == context.route.generationKey else {
            source.reportDiagnosticGap(reason: "Frame crossed a runtime confirmation boundary")
            return
        }
        let evidence = routeProjector.project(connections: frame.value, context: context.route,
                                             observedAt: frame.observedDate)
        guard !evidence.isEmpty else { return }
        fanOut(evidence.compactMap { try? $0.logLine() })
        let journal = routeJournal
        Task { try? await journal.append(evidence) }
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
