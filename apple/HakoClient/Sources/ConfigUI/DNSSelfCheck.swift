import Foundation
import HakoClientUI

typealias DNSPreSaveCheck = HakoDNSPreSaveCheck

 
enum DNSRuntimeSelfCheck {
    private static let probeName = "www.apple.com"

    static func run(
        using command: ClashCommandClient
    ) async -> HakoDNSSelfCheckOutcome {
        guard await command.isConnected else {
            return .notConnected
        }
        let started = Date()
        let answer = await command.runDNSQuery(
            name: probeName,
            type: "A"
        )
        let elapsed = max(
            1,
            Int(Date().timeIntervalSince(started) * 1_000)
        )
        guard let answer, !answer.isEmpty else {
            return .noAnswer(
                detail: "The core did not return an address."
            )
        }
        let hasRecord =
            answer.contains("\"data\"")
            || answer.contains("\"Answer\"")
        return hasRecord
            ? .answered(
                name: probeName,
                milliseconds: elapsed
            )
            : .noAnswer(
                detail: "The reply carried no address."
            )
    }
}
