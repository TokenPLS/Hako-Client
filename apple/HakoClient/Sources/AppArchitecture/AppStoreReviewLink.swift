import Foundation
#if canImport(StoreKit) && canImport(UIKit)
import StoreKit
import UIKit
#endif

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum AppStoreReviewLink {
    static let infoKey = "HakoAppStoreItemID"

    static var isConfigured: Bool { isConfigured(bundle: .main) }

     
     
     
    static func isConfigured(bundle: Bundle) -> Bool {
        guard let raw = bundle.object(forInfoDictionaryKey: infoKey) as? String
        else { return false }
        let identifier = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return !identifier.isEmpty && identifier.allSatisfy(\.isNumber)
    }

     
    @MainActor
    static func requestReview() {
#if canImport(StoreKit) && canImport(UIKit)
         
         
         
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(
            where: { $0.activationState == .foregroundActive }
        ) ?? scenes.first else { return }
        if #available(iOS 16.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
#endif
    }
}
