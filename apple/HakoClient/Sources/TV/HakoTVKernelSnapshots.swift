import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
enum HakoTVKernelSnapshots {
     
     
     
     
     
     
     
    static func urlTestDelay(from reply: Data?) throws -> Int {
        guard let reply,
              let object = try JSONSerialization.jsonObject(with: reply) as? [String: Any],
              let delay = object["delay"] as? Int
        else { return -1 }
        return delay
    }

    enum DecodingError: LocalizedError {
        case notAnObject(String)
        case kernelError(String)

        var errorDescription: String? {
            switch self {
            case .notAnObject(let what): "The tunnel's \(what) reply was not in the expected shape."
            case .kernelError(let message): message
            }
        }
    }

    struct Proxies: Equatable {
        let groups: [HakoProxyGroupSnapshot]
        let latency: [String: HakoProxyLatencyState]
         
        let nodeCount: Int
    }

    struct Traffic: Equatable {
        let up: Int64
        let down: Int64
        let upTotal: Int64
        let downTotal: Int64
        let memory: Int64
    }

    struct Status: Equatable {
        let status: String
        let mode: String
    }

    private static func object(_ data: Data, what: String) throws -> [String: Any] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodingError.notAnObject(what)
        }
        if let error = root["error"] as? String, root.count == 1 {
            throw DecodingError.kernelError(error)
        }
        return root
    }

     
     
     
     
     
     
    static func proxies(from data: Data, groupOrder: [String]) throws -> Proxies {
        let root = try object(data, what: "proxies")
        guard let entries = root["proxies"] as? [String: [String: Any]] else {
            throw DecodingError.notAnObject("proxies")
        }
        func isGroup(_ name: String) -> Bool { entries[name]?["all"] is [Any] }
        func type(of name: String) -> String { entries[name]?["type"] as? String ?? "" }

        var latency: [String: HakoProxyLatencyState] = [:]
        for (name, entry) in entries {
            guard let history = entry["history"] as? [[String: Any]], let last = history.last else { continue }
            let delay = (last["delay"] as? NSNumber)?.intValue ?? 0
            latency[name] = delay > 0 ? .measured(milliseconds: delay) : .failed
        }

        let groupNames = entries.keys.filter { isGroup($0) && entries[$0]?["hidden"] as? Bool != true }
        let ordered = groupOrder.filter { groupNames.contains($0) }
            + groupNames.filter { !groupOrder.contains($0) && $0 != "GLOBAL" }.sorted()
            + (groupNames.contains("GLOBAL") ? ["GLOBAL"] : [])
        let groups = ordered.compactMap { name -> HakoProxyGroupSnapshot? in
            guard let entry = entries[name], let all = entry["all"] as? [String] else { return nil }
            let members = all.map { member in
                HakoProxyMemberSnapshot(name: member, type: type(of: member), isGroup: isGroup(member))
            }
            return HakoProxyGroupSnapshot(
                name: name,
                type: entry["type"] as? String ?? "",
                members: members,
                runtimeSelection: entry["now"] as? String
            )
        }
         
         
         
        let builtIn: Set<String> = ["DIRECT", "REJECT", "REJECT-DROP", "PASS", "PASS-RULE", "COMPATIBLE"]
        let nodeCount = entries.keys.filter { !isGroup($0) && !builtIn.contains($0) }.count
        return Proxies(groups: groups, latency: latency, nodeCount: nodeCount)
    }

     
     
     
     
     
    static func connections(from data: Data) throws -> [HakoActivityConnectionSnapshot] {
        let root = try object(data, what: "connections")
         
         
         
        let list: [[String: Any]]
        if let array = root["connections"] as? [[String: Any]] {
            list = array
        } else if root["connections"] is NSNull || (root["connections"] == nil && root["downloadTotal"] != nil) {
            list = []
        } else {
            throw DecodingError.notAnObject("connections")
        }
        return list.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            let metadata = entry["metadata"] as? [String: Any] ?? [:]
            let host = metadata["host"] as? String ?? ""
            let destinationIP = metadata["destinationIP"] as? String ?? ""
            let destinationPort = metadata["destinationPort"] as? String ?? ""
            let sourceIP = metadata["sourceIP"] as? String ?? ""
            let sourcePort = metadata["sourcePort"] as? String ?? ""
            let network = (metadata["network"] as? String ?? "").uppercased()
            let chains = entry["chains"] as? [String] ?? []
            let destination = Self.endpoint(host.isEmpty ? destinationIP : host, port: destinationPort)
            let source = Self.endpoint(sourceIP, port: sourcePort)
            return HakoActivityConnectionSnapshot(
                id: id,
                destination: destination,
                source: source,
                network: network,
                route: chains.joined(separator: " → "),
                rule: entry["rule"] as? String ?? "",
                upload: (entry["upload"] as? NSNumber)?.int64Value ?? 0,
                download: (entry["download"] as? NSNumber)?.int64Value ?? 0,
                start: (entry["start"] as? String).flatMap(Self.date(from:)),
                host: host,
                sourceIP: sourceIP,
                sourcePort: sourcePort,
                destinationIP: destinationIP,
                destinationPort: destinationPort,
                dnsMode: metadata["dnsMode"] as? String ?? "",
                chains: chains,
                rulePayload: entry["rulePayload"] as? String ?? ""
            )
        }
    }

    static func traffic(from data: Data) throws -> Traffic {
        let root = try object(data, what: "traffic")
        guard let up = root["up"] as? NSNumber, let down = root["down"] as? NSNumber else {
            throw DecodingError.notAnObject("traffic")
        }
        return Traffic(
            up: up.int64Value,
            down: down.int64Value,
            upTotal: (root["upTotal"] as? NSNumber)?.int64Value ?? 0,
            downTotal: (root["downTotal"] as? NSNumber)?.int64Value ?? 0,
            memory: (root["memory"] as? NSNumber)?.int64Value ?? 0
        )
    }

    static func status(from data: Data) throws -> Status {
        let root = try object(data, what: "status")
        guard let status = root["status"] as? String else { throw DecodingError.notAnObject("status") }
        return Status(status: status, mode: root["mode"] as? String ?? "")
    }

     
     
    static func endpoint(_ host: String, port: String) -> String {
        guard !port.isEmpty else { return host }
        let needsBrackets = host.contains(":") && !host.hasPrefix("[")
        return needsBrackets ? "[\(host)]:\(port)" : "\(host):\(port)"
    }

     
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let whole = ISO8601DateFormatter()

    static func date(from text: String) -> Date? {
        fractional.date(from: text) ?? whole.date(from: text)
    }
}
