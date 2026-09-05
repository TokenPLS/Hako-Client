import SwiftUI

 
 
 
extension View {
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    public func hakoFlattensMenuChoices() -> some View {
#if os(macOS)
        pickerStyle(.inline)
#else
        self
#endif
    }

     
     
     
     
    @ViewBuilder
    public func hakoMenuRowChrome() -> some View {
#if os(macOS)
        buttonStyle(.plain)
            .modifier(HakoMenuHoverHighlight())
#else
        self
#endif
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
struct HakoMenuHoverHighlight: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            )
            .onHover { hovering = $0 }
    }
}
