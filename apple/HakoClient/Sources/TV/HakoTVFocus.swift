import SwiftUI

extension View {
     
     
     
     
     
     
    func onHakoTVFocus(_ handler: @escaping () -> Void) -> some View {
        modifier(HakoTVFocusReporter(handler: handler))
    }
}

private struct HakoTVFocusReporter: ViewModifier {
    let handler: () -> Void
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .onChange(of: focused) { _, isFocused in
                if isFocused { handler() }
            }
    }
}
