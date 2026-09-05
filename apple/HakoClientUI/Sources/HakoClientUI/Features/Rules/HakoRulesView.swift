import Foundation
import SwiftUI

 
 
 
 
 
 
struct HakoRuleBucketRoute: Hashable {
    let target: String
}

 
 
 
 
 
 
 
 
 
 
 
enum HakoRuleRowLayout {
    static func showsTypeLine(payload: String) -> Bool {
        !payload.isEmpty
    }
}

private struct HakoRuleBucketRowChrome: ViewModifier {
    let bucket: HakoRuleBucketSnapshot

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .accessibilityLabel(
                "\(bucket.rules.count) rules to \(bucket.target)"
            )
            .accessibilityIdentifier("rules.bucket.\(bucket.target)")
    }
}

public struct HakoRulesOverviewView<
    Icon: View,
    ActiveRules: View
>: View {
     
     
    @Environment(\.locale)
    private var locale
    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let presentationClass: HakoPresentationClass
    private let searchPlacement: SearchFieldPlacement
    private let palette: HakoProductPalette
    private let icon: (HakoSymbol) -> Icon
     
     
     
     
     
     
     
    private let activeRulesDestination: () -> ActiveRules
    private let showsDismissControl: Bool

     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPushRoute) private var pushRoute
    @Environment(\.hakoPopRoute) private var popRoute
    @Environment(\.hakoDetailCanvas) private var inheritedDetailCanvas
     
     
     
    @Environment(\.hakoRegularRootSearchText) private var externalSearchText
    @Environment(\.hakoHostedInRootPool) private var hostedInRootPool
    @State private var query = ""
     
     
     
     
    @State private var identityStamp = UUID()

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        presentationClass: HakoPresentationClass,
        searchPlacement: SearchFieldPlacement = .automatic,
        palette: HakoProductPalette,
        showsDismissControl: Bool = true,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        @ViewBuilder activeRulesDestination: @escaping () -> ActiveRules
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.presentationClass = presentationClass
        self.searchPlacement = searchPlacement
        self.palette = palette
        self.showsDismissControl = showsDismissControl
        self.icon = icon
        self.activeRulesDestination = activeRulesDestination
    }

    public var body: some View {
        routedRootPage
            .onAppear {
                HakoPerf.emit(
                    "rules entry-open id=\(identityStamp.uuidString.prefix(5))"
                )
            }
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private var routedRootPage: some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            rootPage
                .navigationDestination(for: HakoRuleBucketRoute.self) { route in
                    HakoLazyView {
                        Group {
                            if let bucket = overview.buckets.first(
                                where: { $0.target == route.target }
                            ) {
                                bucketDetail(bucket)
                            } else {
                                 
                                 
                                 
                                HakoEmptyState(
                                    title: "Rules Changed",
                                    message:
                                        "This group is no longer in the profile's rules."
                                ) {
                                    icon(.exclamationmarkTriangle)
                                }
                            }
                        }
                        .hakoPushedDetailPage()
                        .modifier(HakoSetterRoutedBack())
                         
                         
                        .environment(\.hakoPushRoute, pushRoute)
                        .environment(\.hakoPopRoute, popRoute)
                        .environment(\.hakoDetailCanvas, inheritedDetailCanvas)
                        .environment(
                            \.hakoRegularShellOwnsCanvas,
                            HakoPushedCanvasOwnership.shellOwnsPushedCanvas
                        )
                    }
                }
        } else {
            rootPage
        }
    }

     
     
    private var effectiveQuery: String {
        externalSearchText ?? query
    }

     
     
     
     
    @ViewBuilder
    private var rootPage: some View {
        if externalSearchText == nil {
            undecoratedRootPage
                 
                 
                .hakoFrameWatch("rules-page")
                .searchable(
                    text: $query,
                    placement: searchPlacement,
                    prompt: Text("Search rules")
                )
                .hakoToolbarUnlessInPanel {
                     
                     
                     
                     
                    ToolbarItem(placement: .cancellationAction) {
                        if showsDismissControl {
                            HakoSheetCloseButton { dismiss() }
                        }
                    }
                }
        } else {
            undecoratedRootPage
        }
    }

    private var undecoratedRootPage: some View {
        HakoRulesBrowserHost {
             
             
            HakoRulesSystemOverview(
                overview: overview,
                query: effectiveQuery,
                palette: palette,
                icon: icon,
                activeRulesEntry: AnyView(activeRulesEntry(selfDrawnDisclosure: false))
            )
            .hakoContentHeading("Rules")
            .accessibilityIdentifier("rules.overview")
            .environment(\.hakoDetailCanvas, palette.canvas)
        } legacy: {
            legacyRootPage
        }
    }

    private var legacyRootPage: some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "rules.product.root",
             
             
             
             
             
             
             
            hostsSelfDrawnCards: true
        ) {
            if effectiveQuery.isEmpty {
                overviewSections
            } else {
                searchResults
            }
            activeRulesEntry(selfDrawnDisclosure: true)
        }
        .hakoContentHeading("Rules")
        .accessibilityIdentifier("rules.overview")
        .environment(\.hakoDetailCanvas, palette.canvas)
    }

    private var overview: HakoRulesOverviewSnapshot {
        snapshot.rules.overview
    }

     
     
     
     
     
    private func activeRulesEntry(selfDrawnDisclosure: Bool) -> some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            HakoRoutedViewLink(showsDisclosureIndicator: false) {
                activeRulesDestination()
                .hakoPushedDetailPage()
            } label: {
                HStack(spacing: HakoTheme.Spacing.row) {
                    icon(.docTextMagnifyingglass)
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)

                    VStack(
                        alignment: .leading,
                        spacing: HakoTheme.Spacing.tight
                    ) {
                        Text("Active Rules")
                            .font(.body.weight(.semibold))
                        Text(
                            snapshot.rules.canInspectActiveRules
                                ? "Inspect the rules currently loaded by the running core."
                                : "Connect Clash to inspect the rules loaded by the running core."
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: HakoTheme.Spacing.compact)

                     
                     
                    if selfDrawnDisclosure {
                        icon(.chevronForward)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .padding(HakoTheme.Spacing.standard)
            }
            .buttonStyle(.plain)
            .disabled(!snapshot.rules.canInspectActiveRules)
            .accessibilityIdentifier("rules.overview.active-rules")
        }
    }

    @ViewBuilder
    private var overviewSections: some View {
        if !overview.buckets.isEmpty {
            HakoProductGroup(
                .format(
                    "Subscription Rules (%@)",
                    [String(overview.inlineCount)]
                ),
                footer:
                    "Grouped by destination. Updates from the subscription replace these rules.",
                palette: palette
            ) {
                 
                 
                 
                 
                 
                 
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.standard
                ) {
                    if overview.inapplicableCount > 0 {
                        inapplicableNotice
                    }

                     
                     
                     
                     
                    LazyVStack(spacing: 0) {
                        ForEach(overview.buckets) { bucket in
                            bucketLink(bucket)
                            if bucket.id != overview.buckets.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }

        if !overview.ruleSets.isEmpty {
            HakoProductGroup(
                .format(
                    "Rule Sets (%@)",
                    [String(overview.ruleSets.count)]
                ),
                palette: palette
            ) {
                LazyVStack(spacing: 0) {
                    ForEach(overview.ruleSets) { ruleSet in
                        ruleSetRow(ruleSet)
                        if ruleSet.id != overview.ruleSets.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }

        if !overview.fallback.isEmpty {
            HakoProductGroup(
                "Fallback",
                footer: "Traffic that matches nothing above.",
                palette: palette
            ) {
                LazyVStack(spacing: 0) {
                    ForEach(overview.fallback) { rule in
                        ruleRow(
                            rule,
                            verticalInset: HakoTheme.Spacing.compact
                        )
                        if rule.id != overview.fallback.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }

        if overview.buckets.isEmpty
            && overview.ruleSets.isEmpty
            && overview.fallback.isEmpty
        {
            HakoProductGroup(palette: palette) {
                HakoEmptyState(
                    title: "No Rules",
                    message:
                        "This profile does not declare routing rules or rule providers."
                ) {
                    icon(.listBulletRectangle)
                }
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let hits = overview.search(effectiveQuery)
        let rows = Array(hits.prefix(100))
        HakoProductGroup(
            .format("%@ matches", [String(hits.count)]),
            palette: palette
        ) {
             
             
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.standard
            ) {
                    if hits.isEmpty {
                        Text("No matching rules")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(rows) { rule in
                                ruleRow(
                                    rule,
                                    verticalInset: HakoTheme.Spacing.compact
                                )
                                if rule.id != rows.last?.id {
                                    Divider()
                                }
                            }
                            if hits.count > 100 {
                                Text("\(hits.count - 100) more matches…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(
                                        .top,
                                        HakoTheme.Spacing.row
                                    )
                            }
                        }
                    }
            }
        }
    }

     
     
     
     
     
    @ViewBuilder
    private func bucketLink(_ bucket: HakoRuleBucketSnapshot) -> some View {
        if hostedInRootPool, let pushRoute {
             
             
             
             
             
             
            Button {
                let token = UUID()
                let bucket = bucket
                HakoViewRouteRegistry.set(token, onReturn: {}) {
                    AnyView(bucketDetail(bucket))
                }
                pushRoute(HakoViewRoute(id: token))
            } label: {
                bucketRowLabel(bucket)
            }
            .modifier(HakoRuleBucketRowChrome(bucket: bucket))
        } else if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            NavigationLink(
                value: HakoRuleBucketRoute(target: bucket.target)
            ) {
                bucketRowLabel(bucket)
            }
            .modifier(HakoRuleBucketRowChrome(bucket: bucket))
        } else {
            HakoRoutedViewLink {
                bucketDetail(bucket)
                    .hakoPushedDetailPage()
            } label: {
                bucketRowLabel(bucket)
            }
            .modifier(HakoRuleBucketRowChrome(bucket: bucket))
        }
    }

    private func bucketRowLabel(
        _ bucket: HakoRuleBucketSnapshot
    ) -> some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            Text(bucket.target)
                .font(.body.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("\(bucket.rules.count)")
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
             
             
             
             
            icon(.chevronForward)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, HakoTheme.Spacing.row)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func bucketDetail(
        _ bucket: HakoRuleBucketSnapshot
    ) -> some View {
        HakoRulesBrowserHost {
            HakoRuleBucketSystemPage(
                bucket: bucket,
                jumpCard: overview.jumpableTargets.contains(bucket.target)
                    ? AnyView(bucketJumpLabel(bucket, inset: 0))
                    : nil,
                palette: palette
            )
        } legacy: {
          Group {
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                HakoRuleBucketLazyPage(
                    bucket: bucket,
                     
                     
                     
                    jumpCard: overview.jumpableTargets.contains(bucket.target)
                        ? AnyView(
                            HakoCardSurface(
                                fill: palette.card,
                                separator: palette.separator
                            ) {
                                bucketJumpLabel(
                                    bucket,
                                    inset: HakoTheme.Spacing.standard
                                )
                            }
                        )
                        : nil,
                    palette: palette
                )
            } else {
                bucketCardPage(bucket)
            }
          }
        }
        .hakoPageTitle(.verbatim(bucket.target), watchAs: "rules-bucket")
    }

     
    private func bucketCardPage(
        _ bucket: HakoRuleBucketSnapshot
    ) -> some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "rules.bucket.\(bucket.target)"
        ) {
             
             
            if overview.jumpableTargets.contains(bucket.target) {
                HakoCardSurface(
                    fill: palette.card,
                    separator: palette.separator
                ) {
                    bucketJumpLabel(
                        bucket,
                        inset: HakoTheme.Spacing.standard
                    )
                }
            }
             
             
            let rows = Array(bucket.rules.prefix(200))
            HakoCardSurface(
                fill: palette.card,
                separator: palette.separator
            ) {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { rule in
                        ruleRow(
                            rule,
                            verticalInset: HakoTheme.Spacing.compact
                        )
                        if rule.id != rows.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(HakoTheme.Spacing.standard)
            }
        }
    }

     
     
     
     
    private func bucketJumpLabel(
        _ bucket: HakoRuleBucketSnapshot,
        inset: CGFloat = 0
    ) -> some View {
        Button {
            send(.openProxiesGroup(name: bucket.target))
        } label: {
            HStack(spacing: HakoTheme.Spacing.row) {
                icon(.serverRack)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.tight
                ) {
                    Text(
                        HakoCopy.format(
                            "Open %@ in Proxies",
                            locale: locale,
                            bucket.target
                        )
                    )
                    .font(.body.weight(.semibold))
                    Text("These rules send traffic there.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: HakoTheme.Spacing.compact)
                 
                icon(.chevronForward)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(inset)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("rules.jump.\(bucket.target)")
    }


     
    private var inapplicableNotice: some View {
        HStack(spacing: 4) {
            icon(.infoCircle)
                .font(.caption)
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            Text(
                HakoCopy.format(
                    "%1$d rules will not take effect on %2$@",
                    locale: locale,
                    overview.inapplicableCount,
                    overview.platformTitle
                )
            )
            .font(.footnote)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("rules.inapplicable")
    }

     
     
    private func ruleSetRow(_ ruleSet: HakoRuleSetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HakoRegionalFlag.label(ruleSet.name, pointSize: 17, relativeTo: .body)
                .font(.body.weight(.semibold))
            Text(hako: .verbatim(ruleSet.subtitle(locale: locale)))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let reason = ruleSet.blockedReason {
                 
                 
                 
                 
                Text(hako: .copy("Not in the runtime"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier(
                        "rules.rule-set.blocked.\(ruleSet.name)"
                    )
                Text(hako: .verbatim(reason))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
         
         
         
        .padding(.vertical, HakoTheme.Spacing.row)
    }

    private func ruleRow(
        _ rule: HakoRuleLineSnapshot,
        verticalInset: CGFloat
    ) -> some View {
         
         
         
         
        HakoPerf.count("rules.row.make")
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.payload.isEmpty ? rule.type : rule.payload)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if HakoRuleRowLayout.showsTypeLine(payload: rule.payload) {
                    Text(rule.type)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
             
             
             
            Text(rule.target)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(palette.raisedFill))
        }
        .padding(.vertical, verticalInset)
    }

    private func send(_ command: HakoRulesCommand) {
        Task {
            try? await actions.perform(
                .rules(command),
                allowedBy: snapshot
            )
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoRuleBucketLazyPage: View {
    let bucket: HakoRuleBucketSnapshot
     
     
    let jumpCard: AnyView?
    let palette: HakoProductPalette

     
    static var renderedRowCap: Int { 200 }

    @Environment(\.locale) private var locale

    var body: some View {
        let rows = Array(bucket.rules.prefix(Self.renderedRowCap))
        let lastIndex = rows.count - 1
        return ScrollView {
            LazyVStack(spacing: 0) {
                if let jumpCard {
                    jumpCard
                        .padding(.bottom, HakoTheme.Spacing.section)
                }
                HakoSectionCaption(
                     
                     
                     
                    .verbatim(
                        HakoCopy.format(
                            "%d rules",
                            locale: locale,
                            bucket.rules.count
                        )
                    )
                )
                 
                 
                 
                .padding(.bottom, HakoTheme.Spacing.cardGap)
                ForEach(
                    Array(rows.enumerated()),
                    id: \.offset
                ) { index, rule in
                    ruleRow(rule)
                        .padding(.horizontal, HakoTheme.Spacing.standard)
                        .padding(
                            .top,
                            index == 0 ? HakoTheme.Spacing.standard : 0
                        )
                        .padding(
                            .bottom,
                            index == lastIndex
                                ? HakoTheme.Spacing.standard
                                : 0
                        )
                        .background(
                            rowCardSlice(index: index, lastIndex: lastIndex)
                        )
                        .overlay(alignment: .bottom) {
                            if index != lastIndex {
                                Divider()
                                    .padding(
                                        .horizontal,
                                        HakoTheme.Spacing.standard
                                    )
                            }
                        }
                }
                if bucket.rules.count > rows.count {
                    Text(
                        HakoCopy.format(
                            "%d more rules",
                            locale: locale,
                            bucket.rules.count - rows.count
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, HakoTheme.Spacing.row)
                }
            }
            .padding(.vertical, HakoTheme.Spacing.section)
             
             
             
             
             
             
             
             
            .padding(.horizontal, HakoTheme.Spacing.standard)
        }
         
         
         
        .environment(\.hakoPageDrawsOwnCards, true)
        .accessibilityIdentifier("rules.bucket.\(bucket.target)")
    }

     
    @ViewBuilder
    private func rowCardSlice(index: Int, lastIndex: Int) -> some View {
        if #available(iOS 16.4, macOS 13.3, tvOS 16.4, *) {
            UnevenRoundedRectangle(
                topLeadingRadius:
                    index == 0 ? HakoTheme.Radius.card : 0,
                bottomLeadingRadius:
                    index == lastIndex ? HakoTheme.Radius.card : 0,
                bottomTrailingRadius:
                    index == lastIndex ? HakoTheme.Radius.card : 0,
                topTrailingRadius:
                    index == 0 ? HakoTheme.Radius.card : 0,
                style: .continuous
            )
            .fill(palette.card)
        } else {
             
             
             
            Rectangle().fill(palette.card)
        }
    }

     
     
     
     
    private func ruleRow(_ rule: HakoRuleLineSnapshot) -> some View {
         
         
        HakoPerf.count("rules.row.make")
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.payload.isEmpty ? rule.type : rule.payload)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if HakoRuleRowLayout.showsTypeLine(payload: rule.payload) {
                    Text(rule.type)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(rule.target)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(palette.raisedFill))
        }
        .padding(.vertical, HakoTheme.Spacing.compact)
    }
}

 
 
 
 
 
 
 
 
 
 
public typealias HakoRuleGeoValueLoader = @MainActor (
    HakoRuleGeoResource
) async -> [String]

public struct HakoProfileRulesView<Icon: View, Trailing: View>: View {
    public typealias GeoValueLoader = HakoRuleGeoValueLoader
    public typealias PolicyOptionsLoader = @MainActor () async
        -> HakoRulePolicyOptions

    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let presentationClass: HakoPresentationClass
    private let runtimeProfile: HakoAppleRuntimeProfile
    private let palette: HakoProductPalette
    private let showsDismissControl: Bool
    private let loadPolicyOptions: PolicyOptionsLoader?
    private let loadGeoValues: GeoValueLoader
    private let icon: (HakoSymbol) -> Icon
     
     
     
     
     
     
     
     
     
     
    private let trailing: Trailing

     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draft: HakoProfileRulesDraft
     
     
     
     
     
     
     
    @State private var openedWith: HakoProfileRulesDraft
    @State private var editingRule: HakoRuleEditTarget?
    @State private var pendingRule: HakoRuleEditTarget?
    @State private var loadedPolicyOptions: HakoRulePolicyOptions?
    @State private var isLoadingPolicyOptions = false
    @State private var showsRuleOrder = false
    @State private var isSaving = false
     
     
     
    @State private var selectedRules: Set<UUID> = []
    @State private var asksAboutBulkDelete = false
     
    @State private var draftRows = HakoIdentifiedRows()

    private func deleteSelectedRules() {
        let indices = Set(selectedRules.compactMap { draftRows.index(of: $0) })
        draft.rules = HakoRuleDeletion.removing(indices, from: draft.rules)
        draftRows.resync(count: draft.rules.count)
        selectedRules = []
    }
    @State private var error = ""
    @State private var didOpenInitialRule = false

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        presentationClass: HakoPresentationClass,
        runtimeProfile: HakoAppleRuntimeProfile,
        palette: HakoProductPalette,
        showsDismissControl: Bool = true,
        loadPolicyOptions: PolicyOptionsLoader? = nil,
        loadGeoValues: @escaping GeoValueLoader,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.presentationClass = presentationClass
        self.runtimeProfile = runtimeProfile
        self.palette = palette
        self.showsDismissControl = showsDismissControl
        self.loadPolicyOptions = loadPolicyOptions
        self.loadGeoValues = loadGeoValues
        self.icon = icon
        self.trailing = trailing()
        let editor = snapshot.rules.editor
        let initialPolicyOptions = editor?.policyOptions ?? .empty
        _loadedPolicyOptions = State(
            initialValue:
                loadPolicyOptions == nil || initialPolicyOptions != .empty
                    ? initialPolicyOptions
                    : nil
        )
        let openingDraft = HakoProfileRulesDraft(
            rules: editor?.rules ?? [],
            prependRules: editor?.prependRules
                ?? HakoProfileRulesSnapshot.prependsByDefault
        )
        _openedWith = State(initialValue: openingDraft)
        _draft = State(
            initialValue: openingDraft
        )
    }

}

public extension HakoProfileRulesView where Trailing == EmptyView {
     
     
     
    init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        presentationClass: HakoPresentationClass,
        runtimeProfile: HakoAppleRuntimeProfile,
        palette: HakoProductPalette,
        showsDismissControl: Bool = true,
        loadGeoValues: @escaping GeoValueLoader,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.init(
            snapshot: snapshot, actions: actions,
            presentationClass: presentationClass, runtimeProfile: runtimeProfile,
            palette: palette, showsDismissControl: showsDismissControl,
            loadGeoValues: loadGeoValues, icon: icon, trailing: { EmptyView() }
        )
    }
}

extension HakoProfileRulesView {
    public var body: some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "profile-rules.product.root"
        ) {
            profileSummary
            personalRules
            priority
            saveBehavior
            trailing
            if !error.isEmpty {
                statusMessage(
                    error,
                    symbol: .exclamationmarkTriangle,
                    color: .red
                )
            }
        }
        .hakoPageTitle("Routing Rules")
        .alert(
            "Delete \(selectedRules.count) rules?",
            isPresented: $asksAboutBulkDelete
        ) {
            Button("Delete", role: .destructive) { deleteSelectedRules() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They are removed from this profile and cannot be brought back.")
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if showsDismissControl && !insideProductModal {
                    Button {
                        dismissPresentation()
                    } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            icon(.xmark)
                        } else {
                            Text("Cancel")
                        }
                    }
                    .accessibilityLabel("Cancel")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if !insideProductModal {
                    Button {
                        persist()
                    } label: {
                        if dynamicTypeSize.isAccessibilitySize {
                            icon(.checkmark)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving)
                    .accessibilityLabel("Save")
                    .accessibilityIdentifier("profile-rules.save")
                }
            }
        }
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: draft != openedWith,
            isBusy: isSaving,
            save: { completion in
                persist()
                completion(true)
            },
            discard: { draft = openedWith }
        )
        .hakoProductModalRoot(title: "Routing Rules")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                HakoModalActionBar(
                    primaryTitle: "Save",
                    primaryDisabled: isSaving,
                    onPrimary: persist
                )
            }
        }
        .hakoProductModal(item: $editingRule, role: .form) { target in
            HakoRuleBuilderView(
                rule: target.rule,
                options: loadedPolicyOptions ?? editor.policyOptions,
                initialRoute: target.initialRoute,
                runtimeProfile: runtimeProfile,
                palette: palette,
                loadGeoValues: loadGeoValues,
                icon: icon
            ) { updated in
                apply(updated, rowID: target.rowID)
            }
            .hakoModalPresentation(.page)
        }
        .hakoProductModal(isPresented: $showsRuleOrder, role: .form) {
            HakoProfileRuleOrderView(
                rules: $draft.rules,
                palette: palette,
                icon: icon
            )
            .hakoModalPresentation(.form)
        }
        .onAppear {
            guard !didOpenInitialRule,
                let raw = editor.initialRuleBuilderRaw
            else {
                return
            }
            didOpenInitialRule = true
            openRuleEditor(HakoRuleEditTarget(
                rowID: nil,
                rule: HakoPersonalRuleSnapshot(raw: raw),
                initialRoute: editor.initialRuleBuilderRoute
            ))
        }
        .accessibilityIdentifier("profile-rules.screen")
        .hakoCapturesDismiss(dismiss)
    }

    private var editor: HakoProfileRulesSnapshot {
        snapshot.rules.editor
            ?? HakoProfileRulesSnapshot(profileName: "Profile")
    }

    private var profileSummary: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            HakoProfileContextHeader(
                profileName: editor.profileName,
                message:
                    "These exceptions belong to this profile. Its imported source stays unchanged."
            ) {
                icon(.profileClipboard)
            }
             
             
             
             
            .padding(.horizontal, HakoTheme.Spacing.standard)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var personalRules: some View {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            groupedPersonalRules
        } else {
            handBuiltPersonalRules
        }
    }

    @ViewBuilder
    private var groupedPersonalRules: some View {
        if draft.rules.isEmpty {
            Section {
                HakoCardEmptyState(
                    title: "No Personal Rules",
                    message: "The profile's own rules remain in effect. Add only the exception you need."
                ) {
                    icon(.listBulletRectangle)
                }
                .padding(.vertical, 10)
                .accessibilityIdentifier("profile-rules.empty")
            } header: {
                personalRulesHeader
            }
            Section {
                addRuleRow
            } footer: {
                personalRulesFootnote
            }
        } else {
            Section {
                rulesRows
                addRuleRow
            } header: {
                personalRulesHeader
            } footer: {
                personalRulesFootnote
            }
        }
    }

    private var personalRulesFootnote: some View {
        Text(
            HakoPlatformLayout.pageUsesSystemSettingsIdiom
                ? "Click a rule to edit it. Use Reorder to change match priority."
                : "Tap to edit. Use Reorder to change match priority."
        )
    }

     
     
     
     
    private var personalRulesHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("PERSONAL RULES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if draft.rules.count >= 2 {
                Button {
                    showsRuleOrder = true
                } label: {
                    Label {
                        Text("Reorder")
                    } icon: {
                        icon(.arrowUpArrowDown)
                    }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .frame(
                    minWidth: HakoTheme.Control.minimumHitTarget,
                    minHeight: HakoTheme.Control.minimumHitTarget
                )
                .contentShape(Rectangle())
                .accessibilityIdentifier("profile-rules.reorder")
            } else {
                Text("Checked top to bottom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var handBuiltPersonalRules: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.cardGap
        ) {
            personalRulesHeader
                .padding(.horizontal, HakoTheme.Spacing.compact)

            if HakoPlatformLayout.collectionLeadsWithEmptyState {
                 
                 
                 
                 
                if draft.rules.isEmpty {
                    rulesCard
                     
                     
                     
                     
                     
                     
                     
                    if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                         
                         
                         
                         
                        Color.clear
                            .frame(height: HakoTheme.Spacing.section)
                    }
                    addRuleCard
                } else {
                    HakoCardSurface(
                        fill: palette.card,
                        separator: palette.separator
                    ) {
                        VStack(spacing: 0) {
                            rulesRows
                            Divider()
                                .padding(.leading, 62)
                            addRuleRow
                        }
                    }
                }
            } else {
                addRuleCard
                rulesCard
            }

            Text(
                HakoPlatformLayout.pageUsesSystemSettingsIdiom
                    ? "Click a rule to edit it. Use Reorder to change match priority."
                    : "Tap to edit. Use Reorder to change match priority."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, HakoTheme.Spacing.compact)
        }
    }


     
     
     
     
     
     
     
     
    private var addRuleRow: some View {
        HakoAddRow(
            Text("Add Rule"),
            context: .standaloneCard,
            action: {
                openRuleEditor(HakoRuleEditTarget(
                    rowID: nil,
                    rule: HakoPersonalRuleSnapshot(raw: ""),
                    initialRoute: nil
                ))
            }
        ) {
            HStack(spacing: HakoTheme.Spacing.row) {
                icon(.plusCircleFill)
                    .font(.title3)
                    .foregroundStyle(.tint)
                Text("Add Rule")
                    .foregroundStyle(.tint)
                Spacer(minLength: 0)
            }
            .padding(HakoTheme.Spacing.standard)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("profile-rules.add")
    }

    private var addRuleCard: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            addRuleRow
        }
    }

    private var rulesCard: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            VStack(spacing: 0) {
                if draft.rules.isEmpty {
                    HakoCardEmptyState(
                        title: "No Personal Rules",
                        message: "The profile's own rules remain in effect. Add only the exception you need."
                    ) {
                        icon(.listBulletRectangle)
                    }
                     
                     
                     
                    .padding(.vertical, 10)
                    .accessibilityIdentifier(
                        "profile-rules.empty"
                    )
                } else {
                    rulesRows
                }
            }
        }
    }

    @ViewBuilder
    private var rulesRows: some View {
        if !selectedRules.isEmpty {
            HStack {
                Button("Cancel") { selectedRules = [] }
                    .frame(
                        minWidth: HakoTheme.Control.minimumHitTarget,
                        minHeight: HakoTheme.Control.minimumHitTarget
                    )
                    .contentShape(Rectangle())
                    .accessibilityIdentifier(
                        "profile-rules.cancel-selection"
                    )
                Spacer()
                Text("\(selectedRules.count) selected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    if HakoRuleDeletion.needsConfirmation(
                        count: selectedRules.count
                    ) {
                        asksAboutBulkDelete = true
                    } else {
                        deleteSelectedRules()
                    }
                } label: {
                    Image(systemName: HakoSymbol.trash.rawValue)
                        .frame(
                            width: HakoTheme.Control.minimumHitTarget,
                            height: HakoTheme.Control.minimumHitTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile-rules.delete-selected")
            }
            .padding(.vertical, HakoTheme.Spacing.compact)
        }

        ForEach(draftRows.current(for: draft.rules)) { row in
            let index = row.index
            let rule = draftRows.index(of: row.id).map { draft.rules[$0] }
                ?? HakoPersonalRuleSnapshot(raw: "")
            Button {
                if !selectedRules.isEmpty {
                    if selectedRules.contains(row.id) {
                        selectedRules.remove(row.id)
                    } else {
                        selectedRules.insert(row.id)
                    }
                    return
                }
                openRuleEditor(HakoRuleEditTarget(
                    rowID: row.id,
                    rule: rule,
                    initialRoute: nil
                ))
            } label: {
                HStack(spacing: HakoTheme.Spacing.compact) {
                    if !selectedRules.isEmpty {
                        Image(
                            systemName: selectedRules.contains(row.id)
                                ? HakoSymbol.checkmarkCircleFill.rawValue
                                : HakoSymbol.circle.rawValue
                        )
                        .foregroundStyle(
                            selectedRules.contains(row.id)
                                ? AnyShapeStyle(.tint)
                                : AnyShapeStyle(.secondary)
                        )
                    }
                    personalRuleRow(
                        rule,
                        index: index
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                "profile-rules.rule.\(index)"
            )
            .contextMenu {
                Button {
                    selectedRules = [row.id]
                } label: {
                    Label(
                        "Select",
                        systemImage: "checkmark.circle"
                    )
                }
                .accessibilityIdentifier(
                    "profile-rules.rule.\(index).select"
                )
                Button {
                    if let index = draftRows.index(of: row.id) {
                        toggleRule(at: index)
                    }
                } label: {
                    Label(
                        rule.isEnabled
                            ? "Disable"
                            : "Enable",
                        systemImage:
                            rule.isEnabled
                                ? "minus.circle"
                                : "checkmark"
                    )
                }
                .accessibilityIdentifier(
                    "profile-rules.rule.\(index).\(rule.isEnabled ? "disable" : "enable")"
                )
                Button(role: .destructive) {
                    draftRows.remove(row.id, from: &draft.rules)
                } label: {
                    Label(
                        "Delete",
                        systemImage: "trash"
                    )
                }
                .accessibilityIdentifier(
                    "profile-rules.rule.\(index).delete"
                )
            }

            if index < draft.rules.count - 1 {
                Divider()
                    .padding(.leading, 62)
            }
        }
        .onAppear { draftRows.resync(count: draft.rules.count) }
        .onChange(of: draft.rules.count) { draftRows.resync(count: $0) }
    }

    private var priority: some View {
         
         
         
         
        HakoProductGroup(
            "PRIORITY",
            footer: priorityFootnote,
            palette: palette,
            touchSpacing: HakoTheme.Spacing.cardGap
        ) {
            HakoSettingsToggleRow(
                Text("Apply before profile rules"),
                isOn: $draft.prependRules
            )
             
             
             
            .padding(.horizontal, HakoTheme.Spacing.standard)
            .frame(
                minHeight: HakoPlatformLayout.pageUsesSystemSettingsIdiom
                    ? nil
                    : HakoTheme.Control
                        .fullWidthRowMinHeightOnItsOwnPlatform
            )
            .accessibilityIdentifier("profile-rules.prepend")
        }
    }

    private var priorityFootnote: HakoDisplayText {
        draft.prependRules
            ? "Personal rules are checked first for deliberate exceptions."
            : "Personal rules are checked after the rules supplied by this profile."
    }

    private var saveBehavior: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            statusMessage(
                "Saving rebuilds the current profile automatically. If VPN is off, it stays off until the next connection.",
                symbol: .checkmarkShieldFill,
                color: .green
            )
        }
    }

    private func personalRuleRow(
        _ rule: HakoPersonalRuleSnapshot,
        index: Int
    ) -> some View {
        let parsed = HakoStructuredRule.parse(rule.raw)
        let title = parsed.flatMap {
            HakoLogicExpressionCodec.summary(
                action: $0.action,
                content: $0.content
            )
        } ?? parsed.flatMap {
            $0.content.isEmpty ? $0.action.title : $0.content
        } ?? rule.raw
        let invalidTarget = parsed.map {
            policyOptionsForValidation?.flagsUnknownTarget(of: $0) ?? false
        } ?? false

        return HStack(
            alignment: .center,
            spacing: HakoTheme.Spacing.row
        ) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.tight
            ) {
                Text(hako: .copy(title))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(parsed?.action.rawValue ?? "RAW")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    ruleColor(
                                        parsed?.action.category
                                    )
                                )
                        )
                    Text(parsed?.target ?? "")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(
                            invalidTarget
                                ? AnyShapeStyle(Color.red)
                                : AnyShapeStyle(Color.secondary)
                        )
                        .lineLimit(1)
                    if let parsed {
                        Text(parsed.action.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let comment = rule.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier(
                            "profile-rules.rule.\(index).comment"
                        )
                }
                if invalidTarget {
                    Text("Target not in this profile")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier(
                            "profile-rules.rule.\(index).invalid-target"
                        )
                }
            }
            Spacer(minLength: 0)
            if !rule.isEnabled {
                Text("Off")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(palette.raisedFill)
                    )
                    .accessibilityIdentifier(
                        "profile-rules.rule.\(index).off"
                    )
            }
            if !HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                 
                 
                 
                icon(.chevronForward)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
         
         
         
         
         
         
        .padding(.horizontal, HakoTheme.Spacing.standard)
        .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.row
            )
        )
        .frame(
            minHeight: HakoPlatformLayout.pageUsesSystemSettingsIdiom
                ? nil
                : 60
        )
        .contentShape(Rectangle())
        .opacity(rule.isEnabled ? 1 : 0.5)
    }

    private func ruleColor(
        _ category: HakoStructuredRule.Category?
    ) -> Color {
        switch category {
        case .domain: .purple
        case .address: .orange
        case .connection: .blue
        case .resources: .teal
        case .logic: .green
        case .advanced, .none: .gray
        }
    }

    private func statusMessage(
        _ text: String,
        symbol: HakoSymbol,
        color: Color
    ) -> some View {
        HStack(
            alignment: .top,
            spacing: HakoTheme.Spacing.compact
        ) {
            icon(symbol)
                .foregroundStyle(color)
            Text(hako: .copy(text))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
         
         
         
         
         
         
        .padding(.horizontal, HakoTheme.Spacing.standard)
        .padding(.vertical, HakoTheme.Spacing.compact)
    }

    private func apply(
        _ updated: HakoPersonalRuleSnapshot,
        rowID: UUID?
    ) {
        if let rowID {
            draftRows.update(rowID, in: &draft.rules, to: updated)
        } else if !draft.rules.contains(where: {
            $0.raw == updated.raw
        }) {
            draftRows.append(updated, to: &draft.rules)
        }
    }

    private func toggleRule(at index: Int) {
        guard draft.rules.indices.contains(index) else { return }
        let current = draft.rules[index]
        draft.rules[index] = HakoPersonalRuleSnapshot(
            raw: current.raw,
            isEnabled: !current.isEnabled,
            comment: current.comment
        )
    }

    private func persist() {
        guard !isSaving else { return }
        isSaving = true
        error = ""
        Task {
            do {
                try await actions.perform(
                    .rules(.saveProfileRules(draft)),
                    allowedBy: snapshot
                )
                dismissPresentation()
            } catch {
                self.error =
                    "Rules could not be saved. The previous configuration is still available."
            }
            isSaving = false
        }
    }

     
     
     
     
     
    private func openRuleEditor(_ target: HakoRuleEditTarget) {
        pendingRule = target
        if loadedPolicyOptions != nil {
            pendingRule = nil
            editingRule = target
            return
        }
        guard let loadPolicyOptions else {
            loadedPolicyOptions = editor.policyOptions
            pendingRule = nil
            editingRule = target
            return
        }
        guard !isLoadingPolicyOptions else { return }
        isLoadingPolicyOptions = true
        Task { @MainActor in
            let options = await loadPolicyOptions()
            loadedPolicyOptions = options
            let requested = pendingRule
            pendingRule = nil
            isLoadingPolicyOptions = false
            editingRule = requested
        }
    }

     
     
     
    private var policyOptionsForValidation: HakoRulePolicyOptions? {
        if let loadedPolicyOptions {
            return loadedPolicyOptions
        }
        return loadPolicyOptions == nil ? editor.policyOptions : nil
    }

    private func dismissPresentation() {
        (productModalDismiss ?? { dismiss() })()
    }
}

private struct HakoRuleEditTarget: Identifiable {
    let id = UUID()
     
     
    let rowID: UUID?
    let rule: HakoPersonalRuleSnapshot
    let initialRoute: HakoRuleBuilderRoute?
}

private struct HakoProfileRuleOrderView<Icon: View>: View {
    @Binding var rules: [HakoPersonalRuleSnapshot]
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon

     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
     
     
     
     
    @State private var rows = HakoIdentifiedRows()

    var body: some View {
        HakoSingleColumnNavigationContainer {
            List {
                ForEach(rows.current(for: rules)) { row in
                    let index = row.index
                    let rule = rows.index(of: row.id).map { rules[$0] }
                        ?? HakoPersonalRuleSnapshot(raw: "")
                    HStack(spacing: HakoTheme.Spacing.row) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                HakoStructuredRule.parse(rule.raw)?
                                    .content
                                    .nonempty
                                    ?? rule.raw
                            )
                            .lineLimit(1)
                            Text(
                                HakoStructuredRule.parse(rule.raw)?
                                    .action.rawValue
                                    ?? "RAW"
                            )
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 8)
                        Button {
                            guard let now = rows.index(of: row.id),
                                  now > 0 else { return }
                            rows.swapAt(now, now - 1, in: &rules)
                        } label: {
                            icon(.arrowUp)
                        }
                        .buttonStyle(.borderless)
                        .frame(
                            width: HakoTheme.Control.minimumHitTarget,
                            height: HakoTheme.Control.minimumHitTarget
                        )
                        .contentShape(Rectangle())
                        .disabled(index == 0)
                        .accessibilityLabel("Move rule up")
                        .accessibilityIdentifier(
                            "profile-rules.order.\(index).move-up"
                        )
                        Button {
                            guard let now = rows.index(of: row.id),
                                  now + 1 < rules.count else {
                                return
                            }
                            rows.swapAt(now, now + 1, in: &rules)
                        } label: {
                            icon(.arrowDown)
                        }
                        .buttonStyle(.borderless)
                        .frame(
                            width: HakoTheme.Control.minimumHitTarget,
                            height: HakoTheme.Control.minimumHitTarget
                        )
                        .contentShape(Rectangle())
                        .disabled(index + 1 == rules.count)
                        .accessibilityLabel("Move rule down")
                        .accessibilityIdentifier(
                            "profile-rules.order.\(index).move-down"
                        )
                    }
                    .tag(index)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(
                        "profile-rules.order.\(index)"
                    )
                    .accessibilityLabel(
                        "\(HakoStructuredRule.parse(rule.raw)?.content.nonempty ?? rule.raw), \(HakoStructuredRule.parse(rule.raw)?.action.rawValue ?? "RAW")"
                    )
                }
                .onAppear { rows.resync(count: rules.count) }
                .onChange(of: rules.count) { rows.resync(count: $0) }
            }
            .hakoPageTitle("Rule Priority")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    HakoSheetCloseButton {
                        dismiss()
                    }
                }
            }
            .hakoProductModalRoot(title: "Rule Priority")
        }
        .hakoCapturesDismiss(dismiss)
    }
}

private extension String {
    var nonempty: String? {
        isEmpty ? nil : self
    }
}

 
 
 
public struct HakoRuleEditorView<Icon: View>: View {
    private let rule: HakoPersonalRuleSnapshot
    private let options: HakoRulePolicyOptions
    private let initialRoute: HakoRuleBuilderRoute?
    private let runtimeProfile: HakoAppleRuntimeProfile
    private let palette: HakoProductPalette
    private let loadGeoValues:
        HakoRuleGeoValueLoader
    private let icon: (HakoSymbol) -> Icon
    private let save: (HakoPersonalRuleSnapshot) -> Void

    public init(
        rule: HakoPersonalRuleSnapshot,
        options: HakoRulePolicyOptions = .empty,
        initialRoute: HakoRuleBuilderRoute? = nil,
        runtimeProfile: HakoAppleRuntimeProfile,
        palette: HakoProductPalette,
        loadGeoValues: @escaping
            HakoRuleGeoValueLoader,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        save: @escaping (HakoPersonalRuleSnapshot) -> Void
    ) {
        self.rule = rule
        self.options = options
        self.initialRoute = initialRoute
        self.runtimeProfile = runtimeProfile
        self.palette = palette
        self.loadGeoValues = loadGeoValues
        self.icon = icon
        self.save = save
    }

    public var body: some View {
        HakoRuleBuilderView(
            rule: rule,
            options: options,
            initialRoute: initialRoute,
            runtimeProfile: runtimeProfile,
            palette: palette,
            loadGeoValues: loadGeoValues,
            icon: icon,
            save: save
        )
    }
}

private struct HakoRuleBuilderView<Icon: View>: View {
    let options: HakoRulePolicyOptions
    let initialRoute: HakoRuleBuilderRoute?
    let runtimeProfile: HakoAppleRuntimeProfile
    let palette: HakoProductPalette
    let loadGeoValues:
        HakoRuleGeoValueLoader
    let icon: (HakoSymbol) -> Icon
    let save: (HakoPersonalRuleSnapshot) -> Void

    @Environment(\.hakoProductModalDismiss) private var modalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()

    @State private var action: HakoStructuredRule.Action
    @State private var content: String
    @State private var target: String
    @State private var noResolve: Bool
    @State private var src: Bool
    @State private var rawMode: Bool
    @State private var rawText: String
    @State private var enabled: Bool
    @State private var comment: String
    @State private var logicConditions: [HakoLogicCondition]?
    @State private var newCondition = HakoLogicCondition(
        action: .network,
        content: "tcp"
    )
    @State private var addingCondition = false
    @State private var error = ""
    @State private var lastAction: HakoStructuredRule.Action
    @State private var autoRoute: HakoRuleBuilderRoute?
    @FocusState private var contentFieldFocused: Bool
    @FocusState private var targetFieldFocused: Bool
    @FocusState private var rawFieldFocused: Bool

    init(
        rule: HakoPersonalRuleSnapshot,
        options: HakoRulePolicyOptions,
        initialRoute: HakoRuleBuilderRoute?,
        runtimeProfile: HakoAppleRuntimeProfile,
        palette: HakoProductPalette,
        loadGeoValues: @escaping
            HakoRuleGeoValueLoader,
        icon: @escaping (HakoSymbol) -> Icon,
        save: @escaping (HakoPersonalRuleSnapshot) -> Void
    ) {
        self.options = options
        self.initialRoute = initialRoute
        self.runtimeProfile = runtimeProfile
        self.palette = palette
        self.loadGeoValues = loadGeoValues
        self.icon = icon
        self.save = save
        _enabled = State(initialValue: rule.isEnabled)
        _comment = State(initialValue: rule.comment ?? "")
        let parsed = HakoStructuredRule.parse(rule.raw)
        let initialAction = parsed?.action ?? .domainSuffix
        _action = State(initialValue: initialAction)
        _content = State(initialValue: parsed?.content ?? "")
        _target = State(
            initialValue:
                parsed?.target
                ?? options.groups.first?.name
                ?? "DIRECT"
        )
        _noResolve = State(initialValue: parsed?.noResolve ?? false)
        _src = State(initialValue: parsed?.src ?? false)
        _rawMode = State(
            initialValue: !rule.raw.isEmpty && parsed == nil
        )
        _rawText = State(initialValue: rule.raw)
        _lastAction = State(initialValue: initialAction)
        if Self.isLogic(initialAction) {
            _logicConditions = State(
                initialValue:
                    (parsed?.content.isEmpty ?? true)
                    ? []
                    : HakoLogicExpressionCodec.parse(
                        action: initialAction,
                        content: parsed?.content ?? ""
                    )
            )
        } else {
            _logicConditions = State(initialValue: nil)
        }
    }

    var body: some View {
        HakoSingleColumnNavigationContainer {
            HakoModalEditorBody {
                builderSections
            }
            .onChange(of: action) { updated in
                content = updated == .network ? "tcp" : ""
                logicConditions = Self.isLogic(updated) ? [] : nil
                if (updated == .subRule)
                    != (lastAction == .subRule)
                {
                    target = ""
                }
                noResolve = false
                src = false
                lastAction = updated
            }
            .background(autoRouteLinks.opacity(0))
            .onAppear {
                autoRoute = initialRoute
            }
            .hakoPageTitle("Rule")
            .hakoRegistersDeparture(
            isDirty: !openedWith.isEmpty && currentFingerprint != openedWith,
            save: { completion in
                submit()
                completion(true)
            },
            discard: {}
        )
        .onAppear { if openedWith.isEmpty { openedWith = currentFingerprint } }
        .hakoProductModalRoot(title: "Rule")
             
             
             
             
             
             
             
            .hakoModalEditorToolbar(
                confirmTitle: "Done",
                confirmationIdentifier: "profile-rule.save",
                confirmationDisabled: !saysSomething,
                onCancel: { dismiss() },
                onConfirm: { submit() }
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if HakoPlatformLayout.modalEditorUsesGroupedForm
                    && insideProductModal
                {
                    HakoModalActionBar(
                        primaryTitle: "Done",
                        primaryDisabled: !saysSomething,
                         
                         
                         
                        primaryHint: saysSomething
                            ? nil
                            : (rawMode
                                ? "Write the rule line to add it."
                                : "Enter what this rule matches."),
                        onPrimary: { submit() }
                    )
                }
            }
        }
        .hakoCapturesDismiss(dismiss)
    }

    @ViewBuilder
    private var builderSections: some View {
        if rawMode {
            rawSections
        } else {
            structuredSections
        }
        if !error.isEmpty {
            Section {
                Text(error)
                    .foregroundStyle(.red)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
            }
        }
    }

    @ViewBuilder
    private var rawSections: some View {
        Section {
            HakoSettingsToggleRow(
                Text("Enabled"),
                isOn: $enabled
            )
            .accessibilityIdentifier("profile-rule.enabled")
        }
        Section {
            rawRuleField
        } header: {
            Text("Raw rule")
        } footer: {
            Text(
                "This rule is not available in the structured editor. Imported source rules are never rewritten."
            )
        }
        commentSection
    }

    @ViewBuilder
    private var structuredSections: some View {
        Section {
            HakoSettingsToggleRow(
                Text("Enabled"),
                isOn: $enabled
            )
            .accessibilityIdentifier("profile-rule.enabled")
            HakoRoutedViewLink {
                HakoRuleTypeSelectionView(
                    selection: $action,
                    runtimeProfile: runtimeProfile,
                    icon: icon
                        )
                        .hakoPushedDetailPage()
                        .modifier(HakoSetterRoutedBack())
            } label: {
                HStack {
                    Text("Type")
                    Spacer()
                    Text(action.rawValue)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("profile-rule.action")
        } header: {
            Text("Rule")
        } footer: {
            Text(hako: .copy(action.summary))
        }

        if action.needsContent {
            Section {
                valueEditor
                if let note = action.iOSInertNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                if HakoPlatformLayout.modalEditorUsesGroupedForm {
                    Text(HakoCopy.key(action.contentLabel))
                } else {
                    Text("Value")
                }
            } footer: {
                if Self.isLogic(action),
                    logicConditions != nil
                {
                    Text(hako: .copy(logicFooter))
                } else if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
                          !action.contentPlaceholder.isEmpty {
                     
                     
                     
                     
                     
                     
                     
                     
                    Text(verbatim: action.contentPlaceholder)
                        .font(.caption.monospaced())
                }
            }
        }

        Section("Target") {
            if action == .subRule {
                if HakoPlatformLayout.modalEditorUsesGroupedForm {
                    HStack {
                         
                         
                         
                        HakoValueField(
                            hint: "sub-rule name",
                            label: action.targetLabel,
                            bordered: HakoPlatformLayout
                                .pageUsesSystemSettingsIdiom,
                            text: $target
                        )
                        .font(.body.monospaced())
                        .focused($targetFieldFocused)
                        .accessibilityIdentifier(
                            "profile-rule.target"
                        )
                    }
                    .frame(maxWidth: .infinity, minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        targetFieldFocused = true
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(
                        "profile-rule.target.row"
                    )
                } else {
                    VStack(
                        alignment: .leading,
                        spacing: HakoTheme.Spacing.tight
                    ) {
                        Text(action.targetLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(
                            "",
                            text: $target,
                            prompt: Text("sub-rule name")
                        )
                            .font(.body.monospaced())
                            .accessibilityIdentifier(
                                "profile-rule.target"
                            )
                    }
                }
            } else {
                HakoRoutedViewLink {
                    HakoRulePolicyPickerView(
                        options: options,
                        current: target,
                        icon: icon
                    ) {
                        target = $0
                    }
                    .hakoPushedDetailPage()
                } label: {
                    enumValueRow("Target", value: target)
                }
                .accessibilityIdentifier(
                    "profile-rule.target.picker"
                )
            }
        }

        if action.supportsNoResolve || action.supportsSrc {
            Section("Params") {
                if action.supportsNoResolve {
                    HakoSettingsToggleRow(
                        Text("Skip DNS resolution"),
                        isOn: $noResolve
                    )
                    .accessibilityIdentifier(
                        "profile-rule.no-resolve"
                    )
                }
                if action.supportsSrc {
                    HakoSettingsToggleRow(
                        Text("Match source instead"),
                        isOn: $src
                    )
                    .accessibilityIdentifier("profile-rule.src")
                }
            }
        }

        if action.hasLimitedIOSMeaning {
            Section {
                Text(
                    "This condition only matches metadata created inside Clash's single TUN inbound. It does not identify another app or process."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }

        commentSection
    }

    private var commentSection: some View {
        Section {
            if HakoPlatformLayout.modalEditorUsesGroupedForm {
                HakoFieldRow(
                    "Comment",
                    hint: "Optional note, stored only on this device",
                    text: $comment
                )
                .accessibilityIdentifier("profile-rule.comment")
            } else {
                TextField(
                    "",
                    text: $comment,
                    prompt: Text(
                        "Optional note, stored only on this device"
                    )
                )
                .accessibilityIdentifier("profile-rule.comment")
            }
        } header: {
            if !HakoPlatformLayout.modalEditorUsesGroupedForm {
                Text("Comment")
            }
        } footer: {
            Text(
                "Never written into the generated configuration."
            )
        }
    }

    @ViewBuilder
    private var valueEditor: some View {
        if Self.isLogic(action) {
            logicValueContent
        } else if action == .network {
            HakoRuleNetworkMenuRow(
                selection: $content,
                identifier: "profile-rule.content"
            )
        } else if action == .geoip || action == .srcGeoIP {
            HakoRoutedViewLink {
                HakoRuleGeoValuePickerView(
                    resource: .geoIP,
                    localizeRegions: true,
                    title: "Country / Region",
                    current: content,
                    loadValues: loadGeoValues,
                    icon: icon
                ) {
                    content = $0.uppercased()
                }
                .hakoPushedDetailPage()
            } label: {
                enumValueRow(
                    "Country / Region",
                    value: content.uppercased(),
                    detail: regionDetail
                )
            }
            .accessibilityIdentifier(
                "profile-rule.content.picker"
            )
        } else if action == .geosite {
            HakoRoutedViewLink {
                HakoRuleGeoValuePickerView(
                    resource: .geoSite,
                    localizeRegions: false,
                    title: "GeoSite category",
                    current: content,
                    loadValues: loadGeoValues,
                    icon: icon
                ) {
                    content = $0
                }
                .hakoPushedDetailPage()
            } label: {
                enumValueRow("Category", value: content)
            }
            .accessibilityIdentifier(
                "profile-rule.content.picker"
            )
        } else if action == .ruleSet,
            !options.ruleSets.isEmpty
        {
            HakoRoutedViewLink {
                HakoRuleSetPickerView(
                    sets: options.ruleSets,
                    current: content,
                    icon: icon
                ) {
                    content = $0
                }
                .hakoPushedDetailPage()
            } label: {
                enumValueRow("Rule Set", value: content)
            }
            .accessibilityIdentifier(
                "profile-rule.content.picker"
            )
        } else {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.tight
            ) {
                if !HakoPlatformLayout.modalEditorUsesGroupedForm {
                     
                     
                    Text(action.contentLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                structuredContentField
            }
        }
    }

    private var structuredContentField: some View {
        HStack {
             
             
             
             
             
             
             
             
             
             
             
            HakoValueField(
                hint: action.contentPlaceholder,
                label: action.contentLabel,
                bordered: HakoPlatformLayout.pageUsesSystemSettingsIdiom,
                text: $content
            )
            .font(.body.monospaced())
            .focused($contentFieldFocused)
            .accessibilityIdentifier("profile-rule.content")
        }
        .frame(maxWidth: .infinity, minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
        .contentShape(Rectangle())
        .onTapGesture {
            contentFieldFocused = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-rule.content.row")
    }

    private var rawRuleField: some View {
        HStack {
             
             
            HakoValueField(
                hint: "DOMAIN-SUFFIX,example.com,PROXY",
                label: "Rule",
                bordered: HakoPlatformLayout.pageUsesSystemSettingsIdiom,
                text: $rawText
            )
            .font(.body.monospaced())
            .focused($rawFieldFocused)
            .accessibilityIdentifier("profile-rule.raw")
        }
        .frame(maxWidth: .infinity, minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
        .contentShape(Rectangle())
        .onTapGesture {
            rawFieldFocused = true
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-rule.raw.row")
    }

     
     
     
    @State private var conditionRows = HakoIdentifiedRows()

    private func condition(_ id: UUID) -> HakoLogicCondition? {
        guard let conditions = logicConditions,
              let index = conditionRows.index(of: id),
              conditions.indices.contains(index) else { return nil }
        return conditions[index]
    }

    private func conditionBinding(
        _ id: UUID, fallback: HakoLogicCondition
    ) -> Binding<HakoLogicCondition> {
        Binding(
            get: { condition(id) ?? fallback },
            set: { updated in
                guard var conditions = logicConditions else { return }
                conditionRows.update(id, in: &conditions, to: updated)
                logicConditions = conditions
            }
        )
    }

    @ViewBuilder
    private var logicValueContent: some View {
        if let conditions = logicConditions {
            ForEach(conditionRows.current(for: conditions)) { row in
                let index = row.index
                let condition = self.condition(row.id)
                    ?? HakoLogicCondition(action: .network, content: "tcp")
                HakoRoutedViewLink {
                    HakoLazyView {
                        HakoRuleConditionEditorView(
                            condition: conditionBinding(
                                row.id, fallback: condition
                            ),
                            options: options,
                            runtimeProfile: runtimeProfile,
                            loadGeoValues: loadGeoValues,
                            icon: icon
                        )
                    }
                    .hakoPushedDetailPage()
                } label: {
                    HStack(spacing: 8) {
                        Text(condition.action.rawValue)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(
                                    cornerRadius: 5
                                )
                                .fill(Color.indigo)
                            )
                        Text(condition.content)
                            .font(.body.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }
                }
                .accessibilityIdentifier(
                    "profile-rule.condition.\(index)"
                )
                .contextMenu {
                    Button(role: .destructive) {
                        guard var conditions = logicConditions else { return }
                        conditionRows.remove(row.id, from: &conditions)
                        logicConditions = conditions
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            let conditionCount = logicConditions?.count ?? 0
            Color.clear.frame(width: 0, height: 0)
                .onAppear { conditionRows.resync(count: conditionCount) }
                .onChange(of: conditionCount) {
                    conditionRows.resync(count: $0)
                }
            if canAddCondition {
                HakoAddRow(Text("Add Condition")) {
                    newCondition = HakoLogicCondition(
                        action: .network,
                        content: "tcp"
                    )
                    addingCondition = true
                } touchLabel: {
                    Label {
                        Text("Add Condition")
                    } icon: {
                        icon(.plus)
                    }
                }
                .accessibilityIdentifier(
                    "profile-rule.condition.add"
                )
                .background(
                    HakoRoutedViewDestination(
                        isPresented: $addingCondition
                    ) {
                        HakoRuleConditionEditorView(
                            condition: $newCondition,
                            options: options,
                            runtimeProfile: runtimeProfile,
                            commitLabel: "Add",
                            loadGeoValues: loadGeoValues,
                            icon: icon
                        ) {
                            logicConditions?.append($0)
                        }
                        .hakoPushedDetailPage()
                    }
                    .opacity(0)
                )
            }
        } else {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.tight
            ) {
                if !HakoPlatformLayout.modalEditorUsesGroupedForm {
                     
                     
                    Text(action.contentLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                structuredContentField
                Text(
                    "This expression uses nesting the condition builder does not cover; edit it verbatim."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var autoRouteLinks: some View {
        Group {
            HakoRoutedViewDestination(
                isPresented: Binding(
                    get: { autoRoute == .country },
                    set: {
                        if !$0 {
                            autoRoute = nil
                        }
                    }
                )
            ) {
                HakoRuleGeoValuePickerView(
                    resource: .geoIP,
                    localizeRegions: true,
                    title: "Country / Region",
                    current: content,
                    loadValues: loadGeoValues,
                    icon: icon
                ) {
                    content = $0.uppercased()
                }
                .hakoPushedDetailPage()
            }
            HakoRoutedViewDestination(
                isPresented: Binding(
                    get: { autoRoute == .policy },
                    set: {
                        if !$0 {
                            autoRoute = nil
                        }
                    }
                )
            ) {
                HakoRulePolicyPickerView(
                    options: options,
                    current: target,
                    icon: icon
                ) {
                    target = $0
                }
                .hakoPushedDetailPage()
            }
            HakoRoutedViewDestination(
                isPresented: Binding(
                    get: { autoRoute == .category },
                    set: {
                        if !$0 {
                            autoRoute = nil
                        }
                    }
                )
            ) {
                HakoRuleGeoValuePickerView(
                    resource: .geoSite,
                    localizeRegions: false,
                    title: "GeoSite category",
                    current: content,
                    loadValues: loadGeoValues,
                    icon: icon
                ) {
                    content = $0
                }
                .hakoPushedDetailPage()
            }
        }
    }

    private func enumValueRow(
        _ label: String,
        value: String,
        detail: String? = nil
    ) -> some View {
        HStack {
            Text(hako: .copy(label))
            Spacer(minLength: HakoTheme.Spacing.compact)
            if value.isEmpty {
                Text("Required")
                    .foregroundStyle(.secondary)
            } else {
                Text(detail.map { "\(value) · \($0)" } ?? value)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform, alignment: .leading)
    }

    private var regionDetail: String? {
        guard content.count == 2 else { return nil }
        return Locale.current.localizedString(
            forRegionCode: content.uppercased()
        )
    }

    private static func isLogic(
        _ action: HakoStructuredRule.Action
    ) -> Bool {
        [.and, .or, .not, .subRule].contains(action)
    }

    private var canAddCondition: Bool {
        guard let conditions = logicConditions else {
            return false
        }
        if action == .not || action == .subRule {
            return conditions.isEmpty
        }
        return true
    }

    private var logicFooter: String {
        switch action {
        case .not:
            "NOT matches when its single condition does not match."
        case .subRule:
            "SUB-RULE branches when its single condition matches."
        case .and:
            "All conditions must match. Long-press a condition to remove it."
        default:
            "Any one condition may match. Long-press a condition to remove it."
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
    private var saysSomething: Bool {
        if rawMode {
            return !rawText.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

     
     
     
     
     
     
     
     
    @State private var openedWith = ""

    private var currentFingerprint: String {
        [
            String(describing: action), content, target,
            String(src), String(rawMode), rawText,
            String(noResolve), comment,
            String(describing: logicConditions), String(enabled),
        ].joined(separator: "\u{1F}")
    }

    private func submit() {
        let candidate: String
        if rawMode {
            candidate = rawText.trimmingCharacters(
                in: .whitespaces
            )
        } else {
            var effectiveContent = content.trimmingCharacters(
                in: .whitespaces
            )
            if Self.isLogic(action),
                let conditions = logicConditions
            {
                let minimum =
                    action == .not || action == .subRule ? 1 : 2
                guard conditions.count >= minimum else {
                    error =
                        minimum == 1
                        ? "Add the condition first."
                        : "Add at least two conditions."
                    return
                }
                guard conditions.allSatisfy({
                    !$0.content.isEmpty
                }) else {
                    error = "Every condition needs a value."
                    return
                }
                effectiveContent =
                    HakoLogicExpressionCodec.serialize(
                        action: action,
                        conditions: conditions
                    )
            }
            let rule = HakoStructuredRule(
                action: action,
                content: effectiveContent,
                target: target.trimmingCharacters(
                    in: .whitespaces
                ),
                noResolve: noResolve,
                src: src
            )
            guard !action.needsContent || !rule.content.isEmpty
            else {
                error = "\(action.contentLabel) is required."
                return
            }
            guard !rule.target.isEmpty else {
                error = "\(action.targetLabel) is required."
                return
            }
            candidate = rule.rawValue
        }
        let disallowReason =
            rawMode
            ? HakoStructuredRule.rawDisallowReason(
                candidate,
                runtimeProfile: runtimeProfile
            )
            : HakoStructuredRule.disallowReason(
                candidate,
                runtimeProfile: runtimeProfile
            )
        if let reason = disallowReason
        {
            error =
                "\(reason) The previous rule is unchanged."
            return
        }
        save(
            HakoPersonalRuleSnapshot(
                raw: candidate,
                isEnabled: enabled,
                comment: comment.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).nonempty
            )
        )
         
        (modalDismiss ?? { dismiss() })()
    }
}

 
 
 
 
 
private struct HakoRuleNetworkMenuRow: View {
    @Binding var selection: String
    let identifier: String

    var body: some View {
        Menu {
            ForEach(["tcp", "udp"], id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    if selection == value {
                        Label(value, systemImage: "checkmark")
                    } else {
                        Text(value)
                    }
                }
                .accessibilityIdentifier(
                    "\(identifier).choice.\(value)"
                )
            }
        } label: {
             
             
             
             
             
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(selection)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                Image(
                    systemName:
                        HakoSymbol.chevronUpChevronDown.rawValue
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Value")
            .accessibilityValue(selection)
            .accessibilityIdentifier(identifier)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .hakoSettingsMenuRow("Value")
        .id("\(identifier)-\(selection)")
        .transaction { $0.animation = nil }
    }
}

private struct HakoRuleTypeSelectionView<Icon: View>: View {
    @Binding var selection: HakoStructuredRule.Action
    let runtimeProfile: HakoAppleRuntimeProfile
    var excludesLogic = false
    var title = "Rule Type"
    let icon: (HakoSymbol) -> Icon

     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPopRoute) private var popRoute
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            Form {
                ForEach(visibleCategories) { category in
                    Section {
                        ForEach(
                            HakoStructuredRule.availableActions(
                                for: runtimeProfile
                            )
                                .filter {
                                    $0.category == category
                                        && (!excludesLogic
                                            || (
                                                $0.category != .logic
                                                    && $0 != .match
                                            ))
                                }
                        ) { value in
                            Button {
                                selection = value
                                dismissRoute()
                            } label: {
                                HStack {
                                    VStack(
                                        alignment: .leading,
                                        spacing: 3
                                    ) {
                                        Text(value.rawValue)
                                            .font(.body.monospaced())
                                            .foregroundStyle(.primary)
                                        Text(hako: .copy(value.summary))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(
                                                horizontal: false,
                                                vertical: true
                                            )
                                         
                                         
                                         
                                         
                                        if let note = HakoStructuredRule.platformNote(
                                            for: value.rawValue,
                                            runtimeProfile: runtimeProfile
                                        ) {
                                            Text(hako: note)
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                    Spacer(
                                        minLength:
                                            HakoTheme.Spacing.compact
                                    )
                                    HakoSelectionMark(
                                        isSelected:
                                            selection == value
                                    )
                                }
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform,
                                    alignment: .leading
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(
                                "rule-type.\(value.rawValue)"
                            )
                        }
                    } header: {
                        Text(hako: .copy(category.title))
                    } footer: {
                        if let note = categoryNote(category) {
                            Text(note)
                        }
                    }
                }
            }
        }
        .hakoPageTitle(.copy(title))
        .accessibilityIdentifier("profile-rule.type.screen")
        .hakoProductModalChild(title: title)
        .hakoCapturesDismiss(dismiss)
    }

    private var visibleCategories: [HakoStructuredRule.Category] {
        HakoStructuredRule.Category.allCases.filter {
            !(excludesLogic && $0 == .logic)
        }
    }

    private func categoryNote(
        _ category: HakoStructuredRule.Category
    ) -> String? {
        switch category {
        case .domain:
            "GEOSITE reads the built-in GeoSite database."
        case .address:
            "GEOIP and ASN heads read the built-in GeoIP, country and ASN databases."
        case .resources:
            "RULE-SET reads this profile's rule providers."
        default:
            nil
        }
    }

    private func dismissRoute() {
#if os(macOS)
        if let popRoute {
            popRoute(HakoPopToken())
        } else {
            dismiss()
        }
#else
         
         
         
        dismiss()
#endif
    }
}


private struct HakoRuleConditionEditorView<Icon: View>: View {
    @Binding var condition: HakoLogicCondition
    let options: HakoRulePolicyOptions
    let runtimeProfile: HakoAppleRuntimeProfile
    var commitLabel: String?
    let loadGeoValues:
        HakoRuleGeoValueLoader
    let icon: (HakoSymbol) -> Icon
    var onCommit: ((HakoLogicCondition) -> Void)?

     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPopRoute) private var popRoute
     
     
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal

    var body: some View {
        Form {
            Section {
                HakoRoutedViewLink {
                    HakoRuleTypeSelectionView(
                        selection: Binding(
                            get: { condition.action },
                            set: {
                                condition.action = $0
                                condition.content =
                                    $0 == .network ? "tcp" : ""
                                condition.noResolve = false
                                condition.src = false
                            }
                        ),
                        runtimeProfile: runtimeProfile,
                        excludesLogic: true,
                        title: "Condition Type",
                        icon: icon
                    )
                    .hakoPushedDetailPage()
                } label: {
                    HStack {
                        Text("Type")
                        Spacer()
                        Text(condition.action.rawValue)
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("condition.type")
            } footer: {
                Text(condition.action.summary)
            }

            Section("Value") {
                conditionValueEditor
            }

            if condition.action.supportsNoResolve
                || condition.action.supportsSrc
            {
                Section("Params") {
                    if condition.action.supportsNoResolve {
                        HakoSettingsToggleRow(
                            Text("Skip DNS resolution"),
                            isOn: $condition.noResolve
                        )
                        .accessibilityIdentifier(
                            "condition.no-resolve"
                        )
                    }
                    if condition.action.supportsSrc {
                        HakoSettingsToggleRow(
                            Text("Match source instead"),
                            isOn: $condition.src
                        )
                        .accessibilityIdentifier("condition.src")
                    }
                }
            }
        }
        .hakoPageTitle("Condition")
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .confirmationAction) {
                if let commitLabel {
                     
                     
                     
                    Button {
                        onCommit?(condition)
                        dismissRoute()
                    } label: {
                        Text(hako: .copy(commitLabel))
                    }
                    .disabled(condition.content.isEmpty)
                    .accessibilityIdentifier("condition.commit")
                }
            }
        }
        .accessibilityIdentifier("condition.screen")
         
         
         
         
         
         
        .hakoProductModalChild(title: "Condition")
         
         
         
         
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal, let commitLabel {
                HakoModalActionBar(
                    primaryTitle: commitLabel,
                    primaryDisabled: condition.content.isEmpty
                ) {
                    onCommit?(condition)
                    dismissRoute()
                }
            }
        }
        .hakoCapturesDismiss(dismiss)
    }

    private var modalCommitAction: (() -> Void)? {
        guard commitLabel != nil else { return nil }
        return {
            guard !condition.content.isEmpty else { return }
            onCommit?(condition)
            dismissRoute()
        }
    }

    private func dismissRoute() {
#if os(macOS)
        if let popRoute {
            popRoute(HakoPopToken())
        } else {
            dismiss()
        }
#else
         
         
         
        dismiss()
#endif
    }

    @ViewBuilder
    private var conditionValueEditor: some View {
        if condition.action == .network {
            HakoRuleNetworkMenuRow(
                selection: $condition.content,
                identifier: "condition.content"
            )
        } else if condition.action == .geoip
            || condition.action == .srcGeoIP
        {
            HakoRoutedViewLink {
                HakoRuleGeoValuePickerView(
                    resource: .geoIP,
                    localizeRegions: true,
                    title: "Country / Region",
                    current: condition.content,
                    loadValues: loadGeoValues,
                    icon: icon
                ) {
                    condition.content = $0.uppercased()
                }
                .hakoPushedDetailPage()
            } label: {
                conditionValueRow("Country / Region")
            }
            .accessibilityIdentifier(
                "condition.content.picker"
            )
        } else if condition.action == .geosite {
            HakoRoutedViewLink {
                HakoRuleGeoValuePickerView(
                    resource: .geoSite,
                    localizeRegions: false,
                    title: "GeoSite category",
                    current: condition.content,
                    loadValues: loadGeoValues,
                    icon: icon
                ) {
                    condition.content = $0
                }
                .hakoPushedDetailPage()
            } label: {
                conditionValueRow("Category")
            }
            .accessibilityIdentifier(
                "condition.content.picker"
            )
        } else if condition.action == .ruleSet,
            !options.ruleSets.isEmpty
        {
            HakoRoutedViewLink {
                HakoRuleSetPickerView(
                    sets: options.ruleSets,
                    current: condition.content,
                    icon: icon
                ) {
                    condition.content = $0
                }
                .hakoPushedDetailPage()
            } label: {
                conditionValueRow("Rule Set")
            }
            .accessibilityIdentifier(
                "condition.content.picker"
            )
        } else {
            HakoFieldRow(
                condition.action.contentLabel,
                hint: condition.action.contentPlaceholder,
                text: $condition.content,
                monospaced: true,
                identifier: "condition.content"
            )
        }
    }

    private func conditionValueRow(
        _ label: String
    ) -> some View {
        HStack {
            Text(hako: .copy(label))
            Spacer(minLength: HakoTheme.Spacing.compact)
            Text(
                condition.content.isEmpty
                    ? "Required"
                    : condition.content
            )
            .font(.body.monospaced())
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
        .contentShape(Rectangle())
    }
}

 
 
 
 
 
public struct HakoRulePolicyPickerView<Icon: View>: View {
    let title: String
    let builtIns: [(name: String, caption: String)]
    let builtInsTitle: String?
    let axPrefix: String
    let offersGlobal: Bool
    let options: HakoRulePolicyOptions
    let current: String
    let icon: (HakoSymbol) -> Icon
    let pick: (String) -> Void

    private static var ruleBuiltIns: [(name: String, caption: String)] {
        [
            ("DIRECT", "Do not proxy; connect directly."),
            ("REJECT", "Abort the request."),
            ("REJECT-DROP", "Drop silently, without answering."),
            ("PASS", "Skip this rule; keep matching the ones below."),
            ("PASS-RULE", "Skip this rule but stay inside the sub-rule list."),
            ("MATCH", "Follow this profile's final MATCH policy."),
        ]
    }

    public init(
        title: String = "Target",
        builtIns: [(name: String, caption: String)]? = nil,
        builtInsTitle: String? = "Built-in",
        axPrefix: String = "rule-policy",
        offersGlobal: Bool = true,
        options: HakoRulePolicyOptions,
        current: String,
        icon: @escaping (HakoSymbol) -> Icon,
        pick: @escaping (String) -> Void
    ) {
        self.title = title
        self.builtIns = builtIns ?? Self.ruleBuiltIns
        self.builtInsTitle = builtInsTitle
        self.axPrefix = axPrefix
        self.offersGlobal = offersGlobal
        self.options = options
        self.current = current
        self.icon = icon
        self.pick = pick
    }

     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPopRoute) private var popRoute
    @State private var query = ""

    public var body: some View {
        Form {
            if !builtIns.isEmpty {
                Section {
                    ForEach(builtIns, id: \.name) { entry in
                        policyRow(entry.name, caption: entry.caption)
                    }
                } header: {
                    if let builtInsTitle {
                        Text(hako: .copy(builtInsTitle))
                    }
                }
            }
            if !filteredGroups.isEmpty || query.isEmpty {
                Section("Groups") {
                    ForEach(filteredGroups) {
                        policyRow($0.name, caption: $0.type)
                    }
                    if offersGlobal,
                        !options.groups.contains(where: {
                        $0.name == "GLOBAL"
                    }),
                        query.isEmpty
                            || "GLOBAL"
                            .localizedCaseInsensitiveContains(query)
                    {
                        policyRow(
                            "GLOBAL",
                            caption: "Kernel built-in group"
                        )
                    }
                }
            }
            if !filteredProxies.isEmpty {
                Section("Proxies") {
                    ForEach(filteredProxies) {
                        policyRow($0.name, caption: $0.type)
                    }
                }
            }
        }
        .hakoProductModalSearchable(
            text: $query,
            prompt: Text("Search proxies")
        )
        .hakoPageTitle(.copy(title))
        .hakoProductModalChild(
            title: title,
            searchText: $query
        )
        .hakoCapturesDismiss(dismiss)
    }

    private var filteredGroups: [HakoRulePolicySnapshot] {
        query.isEmpty
            ? options.groups
            : options.groups.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
    }

    private var filteredProxies: [HakoRulePolicySnapshot] {
        query.isEmpty
            ? options.proxies
            : options.proxies.filter {
                $0.name.localizedCaseInsensitiveContains(query)
            }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private func policyRow(
        _ name: String,
        caption: String
    ) -> some View {
#if os(macOS)
        policyRowLabel(name, caption: caption)
            .contentShape(Rectangle())
            .onTapGesture {
                pick(name)
                dismissRoute()
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                pick(name)
                dismissRoute()
            }
            .accessibilityIdentifier("\(axPrefix).\(name)")
#else
        Button {
            pick(name)
            dismissRoute()
        } label: {
            policyRowLabel(name, caption: caption)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(axPrefix).\(name)")
#endif
    }

    private func policyRowLabel(
        _ name: String,
        caption: String
    ) -> some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .foregroundStyle(.primary)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if name == current {
                icon(.checkmark)
                    .foregroundStyle(.tint)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform,
            alignment: .leading
        )
    }

    private func dismissRoute() {
#if os(macOS)
        if let popRoute {
            popRoute(HakoPopToken())
        } else {
            dismiss()
        }
#else
         
         
         
        dismiss()
#endif
    }
}

 
 
 
 
 
enum HakoGeoValueSearch {
    static func matches(
        values: [String],
        folded: [String],
        needle: String,
        cap: Int,
        localizeRegions: Bool
    ) -> [String] {
        let lowered = needle.lowercased()
        var hits: [String] = []
        hits.reserveCapacity(cap)
        for (index, entry) in folded.enumerated() where index < values.count {
            let value = values[index]
            var matched = entry.contains(lowered)
            if !matched, localizeRegions, value.count == 2 {
                matched = Locale.current
                    .localizedString(forRegionCode: value.uppercased())?
                    .lowercased()
                    .contains(lowered) ?? false
            }
            if matched {
                hits.append(value)
                if hits.count == cap { break }
            }
        }
        return hits
    }
}

private struct HakoRuleGeoValuePickerView<Icon: View>: View {
    let resource: HakoRuleGeoResource
    let localizeRegions: Bool
    let title: String
    let current: String
    let loadValues:
        HakoRuleGeoValueLoader
    let icon: (HakoSymbol) -> Icon
    let pick: (String) -> Void

     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPopRoute) private var popRoute
    @State private var query = ""
    @State private var values: [String] = []
     
     
     
    @State private var foldedValues: [String] = []
     
     
     
     
     
     
     
    @State private var matches: [String] = []
    @State private var loaded = false

    var body: some View {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        List {
            if !loaded {
                Section {
                    ProgressView()
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 96
                        )
                        .accessibilityIdentifier("rule-geo.loading")
                }
            } else if values.isEmpty {
                Section {
                    HakoRuleCatalogUnavailableView(
                        title: "No categories available",
                        detail:
                            "The active Geo database does not publish any \(resourceTitle) categories.",
                        systemImage: "tray"
                    )
                    .accessibilityIdentifier("rule-geo.empty")
                }
            } else if filtered.isEmpty {
                Section {
                    HakoRuleCatalogUnavailableView(
                        title: "No results",
                        detail: "No category matches “\(query)”.",
                        systemImage: "magnifyingglass"
                    )
                    .accessibilityIdentifier(
                        "rule-geo.no-results"
                    )
                }
            } else {
                Section {
                    ForEach(filtered, id: \.self) { value in
                        Button {
                            pick(value)
                            dismissRoute()
                        } label: {
                            HStack(spacing: HakoTheme.Spacing.row) {
                                Text(displayValue(value))
                                    .foregroundStyle(.primary)
                                if let name = regionName(value) {
                                    Text(name)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                if value == current {
                                    icon(.checkmark)
                                        .foregroundStyle(.tint)
                                }
                            }
                            .frame(
                                maxWidth: .infinity,
                                minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform,
                                alignment: .leading
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "rule-geo.\(value)"
                        )
                    }
                }
            }
        }
         
         
        .hakoMacSettingsList(
            minRowHeight: HakoMacSettingsMetrics.listRowMinHeight
        )
        .hakoProductModalSearchable(
            text: $query,
            prompt: Text("Search code or name")
        )
        .hakoPageTitle(.copy(title))
        .task(id: query) { await prepareMatches() }
        .task {
            guard !loaded else { return }
            let loadedValues = await loadValues(resource)
            let folded = await Task.detached(priority: .userInitiated) {
                loadedValues.map { $0.lowercased() }
            }.value
            values = loadedValues
            foldedValues = folded
            loaded = true
            await prepareMatches()
        }
        .hakoProductModalChild(
            title: title,
            searchText: $query
        )
        .hakoCapturesDismiss(dismiss)
    }

    private func dismissRoute() {
#if os(macOS)
        if let popRoute {
            popRoute(HakoPopToken())
        } else {
            dismiss()
        }
#else
         
         
         
        dismiss()
#endif
    }

     
     
     
     
     
     
     
     
    private static var geoMatchCap: Int { 300 }

    private var filtered: [String] { matches }

    @MainActor
    private func prepareMatches() async {
        guard !query.isEmpty else {
             
             
             
             
             
            matches = values
            return
        }
        let needle = query
        let values = values
        let folded = foldedValues
        let cap = Self.geoMatchCap
        let localize = localizeRegions
        let hits = await Task.detached(priority: .userInitiated) {
            HakoGeoValueSearch.matches(
                values: values,
                folded: folded,
                needle: needle,
                cap: cap,
                localizeRegions: localize
            )
        }.value
         
         
        if Task.isCancelled { return }
        matches = hits
    }

    private var resourceTitle: String {
        resource == .geoIP ? "GeoIP" : "GeoSite"
    }

    private func regionName(_ code: String) -> String? {
        guard localizeRegions, code.count == 2 else {
            return nil
        }
        return Locale.current.localizedString(
            forRegionCode: code.uppercased()
        )
    }

    private func displayValue(_ value: String) -> String {
        localizeRegions && value.count == 2
            ? value.uppercased()
            : value
    }
}

private struct HakoRuleSetPickerView<Icon: View>: View {
    let sets: [String]
    let current: String
    let icon: (HakoSymbol) -> Icon
    let pick: (String) -> Void

     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPopRoute) private var popRoute
    @State private var query = ""
     
     
     
     
    @State private var folded: [String] = []
    @State private var matches: [String] = []

    var body: some View {
        Form {
            if filtered.isEmpty {
                Section {
                    HakoRuleCatalogUnavailableView(
                        title: "No results",
                        detail: "No rule set matches “\(query)”.",
                        systemImage: "magnifyingglass"
                    )
                    .accessibilityIdentifier(
                        "rule-set.no-results"
                    )
                }
            } else {
                Section {
                    ForEach(filtered, id: \.self) { name in
                        Button {
                            pick(name)
                            dismissRoute()
                        } label: {
                            HStack {
                                Text(name)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                if name == current {
                                    icon(.checkmark)
                                        .foregroundStyle(.tint)
                                }
                            }
                            .frame(
                                maxWidth: .infinity,
                                minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform,
                                alignment: .leading
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "rule-set.\(name)"
                        )
                    }
                }
            }
        }
        .task(id: query) { await prepareMatches() }
        .hakoProductModalSearchable(
            text: $query,
            prompt: Text("Search rule sets")
        )
        .hakoPageTitle("Rule Sets")
        .hakoProductModalChild(
            title: "Rule Sets",
            searchText: $query
        )
        .hakoCapturesDismiss(dismiss)
    }

    private func dismissRoute() {
#if os(macOS)
        if let popRoute {
            popRoute(HakoPopToken())
        } else {
            dismiss()
        }
#else
         
         
         
        dismiss()
#endif
    }

    private var filtered: [String] { matches }

    @MainActor
    private func prepareMatches() async {
        if folded.count != sets.count {
            folded = sets.map { $0.lowercased() }
        }
        guard !query.isEmpty else {
             
             
            matches = sets
            return
        }
        let needle = query
        let values = sets
        let foldedValues = folded
        let cap = Self.ruleSetMatchCap
        let hits = await Task.detached(priority: .userInitiated) {
            HakoGeoValueSearch.matches(
                values: values,
                folded: foldedValues,
                needle: needle,
                cap: cap,
                localizeRegions: false
            )
        }.value
         
        guard !Task.isCancelled else { return }
        matches = hits
    }

     
     
    private static var ruleSetMatchCap: Int { 300 }
}

private struct HakoRuleCatalogUnavailableView: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(spacing: HakoTheme.Spacing.compact) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(hako: .copy(title))
                .font(.headline)
            Text(hako: .copy(detail))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HakoTheme.Spacing.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension HakoRuleSetSnapshot {
     
     
     
     
     
     
    func subtitle(locale: Locale) -> String {
        guard let entryCount else { return detail }
        let counted = HakoCopy.format("%@ rules", locale: locale, HakoCopy.count(entryCount, locale: locale))
        return detail.isEmpty ? counted : detail + " · " + counted
    }
}
