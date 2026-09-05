import Foundation
import Hako

struct PreflightOutcome {
    let ok: Bool
    let intentJSON: String?
    let errorMessage: String?
}

 
 
 
enum PreflightService {
    static func check(finalYAML: String) -> PreflightOutcome {
        var checkError: NSError?
        let ok = HakoCheckConfig(finalYAML, &checkError)
        guard ok, checkError == nil else {
            return PreflightOutcome(
                ok: false, intentJSON: nil,
                errorMessage: checkError?.localizedDescription ?? "config check failed")
        }
        var intentError: NSError?
        guard let box = HakoPlatformConfigIntentJSON(finalYAML, &intentError) else {
            return PreflightOutcome(
                ok: false, intentJSON: nil,
                errorMessage: intentError?.localizedDescription ?? "intent extraction failed")
        }
        return PreflightOutcome(ok: true, intentJSON: box.value, errorMessage: nil)
    }
}
