import Foundation
import HakoClientUI
import SwiftUI

 
 
 
 
struct RulesOverviewAdapter<ActiveRules: View>: View {
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    private let sourceYAML: String?
    private let canInspectActiveRules: Bool
     
     
    private let compileVerdicts: ProviderCompileVerdicts
     
     
     
    private let activeRules: () -> ActiveRules
    private let openProxiesGroup: ((String) -> Void)?

     
     
     
     
     
     
     
     
     
     
    @State private var prepared: (token: UUID, snapshot: AppleClientSnapshot)?

    @MainActor
    init(
        sourceYAML: String?,
        canInspectActiveRules: Bool = false,
        compileVerdicts: ProviderCompileVerdicts = ProviderCompileVerdicts(),
        openProxiesGroup: ((String) -> Void)? = nil,
        ownsNavigationContainer: Bool = true,
        @ViewBuilder activeRules: @escaping () -> ActiveRules
    ) {
        self.sourceYAML = sourceYAML
        self.canInspectActiveRules = canInspectActiveRules
        self.compileVerdicts = compileVerdicts
        self.activeRules = activeRules
        self.openProxiesGroup = openProxiesGroup
        self.ownsNavigationContainer = ownsNavigationContainer
         
         
         
         
         
        _prepared = State(
            initialValue: RulesOverviewPreparationCache.shared.value(
                for: RulesPreparationKey(
                    sourceYAML: sourceYAML,
                    canInspectActiveRules: canInspectActiveRules,
                    wantsJumpableTargets: openProxiesGroup != nil,
                    compileVerdicts: compileVerdicts
                )
            )
        )
    }

     
    private let ownsNavigationContainer: Bool

    var body: some View {
         
         
         
         
         
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            page
        }
    }

    @ViewBuilder
    private var page: some View {
        if ownsNavigationContainer {
            content.hakoSheetPresentation()
        } else {
            content
        }
    }

    private var content: some View {
        Group {
            if let prepared {
                 
                 
                 
                 
                 
                EquatableBrowser(
                    token: prepared.token,
                    snapshot: prepared.snapshot,
                    presentationClass:
                        horizontalSizeClass == .regular
                            ? .regularTouch
                            : .compactTouch,
                    showsDismissControl: ownsNavigationContainer,
                    actions: sharedActions,
                    activeRules: activeRules
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
         
         
         
         
         
         
        .task(
            id: RulesPreparationKey(
                sourceYAML: sourceYAML,
                canInspectActiveRules: canInspectActiveRules,
                wantsJumpableTargets: openProxiesGroup != nil,
                compileVerdicts: compileVerdicts
            )
        ) {
            let key = RulesPreparationKey(
                sourceYAML: sourceYAML,
                canInspectActiveRules: canInspectActiveRules,
                wantsJumpableTargets: openProxiesGroup != nil,
                compileVerdicts: compileVerdicts
            )
            await prepare(key: key)
        }
    }

    private struct EquatableBrowser: View, Equatable {
        let token: UUID
        let snapshot: AppleClientSnapshot
        let presentationClass: HakoClientUI.HakoPresentationClass
        let showsDismissControl: Bool
        let actions: AppleClientActions
        let activeRules: () -> ActiveRules

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.token == rhs.token
                && lhs.presentationClass == rhs.presentationClass
                && lhs.showsDismissControl == rhs.showsDismissControl
        }

        var body: some View {
            HakoClientUI.HakoRulesOverviewView(
                snapshot: snapshot,
                actions: actions,
                presentationClass: presentationClass,
                palette: HakoClientUI.HakoProductPalette.hakoProduct,
                showsDismissControl: showsDismissControl
            ) { symbol in
                HakoSymbolImage(symbol: symbol)
            } activeRulesDestination: {
                activeRules()
            }
        }
    }

    @MainActor
    private func prepare(key: RulesPreparationKey) async {
        let yaml = sourceYAML
        let canInspect = canInspectActiveRules
        let verdicts = compileVerdicts
        let wantsJumpableTargets = openProxiesGroup != nil
        let world = await RulesOverviewPreparationCache.shared.value(
            for: key
        ) {
            let began = DispatchTime.now().uptimeNanoseconds
            let snapshot = await Task.detached(priority: .userInitiated) {
                RulesOverviewSnapshotBuilder.build(
                    sourceYAML: yaml,
                    canInspectActiveRules: canInspect,
                    wantsJumpableTargets: wantsJumpableTargets,
                    compileVerdicts: verdicts
                )
            }.value
            HakoPerf.span(
                "rules.prepare",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail: "rules=\(snapshot.rules.overview.inlineCount)"
            )
            return (token: UUID(), snapshot: snapshot)
        }
        guard !Task.isCancelled,
              key == RulesPreparationKey(
                  sourceYAML: sourceYAML,
                  canInspectActiveRules: canInspectActiveRules,
                  wantsJumpableTargets: openProxiesGroup != nil,
                  compileVerdicts: compileVerdicts
              ) else { return }
        prepared = world
    }

    private var productPalette: HakoClientUI.HakoProductPalette {
        HakoClientUI.HakoProductPalette.hakoProduct
    }

    private var sharedActions: AppleClientActions {
        AppleClientActions(capability: .rules) { action in
            guard case .rules(let command) = action else {
                return
            }
            switch command {
            case .openActiveRules:
                 
                break
            case .openProxiesGroup(let name):
                openProxiesGroup?(name)
            case .saveProfileRules:
                break
            }
        }
    }
}

 
 
 
private struct RulesPreparationKey: Equatable {
    let sourceYAML: String?
    let canInspectActiveRules: Bool
    let wantsJumpableTargets: Bool
     
     
    let compileVerdicts: ProviderCompileVerdicts
}

 
@MainActor
private enum RulesOverviewPreparationCache {
    static let shared = HakoLastPreparation<
        RulesPreparationKey,
        (token: UUID, snapshot: AppleClientSnapshot)
    >()
}

 
 
 
 
 
enum RulesOverviewSnapshotBuilder {
     
     
     
    static func build(
        sourceYAML: String?,
        canInspectActiveRules: Bool,
        wantsJumpableTargets: Bool,
         
         
         
         
         
        compileVerdicts: ProviderCompileVerdicts = ProviderCompileVerdicts()
    ) -> AppleClientSnapshot {
        let model = RulesOverviewModel.make(sourceYAML: sourceYAML)
        let jumpable: Set<String>
        if wantsJumpableTargets {
            let knownGroups = Set(
                ProxiesOverviewModel.make(sourceYAML: sourceYAML)
                    .groups
                    .map(\.name)
            )
            jumpable = RulesOverviewModel.jumpableTargets(
                buckets: model.buckets,
                fallback: model.fallback,
                knownGroups: knownGroups
            )
        } else {
            jumpable = []
        }
        return AppleClientSnapshot(
            revision: 0,
            connection: AppleClientConnectionSnapshot(
                phase: .unavailable
            ),
            rules: HakoRulesSnapshot(
                overview: HakoRulesOverviewSnapshot(
                    inlineCount: model.inlineCount,
                    inapplicableCount: model.inapplicableCount,
                    platformTitle: model.platformTitle,
                    buckets: model.buckets.map {
                        HakoRuleBucketSnapshot(
                            target: $0.target,
                            rules: $0.rules.map(sharedRule),
                            canOpenProxiesGroup:
                                jumpable.contains($0.target)
                        )
                    },
                    ruleSets: model.ruleSets.map { set in
                        HakoRuleSetSnapshot(
                            name: set.name,
                            detail: compiledDetail(
                                set, verdicts: compileVerdicts
                            ),
                            blockedReason: compileVerdicts.blockedReason(
                                ruleProvider: set.name
                            ),
                            entryCount: compileVerdicts.entryCounts[set.name]
                        )
                    },
                    fallback: model.fallback.map(sharedRule),
                    searchableRules:
                        model.allRules.map(sharedRule),
                    jumpableTargets: jumpable
                ),
                canInspectActiveRules: canInspectActiveRules
            ),
            capabilities: AppleClientCapabilities([
                .rules: .available,
            ])
        )
    }

     
     
    private static func compiledDetail(
        _ set: RulesOverviewModel.RuleSet,
        verdicts: ProviderCompileVerdicts
    ) -> String {
        guard case .compiled(let compiled?)? = verdicts.ruleProviders[set.name],
              !set.behavior.isEmpty,
              compiled != set.behavior
        else { return set.detail }
        return set.detail + " → " + compiled
    }

    private static func sharedRule(
        _ rule: ParsedRule
    ) -> HakoRuleLineSnapshot {
        HakoRuleLineSnapshot(
            raw: rule.raw,
            type: rule.type,
            payload: rule.payload,
            target: rule.target
        )
    }
}

struct ParsedRule: Equatable {
    let raw: String
    let type: String
    let payload: String
    let target: String

     
     
    let typeUppercased: String

    init(raw: String) {
        self.raw = raw
         
         
         
         
         
         
        var fields: [Substring] = []
        fields.reserveCapacity(4)
        let utf8 = raw.utf8
        var start = utf8.startIndex
        var index = start
        while index < utf8.endIndex {
            if utf8[index] == 0x2C {
                if start < index { fields.append(Self.trimmed(raw[start..<index])) }
                start = utf8.index(after: index)
            }
            index = utf8.index(after: index)
        }
        if start < utf8.endIndex { fields.append(Self.trimmed(raw[start..<utf8.endIndex])) }

        type = fields.first.map(String.init) ?? raw
        typeUppercased = type.uppercased()
        var end = fields.count
        while end > 1, Self.isModifier(fields[end - 1]) { end -= 1 }
        target = end > 1 ? String(fields[end - 1]) : ""
        switch end {
        case ...2: payload = ""
        case 3: payload = String(fields[1])
        default: payload = fields[1..<(end - 1)].joined(separator: ",")
        }
    }

    private static func trimmed(_ part: Substring) -> Substring {
        let bytes = part.utf8
        guard let first = bytes.firstIndex(where: { $0 != 0x20 && $0 != 0x09 }),
              let last = bytes.lastIndex(where: { $0 != 0x20 && $0 != 0x09 })
        else { return part[part.startIndex..<part.startIndex] }
        return part[first...last]
    }

     
     
    private static func isModifier(_ field: Substring) -> Bool {
        let bytes = field.utf8
        guard bytes.count == 10 || bytes.count == 3 else { return false }
        let want: StaticString = bytes.count == 10 ? "no-resolve" : "src"
        return want.withUTF8Buffer { expected in
            var i = 0
            for byte in bytes {
                let lower = (0x41...0x5A).contains(byte) ? byte | 0x20 : byte
                if lower != expected[i] { return false }
                i += 1
            }
            return true
        }
    }
}

struct RulesOverviewModel {
    struct Bucket: Identifiable {
        var id: String { target }
        let target: String
        let rules: [ParsedRule]
    }

    struct RuleSet: Identifiable {
        var id: String { name }
        let name: String
        let detail: String
         
         
         
        var behavior: String = ""
    }

    let inlineCount: Int
    let inapplicableCount: Int
     
     
     
    let platformTitle: String
    let buckets: [Bucket]
    let ruleSets: [RuleSet]
    let fallback: [ParsedRule]
    let allRules: [ParsedRule]

    func search(_ query: String) -> [ParsedRule] {
        allRules.filter {
            $0.raw.localizedCaseInsensitiveContains(query)
        }
    }

    static func jumpableTargets(
        buckets: [Bucket],
        fallback: [ParsedRule],
        knownGroups: Set<String>
    ) -> Set<String> {
        Set(buckets.map(\.target) + fallback.map(\.target))
            .intersection(knownGroups)
    }

     
     
     
    var fingerprint: String {
        "\(inlineCount)|\(inapplicableCount)|\(fallback.count)|\(ruleSets.count)|"
            + buckets.map { "\($0.target)=\($0.rules.count)" }.joined(separator: ",")
    }

    static func make(
        sourceYAML: String?,
        runtimeProfile: HakoAppleRuntimeProfile =
            hakoAppleRuntimeProfile
    ) -> RulesOverviewModel {
        guard let yaml = sourceYAML,
              let parsed = ConfigTransforms.parsedRoot(forYAML: yaml)
        else {
            return build(root: nil, runtimeProfile: runtimeProfile)
        }
         
         
        let key = "rules.overview|"
            + runtimeProfile.unavailableRuleActionNames.sorted().joined(separator: ",")
        return parsed.memo(key) { build(root: parsed.root, runtimeProfile: runtimeProfile) }
    }

    private static func build(
        root: [String: Any]?,
        runtimeProfile: HakoAppleRuntimeProfile
    ) -> RulesOverviewModel {
        var parsed: [ParsedRule] = []
        var sets: [RuleSet] = []
        if let root {
            parsed = ((root["rules"] as? [Any]) ?? [])
                .compactMap { $0 as? String }
                .map(ParsedRule.init(raw:))
            if let providers =
                root["rule-providers"] as? [String: Any]
            {
                sets = providers.keys.sorted().map { name in
                    let spec =
                        providers[name] as? [String: Any]
                    let behavior =
                        (spec?["behavior"] as? String) ?? ""
                    let type =
                        (spec?["type"] as? String) ?? ""
                    return RuleSet(
                        name: name,
                        detail: [type, behavior]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · "),
                        behavior: behavior.lowercased()
                    )
                }
            }
        }
        let applicable = parsed.filter { rule in
             
             
             
            guard runtimeProfile.unavailableRuleActionNames
                .contains(rule.typeUppercased)
            else { return true }
             
             
             
             
             
             
             
            return RuleEffect.of(rule.raw) == .matchesEverything
        }
         
         
         
         
        let fallbackRules = applicable.filter {
            $0.typeUppercased == "MATCH"
        }
        let bucketable = applicable.filter {
            $0.typeUppercased != "MATCH"
        }
        let grouped = Dictionary(
            grouping: bucketable,
            by: \.target
        )
        let buckets = grouped
            .map { Bucket(target: $0.key, rules: $0.value) }
            .sorted {
                ($0.rules.count, $1.target)
                    > ($1.rules.count, $0.target)
            }
        return RulesOverviewModel(
            inlineCount: parsed.count,
            inapplicableCount:
                parsed.count - applicable.count,
            platformTitle: runtimeProfile.platformTitle,
            buckets: buckets,
            ruleSets: sets,
            fallback: fallbackRules,
            allRules: parsed
        )
    }
}
