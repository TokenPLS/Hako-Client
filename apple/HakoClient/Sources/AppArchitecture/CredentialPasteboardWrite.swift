import Foundation
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

 
 
 
 
 
 
 
 
enum CredentialPasteboardWrite {
    static func options(
        now: Date,
        lifetime: TimeInterval
    ) -> [UIPasteboard.OptionsKey: Any] {
        [
            .expirationDate: now.addingTimeInterval(lifetime),
            .localOnly: true,
        ]
    }

    static func put(_ value: String, lifetime: TimeInterval = 60) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: value]],
            options: options(now: Date(), lifetime: lifetime)
        )
    }
}
#endif
