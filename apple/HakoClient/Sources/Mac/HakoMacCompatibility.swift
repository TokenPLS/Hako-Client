import AppKit
import HakoClientUI
import SwiftUI

private struct HakoMacRegularDetailLayoutKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var hakoUsesRegularDetailLayout: Bool {
        get { self[HakoMacRegularDetailLayoutKey.self] }
        set { self[HakoMacRegularDetailLayoutKey.self] = newValue }
    }
}

 
 
 
typealias HakoSymbol = HakoClientUI.HakoSymbol
typealias HakoBadgeRole = HakoClientUI.HakoBadgeRole
typealias UITextContentType = HakoMacTextContentType

 
 
 
 
 
enum HakoMacAsset: String {
    case menuBarTemplate = "HakoMenuBarTemplate"
}

extension Image {
    init(hakoMacAsset asset: HakoMacAsset) {
        self.init(asset.rawValue)
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum HakoMacSymbolNameCache {
    private static let guardrail = NSLock()
    nonisolated(unsafe) private static var resolved: [HakoClientUI.HakoSymbol: String] = [:]

    static func name(for symbol: HakoClientUI.HakoSymbol) -> String {
        guardrail.lock()
        let cached = resolved[symbol]
        guardrail.unlock()
        if let cached { return cached }
        let answer = probe(symbol)
        guardrail.lock()
        resolved[symbol] = answer
        guardrail.unlock()
        return answer
    }

    private static func probe(_ symbol: HakoClientUI.HakoSymbol) -> String {
        if symbol.isCustom { return symbol.rawValue }
        return symbol.candidates.first {
            NSImage(
                systemSymbolName: $0,
                accessibilityDescription: nil
            ) != nil
        } ?? symbol.rawValue
    }

    static func resetForTesting() {
        guardrail.lock(); resolved.removeAll(); guardrail.unlock()
    }

    static func isResolvedForTesting(_ symbol: HakoClientUI.HakoSymbol) -> Bool {
        guardrail.lock(); defer { guardrail.unlock() }
        return resolved[symbol] != nil
    }
}

extension HakoClientUI.HakoSymbol {
    var name: String {
        HakoMacSymbolNameCache.name(for: self)
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

struct HakoStatusBadge: View {
    let title: String
    let tint: Color
    var role: HakoBadgeRole = .status

    var body: some View {
        HakoClientUI.HakoStatusBadge(
            title: title,
            tint: tint,
            role: role,
            categoryFill: Color(nsColor: .controlBackgroundColor),
            requirementFill: Color(nsColor: .controlBackgroundColor),
            separator: Color(nsColor: .separatorColor)
        )
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
        HakoClientUI.HakoCardSurface(
            fill: HakoTheme.surface,
            separator: HakoTheme.separator
        ) {
            content
                .padding(HakoTheme.Spacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HakoOverviewCard<Content: View>: View {
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
                .padding(HakoTheme.Spacing.standard)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct OverviewBadge {
    let title: String
    let tint: Color
}

struct OverviewCardHeader: View {
    let title: String
    let symbol: HakoSymbol
    let tint: Color
    var badge: OverviewBadge?

    var body: some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            HakoIconWell(symbol: symbol, tint: tint)
            Text(hako: .copy(title))
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
            Spacer(minLength: HakoTheme.Spacing.compact)
            if let badge {
                HakoStatusBadge(
                    title: badge.title,
                    tint: badge.tint
                )
            }
        }
    }
}

struct HakoGlassEffectContainer<Content: View>: View {
    let content: Content

    init(
        spacing: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        _ = spacing
        self.content = content()
    }

    var body: some View {
        content
    }
}

struct HakoDestinationRow: View {
    let title: HakoDisplayText
    var subtitle: HakoDisplayText?
    let symbol: HakoSymbol
    let tint: Color
    var badge: String?
    var badgeTint: Color = .blue
    var badgeRole: HakoBadgeRole = .requirement
    var linksOut = false

     
     
     
     
     
     
     
     
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .top : .center,
            spacing: HakoTheme.Spacing.row
        ) {
            HakoClientUI.HakoIconWell(tint: tint) {
                HakoSymbolImage(symbol: symbol)
                    .font(.body.weight(.semibold))
            }

            VStack(
                alignment: .leading,
                spacing: HakoTheme.Typography.rowSubtitleGap(locale)
            ) {
                HStack(alignment: .firstTextBaseline) {
                    Text(hako: title)
                    if let badge, !dynamicTypeSize.isAccessibilitySize {
                        HakoClientUI.HakoStatusBadge(
                            title: badge,
                            tint: badgeTint,
                            role: badgeRole,
                            categoryFill: Color(
                                nsColor: .controlBackgroundColor
                            ),
                            requirementFill: Color(
                                nsColor: .controlBackgroundColor
                            ),
                            separator: Color(nsColor: .separatorColor)
                        )
                    }
                }
                if let subtitle {
                    Text(hako: subtitle)
                        .font(HakoTheme.Typography.rowSubtitle(locale))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let badge, dynamicTypeSize.isAccessibilitySize {
                    HakoClientUI.HakoStatusBadge(
                        title: badge,
                        tint: badgeTint,
                        role: badgeRole,
                        categoryFill: Color(nsColor: .controlBackgroundColor),
                        requirementFill: Color(nsColor: .controlBackgroundColor),
                        separator: Color(nsColor: .separatorColor)
                    )
                }
            }
            Spacer(minLength: 0)
            if linksOut {
                HakoSymbolImage(symbol: .link)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, subtitle == nil ? 0 : HakoTheme.Spacing.compact)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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

struct OverviewValueRow: View {
    let title: HakoDisplayText
    let value: HakoDisplayText

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.row) {
            Text(hako: title)
            Spacer(minLength: HakoTheme.Spacing.row)
            Text(hako: value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .subheadline)
        .accessibilityElement(children: .combine)
    }
}

struct RuntimeMetricRow: View {
    let title: HakoDisplayText
    let value: HakoDisplayText
    let symbol: HakoSymbol

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.row) {
            Label {
                Text(hako: title)
            } icon: {
                Image(systemName: symbol.name)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            Spacer(minLength: HakoTheme.Spacing.row)
            Text(hako: value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
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
        case .loading, .success: false
        case .information, .warning, .error: true
        }
    }
}

private struct HakoMacFeedbackOverlay: View {
    let presentation: HakoFeedbackPresentation
    let dismissTitle: String
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            VStack(spacing: HakoTheme.Spacing.standard) {
                symbol
                    .font(.system(size: 48, weight: .semibold))
                    .accessibilityHidden(true)
                Text(hako: presentation.title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)
                if let message = presentation.message {
                    Text(hako: message)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if presentation.requiresExplicitDismissal {
                    Button(dismissTitle, action: onDismiss)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(HakoTheme.Spacing.section)
            .frame(maxWidth: 336)
            .background(.regularMaterial)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: HakoTheme.Radius.card,
                    style: .continuous
                )
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(presentation.accessibilityIdentifier)
    }

    @ViewBuilder
    private var symbol: some View {
        switch presentation.kind {
        case .loading:
            ProgressView()
        case .success:
            Image(systemName: HakoSymbol.checkmarkCircleFill.name)
                .foregroundStyle(.green)
        case .information:
            Image(systemName: HakoSymbol.infoCircleFill.name)
                .foregroundStyle(.blue)
        case .warning:
            Image(systemName: HakoSymbol.exclamationmarkTriangleFill.name)
                .foregroundStyle(.orange)
        case .error:
            Image(systemName: HakoSymbol.xmarkOctagonFill.name)
                .foregroundStyle(.red)
        }
    }
}

enum HakoStatusKind {
    case information
    case success
    case warning
    case error

    var symbol: HakoSymbol {
        switch self {
        case .information: .infoCircleFill
        case .success: .checkmarkCircleFill
        case .warning: .exclamationmarkTriangleFill
        case .error: .xmarkOctagonFill
        }
    }

    var tint: Color {
        switch self {
        case .information: .blue
        case .success: .green
        case .warning: .orange
        case .error: .red
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
                .foregroundStyle(
                    kind == .information ? .secondary : kind.tint
                )
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: kind.symbol.name)
                .foregroundStyle(kind.tint)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HakoMacRegularDetailPageLayoutModifier: ViewModifier {
    let isEnabled: Bool
    @Environment(\.hakoDetailCanvas) private var detailCanvas
    @Environment(\.hakoInsideModalPresentation)
    private var insideNativeModal
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled && !(insideProductModal || insideNativeModal) {
            HakoClientUI.HakoRegularDetailPageLayout(
                 
                 
                 
                 
                 
                background: detailCanvas
                    ?? Color(nsColor: .underPageBackgroundColor)
            ) {
                content
            }
        } else {
            content
        }
    }
}

extension View {
    func hakoRegularDetailPageLayout(enabled: Bool) -> some View {
        modifier(
            HakoMacRegularDetailPageLayoutModifier(isEnabled: enabled)
        )
    }

    func hakoDetailPageInsets() -> some View {
        hakoRegularDetailPageLayout(enabled: true)
    }

    func keyboardType(_ type: HakoMacKeyboardType) -> some View {
        self
    }

    func textInputAutocapitalization(
        _ behavior: HakoMacTextInputAutocapitalization
    ) -> some View {
        self
    }

    func textContentType(
        _ type: HakoMacTextContentType?
    ) -> some View {
        self
    }

    func hakoPrimaryActionButtonStyle() -> some View {
        buttonStyle(.borderedProminent)
    }

    func hakoSecondaryActionButtonStyle() -> some View {
        buttonStyle(.bordered)
    }

    func hakoFeedbackOverlay(
        _ presentation: Binding<HakoFeedbackPresentation?>,
        dismissTitle: String
    ) -> some View {
        ZStack {
            self.disabled(presentation.wrappedValue != nil)

            if let value = presentation.wrappedValue {
                HakoMacFeedbackOverlay(
                    presentation: value,
                    dismissTitle: dismissTitle,
                    onDismiss: { presentation.wrappedValue = nil }
                )
                .zIndex(1)
            }
        }
    }
}

enum HakoMacKeyboardType {
    case `default`
    case URL
    case asciiCapable
    case numberPad
    case numbersAndPunctuation
}

enum HakoMacTextInputAutocapitalization {
    case never
}

enum HakoMacTextContentType {
    case URL
}

enum ByteRateFormatter {
    static func string(_ bytesPerSecond: Int64) -> String {
        HakoThroughputFormatter.rate(bytesPerSecond)
    }
}

enum ByteCountFormatter {
    static func string(_ bytes: Int64) -> String {
        let absolute = Double(max(bytes, 0))
        if absolute < 1_024 {
            return String(format: "%.0f B", absolute)
        }
        if absolute < 1_048_576 {
            return String(format: "%.1f KB", absolute / 1_024)
        }
        if absolute < 1_073_741_824 {
            return String(format: "%.1f MB", absolute / 1_048_576)
        }
        return String(format: "%.2f GB", absolute / 1_073_741_824)
    }
}
