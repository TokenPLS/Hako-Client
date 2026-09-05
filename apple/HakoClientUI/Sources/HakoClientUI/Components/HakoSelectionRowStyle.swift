import SwiftUI

public extension View {
     
     
     
     
     
    @ViewBuilder
    func hakoSelectionRowStyle() -> some View {
#if os(macOS)
        self
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
#else
        self
#endif
    }
}
