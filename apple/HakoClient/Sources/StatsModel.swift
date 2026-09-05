import Combine
import Foundation
import NetworkExtension

struct EgressLookupResult: Equatable {
    let address: String
    let countryName: String
    let countryCode: String
    let provider: String

    static func decode(_ data: Data) -> EgressLookupResult? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let address = object["ip"] as? String,
              !address.isEmpty
        else { return nil }
        let countryName = object["country"] as? String ?? ""
        let countryCode = (object["country_code"] as? String ?? "").uppercased()
        let isp = object["isp"] as? String
            ?? object["asn_organization"] as? String
            ?? object["organization"] as? String
            ?? "?"
        let asn: Int? = {
            if let value = object["asn"] as? Int { return value }
            if let value = object["asn"] as? NSNumber { return value.intValue }
            return nil
        }()
        return EgressLookupResult(
            address: address,
            countryName: countryName,
            countryCode: countryCode,
            provider: asn.map { "\(isp) · AS\($0)" } ?? isp)
    }

    static func flagEmoji(countryCode: String) -> String {
        let code = countryCode.uppercased()
        guard code.count == 2,
              code.unicodeScalars.allSatisfy({ (65...90).contains(Int($0.value)) })
        else { return "" }
        return String(String.UnicodeScalarView(code.unicodeScalars.compactMap {
            UnicodeScalar(127_397 + $0.value)
        }))
    }
}

 
 
@MainActor
final class StatsModel: ObservableObject {
    @Published var egressIP: String = "—"
    @Published var egressISP: String = "—"
    @Published var egressCountryName: String = "—"
    @Published var egressCountryCode: String = ""

    private var session: NETunnelProviderSession?
    private var command: ClashCommandClient?

    func bind(session: NETunnelProviderSession?, command: ClashCommandClient) {
        self.session = session
        self.command = command
    }

    @discardableResult
    func checkEgressIP() async -> Bool {
        await checkEgressIP(attempt: 1)
    }

    private func checkEgressIP(attempt: Int) async -> Bool {
        egressIP = "checking…"
        egressISP = "…"
        egressCountryName = "…"
        egressCountryCode = ""
        guard isVPNActive, command?.isConnected == true else {
            egressIP = "VPN not connected"
            egressISP = "—"
            egressCountryName = "—"
            return false
        }
        guard let url = URL(string: "https://api.ip.sb/geoip") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        do {
            let (data, _) = try await OneShotHTTPSession.data(for: request)
            if let result = EgressLookupResult.decode(data) {
                egressIP = result.address
                egressISP = result.provider
                egressCountryName = result.countryName.isEmpty ? result.countryCode : result.countryName
                egressCountryCode = result.countryCode
                return true
            } else {
                egressIP = "unexpected response"
                egressISP = "—"
                egressCountryName = "—"
                egressCountryCode = ""
                return false
            }
        } catch {
             
             
             
             
            if EgressRetryPolicy.shouldRetry(after: error, attempt: attempt) {
                return await checkEgressIP(attempt: attempt + 1)
            }
            egressIP = "error: \(error.localizedDescription)"
            egressISP = "—"
            egressCountryName = "—"
            egressCountryCode = ""
            return false
        }
    }

    private var isVPNActive: Bool {
        session?.status == .connected || session?.status == .reasserting
    }
}

 
 
 
 
 
 
 
 
 
enum OneShotHTTPSession {
    static func data(
        for request: URLRequest,
        configuration: URLSessionConfiguration = .ephemeral,
        delegate: URLSessionDelegate? = nil
    ) async throws -> (Data, URLResponse) {
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }
        return try await session.data(for: request)
    }
}

 
 
 
 
 
enum EgressRetryPolicy {
    static let maximumAttempts = 2

    static func shouldRetry(after error: Error, attempt: Int) -> Bool {
        guard attempt < maximumAttempts else { return false }
        guard let urlError = error as? URLError else { return false }
        return urlError.code == .timedOut
    }
}
