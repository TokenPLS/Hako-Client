import Foundation
import HakoClientUI

 
 
 
 
enum OverrideRuleValidator {
     
     
    static func disallowReason(
        _ rule: String,
        runtimeProfile: HakoAppleRuntimeProfile =
            hakoAppleRuntimeProfile
    ) -> String? {
        StructuredRule.disallowReason(
            rule,
            runtimeProfile: runtimeProfile
        )
    }

    static func isAllowed(
        _ rule: String,
        runtimeProfile: HakoAppleRuntimeProfile =
            hakoAppleRuntimeProfile
    ) -> Bool {
        disallowReason(
            rule,
            runtimeProfile: runtimeProfile
        ) == nil
    }
}
