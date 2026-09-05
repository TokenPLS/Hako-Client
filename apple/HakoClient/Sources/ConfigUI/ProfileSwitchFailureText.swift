import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 
enum ProfileSwitchFailureText {
     
     
     
     
    static func cardText(
        for failure: ConfigurationFailure,
        locale: Locale = .current
    ) -> String {
        let failures = failure.providerFailures
        guard !failures.isEmpty else {
             
             
             
             
             
             
             
             
             
            return failure.displayMessage.resolved(locale: locale)
        }
        var lines = failures.map { detailLine($0, locale: locale) }
        if failure.kind == .kernelRejected {
             
             
            return lines.map { "\($0)\n\(failure.message)" }
                .joined(separator: "\n")
        }
        lines.append(HakoCopy.string(
            "Check the network and the source addresses, then try again.",
            locale: locale
        ))
        return lines.joined(separator: "\n")
    }

     
     
    static func detailLine(
        _ line: ProviderFailureLine,
        locale: Locale = .current
    ) -> String {
        let reason = shortReason(for: line.kind, locale: locale)
        guard let host = line.url, !host.isEmpty else {
            return HakoCopy.format(
                "Provider “%@” — %@",
                locale: locale,
                line.name,
                reason
            )
        }
        return HakoCopy.format(
            "Provider “%@” (%@) — %@",
            locale: locale,
            line.name,
            host,
            reason
        )
    }


     
     
    private static func shortReason(
        for kind: ConfigurationFailureKind,
        locale: Locale
    ) -> String {
        if case .httpStatus(let status) = kind {
            return HakoCopy.format(
                "The server returned HTTP %@",
                locale: locale,
                String(status)
            )
        }
        return HakoCopy.string(
            ConfigurationFailureClassifier.catalogTitle(for: kind),
            locale: locale
        )
    }

}

 
 
 
 
 
struct ProfileSwitchAlertFailure: LocalizedError {
    let titleText: String
    let messageText: String

    var errorDescription: String? { titleText }

    init(_ failure: ConfigurationFailure, locale: Locale = .current) {
        titleText = HakoCopy.string(failure.title, locale: locale)
        messageText = ProfileSwitchFailureText.cardText(
            for: failure, locale: locale
        )
    }
}
