import SwiftUI

 
 
 

extension View {
     
     
     
     
     
    @ViewBuilder
    public func hakoMacCancelKey() -> some View {
        #if os(macOS)
        keyboardShortcut(.cancelAction)
        #else
        self
        #endif
    }

     
     
     
     
    @ViewBuilder
    public func hakoMacProductModalDismiss(
        _ dismiss: @escaping @Sendable @MainActor () -> Void
    ) -> some View {
        #if os(macOS)
        environment(\.hakoProductModalDismiss, dismiss)
        #else
        self
        #endif
    }
}
