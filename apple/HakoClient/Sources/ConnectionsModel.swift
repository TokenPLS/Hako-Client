import Combine
import Foundation
import Hako
import HakoClientUI

typealias HakoConnection = HakoActivityConnectionSnapshot

enum ConnectionsParser {
    static func parse(_ text: String) -> [HakoConnection] {
        guard let data = text.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = root["connections"] as? [[String: Any]] else {
            return []
        }

         
         
         
         
         
         
         

        var seen = Set<String>()
        return rows.compactMap { row -> HakoConnection? in
            guard let id = row["id"] as? String, !id.isEmpty else { return nil }
            guard seen.insert(id).inserted else { return nil }

            let metadata = row["metadata"] as? [String: Any] ?? [:]
            let host = string(metadata["host"])
            let ip = string(metadata["destinationIP"])
            let port = string(metadata["destinationPort"])
            let sourceIP = string(metadata["sourceIP"])
            let sourcePort = string(metadata["sourcePort"])
            let destination = address(host.isEmpty ? ip : host, port)
            let source = address(sourceIP, sourcePort)
            let chains = row["chains"] as? [String] ?? []
            let startText = string(row["start"])

            return HakoConnection(
                id: id,
                destination: destination.isEmpty ? "Unknown destination" : destination,
                source: source,
                network: string(metadata["network"]).uppercased(),
                route: chains.joined(separator: " → "),
                rule: string(row["rule"]),
                upload: number(row["upload"]),
                download: number(row["download"]),
                start: HakoInstant.parse(startText),
                uid: signedNumber(metadata["uid"]),
                host: host,
                sourceIP: sourceIP,
                sourcePort: sourcePort,
                destinationIP: ip,
                destinationPort: port,
                dnsMode: string(metadata["dnsMode"]),
                process: string(metadata["process"]),
                processPath: string(metadata["processPath"]),
                remoteDestination: string(metadata["remoteDestination"]),
                sourceGeoIP: strings(metadata["sourceGeoIP"]),
                destinationGeoIP: strings(metadata["destinationGeoIP"]),
                destinationIPASN: string(metadata["destinationIPASN"]),
                sourceIPASN: string(metadata["sourceIPASN"]),
                specialRules: string(metadata["specialRules"]),
                specialProxy: string(metadata["specialProxy"]),
                chains: chains,
                rulePayload: string(row["rulePayload"]),
                uploadSpeed: optionalNumber(row["uploadSpeed"]),
                downloadSpeed: optionalNumber(row["downloadSpeed"])
            )
        }
    }

    private static func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }

    private static func number(_ value: Any?) -> Int64 {
        if let value = value as? NSNumber { return max(value.int64Value, 0) }
        return max(Int64(string(value)) ?? 0, 0)
    }

    private static func signedNumber(_ value: Any?) -> Int64 {
        if let value = value as? NSNumber { return value.int64Value }
        return Int64(string(value)) ?? 0
    }

    private static func optionalNumber(_ value: Any?) -> Int64? {
        guard value != nil, !(value is NSNull) else { return nil }
        return number(value)
    }

    private static func strings(_ value: Any?) -> [String] {
        guard let values = value as? [Any] else { return [] }
        return values.map(string).filter { !$0.isEmpty }
    }

    private static func address(_ host: String, _ port: String) -> String {
        guard !host.isEmpty else { return "" }
        guard !port.isEmpty, port != "0" else { return host }
        if host.hasPrefix("["), host.hasSuffix("]") { return "\(host):\(port)" }
        return host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
    }
}

 
 
 
 
 
 
 
 
 
 
enum ConnectionsRecordingPolicy {
     
     
    static func shouldRecord(
        isForeground: Bool,
        isConnected: Bool
    ) -> Bool {
        isForeground && isConnected
    }
}

protocol ConnectionsClient: AnyObject {
    func connect() throws
    func close()
    func getConnections() throws -> String
    func closeConnection(_ id: String) throws
    func closeConnections() throws
}

typealias ConnectionsClientFactory = (
    _ socketPath: String,
    _ handler: HakoClashAPIClientHandlerProtocol
) throws -> ConnectionsClient

private final class NativeConnectionsClient: ConnectionsClient {
    private let client: HakoClashAPIClient

    init(socketPath: String, handler: HakoClashAPIClientHandlerProtocol) throws {
        let options = HakoClashAPIClientOptions()
        options.statusInterval = 1_000
        options.addCommand(HakoCommandConnections)

        var error: NSError?
        guard let client = HakoNewClashAPIClientWithOptions(
            socketPath,
            handler,
            options,
            &error
        ) else {
            throw error ?? NSError(
                domain: "Hako.Connections",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Connections API unavailable"]
            )
        }
        self.client = client
    }

    func connect() throws {
        try client.connect()
    }

    func close() {
        client.close()
    }

    func getConnections() throws -> String {
        var error: NSError?
        let value = client.getConnections(&error)
        if let error { throw error }
        return value
    }

    func closeConnection(_ id: String) throws {
        try client.closeConnection(id)
    }

    func closeConnections() throws {
        try client.closeConnections()
    }
}

private func defaultConnectionsSocketPath() -> String? {
    HakoAppIdentifiers.appGroupContainer?
    .appendingPathComponent("clash.sock")
    .path
}

private func makeNativeConnectionsClient(
    socketPath: String,
    handler: HakoClashAPIClientHandlerProtocol
) throws -> ConnectionsClient {
    try NativeConnectionsClient(socketPath: socketPath, handler: handler)
}

@MainActor
final class ConnectionsModel: ObservableObject {
    @Published private(set) var activityConnections:
        [HakoConnection]
    @Published private(set) var connected = false
    @Published private(set) var loading = false
    @Published private(set) var error = ""
    @Published private(set) var closing: Set<String> = []
    @Published private(set) var closingAll = false
     
    @Published private(set) var requestLog: [ConnectionHistory.Entry] = []

     
     
    var activeConnectionCount: Int {
        activityConnections.count
    }

    var totalCount: Int { activityConnections.count }

    private var history = ConnectionHistory()

    private var client: ConnectionsClient?
    private var handler: Handler?
    private var generation: UInt64 = 0
    private let socketPath: () -> String?
    private let clientFactory: ConnectionsClientFactory
    private let usesFixtureFeed: Bool



    init(
        seed: [HakoConnection] = [],
        connected: Bool = false,
        loading: Bool = false,
        error: String = "",
        recordsInitialSeed: Bool = false,
        usesFixtureFeed: Bool = false,
        socketPath: @escaping () -> String? = defaultConnectionsSocketPath,
        clientFactory: @escaping ConnectionsClientFactory = makeNativeConnectionsClient
    ) {
        let initialSeed: [HakoConnection]
            initialSeed = seed
        activityConnections = initialSeed
        self.connected =
            false || usesFixtureFeed || connected
        self.loading = loading
        self.error = error
        self.usesFixtureFeed = usesFixtureFeed
        self.socketPath = socketPath
        self.clientFactory = clientFactory
        if false || recordsInitialSeed {
            history.record(initialSeed, at: Date())
            requestLog = history.entries
        }
    }

    private var usesStaticFixtureFeed: Bool {
        false || usesFixtureFeed
    }

     
     
    static var inspectorFixtureSeed: [HakoConnection] {
        [
            HakoConnection(
                id: "ui-1",
                destination: "api.example.test:443",
                source: "10.0.0.2:51842",
                network: "TCP",
                route: "PROXY → Singapore 01",
                rule: "DOMAIN-SUFFIX,example.test",
                upload: 42_128,
                download: 1_802_240,
                start: Date(),
                chains: ["PROXY", "Singapore 01"]
            ),
            HakoConnection(
                id: "ui-2",
                destination: "dns.example.test:53",
                source: "10.0.0.2:53418",
                network: "UDP",
                route: "DIRECT",
                rule: "MATCH",
                upload: 512,
                download: 1_024,
                start: Date().addingTimeInterval(-45),
                chains: ["DIRECT"]
            ),
             
             
             
            HakoConnection(
                id: "ui-3",
                destination: "cdn.example.test:443",
                source: "10.0.0.2:51903",
                network: "TCP",
                route: "PROXY → Tokyo 02",
                rule: "DOMAIN-KEYWORD,cdn",
                upload: 8_940,
                download: 24_500_000,
                start: Date().addingTimeInterval(-182),
                chains: ["PROXY", "Tokyo 02"]
            ),
            HakoConnection(
                id: "ui-4",
                destination: "push.example.test:5223",
                source: "10.0.0.2:52011",
                network: "TCP",
                route: "DIRECT",
                rule: "IP-CIDR,17.0.0.0/8",
                upload: 2_048,
                download: 3_120,
                start: Date().addingTimeInterval(-620),
                chains: ["DIRECT"]
            ),
            HakoConnection(
                id: "ui-5",
                destination: "analytics.example.test:443",
                source: "10.0.0.2:52140",
                network: "TCP",
                route: "REJECT",
                rule: "GEOSITE,ads",
                upload: 0,
                download: 0,
                start: Date().addingTimeInterval(-8),
                chains: ["REJECT"]
            ),
            HakoConnection(
                id: "ui-6",
                destination: "video.example.test:443",
                source: "10.0.0.2:52288",
                network: "TCP",
                route: "PROXY → Silicon Valley 01",
                rule: "DOMAIN-SUFFIX,video.example.test",
                upload: 61_400,
                download: 92_800_000,
                start: Date().addingTimeInterval(-1_450),
                chains: ["PROXY", "Silicon Valley 01"]
            ),
        ]
    }

    func start(commandConnected: Bool) {
        if usesStaticFixtureFeed {
            if connected != commandConnected { connected = commandConnected }
            if loading { loading = false }
            if !error.isEmpty { error = "" }
            return
        }
        guard commandConnected, client == nil else { return }
        guard let socketPath = socketPath() else {
            error = "App Group unavailable"
            return
        }

        generation &+= 1
        let token = generation
        loading = true
        error = ""

        let proxy = Handler(owner: self, token: token)
        handler = proxy

        let newClient: ConnectionsClient
        do {
            newClient = try clientFactory(socketPath, proxy)
        } catch {
            loading = false
            self.error = error.localizedDescription
            handler = nil
            return
        }

        client = newClient
        Task.detached { [weak self] in
            do {
                try newClient.connect()
            } catch {
                await self?.failed(error, token: token)
            }
        }
    }

    func stop() {
        if usesStaticFixtureFeed { return }
        let oldClient = detachNativeSubscription()
        Task.detached { oldClient?.close() }
    }



    private func detachNativeSubscription() -> ConnectionsClient? {
        generation &+= 1
        let oldClient = client
        client = nil
        handler = nil
        connected = false
        loading = false
        closing = []
        closingAll = false
        activityConnections = []
        return oldClient
    }

    func sync(_ commandConnected: Bool) {
        if commandConnected {
            start(commandConnected: true)
        } else if connected || client != nil || loading {
            stop()
        }
    }

    func refresh() async {
        if usesStaticFixtureFeed { return }
        guard let client, !closingAll, closing.isEmpty else { return }
        let token = generation
        do {
            let rows = try await Task.detached {
                ConnectionsParser.parse(try client.getConnections())
            }.value
            guard token == generation else { return }
            apply(rows)
        } catch {
            guard token == generation else { return }
            self.error = error.localizedDescription
        }
    }

    func close(_ id: String) async {
        if usesStaticFixtureFeed {
            activityConnections.removeAll { $0.id == id }
            return
        }
        guard let client, !closingAll, !closing.contains(id) else { return }
        let token = generation
        closing.insert(id)
        defer { closing.remove(id) }
        do {
            try await Task.detached { try client.closeConnection(id) }.value
            guard token == generation else { return }
            activityConnections.removeAll { $0.id == id }
        } catch {
            guard token == generation else { return }
            self.error = error.localizedDescription
        }
    }

    func closeAll() async {
        if usesStaticFixtureFeed {
            activityConnections = []
            return
        }
        guard let client, !closingAll, closing.isEmpty else { return }
        let token = generation
        closingAll = true
        defer { closingAll = false }
        do {
            try await Task.detached { try client.closeConnections() }.value
            guard token == generation else { return }
            activityConnections = []
        } catch {
            guard token == generation else { return }
            self.error = error.localizedDescription
        }
    }

    private func apply(_ value: [HakoConnection]) {
        activityConnections = value
        loading = false
        error = ""
        history.record(value, at: Date())
        requestLog = history.entries
    }

    private func didConnect(token: UInt64) {
        guard token == generation else { return }
        connected = true
    }

    private func failed(_ value: Error, token: UInt64) {
        guard token == generation else { return }
        let oldClient = client
        client = nil
        handler = nil
        connected = false
        loading = false
        closing = []
        closingAll = false
        activityConnections = []
        error = value.localizedDescription
        Task.detached { oldClient?.close() }
    }

    private final class Handler: NSObject, HakoClashAPIClientHandlerProtocol {
        weak var owner: ConnectionsModel?
        let token: UInt64

        init(owner: ConnectionsModel, token: UInt64) {
            self.owner = owner
            self.token = token
        }

        func connected() {
            Task { @MainActor [weak owner] in owner?.didConnect(token: token) }
        }

        func disconnected(_ message: String?) {
            Task { @MainActor [weak owner] in
                owner?.failed(
                    NSError(
                        domain: "Hako.Connections",
                        code: 1,
                        userInfo: [
                            NSLocalizedDescriptionKey: message ?? "Connections stream disconnected",
                        ]
                    ),
                    token: token
                )
            }
        }

        func writeConnections(_ message: String?) {
            guard let message else { return }
            let rows = ConnectionsParser.parse(message)
            Task { @MainActor [weak owner] in
                guard owner?.generation == token else { return }
                owner?.apply(rows)
            }
        }

        func writeTraffic(_: String?) {}
        func writeMemory(_: String?) {}
        func writeLogs(_: String?) {}
        func writeMode(_: String?) {}
    }
}


