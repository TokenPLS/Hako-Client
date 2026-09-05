import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
@MainActor
public enum HakoNavigationHooks {
    public static var pop: (() -> Void)?
     
     
    public static var resignCurrentField: (() -> Void)?
}

enum HakoNavigationTransaction {
     
     
     
     
     
     
     
    @MainActor
    static func resignCurrentField() {
#if os(macOS)
        HakoNavigationHooks.resignCurrentField?()
#endif
    }

    static var instantOnMac: Transaction {
        var transaction = Transaction()
#if os(macOS)
        transaction.disablesAnimations = true
        transaction.animation = nil
#endif
        return transaction
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @MainActor
    static func applyPathChange(_ apply: @escaping @MainActor () -> Void) {
#if os(macOS)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                withTransaction(instantOnMac, apply)
            }
        }
#else
        apply()
#endif
    }

     
     
     
     
     
     
     
    @MainActor
    @available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
    static func interceptRootSelection(
        isCurrentRoot: Bool,
        hasPresentedPath: Bool,
        clearPresentedPath: () -> Void
    ) -> Bool {
         
         
         
         
        if HakoPlatformLayout.regularShellKeepsContainer {
            if isCurrentRoot {
                guard hasPresentedPath else { return true }
                HakoViewRouteRegistry.discardAll()
                clearPresentedPath()
                return true
            }
            HakoViewRouteRegistry.discardAll()
        }
        return false
    }
}

 
 
 
 
 
enum HakoPushedCanvasOwnership {
    static var shellOwnsPushedCanvas: Bool {
#if os(macOS)
        true
#else
        false
#endif
    }
}
