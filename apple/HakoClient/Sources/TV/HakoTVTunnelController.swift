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
         
        var panelName: String? = nil
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
    typealias MessageReader = @MainActor (Data, UInt64, Bool) async throws -> Data
    private let messageReader: MessageReader?
    private let pollSleep: @MainActor () async throws -> Void
    private var presentation = HakoTVPollingPresentation(page: .configuration, active: false)
    private var presentationEpoch: UInt64 = 0
    private let observationClock: @MainActor () -> HakoTVObservation.Moment

    func updatePresentation(_ presentation: HakoTVPollingPresentation) {
        guard self.presentation != presentation else { return }
        self.presentation = presentation
        presentationEpoch &+= 1
        state.observations.waitForUpdate()
        stopPolling()
        if presentation.active {
             
            statusChanged()
            startPolling()
        }
    }
    private var startRequested = false
     
     
     
     
    private var stopRequested = false
     
     
     
     
     
    private var stopEpoch = 0
     
     
     
     
     
    private var connectTask: Task<Void, Never>?
     
    private var refreshTask: Task<Void, Never>?
     
     
    private var startGeneration = 0
    private var groupOrder: [String] = []
    private var lastKnownStatus: NEVPNStatus = .invalid
    private var ipcGeneration = HakoTVIPCGeneration(active: false)
    private var observedIPCProfile: ObjectIdentifier?
    private var observedIPCSession: ObjectIdentifier?
    private var controlRevision: UInt64 = 0
    private var activeObservationGeneration: UInt64?
    private var ruleProbePointer: ActiveConfigurationPointer?
    private var ruleProbeGeneration: HakoTVIPCGeneration?
    private var nextRuleProbeAt = Date.distantPast
    private var ruleProbeBackoff: TimeInterval = 3
    private var ruleRecoveryPending = false

    private func replaceIPCGeneration(active: Bool) {
        ipcGeneration.invalidate()
        state.observations.beginGeneration()
        sweepingMembers = []
        ipcGeneration = HakoTVIPCGeneration(active: active)
    }

    init(
        container: URL? = HakoTVTunnelController.defaultContainer,
        session: URLSession = HakoTVNetwork.session,
        autoConnect: HakoTVAutoConnect.Store = HakoTVAutoConnect.Store(),
        loadProfiles: @escaping ProfileLoader = { try await NETunnelProviderManager.loadAllFromPreferences() },
        makeProfile: @escaping ProfileMaker = { NETunnelProviderManager() },
        preferencesTimeout: TimeInterval = 15,
        messageReader: MessageReader? = nil,
        observationClock: @escaping @MainActor () -> HakoTVObservation.Moment = { .init(date: Date()) },
        pollSleep: @escaping @MainActor () async throws -> Void = { try await Task.sleep(for: .seconds(1)) }
    ) {
        self.container = container
        self.messageReader = messageReader
        self.observationClock = observationClock
        self.pollSleep = pollSleep
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
             
             
            if let container, let store = try? ConfigResourceStore(containerURL: container),
               let expected = try? store.activeIdentity() {
                do {
                    _ = try await HakoTVConfigPipeline(container: container, session: session).recoverRules(expected: expected)
                    loadActiveConfigurationFacts()
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                     
                     
                    HakoLogStore.shared.append("tv startup rule recovery: \(error.localizedDescription)", stream: .app, level: .warning)
                }
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
        let generation = ipcGeneration
        state.refresh = .updating(subscription.id, .downloading)
        do {
            try await activate(subscription) { [weak self] phase in
                self?.state.refresh = .updating(subscription.id, phase)
            }
            state.refresh = nil
            if state.isConnected {
                try await reloadOrRestart(subscription, expectedGeneration: generation)
            }
        } catch is CancellationError {
            state.refresh = nil
        } catch {
             
             
            state.refresh = .failed(subscription.id, error.localizedDescription)
            HakoLogStore.shared.append("tv update failed  reason=\(error.localizedDescription)", stream: .app, level: .warning)
        }
    }

     
     
     
    func reloadOrRestart(_ subscription: HakoTVSubscription, expectedGeneration: HakoTVIPCGeneration? = nil) async throws {
        let generation = expectedGeneration ?? ipcGeneration
        controlRevision &+= 1
        state.observations.waitForUpdate()
        let reply = try await send(["cmd": "reload"], timeout: Self.reloadTimeout, expectedGeneration: generation)
        guard generation === ipcGeneration, generation.isValid else { throw ControllerError.ipcReplySuperseded }
        if Self.isOK(reply) {
            HakoLogStore.shared.append("tv reload applied", stream: .app)
            await refreshProxies()
            await refreshStatus()
            return
        }
         
         
        guard case ControllerError.kernelRefused = Self.replyError(reply) else { throw ControllerError.invalidResponse }
        HakoLogStore.shared.append("tv reload refused; restarting the tunnel", stream: .app, level: .warning)
         
         
        let epoch = stopEpoch + 1
        await disconnect()
        guard stopEpoch == epoch else { throw CancellationError() }
        try await waitUntilDown()
         
         
        guard stopEpoch == epoch else { throw CancellationError() }
         
         
        stopRequested = false
        try await start()
    }

     
     
     
    func disconnect() async {
        replaceIPCGeneration(active: false)
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
            state.observations.mode.selectLocally()
            return
        }
        let generation = ipcGeneration
        controlRevision &+= 1
        let revision = controlRevision
        do {
            state.observations.mode.waitForUpdate()
            let reply = try await send(["cmd": "setMode", "mode": mode.kernelToken], expectedGeneration: generation)
            guard generation.isValid, revision == controlRevision else { return }
            guard Self.isOK(reply) else { throw Self.replyError(reply) }
            state.outboundMode = mode
            state.observations.mode.acknowledgeOperation(at: observationClock().date)
            state.issue = nil
        } catch {
            HakoLogStore.shared.append("tv setMode outcome  reason=\(error.localizedDescription)", stream: .app, level: .warning)
            guard generation.isValid, revision == controlRevision else { return }
            report(issue: error.localizedDescription)
        }
    }

    func pin(member: String, group: String) async {
        guard state.isConnected else {
            state.pin(member: member, in: group)
            return
        }
        let generation = ipcGeneration
        controlRevision &+= 1
        let revision = controlRevision
        let epoch = presentationEpoch
        do {
            state.observations.proxies.waitForUpdate()
            let reply = try await send(["cmd": "select", "group": group, "name": member], expectedGeneration: generation)
            guard generation.isValid, revision == controlRevision else { return }
            guard Self.isOK(reply) else { throw Self.replyError(reply) }
            state.issue = nil
             
            if presentation.active && presentationEpoch == epoch {
                await refreshProxies()
            }
        } catch {
            HakoLogStore.shared.append("tv pin outcome  reason=\(error.localizedDescription)", stream: .app, level: .warning)
            guard generation.isValid, revision == controlRevision else { return }
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
        let generation = ipcGeneration
        let previousLatency = group.members.reduce(into: [String: HakoProxyLatencyState]()) {
            $0[$1.name] = state.latency[$1.name]
        }
        sweepingMembers = Set(group.members.map(\.name))
        defer {
            if generation === ipcGeneration {
                for member in group.members where state.latency[member.name] == .testing {
                    state.latency[member.name] = previousLatency[member.name] ?? .untested
                }
                sweepingMembers = []
            }
        }
        HakoTVNodesScreen.beginTesting(group, state: &state)
         
         
         
         
         
         
         
         
         
        var measured = 0
        for member in group.members {
            guard generation.isValid else { return }
            do {
                let reply = try await send(["cmd": "urltest", "name": member.name], expectedGeneration: generation)
                guard generation.isValid else { return }
                let delay = (try? HakoTVKernelSnapshots.urlTestDelay(from: reply)) ?? -1
                if delay > 0 { measured += 1 }
                HakoTVNodesScreen.record(delay: delay, for: member.name, state: &state)
            } catch {
                HakoLogStore.shared.append("tv url test sweep ended  reason=\(error.localizedDescription)", stream: .app, level: .warning)
                guard generation.isValid else { return }
                state.latency[member.name] = .failed
                report(issue: error.localizedDescription)
                return
            }
        }
        HakoLogStore.shared.append(
            "url test sweep done  group=\(group.name) measured=\(measured) of \(group.members.count)",
            stream: .app
        )
    }

     
     
     
     
     
    func testOne(member: HakoProxyMemberSnapshot) async {
        guard state.isConnected, !sweepingMembers.contains(member.name) else { return }
        let generation = ipcGeneration
        sweepingMembers.insert(member.name)
        defer { if generation === ipcGeneration { sweepingMembers.remove(member.name) } }
        state.latency[member.name] = .testing
        do {
            let reply = try await send(["cmd": "urltest", "name": member.name], expectedGeneration: generation)
            guard generation.isValid else { return }
            let delay = (try? HakoTVKernelSnapshots.urlTestDelay(from: reply)) ?? -1
            HakoTVNodesScreen.record(delay: delay, for: member.name, state: &state)
            HakoLogStore.shared.append("url test one  node=\(member.name) delay=\(delay)", stream: .app)
        } catch {
            HakoLogStore.shared.append("tv url test ended  reason=\(error.localizedDescription)", stream: .app, level: .warning)
            guard generation.isValid else { return }
            state.latency[member.name] = .failed
            report(issue: error.localizedDescription)
        }
    }

     
     
     
     
     
     
    private var sweepingMembers: Set<String> = []

     

     
     
    var iCloudRestore: HakoTVICloudRestore? {
        get { injectedICloudRestore ?? container.map { HakoTVICloudRestore(container: $0) } }
        set { injectedICloudRestore = newValue }
    }
    private var injectedICloudRestore: HakoTVICloudRestore?

     
     
     
     
    func refreshRestoredProfilesIfNewer(store: HakoTVSubscriptionStore) async -> HakoTVSubscriptionStore? {
        guard let service = iCloudRestore, !store.followingAutoBackup.isEmpty else { return nil }
        var working = store
        let result: Result<HakoTVSubscriptionStore?, Error>
        do {
            let changed = try await service.refreshIfNewer(store: &working)
            result = .success(changed ? working : nil)
        } catch {
            result = .failure(error)
        }
        switch result {
        case .success(let refreshed):
            if refreshed != nil {
                HakoLogStore.shared.append("tv icloud refresh applied", stream: .app)
            }
            return refreshed
        case .failure(let error):
            HakoLogStore.shared.append("tv icloud refresh failed  reason=\(error.localizedDescription)", stream: .app, level: .warning)
            return nil
        }
    }

     
    func probeICloudForWelcome() async {
        guard let service = iCloudRestore else { return }
        let availability = await HakoTVICloudRestore.availability(locator: service.locator())
        state.iCloudRestoreLine = HakoTVICloudRestorePresentation.welcomeLine(availability)
    }

     
     
    func restoredDocumentIsNewerThanLastActivation(_ subscription: HakoTVSubscription) -> Bool {
        guard let at = subscription.restored?.exportedAt, let last = lastActivation,
              last.subscriptionID == subscription.id else { return false }
        return at > last.at
    }

     
    func noteActivated(_ subscription: HakoTVSubscription, at date: Date) {
        lastActivation = Activation(subscriptionID: subscription.id, at: date)
    }

    private func needsActivation(for subscription: HakoTVSubscription) -> Bool {
        if restoredDocumentIsNewerThanLastActivation(subscription) { return true }
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
        controlRevision &+= 1
        state.observations.proxies = .init()
        state.observations.mode = .init()
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
        lastActivation = Activation(subscriptionID: subscription.id, at: Date(), panelName: activation.panelName)
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
        controlRevision &+= 1
        state.observations.waitForUpdate()
        state.observations.mode.useConfiguration()
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
            state.observations.proxies.useConfiguration()
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
        replaceIPCGeneration(active: false)
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
        let active = status == .connected || status == .reasserting
        let previouslyActive = previous == .connected || previous == .reasserting
        let profileID = manager.map { ObjectIdentifier($0) }
        let sessionID = manager?.vpnConnection.map { ObjectIdentifier($0) }
        let runtimeIdentityChanged = profileID != observedIPCProfile || sessionID != observedIPCSession
        if active != previouslyActive || runtimeIdentityChanged {
            replaceIPCGeneration(active: active)
            observedIPCProfile = profileID
            observedIPCSession = sessionID
        }
        if active {
             
            if activeObservationGeneration == nil || runtimeIdentityChanged {
                activeObservationGeneration = state.observations.generation
            }
        } else if status == .disconnected || status == .invalid, let ended = activeObservationGeneration {
            state.observations.lastEndedGeneration = ended
            activeObservationGeneration = nil
        }
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
            stopPolling()
            state.stage = .connecting
        case .disconnecting:
            stopPolling()
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
        guard pollTask == nil, presentation.active, state.isConnected else { return }
        let page = presentation.page
        pollTask = Task { [weak self] in
            var tick = 0
            while !Task.isCancelled {
                guard let self, self.state.isConnected else { return }
                for command in page.commands(tick: tick) {
                    guard !Task.isCancelled else { return }
                    switch command {
                    case .traffic: await self.refreshTraffic()
                    case .proxies: await self.refreshProxies(cancellableRead: true)
                    case .connections: await self.refreshConnections()
                    case .status: await self.refreshStatus(cancellableRead: true)
                    }
                }
                tick = (tick + 1) % 3
                do { try await self.pollSleep() } catch { return }
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


     
    private struct ReadContext {
        let generation: HakoTVIPCGeneration
        let presentationEpoch: UInt64
        let controlRevision: UInt64
    }

    private func readContext() -> ReadContext {
        .init(generation: ipcGeneration, presentationEpoch: presentationEpoch, controlRevision: controlRevision)
    }

    private func accepts(_ context: ReadContext) -> Bool {
        acceptsKernelReplies && context.generation === ipcGeneration && context.generation.isValid
            && context.presentationEpoch == presentationEpoch && context.controlRevision == controlRevision
    }

    private func readFailed(_ error: Error, context: ReadContext,
                            fields: [WritableKeyPath<HakoTVControlObservations, HakoTVObservation>]) {
        guard accepts(context), !(error is CancellationError) else { return }
        let kind: HakoTVObservation.FailureKind
        if let error = error as? ControllerError {
            switch error {
            case .ipcReplySuperseded: return
            case .ipcNotSent: kind = .notSent
            case .ipcResultUnknown: kind = .resultUnknown
            case .invalidResponse: kind = .invalidReply
            default: kind = .readFailed
            }
        } else {
            if let decoding = error as? HakoTVKernelSnapshots.DecodingError {
                switch decoding {
                case .kernelError: kind = .readFailed
                case .notAnObject: kind = .invalidReply
                }
            } else { kind = .readFailed }
        }
        let failure = HakoTVObservation.Failure(kind: kind, message: error.localizedDescription)
        for field in fields { state.observations[keyPath: field].fail(failure) }
    }

    private func refreshTraffic() async {
        let context = readContext()
        do {
            let reply = try await send(["cmd": "traffic"], timeout: 2, cancellableRead: true)
            let traffic = try HakoTVKernelSnapshots.traffic(from: reply)
            guard accepts(context) else { return }
            let moment = observationClock()
            if traffic.hasRates {
                state.downloadBytesPerSecond = traffic.down
                state.uploadBytesPerSecond = traffic.up
                state.observations.traffic.accept(moment)
            } else {
                state.observations.traffic.fail(.init(kind: .invalidReply, message: String(localized: "Valid traffic rates were not included in the reply.")))
            }
            if traffic.hasTotals {
                state.sessionBytes = traffic.downTotal + traffic.upTotal
                state.observations.totals.accept(moment)
            } else {
                state.observations.totals.fail(.init(kind: .invalidReply, message: String(localized: "Valid session totals were not included in the reply.")))
            }
            if traffic.memory > 0 {
                state.memoryBytes = traffic.memory
                state.observations.memory.accept(moment)
            } else {
                state.observations.memory.fail(.init(kind: .invalidReply, message: String(localized: "A valid memory sample was not included in the reply.")))
            }
        } catch {
            readFailed(error, context: context, fields: [\.traffic, \.totals, \.memory])
        }
    }

    func refreshProxies(cancellableRead: Bool = false) async {
        let context = readContext()
        do {
            let reply = try await send(["cmd": "proxies"], cancellableRead: cancellableRead)
            let decoded = try HakoTVKernelSnapshots.proxies(from: reply, groupOrder: groupOrder)
            guard accepts(context) else { return }
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
            } else {
                state.nodeName = ""
                state.nodeGroup = ""
            }
            state.observations.proxies.accept(observationClock())
        } catch {
            readFailed(error, context: context, fields: [\.proxies])
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
        let context = readContext()
        do {
            let reply = try await send(["cmd": "connections"], cancellableRead: true)
            let read = try HakoTVKernelSnapshots.connectionRead(from: reply)
            guard accepts(context) else { return }
            guard read.isComplete else {
                state.observations.connections.fail(.init(kind: .invalidReply, message: String(localized: "The connection list was incomplete.")))
                return
            }
            state.connections = read.rows
            state.connectionCount = read.rows.count
            state.observations.connections.accept(observationClock())
        } catch {
            readFailed(error, context: context, fields: [\.connections])
        }
    }

    private func refreshStatus(cancellableRead: Bool = false) async {
        let context = readContext()
        do {
            let reply = try await send(["cmd": "status"], cancellableRead: cancellableRead)
            let status = try HakoTVKernelSnapshots.status(from: reply)
            guard let mode = HakoTVOutboundMode(rawValue: status.mode.lowercased()) else {
                throw HakoTVKernelSnapshots.DecodingError.notAnObject("mode")
            }
            guard accepts(context) else { return }
            state.outboundMode = mode
            state.observations.mode.accept(observationClock())
            await refreshRuleProviders(force: false)
        } catch {
            readFailed(error, context: context, fields: [\.mode])
        }
    }

     
    func refreshRuleProviders(force: Bool = true, now: Date = Date()) async {
        let context = readContext()
        guard accepts(context), let container,
              let store = try? ConfigResourceStore(containerURL: container),
              let expected = try? store.activeIdentity() else { return }
        let newIdentity = ruleProbePointer != expected || ruleProbeGeneration !== ipcGeneration
        let pending = ruleRecoveryPending || state.providers.contains { $0.kind == "rule" && $0.pending == true }
        let visible = presentation.active && presentation.page == .providers
        guard force || newIdentity || ((pending || visible) && now >= nextRuleProbeAt) else { return }
        if newIdentity { ruleProbeBackoff = 3 }
        ruleProbePointer = expected
        ruleProbeGeneration = ipcGeneration
        nextRuleProbeAt = now.addingTimeInterval(visible ? 10 : ruleProbeBackoff)
        ruleProbeBackoff = min(60, ruleProbeBackoff * 2)
        let directory = store.providersDirectory(profileID: expected.profileID, revision: expected.revision)
        let record = directory.flatMap { HakoTVRuleRecovery.read(from: $0) }
        ruleRecoveryPending = record?.hasUnexpandedRoutes ?? false
         
         
        guard state.providers.contains(where: { $0.kind == "rule" }) else { return }
        do {
            let reply = try await send(["cmd": "ruleProviders"], cancellableRead: true)
            let providers = try HakoTVKernelSnapshots.ruleProviders(from: reply)
            guard accepts(context), try store.activeIdentity() == expected else { return }
            state.providers = state.providers.map { entry in
                guard entry.kind == "rule", let provider = providers[entry.name] else { return entry }
                return .init(kind: entry.kind, name: entry.name,
                             updatedAt: provider.updatedAt ?? entry.updatedAt,
                             failure: provider.loaded ? nil : entry.failure,
                             pending: provider.loaded ? false : (record == nil ? entry.pending : true))
            }
            state.ruleProvidersLoaded = HakoTVProviderCatalog(entries: state.providers).readyCount
            guard record != nil else { return }
            let loadedHashes = providers.filter { $0.value.loaded }.mapValues(\.contentHash)
            let pipeline = HakoTVConfigPipeline(container: container, session: session)
            let recovered = try await pipeline.recoverRules(expected: expected, loadedHashes: loadedHashes) { [weak self] hashes in
                guard let self, self.accepts(context), try store.activeIdentity() == expected else { return false }
                let second = try HakoTVKernelSnapshots.ruleProviders(from:
                    await self.send(["cmd": "ruleProviders"], cancellableRead: true))
                guard self.accepts(context), try store.activeIdentity() == expected else { return false }
                return hashes.allSatisfy { key, hash in
                    let name = String(key.dropFirst("rule:".count))
                    return second[name]?.loaded == true && second[name]?.contentHash == hash
                }
            }
            if let recovered, accepts(context) {
                ruleProbePointer = .init(profileID: recovered.profileID, revision: recovered.revision)
                if let directory = store.providersDirectory(profileID: recovered.profileID, revision: recovered.revision) {
                    ruleRecoveryPending = HakoTVRuleRecovery.read(from: directory)?.hasUnexpandedRoutes ?? false
                }
            }
        } catch {
             
             
            guard !(error is CancellationError), accepts(context),
                  (try? store.activeIdentity()) == expected else { return }
            HakoLogStore.shared.append("tv rule recovery: \(error.localizedDescription)", stream: .app, level: .warning)
        }
    }


     

    private func send(_ object: [String: Any], timeout: TimeInterval = messageTimeout, cancellableRead: Bool = false, expectedGeneration: HakoTVIPCGeneration? = nil) async throws -> Data {
        let generation = expectedGeneration ?? ipcGeneration
        guard generation === ipcGeneration, generation.isValid else { throw ControllerError.ipcNotSent(.connectionChanged) }
        let payload = try JSONSerialization.data(withJSONObject: object)
        let reply: Data
        if let messageReader {
            reply = try await messageReader(payload, UInt64(timeout * 1_000_000_000), cancellableRead)
        } else {
            guard let session = manager?.vpnConnection as? NETunnelProviderSession else {
                throw ControllerError.ipcNotSent(.connectionChanged)
            }
            reply = try await HakoTVIPCChannel.shared.send(session: session, data: payload,
                timeoutNanoseconds: UInt64(timeout * 1_000_000_000),
                cancellableRead: cancellableRead, generation: generation)
        }
        guard generation === ipcGeneration, generation.isValid else { throw ControllerError.ipcReplySuperseded }
        return reply
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
        case ipcNotSent(IPCNotSentReason)
        case ipcResultUnknown
        case ipcReplySuperseded

        enum IPCNotSentReason {
            case capacity, deadline, connectionChanged, unresolved, invalidRequest, unsupportedAsyncReload
            case transport(String)
        }
        case tunnelDidNotStart
        case tunnelStopped
        case kernelRefused(String)

        var errorDescription: String? {
            switch self {
            case .appGroupUnavailable:
                return String(localized: "Clash could not open its secure shared container.")
            case .extensionUnavailable:
                return String(localized: "The Clash packet tunnel is not available.")
            case .systemTimedOut:
                return String(localized: "The system did not answer in time.")
            case .tunnelTimedOut:
                return String(localized: "The Clash packet tunnel did not answer in time.")
            case .ipcNotSent(let reason):
                let detail: String
                switch reason {
                case .capacity: detail = String(localized: "The tunnel request queue is full.")
                case .deadline: detail = String(localized: "The request expired while waiting.")
                case .connectionChanged: detail = String(localized: "The connection changed while waiting.")
                case .unresolved: detail = String(localized: "An earlier tunnel request is still unresolved.")
                case .invalidRequest: detail = String(localized: "The tunnel request is invalid.")
                case .unsupportedAsyncReload: detail = String(localized: "Asynchronous reload is not supported here.")
                case .transport(let message): detail = message
                }
                return String(localized: "Not sent.") + " " + detail
            case .ipcResultUnknown:
                return String(localized: "The request was sent, but its result could not be confirmed. It will not be sent again automatically.")
            case .ipcReplySuperseded:
                return String(localized: "The request's reply belongs to an earlier connection.")
            case .invalidResponse:
                return String(localized: "The Clash packet tunnel returned an invalid response.")
            case .tunnelDidNotStart:
                return String(localized: "The tunnel stopped before it came up.")
            case .tunnelStopped:
                return String(localized: "The tunnel stopped on its own. Connect again to bring it back.")
            case .kernelRefused(let reason):
                return String(localized: "The tunnel refused: \(reason)")
            }
        }
    }
}

 
 
 
actor HakoTVIPCChannel {
    static let shared = HakoTVIPCChannel()
    typealias Delivery = @Sendable (Data, @escaping @Sendable (Data?) -> Void) throws -> Void
    typealias Failure = HakoTVTunnelController.ControllerError

    struct Limits: Sendable {
        var queuedCount = 32
        var payloadBytes = 256 * 1024
        var timeoutNanoseconds: UInt64 = 30_000_000_000
    }
    private struct Pending {
        let id: UUID
        let command: String
        let deliver: Delivery
        let data: Data
        let ticket: HakoTVReadAdmission?
        let generation: HakoTVIPCGeneration?
        let deadline: ContinuousClock.Instant
        let continuation: CheckedContinuation<Data, Error>
    }
     
     
    private struct Unresolved {
        let id: UUID
        let command: String
        let generation: HakoTVIPCGeneration?
        let deadline: ContinuousClock.Instant
        var continuation: CheckedContinuation<Data, Error>?
    }

    private let limits: Limits
    private var queue: [Pending] = []
    private var current: Unresolved?
    private var deadlines: [UUID: Task<Void, Never>] = [:]
    private(set) var queuedBytes = 0
    var queuedCount: Int { queue.count }
    var unresolvedCount: Int { current == nil ? 0 : 1 }
    var quarantined: Bool { current != nil && current?.continuation == nil }

    init(limits: Limits = Limits()) { self.limits = limits }

    func send(session: NETunnelProviderSession, data: Data, timeoutNanoseconds: UInt64,
              cancellableRead: Bool = false, generation: HakoTVIPCGeneration? = nil) async throws -> Data {
        try await send(data: data, timeoutNanoseconds: timeoutNanoseconds,
                       cancellableRead: cancellableRead, generation: generation) { data, reply in
            try session.sendProviderMessage(data, responseHandler: reply)
        }
    }

    func send(data: Data, timeoutNanoseconds: UInt64, cancellableRead: Bool = false,
              generation: HakoTVIPCGeneration? = nil, deliver: @escaping Delivery) async throws -> Data {
        let deadline = ContinuousClock.now.advanced(by: .nanoseconds(Int64(clamping:
            min(timeoutNanoseconds, limits.timeoutNanoseconds))))
        guard data.count <= limits.payloadBytes else { throw Failure.ipcNotSent(.capacity) }
        guard let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = request["cmd"] as? String, !command.isEmpty, command.utf8.count <= 64 else {
            throw Failure.ipcNotSent(.invalidRequest)
        }
         
         
        if command == "reload", request["async"] as? Bool == true {
            throw Failure.ipcNotSent(.unsupportedAsyncReload)
        }
        let id = UUID()
        let ticket = cancellableRead && Self.readCommands.contains(command) ? HakoTVReadAdmission() : nil
        return try await withTaskCancellationHandler {
            if ticket != nil { try Task.checkCancellation() }
            guard generation?.isValid != false else { throw Failure.ipcNotSent(.connectionChanged) }
            guard deadline > .now else { throw Failure.ipcNotSent(.deadline) }
            guard !quarantined else { throw Failure.ipcNotSent(.unresolved) }
            guard queue.count < limits.queuedCount,
                  data.count <= limits.payloadBytes - queuedBytes else { throw Failure.ipcNotSent(.capacity) }
            return try await withCheckedThrowingContinuation { continuation in
                queue.append(Pending(id: id, command: command, deliver: deliver, data: data,
                    ticket: ticket, generation: generation, deadline: deadline, continuation: continuation))
                queuedBytes += data.count
                deadlines[id] = Task { [weak self] in
                    do { try await ContinuousClock().sleep(until: deadline) } catch { return }
                    await self?.expire(id: id)
                }
                startNextIfNeeded()
            }
        } onCancel: {
            guard let ticket else { return }
            ticket.cancel()
            Task { await self.removeQueued(id: id, error: CancellationError()) }
        }
    }

    private static let readCommands: Set<String> = [
        "hello", "runtimeDiagnostics", "reloadStatus", "status", "traffic",
        "connections", "proxies", "ruleProviders", "logs", "proxyShareStatus"
    ]

    private func removeQueued(id: UUID, error: Error) {
        guard let index = queue.firstIndex(where: { $0.id == id }) else { return }
        let pending = queue.remove(at: index)
        queuedBytes -= pending.data.count
        deadlines.removeValue(forKey: id)?.cancel()
        pending.continuation.resume(throwing: error)
    }

    private func startNextIfNeeded() {
        guard current == nil else { return }
        while !queue.isEmpty {
            let pending = queue.removeFirst()
            queuedBytes -= pending.data.count
            let failure: Error?
            if pending.generation?.isValid == false { failure = Failure.ipcNotSent(.connectionChanged) }
            else if pending.deadline <= .now { failure = Failure.ipcNotSent(.deadline) }
            else if let ticket = pending.ticket, !ticket.admit() { failure = CancellationError() }
            else { failure = nil }
            if let failure {
                deadlines.removeValue(forKey: pending.id)?.cancel()
                pending.continuation.resume(throwing: failure)
                continue
            }
            let id = pending.id
            current = Unresolved(id: id, command: pending.command, generation: pending.generation,
                                 deadline: pending.deadline, continuation: pending.continuation)
            do {
                try pending.deliver(pending.data) { [weak self] response in
                    Task { await self?.receive(id: id, response: response) }
                }
                return
            } catch {
                 
                deadlines.removeValue(forKey: id)?.cancel()
                current = nil
                pending.continuation.resume(throwing: Failure.ipcNotSent(.transport(error.localizedDescription)))
                 
            }
        }
    }

    private func expire(id: UUID) {
        deadlines.removeValue(forKey: id)?.cancel()
        if current?.id == id { makeUnknown(id: id) }
        else { removeQueued(id: id, error: Failure.ipcNotSent(.deadline)) }
    }

    private func makeUnknown(id: UUID) {
        guard current?.id == id else { return }
        deadlines.removeValue(forKey: id)?.cancel()
        let continuation = current?.continuation
        current?.continuation = nil
        continuation?.resume(throwing: Failure.ipcResultUnknown)
    }

    private func receive(id: UUID, response: Data?) {
        guard let unresolved = current, unresolved.id == id else { return }
        guard let response, Self.isCompletion(response, command: unresolved.command) else {
            makeUnknown(id: id)
            return
        }
        deadlines.removeValue(forKey: id)?.cancel()
        current = nil
        if unresolved.deadline <= .now {
            unresolved.continuation?.resume(throwing: Failure.ipcResultUnknown)
        } else if unresolved.generation?.isValid == false {
            unresolved.continuation?.resume(throwing: Failure.ipcReplySuperseded)
        } else {
            unresolved.continuation?.resume(returning: response)
        }
        startNextIfNeeded()
    }

    private static func isCompletion(_ data: Data, command: String) -> Bool {
         
         
        if command == "consumeGoCrashReport" { return String(data: data, encoding: .utf8) != nil }
        guard let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return false }
        if command == "logs", value is [String] || value is NSNull { return true }
        guard let object = value as? [String: Any] else { return false }
        if object["error"] is String { return true }
        if object["accepted"] as? Bool == true { return false }
        switch command {
        case "reload", "setMode", "select", "closeAll", "recordMemoryPressureEvidence":
            return object["ok"] as? Bool == true
        case "hello":
            return object["schemaVersion"] is NSNumber && object["coreVersion"] is String
        case "status":
            return object["status"] is String && object["mode"] is String
        case "traffic":
            return ["up", "down", "upTotal", "downTotal"].allSatisfy { object[$0] is NSNumber }
        case "connections":
            return object["connections"] is [Any] || object["connections"] is NSNull
        case "proxies": return object["proxies"] is [String: Any]
         
         
         
        case "ruleProviders": return object["providers"] is [String: Any]
        case "urltest": return object["delay"] is NSNumber
        case "close": return object["closed"] is NSNumber
        case "proxyShareStart", "proxyShareStop", "proxyShareStatus":
            return object["ok"] as? Bool == true && object["status"] is [String: Any]
        case "runtimeDiagnostics", "reloadRuntimeSetupOptions", "exerciseSleepWake":
            return object["goroutines"] is NSNumber
        case "consumeOOMEvidence":
            return object["schemaVersion"] is NSNumber && object["pressureLevel"] is String
                && object["possibleSystemKill"] as? Bool == true
        case "reloadStatus":
            return object["session"] is String && object["state"] is String
        default:
             
             
            return false
        }
    }
}

 
 
final class HakoTVIPCGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var valid: Bool
    init(active: Bool = true) { valid = active }
    var isValid: Bool { lock.lock(); defer { lock.unlock() }; return valid }
    func invalidate() { lock.lock(); valid = false; lock.unlock() }
}

 
 
private final class HakoTVReadAdmission: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var admitted = false
    func cancel() {
        lock.lock(); defer { lock.unlock() }
        if !admitted { cancelled = true }
    }
    func admit() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { return false }
        admitted = true
        return true
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


enum HakoTVPollingPage: Equatable, Sendable {
    case home, nodes, outboundMode, connections, connectionDetail, diagnostics, configuration, providers

     
     
    func commands(tick: Int) -> [HakoTVPollingCommand] {
        var result: [HakoTVPollingCommand] = []
        if self == .home || self == .diagnostics { result.append(.traffic) }
        if tick % 3 == 0 {
            if self == .home || self == .nodes { result.append(.proxies) }
            if self == .home || self == .connections || self == .connectionDetail { result.append(.connections) }
            result.append(.status)
        }
        return result
    }
}

enum HakoTVPollingCommand: String, Equatable, Sendable {
    case traffic, proxies, connections, status
}

struct HakoTVPollingPresentation: Equatable, Sendable {
    let page: HakoTVPollingPage
    let active: Bool
}
