import SwiftUI

private struct HakoRegularRootScrollsContentKey: EnvironmentKey {
    static let defaultValue = false
}

 
 
 
 
 
 
struct HakoScrollRequestKey: EnvironmentKey {
     
     
    static let defaultValue: HakoScrollRequest? = nil
}

 
 
 
 
 
public struct HakoScrollRequest: @unchecked Sendable, Equatable {
     
     
     
    private let token: UUID
    private let perform: (AnyHashable) -> Void

    init(token: UUID = UUID(), perform: @escaping (AnyHashable) -> Void) {
        self.token = token
        self.perform = perform
    }

    public func callAsFunction(_ id: AnyHashable) {
        perform(id)
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.token == b.token
    }
}

struct HakoShellDrawsRootHeadingKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    internal var hakoScrollToID: HakoScrollRequest? {
        get { self[HakoScrollRequestKey.self] }
        set { self[HakoScrollRequestKey.self] = newValue }
    }
}

private struct HakoRegularRootLargeTitleKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

private struct HakoRegularShellOwnsCanvasKey: EnvironmentKey {
    static let defaultValue = false
}

 
 
 
 
 
 
 
 
 
private struct HakoRegularRootIsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
public final class HakoLatencyPulseGate: @unchecked Sendable, Equatable {
    public var isOpen = true
    public init() {}

     
     
     
     
     
     
     
    public static func == (a: HakoLatencyPulseGate, b: HakoLatencyPulseGate) -> Bool {
        a === b
    }
}

private struct HakoLatencyPulseGateKey: EnvironmentKey {
     
     
    static let defaultValue: HakoLatencyPulseGate? = nil
}

 
 
 
 
 
 
 
 
 
@MainActor
public final class HakoRegularRootChannels: ObservableObject {
    @Published public var searchText = ""
    @Published public var foldCommand = 0
     
     
     
    @Published public var contentGeneration = 0
    @Published public var isActive = true
     
     
     
     
     
    public let latencyPulseGate = HakoLatencyPulseGate()
     
     
     
    public var uiTransitionSink: (() -> Void)?
     
     
     
     
     
     
     
     
    @Published public var openGroup = HakoRootOpenGroupSignal()
    @Published public var displayPreferences = HakoRootDisplaySignal()

    public init() {}

    public func requestOpenGroup(_ name: String) {
        openGroup = HakoRootOpenGroupSignal(
            token: openGroup.token &+ 1,
            group: name
        )
    }

     
     
     
     
     
     
     
     
    public func requestDisplayPreferences(
        _ value: HakoProxiesDisplayPreferences
    ) {
        displayPreferences = HakoRootDisplaySignal(
            token: displayPreferences.token &+ 1,
            preferences: value
        )
    }
}

 
 
public struct HakoRootOpenGroupSignal: Equatable, Sendable {
    public var token = 0
    public var group: String?

    public init(token: Int = 0, group: String? = nil) {
        self.token = token
        self.group = group
    }
}

 
 
public struct HakoRootDisplaySignal: Equatable, Sendable {
    public var token = 0
    public var preferences: HakoProxiesDisplayPreferences?

    public init(
        token: Int = 0,
        preferences: HakoProxiesDisplayPreferences? = nil
    ) {
        self.token = token
        self.preferences = preferences
    }
}

private struct HakoRegularRootOpenGroupKey: EnvironmentKey {
    static let defaultValue = HakoRootOpenGroupSignal()
}

private struct HakoRegularRootDisplayKey: EnvironmentKey {
    static let defaultValue = HakoRootDisplaySignal()
}

 
 
 
 
 
 
private struct HakoHostedInRootPoolKey: EnvironmentKey {
    static let defaultValue = false
}

 
 
 
public struct HakoPooledRootFeed: View {
    @ObservedObject private var channels: HakoRegularRootChannels
    private let foldStateSink: HakoBoolSink?
     
     
    private let background: Color
    private let build: () -> AnyView

    public init(
        channels: HakoRegularRootChannels,
        foldStateSink: HakoBoolSink? = nil,
        background: Color,
        build: @escaping () -> AnyView
    ) {
        self.channels = channels
        self.foldStateSink = foldStateSink
        self.background = background
        self.build = build
    }

    public var body: some View {
         
         
         
         
         
        HakoRegularDetailNavigationFrame(background: background) {
            fed
        }
    }

    private var fed: some View {
        build()
            .environment(\.hakoRegularRootSearchText, channels.searchText)
            .environment(\.hakoRegularRootFoldCommand, channels.foldCommand)
            .environment(\.hakoRegularRootFoldStateSink, foldStateSink)
            .environment(\.hakoRegularRootIsActive, channels.isActive)
            .environment(\.hakoLatencyPulseGate, channels.latencyPulseGate)
            .environment(\.hakoRegularRootOpenGroup, channels.openGroup)
            .environment(
                \.hakoRegularRootDisplayPreferences, channels.displayPreferences
            )
            .environment(\.hakoHostedInRootPool, true)
             
             
             
             
             
             
             
            .environment(\.hakoRegularRootScrollsContent, false)
            .environment(\.hakoRegularRootLargeTitle, nil)
            .environment(\.hakoShellDrawsRootHeading, true)
            .environment(\.hakoRegularShellOwnsCanvas, true)
    }
}

 
 
 
 
 
 
 
 
 
 
private struct HakoPageDrawsOwnCardsKey: EnvironmentKey {
    static let defaultValue = false
}

 
 
 
 
 
 
 
private struct HakoRegularRootSearchTextKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

 
 
 
 
 
 
private struct HakoRegularRootFoldCommandKey: EnvironmentKey {
    static let defaultValue = 0
}

 
 
private struct HakoRegularRootFoldStateSinkKey: EnvironmentKey {
     
     
    nonisolated(unsafe) static let defaultValue: HakoBoolSink? = nil
}

 
 
 
 
public struct HakoBoolSink: Equatable {
    private let token: UUID
    private let sink: (Bool) -> Void

    public init(token: UUID = UUID(), _ sink: @escaping (Bool) -> Void) {
        self.token = token
        self.sink = sink
    }

    public func callAsFunction(_ value: Bool) {
        sink(value)
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.token == b.token
    }
}

extension EnvironmentValues {
    var hakoRegularRootScrollsContent: Bool {
        get { self[HakoRegularRootScrollsContentKey.self] }
        set { self[HakoRegularRootScrollsContentKey.self] = newValue }
    }

    var hakoPageDrawsOwnCards: Bool {
        get { self[HakoPageDrawsOwnCardsKey.self] }
        set { self[HakoPageDrawsOwnCardsKey.self] = newValue }
    }

    public var hakoRegularRootIsActive: Bool {
        get { self[HakoRegularRootIsActiveKey.self] }
        set { self[HakoRegularRootIsActiveKey.self] = newValue }
    }

    public var hakoLatencyPulseGate: HakoLatencyPulseGate? {
        get { self[HakoLatencyPulseGateKey.self] }
        set { self[HakoLatencyPulseGateKey.self] = newValue }
    }

    public var hakoRegularRootOpenGroup: HakoRootOpenGroupSignal {
        get { self[HakoRegularRootOpenGroupKey.self] }
        set { self[HakoRegularRootOpenGroupKey.self] = newValue }
    }

    public var hakoRegularRootDisplayPreferences: HakoRootDisplaySignal {
        get { self[HakoRegularRootDisplayKey.self] }
        set { self[HakoRegularRootDisplayKey.self] = newValue }
    }

    public var hakoHostedInRootPool: Bool {
        get { self[HakoHostedInRootPoolKey.self] }
        set { self[HakoHostedInRootPoolKey.self] = newValue }
    }

    public var hakoRegularRootSearchText: String? {
        get { self[HakoRegularRootSearchTextKey.self] }
        set { self[HakoRegularRootSearchTextKey.self] = newValue }
    }

    public var hakoRegularRootFoldCommand: Int {
        get { self[HakoRegularRootFoldCommandKey.self] }
        set { self[HakoRegularRootFoldCommandKey.self] = newValue }
    }

    public var hakoRegularRootFoldStateSink: HakoBoolSink? {
        get { self[HakoRegularRootFoldStateSinkKey.self] }
        set { self[HakoRegularRootFoldStateSinkKey.self] = newValue }
    }

    var hakoRegularRootLargeTitle: String? {
        get { self[HakoRegularRootLargeTitleKey.self] }
        set { self[HakoRegularRootLargeTitleKey.self] = newValue }
    }

     
     
     
     
     
     
    var hakoShellDrawsRootHeading: Bool {
        get { self[HakoShellDrawsRootHeadingKey.self] }
        set { self[HakoShellDrawsRootHeadingKey.self] = newValue }
    }

    var hakoRegularShellOwnsCanvas: Bool {
        get { self[HakoRegularShellOwnsCanvasKey.self] }
        set { self[HakoRegularShellOwnsCanvasKey.self] = newValue }
    }
}

 
 
 
 
 
 
 
public struct HakoRegularRootTopVisibilityPreferenceKey: PreferenceKey {
    public static let defaultValue = true

    public static func reduce(
        value: inout Bool,
        nextValue: () -> Bool
    ) {
        value = value && nextValue()
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoProductDestinationPresentation: Equatable, Sendable {
    public let title: HakoDisplayText
    public let subtitle: HakoDisplayText
    public let badge: HakoDisplayText?

    public init(
        title: HakoDisplayText,
        subtitle: HakoDisplayText,
        badge: HakoDisplayText? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
    }
}

 
 
 
 
 
struct HakoProductRootPage<Content: View>: View {
    @Environment(\.hakoRegularRootScrollsContent)
    private var regularShellScrollsContent
    @Environment(\.hakoRegularRootLargeTitle)
    private var regularRootLargeTitle
    @Environment(\.hakoRegularShellOwnsCanvas)
    private var regularShellOwnsCanvas
    @State private var isScrollTopVisible = true
     
    @State private var scrollRequestToken = UUID()

    let palette: HakoProductPalette
    let accessibilityIdentifier: String
     
     
     
     
     
     
     
     
     
     
     
    let hostsSelfDrawnCards: Bool
    let content: Content

    init(
        palette: HakoProductPalette,
        accessibilityIdentifier: String,
        hostsSelfDrawnCards: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.accessibilityIdentifier = accessibilityIdentifier
        self.hostsSelfDrawnCards = hostsSelfDrawnCards
        self.content = content()
    }

    var body: some View {
        Group {
            if regularShellScrollsContent {
                productContent
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(accessibilityIdentifier)
            } else {
                internallyScrollingContent
            }
        }
         
         
        .environment(\.hakoPageDrawsOwnCards, hostsSelfDrawnCards)
        .background(rootCanvas)
    }

    @ViewBuilder
    private var productContent: some View {
         
         
         
         
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
           !hostsSelfDrawnCards,
           #available(iOS 16.0, macOS 13.0, *) {
            VStack(alignment: .leading, spacing: 0) {
                alignedLargeTitle
                    .padding(.horizontal, HakoTheme.Spacing.standard)
                    .padding(.top, HakoTheme.Spacing.section)
                Form { content }
                    .formStyle(.grouped)
                    .environment(\.defaultMinListRowHeight, 0)
                     
                     
                     
                    .scrollContentBackground(.hidden)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.section) {
                alignedLargeTitle
                content
            }
            .padding(.horizontal, HakoTheme.Layout.cardHorizontalInset)
            .padding(.vertical, HakoTheme.Spacing.section)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var internallyScrollingContent: some View {
        ScrollViewReader { proxy in
            scrollingBody
                .environment(
                    \.hakoScrollToID,
                    HakoScrollRequest(token: scrollRequestToken) { id in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(id, anchor: .top)
                        }
                    }
                )
        }
    }

    @ViewBuilder
    private var scrollingBody: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
           !hostsSelfDrawnCards {
             
             
             
             
             
            productContent
        } else if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
            ScrollView {
                productContent
            }
            .onScrollGeometryChange(for: String.self) { geo in
                "content=\(Int(geo.contentSize.height)) off=\(Int(geo.contentOffset.y)) view=\(Int(geo.containerSize.height))"
            } action: { old, new in
                guard old != new else { return }
                HakoScrollGeoProbe.emit(new, id: accessibilityIdentifier)
            }
            .onScrollPhaseChange { _, newPhase in
                if newPhase.isScrolling {
                    isScrollTopVisible = false
                }
            }
            .accessibilityIdentifier(accessibilityIdentifier)
            .preference(
                key: HakoRegularRootTopVisibilityPreferenceKey.self,
                value: isScrollTopVisible
            )
        } else {
            ScrollView {
                productContent
            }
            .accessibilityIdentifier(accessibilityIdentifier)
            .preference(
                key: HakoRegularRootTopVisibilityPreferenceKey.self,
                value: isScrollTopVisible
            )
        }
    }

    @ViewBuilder
    private var alignedLargeTitle: some View {
        if let title = regularRootLargeTitle {
            largeTitle(title)
        }
    }

    private func largeTitle(_ title: String) -> some View {
        Text(hako: .copy(title))
            .font(.largeTitle.bold())
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("regular.detail.title")
    }

    @ViewBuilder
    private var rootCanvas: some View {
        if regularShellOwnsCanvas {
            Color.clear
        } else {
            palette.canvas.ignoresSafeArea()
        }
    }
}

public extension View {
     
     
     
     
     
     
     
     
    func hakoOwnsProductCanvas() -> some View {
        environment(\.hakoRegularShellOwnsCanvas, false)
    }
}

 
struct HakoProductPageSection<Content: View>: View {
    let title: String
    let palette: HakoProductPalette
    let presentationClass: HakoPresentationClass
    let content: Content

    init(
        title: String,
        palette: HakoProductPalette,
        presentationClass: HakoPresentationClass,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.palette = palette
        self.presentationClass = presentationClass
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
         
         
         
         
         
         
         
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            Section {
                content
            } header: {
                Text(hako: .copy(title))
            }
        } else {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
                Text(hako: .copy(title))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, HakoTheme.Layout.cardHorizontalInset)

                primaryCard
            }
        }
    }

    @ViewBuilder
    private var primaryCard: some View {
        let rows = VStack(spacing: 0) {
            content
        }
        .padding(
            .vertical,
            presentationClass == .regularTouch
                || presentationClass == .desktop
                ? HakoTheme.Spacing.compact
                : 0
        )
        .padding(.horizontal, HakoTheme.Spacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        let traditionalCard = HakoCardSurface(
            fill: palette.card,
            separator: palette.separator,
            cornerRadius: HakoTheme.Radius.groupedSection
        ) {
            rows
        }

         
         
        if usesTraditionalPrimaryCard {
            traditionalCard
        } else if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
             
             
             
             
            rows
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: HakoTheme.Radius.liquidGlassCard,
                        style: .continuous
                    )
                )
                .glassEffect(
                    .regular,
                    in: .rect(
                        cornerRadius: HakoTheme.Radius.liquidGlassCard
                    )
                )
        } else {
            traditionalCard
        }
    }

     
     
     
     
    static func usesTraditionalPrimaryCard(
        for presentationClass: HakoPresentationClass
    ) -> Bool {
         
         
         
         
         
         
        presentationClass == .desktop
    }

    private var usesTraditionalPrimaryCard: Bool {
        Self.usesTraditionalPrimaryCard(for: presentationClass)
    }
}

 
public struct HakoProductDestinationRow<Icon: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale

    public let presentation: HakoProductDestinationPresentation
    public let symbol: HakoSymbol
    public let tint: Color
    public let presentationClass: HakoPresentationClass
    public let palette: HakoProductPalette
    private let icon: (HakoSymbol) -> Icon

    public init(
        presentation: HakoProductDestinationPresentation,
        symbol: HakoSymbol,
        tint: Color,
        presentationClass: HakoPresentationClass,
        palette: HakoProductPalette,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.presentation = presentation
        self.symbol = symbol
        self.tint = tint
        self.presentationClass = presentationClass
        self.palette = palette
        self.icon = icon
    }

    public var body: some View {
        Group {
            if dynamicTypeSize >= .accessibility1 {
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.standard
                ) {
                    HStack {
                        leadingIcon
                        Spacer(minLength: HakoTheme.Spacing.standard)
                        disclosureIcon
                    }

                    destinationCopy
                }
            } else {
                 
                 
                 
                 
                HStack(
                    alignment: .center,
                    spacing: HakoTheme.Spacing.row
                ) {
                    leadingIcon
                    destinationCopy
                    Spacer(minLength: 0)
                    disclosureIcon
                }
            }
        }
         
         
         
         
         
        .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.compact
            )
        )
         
         
         
         
        .frame(minHeight: rowFloor)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var leadingIcon: some View {
        HakoIconWell(tint: tint) {
            icon(symbol)
                .font(.body.weight(.semibold))
        }
    }

    private var destinationCopy: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Typography.rowSubtitleGap(locale)
        ) {
            Text(hako: presentation.title)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(hako: presentation.subtitle)
                .font(HakoTheme.Typography.rowSubtitle(locale))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var disclosureIcon: some View {
        icon(.chevronForward)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

     
     
     
     
    private var ownsRowMetrics: Bool {
        !HakoPlatformLayout.pageUsesSystemSettingsIdiom
    }

     
     
     
     
     
     
    private var rowFloor: CGFloat? {
        guard ownsRowMetrics else { return nil }
        if let regular = destinationRowMinHeight { return regular }
        return hasSubtitle ? HakoTheme.Layout.destinationRowTargetHeight : nil
    }

    private var hasSubtitle: Bool {
        switch presentation.subtitle {
        case .verbatim(let value), .copy(let value): return !value.isEmpty
        default: return true
        }
    }

    private var destinationRowMinHeight: CGFloat? {
        presentationClass == .regularTouch || presentationClass == .desktop
            ? HakoTheme.Regular.Detail.destinationRowMinHeight
            : nil
    }
}

 
 
@MainActor
enum HakoScrollGeoProbe {
    private static var last = Date.distantPast
    static func emit(_ line: String, id: String) {
        let now = Date()
        guard now.timeIntervalSince(last) > 1 else { return }
        last = now
        HakoPerf.emit("scrollgeo \(id) \(line)")
    }
}
