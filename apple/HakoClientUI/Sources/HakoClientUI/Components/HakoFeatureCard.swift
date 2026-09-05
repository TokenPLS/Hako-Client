import SwiftUI

 
 
 
 
public struct HakoFeatureCard<Content: View>: View {
    public let palette: HakoProductPalette

    private let content: Content

    public init(
        palette: HakoProductPalette,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
         
         
         
         
         
         
         
         
         
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            Section {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HakoCardSurface(
                fill: palette.card,
                separator: palette.separator
            ) {
                content
                    .padding(HakoTheme.Spacing.standard)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
