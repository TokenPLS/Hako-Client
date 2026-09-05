import Foundation
import HakoClientUI
import SwiftUI

 
struct RulePolicyOptions {
    let groups: [(name: String, type: String)]
    let proxies: [(name: String, type: String)]
    let ruleSets: [String]
     
     
     
     
    var domainRuleSets: [String] = []
     
    var subRuleNames: [String]? = nil

    static let empty = RulePolicyOptions(
        groups: [],
        proxies: [],
        ruleSets: []
    )

    static func make(sourceYAML: String?) -> RulePolicyOptions {
        let proxiesModel = ProxiesOverviewModel.make(
            sourceYAML: sourceYAML
        )
        let rulesModel = RulesOverviewModel.make(
            sourceYAML: sourceYAML
        )
        return RulePolicyOptions(
            groups: proxiesModel.groups.map {
                ($0.name, $0.type)
            },
            proxies: proxiesModel.proxies.map {
                ($0.name, $0.type)
            },
            ruleSets: rulesModel.ruleSets.map(\.name),
            domainRuleSets: rulesModel.ruleSets
                .filter { $0.behavior != "ipcidr" }
                .map(\.name),
            subRuleNames: subRuleBranchNames(in: sourceYAML)
        )
    }

     
     
     
     
     
     
    func including(customGroups: [CustomProxyGroup]) -> RulePolicyOptions {
        let known = Set(groups.map(\.name))
        let fresh = customGroups
            .filter { !$0.name.isEmpty && !known.contains($0.name) }
            .map { (name: $0.name, type: $0.type) }
        guard !fresh.isEmpty else { return self }
        return RulePolicyOptions(
            groups: groups + fresh,
            proxies: proxies,
            ruleSets: ruleSets,
            domainRuleSets: domainRuleSets,
            subRuleNames: subRuleNames
        )
    }

     
     
     
    private static func subRuleBranchNames(in yaml: String?) -> [String]? {
        guard let yaml,
              let json = try? ConfigTransforms.yamlToJSON(yaml),
              let root = try? JSONSerialization.jsonObject(
                with: Data(json.utf8)
              ) as? [String: Any],
              let subRules = root["sub-rules"] as? [String: Any] else {
            return nil
        }
        return Array(subRules.keys)
    }

    var shared: HakoRulePolicyOptions {
        HakoRulePolicyOptions(
            groups: groups.map {
                HakoRulePolicySnapshot(
                    name: $0.name,
                    type: $0.type
                )
            },
            proxies: proxies.map {
                HakoRulePolicySnapshot(
                    name: $0.name,
                    type: $0.type
                )
            },
            ruleSets: ruleSets,
            subRuleNames: subRuleNames
        )
    }
}

typealias RuleTargetVerdict = HakoRuleTargetVerdict

extension RulePolicyOptions {
    static let builtinPolicies =
        HakoRulePolicyOptions.builtinPolicies

    func verdict(forTarget target: String) -> RuleTargetVerdict {
        shared.verdict(forTarget: target)
    }

    func flagsUnknownTarget(
        of rule: StructuredRule
    ) -> Bool {
        shared.flagsUnknownTarget(of: rule)
    }
}

 
 
 
struct RuleBuilderAdapter: View {
    private let raw: String
    private let options: RulePolicyOptions
    private let enabled: Bool
    private let comment: String
    private let saveDetails:
        ((_ raw: String, _ enabled: Bool, _ comment: String) -> Void)?
    private let save: (String) -> Void

    init(
        raw: String,
        options: RulePolicyOptions = .empty,
        enabled: Bool = true,
        comment: String = "",
        saveDetails: (
            (_ raw: String, _ enabled: Bool, _ comment: String) -> Void
        )? = nil,
        save: @escaping (String) -> Void
    ) {
        self.raw = raw
        self.options = options
        self.enabled = enabled
        self.comment = comment
        self.saveDetails = saveDetails
        self.save = save
    }

    var body: some View {
        HakoClientUI.HakoRuleEditorView(
            rule: HakoPersonalRuleSnapshot(
                raw: raw,
                isEnabled: enabled,
                comment: comment.isEmpty ? nil : comment
            ),
            options: options.shared,
            initialRoute: initialRoute,
            runtimeProfile: hakoAppleRuntimeProfile,
            palette: HakoClientUI.HakoProductPalette.hakoProduct,
            loadGeoValues: { resource in
                await GeoCategoryCache.shared.categories(
                    for:
                        resource == .geoIP
                            ? .geoip
                            : .geosite
                )
            },
            icon: { symbol in
                HakoSymbolImage(symbol: symbol)
            }
        ) { updated in
            if let saveDetails {
                saveDetails(
                    updated.raw,
                    updated.isEnabled,
                    updated.comment ?? ""
                )
            } else {
                save(updated.raw)
            }
        }
    }

    private var initialRoute: HakoRuleBuilderRoute? {

        return nil

    }
}

 
 
struct GeoValuePickerView: View {
    let resource: GeoResource
    let localizeRegions: Bool
    let title: String
    let current: String
    let pick: (String) -> Void

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @State private var query = ""
    @State private var values: [String] = []
    @State private var loaded = false

    private func regionName(_ code: String) -> String? {
        guard localizeRegions, code.count == 2 else {
            return nil
        }
        return Locale.current.localizedString(
            forRegionCode: code.uppercased()
        )
    }

    private var filtered: [String] {
        guard !query.isEmpty else { return values }
        return values.filter {
            $0.localizedCaseInsensitiveContains(query)
                || (
                    regionName($0)?
                        .localizedCaseInsensitiveContains(query)
                        ?? false
                )
        }
    }

    var body: some View {
        Group {
            if !loaded {
                ProgressView()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .accessibilityIdentifier("rule-geo.loading")
            } else {
                List(filtered, id: \.self) { value in
                    Button {
                        pick(value)
                        dismiss()
                    } label: {
                        HStack(spacing: HakoTheme.Spacing.row) {
                            Text(
                                localizeRegions
                                    && value.count == 2
                                    ? value.uppercased()
                                    : value
                            )
                            if let name = regionName(value) {
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            if value == current {
                                HakoSymbolImage(
                                    symbol: .checkmark
                                )
                                .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "rule-geo.\(value)"
                    )
                }
                .searchable(
                    text: $query,
                    prompt: Text("Search code or name")
                )
            }
        }
        .hakoPageTitle(.copy(title))
        .task {
            guard !loaded else { return }
            values = await GeoCategoryCache.shared.categories(
                for: resource
            )
            loaded = true
        }
        .hakoCapturesDismiss(dismiss)
    }
}

 
struct RuleSetPickerView: View {
    let sets: [String]
    let current: String
    let pick: (String) -> Void

     
    @State private var dismiss = HakoDismissHandle()

    var body: some View {
        List(sets, id: \.self) { name in
            Button {
                pick(name)
                dismiss()
            } label: {
                HStack {
                    Text(name)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    if name == current {
                        HakoSymbolImage(symbol: .checkmark)
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .hakoPageTitle("Rule Sets")
        .hakoCapturesDismiss(dismiss)
    }
}
