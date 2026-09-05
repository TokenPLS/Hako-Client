import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoProductGroup<Content: View, Trailing: View>: View {
    private let title: HakoDisplayText?
    private let footer: HakoDisplayText?
    private let palette: HakoProductPalette
     
     
     
    private let touchSpacing: CGFloat
     
     
     
     
    private let paintsInSettingsIdiom: Bool
    private let trailing: Trailing
    private let content: Content

     
     
    @Environment(\.hakoPageDrawsOwnCards) private var pageDrawsOwnCards

    public init(
        _ title: HakoDisplayText? = nil,
        footer: HakoDisplayText? = nil,
        palette: HakoProductPalette,
        touchSpacing: CGFloat = HakoTheme.Spacing.section,
        paintsInSettingsIdiom: Bool = false,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.palette = palette
        self.touchSpacing = touchSpacing
        self.paintsInSettingsIdiom = paintsInSettingsIdiom
        self.trailing = trailing()
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
           !paintsInSettingsIdiom,
           !pageDrawsOwnCards {
            Section {
                content
            } header: {
                if let title {
                    HStack(alignment: .firstTextBaseline) {
                        Text(hako: title)
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        trailing
                    }
                }
            } footer: {
                if let footer {
                    Text(hako: footer)
                        .hakoMacSettingsFootnote()
                }
            }
        } else {
            VStack(
                alignment: .leading,
                 
                 
                 
                 
                 
                 
                 
                spacing: HakoPlatformLayout.pageUsesSystemSettingsIdiom
                    ? HakoTheme.Spacing.cardGap
                    : touchSpacing
            ) {
                if let title {
                    HakoSectionCaption(title) { trailing }
                }
                HakoCardSurface(
                    fill: palette.card,
                    separator: palette.separator,
                    paintsInSettingsIdiom: paintsInSettingsIdiom
                ) {
                     
                     
                     
                     
                     
                     
                     
                     
                    content
                        .padding(HakoTheme.Spacing.standard)
                }
                if let footer {
                    HakoSectionFooter(footer)
                }
            }
        }
    }
}

public extension HakoProductGroup where Trailing == EmptyView {
    init(
        _ title: HakoDisplayText? = nil,
        footer: HakoDisplayText? = nil,
        palette: HakoProductPalette,
        touchSpacing: CGFloat = HakoTheme.Spacing.section,
        paintsInSettingsIdiom: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            title,
            footer: footer,
            palette: palette,
            touchSpacing: touchSpacing,
            paintsInSettingsIdiom: paintsInSettingsIdiom,
            trailing: { EmptyView() },
            content: content
        )
    }
}
