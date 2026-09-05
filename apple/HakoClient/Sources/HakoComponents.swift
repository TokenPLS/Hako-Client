import SwiftUI
import UIKit
import HakoClientUI

private struct HakoRegularDetailLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var hakoUsesRegularDetailLayout: Bool {
        get { self[HakoRegularDetailLayoutKey.self] }
        set { self[HakoRegularDetailLayoutKey.self] = newValue }
    }
}

private struct HakoRegularDetailPageLayoutModifier: ViewModifier {
    let isEnabled: Bool
    @Environment(\.hakoDetailCanvas) private var detailCanvas

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            HakoClientUI.HakoRegularDetailPageLayout(
                background: detailCanvas ?? HakoTheme.canvas
            ) {
                content
            }
        } else {
            content
        }
    }
}

 
 
 
 
 
 
private struct HakoDetailPageInsets: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content.hakoRegularDetailPageLayout(
            enabled: horizontalSizeClass == .regular
        )
    }
}

extension View {
    func hakoRegularDetailPageLayout(enabled: Bool) -> some View {
        modifier(HakoRegularDetailPageLayoutModifier(isEnabled: enabled))
    }

     
    func hakoDetailPageInsets() -> some View {
        modifier(HakoDetailPageInsets())
    }
}

 
 
typealias HakoSymbol = HakoClientUI.HakoSymbol

extension HakoClientUI.HakoSymbol {
     
     
    var name: String {
        if isCustom {
            return rawValue
        }

        return candidates.first(where: { UIImage(systemName: $0) != nil }) ?? rawValue
    }
}

 
 
struct HakoSymbolImage: View {
    let symbol: HakoSymbol
    var resizesToFit = false

    @ViewBuilder
    var body: some View {
        Group {
            if symbol.isCustom {
                rendered(Image(symbol.name))
            } else {
                rendered(Image(systemName: symbol.name))
            }
        }
        .scaleEffect(symbol.opticalScale)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func rendered(_ image: Image) -> some View {
         
         
         
         
        if resizesToFit {
            image
                .resizable()
                .scaledToFit()
        } else {
            image
        }
    }
}

 
 
struct HakoGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
     
     
    @ViewBuilder
    func hakoPrimaryActionButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }

     
    @ViewBuilder
    func hakoSecondaryActionButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

}

typealias HakoSelectionMark = HakoClientUI.HakoSelectionMark

 
 
 
 
struct HakoCardSurface<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HakoClientUI.HakoCardSurface(
            fill: HakoTheme.surface,
            separator: HakoTheme.separator
        ) {
            content
        }
    }
}

struct HakoFeatureCard<Content: View>: View {
    let content: Content
    var isInteractive: Bool = false

    init(
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.isInteractive = isInteractive
        self.content = content()
    }

    var body: some View {
        HakoCardSurface {
            content
                .padding(HakoTheme.Spacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

 
 
struct HakoIconWell: View {
    let symbol: HakoSymbol
    let tint: Color

    var body: some View {
        HakoClientUI.HakoIconWell(tint: tint) {
            HakoSymbolImage(symbol: symbol)
                .font(.body.weight(.semibold))
        }
    }
}

typealias HakoBadgeRole = HakoClientUI.HakoBadgeRole

struct HakoStatusBadge: View {
    let title: String
    let tint: Color
    var role: HakoBadgeRole = .status

    var body: some View {
        HakoClientUI.HakoStatusBadge(
            title: title,
            tint: tint,
            role: role,
            categoryFill: Color(uiColor: .tertiarySystemFill),
            requirementFill: Color(uiColor: .secondarySystemGroupedBackground),
            separator: HakoTheme.separator
        )
    }
}

 
 
struct HakoDestinationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

     
     
     
     
    let title: HakoDisplayText
     
     
     
     
    var subtitle: HakoDisplayText?
    let symbol: HakoSymbol
    let tint: Color
    var badge: String?
    var badgeTint: Color = .blue
    var badgeRole: HakoBadgeRole = .requirement
     
     
     
    var linksOut = false

    var body: some View {
         
         
         
         
         
         
         
         
         
         
         

         
         
         
         
         
         
        HStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center,
            spacing: HakoTheme.Spacing.row
        ) {
            HakoIconWell(symbol: symbol, tint: tint)

            VStack(
                alignment: .leading,
                spacing: HakoTheme.Typography.rowSubtitleGap(locale)
            ) {
                HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.compact) {
                    Text(hako: title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if let badge, !dynamicTypeSize.isAccessibilitySize {
                        HakoStatusBadge(title: badge, tint: badgeTint, role: badgeRole)
                    }
                }

                if let subtitle {
                    Text(hako: subtitle)
                        .font(HakoTheme.Typography.rowSubtitle(locale))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let badge, dynamicTypeSize.isAccessibilitySize {
                    HakoStatusBadge(title: badge, tint: badgeTint, role: badgeRole)
                }
            }

            Spacer(minLength: 0)
            if linksOut {
                externalLinkIcon
            }
        }
         
         
         
         
         
         
        .padding(.vertical, subtitle == nil ? 0 : HakoTheme.Spacing.compact)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var externalLinkIcon: some View {
        HakoSymbolImage(symbol: .link)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }
}

 
 
struct HakoPrimaryDestinationRow: View {
    let title: HakoDisplayText
    let subtitle: HakoDisplayText
    let symbol: HakoSymbol
    let tint: Color

    var body: some View {
        HStack(spacing: HakoTheme.Spacing.compact) {
            HakoDestinationRow(
                title: title,
                subtitle: subtitle,
                symbol: symbol,
                tint: tint
            )

             
             
            if !HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                HakoSymbolImage(symbol: .chevronForward)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, HakoTheme.Spacing.compact)
    }
}

struct HakoEmptyState: View {
    let title: String
    let message: String
    let symbol: HakoSymbol
    var isLoading = false

    var body: some View {
        HakoClientUI.HakoEmptyState(
            title: title,
            message: message,
            isLoading: isLoading
        ) {
            HakoSymbolImage(symbol: symbol)
        }
    }
}

extension View {
     
     
     
    func hakoEmptyStateListCard() -> some View {
        self
            .background(
                RoundedRectangle(
                    cornerRadius: HakoTheme.Radius.groupedSection,
                    style: .continuous
                )
                .fill(HakoTheme.surface)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: HakoTheme.Radius.groupedSection,
                    style: .continuous
                )
                .stroke(HakoTheme.separator.opacity(0.16), lineWidth: 0.5)
            )
            .listRowInsets(
                EdgeInsets(
                    top: HakoTheme.Spacing.standard,
                    leading: HakoTheme.Spacing.standard,
                    bottom: HakoTheme.Spacing.standard,
                    trailing: HakoTheme.Spacing.standard
                )
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

enum HakoStatusKind {
    case information
    case success
    case warning
    case error

    var symbol: HakoSymbol {
        switch self {
        case .information: return .infoCircleFill
        case .success: return .checkmarkCircleFill
        case .warning: return .exclamationmarkTriangleFill
        case .error: return .xmarkOctagonFill
        }
    }

    var tint: Color {
        switch self {
        case .information: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct HakoStatusMessage: View {
     
     
     
     
     
    let text: HakoDisplayText
    let kind: HakoStatusKind

    var body: some View {
        Label {
            Text(hako: text)
                .font(.subheadline)
                .foregroundStyle(kind == .information ? .secondary : kind.tint)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: kind.symbol.name)
                .foregroundStyle(kind.tint)
        }
        .accessibilityElement(children: .combine)
    }
}

 
 
 
 
 
struct HakoFeedbackPresentation: Equatable {
    enum Kind: Equatable {
        case loading
        case success
        case information
        case warning
        case error
    }

    let kind: Kind
     
    let title: HakoDisplayText
     
     
     
    let message: HakoDisplayText?
    let accessibilityIdentifier: String

    static func loading(
        title: HakoDisplayText,
        message: HakoDisplayText? = nil,
        accessibilityIdentifier: String
    ) -> Self {
        Self(
            kind: .loading,
            title: title,
            message: message,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    static func success(
        title: HakoDisplayText,
        message: HakoDisplayText? = nil,
        accessibilityIdentifier: String
    ) -> Self {
        Self(
            kind: .success,
            title: title,
            message: message,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    static func information(
        title: HakoDisplayText,
        message: HakoDisplayText? = nil,
        accessibilityIdentifier: String
    ) -> Self {
        Self(
            kind: .information,
            title: title,
            message: message,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    static func warning(
        title: HakoDisplayText,
        message: HakoDisplayText? = nil,
        accessibilityIdentifier: String
    ) -> Self {
        Self(
            kind: .warning,
            title: title,
            message: message,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

    static func error(
        title: HakoDisplayText,
        message: HakoDisplayText? = nil,
        accessibilityIdentifier: String
    ) -> Self {
        Self(
            kind: .error,
            title: title,
            message: message,
            accessibilityIdentifier: accessibilityIdentifier
        )
    }

     
     
    var requiresExplicitDismissal: Bool {
        switch kind {
        case .loading, .success:
            return false
        case .information, .warning, .error:
            return true
        }
    }

    fileprivate var announcement: String {
        [title.rawValue, message?.rawValue]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

 
 
 
struct HakoFeedbackOverlay: View {
    let presentation: HakoFeedbackPresentation
    let dismissTitle: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            HakoCardSurface {
                VStack(spacing: HakoTheme.Spacing.standard) {
                    feedbackSymbol
                        .frame(width: 64, height: 64)

                    VStack(spacing: HakoTheme.Spacing.compact) {
                        Text(hako: presentation.title)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if let message = presentation.message,
                           !message.rawValue.isEmpty {
                            Text(hako: message)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if presentation.requiresExplicitDismissal {
                        Button(dismissTitle.hakoLocalized, action: onDismiss)
                            .font(.headline)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .frame(
                                minWidth: 140,
                                minHeight: HakoClientUI.HakoTheme.Control
                                    .minimumHitTarget
                            )
                            .accessibilityIdentifier(
                                "\(presentation.accessibilityIdentifier).dismiss"
                            )
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .padding(.horizontal, HakoTheme.Spacing.section)
                .padding(.vertical, HakoTheme.Spacing.standard)
            }
            .frame(maxWidth: 336)
            .padding(.horizontal, HakoTheme.Spacing.section)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(hako: presentation.title))
        .accessibilityValue(presentation.message?.rawValue ?? "")
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape) {
            if presentation.requiresExplicitDismissal {
                onDismiss()
            }
        }
        .onAppear(perform: announce)
        .onChange(of: presentation) { _ in announce() }
    }

    @ViewBuilder
    private var feedbackSymbol: some View {
        switch presentation.kind {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .tint(.blue)
                .accessibilityHidden(true)
        case .success:
            statusSymbol(.checkmarkCircleFill, tint: .green)
        case .information:
            statusSymbol(.infoCircleFill, tint: .blue)
        case .warning:
            statusSymbol(.exclamationmarkTriangleFill, tint: .orange)
        case .error:
            statusSymbol(.xmarkOctagonFill, tint: .red)
        }
    }

    private func statusSymbol(_ symbol: HakoSymbol, tint: Color) -> some View {
        HakoSymbolImage(symbol: symbol)
            .font(.system(size: 52, weight: .semibold))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private func announce() {
        UIAccessibility.post(
            notification: .announcement,
            argument: presentation.announcement
        )
    }
}

private struct HakoFeedbackOverlayModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var presentation: HakoFeedbackPresentation?
    let dismissTitle: String

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(presentation != nil)

            if let presentation {
                HakoFeedbackOverlay(
                    presentation: presentation,
                    dismissTitle: dismissTitle,
                    onDismiss: { self.presentation = nil }
                )
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .scale(scale: 0.96).combined(with: .opacity)
                    )
                    .zIndex(1)
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.22),
            value: presentation
        )
    }
}

extension View {
     
     
    func hakoFeedbackOverlay(
        _ presentation: Binding<HakoFeedbackPresentation?>,
        dismissTitle: String
    ) -> some View {
        modifier(
            HakoFeedbackOverlayModifier(
                presentation: presentation,
                dismissTitle: dismissTitle
            )
        )
    }
}


