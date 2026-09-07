import SwiftUI

extension View {
     
     
     
     
     
     
    @ViewBuilder
    public func hakoPrimaryActionButtonStyle() -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}
