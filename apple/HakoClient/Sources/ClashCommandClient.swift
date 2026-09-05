import Combine
import Foundation
import HakoClientUI
import os
import Hako
import NetworkExtension

 
 
 
 
 
 
 
private final class CoreCallRace<Value>: @unchecked Sendable {
    enum Outcome {
        case result(Result<Value, Error>)
        case deadline
        case cancelled
    }

    private let lock = NSLock()
    private var continuation: CheckedContinuation<Outcome, Never>?
    private var pending: Outcome?
    private var resolved = false

    func wait() async -> Outcome {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let pending {
                self.pending = nil
                lock.unlock()
                continuation.resume(returning: pending)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }

    @discardableResult
    func resolve(_ outcome: Outcome) -> Bool {
        lock.lock()
        guard !resolved else {
            lock.unlock()
            return false
        }
        resolved = true
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(returning: outcome)
        } else {
            pending = outcome
            lock.unlock()
        }
        return true
    }
}

struct ClashTrafficSnapshot {
    var upload: Int64 = 0
    var download: Int64 = 0
    var uploadTotal: Int64 = 0
    var downloadTotal: Int64 = 0
     
     
    var uploadHistory: [Int64] = Array(repeating: 0, count: 30)
    var downloadHistory: [Int64] = Array(repeating: 0, count: 30)
}

struct ClashTrafficReducer {
    private(set) var snapshot = ClashTrafficSnapshot()

    mutating func consume(up: Int64, down: Int64, upTotal: Int64, downTotal: Int64) -> ClashTrafficSnapshot {
         
         
         
        let upload = max(up, 0)
        let download = max(down, 0)

        func appending(_ value: Int64, to samples: [Int64]) -> [Int64] {
            var next = samples
            next.append(value)
            if next.count > 30 { next.removeFirst(next.count - 30) }
            return next
        }
        snapshot = ClashTrafficSnapshot(
            upload: upload,
            download: download,
            uploadTotal: upTotal,
            downloadTotal: downTotal,
            uploadHistory: appending(upload, to: snapshot.uploadHistory),
            downloadHistory: appending(download, to: snapshot.downloadHistory)
        )
        return snapshot
    }
}

struct ClashURLTestOutcome: Sendable {
    let delay: Int
    let failureCategory: String

    var succeeded: Bool { delay > 0 }
}

struct OOMEvidenceConsumeTracker {
    private(set) var lastProviderKey: String?

    mutating func beginAttempt(processIdentifier: Int32, startTimeUnix: Int64) -> Bool {
        guard processIdentifier > 0, startTimeUnix > 0 else { return false }
        let key = "\(processIdentifier):\(startTimeUnix)"
        guard key != lastProviderKey else { return false }
        lastProviderKey = key
        return true
    }
}

struct RuntimeRouteContext: Equatable, Sendable {
    let profileID: String
    let profileRevision: String
    let coreProcessIdentifier: Int32
    let coreStartTimeUnix: Int64
    let mode: String

    fileprivate var generationKey: String {
        [
            profileID,
            profileRevision,
            String(coreProcessIdentifier),
            String(coreStartTimeUnix),
        ].joined(separator: "\u{001F}")
    }
}

struct RuntimeRouteEvidence: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case runtimeControlConnected = "runtime-control-connected"
        case runtimeCoreConfirmed = "runtime-core-confirmed"
        case runtimeControlDisconnected = "runtime-control-disconnected"
        case modeRequested = "mode-requested"
        case modeConfirmed = "mode-confirmed"
        case modeRejected = "mode-rejected"
        case selectionRequested = "selection-requested"
        case selectionConfirmed = "selection-confirmed"
        case selectionRejected = "selection-rejected"
        case trafficRouteObserved = "traffic-route-observed"
    }

    let schemaVersion: Int
    let kind: Kind
    let timestamp: Date
     
     
     
    let profilePointerID: String
    let profilePointerRevision: String
    let coreProcessIdentifier: Int32
    let coreStartTimeUnix: Int64
    let mode: String
    let connectionID: String
    let chains: [String]
    let rule: String
    let network: String
    let selectionGroup: String?
    let requestedMember: String?
    let confirmedMember: String?
    let resolvedMember: String?
    let failureCategory: String?

    init(
        kind: Kind,
        timestamp: Date = Date(),
        profilePointerID: String,
        profilePointerRevision: String,
        coreProcessIdentifier: Int32,
        coreStartTimeUnix: Int64,
        mode: String,
        connectionID: String = "",
        chains: [String] = [],
        rule: String = "",
        network: String = "",
        selectionGroup: String? = nil,
        requestedMember: String? = nil,
        confirmedMember: String? = nil,
        resolvedMember: String? = nil,
        failureCategory: String? = nil
    ) {
        schemaVersion = 1
        self.kind = kind
        self.timestamp = timestamp
        self.profilePointerID = profilePointerID
        self.profilePointerRevision = profilePointerRevision
        self.coreProcessIdentifier = coreProcessIdentifier
        self.coreStartTimeUnix = coreStartTimeUnix
        self.mode = mode
        self.connectionID = connectionID
        self.chains = chains
        self.rule = rule
        self.network = network
        self.selectionGroup = selectionGroup
        self.requestedMember = requestedMember
        self.confirmedMember = confirmedMember
        self.resolvedMember = resolvedMember
        self.failureCategory = failureCategory
    }

    func jsonLine() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(
            decoding: try encoder.encode(self),
            as: UTF8.self
        )
    }

    func logLine() throws -> String {
        "ROUTE_EVIDENCE \(try jsonLine())"
    }
}

final class RuntimeRouteEvidenceProjector {
    private static let maximumObservedRoutes = 2_048

    private var runtimeGenerationKey = ""
    private var observedRouteKeys: Set<String> = []
    private var observedRouteOrder: [String] = []

    func project(
        connections: [HakoConnection],
        context: RuntimeRouteContext
    ) -> [RuntimeRouteEvidence] {
        if runtimeGenerationKey != context.generationKey {
            runtimeGenerationKey = context.generationKey
            observedRouteKeys.removeAll(keepingCapacity: true)
            observedRouteOrder.removeAll(keepingCapacity: true)
        }

        var evidence: [RuntimeRouteEvidence] = []
        for connection in connections {
            let chains = connection.chains
                .map(Self.sanitize)
                .filter { !$0.isEmpty }
            guard !chains.isEmpty else { continue }
            let connectionID = Self.sanitize(connection.id)
            let rule = Self.sanitize(connection.rule)
            let network = Self.sanitize(connection.network)
            let routeKey = [
                connectionID,
                chains.joined(separator: "\u{001F}"),
                rule,
                network,
            ].joined(separator: "\u{001E}")
            guard observedRouteKeys.insert(routeKey).inserted else { continue }
            observedRouteOrder.append(routeKey)
            evidence.append(
                RuntimeRouteEvidence(
                    kind: .trafficRouteObserved,
                    profilePointerID: Self.sanitize(context.profileID),
                    profilePointerRevision:
                        Self.sanitize(context.profileRevision),
                    coreProcessIdentifier: context.coreProcessIdentifier,
                    coreStartTimeUnix: context.coreStartTimeUnix,
                    mode: Self.sanitize(context.mode),
                    connectionID: connectionID,
                    chains: chains,
                    rule: rule,
                    network: network
                )
            )
        }

        if observedRouteOrder.count > Self.maximumObservedRoutes {
            let overflow =
                observedRouteOrder.count - Self.maximumObservedRoutes
            for key in observedRouteOrder.prefix(overflow) {
                observedRouteKeys.remove(key)
            }
            observedRouteOrder.removeFirst(overflow)
        }
        return evidence
    }

    private static func sanitize(_ value: String) -> String {
        let flattened = value.components(
            separatedBy: .controlCharacters
        ).joined(separator: " ")
        return String(flattened.prefix(256))
    }
}

actor RuntimeRouteEvidenceJournal {
    private let fileURL: URL?
    private let maximumBytes: Int

    init(fileURL: URL?, maximumBytes: Int = 2_000_000) {
        self.fileURL = fileURL
        self.maximumBytes = max(1_024, maximumBytes)
    }

    static func defaultFileURL() -> URL? {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent(
            "HakoRouteEvidence.jsonl",
            isDirectory: false
        )
    }

    func append(_ events: [RuntimeRouteEvidence]) throws {
        guard let fileURL, !events.isEmpty else { return }
        let lines = try events.map { try $0.jsonLine() }
        let payload = Data(
            (lines.joined(separator: "\n") + "\n").utf8
        )
        guard payload.count <= maximumBytes else {
            throw CocoaError(.fileWriteOutOfSpace)
        }

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let currentSize = (
            try? fileURL.resourceValues(
                forKeys: [.fileSizeKey]
            ).fileSize
        ) ?? 0
        if currentSize + payload.count > maximumBytes {
            let rotatedURL = rotatedFileURL(for: fileURL)
            if FileManager.default.fileExists(atPath: rotatedURL.path) {
                try FileManager.default.removeItem(at: rotatedURL)
            }
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.moveItem(
                    at: fileURL,
                    to: rotatedURL
                )
            }
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: payload)
        } else {
            try payload.write(to: fileURL, options: .atomic)
        }
    }

    func recentLines(limit: Int) throws -> [String] {
        guard let fileURL, limit > 0 else { return [] }
        let urls = [rotatedFileURL(for: fileURL), fileURL]
        let lines = try urls.flatMap { url -> [String] in
            guard FileManager.default.fileExists(atPath: url.path) else {
                return []
            }
            let text = String(
                decoding: try Data(contentsOf: url),
                as: UTF8.self
            )
            return text.split(
                separator: "\n",
                omittingEmptySubsequences: true
            ).map(String.init)
        }
        return Array(lines.suffix(limit))
    }

    func clear() throws {
        guard let fileURL else { return }
        for url in [fileURL, rotatedFileURL(for: fileURL)]
        where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func rotatedFileURL(for url: URL) -> URL {
        url.appendingPathExtension("1")
    }
}

enum ProviderSideUpdateOutcome: Equatable {
    case applied
    case requiresFullApply
}

enum NativeProviderSideUpdateError: Error, Equatable {
    case unsupportedKind(String)
}

 
 
 
enum NativeProviderSideUpdateDispatcher {
    static func execute(
        _ update: ProviderRuntimeUpdate,
        proxy: (_ name: String, _ payload: Data) throws -> Void,
        rule: (_ name: String, _ payload: Data) throws -> Void
    ) throws {
        switch update.kind.lowercased() {
        case "proxy":
            try proxy(update.name, update.payload)
        case "rule":
            try rule(update.name, update.payload)
        default:
            throw NativeProviderSideUpdateError.unsupportedKind(update.kind)
        }
    }
}

@MainActor
final class ClashCommandClient: ObservableObject, ProxyShareCommanding {
    @Published private(set) var isConnected = false
    @Published private(set) var lastError = ""
    @Published private(set) var traffic = ClashTrafficSnapshot() {
        didSet { HakoPerf.count("pub.cmd.traffic") }
    }
     
     
     
     
     
     
     
     
     
     
     
     
    private(set) var trafficSampleCount = 0
    private(set) var uploadNonZeroSampleCount = 0
    private(set) var downloadNonZeroSampleCount = 0
    private(set) var peakUploadBytesPerSecond: Int64 = 0
    private(set) var peakDownloadBytesPerSecond: Int64 = 0
    private(set) var streamDisconnectCount = 0
     
     
    @Published private(set) var memoryFootprintBytes: Int64 = 0
    @Published private(set) var memoryBytes: Int64 = 0 {
        didSet { HakoPerf.count("pub.cmd.memory") }
    }
    @Published private(set) var mode = "—"
    @Published private(set) var peerSchemaVersion: Int32 = 0
    @Published private(set) var peerCoreVersion = "—"
    @Published private(set) var peerCapabilities: [String] = []
    @Published private(set) var runtimeDiagnostics: HakoRuntimeDiagnostics?
     
    @Published private(set) var previousGoCrashReport: String?
    @Published private(set) var previousOOMEvidence: HakoOOMEvidence?
    @Published private(set) var proxiesData: Data?
     
     
     
     
    @Published private(set) var rules: [ClashRule] = []
    @Published private(set) var logs: [String] = []
    @Published private(set) var isCollectingMemory = false
    @Published private(set) var memoryActionMessage = ""

    private static let logMaxLines = 1_000
    private static let logBatchNanoseconds: UInt64 = 100_000_000

    private var client: HakoClashAPIClient?
    private var providerSession: NETunnelProviderSession?
    private var clientHandler: HandlerProxy?
    private var connectTask: Task<Void, Never>?
    private var logBatchTask: Task<Void, Never>?
    private var pendingLogs: [String] = []
    private var trafficReducer = ClashTrafficReducer()
    private let routeEvidenceProjector = RuntimeRouteEvidenceProjector()
    private let routeEvidenceJournal = RuntimeRouteEvidenceJournal(
        fileURL: RuntimeRouteEvidenceJournal.defaultFileURL()
    )
    private var lastConfirmedRuntimeEvidenceKey = ""
    private var generation: UInt64 = 0
    private var wantsConnection = false
    private var isConnecting = false
    private var oomEvidenceConsumeTracker = OOMEvidenceConsumeTracker()
    private var uiTestProxyShareStatus = ProxyShareStatus.disabled



     
     
    private var servesProxyShareFixture: Bool {


        return false
    }

    var proxyShareAPIReady: Bool {
        servesProxyShareFixture ? isConnected : isConnected && client != nil
    }

     
     
     
     
     
     
    var proxyShareAPIClientReady: Bool {
        servesProxyShareFixture ? true : client != nil
    }

    init() {return 
    }



    func bind(session: NETunnelProviderSession?) {
        providerSession = session
        if wantsConnection { connectIfNeeded() }
    }

    func sync(vpnStatus: String) {
        let normalized = vpnStatus.lowercased()
        let shouldConnect = normalized == "connected" || normalized == "reasserting"
        if shouldConnect {
            wantsConnection = true
            connectIfNeeded()
            return
        }

         
         
         
         
        guard wantsConnection || client != nil || isConnecting || isConnected else { return }
        disconnect()
    }

     
     
     
     
     
     
     
     
     
     
     
     
    @Published private(set) var isReopeningControlSession = false

    func reconnectIfNeeded() {
        guard wantsConnection else { return }
        isReopeningControlSession = true
        disconnect(preserveIntent: true)
        connectIfNeeded()
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func applyTrafficStatisticsPreference() {
        let enabled = TrafficStatisticsSettings.onlyProxy()
        guard let client else { return }
        do {
            try client.setOnlyStatisticsProxy(enabled)
        } catch {
            HakoLogStore.shared.append(
                "traffic scope re-subscribe failed, keeping the previous one: "
                    + error.localizedDescription,
                stream: .app,
                level: .warning
            )
        }
    }

    func disconnect(preserveIntent: Bool = false) {
        if isConnected {
            recordRouteControl(
                kind: .runtimeControlDisconnected,
                failureCategory: preserveIntent
                    ? "client-reconnect"
                    : "vpn-disconnected"
            )
        }
        if !preserveIntent { wantsConnection = false }
        generation &+= 1
        connectTask?.cancel()
        connectTask = nil
        isConnecting = false
        let oldClient = client
        client = nil
        clientHandler = nil
        isConnected = false
         
         
         
         
         
         
         
         
         
         
         
         
         
        if !preserveIntent {
            trafficReducer = ClashTrafficReducer()
            traffic = ClashTrafficSnapshot()
            memoryBytes = 0
            peerSchemaVersion = 0
            peerCoreVersion = "—"
            peerCapabilities = []
            runtimeDiagnostics = nil
             
             
             
             
             
             
             
             
            proxiesData = nil
            announcedSelection = [:]
             
             
             
             
            mode = "—"
        }
        Task.detached { oldClient?.close() }
    }

    func clearLogs() {
        logBatchTask?.cancel()
        logBatchTask = nil
        pendingLogs.removeAll(keepingCapacity: true)
        logs.removeAll(keepingCapacity: true)
         
         
         
         
        HakoLogStore.shared.clear()


         
         
         
         
         
        HakoLogStore.shared.append("logs cleared", stream: .app)
        logs = ["INFO logs cleared"]
        let journal = routeEvidenceJournal
        Task { try? await journal.clear() }
    }

     
     
     
     
     
     
    func sideUpdateProvider(_ update: ProviderRuntimeUpdate) async -> ProviderSideUpdateOutcome {
        guard !false,
              let client,
              isConnected else {
            return .requiresFullApply
        }
        let token = generation
        do {
            try await Task.detached {
                try NativeProviderSideUpdateDispatcher.execute(
                    update,
                    proxy: { name, payload in
                        _ = try client.sideUpdateProxyProvider(name, payload: payload)
                    },
                    rule: { name, payload in
                        _ = try client.sideUpdateRuleProvider(name, payload: payload)
                    }
                )
            }.value
            guard token == generation,
                  self.client === client,
                  isConnected else {
                return .requiresFullApply
            }
            lastError = ""
            await refreshMetadata()
            return .applied
        } catch {
            return .requiresFullApply
        }
    }

     
     
     
    func providerRuntimeCatalog() async throws -> ProviderRuntimeCatalog {
        guard let client, isConnected else {
            throw ProviderRuntimeCatalogError.unavailable
        }
        let token = generation
        do {
            let catalog = try await boundedCoreCall("provider-catalog") {
                try NativeProviderRuntimeDispatcher.catalog(
                    proxy: { try Self.getProxyProviders(client) },
                    rule: { try Self.getRuleProviders(client) }
                )
            }
            guard token == generation,
                  self.client === client,
                  isConnected else {
                throw ProviderRuntimeCatalogError.unavailable
            }
            return catalog
        } catch let error as ProviderRuntimeCatalogError {
            throw error
        } catch {
             
             
            throw ProviderRuntimeCatalogError.unavailable
        }
    }

     
     
     
    func healthCheckProxyProvider(named name: String) async throws -> ProxyProviderRuntime {
        guard let client, isConnected else {
            throw ProviderRuntimeCatalogError.unavailable
        }
        let token = generation
        do {
            let provider = try await boundedCoreCall("provider-health") {
                try NativeProviderRuntimeDispatcher.healthCheck(
                    name: name,
                    health: { providerName in
                        _ = try client.healthCheckProxyProvider(providerName)
                    },
                    detail: { providerName in
                        try Self.getProxyProvider(client, name: providerName)
                    }
                )
            }
            guard token == generation,
                  self.client === client,
                  isConnected else {
                throw ProviderRuntimeCatalogError.unavailable
            }
            return provider
        } catch let error as ProviderRuntimeCatalogError {
            throw error
        } catch {
            throw ProviderRuntimeCatalogError.unavailable
        }
    }

    func fetchProxyShareStatus() async throws -> ProxyShareStatus {
        if servesProxyShareFixture { return uiTestProxyShareStatus }
        guard let client, isConnected else { throw ProxyShareError.apiUnavailable }
        let token = generation
        do {
            let status = try await Task.detached {
                try ProxyShareStatusParser.parse(Self.getProxyShareStatus(client))
            }.value
            guard token == generation,
                  self.client === client,
                  isConnected else {
                throw ProxyShareError.apiUnavailable
            }
            return status
        } catch {
            throw ProxyShareFailureClassifier.classify(error)
        }
    }

    func startProxyShare(
        _ configuration: ProxyShareConfiguration
    ) async throws -> ProxyShareStatus {
        if servesProxyShareFixture {
            uiTestProxyShareStatus = ProxyShareStatus(
                enabled: true,
                port: configuration.port,
                protocols: [.http, .socks5],
                authenticationRequired: true
            )
            return uiTestProxyShareStatus
        }
        guard let client, isConnected else { throw ProxyShareError.apiUnavailable }
        let token = generation
        do {
            let status = try await Task.detached {
                _ = try client.startProxyShare(
                    configuration.port,
                    username: configuration.username,
                    password: configuration.password
                )
                return try ProxyShareStatusParser.parse(
                    Self.getProxyShareStatus(client)
                )
            }.value
            guard token == generation,
                  self.client === client,
                  isConnected else {
                throw ProxyShareError.apiUnavailable
            }
            return status
        } catch {
            throw ProxyShareFailureClassifier.classify(error)
        }
    }

    func stopProxyShare() async throws -> ProxyShareStatus {
        if servesProxyShareFixture {
            uiTestProxyShareStatus = .disabled
            return .disabled
        }
        guard let client, isConnected else { throw ProxyShareError.apiUnavailable }
        let token = generation
        do {
            let status = try await Task.detached {
                _ = try client.stopProxyShare()
                return try ProxyShareStatusParser.parse(
                    Self.getProxyShareStatus(client)
                )
            }.value
            guard token == generation,
                  self.client === client,
                  isConnected else {
                throw ProxyShareError.apiUnavailable
            }
            return status
        } catch {
            throw ProxyShareFailureClassifier.classify(error)
        }
    }

     
     
    func generateDiagnosticLogs(count: Int) {
        guard count > 0 else { return }
        let generated = (0..<count).map {
            "DEBUG [developer:\($0)] local diagnostic log payload \(String(repeating: "x", count: 48))"
        }
        logs = Array((logs + generated).suffix(Self.logMaxLines))
    }

    func refreshMetadata() async {
        guard let client else { return }
        let token = generation
        let modeWritesAtRequest = localModeWrites
        do {
            async let configs = Task.detached { try Self.getConfigs(client) }.value
            async let proxies = Task.detached { try Self.getProxies(client) }.value
            let (configsJSON, proxiesJSON) = try await (configs, proxies)
            guard token == generation, self.client === client, isConnected else { return }
            applyConfigs(
                configsJSON,
                source: "configs-poll",
                modeWritesAtRequest: modeWritesAtRequest
            )
            proxiesData = proxiesJSON.data(using: .utf8)
            lastError = ""
        } catch {
             
             
             
            guard token == generation, self.client === client, isConnected else { return }
            if error.localizedDescription.localizedCaseInsensitiveContains("EOF") { return }
            lastError = error.localizedDescription
        }
    }

     
     
    func flushDNSCache() async {
        await runCacheFlush { try Self.flushDNSCache($0) }
    }

     
    func flushFakeIPCache() async {
        await runCacheFlush { try Self.flushFakeIPCache($0) }
    }

    private func runCacheFlush(
        _ flush: @escaping @Sendable (HakoClashAPIClient) throws -> Void
    ) async {
        guard let client else { return }
        let token = generation
        do {
            try await Task.detached { try flush(client) }.value
            guard token == generation, self.client === client, isConnected else { return }
            lastError = ""
        } catch {
            guard token == generation, self.client === client, isConnected else { return }
            lastError = error.localizedDescription
        }
    }

     
     
     
    func fetchRules() async {
        guard let client else { return }
        let token = generation
        do {
            let json = try await Task.detached { try Self.getRules(client) }.value
            guard token == generation, self.client === client, isConnected else { return }
            applyRules(json)
            lastError = ""
        } catch {
            guard token == generation, self.client === client, isConnected else { return }
            if error.localizedDescription.localizedCaseInsensitiveContains("EOF") { return }
            lastError = error.localizedDescription
        }
    }

     
     
     
    func applyRules(_ json: String) {
        rules = ClashRulesPayload.decode(json.data(using: .utf8))
    }

     
     
     
    func runDNSQuery(name: String, type: String) async -> String? {
        guard let client else { return nil }
        do {
            return try await Task.detached { try Self.queryDNS(client, name: name, type: type) }.value
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func readStartupExplanation() -> HakoStartupExplanation? {
        let raw = HakoExplainLastStartup()
        guard let decoded = HakoStartupExplanation.decode(raw) else {
             
             
             
             
             
             
             
             
            HakoLogStore.shared.append(
                "startup-explanation nil rawBytes=\(raw.utf8.count)",
                stream: .app, level: .info)
            return nil
        }
        let account = Self.explanationWithMeasuredStage(
            decoded, phaseLogLines: Self.phaseLogLines()
        )
         
         
         
        guard let pressure = CoreMemoryPressure.observed() else { return account }
        return account.corrected(
            footprintBytes: pressure.footprintBytes,
            budgetBytes: pressure.limitBytes
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    nonisolated static func explanationWithMeasuredStage(
        _ account: HakoStartupExplanation,
        phaseLogLines: [String]
    ) -> HakoStartupExplanation {
        guard let measured = HakoMemoryLedger.lastRun(
            from: phaseLogLines
        ).rows.last?.name, !measured.isEmpty else { return account }
        return HakoStartupExplanation(
            resource: account.resource,
            footprintBytes: account.footprintBytes,
            budgetBytes: account.budgetBytes,
            stage: measured
        )
    }

    private static func phaseLogLines() -> [String] {
        guard let container = HakoAppIdentifiers.appGroupContainer,
              let text = try? String(
                  contentsOf: container.appendingPathComponent(
                      MemorySampleLog.startupPhaseFileName
                  ),
                  encoding: .utf8
              )
        else { return [] }
        return text.split(separator: "\n").map(String.init)
    }

     
     
     
    func clearStartupExplanation() {
        HakoClearLastStartupExplanation()
    }

     
     
     
     
     
     
    func explainDNS(
        name: String,
        type: String,
        probe: Bool
    ) async -> String? {
        guard let client else { return nil }
        do {
            return try await boundedCoreCall("dns-explain") {
                try Self.explainDNS(
                    client,
                    name: name,
                    type: type,
                    probe: probe
                )
            }
        } catch {
             
             
             
             
             
             
             
             
             
            HakoLogStore.shared.append(
                "dns explain unavailable: " + error.localizedDescription,
                stream: .app,
                level: .warning
            )
            return nil
        }
    }

     
     
     
     
     
     
     
     
    func configDeviations() async -> ConfigDeviationReport? {
        guard let client else { return nil }
        do {
            let json = try await boundedCoreCall("config-deviations") {
                try Self.configDeviations(client)
            }
            return try ConfigDeviationReport.decode(json)
        } catch {
             
             
             
             
             
            HakoLogStore.shared.append(
                "config deviations unavailable: " + error.localizedDescription,
                stream: .app,
                level: .warning
            )
            return nil
        }
    }

    func refreshRuntimeDiagnostics() async {
        guard let providerSession else { return }
        do {
            let diagnostics =
                try await HakoClient(
                    session: providerSession
                ).runtimeDiagnostics()
            runtimeDiagnostics = diagnostics
            let context = currentRouteContext()
            if context.generationKey != lastConfirmedRuntimeEvidenceKey {
                lastConfirmedRuntimeEvidenceKey = context.generationKey
                recordRouteControl(kind: .runtimeCoreConfirmed)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func requestGarbageCollection() async {
        guard !isCollectingMemory else { return }
        guard let providerSession else {
            lastError = "VPN Provider API is not connected."
            return
        }
        guard peerCapabilities.contains(HakoCommandCapability.forceGCV1) else {
            lastError = "The installed VPN Extension does not support memory release. Reinstall or update Clash."
            return
        }
        isCollectingMemory = true
        defer { isCollectingMemory = false }
        do {
            try await HakoClient(session: providerSession).forceGarbageCollection()
            memoryActionMessage = "Memory released"
            lastError = ""
            await refreshRuntimeDiagnostics()
        } catch {
            memoryActionMessage = ""
            lastError = error.localizedDescription
        }
    }

    private func consumeStartupOOMEvidence() async {
        guard let providerSession else { return }
        let providerClient = HakoClient(session: providerSession)
        guard let diagnostics = try? await providerClient.runtimeDiagnostics() else { return }
        guard oomEvidenceConsumeTracker.beginAttempt(
            processIdentifier: diagnostics.processIdentifier,
            startTimeUnix: diagnostics.startTimeUnix
        ) else { return }
         
         
         
         
        previousOOMEvidence = try? await providerClient.consumeOOMEvidence()
         
         
         
         
        if let report = await providerClient.consumeGoCrashReport() {
            previousGoCrashReport = report
        }
    }

     
     
     
     
     
     
     
    private var localModeWrites: UInt64 = 0

     
     
     
     
     
     
    private var modeSendChain: Task<Bool, Never>?

     
     
     
     
     
     
    @discardableResult
    func setMode(_ newMode: String) async -> Bool {
        let previous = modeSendChain
        let link = Task { [weak self] in
            _ = await previous?.value
            return await self?.sendModeNow(newMode) ?? false
        }
        modeSendChain = link
        return await link.value
    }

    private func sendModeNow(_ newMode: String) async -> Bool {
        recordRouteControl(
            kind: .modeRequested,
            requestedMember: newMode
        )
        guard let client else {
            recordRouteControl(
                kind: .modeRejected,
                requestedMember: newMode,
                failureCategory: "control-unavailable"
            )
            return false
        }
        do {
            try await Task.detached { try client.setMode(newMode) }.value
            mode = newMode
            localModeWrites &+= 1
            lastError = ""
            recordRouteControl(
                kind: .modeConfirmed,
                confirmedMember: newMode
            )
            return true
        } catch {
            lastError = error.localizedDescription
            recordRouteControl(
                kind: .modeRejected,
                requestedMember: newMode,
                failureCategory: "core-rejected"
            )
            return false
        }
    }

     
     
     
     
     
     
     
     
     
    var lastCommandError: String { lastError }

    func unfix(group: String) async -> Bool {
        guard let client, isConnected else {
            lastError = "Proxy control is not connected."
            return false
        }
        do {
            try await Task.detached { try client.unfixProxy(group) }.value
             
             
            await refreshMetadata()
            lastError = ""
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func select(group: String, name: String) async -> Bool {
        recordRouteControl(
            kind: .selectionRequested,
            selectionGroup: group,
            requestedMember: name
        )
        guard let client, isConnected else {
            lastError = "Proxy control is not connected."
            recordRouteControl(
                kind: .selectionRejected,
                selectionGroup: group,
                requestedMember: name,
                failureCategory: "control-unavailable"
            )
            return false
        }
        let token = generation
        do {
            try await Task.detached { try client.selectProxy(group, name: name) }.value
            await refreshMetadata()
            let confirmedGroup = NodeInventory.parse(proxiesData).0.first(
                where: { $0.name == group }
            )
            guard token == generation,
                  self.client === client,
                  isConnected,
                  confirmedGroup?.now == name else {
                lastError =
                    "The running proxy group did not confirm the selected route."
                recordRouteControl(
                    kind: .selectionRejected,
                    selectionGroup: group,
                    requestedMember: name,
                    confirmedMember: confirmedGroup?.now,
                    resolvedMember: confirmedGroup?.resolvedNow,
                    failureCategory: "catalog-unconfirmed"
                )
                return false
            }
            lastError = ""
            recordRouteControl(
                kind: .selectionConfirmed,
                selectionGroup: group,
                requestedMember: name,
                confirmedMember: confirmedGroup?.now,
                resolvedMember: confirmedGroup?.resolvedNow
            )
            return true
        } catch {
            guard token == generation,
                  self.client === client else {
                return false
            }
            lastError = error.localizedDescription
            recordRouteControl(
                kind: .selectionRejected,
                selectionGroup: group,
                requestedMember: name,
                failureCategory: "core-rejected"
            )
            return false
        }
    }

     
     
     
     
     
    func closeConnectionsAfterProxySelection() async {
        guard let client, isConnected else {
            lastError = "Proxy control is not connected."
            return
        }
        let token = generation
        do {
            try await Task.detached {
                try client.closeConnections()
            }.value
            guard token == generation,
                  self.client === client,
                  isConnected else {
                return
            }
            lastError = ""
        } catch {
            guard token == generation,
                  self.client === client,
                  isConnected else {
                return
            }
            lastError = error.localizedDescription
        }
    }

    func urlTest(name: String, url: String = "") async -> Int {
        let outcome = await probeOutcome(name: name, url: url)
        if outcome.succeeded {
            lastError = ""
        } else {
            lastError = Self.urlTestFailureMessage(category: outcome.failureCategory)
        }
        return outcome.delay
    }

    func urlTestQuietly(name: String, url: String = "") async -> ClashURLTestOutcome {
        await probeOutcome(name: name, url: url)
    }

    func startSTUNTest(
        server: String,
        outbound: String,
        handler: HakoSTUNTestHandlerProtocol
    ) async throws -> HakoSTUNTestSession {
        guard let client else {
            throw NSError(
                domain: "HakoClient.STUN",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "VPN Provider API is not connected."]
            )
        }
        guard peerCapabilities.contains(HakoCommandCapability.stunV1) else {
            throw NSError(
                domain: "HakoClient.STUN",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "The installed VPN Extension does not support STUN diagnostics. Reinstall or update Clash."]
            )
        }
        return try await Task.detached {
            try client.startSTUNTest(
                server,
                outbound: outbound,
                handler: handler
            )
        }.value
    }

     
     
     
     
     
     
    private func probeOutcome(name: String, url: String) async -> ClashURLTestOutcome {
        guard let client, isConnected else {
             
             
             
             
            HakoLogStore.shared.append(
                "urltest blocked  name=\(name)  control-session "
                    + (client == nil ? "absent" : "reconnecting"),
                stream: .app, level: .warning)
            return ClashURLTestOutcome(delay: -1, failureCategory: "api-unavailable")
        }
        do {
             
             
             
             
             
             
             
             
             
             
             
            let payload = try await boundedCoreCall(
                "urltest", countsTowardWedge: false
            ) {
                 
                 
                 
                var failure: NSError?
                let body = client.urlTestOutcome(
                    name, testURL: url, error: &failure)
                if let failure { throw failure }
                return body
            }
            let outcome = Self.parseURLTestOutcome(payload)
            if outcome.succeeded {
                HakoLogStore.shared.append(
                    "urltest ok  name=\(name)  delay=\(outcome.delay)ms",
                    stream: .app, level: .info)
                return outcome
            }
            let reason = "urltest failed  name=\(name)  "
                + "category=\(outcome.failureCategory)  payload=\(payload)"
            HakoLogStore.shared.append(reason, stream: .app, level: .warning)
            Self.urlTestLog.warning("\(reason, privacy: .public)")
            return outcome
        } catch {
             
             
             
            let category = Self.urlTestFailureCategory(error.localizedDescription)
             
             
             
             
             
             
            let reason = "urltest failed  name=\(name)  category=\(category)  error=\(error.localizedDescription)"
            HakoLogStore.shared.append(reason, stream: .app, level: .warning)
            Self.urlTestLog.warning("\(reason, privacy: .public)")
            return ClashURLTestOutcome(delay: -1, failureCategory: category)
        }
    }


     
     
    private var coreCallBreachStreak = 0

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func boundedCoreCall<T: Sendable>(
        _ label: String,
        seconds: UInt64 = 8,
        countsTowardWedge: Bool = true,
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        let race = CoreCallRace<T>()
        let outcome = await withTaskCancellationHandler {
             
             
             
            let timeout = Task.detached {
                do {
                    try await Task.sleep(
                        nanoseconds: seconds * 1_000_000_000
                    )
                    race.resolve(.deadline)
                } catch {
                     
                }
            }
            Task.detached {
                let result = await Self.onDedicatedThread {
                    Result { try work() }
                }
                if race.resolve(.result(result)) {
                    timeout.cancel()
                }
            }
            let outcome = await race.wait()
            timeout.cancel()
            return outcome
        } onCancel: {
            race.resolve(.cancelled)
        }

        switch outcome {
        case .deadline:
            if countsTowardWedge { coreCallBreachStreak += 1 }
            HakoLogStore.shared.append(
                "core-call deadline  call=\(label)  streak=\(coreCallBreachStreak)",
                stream: .app, level: .warning)
            if countsTowardWedge, coreCallBreachStreak >= 3 {
                coreCallBreachStreak = 0
                let move = "reopening"
                HakoLogStore.shared.append(
                    "core-call self-heal  \(move) the control session",
                    stream: .app, level: .warning)
                reconnectIfNeeded()
            }
            throw CoreCallDeadline(label: label)
        case .cancelled:
            throw CancellationError()
        case .result(let result):
            coreCallBreachStreak = 0
            return try result.get()
        }
    }

     
     
    private nonisolated static func onDedicatedThread<T: Sendable>(
        _ work: @escaping @Sendable () -> T
    ) async -> T {
        await withCheckedContinuation { continuation in
            Thread.detachNewThread {
                continuation.resume(returning: work())
            }
        }
    }

     
    struct CoreCallDeadline: Error, LocalizedError {
        let label: String
        var errorDescription: String? {
            "core call \(label) exceeded its 8s client deadline (timeout)"
        }
    }

    private static let urlTestLog = Logger(
        subsystem: "org.example.hako", category: "urltest")

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func parseURLTestOutcome(_ payload: String) -> ClashURLTestOutcome {
        guard let data = payload.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data)
                  as? [String: Any]
        else {
             
             
             
             
             
             
             
             
             
             
             
            let note = "urltest payload-unparsed  fallback=prose  payload=\(payload)"
            HakoLogStore.shared.append(note, stream: .app, level: .warning)
            urlTestLog.warning("\(note, privacy: .public)")
            return ClashURLTestOutcome(
                delay: -1,
                failureCategory: urlTestFailureCategory(payload)
            )
        }
        if let delay = root["delay"] as? Int, delay > 0 {
            return ClashURLTestOutcome(delay: delay, failureCategory: "")
        }
        if root["deferred"] as? Bool == true {
            return ClashURLTestOutcome(
                delay: -1, failureCategory: "admission-deferred")
        }
        let failure = root["failure"] as? [String: Any] ?? [:]
        let errno = (failure["errno"] as? String ?? "").uppercased()
        let kind = (failure["kind"] as? String ?? "").lowercased()
        let inner = failure["message"] as? String
            ?? root["message"] as? String
            ?? payload
        return ClashURLTestOutcome(
            delay: -1,
            failureCategory: urlTestCategory(
                errno: errno, kind: kind, message: inner)
        )
    }

     
     
    static func urlTestCategory(
        errno: String,
        kind: String,
        message: String
    ) -> String {
        switch errno {
        case "ECONNREFUSED": return "connection-refused"
         
         
         
        case "EADDRNOTAVAIL": return "address-unavailable"
        case "EHOSTUNREACH", "ENETUNREACH": return "unreachable"
        case "ETIMEDOUT": return "timeout"
        case "ECONNRESET": return "connection-reset"
        case "EPIPE": return "connection-closed"
        default: break
        }
        switch kind {
        case "timeout": return "timeout"
        case "canceled": return "canceled"
        case "status": return "unexpected-status"
        case "write": return "write-failed"
        case "read": return "read-failed"
        case "dial": return "dial-failed"
        default: break
        }
         
         
         
        return urlTestFailureCategory(message)
    }

    static func urlTestFailureCategory(_ description: String) -> String {
        let value = description.lowercased()
         
         
         
        if value.contains("url test deferred: memory admission") {
            return "admission-deferred"
        }
        if value.contains("timeout") || value.contains("deadline exceeded") || value.contains("http 504") {
            return "timeout"
        }
        if value.contains("dns") || value.contains("no such host") || value.contains("couldn't find ip") {
            return "dns"
        }
        if value.contains("tls") || value.contains("certificate") || value.contains("x509") {
            return "tls"
        }
        if value.contains("auth") || value.contains("unauthorized") || value.contains("forbidden") {
            return "authentication"
        }
        if value.contains("503 service unavailable") {
            return "proxy-service-unavailable"
        }
        if value.contains("502 bad gateway") {
            return "proxy-bad-gateway"
        }
        if value.contains("connect method not allowed") {
            return "proxy-connect-unsupported"
        }
        if value.contains("can not connect remote err code") {
            return "proxy-connect-rejected"
        }
        if value.contains("connection refused") {
            return "connection-refused"
        }
        if value.contains("unexpected http status") {
            return "unexpected-status"
        }
        if value.contains("network is unreachable") || value.contains("no route to host") {
            return "network-unreachable"
        }
        if value.contains("eof") || value.contains("connection reset") || value.contains("broken pipe") {
            return "connection-closed"
        }
        if value.contains("http 503") {
            return "delay-test-failed"
        }
        return "other"
    }

    static func urlTestFailureMessage(category: String) -> String {
        switch category {
        case "timeout": return "URL test timed out after 5 seconds."
        case "dns": return "URL test failed because the node hostname could not be resolved."
        case "tls": return "URL test failed during TLS or certificate verification."
        case "authentication": return "URL test failed authentication. Check the node credentials."
        case "proxy-service-unavailable": return "The HTTP proxy returned 503 Service Unavailable for the test target."
        case "proxy-bad-gateway": return "The HTTP proxy returned 502 Bad Gateway for the test target."
        case "proxy-connect-unsupported": return "The configured HTTP proxy does not allow CONNECT requests."
        case "proxy-connect-rejected": return "The HTTP proxy rejected the CONNECT target."
        case "connection-refused": return "The node server refused the connection."
        case "unexpected-status": return "The URL test target returned an unexpected HTTP status through this node."
        case "network-unreachable": return "The node server is unreachable on the current network."
        case "connection-closed": return "The node connection closed during the URL test."
        case "api-unavailable": return "VPN Provider API is not connected."
        default: return "URL test failed for the selected node. Check reachability, TLS/authentication, and protocol settings."
        }
    }

    private func connectIfNeeded() {
        guard client == nil, !isConnecting else { return }
         
         
         
         
        guard let providerSession else { return }
        guard let container = HakoAppIdentifiers.appGroupContainer
        else {
            lastError = "App Group container unavailable"
            return
        }

        generation &+= 1
         
         
        runtimeIdentityCache.invalidate()
        let token = generation
        isConnecting = true
        connectTask = Task { [weak self] in
            do {
                let hello = try await HakoClient(session: providerSession).hello()
                guard !Task.isCancelled else { return }
                self?.openNativeClient(
                    socketPath: container.appendingPathComponent("clash.sock").path,
                    hello: hello,
                    token: token
                )
            } catch {
                self?.connectFailed(error, token: token)
            }
        }
    }

    private func openNativeClient(socketPath: String, hello: HakoCommandHello, token: UInt64) {
        guard token == generation, wantsConnection else { return }
        connectTask = nil
        let handler = HandlerProxy(owner: self, token: token)
        let options = Self.makeOptions(
            onlyStatisticsProxy: TrafficStatisticsSettings.onlyProxy()
        )
        var error: NSError?
        guard let newClient = HakoNewClashAPIClientWithOptions(
            socketPath,
            handler,
            options,
            &error
        ) else {
            connectFailed(
                error ?? NSError(
                    domain: "HakoClient.CommandClient",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to create Clash API client"]
                ),
                token: token
            )
            return
        }

        peerSchemaVersion = hello.schemaVersion
        peerCoreVersion = hello.coreVersion
        peerCapabilities = hello.capabilities
        clientHandler = handler
        client = newClient
        connectTask = Task.detached { [weak self] in
            do {
                try newClient.connect()
            } catch {
                await self?.connectFailed(error, token: token)
            }
        }
    }

    static func makeOptions(onlyStatisticsProxy: Bool) -> HakoClashAPIClientOptions {
        let options = HakoClashAPIClientOptions()
         
         
         
         
         
        options.statusInterval = 250
        options.addCommand(HakoCommandStatus)
        options.addCommand(HakoCommandLog)
        options.addCommand(HakoCommandConnections)
         
         
         
         
        options.addCommand(HakoCommandMode)
        options.onlyStatisticsProxy = onlyStatisticsProxy
        return options
    }

    private nonisolated static func getConfigs(_ client: HakoClashAPIClient) throws -> String {
        var error: NSError?
        let result = client.getConfigs(&error)
        if let error { throw error }
        return result
    }

    private nonisolated static func flushDNSCache(_ client: HakoClashAPIClient) throws {
        try client.flushDNSCache()
    }

    private nonisolated static func flushFakeIPCache(_ client: HakoClashAPIClient) throws {
        try client.flushFakeIPCache()
    }

    private nonisolated static func getProxies(_ client: HakoClashAPIClient) throws -> String {
        var error: NSError?
        let result = client.getProxies(&error)
        if let error { throw error }
        return result
    }

    private nonisolated static func getRules(_ client: HakoClashAPIClient) throws -> String {
        var error: NSError?
        let result = client.getRules(&error)
        if let error { throw error }
        return result
    }

    private nonisolated static func queryDNS(
        _ client: HakoClashAPIClient, name: String, type: String
    ) throws -> String {
        var error: NSError?
        let result = client.queryDNS(name, qType: type, error: &error)
        if let error { throw error }
        return result
    }

    private nonisolated static func explainDNS(
        _ client: HakoClashAPIClient,
        name: String,
        type: String,
        probe: Bool
    ) throws -> String {
        var error: NSError?
        let result = client.explainDNS(
            name,
            qType: type,
            probe: probe,
            error: &error
        )
        if let error { throw error }
        return result
    }

    private nonisolated static func configDeviations(
        _ client: HakoClashAPIClient
    ) throws -> String {
        var error: NSError?
        let result = client.getConfigDeviations(&error)
        if let error { throw error }
        return result
    }

    private nonisolated static func getProxyShareStatus(
        _ client: HakoClashAPIClient
    ) throws -> String {
        var error: NSError?
        let result = client.getProxyShareStatus(&error)
        if let error { throw error }
        return result
    }

    private nonisolated static func getProxyProviders(
        _ client: HakoClashAPIClient
    ) throws -> String {
        var error: NSError?
        let result = client.getProxyProviders(&error)
        if let error { throw error }
        return result
    }

    private nonisolated static func getProxyProvider(
        _ client: HakoClashAPIClient,
        name: String
    ) throws -> String {
        var error: NSError?
        let result = client.getProxyProvider(name, error: &error)
        if let error { throw error }
        return result
    }

    private nonisolated static func getRuleProviders(
        _ client: HakoClashAPIClient
    ) throws -> String {
        var error: NSError?
        let result = client.getRuleProviders(&error)
        if let error { throw error }
        return result
    }

    private func connectFailed(_ error: Error, token: UInt64) {
        guard token == generation else { return }
        isConnecting = false
        connectTask = nil
        client = nil
        clientHandler = nil
        isConnected = false
        lastError = error.localizedDescription
         
         
        isReopeningControlSession = false
        scheduleReconnect(token: token)
    }

    private func handleConnected(token: UInt64) {
        guard token == generation else { return }
        isConnecting = false
        connectTask = nil
        isConnected = true
         
         
         
        isReopeningControlSession = false
        lastError = ""
        trafficReducer = ClashTrafficReducer()
        traffic = ClashTrafficSnapshot()
        recordRouteControl(kind: .runtimeControlConnected)
        Task { await refreshMetadata() }
        Task { await refreshRuntimeDiagnostics() }
        Task { await consumeStartupOOMEvidence() }
    }

    private func handleDisconnected(_ message: String, token: UInt64) {
        guard token == generation else { return }
        recordRouteControl(
            kind: .runtimeControlDisconnected,
            failureCategory: "stream-disconnected"
        )
        streamDisconnectCount += 1
        isConnecting = false
        connectTask = nil
         
         
        modeStreamSettler.cancel()
        client = nil
        clientHandler = nil
        isConnected = false
        trafficReducer = ClashTrafficReducer()
        traffic = ClashTrafficSnapshot()
        memoryBytes = 0
        peerSchemaVersion = 0
        peerCoreVersion = "—"
        peerCapabilities = []
        runtimeDiagnostics = nil
        if !message.isEmpty { lastError = message }
        scheduleReconnect(token: token)
    }

    private func scheduleReconnect(token: UInt64) {
        guard wantsConnection, token == generation else { return }
        connectTask?.cancel()
        connectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, let self, token == self.generation, self.wantsConnection else { return }
            self.connectTask = nil
            self.connectIfNeeded()
        }
    }

    private func handleTraffic(_ payload: TrafficPayload, token: UInt64) {
        guard token == generation else { return }
        traffic = trafficReducer.consume(
            up: payload.up,
            down: payload.down,
            upTotal: payload.upTotal,
            downTotal: payload.downTotal
        )
        trafficSampleCount += 1
        if traffic.upload > 0 { uploadNonZeroSampleCount += 1 }
        if traffic.download > 0 { downloadNonZeroSampleCount += 1 }
        peakUploadBytesPerSecond = max(peakUploadBytesPerSecond, traffic.upload)
        peakDownloadBytesPerSecond = max(peakDownloadBytesPerSecond, traffic.download)
    }

    private func handleMemory(_ payload: MemoryPayload, token: UInt64) {
        guard token == generation, payload.inuse > 0 else { return }
        memoryBytes = payload.inuse
        memoryFootprintBytes = max(0, payload.footprint ?? 0)
    }

    private func handleConnections(
        _ connections: [HakoConnection],
        token: UInt64
    ) {
        guard token == generation else { return }
        let evidence = routeEvidenceProjector.project(
            connections: connections,
            context: currentRouteContext()
        )
        recordRouteEvidence(evidence)
    }

    private func handleLog(_ payload: LogPayload, token: UInt64) {
        guard token == generation else { return }
         
        enqueueLogLines([
            "\(payload.type.uppercased()) \(payload.payload)",
        ])
    }

     
     
     
     
     
     
     
     
     
     
     
     
    private let modeStreamSettler = TrailingEdgeSettler(
        windowNanoseconds: TrailingEdgeSettler.modeStreamWindowNanoseconds
    )

    private func handleMode(_ json: String, token: UInt64) {
        guard token == generation else { return }
        modeStreamSettler.submit { [weak self] in
            guard let self, token == self.generation else { return }
            self.applyConfigs(json, source: "mode-stream")
            self.adoptStreamSelection(json)
        }
    }

     
     
     
    private var announcedSelection: [String: String] = [:]

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func adoptStreamSelection(_ json: String) {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
                  as? [String: Any],
              let selected = object["selected"] as? [String: String]
        else { return }
        guard selected != announcedSelection else { return }
        let wasFirstMessage = announcedSelection.isEmpty
        announcedSelection = selected
        guard !wasFirstMessage else { return }
        selectionAnnouncements &+= 1
    }

     
     
     
     
     
     
     
     
    @Published private(set) var selectionAnnouncements = 0

    private func enqueueLogLines(_ lines: [String]) {
        guard !lines.isEmpty else { return }
        pendingLogs.append(contentsOf: lines)
        guard logBatchTask == nil else { return }
        if logs.isEmpty {
            flushLogs()
            return
        }
        logBatchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.logBatchNanoseconds)
            guard !Task.isCancelled else { return }
            self?.flushLogs()
        }
    }

    private func flushLogs() {
        logBatchTask = nil
        guard !pendingLogs.isEmpty else { return }
        var buffer = logs
        buffer.append(contentsOf: pendingLogs)
        pendingLogs.removeAll(keepingCapacity: true)
        if buffer.count > Self.logMaxLines {
            buffer.removeFirst(buffer.count - Self.logMaxLines)
        }
        logs = buffer
    }

     
     
     
     
    private static let runtimeIdentityTTL: TimeInterval = 5
    private lazy var runtimeIdentityCache = RuntimeIdentityCache(
        ttl: Self.runtimeIdentityTTL
    ) {
        NodesRuntimeIdentity.load()
    }

    private func currentRouteContext() -> RuntimeRouteContext {
        let identity = runtimeIdentityCache.current()
        return RuntimeRouteContext(
            profileID: identity?.profileID ?? "unavailable",
            profileRevision: identity?.revision ?? "unavailable",
            coreProcessIdentifier:
                runtimeDiagnostics?.processIdentifier ?? 0,
            coreStartTimeUnix:
                runtimeDiagnostics?.startTimeUnix ?? 0,
            mode: mode
        )
    }

    private func recordRouteControl(
        kind: RuntimeRouteEvidence.Kind,
        selectionGroup: String? = nil,
        requestedMember: String? = nil,
        confirmedMember: String? = nil,
        resolvedMember: String? = nil,
        failureCategory: String? = nil
    ) {
        let context = currentRouteContext()
        recordRouteEvidence([
            RuntimeRouteEvidence(
                kind: kind,
                profilePointerID: context.profileID,
                profilePointerRevision: context.profileRevision,
                coreProcessIdentifier:
                    context.coreProcessIdentifier,
                coreStartTimeUnix: context.coreStartTimeUnix,
                mode: context.mode,
                selectionGroup: selectionGroup,
                requestedMember: requestedMember,
                confirmedMember: confirmedMember,
                resolvedMember: resolvedMember,
                failureCategory: failureCategory
            ),
        ])
    }

    private func recordRouteEvidence(
        _ evidence: [RuntimeRouteEvidence]
    ) {
        guard !false, !evidence.isEmpty else {
            return
        }
        enqueueLogLines(evidence.compactMap { try? $0.logLine() })
        let journal = routeEvidenceJournal
        Task { try? await journal.append(evidence) }
    }

     
     
     
    func applyConfigs(
        _ json: String,
        source: String = "?",
        modeWritesAtRequest: UInt64? = nil
    ) {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let currentMode = object["mode"] as? String
        else { return }
         
         
         
         
         
        if let writes = modeWritesAtRequest, writes != localModeWrites {
            return
        }
         
         
         
         
        guard mode != currentMode else { return }
         
         
         
         
         
         
         
        {
            let was = mode
             
             
             
             
             
            HakoLogStore.shared.append(
                "outbound mode  \(was) -> \(currentMode)  from=\(source)",
                stream: .app, level: .warning)
        }()
        mode = currentMode
         
         
         
         
        localModeWrites &+= 1
    }

    private func updateSeedSelection(group: String, name: String) {
        guard let proxiesData,
              var root = try? JSONSerialization.jsonObject(with: proxiesData) as? [String: Any],
              var proxies = root["proxies"] as? [String: Any],
              var selected = proxies[group] as? [String: Any]
        else { return }
        selected["now"] = name
        proxies[group] = selected
        root["proxies"] = proxies
        self.proxiesData = try? JSONSerialization.data(withJSONObject: root)
    }
}

private extension ClashCommandClient {
    struct TrafficPayload: Decodable {
        let up: Int64
        let down: Int64
        let upTotal: Int64
        let downTotal: Int64
    }

    struct MemoryPayload: Decodable {
        let inuse: Int64
         
         
        let footprint: Int64?
    }

    struct LogPayload: Decodable {
        let type: String
        let payload: String
    }

    final class HandlerProxy: NSObject, HakoClashAPIClientHandlerProtocol {
        weak var owner: ClashCommandClient?
        let token: UInt64

        init(owner: ClashCommandClient, token: UInt64) {
            self.owner = owner
            self.token = token
        }

        func connected() {
            Task { @MainActor [weak owner] in owner?.handleConnected(token: token) }
        }

        func disconnected(_ message: String?) {
            Task { @MainActor [weak owner] in owner?.handleDisconnected(message ?? "", token: token) }
        }

        func writeTraffic(_ message: String?) {
            guard let data = message?.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(TrafficPayload.self, from: data)
            else { return }
            Task { @MainActor [weak owner] in owner?.handleTraffic(payload, token: token) }
        }

        func writeMemory(_ message: String?) {
            guard let data = message?.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(MemoryPayload.self, from: data)
            else { return }
            Task { @MainActor [weak owner] in owner?.handleMemory(payload, token: token) }
        }

        func writeLogs(_ message: String?) {
            guard let data = message?.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(LogPayload.self, from: data)
            else { return }
            Task { @MainActor [weak owner] in owner?.handleLog(payload, token: token) }
        }

        func writeConnections(_ message: String?) {
            guard let message else { return }
            let connections = ConnectionsParser.parse(message)
            Task { @MainActor [weak owner] in
                owner?.handleConnections(
                    connections,
                    token: token
                )
            }
        }

        func writeMode(_ message: String?) {
            guard let message else { return }
            Task { @MainActor [weak owner] in owner?.handleMode(message, token: token) }
        }
    }
}
