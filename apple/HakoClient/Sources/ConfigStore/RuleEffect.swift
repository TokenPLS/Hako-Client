import Foundation
import Hako

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum RuleEffect {
     
     
     
     
     
     
     
    case neverMatches
    case matchesEverything
     
     
    case unjudged

    static func of(_ rule: String) -> RuleEffect {
        switch HakoRuleEffectForIOS(rule) {
        case HakoRuleEffectNeverMatches: .neverMatches
        case HakoRuleEffectMatchesEverything: .matchesEverything
        default: .unjudged
        }
    }

     
     
     
    static func neverMatches(_ rule: String) -> Bool {
        of(rule) == .neverMatches
    }
}
