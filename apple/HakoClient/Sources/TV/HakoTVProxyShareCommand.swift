import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
final class HakoTVProxyShareCommand: ObservableObject, ProxyShareCommanding {
     
     
     
    typealias Envelope = @MainActor ([String: Any]) async throws -> Data

    private let envelope: Envelope
    private let isConnected: @MainActor () -> Bool

    init(send: @escaping Envelope, isConnected: @escaping @MainActor () -> Bool) {
        self.envelope = send
        self.isConnected = isConnected
    }

    var proxyShareAPIReady: Bool { isConnected() }
    var proxyShareAPIClientReady: Bool { isConnected() }

    func fetchProxyShareStatus() async throws -> ProxyShareStatus {
        try await ask(["cmd": "proxyShareStatus"])
    }

    func startProxyShare(_ configuration: ProxyShareConfiguration) async throws -> ProxyShareStatus {
        try await ask([
            "cmd": "proxyShareStart",
             
             
             
             
             
            "port": configuration.port,
            "username": configuration.username,
            "password": configuration.password,
        ])
    }

    func stopProxyShare() async throws -> ProxyShareStatus {
        try await ask(["cmd": "proxyShareStop"])
    }

     
     
     
     
     
     
     
     
    private func ask(_ message: [String: Any]) async throws -> ProxyShareStatus {
        guard isConnected() else { throw ProxyShareError.apiUnavailable }
        let reply = try await envelope(message)
        let root = try? JSONSerialization.jsonObject(with: reply) as? [String: Any]
        guard let root else { throw ProxyShareError.invalidResponse }
        if let refusal = root["error"] as? String {
            throw NSError(
                domain: "HakoTV.ProxyShare",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: refusal]
            )
        }
        guard root["ok"] as? Bool == true,
              let status = root["status"],
              let document = try? JSONSerialization.data(withJSONObject: status),
              let json = String(data: document, encoding: .utf8)
        else { throw ProxyShareError.invalidResponse }
        return try ProxyShareStatusParser.parse(json)
    }
}


