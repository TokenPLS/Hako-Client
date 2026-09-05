import Foundation
import SwiftUI

public struct HakoProductPalette {
    public let canvas: Color
    public let surface: Color
    public let raisedFill: Color
    public let separator: Color
     
     
     
     
     
     
    public let card: Color

    public init(
        canvas: Color,
        surface: Color,
        raisedFill: Color,
        separator: Color,
        card: Color? = nil
    ) {
        self.canvas = canvas
        self.surface = surface
        self.raisedFill = raisedFill
        self.separator = separator
        self.card = card ?? surface
    }
}

private extension View {
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoTracksScrollDistance(
        _ action: @escaping (CGFloat) -> Void
    ) -> some View {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
            onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, distance in
                action(distance)
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func hakoHomePinnedTopBar<Footprint: View, Bar: View>(
        stableFootprint: Bool,
        @ViewBuilder footprint: @escaping () -> Footprint,
        @ViewBuilder bar: @escaping () -> Bar
    ) -> some View {
        if stableFootprint {
            hakoStablePinnedTopBar(footprint: footprint, bar: bar)
        } else {
            hakoPinnedTopBar(bar)
        }
    }
}

private let hakoHomeTopAnchor = "hako.home.top"

 
 
 
private struct HakoHomeCompactingBar<Content: View>: View {
    @ObservedObject private var state: HakoHomeHeaderCompactionState
    private let content: (CGFloat) -> Content

    init(
        state: HakoHomeHeaderCompactionState,
        @ViewBuilder content: @escaping (CGFloat) -> Content
    ) {
        self.state = state
        self.content = content
    }

    var body: some View {
        content(state.progress)
    }
}

 
 
 
 
 
public struct HakoHomeView<Icon: View>: View, Equatable {
     
     
     
     
    nonisolated public static func == (a: Self, b: Self) -> Bool {
        a.snapshot == b.snapshot
            && a.presentationClass == b.presentationClass
    }

     
     
    @Environment(\.locale)
    private var locale
    @Environment(\.hakoRegularRootScrollsContent)
    private var regularShellScrollsContent
    @Environment(\.hakoRegularShellOwnsCanvas)
    private var regularShellOwnsCanvas

    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let presentationClass: HakoPresentationClass
    private let palette: HakoProductPalette
    private let customizationPresentation: (AnyView) -> AnyView
    private let icon: (HakoSymbol) -> Icon

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var section: HakoHomeSection
    @State private var favoriteCards: [HakoHomeCard]
    @State private var trafficScope: HakoHomeTrafficScope
    @State private var showsCardCustomization = false
    @State private var headerCompaction = HakoHomeHeaderCompactionState()

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        presentationClass: HakoPresentationClass,
        palette: HakoProductPalette,
        customizationPresentation: @escaping (AnyView) -> AnyView = {
            $0
        },
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.presentationClass = presentationClass
        self.palette = palette
        self.customizationPresentation = customizationPresentation
        self.icon = icon
        _section = State(initialValue: snapshot.home.initialSection)
        _favoriteCards = State(initialValue: snapshot.home.favoriteCards)
        _trafficScope = State(initialValue: snapshot.home.trafficScope)
    }

    public var body: some View {
        let _ = HakoPerf.count("home.body")
        Group {
            if regularShellScrollsContent {
                homeContent
                    .id(section)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home.root")
            } else {
                 
                 
                 
                 
                homeScrollView
            }
        }
         
         
         
         
         
         
         
        .hakoHomePinnedTopBar(
            stableFootprint: headerCompactionEnabled,
            footprint: { topBar(compaction: 1) },
            bar: {
                if headerCompactionEnabled {
                    HakoHomeCompactingBar(state: headerCompaction) { progress in
                        topBar(compaction: progress)
                    }
                } else {
                    topBar(compaction: 0)
                }
            }
        )
        .background(rootCanvas)
         
         
         
         
         
         
         
        .hakoFrameWatch("Home")
        .sheet(isPresented: $showsCardCustomization) {
            HakoHomeCardCustomizationView(
                cards: $favoriteCards,
                palette: palette,
                customizationPresentation: customizationPresentation,
                icon: icon
            )
            .hakoModalPresentation(.form)
             
             
             
             
            .hakoMacProductModalDismiss {
                showsCardCustomization = false
            }
        }
        .onChange(of: favoriteCards) { cards in
            send(.setCards(cards))
        }
        .onChange(of: snapshot.home.favoriteCards) { cards in
            let normalized = HakoHomeCatalog.normalized(cards)
            if favoriteCards != normalized {
                favoriteCards = normalized
            }
        }
        .onChange(of: snapshot.home.trafficScope) { scope in
            trafficScope = scope
        }
        .onChange(of: headerCompactionEnabled) { enabled in
            if !enabled { headerCompaction.reset() }
        }
    }

    @ViewBuilder
    private var rootCanvas: some View {
        if regularShellOwnsCanvas {
            Color.clear
        } else {
            palette.canvas.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var homeScrollView: some View {
         
         
         
         
         
        let scroll = ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(hakoHomeTopAnchor)
                    if headerCompactionEnabled {
                         
                         
                         
                         
                        Color.clear
                            .frame(height: headerExpansionDistance)
                    }
                    homeContent
                        .id(section)
                }
            }
            .onChange(of: section) { _ in
                headerCompaction.reset()
                proxy.scrollTo(hakoHomeTopAnchor, anchor: .top)
            }
        }
        .accessibilityIdentifier("home.root")

        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            scroll.scrollClipDisabled()
                .hakoTracksScrollDistance { updateHeaderCompaction(for: $0) }
        } else {
            scroll
        }
    }

     
     
     
     
     
    private func updateHeaderCompaction(for distance: CGFloat) {
        headerCompaction.update(
            distance: distance,
            range: headerExpansionDistance,
            enabled: headerCompactionEnabled
        )
    }

     
     
    private var headerCompactionEnabled: Bool {
        presentationClass == .compactTouch
            && !dynamicTypeSize.isAccessibilitySize
    }

     
     
    private var headerExpansionDistance: CGFloat {
        (HakoTheme.Spacing.section - HakoTheme.Spacing.tight)
            + (HakoTheme.Control.minimumHitTarget - 30)
            + HakoTheme.Spacing.row
            + statusRowHeight
            + (HakoTheme.Spacing.compact - HakoTheme.Spacing.tight)
    }

    private var homeContent: some View {
        VStack(spacing: HakoTheme.Spacing.section) {
            homeCards
        }
        .padding(.horizontal, HakoTheme.Spacing.standard)
        .padding(.top, contentTopInset)
        .padding(.bottom, HakoTheme.Spacing.section)
    }

    @ViewBuilder
    private var homeCards: some View {
        if snapshot.selectedProfile == nil {
            unavailableProfileCard
        } else if section == .common {
            commonContent
        } else {
            adjustmentContent
        }
    }

    private var contentTopInset: CGFloat {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *),
           presentationClass == .regularTouch {
            return HakoTheme.Spacing.section * 2
        }
        return HakoTheme.Spacing.section
    }

    private func topBar(compaction: CGFloat) -> some View {
        VStack(spacing: 0) {
            header(compaction: compaction)
            sectionPicker
        }
    }

    private func header(compaction: CGFloat) -> some View {
        let distance = headerExpansionDistance * compaction
        let topReduction = HakoTheme.Spacing.section - HakoTheme.Spacing.tight
        let statusReductionStart = topReduction
        let spacingReductionStart = statusReductionStart + statusRowHeight
        let actionReductionStart = spacingReductionStart + HakoTheme.Spacing.row
        let bottomReductionStart = actionReductionStart
            + (HakoTheme.Control.minimumHitTarget - 30)
        let actionProgress = HakoHomeHeaderCompaction.progress(
            distance: distance - actionReductionStart,
            range: HakoTheme.Control.minimumHitTarget - 30
        )
         
         
         
        let statusOpacity = 1 - HakoHomeHeaderCompaction.progress(
            distance: distance,
            range: HakoTheme.Spacing.row
        )

         
         
         
         
        return VStack(
            alignment: .leading,
            spacing: HakoHomeHeaderCompaction.stagedValue(
                expanded: HakoTheme.Spacing.row,
                compact: 0,
                distance: distance,
                after: spacingReductionStart
            )
        ) {
            profileAndPrimaryAction(compaction: actionProgress)
            if compaction < 1 {
                connectionStatus
                    .opacity(statusOpacity)
                    .frame(
                        height: HakoHomeHeaderCompaction.stagedValue(
                            expanded: statusRowHeight,
                            compact: 0,
                            distance: distance,
                            after: statusReductionStart
                        ),
                        alignment: .top
                    )
                    .clipped()
            }
        }
        .padding(.horizontal, HakoTheme.Spacing.standard)
        .padding(
            .top,
            HakoHomeHeaderCompaction.stagedValue(
                expanded: HakoTheme.Spacing.section,
                compact: HakoTheme.Spacing.tight,
                distance: distance,
                after: 0
            )
        )
        .padding(
            .bottom,
            HakoHomeHeaderCompaction.stagedValue(
                expanded: HakoTheme.Spacing.compact,
                compact: HakoTheme.Spacing.tight,
                distance: distance,
                after: bottomReductionStart
            )
        )
    }

    @ViewBuilder
    private func profileAndPrimaryAction(compaction: CGFloat) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.standard
            ) {
                profileButton
                primaryAction(compaction: compaction)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(alignment: .center, spacing: HakoTheme.Spacing.row) {
                profileButton
                Spacer(minLength: HakoTheme.Spacing.compact)
                primaryAction(compaction: compaction)
            }
        }
    }

    private var profileButton: some View {
        Button {
            send(.openProfiles)
        } label: {
            HStack(spacing: HakoTheme.Spacing.compact) {
                 
                 
                 
                 
                 
                 
                 
                icon(.trayFullFill)
                    .font(
                        dynamicTypeSize.isAccessibilitySize
                            ? .headline.weight(.bold)
                            : .title2.weight(.bold)
                    )
                    .foregroundStyle(.tint)
                 
                 
                 
                (
                    snapshot.selectedProfile.map { Text(verbatim: $0.label) }
                        ?? Text(hako: "Not Set Up")
                )
                .font(
                    dynamicTypeSize.isAccessibilitySize
                        ? .headline.weight(.bold)
                        : .title2.weight(.bold)
                )
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(
                    horizontal: false,
                    vertical: dynamicTypeSize.isAccessibilitySize
                )
                icon(.chevronDown)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(
            snapshot.selectedProfile?.label ?? "Not Set Up"
        )
        .accessibilityHint("Opens Profiles")
        .accessibilityIdentifier("home.profile.open")
    }

     
     
     
     
     
     
     
    @ScaledMetric(relativeTo: .subheadline)
    private var statusRowHeight: CGFloat = 20

    private var connectionStatus: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.compact
                ) {
                    connectionState
                    connectionReason
                }
            } else {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                HStack(spacing: HakoTheme.Spacing.compact) {
                    if snapshot.home.connection.issue != nil {
                        connectionReason
                    } else {
                        connectionState
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: statusRowHeight, alignment: .leading)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

     
     
     
     
     
     
     
    private var connectionState: some View {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        HakoHomeConnectionStatus(
            subtitle: HakoCopy.string(
                for: snapshot.home.connection.subtitle,
                locale: locale
            ),
            coreStartedAtUnixSeconds:
                snapshot.home.traffic.coreStartedAtUnixSeconds,
            isConnected: snapshot.home.connection.phase == .connected,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

     
     
     
     
     
     
     
     
     
     
    static var issueTint: Color { .orange }

     
     
    @ViewBuilder
    private var connectionReason: some View {
        if let issue = snapshot.home.connection.issue {
            Button {
                send(.showConnectionIssue)
            } label: {
                 
                 
                 
                 
                 
                Text(hako: .copy(issue.message))
                     
                     
                     
                    .multilineTextAlignment(.leading)
                     
                     
                     
                     
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .truncationMode(.tail)
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .contentShape(Rectangle())
             
             
             
             
             
             
            .foregroundStyle(Self.issueTint)
            .accessibilityIdentifier("home.connection.reason")
            .accessibilityValue(issue.message)
        }
    }

    private func primaryAction(compaction: CGFloat) -> some View {
        Group {
            if let title = snapshot.home.connection.primaryActionTitle {
                Button {
                    send(
                        .performPrimaryAction(
                            snapshot.home.connection.primaryAction
                        )
                    )
                } label: {
                    primaryActionLabel(title, compaction: compaction)
                }
                .modifier(HakoHomePrimaryButtonStyle())
                .modifier(HakoHomeCapsuleButtonShape())
                .controlSize(.regular)
                .tint(
                    snapshot.home.connection.primaryAction == .disconnect
                        ? .green
                        : .blue
                )
                .disabled(
                    !snapshot.home.connection.primaryActionEnabled
                        || snapshot.home.isProfileActionInFlight
                )
                .accessibilityIdentifier("overview.connection.action")
            } else {
                 
                 
                 
                 
                 
                let cancellable =
                    snapshot.home.connection.primaryAction == .cancel
                Button {
                    if cancellable {
                        send(.performPrimaryAction(.cancel))
                    }
                } label: {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                 
                 
                 
                 
                 
                 
                 
                .modifier(HakoHomeGlassSpinnerStyle())
                .modifier(HakoHomeCapsuleButtonShape())
                .controlSize(.regular)
                .disabled(!cancellable)
                .accessibilityLabel(
                    cancellable
                        ? HakoCopy.key("Cancel Connecting")
                        : HakoCopy.key(snapshot.home.connection.title)
                )
                .accessibilityIdentifier("overview.connection.action")
            }
        }
        .frame(
            minWidth: 104,
            idealWidth: dynamicTypeSize.isAccessibilitySize ? nil : 104,
            maxWidth: dynamicTypeSize.isAccessibilitySize ? nil : 104,
            minHeight: primaryActionHeight(compaction: compaction),
            idealHeight: primaryActionHeight(compaction: compaction),
            maxHeight: dynamicTypeSize.isAccessibilitySize
                ? nil
                : primaryActionHeight(compaction: compaction)
        )
    }

     
     
     
     
     
     
     
    private func primaryActionHeight(compaction: CGFloat) -> CGFloat {
        HakoHomeHeaderCompaction.value(
            expanded: HakoTheme.Control.minimumHitTarget,
            compact: 30,
            progress: compaction
        )
    }

    @ViewBuilder
    private func primaryActionLabel(
        _ title: String,
        compaction: CGFloat
    ) -> some View {
        let label = Text(HakoCopy.key(title))
            .font(.subheadline.weight(.bold))
            .multilineTextAlignment(.center)
            .lineLimit(1)

        if dynamicTypeSize.isAccessibilitySize {
            label
                .fixedSize(horizontal: true, vertical: true)
                .frame(minHeight: 32)
        } else {
            label.frame(
                maxWidth: .infinity,
                minHeight: HakoHomeHeaderCompaction.value(
                    expanded: 32,
                    compact: 16,
                    progress: compaction
                )
            )
        }
    }

    private var sectionPicker: some View {
        HakoHomeSectionTabs(section: $section, separator: palette.separator)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HakoTheme.Spacing.standard)
    }

    private var commonContent: some View {
        Group {
            ForEach(favoriteCards) { card in
                 
                 
                 
                 
                 
                 
                 
                HakoPerf.measure("home.card") {
                    commonCard(card)
                }
                .id(card.id)
            }
            if favoriteCards.isEmpty {
                HakoHomePrimaryPageCard(palette: palette) {
                    VStack(
                        alignment: .leading,
                        spacing: HakoTheme.Spacing.compact
                    ) {
                        Text(HakoCopy.key("No Favorite Cards"))
                            .font(.headline)
                        Text(
                            HakoCopy.key(
                                "Choose the controls you want to keep close at hand."
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("home.cards.empty")
            }
            Button {
                showsCardCustomization = true
            } label: {
                Label {
                    Text(HakoCopy.key("Customize Cards"))
                } icon: {
                    icon(.plus)
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, HakoTheme.Spacing.compact)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("home.cards.customize")
        }
    }

    @ViewBuilder
    private func commonCard(_ card: HakoHomeCard) -> some View {
        switch card {
        case .routing:
            HakoHomeRoutingCard(
                mode: snapshot.home.routing.mode,
                palette: palette,
                icon: icon
            ) { mode in
                Task {
                    try? await actions.perform(
                        .setOutboundMode(mode),
                        allowedBy: snapshot
                    )
                }
            }
            .equatable()
        case .proxies:
            HakoHomeDomainCountCard(
                card: card,
                snapshot: snapshot.home.proxies,
                identifier: "home.context.tile.proxies",
                palette: palette,
                icon: icon
            ) {
                send(.openProxies)
            }
            .equatable()
        case .rules:
            HakoHomeDomainCountCard(
                card: card,
                snapshot: snapshot.home.rules,
                identifier: "home.context.tile.rules",
                palette: palette,
                icon: icon
            ) {
                send(.openRules)
            }
            .equatable()
        case .traffic:
             
             
             
            HakoHomeTrafficCardFeed(
                fallback: snapshot.home.traffic,
                scope: $trafficScope,
                palette: palette,
                icon: icon
            )
            .onChange(of: trafficScope) { scope in
                send(.setTrafficScope(scope))
            }
        case .externalIP:
            HakoHomeExternalIPCard(
                snapshot: snapshot.home.egress,
                palette: palette,
                icon: icon
            ) {
                send(.refreshExternalIP)
            }
            .equatable()
        case .lanIP:
            HakoHomeLANIPCard(
                address: snapshot.home.lanAddress,
                palette: palette,
                icon: icon
            ) {
                send(.refreshLANIP)
            }
            .equatable()
        }
    }

    private var adjustmentContent: some View {
        Group {
            ForEach(snapshot.home.adjustments, id: \.module) { item in
                HakoHomeAdjustmentCard(
                    snapshot: item,
                    palette: palette,
                    icon: icon
                ) { action in
                    send(.openAdjustment(action))
                }
                .equatable()
            }

            Button {
                send(.openRuntimeConfiguration)
            } label: {
                Label {
                    Text(
                        HakoCopy.key(
                            "View Runtime Configuration"
                        )
                    )
                } icon: {
                    icon(.docText)
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, HakoTheme.Spacing.compact)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityIdentifier(
                "home.modify.view-runtime-config"
            )
        }
    }

    private var unavailableProfileCard: some View {
        HakoHomePrimaryPageCard(palette: palette) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.standard
            ) {
                HakoHomeCardTitle(
                    cardTitle: "Profile Unavailable",
                    symbol: .exclamationmarkTriangle,
                    tint: .orange,
                    icon: icon
                )
                Text(
                    HakoCopy.key(
                        "Clash could not prepare its local Direct profile. Open Profiles to retry without replacing your data."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Button {
                    send(.openProfiles)
                } label: {
                    Text(HakoCopy.key("Open Profiles"))
                }
                .modifier(HakoHomePrimaryButtonStyle())
                .modifier(HakoHomeCapsuleButtonShape())
                .accessibilityIdentifier(
                    "home.unavailable.open-profiles"
                )
            }
        }
        .accessibilityIdentifier("home.card.profile-unavailable")
    }

    private func send(_ command: HakoHomeCommand) {
        Task {
            try? await actions.perform(.home(command), allowedBy: snapshot)
        }
    }
}

private struct HakoHomePrimaryButtonStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}

private struct HakoHomeGlassSpinnerStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            content.buttonStyle(.glass)
        } else {
            content.buttonStyle(.bordered)
        }
    }
}

private struct HakoHomeCapsuleButtonShape: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.buttonBorderShape(.capsule)
        } else {
            content
        }
    }
}

private struct HakoHomePrimaryPageCard<Content: View>: View {
    let palette: HakoProductPalette
    let isInteractive: Bool
     
     
     
     
     
     
     
    let managesHorizontalInsets: Bool
    let content: Content

    init(
        palette: HakoProductPalette,
        isInteractive: Bool = false,
        managesHorizontalInsets: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.palette = palette
        self.isInteractive = isInteractive
        self.managesHorizontalInsets = managesHorizontalInsets
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
         
         
         
         
         
         
         
        let _ = HakoPerf.count("home.card.body")
        let padded = content
            .padding(
                managesHorizontalInsets ? .top : .all,
                HakoTheme.Spacing.standard
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        let traditionalCard = HakoCardSurface(
            fill: palette.card,
            separator: palette.separator,
             
             
             
             
            paintsInSettingsIdiom: true
        ) {
            padded
        }

         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        let wearsPlatformMaterial: Bool = {
            if HakoPerfExperiment.suppressesGlass { return false }
            if HakoPlatformLayout.primaryPageCardUsesLiquidGlass { return true }
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom { return false }
            return true
        }()

         
         
         
         
         
         
         
         
         
        let cardCorner = HakoPlatformLayout.primaryPageCardUsesLiquidGlass
            ? HakoTheme.Radius.card
            : HakoTheme.Radius.liquidGlassCard

        if wearsPlatformMaterial,
           #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
             
             
             
             
             
             
             
            padded
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: cardCorner,
                        style: .continuous
                    )
                )
                .glassEffect(
                    isInteractive ? .regular.interactive() : .regular,
                    in: .rect(cornerRadius: cardCorner)
                )
        } else {
            traditionalCard
        }
    }
}

 
 
 
 
 
 
private struct HakoHomeConnectionStatus: View {
    let subtitle: String
    let coreStartedAtUnixSeconds: Int64
    let isConnected: Bool
    let isAccessibilitySize: Bool

    @State private var now = Date()

    var body: some View {
        let seconds = HakoConnectionDuration.secondsElapsed(
            sinceUnixSeconds: coreStartedAtUnixSeconds,
            now: now
        )
        Text(
            HakoHomeStatusLine.text(
                subtitle: subtitle,
                duration: seconds.map {
                    HakoConnectionDuration.text(secondsElapsed: $0)
                },
                isConnected: isConnected
            )
        )
        .monospacedDigit()
        .lineLimit(isAccessibilitySize ? 3 : 1)
         
         
         
        .truncationMode(.middle)
        .fixedSize(horizontal: false, vertical: isAccessibilitySize)
        .accessibilityLabel(
            HakoHomeStatusLine.accessibilityLabel(
                subtitle: subtitle,
                secondsElapsed: seconds,
                isConnected: isConnected
            )
        )
        .accessibilityIdentifier("home.connection.subtitle")
        .modifier(HakoHomeDurationTicker(now: $now))
    }
}

private struct HakoHomeCardTitle<Icon: View>: View {
    let cardTitle: String
    let symbol: HakoSymbol
    let tint: Color?
     
     
     
     
     
    let followsAccent: Bool
    let icon: (HakoSymbol) -> Icon

    init(
        cardTitle: String,
        symbol: HakoSymbol,
        icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.cardTitle = cardTitle
        self.symbol = symbol
        self.tint = nil
        self.followsAccent = false
        self.icon = icon
    }

     
     
     
     
    init(
        cardTitle: String,
        symbol: HakoSymbol,
        followsAccent: Bool,
        icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.cardTitle = cardTitle
        self.symbol = symbol
        self.tint = nil
        self.followsAccent = followsAccent
        self.icon = icon
    }

    init(
        cardTitle: String,
        symbol: HakoSymbol,
        tint: Color,
        followsAccent: Bool = false,
        icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.cardTitle = cardTitle
        self.symbol = symbol
        self.tint = tint
        self.followsAccent = followsAccent
        self.icon = icon
    }

    var body: some View {
        HakoCardTitle(
            titleTint: tint ?? .primary,
            iconTint: tint ?? .primary,
            followsAccent: followsAccent
        ) {
            Text(HakoCopy.key(cardTitle))
        } icon: {
            icon(symbol)
                .modifier(HakoSymbolBreath(value: symbol))
                .modifier(HakoGlyphSlot())
        }
    }
}

 
 
 
 
 
 
private struct HakoSymbolBreath: ViewModifier {
    let value: HakoSymbol

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            content
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.13), value: value)
        } else {
            content
        }
    }
}

 
 
 
 
 
 
 
 
private struct HakoGlyphSlot: ViewModifier {
    @ScaledMetric(relativeTo: .headline) private var width: CGFloat = 26

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: width, alignment: .center)
    }
}

 
 
 
private struct HakoHomeTrafficCardFeed<Icon: View>: View {
    let fallback: AppleClientTrafficSnapshot
    @Binding var scope: HakoHomeTrafficScope
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon
    @Environment(\.hakoTrafficFeed) private var feed

    var body: some View {
        if let feed {
            HakoHomeTrafficCardObserving(feed: feed, scope: $scope, palette: palette, icon: icon)
        } else {
            HakoHomeTrafficCard(traffic: fallback, scope: $scope, palette: palette, icon: icon)
                .equatable()
        }
    }
}

private struct HakoHomeTrafficCardObserving<Icon: View>: View {
    @ObservedObject var feed: HakoTrafficFeed
    @Binding var scope: HakoHomeTrafficScope
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon

    var body: some View {
        HakoHomeTrafficCard(traffic: feed.traffic, scope: $scope, palette: palette, icon: icon)
            .equatable()
    }
}

private struct HakoHomeTrafficCard<Icon: View>: View {
     
     
    @Environment(\.locale) private var locale
    let traffic: AppleClientTrafficSnapshot
    @Binding var scope: HakoHomeTrafficScope
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let _ = HakoPerf.count("home.traffic.card")
        HakoHomePrimaryPageCard(palette: palette) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.standard
            ) {
                HakoHomeCardTitle(
                    cardTitle: HakoHomeCard.traffic.title,
                    symbol: HakoHomeCard.traffic.symbol,
                    icon: icon
                )
                metrics
                rateHistory
                HakoHomeTrafficScopeTabs(scope: $scope)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("home.traffic.scope")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.card.traffic")
        .modifier(HakoTrafficCardHeightWitness())
    }

    @ViewBuilder
    private var metrics: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: HakoTheme.Spacing.row) {
                uploadMetric
                downloadMetric
            }
        } else {
            HStack(
                alignment: .top,
                spacing: HakoTheme.Spacing.row
            ) {
                uploadMetric
                downloadMetric
            }
        }
    }

     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private var rateHistory: some View {
        let series = HakoTrafficSeries.normalizedPair(
            upload: traffic.uploadRatesBytesPerSecond,
            download: traffic.downloadRatesBytesPerSecond
        )
        let hasShape = series.upload.count >= 2
            || series.download.count >= 2
        let hasTraffic = series.upload.contains { $0 > 0 }
            || series.download.contains { $0 > 0 }
         
         
         
         
         
         
        ZStack(alignment: .bottom) {
            if hasShape, hasTraffic {
                 
                 
                HakoRateSparkline(
                    series: [
                        .init(values: series.download, tint: .blue),
                        .init(values: series.upload, tint: .green),
                    ]
                )
                .accessibilityLabel(
                    "Upload and download over the last 30 seconds"
                )
                .accessibilityIdentifier("home.traffic.history")
            } else {
                 
                 
                 
                 
                 
                HakoRateSparkline(
                    series: [
                        .init(
                            values: [0, 0],
                            tint: palette.separator
                        ),
                    ]
                )
                .accessibilityLabel(
                    "No traffic in the last 30 seconds"
                )
                .accessibilityIdentifier("home.traffic.history.zero")
            }
        }
        .frame(height: 34)
    }

    private var uploadMetric: some View {
        metric(
            title: "Upload",
            symbol: .arrowUp,
            tint: .green,
            rate: HakoHomeByteRateFormatter.string(
                traffic.uploadBytesPerSecond
            ),
            total: HakoHomeByteCountFormatter.string(
                traffic.uploadTotalBytes
            )
        )
    }

    private var downloadMetric: some View {
        metric(
            title: "Download",
            symbol: .arrowDown,
            tint: .blue,
            rate: HakoHomeByteRateFormatter.string(
                traffic.downloadBytesPerSecond
            ),
            total: HakoHomeByteCountFormatter.string(
                traffic.downloadTotalBytes
            )
        )
    }

    private func metric(
        title: String,
        symbol: HakoSymbol,
        tint: Color,
        rate: String,
        total: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(HakoCopy.key(title))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            } icon: {
                icon(symbol).foregroundStyle(tint)
            }
             
             
            Text(rate)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(
                verbatim: "\(total) \(HakoCopy.string("total", locale: locale))"
            )
            .font(.caption)
            .foregroundStyle(.tertiary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

 
 
 
 
 
 
private struct HakoTrafficCardHeightWitness: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
            content.onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                HakoPerf.emit("traffic-card height=\(Int(height))")
            }
        } else {
            content
        }
    }
}

private struct HakoHomeExternalIPCard<Icon: View>: View {
    let snapshot: HakoHomeEgressSnapshot
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon
    let refresh: () -> Void

    var body: some View {
        HakoHomePrimaryPageCard(palette: palette) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.compact
            ) {
                HStack(spacing: HakoTheme.Spacing.row) {
                    HakoHomeCardTitle(
                        cardTitle: HakoHomeCard.externalIP.title,
                        symbol: HakoHomeCard.externalIP.symbol,
                        icon: icon
                    )
                    Spacer(minLength: 0)
                    Button(action: refresh) {
                        icon(.arrowClockwise)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(
                                snapshot.canRefresh
                                    ? AnyShapeStyle(.tint)
                                    : AnyShapeStyle(.secondary)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!snapshot.canRefresh)
                    .accessibilityIdentifier("home.externalIP.check")
                }
                 
                 
                 
                 
                HStack(spacing: HakoTheme.Spacing.compact) {
                    if let address = snapshot.address,
                       !snapshot.flag.isEmpty {
                        let _ = address
                        HakoRegionalFlag.label(snapshot.flag, pointSize: 20, relativeTo: .title3).font(.title3)
                    }
                     
                     
                    Text(snapshot.address ?? "—")
                        .font(.title3.weight(.semibold).monospaced())
                        .foregroundStyle(
                            snapshot.address == nil ? .secondary : .primary
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                Group {
                    if snapshot.address != nil, !snapshot.detail.isEmpty {
                        Text(hako: .verbatim(snapshot.detail))
                    } else {
                        Text(HakoCopy.key(
                            snapshot.isChecking
                                ? "Checking…"
                                : "Connect Clash to check"
                        ))
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.card.externalIP")
    }
}

private struct HakoHomeLANIPCard<Icon: View>: View {
    let address: String?
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon
    let refresh: () -> Void

    var body: some View {
        HakoHomePrimaryPageCard(palette: palette) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.compact
            ) {
                HStack(spacing: HakoTheme.Spacing.row) {
                    HakoHomeCardTitle(
                        cardTitle: HakoHomeCard.lanIP.title,
                        symbol: HakoHomeCard.lanIP.symbol,
                        icon: icon
                    )
                    Spacer(minLength: 0)
                    Button(action: refresh) {
                        icon(.arrowClockwise)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.lanIP.refresh")
                }
                 
                 
                 
                Text(address ?? "—")
                    .font(.title3.weight(.semibold).monospaced())
                    .foregroundStyle(address == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(
                    HakoCopy.key(
                        address != nil
                            ? "This device"
                            : "Not on a local network"
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.card.lanIP")
        .onAppear(perform: refresh)
    }
}

private struct HakoHomeRoutingCard<Icon: View>: View {
    let mode: AppleClientOutboundMode
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon
    let setMode: (AppleClientOutboundMode) -> Void

     
     
     
    @Namespace private var selectionBand

     
     
     
     
     
     
     
     
     
     
     
     
    @State private var isCollapsingSelection = false

     
     
    static func symbol(for mode: AppleClientOutboundMode) -> HakoSymbol {
        switch mode {
        case .global: .arrowTriangleMerge
        case .direct: .arrowLeftAndRight
        default: .arrowTriangleBranch
        }
    }

    var body: some View {
        HakoHomePrimaryPageCard(
            palette: palette,
            managesHorizontalInsets: true
        ) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.standard
            ) {
                HakoHomeCardTitle(
                    cardTitle: HakoHomeCard.routing.title,
                    symbol: Self.symbol(for: mode),
                    followsAccent: true,
                    icon: icon
                )
                .padding(.horizontal, HakoTheme.Spacing.standard)
                VStack(spacing: 0) {
                    modeRows
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.card.routing")
    }

    @ViewBuilder
    private var modeRows: some View {
        modeRow(
            .global,
            title: "Global",
            subtitle:
                "Send all traffic through the selected proxy"
        )
        modeRow(
            .rule,
            title: "Rule",
            subtitle: "Route traffic by the profile rules"
        )
        modeRow(
            .direct,
            title: "Direct",
            subtitle: "Connect directly, without a proxy"
        )
    }


    private func modeRow(
        _ candidate: AppleClientOutboundMode,
        title: String,
        subtitle: String
    ) -> some View {
        let isSelected = mode == candidate
        return Button {
             
             
             
             
             
            withAnimation(
                .spring(response: 0.36, dampingFraction: 0.82)
            ) {
                setMode(candidate)
            }
        } label: {
            HStack(
                alignment: .center,
                spacing: HakoTheme.Spacing.row
            ) {
                 
                 
                 
                 
                HakoSelectionMark(isSelected: isSelected)
                VStack(alignment: .leading, spacing: 3) {
                    Text(HakoCopy.key(title))
                        .font(
                            .title3.weight(
                                isSelected ? .bold : .semibold
                            )
                        )
                        .foregroundStyle(titleStyle(isSelected))
                    if isSelected, !isCollapsingSelection {
                        Text(HakoCopy.key(subtitle))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                             
                             
                             
                             
                             
                            .transition(.opacity)
                    }
                }
                Spacer(minLength: 0)
            }
             
             
             
             
             
             
             
            .padding(.vertical, HakoTheme.Spacing.row)
            .padding(.horizontal, HakoTheme.Spacing.standard)
            .frame(
                maxWidth: .infinity,
                minHeight: HakoHomeOutboundModeRowMetrics.minimumHeight,
                alignment: .leading
            )
            .background(selectionBackground(isSelected))
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityIdentifier("home.mode.\(candidate.rawValue)")
    }

    @ViewBuilder
    private func selectionBackground(_ isSelected: Bool) -> some View {
         
         
         
        if isSelected {
            selectionFill
                .matchedGeometryEffect(
                    id: "home.routing.selection",
                    in: selectionBand
                )
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func titleStyle(_ isSelected: Bool) -> AnyShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary)
    }

     
     
     
     
     
    private var selectionFill: some View {
        Rectangle().fill(.quaternary)
    }
}

private struct HakoHomeDomainCountCard<Icon: View>: View {
    @Environment(\.locale)
    private var locale
    let card: HakoHomeCard
    let snapshot: HakoHomeDomainSnapshot
    let identifier: String
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HakoHomePrimaryPageCard(
            palette: palette,
            isInteractive: true
        ) {
            Button(action: action) {
                summary
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityIdentifier(identifier)
        }
        .accessibilityElement(children: .contain)
    }

    private var summary: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.compact
        ) {
            HStack(spacing: 0) {
                HakoHomeCardTitle(
                    cardTitle: card.title,
                    symbol: card.symbol,
                    icon: icon
                )
                Spacer(minLength: HakoTheme.Spacing.compact)
                icon(.chevronForward)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            if let count = snapshot.count {
                countSummary(count)
            }
            if !snapshot.names.isEmpty {
                HakoRegionalFlag.label(snapshot.names.joined(separator: " · "), pointSize: 12, relativeTo: .caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(
                        dynamicTypeSize.isAccessibilitySize ? 3 : 1
                    )
                    .truncationMode(.middle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func countSummary(_ count: Int) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.tight
            ) {
                countLabel(count)
                breakdownLabel
            }
        } else {
            HStack(
                alignment: .firstTextBaseline,
                spacing: HakoTheme.Spacing.compact
            ) {
                countLabel(count)
                breakdownLabel
            }
        }
    }

     
     
     
     
    private func countLabel(_ count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(count, format: .number)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
            if let unit = snapshot.countUnit {
                Text(hako: .copy(unit))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
         
         
         
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenCount(count))
        .accessibilityIdentifier("\(identifier).count")
    }

     
    private func spokenCount(_ count: Int) -> String {
        let number = count.formatted(.number.locale(locale))
        guard let unit = snapshot.countUnit else { return number }
        return "\(number) \(HakoCopy.string(unit, locale: locale))"
    }

    @ViewBuilder
    private var breakdownLabel: some View {
        if let breakdown = snapshot.breakdown {
            Text(breakdown)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(identifier).breakdown")
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                .fixedSize(
                    horizontal: false,
                    vertical: dynamicTypeSize.isAccessibilitySize
                )
        }
    }

    private var accessibilitySummary: String {
        var result = HakoCopy.string(card.title, locale: locale)
        if let count = snapshot.count {
            result = "\(count) \(result)"
        }
        if let breakdown = snapshot.breakdown {
            result += ", \(breakdown)"
        }
        return result
    }
}

private struct HakoHomeAdjustmentCard<Icon: View>: View {
    let snapshot: HakoHomeAdjustmentSnapshot
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon
    let perform: (HakoHomeAdjustmentAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HakoHomePrimaryPageCard(palette: palette) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.standard
            ) {
                HakoHomeCardTitle(
                    cardTitle: snapshot.module.title,
                    symbol: snapshot.module.symbol,
                    icon: icon
                )
                Text(HakoCopy.key(snapshot.summary))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !snapshot.module.actions.isEmpty {
                    actions
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            "home.card.adjust.\(snapshot.module.id)"
        )
    }

    private var actions: some View {
         
         
         
         
        HakoModuleEntries(
            entries: snapshot.module.actions.map { action in
                HakoModuleEntry(
                    id: action.rawValue,
                    title: action.title
                ) {
                    perform(action)
                }
            },
            palette: palette,
            stacked: dynamicTypeSize.isAccessibilitySize,
            identifier: { "home.modify.\(snapshot.module.id).\($0.id)" }
        )
    }

}


private struct HakoHomeCardCustomizationView<Icon: View>: View {
    @Binding var cards: [HakoHomeCard]
    let palette: HakoProductPalette
    let customizationPresentation: (AnyView) -> AnyView
    let icon: (HakoSymbol) -> Icon

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var availableCards: [HakoHomeCard] {
        HakoHomeCatalog.optionalCards.filter { !cards.contains($0) }
    }

    var body: some View {
        HakoSingleColumnNavigationContainer {
            customizationPresentation(AnyView(content))
        }
         
         
         
         
         
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.cards.customization")
    }

    private var content: some View {
        List {
            if dynamicTypeSize.isAccessibilitySize {
                Text(HakoCopy.key("Customize Cards"))
                    .font(.largeTitle.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .listRowBackground(Color.clear)
            }

            Section {
                ForEach(cards) { card in
                    cardLabel(card)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        HakoCopy.key(card.title)
                    )
                    .accessibilityIdentifier(
                        "home.cards.favorite.\(card.rawValue)"
                    )
                    .accessibilityValue(
                        HakoHomeCatalog.requiredCards.contains(card)
                            ? "Required"
                            : "Optional"
                    )
                    .accessibilityHint(
                        HakoHomeCatalog.requiredCards.contains(card)
                            ? "Always stays on Home"
                            : "Can be removed from Home"
                    )
                    .deleteDisabled(
                        HakoHomeCatalog.requiredCards.contains(card)
                    )
                    .id("favorite.\(card.rawValue)")
                }
                .onDelete { offsets in
                    cards.remove(
                        atOffsets: IndexSet(
                            offsets.filter {
                                !HakoHomeCatalog.requiredCards.contains(
                                    cards[$0]
                                )
                            }
                        )
                    )
                }
                .onMove {
                    cards.move(fromOffsets: $0, toOffset: $1)
                }
            } header: {
                Text(HakoCopy.key("Favorites"))
            } footer: {
                Text(
                    HakoCopy.key(
                        "Outbound Mode, Proxies, and Rules always stay on Home. Drag any card to change the order."
                    )
                )
            }

            if !availableCards.isEmpty {
                Section(HakoCopy.key("Available")) {
                    ForEach(availableCards) { card in
                        Button {
                            cards.append(card)
                        } label: {
                            HStack {
                                cardLabel(card)
                                Spacer()
                                icon(.plus)
                                    .foregroundStyle(.tint)
                            }
                        }
                        .accessibilityIdentifier(
                            "home.cards.available.\(card.rawValue)"
                        )
                        .id("available.\(card.rawValue)")
                    }
                }
            }
        }
        .navigationTitle(
            dynamicTypeSize.isAccessibilitySize
                ? ""
                : HakoCopy.key("Customize Cards")
        )
        .hakoToolbarUnlessInPanel {
             
             
             
            ToolbarItem(placement: .cancellationAction) {
                HakoSheetCloseButton { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(HakoCopy.key("Reset")) {
                    cards = HakoHomeCatalog.defaultCards
                }
            }
        }
    }

    @ViewBuilder
    private func cardLabel(_ card: HakoHomeCard) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text(HakoCopy.key(card.title))
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Label {
                Text(HakoCopy.key(card.title))
            } icon: {
                 
                 
                if card.symbol == .serverRack {
                    icon(card.symbol)
                        .font(.body.weight(.light))
                } else {
                    icon(card.symbol)
                }
            }
        }
    }
}

 
 
private enum HakoHomeByteRateFormatter {
    static func string(_ bytesPerSecond: Int64) -> String {
        HakoThroughputFormatter.rate(bytesPerSecond)
    }
}

 
 
private enum HakoHomeByteCountFormatter {
    static func string(_ bytes: Int64) -> String {
        HakoThroughputFormatter.usage(bytes)
    }
}

 
 
 
 
 
 
private struct HakoHomeDurationTicker: ViewModifier {
    @Binding var now: Date

    func body(content: Content) -> some View {
        content
            .onAppear { now = Date() }
            .modifier(HakoSecondTick(now: $now))
    }
}

private struct HakoSecondTick: ViewModifier {
    @Binding var now: Date

    func body(content: Content) -> some View {
        if HakoPerfExperiment.suppressesDurationTick {
            content
        } else if #available(iOS 15.0, macOS 12.0, tvOS 15.0, *) {
            content.task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    now = Date()
                }
            }
        } else {
            content
        }
    }
}

 
extension HakoProductPalette: Equatable {}

 

 
 
 
 
extension HakoHomeTrafficCard: @MainActor Equatable {
    static func == (a: Self, b: Self) -> Bool {
        a.traffic == b.traffic && a.scope == b.scope && a.palette == b.palette
    }
}

extension HakoHomeExternalIPCard: @MainActor Equatable {
    static func == (a: Self, b: Self) -> Bool {
        a.snapshot == b.snapshot && a.palette == b.palette
    }
}

extension HakoHomeLANIPCard: @MainActor Equatable {
    static func == (a: Self, b: Self) -> Bool {
        a.address == b.address && a.palette == b.palette
    }
}

extension HakoHomeRoutingCard: @MainActor Equatable {
    static func == (a: Self, b: Self) -> Bool {
        a.mode == b.mode && a.palette == b.palette
    }
}

extension HakoHomeDomainCountCard: @MainActor Equatable {
    static func == (a: Self, b: Self) -> Bool {
        a.card == b.card && a.snapshot == b.snapshot
            && a.identifier == b.identifier && a.palette == b.palette
    }
}

extension HakoHomeAdjustmentCard: @MainActor Equatable {
    static func == (a: Self, b: Self) -> Bool {
        a.snapshot == b.snapshot && a.palette == b.palette
    }
}
