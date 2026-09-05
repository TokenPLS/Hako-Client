@preconcurrency import Hako
import Network
import NetworkExtension
import os.log

let appGroupID = HakoAppIdentifiers.appGroup



enum ExtensionError: LocalizedError {
    case appGroupUnavailable
    case configurationUnavailable
    case physicalPathUnavailable
    case serviceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "App Group container \(appGroupID) unavailable — check entitlements"
        case .configurationUnavailable:
            return "No client-staged config.yaml is available in the App Group"
        case .physicalPathUnavailable:
            return "No satisfied physical Wi-Fi, cellular, or wired path is available"
        case let .serviceUnavailable(reason):
            return "Hako service unavailable: \(reason)"
        }
    }
}

private struct PhysicalPathEvent {
    let sequence: UInt64
    let unixTimeMilliseconds: Int64
    let interfaceName: String
    let interfaceType: String
    let interfaceIndex: UInt32
    let satisfied: Bool
    let expensive: Bool
    let constrained: Bool
    let supportsIPv4: Bool
    let supportsIPv6: Bool

    var jsonObject: [String: Any] {
        [
            "sequence": sequence,
            "unixTimeMilliseconds": unixTimeMilliseconds,
            "interfaceName": interfaceName,
            "interfaceType": interfaceType,
            "interfaceIndex": interfaceIndex,
            "satisfied": satisfied,
            "expensive": expensive,
            "constrained": constrained,
            "supportsIPv4": supportsIPv4,
            "supportsIPv6": supportsIPv6,
        ]
    }
}

final class ExtensionProvider: NSObject {
    private let tunnelProvider: NEPacketTunnelProvider
#if os(iOS) || os(macOS)
     
     
     
    lazy var widgetMailbox = WidgetMailboxService(
        provider: self,
        store: HakoWidgetMailboxStore(
            root: HakoAppIdentifiers.appGroupContainer ?? FileManager.default.temporaryDirectory
        )
    )
#endif
    private var service: HakoBoxService?
    private var networkSettings: NEPacketTunnelNetworkSettings?
    private var tunStrictRouteRequested = false
     
     
     
     
     
     
    private var preappliedTunnel: Task<Int32, Error>?
    private var preappliedDescriptor: PreappliedTunnelDescriptor?
    private var preappliedTunIntent = ""
    private var packetFlowBridge: PacketFlowBridge?
    private var packetFlowConfiguration: PacketFlowBridgeConfiguration = .default
    private let lifecycle = ProviderLifecycle()
    private let operationGate = ProviderOperationGate()
     
     
     
    private let tunnelSessionLease = ProviderTunnelSessionLease()
    private let reloadEnvelope = ProviderReloadEnvelope()


    private let log = Logger(subsystem: "org.example.hako.demo.extension", category: "core")

     
     
     
     
    private let physicalPathMonitorFactory: () -> any PhysicalPathMonitoring
    private let physicalPathMonitorSession = PhysicalPathMonitorSession()
    private let pathQueueKey = DispatchSpecificKey<Void>()
    private lazy var pathQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "org.example.hako.pathmonitor")
        queue.setSpecific(key: pathQueueKey, value: ())
        return queue
    }()
    private let pathLock = NSLock()
     
     
     
     
    private let stateLock = NSLock()
    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }
    private var currentService: HakoBoxService? { withStateLock { service } }
    private var currentPacketFlowBridge: PacketFlowBridge? { withStateLock { packetFlowBridge } }
    private var defaultInterfaceIndex: UInt32 = 0
    private var defaultInterfaceName = ""
    private var defaultInterfaceType = ""
    private var defaultPathIsSatisfied = false
    private var defaultPathIsExpensive = false
    private var defaultPathIsConstrained = false
    private var defaultPathSupportsIPv4 = false
    private var defaultPathSupportsIPv6 = false
    private var physicalPathUpdateCount: UInt64 = 0
    private var physicalPathHistory: [PhysicalPathEvent] = []
    private var providerSleepCount: UInt64 = 0
    private var providerWakeCount: UInt64 = 0
     
    private var interfaceListener: (any HakoInterfaceUpdateListenerProtocol)?

    init(
        tunnelProvider: NEPacketTunnelProvider,
        physicalPathMonitorFactory: @escaping () -> any PhysicalPathMonitoring =
            ExtensionProvider.makeDefaultPhysicalPathMonitor
    ) {
        self.tunnelProvider = tunnelProvider
        self.physicalPathMonitorFactory = physicalPathMonitorFactory
        super.init()
    }

    static func makeDefaultPhysicalPathMonitor() -> any PhysicalPathMonitoring {

        ApplePhysicalPathMonitor()

    }

    private func startPathMonitor() -> PhysicalPathStartupGate.Generation {
        let monitor = physicalPathMonitorFactory()
        pathLock.lock()
        defaultInterfaceIndex = 0
        defaultInterfaceName = ""
        defaultInterfaceType = ""
        defaultPathIsSatisfied = false
        defaultPathIsExpensive = false
        defaultPathIsConstrained = false
        physicalPathUpdateCount = 0
        physicalPathHistory.removeAll(keepingCapacity: true)
        providerSleepCount = 0
        providerWakeCount = 0
        pathLock.unlock()


        return physicalPathMonitorSession.start(
            monitor: monitor,
            queue: pathQueue
        ) { [weak self] snapshot in
            guard let self else { return }
            pathLock.lock()
            defaultInterfaceIndex = snapshot.interfaceIndex
            defaultInterfaceName = snapshot.interfaceName
            defaultInterfaceType = snapshot.interfaceType
            defaultPathIsSatisfied = snapshot.isReady
            defaultPathIsExpensive = snapshot.expensive
            defaultPathIsConstrained = snapshot.constrained
            defaultPathSupportsIPv4 = snapshot.supportsIPv4
            defaultPathSupportsIPv6 = snapshot.supportsIPv6
            physicalPathUpdateCount &+= 1
            physicalPathHistory.append(PhysicalPathEvent(
                sequence: physicalPathUpdateCount,
                unixTimeMilliseconds: Int64(Date().timeIntervalSince1970 * 1_000),
                interfaceName: snapshot.interfaceName,
                interfaceType: snapshot.interfaceType,
                interfaceIndex: snapshot.interfaceIndex,
                satisfied: snapshot.isReady,
                expensive: snapshot.expensive,
                constrained: snapshot.constrained,
                supportsIPv4: snapshot.supportsIPv4,
                supportsIPv6: snapshot.supportsIPv6
            ))
            if physicalPathHistory.count > 32 {
                physicalPathHistory.removeFirst(physicalPathHistory.count - 32)
            }
            let listener = interfaceListener
            pathLock.unlock()
#if os(iOS) || os(macOS)
             
            widgetMailbox.pathChanged(interfaceType: snapshot.interfaceType)
#endif
            log.info("path update: default egress \(snapshot.interfaceName.isEmpty ? "none" : snapshot.interfaceName, privacy: .private) index=\(snapshot.interfaceIndex, privacy: .private)")
             
             
            listener?.updateDefaultInterface(
                snapshot.interfaceName,
                interfaceIndex: Int32(bitPattern: snapshot.interfaceIndex),
                isExpensive: snapshot.expensive,
                isConstrained: snapshot.constrained,
                supportsIPv4: snapshot.supportsIPv4,
                supportsIPv6: snapshot.supportsIPv6
            )
        }
    }

    private func stopPathMonitor() {
        physicalPathMonitorSession.stop()
         
         
         
        if DispatchQueue.getSpecific(key: pathQueueKey) == nil {
            pathQueue.sync {}
        }
        pathLock.lock()
        interfaceListener = nil
        defaultInterfaceIndex = 0
        defaultInterfaceName = ""
        defaultInterfaceType = ""
        defaultPathSupportsIPv4 = false
        defaultPathSupportsIPv6 = false
        defaultPathIsSatisfied = false
        defaultPathIsExpensive = false
        defaultPathIsConstrained = false
        pathLock.unlock()
    }

    private func currentInterfaceIndex() -> UInt32 {
        pathLock.lock(); defer { pathLock.unlock() }
        return defaultInterfaceIndex
    }

    private func waitForPhysicalPath(
        _ generation: PhysicalPathStartupGate.Generation,
        timeoutSeconds: Double = 10
    ) async throws {
        do {
            try await physicalPathMonitorSession.wait(
                for: generation,
                timeoutNanoseconds: UInt64(max(0, timeoutSeconds) * 1_000_000_000)
            )
        } catch PhysicalPathStartupGateError.timedOut {
            throw ExtensionError.physicalPathUnavailable
        } catch PhysicalPathStartupGateError.superseded {
            throw CancellationError()
        }
    }

    func start() async throws {
        await operationGate.enter()
        do {
            try lifecycle.beginStart()
            try await start0()
            try lifecycle.didStart()
            StartupMemorySampler.shared.mark("tunnel-up")
            await operationGate.leave()
        } catch {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            let reason = String(describing: error)
            log.error("tunnel start failed: \(reason, privacy: .public)")
            HakoLogStore.shared.append(
                "tunnel start failed: \(reason)",
                stream: .app,
                level: .error
            )
            await teardownResources(policy: .failedStart)
            lifecycle.didFailStart()
            await operationGate.leave()
            throw error
        }
    }

    private func start0() async throws {
         
         
         
         
         
        guard let container = HakoAppIdentifiers.appGroupContainer
        else {
            throw ExtensionError.appGroupUnavailable
        }

         
         
        StartupMemorySampler.shared.begin(container: container)

         
         
         
         
         
         
        let gateStartedAt = DispatchTime.now().uptimeNanoseconds
        let pathGeneration = startPathMonitor()
        StartupMemorySampler.shared.mark("path-monitor-started")

         
         
         
         
         
         
         
         
         
         
         
        preapplyTunnelSettingsIfKnown(container: container)

        let options = HakoSetupOptions()
        StartupMemorySampler.shared.mark("options-allocated")
        options.basePath = container.path
        options.workingPath = container.appendingPathComponent("working").path
        options.tempPath = container.appendingPathComponent("temp").path
         
         
         
         
         
         
        options.startupPhaseLogPath = container.appendingPathComponent(
            MemorySampleLog.startupPhaseFileName
        ).path
        options.timeZone = TimeZone.current.identifier  
        options.logMaxLines = 1000
         
         
         
        ApplePacketTunnelRuntimePolicy.current.apply(to: options)
         
         
         
         
         
         
         
         
        if let store = CertificateStorePolicy.setupValue(
            forStored: UserDefaults(suiteName: appGroupID)?
                .string(forKey: CertificateStorePolicy.defaultsKey)
        ) {
            options.certificateStore = store
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
        let allowLanPermitted = LocalNetworkPermission.isPermitted(
            UserDefaults(suiteName: appGroupID)
        )
        HakoSetAllowLanPermitted(allowLanPermitted)
         
         
         
         
         
         
         
         
         
        HakoLogStore.shared.append(
            "allow-lan permitted=\(allowLanPermitted)",
            stream: .app,
            level: .warning
        )
         
         
         
         
        StartupMemorySampler.shared.mark("cert-store-read")
        packetFlowConfiguration = .default



         
         
         
         
         
         
         
         
         
         
         
         
#if os(tvOS)
         
         
        let includeAllNetworks = false
#else
        let includeAllNetworks = (tunnelProvider.protocolConfiguration
            as? NETunnelProviderProtocol)?.includeAllNetworks ?? false
#endif
        options.includeAllNetworks = includeAllNetworks
        log.info("include all networks=\(includeAllNetworks)")
        StartupMemorySampler.shared.mark("options-built")
        var error: NSError?
        HakoSetup(options, &error)
        if let error { throw error }
        StartupMemorySampler.shared.mark("setup-done")
         
         
        StartupMemorySampler.shared.note(HakoLogStore.shared.composition())

         
         
         
         
         
         
         
         
         
         
         
         
         
         
        let collectionOptions = HakoRuntimeSetupOptions()
        collectionOptions.gcPercent = 10
        var collectionError: NSError?
        HakoReloadSetupOptions(collectionOptions, &collectionError)
        if let collectionError {
             
             
             
            HakoLogStore.shared.append(
                "gc percent not applied: " + collectionError.localizedDescription,
                stream: .app,
                level: .warning
            )
        }



        guard let service = HakoNewService(self, &error) else {
            throw error ?? ExtensionError.serviceUnavailable("NewService returned nil")
        }
        StartupMemorySampler.shared.mark("service-created")
        withStateLock { self.service = service }
         
         
         
         
        let storedConfiguration: StoredConfiguration?
        do {
            storedConfiguration = try stagedConfig()
        } catch ConfigResourceStoreError.noValidConfiguration {
            storedConfiguration = nil
        }
        let yaml: String
        if let storedConfiguration,
           let storedText = storedConfiguration.text {
            yaml = storedText
        } else {

            throw ExtensionError.configurationUnavailable

        }
         
         
         
         
        StartupMemorySampler.shared.note(
            "config bytes=\(yaml.utf8.count) revision=\(storedConfiguration?.revision ?? "none")"
        )
        StartupMemorySampler.shared.mark("config-read")
        try await waitForPhysicalPath(pathGeneration)
        let gateElapsedMilliseconds =
            (DispatchTime.now().uptimeNanoseconds - gateStartedAt) / 1_000_000
        log.info("physical path gate ready after \(gateElapsedMilliseconds, privacy: .public) ms; Core start permitted")
        StartupMemorySampler.shared.mark("path-gate-ready")
         
         
         
         
        StartupMemorySampler.shared.mark("pre-core-start")
        try service.start(yaml)
        StartupMemorySampler.shared.mark("core-started")
         
         
         
         
         
        var intentError: NSError?
        if let box = HakoPlatformConfigIntentJSON(yaml, &intentError),
           let groupDefaults = UserDefaults(suiteName: appGroupID) {
            TunnelIntentStamp.write(box.value, to: groupDefaults)
        }
        if let storedConfiguration,
           storedConfiguration.revision != "legacy-unversioned" {
             
             
             
             
             
            let container = container
            Task.detached(priority: .utility) { [log] in
                do {
                    let store = try ConfigResourceStore(containerURL: container)
                    if storedConfiguration.recoveredFromLastKnownGood {
                         
                         
                         
                         
                         
                        log.info("configuration store started last-known-good fallback")
                    } else {
                        try store.markLastKnownGood(
                            profileID: storedConfiguration.profileID,
                            revision: storedConfiguration.revision
                        )
                    }
                } catch {
                     
                     
                     
                    log.error("configuration store could not mark startup success: \(error.localizedDescription, privacy: .private)")
                }
                StartupMemorySampler.shared.mark("lkg-marked")
            }
        }
        log.info("hako core \(HakoVersion(), privacy: .public) status=\(service.status(), privacy: .public) tz=\(HakoTZProbe(), privacy: .private)")
        HakoLogStore.shared.append(
            "tunnel started  core=\(HakoVersion()) status=\(service.status())",
            stream: .app
        )
    }

    private func stagedConfig() throws -> StoredConfiguration {
        guard let container = HakoAppIdentifiers.appGroupContainer
        else { throw ExtensionError.appGroupUnavailable }
        return try ConfigResourceStore(containerURL: container).loadCurrent()
    }

    func stop(reason: NEProviderStopReason) async {
        await operationGate.enter()
        guard lifecycle.beginStop() else {
            await operationGate.leave()
            return
        }
         
         
         
         
         
         
         
         
         
         
         
         
        let summary = hakoStopReasonSummary(reason)
        log.info("stopping packet tunnel, \(summary, privacy: .public)")
        HakoLogStore.shared.append(
            "tunnel stopping  \(summary)",
            stream: .app,
            level: .warning
        )
        HakoLogStore.shared.flush()
        await teardownResources(policy: .systemStop)
        lifecycle.didStop()
        await operationGate.leave()
    }

    private func teardownResources(policy: ProviderTeardownPolicy) async {
         
         
         
         
        stopPathMonitor()
         
         
         
        tunnelSessionLease.invalidate()
         
         
         
        let (svc, bridge, hadNetworkSettings) = withStateLock {
            () -> (HakoBoxService?, PacketFlowBridge?, Bool) in
            let s = service
            let b = packetFlowBridge
            let had = networkSettings != nil
            service = nil
            packetFlowBridge = nil
            networkSettings = nil
            tunStrictRouteRequested = false
            return (s, b, had)
        }
        if let svc {
            do {
                try svc.close()
            } catch {
                log.error("service close failed: \(error.localizedDescription, privacy: .private)")
                HakoLogStore.shared.append(
                    "service close failed  \(error.localizedDescription)",
                    stream: .app,
                    level: .error
                )
            }
        }
        bridge?.stop()
        if policy.clearsNetworkSettings, hadNetworkSettings {
            do {
                try await tunnelProvider.setTunnelNetworkSettings(nil)
            } catch {
                log.error("clear tunnel settings failed: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    func sleep() {
        pathLock.lock()
        providerSleepCount &+= 1
        let count = providerSleepCount
        pathLock.unlock()
        currentService?.pause()
         
         
        HakoLogStore.shared.append("provider sleep  n=\(count)", stream: .app)
        HakoLogStore.shared.flush()
    }

    func wake() {
        pathLock.lock()
        providerWakeCount &+= 1
        let count = providerWakeCount
        pathLock.unlock()
        currentService?.wake()
        HakoLogStore.shared.append("provider wake  n=\(count)", stream: .app)
    }

     
     
     
    private final class MessageFollowUp {
        var run: (() -> Void)?
    }

     
     
     
     
     
     
     
    func handleMessage(_ data: Data) async -> (reply: Data, afterReply: (() -> Void)?) {
        let followUp = MessageFollowUp()
        let reply = await respond(to: data, followUp: followUp)
        return (reply, followUp.run)
    }

    private func respond(to data: Data, followUp: MessageFollowUp) async -> Data {
        guard let req = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cmd = req["cmd"] as? String
        else {
            return jsonError("bad request")
        }
        switch cmd {
        case "hello":
            return jsonObject([
                "schemaVersion": HakoCommandSchemaVersion,
                "minSchemaVersion": HakoCommandSchemaMinVersion,
                "coreVersion": HakoVersion(),
                "capabilities": ["stun-v1", ProviderReloadEnvelope.capability]
            ])
        case "runtimeDiagnostics":
            guard let service = currentService else { return jsonError("service not running") }
            return runtimeDiagnosticsData(service)
        case "consumeGoCrashReport":
             
             
             
             
            var crashError: NSError?
            guard let report = HakoConsumeGoCrashReport(&crashError) else {
                return jsonError(
                    crashError?.localizedDescription ?? "no Go crash report"
                )
            }
            return Data(report.value.utf8)
        case "consumeOOMEvidence":
            var consumeError: NSError?
            guard let evidence = HakoConsumeOOMEvidence(&consumeError) else {
                return jsonError(consumeError?.localizedDescription ?? "OOM evidence unavailable")
            }
            return Data(evidence.value.utf8)
        case "reload":
             
             
             
             
             
             
             
             
             
             
             
             
            guard let service = currentService else { return jsonError("service not running") }
            do {
                guard let yaml = try stagedConfig().text else {
                    return jsonError("staged config is not UTF-8")
                }
                let reply = reloadEnvelope.reply(to: req) { try service.reload(yaml) }
                followUp.run = reply.start
                return jsonObject(reply.object)
            } catch {
                return jsonError(error.localizedDescription)
            }
        case "reloadStatus":
             
             
             
             
             
            return jsonObject(reloadEnvelope.statusReply(to: req))


        case "status": return Data(HakoStatusJSON().utf8)
        case "traffic": return Data(HakoTrafficJSON().utf8)
        case "connections": return Data(HakoConnectionsJSON().utf8)
        case "proxies": return Data(HakoProxiesJSON().utf8)
        case "logs": return Data(HakoRecentLogsJSON().utf8)
        case "setMode":
            guard let mode = req["mode"] as? String else { return jsonError("missing mode") }
            do { try currentService?.setMode(mode); return okJSON() } catch { return jsonError(error.localizedDescription) }
        case "select":
            guard let group = req["group"] as? String, let name = req["name"] as? String
            else { return jsonError("missing group/name") }
            var selectErr: NSError?
            HakoSelectProxy(group, name, &selectErr)
            if let selectErr { return jsonError(selectErr.localizedDescription) }
            return okJSON()
        case "urltest":
            guard let name = req["name"] as? String else { return jsonError("missing name") }
            let delay = HakoURLTest(name, req["url"] as? String ?? "")
            return Data("{\"delay\":\(delay)}".utf8)
        case "close":
            guard let id = req["id"] as? String else { return jsonError("missing id") }
            return Data("{\"closed\":\(HakoCloseConnection(id))}".utf8)
        case "closeAll":
            HakoCloseAllConnections(); return okJSON()
         
         
         
         
         
         
         
         
         
        case "proxyShareStart":
            guard let service = currentService else { return jsonError("service not running") }
            guard let requested = req["port"] as? NSNumber else { return jsonError("missing port") }
             
             
             
             
             
            guard let port = Int32(exactly: requested.doubleValue) else { return jsonError("port must be a whole number") }
            do {
                try service.startProxyShare(port, username: req["username"] as? String ?? "", password: req["password"] as? String ?? "")
                return proxyShareStatusReply(service)
            } catch {
                return jsonError(error.localizedDescription)
            }
        case "proxyShareStop":
            guard let service = currentService else { return jsonError("service not running") }
            do {
                try service.stopProxyShare()
                return proxyShareStatusReply(service)
            } catch {
                return jsonError(error.localizedDescription)
            }
        case "proxyShareStatus":
            guard let service = currentService else { return jsonError("service not running") }
            return proxyShareStatusReply(service)
        default:
            return jsonError("unknown cmd \(cmd)")
        }
    }

    private func okJSON() -> Data { Data("{\"ok\":true}".utf8) }
    private func jsonObject(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? jsonError("encode response")
    }
    private func jsonError(_ msg: String) -> Data {
        Data((try? JSONSerialization.data(withJSONObject: ["error": msg])) ?? Data("{\"error\":\"?\"}".utf8))
    }

     
     
     
     
    private func proxyShareStatusReply(_ service: HakoBoxService) -> Data {
        guard let data = service.proxyShareStatusJSON().data(using: .utf8),
              let status = try? JSONSerialization.jsonObject(with: data)
        else { return jsonError("proxy share status is not JSON") }
        return jsonObject(["ok": true, "status": status])
    }

    private func runtimeDiagnosticsData(_ service: HakoBoxService) -> Data {
        guard let data = service.runtimeDiagnosticsJSON().data(using: .utf8),
              var diagnostics = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return jsonError("invalid core diagnostics") }
        let (strictRoute, settingsSnapshot) = withStateLock { (tunStrictRouteRequested, networkSettings) }
         
         
         
         
         
        diagnostics["extensionMemoryFootprintBytes"] = HakoMemoryFootprint()
        diagnostics["lowMemoryBuild"] = HakoLowMemoryBuild()
        diagnostics["tunStrictRouteRequested"] = strictRoute
        diagnostics["appleIPv4IncludedRouteCount"] = settingsSnapshot?.ipv4Settings?.includedRoutes?.count ?? 0
        diagnostics["appleIPv4ExcludedRouteCount"] = settingsSnapshot?.ipv4Settings?.excludedRoutes?.count ?? 0
        diagnostics["appleIPv6IncludedRouteCount"] = settingsSnapshot?.ipv6Settings?.includedRoutes?.count ?? 0
        diagnostics["appleIPv6ExcludedRouteCount"] = settingsSnapshot?.ipv6Settings?.excludedRoutes?.count ?? 0
        diagnostics["appleMTU"] = settingsSnapshot?.mtu?.intValue ?? 0
        pathLock.lock()
        diagnostics["applePhysicalInterfaceName"] = defaultInterfaceName
        diagnostics["applePhysicalInterfaceType"] = defaultInterfaceType
        diagnostics["applePhysicalInterfaceIndex"] = defaultInterfaceIndex
        diagnostics["applePhysicalPathSatisfied"] = defaultPathIsSatisfied
        diagnostics["applePhysicalPathExpensive"] = defaultPathIsExpensive
        diagnostics["applePhysicalPathConstrained"] = defaultPathIsConstrained
        diagnostics["applePhysicalPathSupportsIPv4"] = defaultPathSupportsIPv4
        diagnostics["applePhysicalPathSupportsIPv6"] = defaultPathSupportsIPv6
        diagnostics["applePhysicalPathUpdateCount"] = physicalPathUpdateCount
        diagnostics["applePhysicalPathHistory"] = physicalPathHistory.map(\.jsonObject)
        diagnostics["appleProviderSleepCount"] = providerSleepCount
        diagnostics["appleProviderWakeCount"] = providerWakeCount
        pathLock.unlock()
        if let bridge = currentPacketFlowBridge?.snapshot() {
            diagnostics["packetFlowReadCallbackBatches"] = bridge.readCallbackBatches
            diagnostics["packetFlowPacketsFromSystem"] = bridge.packetsFromSystem
            diagnostics["packetFlowBytesFromSystem"] = bridge.bytesFromSystem
            diagnostics["packetFlowPacketsToCore"] = bridge.packetsToCore
            diagnostics["packetFlowBytesToCore"] = bridge.bytesToCore
            diagnostics["packetFlowSendSyscallCount"] = bridge.sendSyscallCount
            diagnostics["packetFlowSendWouldBlockCount"] = bridge.sendWouldBlockCount
            diagnostics["packetFlowSendENOBUFSCount"] = bridge.sendENOBUFSCount
            diagnostics["packetFlowSendENOMEMCount"] = bridge.sendENOMEMCount
            diagnostics["packetFlowReceiveWouldBlockCount"] = bridge.receiveWouldBlockCount
            diagnostics["packetFlowReceiveENOBUFSCount"] = bridge.receiveENOBUFSCount
            diagnostics["packetFlowReceiveENOMEMCount"] = bridge.receiveENOMEMCount
            diagnostics["packetFlowSendBackoffCount"] = bridge.sendBackoffCount
            diagnostics["packetFlowSendAccumulatedBackoffNanoseconds"] = bridge.sendAccumulatedBackoffNanoseconds
            diagnostics["packetFlowReceiveBackoffCount"] = bridge.receiveBackoffCount
            diagnostics["packetFlowReceiveAccumulatedBackoffNanoseconds"] = bridge.receiveAccumulatedBackoffNanoseconds
            diagnostics["packetFlowPacketsToSystem"] = bridge.packetsToSystem
            diagnostics["packetFlowDroppedToCore"] = bridge.droppedToCore
            diagnostics["packetFlowDroppedToSystem"] = bridge.droppedToSystem
            diagnostics["packetFlowPendingPackets"] = bridge.pendingPackets
            diagnostics["packetFlowPendingBytes"] = bridge.pendingBytes
            diagnostics["packetFlowPeakPendingPackets"] = bridge.peakPendingPackets
            diagnostics["packetFlowPeakPendingBytes"] = bridge.peakPendingBytes
            diagnostics["packetFlowQueueLatencySamples"] = bridge.queueLatencySamples
            diagnostics["packetFlowAverageQueueLatencyNanoseconds"] = bridge.averageQueueLatencyNanoseconds
            diagnostics["packetFlowMaxQueueLatencyNanoseconds"] = bridge.maxQueueLatencyNanoseconds
            diagnostics["packetFlowSystemWriteCalls"] = bridge.systemWriteCalls
            diagnostics["packetFlowMaxSystemWriteBatch"] = bridge.maxSystemWriteBatch
            diagnostics["packetFlowConfiguredMaxDrainBatch"] = bridge.configuredMaxDrainBatch
            diagnostics["packetFlowCoreToSystemFlushNanoseconds"] = bridge.coreToSystemFlushNanoseconds
            diagnostics["packetFlowSocketBufferRequestedBytes"] = bridge.socketBufferRequestedBytes
            diagnostics["packetFlowFlowEndpointSendBufferBytes"] = bridge.flowEndpointSendBufferBytes
            diagnostics["packetFlowFlowEndpointReceiveBufferBytes"] = bridge.flowEndpointReceiveBufferBytes
            diagnostics["packetFlowCoreEndpointSendBufferBytes"] = bridge.coreEndpointSendBufferBytes
            diagnostics["packetFlowCoreEndpointReceiveBufferBytes"] = bridge.coreEndpointReceiveBufferBytes
            diagnostics["packetFlowFlowEndpointSendBufferSetErrno"] = bridge.flowEndpointSendBufferSetErrno
            diagnostics["packetFlowFlowEndpointReceiveBufferSetErrno"] = bridge.flowEndpointReceiveBufferSetErrno
            diagnostics["packetFlowCoreEndpointSendBufferSetErrno"] = bridge.coreEndpointSendBufferSetErrno
            diagnostics["packetFlowCoreEndpointReceiveBufferSetErrno"] = bridge.coreEndpointReceiveBufferSetErrno
            diagnostics["packetFlowFlowEndpointSendBufferGetErrno"] = bridge.flowEndpointSendBufferGetErrno
            diagnostics["packetFlowFlowEndpointReceiveBufferGetErrno"] = bridge.flowEndpointReceiveBufferGetErrno
            diagnostics["packetFlowCoreEndpointSendBufferGetErrno"] = bridge.coreEndpointSendBufferGetErrno
            diagnostics["packetFlowCoreEndpointReceiveBufferGetErrno"] = bridge.coreEndpointReceiveBufferGetErrno
        }
        return jsonObject(diagnostics)
    }

    private func writeRestartEvidence(
        requested: Int,
        completed: Int,
        processIdentifiers: [Int32],
        goroutineCounts: [Int],
        error: String
    ) {
        guard let container = HakoAppIdentifiers.appGroupContainer,
              let data = try? JSONSerialization.data(withJSONObject: [
                "requested": requested,
                "completed": completed,
                "processIdentifiers": processIdentifiers,
                "goroutineCounts": goroutineCounts,
                "error": error
              ], options: [.sortedKeys])
        else { return }
        try? data.write(
            to: container.appendingPathComponent("provider-restart-evidence.json"),
            options: .atomic
        )
    }


}

 
 
extension ExtensionProvider: HakoPlatformInterfaceProtocol {
    func writeLog(_ message: String?) {
        guard let message else { return }
        log.info("[core] \(message, privacy: .private)")
         
         
         
        HakoLogStore.shared.append(message, stream: .core)
    }

     
     
     
    func openTun(_ options: (any HakoTunOptionsProtocol)?, ret0_: UnsafeMutablePointer<Int32>?) throws {
        guard let options else {
            throw ExtensionError.serviceUnavailable("OpenTun: nil options")
        }
        guard let ret0_ else {
            throw ExtensionError.serviceUnavailable("OpenTun: nil return pointer")
        }
         
         
         
        let session = tunnelSessionLease.begin()
        let fd: Int32
        do {
            fd = try runBlocking { [self] in
                try await openTun0(options, session: session)
            }
        } catch {
            tunnelSessionLease.invalidate()
            throw error
        }
        ret0_.pointee = fd
    }

    private func openTun0(
        _ options: any HakoTunOptionsProtocol,
        session: ProviderTunnelSessionLease.Session
    ) async throws -> Int32 {
        StartupMemorySampler.shared.note("tun: open-entered")
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let effectiveMTU = options.getMTU()
        guard (1_280...9_000).contains(Int(effectiveMTU)) else {
            throw ExtensionError.serviceUnavailable(
                "OpenTun: Core returned invalid MTU \(effectiveMTU); expected 1280...9000"
            )
        }
         
         
         
         
         
        settings.mtu = NSNumber(value: effectiveMTU)
        settings.tunnelOverheadBytes = nil

         
         
         
         
        var dnsSettings: NEDNSSettings?
        let dnsBox = try options.getDNSServerAddress()
        guard !dnsBox.value.isEmpty else {
            throw ExtensionError.serviceUnavailable("OpenTun: DNS takeover address unavailable")
        }
        let s = NEDNSSettings(servers: [dnsBox.value])
        settings.dnsSettings = s
        dnsSettings = s

         
        var v4Addr: [String] = [], v4Mask: [String] = []
        guard let v4It = options.getInet4Address() else {
            throw ExtensionError.serviceUnavailable("OpenTun: nil Inet4Address iterator")
        }
        while v4It.hasNext() {
            guard let p = v4It.next() else { break }
            v4Addr.append(p.address()); v4Mask.append(p.mask())
        }
         
         
        let routeSwitches = HakoTunnelRouteShaping.Switches.read(
            from: UserDefaults(suiteName: appGroupID)
        )
        let splitTable = HakoTunnelRouteShaping.usesSplitTable(
            strictRoute: options.getStrictRoute(), switches: routeSwitches
        )
        HakoLogStore.shared.append(
            "route shaping: hideVPNIcon=\(routeSwitches.hideVPNIcon) homeKitCompatibility=\(routeSwitches.homeKitCompatibility) splitTable=\(splitTable)",
            stream: .app
        )
        if !v4Addr.isEmpty {
            guard let includedIt = options.getInet4RouteAddress(),
                  let excludedIt = options.getInet4RouteExcludeAddress() else {
                throw ExtensionError.serviceUnavailable("OpenTun: nil Inet4 route iterator")
            }
            let v4 = NEIPv4Settings(addresses: v4Addr, subnetMasks: v4Mask)
            let included = collectV4Routes(includedIt)
            let effective = included.isEmpty ? defaultV4Routes(strict: splitTable) : included
            v4.includedRoutes = effective
            v4.excludedRoutes = HakoTunnelRouteShaping.v4Excluded(
                collectV4Routes(excludedIt).map { .init(address: $0.destinationAddress, mask: $0.destinationSubnetMask) },
                includedIsEmpty: effective.isEmpty,
                switches: routeSwitches
            ).map { NEIPv4Route(destinationAddress: $0.address, subnetMask: $0.mask) }
            settings.ipv4Settings = v4
        }

         
        var v6Addr: [String] = [], v6Prefix: [NSNumber] = []
        guard let v6It = options.getInet6Address() else {
            throw ExtensionError.serviceUnavailable("OpenTun: nil Inet6Address iterator")
        }
        while v6It.hasNext() {
            guard let p = v6It.next() else { break }
            v6Addr.append(p.address()); v6Prefix.append(NSNumber(value: p.prefix()))
        }
        if !v6Addr.isEmpty {
            guard let includedIt = options.getInet6RouteAddress(),
                  let excludedIt = options.getInet6RouteExcludeAddress() else {
                throw ExtensionError.serviceUnavailable("OpenTun: nil Inet6 route iterator")
            }
            let v6 = NEIPv6Settings(addresses: v6Addr, networkPrefixLengths: v6Prefix)
            let included = collectV6Routes(includedIt)
            let effective = included.isEmpty ? defaultV6Routes(strict: splitTable) : included
            v6.includedRoutes = effective
            v6.excludedRoutes = HakoTunnelRouteShaping.v6Excluded(
                collectV6Routes(excludedIt).map { .init(address: $0.destinationAddress, prefix: $0.destinationNetworkPrefixLength.intValue) },
                includedIsEmpty: effective.isEmpty,
                switches: routeSwitches
            ).map { NEIPv6Route(destinationAddress: $0.address, networkPrefixLength: NSNumber(value: $0.prefix)) }
            settings.ipv6Settings = v6
        }

         
         
         
        dnsSettings?.matchDomains = [""]
        dnsSettings?.matchDomainsNoSearch = true
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            dnsSettings?.allowFailover = false
        }

        let strictRoute = options.getStrictRoute()
         
         
        let requested = PreappliedTunnelDescriptor(
            mtu: Int(effectiveMTU),
            dnsServerAddress: dnsBox.value,
            inet4Addresses: zip(v4Addr, v4Mask).map { "\($0)/\($1)" },
            inet6Addresses: zip(v6Addr, v6Prefix).map { "\($0)/\($1.intValue)" },
            inet4IncludedRoutes: (settings.ipv4Settings?.includedRoutes ?? [])
                .map { "\($0.destinationAddress)/\($0.destinationSubnetMask)" },
            inet4ExcludedRoutes: (settings.ipv4Settings?.excludedRoutes ?? [])
                .map { "\($0.destinationAddress)/\($0.destinationSubnetMask)" },
            inet6IncludedRoutes: (settings.ipv6Settings?.includedRoutes ?? [])
                .map { "\($0.destinationAddress)/\($0.destinationNetworkPrefixLength)" },
            inet6ExcludedRoutes: (settings.ipv6Settings?.excludedRoutes ?? [])
                .map { "\($0.destinationAddress)/\($0.destinationNetworkPrefixLength)" },
            strictRoute: strictRoute
        )
         
         
         
        if let claimed = try await claimPreappliedTunnel(matching: requested) {
            StartupMemorySampler.shared.note("tun: pre-applied claimed")
            let published = tunnelSessionLease.commitIfCurrent(session) {
                HakoLogStore.shared.markTunnelEstablished()
            }
            guard published else {
                throw ExtensionError.serviceUnavailable(
                    "the tunnel session was superseded before it was established"
                )
            }
             
             
             
             
            HakoLogStore.shared.append(
                "tunnel opened from pre-applied settings  fd=\(claimed) bridge=none",
                stream: .app
            )
            return claimed
        }
        withStateLock {
            tunStrictRouteRequested = strictRoute
            networkSettings = settings
        }
         
         
         
        StartupMemorySampler.shared.note("tun: settings-built")
        try await tunnelProvider.setTunnelNetworkSettings(settings)
        StartupMemorySampler.shared.note("tun: settings-applied")


        currentPacketFlowBridge?.stop()
        let provider = tunnelProvider
        let bridge = PacketFlowBridge(
            packetFlow: provider.packetFlow,
            configuration: packetFlowConfiguration
        ) { [weak provider] error in
            provider?.cancelTunnelWithError(error)
        }
        let bridgeFD = try bridge.start()
         
         
         
         
         
         
         
         
         
         
        var rememberedKey = ""
        let published = tunnelSessionLease.commitIfCurrent(session) {
            HakoLogStore.shared.markTunnelEstablished()
            withStateLock { packetFlowBridge = bridge }
            rememberedKey = rememberPreapplied(requested)
        }
        guard published else {
             
             
             
            bridge.stop()
             
             
             
            HakoLogStore.shared.append(
                "packet bridge stopped  fd=\(bridgeFD) reason=session-superseded preapplied=not-remembered",
                stream: .app
            )
            await compensateLateTunnelSettings()
            throw ExtensionError.serviceUnavailable(
                "the tunnel session was superseded before it was established"
            )
        }
         
         
         
         
         
        let remembered = rememberedKey.isEmpty
            ? "preapplied=not-remembered(no-tun-intent)"
            : "preapplied-remembered-key=\(rememberedKey.prefix(12))"
        HakoLogStore.shared.append(
            "packet bridge started  fd=\(bridgeFD) \(remembered)",
            stream: .app
        )
        StartupMemorySampler.shared.note("tun: bridge-up")
        return bridgeFD
    }

     
     
     
     
     
     
     
     
     
    private func compensateLateTunnelSettings() async {
        var owed = false
        tunnelSessionLease.compensateIfIdle { owed = true }
        guard owed else { return }
         
         
         
         
        let owned = withStateLock { () -> Bool in
            guard networkSettings != nil else { return false }
            networkSettings = nil
            return true
        }
        guard owned else { return }
        do {
            try await tunnelProvider.setTunnelNetworkSettings(nil)
        } catch {
            log.error(
                "late tunnel settings not cleared: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

     
     
     
     
     
     
    private func preapplyTunnelSettingsIfKnown(container: URL) {


        guard let stored = try? ConfigResourceStore(containerURL: container).loadCurrent()
        else { return }
         
         
         
         
         
         
        let defaults = UserDefaults(suiteName: appGroupID)
        let fingerprint = PublishedTunIntent.current(defaults: defaults)
        guard !fingerprint.isEmpty else { return }
         
         
         
        withStateLock { preappliedTunIntent = fingerprint }
        let known = PreappliedTunnelStore(defaults: defaults)
            .descriptor(forTunIntent: fingerprint)
         
         
         
         
        StartupMemorySampler.shared.note(
            "tun: preapply key=\(fingerprint.prefix(12)) cached=\(known != nil)"
        )
        guard let known else { return }
        let provider = tunnelProvider
        let settings = Self.networkSettings(from: known)
        let task = Task<Int32, Error> { [weak self] in
            try await provider.setTunnelNetworkSettings(settings)
            guard let self else { throw ExtensionError.serviceUnavailable("provider went away") }


            self.currentPacketFlowBridge?.stop()
            let bridge = PacketFlowBridge(
                packetFlow: provider.packetFlow,
                configuration: self.packetFlowConfiguration
            ) { [weak provider] error in
                provider?.cancelTunnelWithError(error)
            }
            let fd = try bridge.start()
            self.withStateLock {
                self.packetFlowBridge = bridge
                self.networkSettings = settings
                self.tunStrictRouteRequested = known.strictRoute
            }
            return fd
        }
        withStateLock {
            preappliedTunnel = task
            preappliedDescriptor = known
        }
        StartupMemorySampler.shared.mark("tun-preapply-dispatched")
    }

     
     
     
    private static func networkSettings(
        from descriptor: PreappliedTunnelDescriptor
    ) -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = NSNumber(value: descriptor.mtu)
        settings.tunnelOverheadBytes = nil
        let dns = NEDNSSettings(servers: [descriptor.dnsServerAddress])
        dns.matchDomains = [""]
        dns.matchDomainsNoSearch = true
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            dns.allowFailover = false
        }
        settings.dnsSettings = dns

        let v4 = descriptor.inet4Addresses.compactMap(Self.splitPrefix)
        if !v4.isEmpty {
            let ipv4 = NEIPv4Settings(addresses: v4.map(\.0), subnetMasks: v4.map(\.1))
            ipv4.includedRoutes = descriptor.inet4IncludedRoutes
                .compactMap(Self.splitPrefix)
                .map { NEIPv4Route(destinationAddress: $0.0, subnetMask: $0.1) }
            ipv4.excludedRoutes = descriptor.inet4ExcludedRoutes
                .compactMap(Self.splitPrefix)
                .map { NEIPv4Route(destinationAddress: $0.0, subnetMask: $0.1) }
            settings.ipv4Settings = ipv4
        }
        let v6 = descriptor.inet6Addresses.compactMap(Self.splitPrefix)
        if !v6.isEmpty {
            let ipv6 = NEIPv6Settings(
                addresses: v6.map(\.0),
                networkPrefixLengths: v6.map { NSNumber(value: Int($0.1) ?? 128) }
            )
            ipv6.includedRoutes = descriptor.inet6IncludedRoutes
                .compactMap(Self.splitPrefix)
                .map {
                    NEIPv6Route(
                        destinationAddress: $0.0,
                        networkPrefixLength: NSNumber(value: Int($0.1) ?? 128)
                    )
                }
            ipv6.excludedRoutes = descriptor.inet6ExcludedRoutes
                .compactMap(Self.splitPrefix)
                .map {
                    NEIPv6Route(
                        destinationAddress: $0.0,
                        networkPrefixLength: NSNumber(value: Int($0.1) ?? 128)
                    )
                }
            settings.ipv6Settings = ipv6
        }
        return settings
    }

    private static func splitPrefix(_ value: String) -> (String, String)? {
        guard let slash = value.lastIndex(of: "/") else { return nil }
        return (String(value[value.startIndex..<slash]),
                String(value[value.index(after: slash)...]))
    }

     
     
     
     
    private func claimPreappliedTunnel(
        matching requested: PreappliedTunnelDescriptor
    ) async throws -> Int32? {
        let (task, applied) = withStateLock {
            (preappliedTunnel, preappliedDescriptor)
        }
        guard let task else { return nil }
        withStateLock {
            preappliedTunnel = nil
            preappliedDescriptor = nil
        }
        guard applied == requested else {
             
             
             
             
            _ = try? await task.value
            currentPacketFlowBridge?.stop()
            StartupMemorySampler.shared.note("tun: pre-applied discarded (settings changed)")
            return nil
        }
        do {
            return try await task.value
        } catch {
             
             
            StartupMemorySampler.shared.note("tun: pre-applied failed, applying normally")
            return nil
        }
    }

     
     
     
     
    @discardableResult
    private func rememberPreapplied(_ descriptor: PreappliedTunnelDescriptor) -> String {
        let fingerprint = withStateLock { preappliedTunIntent }
        PreappliedTunnelStore(defaults: UserDefaults(suiteName: appGroupID))
            .remember(descriptor, forTunIntent: fingerprint)
        return fingerprint
    }

     
     
     
    private func collectV4Routes(_ it: any HakoRoutePrefixIteratorProtocol) -> [NEIPv4Route] {
        var routes: [NEIPv4Route] = []
        while it.hasNext() {
            guard let p = it.next() else { break }
            routes.append(NEIPv4Route(destinationAddress: p.address(), subnetMask: p.mask()))
        }
        return routes
    }

    private func collectV6Routes(_ it: any HakoRoutePrefixIteratorProtocol) -> [NEIPv6Route] {
        var routes: [NEIPv6Route] = []
        while it.hasNext() {
            guard let p = it.next() else { break }
            routes.append(NEIPv6Route(destinationAddress: p.address(), networkPrefixLength: NSNumber(value: p.prefix())))
        }
        return routes
    }

     
     
     
     
     
    private func defaultV4Routes(strict: Bool) -> [NEIPv4Route] {
        guard strict else { return [NEIPv4Route.default()] }
        return HakoTunnelRouteShaping.v4SplitTable.map {
            NEIPv4Route(destinationAddress: $0.address, subnetMask: $0.mask)
        }
    }

    private func defaultV6Routes(strict: Bool) -> [NEIPv6Route] {
        guard strict else { return [NEIPv6Route.default()] }
        return HakoTunnelRouteShaping.v6SplitTable.map {
            NEIPv6Route(destinationAddress: $0.address, networkPrefixLength: NSNumber(value: $0.prefix))
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    private final class BlockingResultBox<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Result<T, Error>?
        private var abandoned = false

         
        func deliver(_ result: Result<T, Error>) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !abandoned else { return false }
            value = result
            return true
        }

        func abandon() {
            lock.lock()
            abandoned = true
            lock.unlock()
        }

        func take() -> Result<T, Error>? {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    private static var blockingOperationLimit: DispatchTime { .now() + .seconds(20) }

    private func runBlocking<T>(_ operation: @escaping () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = BlockingResultBox<T>()
        Task {
            let outcome: Result<T, Error>
            do { outcome = .success(try await operation()) }
            catch { outcome = .failure(error) }
            if box.deliver(outcome) { semaphore.signal() }
        }
        guard semaphore.wait(timeout: Self.blockingOperationLimit) == .success else {
            box.abandon()
            throw ExtensionError.serviceUnavailable(
                "the system did not finish applying the tunnel settings"
            )
        }
        guard let result = box.take() else {
            throw ExtensionError.serviceUnavailable(
                "the tunnel settings finished without a result"
            )
        }
        return try result.get()
    }

    func usePlatformAutoDetectControl() -> Bool {
        true  
    }

     
     
     
     
    func autoDetectControl(_ fd: Int32) throws {
        let idx = currentInterfaceIndex()
        guard idx != 0 else {
            throw ExtensionError.serviceUnavailable("physical path unavailable; refusing unscoped socket fd \(fd)")
        }
        var index = idx
        let v4 = setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &index, socklen_t(MemoryLayout<UInt32>.size))
        let v6 = setsockopt(fd, IPPROTO_IPV6, IPV6_BOUND_IF, &index, socklen_t(MemoryLayout<UInt32>.size))
         
         
        if v4 != 0, v6 != 0 {
            throw ExtensionError.serviceUnavailable("IP_BOUND_IF failed for fd \(fd) (errno \(errno))")
        }
    }

     
     
     
     
    func startDefaultInterfaceMonitor(_ listener: (any HakoInterfaceUpdateListenerProtocol)?) throws {
        guard let listener else { return }
        let publishInitialPath = { [self] in
            pathLock.lock()
            guard defaultPathIsSatisfied,
                  defaultInterfaceIndex != 0,
                  !defaultInterfaceName.isEmpty
            else {
                interfaceListener = nil
                pathLock.unlock()
                throw ExtensionError.physicalPathUnavailable
            }
            interfaceListener = listener
            let idx = defaultInterfaceIndex
            let name = defaultInterfaceName
            let isExpensive = defaultPathIsExpensive
            let isConstrained = defaultPathIsConstrained
            let supportsIPv4 = defaultPathSupportsIPv4
            let supportsIPv6 = defaultPathSupportsIPv6
            pathLock.unlock()
            listener.updateDefaultInterface(
                name,
                interfaceIndex: Int32(bitPattern: idx),
                isExpensive: isExpensive,
                isConstrained: isConstrained,
                supportsIPv4: supportsIPv4,
                supportsIPv6: supportsIPv6
            )
        }
        if DispatchQueue.getSpecific(key: pathQueueKey) != nil {
            try publishInitialPath()
        } else {
            try pathQueue.sync(execute: publishInitialPath)
        }
    }

    func closeDefaultInterfaceMonitor(_: (any HakoInterfaceUpdateListenerProtocol)?) throws {
        let detach = { [self] in
            pathLock.lock()
            interfaceListener = nil
            pathLock.unlock()
        }
        if DispatchQueue.getSpecific(key: pathQueueKey) != nil {
            detach()
        } else {
             
             
            pathQueue.sync(execute: detach)
        }
    }

    func getInterfaces() throws -> any HakoNetworkInterfaceIteratorProtocol {
        throw ExtensionError.serviceUnavailable("GetInterfaces not wired (unused: sing-tun monitor disabled)")
    }

    func underNetworkExtension() -> Bool {
        true
    }
}
