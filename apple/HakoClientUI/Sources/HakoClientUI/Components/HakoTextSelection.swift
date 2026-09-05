import SwiftUI

extension View {
     
     
    @ViewBuilder
    func hakoTextSelectionEnabled() -> some View {
#if os(tvOS)
        self
#else
        textSelection(.enabled)
#endif
    }
}
