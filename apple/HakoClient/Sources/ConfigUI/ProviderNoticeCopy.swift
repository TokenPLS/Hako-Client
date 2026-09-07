import Foundation
import HakoClientUI

 
 
 
 
 
 
 
 
 
enum ProviderNoticeCopy {
     
    static func summary(count: Int) -> HakoDisplayText {
        .format("%@ affected.", [String(count)])
    }

     
     
     
    static func changedList(_ keys: [String], locale: Locale) -> String {
        keys.map { key in
            if key.hasPrefix("payload.") {
                return HakoCopy.format("node %@", locale: locale, String(key.dropFirst("payload.".count)))
            }
            return key
        }.joined(separator: ", ")
    }

     
     
    static func line(for notice: ProviderDefinitionMergeNotice, locale: Locale = .current) -> HakoDisplayText {
        switch notice.reason {
        case .keyConflict(let key, let mineJSON, let theirsJSON):
            return .format(
                "You set %@ to %@; the subscription now says %@. Yours is kept.",
                [key, mineJSON, theirsJSON]
            )
        case .nameCollision:
            return .copy("The subscription now has a source with this name too; your keys were merged over it.")
        case .legacyUnfrozen(let differingKeys):
             
             
             
             
            return .format(
                "%@ had been held to an older copy of the subscription and now follows it again. Changed with that: %@. If any of these was your own edit, set it again.",
                [notice.provider, changedList(differingKeys, locale: locale)]
            )
        case .baselineRemoved:
            return .copy("The subscription no longer has this source; your edit of it was dropped.")
        case .payloadNodeRemoved(let node):
            return .format(
                "The subscription no longer has the node %@; the dialer you set on it was dropped.",
                [node]
            )
        }
    }
}
