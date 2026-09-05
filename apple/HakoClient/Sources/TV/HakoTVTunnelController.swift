import Combine
import Foundation
import NetworkExtension

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
final class HakoTVTunnelController: ObservableObject {
     
     
    @Published var state: HakoTVProductState = .empty

     
     
     
     
    @Published var lastActivation: Activation?

    struct Activation: Equatable {
        let subscriptionID: HakoTVSubscription.ID
        let at: Date
    }

    static let vpnProfileTitle = "Clash"
    static let vpnProfileDescription = "Clash by Hako"

     
     
     
     
     
    nonisolated static var defaultContainer: URL? {
        if let group = HakoAppIdentifiers.appGroupContainer { return group }

        return nil

    }
    private static let messageTimeout: TimeInterval = 8
     
    private static let reloadTimeout: TimeInterval = 30

    private let container: URL?
    private let session: URLSession
     
    private let autoConnect: HakoTVAutoConnect.Store
     
     
    typealias ProfileLoader = @MainActor () async throws -> [any HakoTVSystemProfile]
    typealias ProfileMaker = @MainActor () -> any HakoTVSystemProfile
     
     
     
     
    private let coordinator: HakoTVProfileCoordinator
     
     
    private var manager: (any HakoTVSystemProfile)? { coordinator.current }
    private var statusObserver: NSObjectProtocol?
    private var pollTask: Task<Void, Never>?
    private var startRequested = false
     
     
     
     
    private var stopRequested = false
     
     
     
     
     
    private var stopEpoch = 0
     
     
     
     
     
    private var connectTask: Task<Void, Never>?
     
    private var refreshTask: Task<Void, Never>?
     
     
    private var startGeneration = 0
    private var groupOrder: [String] = []
    private var lastKnownStatus: NEVPNStatus = .invalid

    init(
        container: URL? = HakoTVTunnelController.defaultContainer,
        session: URLSession = HakoTVNetwork.session,
        autoConnect: HakoTVAutoConnect.Store = HakoTVAutoConnect.Store(),
        loadProfiles: @escaping ProfileLoader = { try await NETunnelProviderManager.loadAllFromPreferences() },
        makeProfile: @escaping ProfileMaker = { NETunnelProviderManager() },
        preferencesTimeout: TimeInterval = 15
    ) {
        self.container = container
        self.session = session
        self.autoConnect = autoConnect
        self.coordinator = HakoTVProfileCoordinator(
            intent: autoConnect.isEnabled,
            persistIntent: { autoConnect.set($0) },
            load: loadProfiles,
            make: makeProfile,
            timeout: preferencesTimeout,
            ownedBy: { HakoTVTunnelController.owns($0) }
        )
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let connection = notification.object as? NEVPNConnection else { return }
            Task { @MainActor in
                guard let managed = self.manager?.vpnConnection, connection === managed else { return }
                self.statusChanged()
            }
        }
    }

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
        pollTask?.cancel()
    }

     

     
     
     
     
     
     
    func prepare(subscription: HakoTVSubscription?) async {
        do {
            try await coordinator.find()
        } catch {
            report(issue: error.localizedDescription)
        }
        state.autoConnect = autoConnect.isEnabled
        showConfiguration(for: subscription)
        statusChanged()
    }

     
     
     
    func connect(subscription: HakoTVSubscription) async {
        guard connectTask == nil else { return }
         
         
         
         
         
         
        stopRequested = false
         
         
         
        if let refreshTask { await refreshTask.value }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performConnect(subscription)
        }
        connectTask = task
        await task.value
         
         
        if connectTask == task { connectTask = nil }
    }

    private func performConnect(_ subscription: HakoTVSubscription) async {
        state.issue = nil
        do {
            if needsActivation(for: subscription) {
                state.pipelinePhase = .downloading
                defer { state.pipelinePhase = nil }
                try await activate(subscription) { [weak self] phase in self?.state.pipelinePhase = phase }
            }
            try Task.checkCancellation()
            try await start()
        } catch is CancellationError {
             
             
            state.pipelinePhase = nil
            HakoLogStore.shared.append("tv connect cancelled", stream: .app)
            statusChanged()
        } catch {
            state.pipelinePhase = nil
            report(issue: error.localizedDescription)
            HakoLogStore.shared.append("tv connect failed  reason=\(error.localizedDescription)", stream: .app, level: .warning)
            statusChanged()
        }
    }

     
     
     
     
     
     
     
    func refresh(subscription: HakoTVSubscription) async {
        guard connectTask == nil, refreshTask == nil else { return }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh(subscription)
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh(_ subscription: HakoTVSubscription) async {
        state.refresh = .updating(subscription.id, .downloading)
        do {
            try await activate(subscription) { [weak self] phase in
                self?.state.refresh = .updating(subscription.id, phase)
            }
            state.refresh = nil
            if state.isConnected {
                try await reloadOrRestart(subscription)
            }
        } catch is CancellationError {
            state.refresh = nil
        } catch {
            state.refresh = .failed(subscription.id, error.localizedDescription)
            HakoLogStore.shared.append("tv update failed  reason=\(error.localizedDescription)", stream: .app, level: .warning)
        }
    }

     
     
     
     
    private func reloadOrRestart(_ subscription: HakoTVSubscription) async throws {
        let reply = try? await send(["cmd": "reload"], timeout: Self.reloadTimeout)
        if let reply, Self.isOK(reply) {
            HakoLogStore.shared.append("tv reload applied", stream: .app)
            await refreshProxies()
            await refreshStatus()
            return
        }
        HakoLogStore.shared.append("tv reload refused; restarting the tunnel", stream: .app, level: .warning)
        await disconnect()
        let epoch = stopEpoch
        try await waitUntilDown()
         
         
        guard stopEpoch == epoch else { throw CancellationError() }
         
         
        stopRequested = false
        try await start()
    }

     
     
     
    func disconnect() async {
        startRequested = false
        stopRequested = true
        stopEpoch += 1
        if let connectTask {
            connectTask.cancel()
            await connectTask.value
             
             
             
             
             
            if self.connectTask == connectTask { self.connectTask = nil }
        }
         
         
         
         
         
        await coordinator.stop { $0.stopVPNTunnel() }
        statusChanged()
    }

     
     
     
     
     
     
     
    func setAutoConnect(_ wanted: Bool) async {
        await coordinator.setWanted(wanted) { [weak self] outcome, wish in
            guard let self else { return }
             
             
            switch outcome {
            case .saved, .noProfile:
                self.state.autoConnect = wish
                self.state.autoConnectIssue = nil
            case .indeterminate(let error):
                 
                 
                 
                self.state.autoConnect = wish
                self.state.autoConnectIssue = Self.saveIndeterminate(error)
            case .refused(let error):
                 
                self.state.autoConnect = self.autoConnect.isEnabled
                self.state.autoConnectIssue = Self.saveRefused(error)
            case .loadFailed(let error):
                 
                self.state.autoConnect = self.autoConnect.isEnabled
                self.state.autoConnectIssue = Self.saveRefused(error)
            case .superseded:
                 
                 
                break
            }
        }
    }

     
     
     
     
    func subscriptionChanged(to subscription: HakoTVSubscription) async {
        let busy = connectTask != nil || state.isConnected || state.stage == .connecting
        guard busy else {
            showConfiguration(for: subscription)
            return
        }
        await disconnect()
        let epoch = stopEpoch
        do {
            try await waitUntilDown()
        } catch {
            report(issue: error.localizedDescription)
            return
        }
         
         
        guard stopEpoch == epoch else {
            showConfiguration(for: subscription)
            return
        }
        await connect(subscription: subscription)
    }



     

     
     
     
     
     
    func sendProxyShare(_ message: [String: Any]) async throws -> Data {
        try await send(message)
    }

    func setMode(_ mode: HakoTVOutboundMode) async {
        guard state.isConnected else {
            state.outboundMode = mode
            return
        }
        do {
            let reply = try await send(["cmd": "setMode", "mode": mode.kernelToken])
            guard Self.isOK(reply) else { throw Self.replyError(reply) }
            state.outboundMode = mode
            state.issue = nil
        } catch {
            report(issue: error.localizedDescription)
        }
    }

    func pin(member: String, group: String) async {
        guard state.isConnected else {
            state.pin(member: member, in: group)
            return
        }
        do {
            let reply = try await send(["cmd": "select", "group": group, "name": member])
            guard Self.isOK(reply) else { throw Self.replyError(reply) }
            state.issue = nil
            await refreshProxies()
        } catch {
            report(issue: error.localizedDescription)
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func testAll(group: HakoProxyGroupSnapshot) async {
         
         
         
         
         
         
        HakoLogStore.shared.append(
            "url test sweep requested  group=\(group.name) members=\(group.members.count) "
                + "connected=\(state.isConnected) stage=\(state.stage) busy=\(!sweepingMembers.isEmpty)",
            stream: .app
        )
        guard state.isConnected, sweepingMembers.isEmpty else { return }
        sweepingMembers = Set(group.members.map(\.name))
        defer { sweepingMembers = [] }
        HakoTVNodesScreen.beginTesting(group, state: &state)
         
         
         
         
         
         
         
         
         
        var measured = 0
        for member in group.members {
            guard state.isConnected else { return }
            let reply = try? await send(["cmd": "urltest", "name": member.name])
            let delay = (try? HakoTVKernelSnapshots.urlTestDelay(from: reply)) ?? -1
            if delay > 0 { measured += 1 }
            HakoTVNodesScreen.record(delay: delay, for: member.name, state: &state)
        }
        HakoLogStore.shared.append(
            "url test sweep done  group=\(group.name) measured=\(measured) of \(group.members.count)",
            stream: .app
        )
    }

     
     
     
     
     
    func testOne(member: HakoProxyMemberSnapshot) async {
        guard state.isConnected, !sweepingMembers.contains(member.name) else { return }
        sweepingMembers.insert(member.name)
        defer { sweepingMembers.remove(member.name) }
        state.latency[member.name] = .testing
        let reply = try? await send(["cmd": "urltest", "name": member.name])
        let delay = (try? HakoTVKernelSnapshots.urlTestDelay(from: reply)) ?? -1
        HakoTVNodesScreen.record(delay: delay, for: member.name, state: &state)
        HakoLogStore.shared.append(
            "url test one  node=\(member.name) delay=\(delay)",
            stream: .app
        )
    }

     
     
     
     
     
     
    private var sweepingMembers: Set<String> = []

     

    private func needsActivation(for subscription: HakoTVSubscription) -> Bool {
        guard let container, let store = try? ConfigResourceStore(containerURL: container),
              let pointer = try? store.activePointer()
        else { return true }
        return pointer.profileID != HakoTVConfigPipeline.profileID(for: subscription)
    }

     
     
     
    private func showConfiguration(for subscription: HakoTVSubscription?) {
        if let subscription, !needsActivation(for: subscription) {
            loadActiveConfigurationFacts()
        } else {
            clearConfigurationFacts()
        }
    }

    private func clearConfigurationFacts() {
        guard !state.isConnected else { return }
        groupOrder = []
        state.rules = []
        state.ruleCount = 0
        state.dnsEnhancedMode = ""
        state.dnsNameservers = []
        state.dnsFallback = []
        state.dnsDefaultNameservers = []
        state.groupCount = 0
        state.ruleProvidersTotal = 0
        state.ruleProvidersLoaded = 0
        state.proxyGroups = []
        state.nodeCount = 0
        state.nodeGroup = ""
        state.nodeName = ""
    }

     
     
     
     
    private func activate(_ subscription: HakoTVSubscription, report: @escaping @MainActor (HakoTVConfigPipeline.Phase) -> Void) async throws {
        guard let container else { throw ControllerError.appGroupUnavailable }
        let pipeline = HakoTVConfigPipeline(container: container, session: session)
        let activation = try await pipeline.activate(subscription: subscription) { phase in
            Task { @MainActor in report(phase) }
        }
        for warning in activation.warnings {
            HakoLogStore.shared.append("provider warning  \(warning)", stream: .app, level: .warning)
        }
        apply(facts: try HakoTVConfigFacts(yaml: activation.finalYAML), catalog: activation.catalog)
        lastActivation = Activation(subscriptionID: subscription.id, at: Date())
    }

     
     
     
     
    private func loadActiveConfigurationFacts() {
        guard let container, let store = try? ConfigResourceStore(containerURL: container),
              let current = try? store.loadCurrent(), let yaml = current.text,
              let facts = try? HakoTVConfigFacts(yaml: yaml)
        else { return }
         
         
         
         
         
         
        let directory = try? store.activeProvidersDirectory()
        let catalog = directory.flatMap { HakoTVProviderCatalog.read(from: $0) }
        let files = directory
            .flatMap { try? FileManager.default.subpathsOfDirectory(atPath: $0.path) } ?? []
        apply(
            facts: facts,
            catalog: catalog ?? HakoTVProviderCatalog(entries: []),
            fallbackCount: HakoTVProviderCatalog.providerFileCount(in: files)
        )
    }

     
     
     
     
     
     
    private func report(issue: String) {
        state.issue = issue
        state.note(problem: issue)
    }

    private func apply(facts: HakoTVConfigFacts, catalog: HakoTVProviderCatalog, fallbackCount: Int? = nil) {
        groupOrder = facts.proxyGroupNames
        state.rules = facts.rules
        state.ruleCount = facts.rules.count
        state.dnsEnhancedMode = facts.dnsEnhancedMode
        state.dnsNameservers = facts.dnsNameservers
        state.dnsFallback = facts.dnsFallback
        state.dnsDefaultNameservers = facts.dnsDefaultNameservers
        state.groupCount = facts.proxyGroupNames.count
        state.outboundMode = HakoTVOutboundMode(rawValue: facts.mode) ?? .rule
        state.geodataSource = "Bundled"
        state.providers = catalog.entries
        let total = catalog.entries.isEmpty ? (fallbackCount ?? 0) : catalog.entries.count
        state.ruleProvidersTotal = total
        state.ruleProvidersLoaded = catalog.entries.isEmpty ? total : catalog.readyCount
         
         
         
         
         
        if !state.isConnected {
            state.proxyGroups = facts.proxyGroups
            state.nodeCount = facts.nodeCount
            if let first = facts.proxyGroups.first {
                state.nodeGroup = first.name
                state.nodeName = first.members.first?.name ?? ""
            }
        }
    }

     

    private func start() async throws {
         
         
         
         
         
         
        let epoch = stopEpoch
        try await coordinator.commitStart(
            configure: { profile in
                let tunnelProtocol = (profile.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
                tunnelProtocol.providerBundleIdentifier = HakoAppIdentifiers.tvPacketTunnelExtensionBundleID
                tunnelProtocol.serverAddress = Self.vpnProfileDescription
                profile.protocolConfiguration = tunnelProtocol
                profile.localizedDescription = Self.vpnProfileTitle
                profile.isEnabled = true
            },
            shouldAbort: { [weak self] in
                guard let self else { return true }
                return self.stopEpoch != epoch
            }
        )
         
         
         
        if stopEpoch != epoch || Task.isCancelled { throw CancellationError() }
        guard let profile = coordinator.current else { throw ControllerError.tunnelDidNotStart }
        startRequested = true
        startGeneration += 1
        try profile.startVPNTunnel()
        HakoLogStore.shared.append("tv vpn start requested", stream: .app)
         
         
         
         
        state.stage = .connecting
    }

    private static func owns(_ manager: any HakoTVSystemProfile) -> Bool {
        (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier
            == HakoAppIdentifiers.tvPacketTunnelExtensionBundleID
    }


     
     
    static func saveRefused(_ error: Error) -> String {
        String(localized: "The system did not take the change — the switch is back where it was.") + " " + error.localizedDescription
    }

     
     
    static func saveIndeterminate(_ error: Error) -> String {
        String(localized: "The system has not answered yet — the change may still take. The switch shows what you asked for; the next Connect applies it again.") + " " + error.localizedDescription
    }

     
     
     
    private func waitUntilDown() async throws {
         
        for _ in 0..<100 where (manager?.status ?? .disconnected) != .disconnected {
            try await Task.sleep(for: .milliseconds(100))
        }
        guard (manager?.status ?? .disconnected) == .disconnected else {
            throw ControllerError.systemTimedOut
        }
    }

    private func statusChanged() {
        let status = manager?.status ?? .invalid
        let previous = lastKnownStatus
        lastKnownStatus = status
        switch status {
        case .connected, .reasserting:
            if state.stage != .connected {
                state.stage = .connected
                state.connectedSince = Date()
                state.issue = nil
                startRequested = false
                startPolling()
            }
        case .connecting:
            state.stage = .connecting
        case .disconnecting:
            state.stage = .disconnecting
        case .disconnected, .invalid:
            let wasUp = state.stage == .connected || state.stage == .disconnecting
            state.stage = .disconnected
            stopPolling()
            state.connectedSince = nil
            state.downloadBytesPerSecond = 0
            state.uploadBytesPerSecond = 0
            state.connections = []
            state.connectionCount = 0
             
             
             
             
            let startNeverCameUp = startRequested && !wasUp
                && (previous == .connecting || previous == .disconnected || previous == .invalid)
            let droppedWhileUp = wasUp && !stopRequested
            if startNeverCameUp || droppedWhileUp {
                startRequested = false
                explainDrop(unexpectedWhileUp: droppedWhileUp)
            }
            stopRequested = false
        @unknown default:
            state.stage = .disconnected
        }
    }

    private func explainDrop(unexpectedWhileUp: Bool) {
        let fallback = unexpectedWhileUp
            ? ControllerError.tunnelStopped.localizedDescription
            : ControllerError.tunnelDidNotStart.localizedDescription
        guard let connection = manager?.vpnConnection else {
            report(issue: fallback)
            return
        }
        let generation = startGeneration
        connection.fetchLastDisconnectError { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                 
                 
                guard self.startGeneration == generation, self.state.stage == .disconnected else { return }
                if let error {
                    self.report(issue: error.localizedDescription)
                } else if self.state.issue == nil {
                    self.report(issue: fallback)
                }
            }
        }
    }

     

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self else { return }
                await self.refreshTraffic()
                if tick % 3 == 0, !Task.isCancelled {
                    await self.refreshProxies()
                    await self.refreshConnections()
                    await self.refreshStatus()
                }
                tick += 1
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

     
     
    private var acceptsKernelReplies: Bool {
        state.isConnected && !Task.isCancelled
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func refreshTraffic() async {
        guard let reply = try? await send(["cmd": "traffic"], timeout: 2),
              let traffic = try? HakoTVKernelSnapshots.traffic(from: reply),
              acceptsKernelReplies else { return }
        state.downloadBytesPerSecond = traffic.down
        state.uploadBytesPerSecond = traffic.up
        state.sessionBytes = traffic.downTotal + traffic.upTotal
        if traffic.memory > 0 { state.memoryBytes = traffic.memory }
    }

    func refreshProxies() async {
        guard let reply = try? await send(["cmd": "proxies"]),
              let decoded = try? HakoTVKernelSnapshots.proxies(from: reply, groupOrder: groupOrder),
              acceptsKernelReplies else { return }
        state.proxyGroups = decoded.groups
         
         
        state.latency = HakoTVNodesScreen.merge(
            polled: decoded.latency, over: state.latency, sweeping: sweepingMembers
        )
        state.nodeCount = decoded.nodeCount
        state.groupCount = decoded.groups.filter { $0.name != "GLOBAL" }.count
         
         
        let root = state.outboundMode == .global
            ? decoded.groups.first { $0.name == "GLOBAL" }
            : decoded.groups.first { $0.name != "GLOBAL" }
        if let root {
            state.nodeGroup = root.name
            state.nodeName = Self.leaf(of: root, in: decoded.groups) ?? root.currentSelection ?? ""
        }
    }

    private static func leaf(of group: HakoProxyGroupSnapshot, in groups: [HakoProxyGroupSnapshot], depth: Int = 0) -> String? {
        guard depth < 8, let selection = group.currentSelection else { return nil }
        if let next = groups.first(where: { $0.name == selection }) {
            return leaf(of: next, in: groups, depth: depth + 1) ?? selection
        }
        return selection
    }

    private func refreshConnections() async {
        guard let reply = try? await send(["cmd": "connections"]),
              let rows = try? HakoTVKernelSnapshots.connections(from: reply),
              acceptsKernelReplies else { return }
        state.connections = rows
        state.connectionCount = rows.count
    }

    private func refreshStatus() async {
        guard let reply = try? await send(["cmd": "status"]),
              let status = try? HakoTVKernelSnapshots.status(from: reply),
              let mode = HakoTVOutboundMode(rawValue: status.mode.lowercased()),
              acceptsKernelReplies else { return }
        state.outboundMode = mode
    }

     

    private func send(_ object: [String: Any], timeout: TimeInterval = messageTimeout) async throws -> Data {
        guard let session = manager?.vpnConnection as? NETunnelProviderSession else {
            throw ControllerError.extensionUnavailable
        }
        let payload = try JSONSerialization.data(withJSONObject: object)
        return try await HakoTVIPCChannel.shared.send(
            session: session,
            data: payload,
            timeoutNanoseconds: UInt64(timeout * 1_000_000_000)
        )
    }

    private static func isOK(_ reply: Data) -> Bool {
        (try? JSONSerialization.jsonObject(with: reply) as? [String: Any])?["ok"] as? Bool == true
    }

    private static func replyError(_ reply: Data) -> Error {
        guard let message = (try? JSONSerialization.jsonObject(with: reply) as? [String: Any])?["error"] as? String else {
            return ControllerError.invalidResponse
        }
        return ControllerError.kernelRefused(message)
    }

     

     
     
     
     
     
     
     
     
     
     
     
    static func bounded<T: Sendable>(
        _ seconds: TimeInterval,
        late: (@Sendable (Result<T, Error>) -> Void)? = nil,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            let once = HakoTVResumeOnce()
            let work = Task {
                do {
                    let value = try await operation()
                    if once.claim() { continuation.resume(returning: value) } else { late?(.success(value)) }
                } catch {
                    if once.claim() { continuation.resume(throwing: error) } else { late?(.failure(error)) }
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                if once.claim() {
                     
                     
                    if late == nil { work.cancel() }
                    continuation.resume(throwing: ControllerError.systemTimedOut)
                }
            }
        }
    }

     
     
     
     
    enum ControllerError: LocalizedError {
        case appGroupUnavailable
        case extensionUnavailable
        case systemTimedOut
        case tunnelTimedOut
        case invalidResponse
        case tunnelDidNotStart
        case tunnelStopped
        case kernelRefused(String)

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable:
                String(localized: "Clash could not open its secure shared container.")
            case .extensionUnavailable:
                String(localized: "The Clash packet tunnel is not available.")
            case .systemTimedOut:
                String(localized: "The system did not answer in time.")
            case .tunnelTimedOut:
                String(localized: "The Clash packet tunnel did not answer in time.")
            case .invalidResponse:
                String(localized: "The Clash packet tunnel returned an invalid response.")
            case .tunnelDidNotStart:
                String(localized: "The tunnel stopped before it came up.")
            case .tunnelStopped:
                String(localized: "The tunnel stopped on its own. Connect again to bring it back.")
            case .kernelRefused(let reason):
                String(localized: "The tunnel refused: \(reason)")
            }
        }
    }
}

 
 
 
 
private actor HakoTVIPCChannel {
    static let shared = HakoTVIPCChannel()

    private struct Pending {
        let id: UUID
        let session: NETunnelProviderSession
        let data: Data
        let timeoutNanoseconds: UInt64
        let continuation: CheckedContinuation<Data, Error>
    }

    private var queue: [Pending] = []
    private var current: Pending?
    private var timeoutTask: Task<Void, Never>?

    func send(session: NETunnelProviderSession, data: Data, timeoutNanoseconds: UInt64) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.append(Pending(
                id: UUID(), session: session, data: data,
                timeoutNanoseconds: timeoutNanoseconds, continuation: continuation
            ))
            startNextIfNeeded()
        }
    }

    private func startNextIfNeeded() {
        guard current == nil, !queue.isEmpty else { return }
        let pending = queue.removeFirst()
        current = pending
        do {
            try pending.session.sendProviderMessage(pending.data) { [weak self] response in
                Task {
                    guard let response else {
                        await self?.finish(id: pending.id, result: .failure(HakoTVTunnelController.ControllerError.extensionUnavailable))
                        return
                    }
                    await self?.finish(id: pending.id, result: .success(response))
                }
            }
        } catch {
            finish(id: pending.id, result: .failure(error))
            return
        }
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: pending.timeoutNanoseconds)
            await self?.finish(id: pending.id, result: .failure(HakoTVTunnelController.ControllerError.tunnelTimedOut))
        }
    }

    private func finish(id: UUID, result: Result<Data, Error>) {
        guard let pending = current, pending.id == id else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        current = nil
        pending.continuation.resume(with: result)
        startNextIfNeeded()
    }
}

 
final class HakoTVResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
