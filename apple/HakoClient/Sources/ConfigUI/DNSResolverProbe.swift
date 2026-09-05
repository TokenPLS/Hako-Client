import Foundation
import HakoClientUI
import Network

typealias DNSResolverPreset = HakoDNSResolverPreset
typealias DNSResolverCatalog = HakoDNSResolverCatalog

 
 
struct DNSResolverEndpoint: Equatable {
    enum Transport: String, Equatable {
        case udp, tcp, tls, https, quic
    }

    let transport: Transport
    let host: String
    let port: UInt16
     
    let path: String

     
    var protocolLabel: String {
        switch transport {
        case .https: return "DoH"
        case .tls: return "DoT"
        case .quic: return "DoQ"
        case .udp: return "UDP"
        case .tcp: return "TCP"
        }
    }
}

typealias DNSResolverProbeOutcome = HakoDNSResolverOutcome

enum DNSResolverProbe {
     
     
     
     
     
    static func endpoint(for address: String) -> DNSResolverEndpoint? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !DNSServerValidator.isStrippedOnIOS(trimmed) else {
            return nil
        }
         
         
        var rest = trimmed
        if let hash = rest.firstIndex(of: "#") {
            rest = String(rest[..<hash])
        }

        var transport: DNSResolverEndpoint.Transport = .udp
        if let range = rest.range(of: "://") {
            let scheme = String(rest[..<range.lowerBound]).lowercased()
            guard let parsed = DNSResolverEndpoint.Transport(rawValue: scheme) else {
                return nil
            }
            transport = parsed
            rest = String(rest[range.upperBound...])
        }

        var path = "/dns-query"
        if let slash = rest.firstIndex(of: "/") {
            let tail = String(rest[slash...])
            if transport == .https, tail.count > 1 { path = tail }
            rest = String(rest[..<slash])
        }
        guard !rest.isEmpty else { return nil }

        var host = rest
        var port: UInt16 = defaultPort(for: transport)
        if rest.hasPrefix("[") {
            guard let close = rest.firstIndex(of: "]") else { return nil }
            host = String(rest[rest.index(after: rest.startIndex)..<close])
            let after = rest[rest.index(after: close)...]
            if after.hasPrefix(":"), let parsed = UInt16(after.dropFirst()) {
                port = parsed
            }
        } else if rest.filter({ $0 == ":" }).count == 1,
                  let colon = rest.lastIndex(of: ":"),
                  let parsed = UInt16(rest[rest.index(after: colon)...]) {
            host = String(rest[..<colon])
            port = parsed
        }
        guard !host.isEmpty else { return nil }
        return DNSResolverEndpoint(transport: transport, host: host, port: port, path: path)
    }

    static func defaultPort(for transport: DNSResolverEndpoint.Transport) -> UInt16 {
        switch transport {
        case .udp, .tcp: return 53
        case .tls, .quic: return 853
        case .https: return 443
        }
    }

     
    static func untestableReason(for address: String) -> String? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Enter an address first." }
        if DNSServerValidator.isStrippedOnIOS(trimmed) {
            return "iOS strips system and dhcp resolvers, so there is nothing to reach."
        }
        if endpoint(for: trimmed) == nil {
            return "This address cannot be parsed as a resolver."
        }
        return nil
    }

     
     
     
    static func queryMessage(id: UInt16, name: String = "example.com") -> Data {
        var data = Data()
        data.append(contentsOf: [UInt8(id >> 8), UInt8(id & 0xFF)])
        data.append(contentsOf: [0x01, 0x00])               
        data.append(contentsOf: [0x00, 0x01])               
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        for label in name.split(separator: ".") {
            data.append(UInt8(label.utf8.count))
            data.append(contentsOf: Array(label.utf8))
        }
        data.append(0x00)
        data.append(contentsOf: [0x00, 0x01, 0x00, 0x01])  
        return data
    }

     
     
    static func isAnswer(_ data: Data, id: UInt16) -> Bool {
        guard data.count >= 12 else { return false }
        let bytes = [UInt8](data)
        let replyID = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        let isResponse = bytes[2] & 0x80 != 0
        let questions = UInt16(bytes[4]) << 8 | UInt16(bytes[5])
        return replyID == id && isResponse && questions >= 1
    }
}

 
 
 
 
actor DNSResolverReachability {
    static let shared = DNSResolverReachability()

    private let timeout: TimeInterval = 4

    func probe(_ address: String) async -> DNSResolverProbeOutcome {
        if let reason = DNSResolverProbe.untestableReason(for: address) {
            return .notTestable(reason: reason)
        }
        guard let endpoint = DNSResolverProbe.endpoint(for: address) else {
            return .notTestable(reason: "This address cannot be parsed as a resolver.")
        }
        let id = UInt16.random(in: 1 ... UInt16.max)
        let query = DNSResolverProbe.queryMessage(id: id)
        let started = Date()
        switch endpoint.transport {
        case .https:
            return await probeOverHTTPS(endpoint, query: query, id: id, started: started)
        case .udp, .tcp, .tls, .quic:
            return await probeOverConnection(endpoint, query: query, id: id, started: started)
        }
    }

    private func elapsed(_ started: Date) -> Int {
        max(1, Int(Date().timeIntervalSince(started) * 1000))
    }

    private func probeOverHTTPS(
        _ endpoint: DNSResolverEndpoint,
        query: Data,
        id: UInt16,
        started: Date
    ) async -> DNSResolverProbeOutcome {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpoint.host
        components.port = endpoint.port == 443 ? nil : Int(endpoint.port)
        components.path = endpoint.path
        guard let url = components.url else {
            return .notTestable(reason: "This address cannot be parsed as a resolver.")
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = query
        request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return .invalidReply
            }
            return DNSResolverProbe.isAnswer(data, id: id)
                ? .reachable(milliseconds: elapsed(started))
                : .invalidReply
        } catch let error as URLError {
            switch error.code {
            case .timedOut, .cannotConnectToHost where error.failureURLString == nil:
                return .timedOut
            case .cannotConnectToHost, .networkConnectionLost:
                return .refused
            case .secureConnectionFailed, .serverCertificateUntrusted,
                 .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid:
                return .handshakeFailed
            default:
                return .timedOut
            }
        } catch {
            return .timedOut
        }
    }

    private func probeOverConnection(
        _ endpoint: DNSResolverEndpoint,
        query: Data,
        id: UInt16,
        started: Date
    ) async -> DNSResolverProbeOutcome {
        let parameters: NWParameters
        switch endpoint.transport {
        case .udp:
            parameters = .udp
        case .tcp:
            parameters = .tcp
        case .tls:
            parameters = .tls
        case .quic:
            if #available(iOS 15.0, *) {
                let options = NWProtocolQUIC.Options(alpn: ["doq"])
                parameters = NWParameters(quic: options)
            } else {
                return .notTestable(reason: "DoQ needs iOS 15 or later.")
            }
        case .https:
            return .notTestable(reason: "handled over HTTPS")
        }
        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
            return .notTestable(reason: "This address cannot be parsed as a resolver.")
        }
         
        let payload: Data
        switch endpoint.transport {
        case .udp:
            payload = query
        default:
            var framed = Data([UInt8(query.count >> 8), UInt8(query.count & 0xFF)])
            framed.append(query)
            payload = framed
        }
        let connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: port,
            using: parameters
        )
        let transport = endpoint.transport
        return await withCheckedContinuation { continuation in
            let box = ProbeContinuationBox(continuation: continuation)
            let queue = DispatchQueue(label: "org.example.hako.dns-probe")
            queue.asyncAfter(deadline: .now() + timeout) {
                box.finish(.timedOut) { connection.cancel() }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if error != nil {
                            box.finish(.refused) { connection.cancel() }
                            return
                        }
                        let deliver: (Data?) -> Void = { body in
                            guard let body, !body.isEmpty else {
                                box.finish(.invalidReply) { connection.cancel() }
                                return
                            }
                            let outcome: DNSResolverProbeOutcome =
                                DNSResolverProbe.isAnswer(body, id: id)
                                    ? .reachable(milliseconds: max(1, Int(
                                        Date().timeIntervalSince(started) * 1000
                                    )))
                                    : .invalidReply
                            box.finish(outcome) { connection.cancel() }
                        }
                        switch transport {
                        case .udp:
                            connection.receiveMessage { data, _, _, receiveError in
                                deliver(receiveError == nil ? data : nil)
                            }
                        case .quic:
                             
                             
                            connection.receiveMessage { data, _, _, receiveError in
                                guard receiveError == nil, let data, data.count > 2 else {
                                    deliver(nil)
                                    return
                                }
                                deliver(data.dropFirst(2))
                            }
                        default:
                             
                             
                             
                             
                             
                            Self.receiveFramedAnswer(
                                connection, accumulated: Data(), completion: deliver
                            )
                        }
                    })
                case .failed(let error):
                    let outcome: DNSResolverProbeOutcome
                    switch error {
                    case .posix(.ECONNREFUSED), .posix(.EHOSTUNREACH), .posix(.ENETUNREACH):
                        outcome = .refused
                    case .tls:
                        outcome = .handshakeFailed
                    default:
                        outcome = .timedOut
                    }
                    box.finish(outcome) { connection.cancel() }
                case .waiting(let error):
                     
                     
                     
                    if case .tls = error {
                        box.finish(.handshakeFailed) { connection.cancel() }
                    }
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

     
     
    private nonisolated static func receiveFramedAnswer(
        _ connection: NWConnection,
        accumulated: Data,
        completion: @escaping (Data?) -> Void
    ) {
        if accumulated.count >= 2 {
            let prefix = [UInt8](accumulated.prefix(2))
            let need = Int(prefix[0]) << 8 | Int(prefix[1])
            if need > 0, accumulated.count - 2 >= need {
                completion(Data(accumulated.dropFirst(2).prefix(need)))
                return
            }
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) {
            chunk, _, isComplete, error in
            if error != nil {
                completion(nil)
                return
            }
            var next = accumulated
            if let chunk { next.append(chunk) }
            if isComplete, chunk?.isEmpty != false {
                completion(nil)
                return
            }
            receiveFramedAnswer(connection, accumulated: next, completion: completion)
        }
    }
}

 
 
private final class ProbeContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<DNSResolverProbeOutcome, Never>?

    init(continuation: CheckedContinuation<DNSResolverProbeOutcome, Never>) {
        self.continuation = continuation
    }

    func finish(_ outcome: DNSResolverProbeOutcome, cleanup: () -> Void) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return }
        cleanup()
        pending.resume(returning: outcome)
    }
}
