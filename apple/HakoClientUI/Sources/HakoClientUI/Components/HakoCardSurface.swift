import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoCardSurface<Content: View>: View {
    public let fill: Color
    public let separator: Color
    public let cornerRadius: CGFloat

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    public let paintsInSettingsIdiom: Bool

     
     
     
    @Environment(\.hakoPageDrawsOwnCards) private var pageDrawsOwnCards

    private let content: Content

    public init(
        fill: Color,
        separator: Color,
        cornerRadius: CGFloat = HakoTheme.Radius.card,
        paintsInSettingsIdiom: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.fill = fill
        self.separator = separator
        self.cornerRadius = cornerRadius
        self.paintsInSettingsIdiom = paintsInSettingsIdiom
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
         
         
         
         
         
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
           !paintsInSettingsIdiom,
           !pageDrawsOwnCards {
             
             
             
             
             
             
             
            Section {
                content
                    .modifier(HakoCardControlSurfacePolicy())
            }
        } else {
            painted
        }
    }

    private var painted: some View {
        content
            .modifier(HakoCardControlSurfacePolicy())
            .background(shape.fill(fill))
             
             
             
             
             
             
             
            .clipShape(shape)
            .overlay(shape.stroke(separator.opacity(0.16), lineWidth: 0.5))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

 
 
 
 
private struct HakoCardControlSurfacePolicy: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        content.textFieldStyle(.plain)
#else
        content
#endif
    }
}
