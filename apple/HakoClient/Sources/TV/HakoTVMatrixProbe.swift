import Foundation

 
 
 
struct HakoTVProbeSpec: Equatable {
    struct TCP: Equatable { let host: String; let port: Int; let payload: String }
    struct UDP: Equatable { let host: String; let port: Int; let payload: String; let attempts: Int }
    struct DNS: Equatable { let name: String; let connectPort: Int? }

    let label: String
    let tcp: TCP?
    let udp: UDP?
    let dns: DNS?

    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let label = root["label"] as? String
        else { return nil }
        self.label = label
        if let leg = root["tcp"] as? [String: Any],
           let host = leg["host"] as? String, let port = leg["port"] as? Int,
           let payload = leg["payload"] as? String {
            tcp = TCP(host: host, port: port, payload: payload)
        } else { tcp = nil }
        if let leg = root["udp"] as? [String: Any],
           let host = leg["host"] as? String, let port = leg["port"] as? Int,
           let payload = leg["payload"] as? String {
             
            udp = UDP(host: host, port: port, payload: payload, attempts: leg["attempts"] as? Int ?? 3)
        } else { udp = nil }
        if let leg = root["dns"] as? [String: Any], let name = leg["name"] as? String {
            dns = DNS(name: name, connectPort: leg["connectPort"] as? Int)
        } else { dns = nil }
    }
}

 
 
 
 
 
 
struct HakoTVMatrixDiagnostics {
     
     
    static let counterKeys = [
        "packetFlowPacketsToCore", "packetFlowPacketsToSystem",
        "packetFlowBytesToCore", "packetFlowBytesToSystem",
        "packetFlowDroppedToCore", "packetFlowDroppedToSystem",
        "packetFlowPendingPackets", "packetFlowPendingBytes",
    ]

    let raw: [String: Any]
    let counters: [String: Int64]
    let gvisorKeysPresent: Bool
    let gvisorTCPConnections: Int64?
    let availableMemoryBytes: Int64?
    let physicalMemoryBytes: Int64?

    init?(data: Data) {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        raw = root
        var counters: [String: Int64] = [:]
        for key in Self.counterKeys {
            if let value = root[key] as? NSNumber { counters[key] = value.int64Value }
        }
        self.counters = counters
        let gvisorKeys = root.keys.filter { $0.hasPrefix("gvisorTCPWindow") }
        gvisorKeysPresent = !gvisorKeys.isEmpty
        gvisorTCPConnections = (root["gvisorTCPWindowConnections"] as? NSNumber)?.int64Value
        availableMemoryBytes = (root["availableMemoryBytes"] as? NSNumber)?.int64Value
        physicalMemoryBytes = (root["physicalMemoryBytes"] as? NSNumber)?.int64Value
    }

     
     
    func counterDeltas(since before: HakoTVMatrixDiagnostics) -> [String: Int64] {
        var deltas: [String: Int64] = [:]
        for (key, value) in counters {
            if let earlier = before.counters[key] { deltas[key] = value - earlier }
        }
        return deltas
    }
}


