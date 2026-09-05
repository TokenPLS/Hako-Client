import HakoClientUI
import SwiftUI

 
 
 
struct ProfileRulesAdapter: View {
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    private let profile: Profile
    private let sourceYAML: String?
    private let ownsNavigationContainer: Bool
    private let save: (ProfileRulesDraft) throws -> Void
    @Environment(\.locale) private var locale
    @State private var deviations: ConfigDeviationReport?

    init(
        profile: Profile,
        sourceYAML: String? = nil,
        ownsNavigationContainer: Bool = true,
        save: @escaping (ProfileRulesDraft) throws -> Void
    ) {
        self.profile = profile
        self.sourceYAML = sourceYAML
        self.ownsNavigationContainer = ownsNavigationContainer
        self.save = save
    }

     
     
     
     
     
     
     
     
    @State private var prepared: (token: UUID, snapshot: AppleClientSnapshot)?

    var body: some View {
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            Group {
                if let prepared {
                     
                     
                    EquatableEditor(
                        token: prepared.token,
                        snapshot: prepared.snapshot,
                        presentationClass: presentationClass,
                        showsDismissControl: ownsNavigationContainer,
                        actions: sharedActions,
                        deviations: deviations,
                        loadPolicyOptions: {
                            await Self.loadPolicyOptions(
                                sourceYAML: sourceYAML
                            )
                        }
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .task(
                id: PreparationKey(profile: profile, sourceYAML: sourceYAML)
            ) {
                await prepare()
            }
            .task(id: RunningCoreDeviations.taskKey(for: profile)) {
                let profile = profile
                let locale = locale
                deviations = await Task.detached(priority: .userInitiated) {
                    RunningCoreDeviations.report(
                        profile: profile,
                        sidecarYAML: RunningCoreDeviations.sidecarYAML(for: profile),
                        locale: locale
                    )
                }.value
            }
            .hakoFeaturePresentation(
                ownsNavigationContainer: ownsNavigationContainer
            )
        }
    }

    private struct EquatableEditor: View, Equatable {
        let token: UUID
        let snapshot: AppleClientSnapshot
        let presentationClass: HakoClientUI.HakoPresentationClass
        let showsDismissControl: Bool
        let actions: AppleClientActions
         
         
        let deviations: ConfigDeviationReport?
        let loadPolicyOptions: @MainActor () async
            -> HakoClientUI.HakoRulePolicyOptions

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.token == rhs.token
                && lhs.presentationClass == rhs.presentationClass
                && lhs.showsDismissControl == rhs.showsDismissControl
                && lhs.deviations == rhs.deviations
        }

        var body: some View {
            HakoClientUI.HakoProfileRulesView(
                snapshot: snapshot,
                actions: actions,
                presentationClass: presentationClass,
                runtimeProfile: hakoAppleRuntimeProfile,
                palette: HakoClientUI.HakoProductPalette.hakoProduct,
                showsDismissControl: showsDismissControl,
                loadPolicyOptions: loadPolicyOptions,
                loadGeoValues: { resource in
                    await GeoCategoryCache.shared.categories(
                        for:
                            resource == .geoIP
                                ? .geoip
                                : .geosite
                    )
                }
            ) { symbol in
                HakoSymbolImage(symbol: symbol)
            } trailing: {
                 
                 
                 
                ConfigDeviationSection(
                    report: deviations,
                    fields: RunningCoreDeviations.fields(for: [.routingRules]),
                    identifierPrefix: "profile-rules.deviation"
                )
            }
        }
    }

    private struct PreparationKey: Equatable {
        let profile: Profile
        let sourceYAML: String?
    }

    @MainActor
    private func prepare() async {
        let profile = profile
        let began = DispatchTime.now().uptimeNanoseconds
        let snapshot = await Task.detached(priority: .userInitiated) {
            Self.buildSnapshot(profile: profile)
        }.value
        HakoClientUI.HakoPerf.span(
            "rules.landing.prepare",
            milliseconds: Self.elapsedMilliseconds(since: began),
            detail: "personal=\(snapshot.rules.editor?.rules.count ?? 0)"
        )
        prepared = (token: UUID(), snapshot: snapshot)
    }

    @MainActor
    private static func loadPolicyOptions(
        sourceYAML: String?
    ) async -> HakoClientUI.HakoRulePolicyOptions {
        let began = DispatchTime.now().uptimeNanoseconds
        let options = await Task.detached(priority: .userInitiated) {
            buildPolicyOptions(sourceYAML: sourceYAML)
        }.value
        HakoClientUI.HakoPerf.span(
            "rules.policy.prepare",
            milliseconds: elapsedMilliseconds(since: began),
            detail:
                "groups=\(options.groups.count) proxies=\(options.proxies.count)"
        )
        return options
    }

    nonisolated private static func elapsedMilliseconds(
        since began: UInt64
    ) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000
    }

    private var presentationClass: HakoClientUI.HakoPresentationClass {
#if os(macOS)
         
         
        .regularTouch
#else
        horizontalSizeClass == .regular
            ? .regularTouch
            : .compactTouch
#endif
    }

    private var productPalette: HakoClientUI.HakoProductPalette {
        HakoClientUI.HakoProductPalette.hakoProduct
    }

     
     
    nonisolated static func buildSnapshot(
        profile: Profile
    ) -> AppleClientSnapshot {
        let draft = ProfileRulesDraft(profile: profile)
        return AppleClientSnapshot(
            revision: 0,
            connection: AppleClientConnectionSnapshot(
                phase: .unavailable
            ),
            rules: HakoRulesSnapshot(
                editor: HakoProfileRulesSnapshot(
                    profileName: profile.label,
                    rules: draft.rules.map {
                        HakoPersonalRuleSnapshot(
                            raw: $0,
                            isEnabled:
                                !draft.disabledRules.contains($0),
                            comment: draft.comments[$0]
                        )
                    },
                    prependRules: draft.prependRules,
                    policyOptions: .empty,
                    initialRuleBuilderRaw:
                        initialRuleBuilderRaw,
                    initialRuleBuilderRoute:
                        initialRuleBuilderRoute
                )
            ),
            capabilities: AppleClientCapabilities([
                .rules: .available,
            ])
        )
    }

     
     
     
    nonisolated static func buildPolicyOptions(
        sourceYAML: String?
    ) -> HakoClientUI.HakoRulePolicyOptions {
        RulePolicyOptions.make(sourceYAML: sourceYAML).shared
    }

    private var sharedActions: AppleClientActions {
        AppleClientActions(capability: .rules) { action in
            guard case .rules(
                .saveProfileRules(let sharedDraft)
            ) = action else {
                return
            }
            var draft = ProfileRulesDraft(profile: profile)
            draft.rules = sharedDraft.rules.map(\.raw)
            draft.prependRules = sharedDraft.prependRules
            draft.disabledRules = Set(
                sharedDraft.rules
                    .filter { !$0.isEnabled }
                    .map(\.raw)
            )
            draft.comments = Dictionary(
                uniqueKeysWithValues:
                    sharedDraft.rules.compactMap {
                        rule in
                        guard let comment = rule.comment,
                            !comment.isEmpty
                        else {
                            return nil
                        }
                        return (rule.raw, comment)
                    }
            )
            try save(draft)
        }
    }

    nonisolated private static var initialRuleBuilderRaw: String? {

        nil

    }

    nonisolated private static var initialRuleBuilderRoute: HakoRuleBuilderRoute? {

        nil

    }
}
