import HakoClientUI
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

 
 
 
struct ProfileOverrideView: View {
    let profile: Profile

     
     
     
    @State private var overrideDeviations: ConfigDeviationReport?
    let save: (Profile) -> Void
    private let settingsFacade: ProfileSettingsFacade

     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @State private var patchText: String
    @State private var patchDiagnosticLine: Int?
    @State private var rules: [String]
    @State private var prependRules: Bool
    @State private var disabledGlobalRules: Set<String>
    @State private var selectedScriptID: String?
    @State private var mode: Profile.OverwriteMode
    @State private var customGroups: [CustomProxyGroup]
    @State private var customRules: [String]
    @State private var proxyChain: ProxyChainSpec
    @State private var legacyRelayMigrations: [LegacyRelayMigration]
    @State private var error = ""
    @State private var isConfirmingQuickFill = false
    @State private var editingRule: RuleEditTarget?

    private let globalRules: [String]
    private let scripts: [ConfigScript]
    private let rawYAML: String?
    private let opensProxyChainsDirectly: Bool

    private struct RuleEditTarget: Identifiable {
        let id = UUID()
         
         
         
        let rowID: UUID?
        let raw: String
    }

     
    @State private var ruleRows = HakoIdentifiedRows()

    init(
        profile: Profile,
        rawYAML: String?,
        openProxyChains: Bool = false,
        save: @escaping (Profile) -> Void
    ) {
        let settingsFacade = ProfileSettingsFacade()
        let settings = settingsFacade.snapshot(for: profile)
        self.profile = profile
        self.save = save
        self.rawYAML = rawYAML
        self.settingsFacade = settingsFacade
        opensProxyChainsDirectly = openProxyChains
        _patchText = State(initialValue: Self.prettyJSON(settings.override.patchJSON))
        _rules = State(initialValue: settings.override.appendRules)
        _prependRules = State(initialValue: settings.override.prependRules)
        _disabledGlobalRules = State(
            initialValue: Set(settings.override.disabledGlobalRules ?? [])
        )
        globalRules = settings.migratedGlobalOverride?.appendRules ?? []
        scripts = ScriptLibrary.load()
        _selectedScriptID = State(initialValue: settings.selectedScriptID)
        _mode = State(initialValue: settings.overwriteMode ?? .standard)
        _customGroups = State(initialValue: settings.customOverwrite?.proxyGroups ?? [])
        _customRules = State(initialValue: settings.customOverwrite?.rules ?? [])
        _proxyChain = State(initialValue: settings.proxyChain ?? ProxyChainSpec())
        _legacyRelayMigrations = State(
            initialValue: settings.legacyRelayMigrations ?? []
        )
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            if opensProxyChainsDirectly {
                ProfileProxyChainEditor(
                    baseResult: chainBaseResult(),
                    spec: $proxyChain,
                    legacyRelayMigrations: $legacyRelayMigrations
                )
                .hakoSheetPresentation()
                .hakoToolbarUnlessInPanel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismissPresentation() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        HakoSaveButton { persist() }
                    }
                }
            } else {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Profile.OverwriteMode.allCases) { mode in
                             
                             
                             
                             
                            Text(HakoCopy.key(mode.rawValue.capitalized))
                                .tag(mode)
                        }
                    }
                    .hakoIdiomFormPickerStyle()
                    .accessibilityIdentifier("profile.override.mode")
                } header: {
                    Text("Override Mode")
                }

                if mode == .standard {
                    Section {
                        CodeEditorPanel(
                            text: $patchText,
                            language: .json,
                            minHeight: 260,
                            diagnosticLine: patchDiagnosticLine
                        )
                    } header: {
                        Text("Patch JSON")
                    } footer: {
                        Text("Deep-merged into this profile's generated working copy. Use {} for no field overrides.")
                    }

                    Section {
                        ForEach(ruleRows.current(for: rules)) { row in
                            let rule = ruleRows.index(of: row.id)
                                .map { rules[$0] } ?? ""
                            HakoMacDeletableRow(onDelete: {
                                ruleRows.remove(row.id, from: &rules)
                            }) {
                                Button {
                                    editingRule = RuleEditTarget(rowID: row.id, raw: rule)
                                } label: {
                                    Text(rule)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        .onDelete { ruleRows.removeOffsets($0, from: &rules) }
                        .onMove { ruleRows.move(fromOffsets: $0, toOffset: $1, in: &rules) }
                        .onAppear { ruleRows.resync(count: rules.count) }
                        .onChange(of: rules.count) { ruleRows.resync(count: $0) }

                        HakoAddRow(Text("Add Rule")) {
                            editingRule = RuleEditTarget(rowID: nil, raw: "")
                        } touchLabel: {
                            Label("Add Rule", systemImage: HakoSymbol.plus.name)
                        }
                        Toggle("Insert before subscription rules", isOn: $prependRules)
                            .accessibilityIdentifier("profile.override.prepend-rules")
                    } header: {
                        Text("Added Rules")
                    } footer: {
                        Text(
                            HakoPlatformLayout.pageUsesSystemSettingsIdiom
                                ? "Click a rule to edit it; use Edit to reorder or delete."
                                : "Tap to edit; use Edit to reorder or delete."
                        )
                    }
                } else if mode == .script {
                    Section {
                    Picker("Override Script", selection: $selectedScriptID) {
                        Text("None").tag(String?.none)
                        ForEach(scripts) { script in
                            Text(script.label).tag(Optional(script.id))
                        }
                    }
                        .accessibilityIdentifier("profile.override.script")
                    } header: {
                        Text("Script")
                    } footer: {
                        Text("The selected script transforms the full generated working copy before app-wide overrides.")
                    }
                } else {
                    Section {
                        HakoRoutedViewLink {
                            HakoLazyView {
                                CustomProxyGroupsEditor(
                                    groups: $customGroups,
                                    profileProxyNames: memberCandidateNames,
                                    validationContext:
                                        GroupMemberCandidates.validationContext(
                                            sourceYAML: rawYAML,
                                            profile: profile,
                                             
                                             
                                             
                                            draftGroups: customGroups
                                        ),
                                    onRename: { old, new in
                                         
                                         
                                         
                                        var spec = CustomOverwriteSpec(
                                            proxyGroups: customGroups,
                                            rules: customRules
                                        )
                                        spec.renameProxyGroup(from: old, to: new)
                                        customGroups = spec.proxyGroups
                                        customRules = spec.rules
                                    }
                                )
                            }
                        } label: {
                            HakoDestinationRow(
                                title: "Proxy Groups",
                                subtitle: .format(
                                    "%@ groups",
                                    [String(customGroups.count)]
                                ),
                                symbol: .point3ConnectedTrianglepathDotted,
                                tint: .blue
                            )
                        }
                        .accessibilityIdentifier("profile.override.proxy-groups")
                        HakoRoutedViewLink {
                            CustomRulesEditor(
                                rules: $customRules,
                                options: policyOptions
                            )
                        } label: {
                            HakoDestinationRow(
                                title: "Rules",
                                subtitle: .format(
                                    "%@ rules",
                                    [String(customRules.count)]
                                ),
                                symbol: .listBulletRectangle,
                                tint: .orange
                            )
                        }
                        Button("Quick Fill from Source") {
                             
                             
                            if customGroups.isEmpty, customRules.isEmpty {
                                quickFill()
                            } else {
                                isConfirmingQuickFill = true
                            }
                        }
                        .accessibilityIdentifier("profile-override.quick-fill")
                        .hakoMacFormActionChrome()
                    } header: {
                        Text("Custom Configuration")
                    } footer: {
                        Text("Custom mode replaces proxy-groups and rules in the runtime copy; the source remains unchanged.")
                    }
                }

                Section {
                    HakoRoutedViewLink {
                        ProfileProxyChainEditor(
                            baseResult: chainBaseResult(),
                            spec: $proxyChain,
                            legacyRelayMigrations: $legacyRelayMigrations
                        )
                    } label: {
                        HakoDestinationRow(
                            title: "Proxy Chains",
                            subtitle: proxyChainSubtitle,
                            symbol: .arrowTriangleBranch,
                            tint: .indigo
                        )
                    }
                    .accessibilityIdentifier("profile.override.proxy-chains")
                } header: {
                    Text("Proxy Identity")
                } footer: {
                    Text("Credentials stay in the device Keychain. Chains use dialer-proxy; neither feature rewrites the downloaded source.")
                }

                if !globalRules.isEmpty {
                    Section {
                        ForEach(globalRules, id: \.self) { rule in
                            Toggle(
                                isOn: Binding(
                                    get: { !disabledGlobalRules.contains(rule) },
                                    set: { enabled in
                                        if enabled { disabledGlobalRules.remove(rule) }
                                        else { disabledGlobalRules.insert(rule) }
                                    }
                                )
                            ) { Text(rule).font(.caption.monospaced()) }
                             
                             
                             
                            .accessibilityIdentifier("profile.override.migrated-rule.\(rule)")
                        }
                    } header: {
                        Text("Migrated Rules")
                    } footer: {
                        Text(
                            "Rules preserved for this profile during the app-wide settings migration."
                        )
                    }
                }

                if !error.isEmpty {
                    HakoStatusMessage(text: .copy(error), kind: .error)
                }

                ConfigDeviationSection(
                    report: overrideDeviations,
                    fields: RunningCoreDeviations.fields(
                        for: [.mode, .routingRules, .proxySources, .ruleSets, .advancedTrust]
                    ),
                    identifierPrefix: "profile-override.deviation"
                )
            }
            .task(id: profile.id) {
                let profile = profile
                overrideDeviations = await Task.detached(priority: .utility) {
                    RunningCoreDeviations.report(
                        profile: profile,
                        sidecarYAML: RunningCoreDeviations.sidecarYAML(for: profile),
                        locale: .current
                    )
                }.value
            }
            .hakoPageTitle("Profile Override")
             
             
             
             
            .alert(
                "Replace your custom groups and rules?",
                isPresented: $isConfirmingQuickFill
            ) {
                Button("Replace", role: .destructive) { quickFill() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Quick Fill reads this profile's source and replaces everything you have built here. This cannot be undone.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !insideProductModal {
                        Button("Cancel") { dismissPresentation() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                        HakoSaveButton { persist() }
                    }
                }
#if !os(macOS)
                ToolbarItem(placement: .bottomBar) {
                    HakoEditButton()
                }
#endif
            }
            .hakoProductModalRoot(title: "Profile Override")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                    HakoModalActionBar(
                        primaryTitle: "Save",
                    primaryDisabled: !hasChanges,
                        onPrimary: persist
                    )
                }
            }
            .hakoProductModal(item: $editingRule, role: .page) { target in
                RuleBuilderAdapter(
                    raw: target.raw,
                    options: policyOptions
                ) { rule in
                    if let id = target.rowID {
                        ruleRows.update(id, in: &rules, to: rule)
                    } else if !rules.contains(rule) {
                        ruleRows.append(rule, to: &rules)
                    }
                }
                .hakoModalPresentation(.page)
            }
            }
        }
        .hakoStackNavigationViewStyle()
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
     
     
     
     
     
     
     
    private var hasChanges: Bool {
        guard let updated = try? draftProfile() else { return true }
        return updated != profile
    }

    private func persist() {
        do {
            let updated = try draftProfile()
            if let rawYAML {
                _ = try ProfileRuntimeConfigBuilder.runtimePreview(
                    raw: rawYAML,
                    profile: updated
                )
            } else if !proxyChain.isEmpty || !legacyRelayMigrations.isEmpty {
                throw PipelineError.sourceUnavailable(
                    "Sync or activate this profile before configuring proxy chains."
                )
            }
            save(updated)
            dismissPresentation()
        } catch {
            patchDiagnosticLine = CodeEditorDiagnosticParser.line(in: error.localizedDescription)
            if error is CustomOverwriteError
                || error is ProxyChainError
                || error is LegacyRelayMigrationError
                || error is PipelineError {
                self.error = error.localizedDescription
            } else {
                self.error = "Patch JSON must be an object: \(error.localizedDescription)"
            }
        }
    }

    private func dismissPresentation() {
        (productModalDismiss ?? { dismiss() })()
    }

     
     
    private var policyOptions: RulePolicyOptions {
        RulePolicyOptions
            .make(sourceYAML: rawYAML)
            .including(customGroups: customGroups)
    }

    private func quickFill() {
        do {
            guard let rawYAML else {
                error = "Sync or activate this profile before using Quick Fill."
                return
            }
            let parsed = try CustomOverwriteSpec.parse(sourceYAML: rawYAML)
            customGroups = parsed.proxyGroups
            customRules = parsed.rules
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func chainBaseResult() -> Result<String, Error> {
        Result {
            guard let rawYAML else {
                throw PipelineError.sourceUnavailable(
                    "Sync or activate this profile before configuring proxy chains."
                )
            }
            var draft = try draftProfile()
            draft.proxyChain = nil
            return try ProfileRuntimeConfigBuilder.buildProduction(
                raw: rawYAML,
                profile: draft,
                applyProxyChain: false,
                applyLegacyRelayMigration: false
            )
        }
    }

    private func draftProfile() throws -> Profile {
        let trimmed = patchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let patchJSON: String
        if mode != .standard || trimmed.isEmpty || trimmed == "{}" {
            patchJSON = ""
        } else {
            let value = try JSONSerialization.jsonObject(with: Data(trimmed.utf8))
            guard value is [String: Any] else {
                throw CocoaError(.propertyListReadCorrupt)
            }
            let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
            patchJSON = String(decoding: data, as: UTF8.self)
        }

        let customOverwrite = CustomOverwriteSpec(
            proxyGroups: customGroups,
            rules: customRules
        )
        if mode == .custom { try customOverwrite.validate() }

        var settings = settingsFacade.snapshot(for: profile)
        settings.override = OverrideSpec(
            patchJSON: patchJSON,
            appendRules: rules,
            prependRules: prependRules,
            disabledGlobalRules: globalRules.filter(disabledGlobalRules.contains)
        )
        settings.selectedScriptID = selectedScriptID
        settings.overwriteMode = mode
        settings.customOverwrite = customOverwrite
        settings.proxyChain = proxyChain.isEmpty ? nil : proxyChain
        settings.legacyRelayMigrations = legacyRelayMigrations.isEmpty
            ? nil
            : legacyRelayMigrations
        return settingsFacade.applying(settings, to: profile)
    }

    private var proxyChainSubtitle: HakoDisplayText {
        let chainCount = proxyChain.assignments.count
        let relayCount = legacyRelayMigrations.count
        if chainCount == 0 && relayCount == 0 {
            return "Use generated proxy identities"
        }
        if chainCount > 0, relayCount > 0 {
            return .format(
                "%@ chain overrides · %@ relay migrations",
                [String(chainCount), String(relayCount)]
            )
        }
        return chainCount > 0
            ? .format("%@ chain overrides", [String(chainCount)])
            : .format("%@ relay migrations", [String(relayCount)])
    }

     
     
    private var memberCandidateNames: [String] {
        guard let rawYAML,
              let inventory = try? ProxyChainSpec.inventory(from: rawYAML)
        else { return [] }
        return inventory.map(\.name)
    }

    private static func prettyJSON(_ raw: String) -> String {
        guard !raw.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: Data(raw.utf8)),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

 
 
 
struct ProfileProxyChainDerivedState: Equatable {
    let relayAssessments: [LegacyRelayAssessment]
    let validationMessage: String

    static func evaluate(
        baseYAML: String?,
        baseError: String,
        inventory: [ProxyIdentity],
        spec: ProxyChainSpec,
        payloadEdits: [ProxyPayloadDialerEdit],
        legacyRelayMigrations: [LegacyRelayMigration]
    ) -> Self {
        guard baseError.isEmpty else {
            return Self(relayAssessments: [], validationMessage: "")
        }
        do {
            let overlaid = overlay(
                inventory: inventory,
                payloadEdits: payloadEdits
            )
            try spec.validate(in: overlaid)
            guard let baseYAML else {
                throw PipelineError.sourceUnavailable(
                    "Sync or activate this profile before configuring proxy chains."
                )
            }
            let generated = try spec.apply(to: baseYAML)
            let assessments =
                (try? LegacyRelayMigrationEngine.assess(generated)) ?? []
            do {
                _ = try LegacyRelayMigrationEngine.apply(
                    legacyRelayMigrations,
                    to: generated
                )
                return Self(
                    relayAssessments: assessments,
                    validationMessage: ""
                )
            } catch is LegacyRelayMigrationError where !assessments.isEmpty {
                 
                 
                return Self(
                    relayAssessments: assessments,
                    validationMessage: ""
                )
            } catch {
                return Self(
                    relayAssessments: assessments,
                    validationMessage: error.localizedDescription
                )
            }
        } catch {
            return Self(
                relayAssessments: [],
                validationMessage: error.localizedDescription
            )
        }
    }

    static func overlay(
        inventory: [ProxyIdentity],
        payloadEdits: [ProxyPayloadDialerEdit]
    ) -> [ProxyIdentity] {
        guard !payloadEdits.isEmpty else { return inventory }
        let edits = payloadEdits.reduce(into: [String: String]()) {
             
             
             
            $0["\($1.provider)\u{001F}\($1.node)"] = $1.dialerProxy
        }
        return inventory.map { identity in
            guard identity.kind == .payloadProxy,
                  let provider = identity.provider,
                  let edit = edits["\(provider)\u{001F}\(identity.name)"]
            else { return identity }
            return ProxyIdentity(
                name: identity.name,
                type: identity.type,
                dialerProxy: edit,
                kind: identity.kind,
                members: identity.members,
                provider: identity.provider
            )
        }
    }
}

struct ProfileProxyChainPreparation {
    let baseYAML: String?
    let inventory: [ProxyIdentity]
    let error: String
    let derived: ProfileProxyChainDerivedState
    let hasDerivedState: Bool

    init(
        baseResult: Result<String, Error>,
        spec: ProxyChainSpec = ProxyChainSpec(),
        legacyRelayMigrations: [LegacyRelayMigration] = [],
        payloadEdits: [ProxyPayloadDialerEdit] = [],
        precomputesDerived: Bool = true
    ) {
        let resolvedYAML: String?
        let identities: [ProxyIdentity]
        let message: String
        switch baseResult {
        case .success(let sourceYAML):
            do {
                let parsedInventory = try ProxyChainSpec.inventory(
                    from: sourceYAML
                )
                self.baseYAML = sourceYAML
                inventory = parsedInventory
                error = ""
                hasDerivedState = precomputesDerived
                derived = precomputesDerived
                    ? ProfileProxyChainDerivedState.evaluate(
                        baseYAML: sourceYAML,
                        baseError: "",
                        inventory: parsedInventory,
                        spec: spec,
                        payloadEdits: payloadEdits,
                        legacyRelayMigrations: legacyRelayMigrations
                    )
                    : ProfileProxyChainDerivedState(
                        relayAssessments: [],
                        validationMessage: ""
                    )
                return
            } catch {
                resolvedYAML = nil
                identities = []
                message = error.localizedDescription
            }
        case .failure(let error):
            resolvedYAML = nil
            identities = []
            message = error.localizedDescription
        }
        baseYAML = resolvedYAML
        inventory = identities
        error = message
        hasDerivedState = true
        derived = ProfileProxyChainDerivedState.evaluate(
            baseYAML: resolvedYAML,
            baseError: message,
            inventory: identities,
            spec: spec,
            payloadEdits: payloadEdits,
            legacyRelayMigrations: legacyRelayMigrations
        )
    }

    static func make(profile: Profile, rawYAML: String?) -> Self {
        let baseResult: Result<String, Error> = Result {
            guard let rawYAML else {
                throw PipelineError.sourceUnavailable(
                    "Sync or prepare this profile before configuring proxy chains."
                )
            }
            var base = profile
            base.proxyChain = nil
            base.legacyRelayMigrations = nil
            return try ProfileRuntimeConfigBuilder.buildProduction(
                raw: rawYAML,
                profile: base,
                applyProxyChain: false,
                applyLegacyRelayMigration: false
            )
        }
        return ProfileProxyChainPreparation(
            baseResult: baseResult,
            spec: profile.proxyChain ?? ProxyChainSpec(),
            legacyRelayMigrations: profile.legacyRelayMigrations ?? []
        )
    }
}

 
 
struct ProfileProxyChainEditor: View {
     
     
    @ViewBuilder
    private func legacyRelayRow(
        _ relay: LegacyRelayAssessment
    ) -> some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
            HStack(alignment: .firstTextBaseline) {
                Text(relay.groupName)
                    .font(.body.weight(.semibold))
                Spacer()
                if isConfirmed(relay) {
                    HakoStatusBadge(title: "TCP only", tint: .orange)
                }
            }
            Text(hako: .copy(relay.pathDescription))
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let blocker = relay.blocker {
                Text(hako: .copy(blocker.explanation))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Edit the profile or rebuild the affected proxies and group before using this configuration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isConfirmed(relay) {
                Text("This profile uses the reviewed TCP-only chain; the original profile stays unchanged.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Remove Migration", role: .destructive) {
                    confirmingRelayRemoval = relay
                }
                .accessibilityIdentifier(
                    "proxy-chain.legacy-relay.remove.\(relay.groupName)"
                )
            } else {
                Button("Review TCP-only Migration") {
                    confirmingRelay = relay
                }
                .accessibilityIdentifier(
                    "proxy-chain.legacy-relay.review.\(relay.groupName)"
                )
            }
        }
        .padding(.vertical, HakoTheme.Spacing.compact / 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            "proxy-chain.legacy-relay.\(relay.groupName)"
        )
        .accessibilityLabel(
            "\(relay.groupName), \(relay.pathDescription)"
        )
    }

    private var legacyRelayFooter: some View {
        Text("Older relay groups require review before Clash can rebuild them as supported proxy chains.")
    }

    @Binding var spec: ProxyChainSpec
    @Binding var legacyRelayMigrations: [LegacyRelayMigration]
     
     
     
    @Binding var payloadEdits: [ProxyPayloadDialerEdit]
     
    let measure: ((String) async -> Int?)?
    let openCustomNodes: (() -> Void)?
    let profileName: String?

    private let baseYAML: String?
    private let inventory: [ProxyIdentity]
    private let baseError: String
    private let saveError: String

    @State private var editing: ProxyIdentity?
    @State private var addingChain = false
     
    @State private var delays: [String: Int] = [:]
    @State private var measuring: Set<String> = []
    @State private var migrating: OrphanTarget?
    @State private var confirmingRelay: LegacyRelayAssessment?
    @State private var confirmingRelayRemoval: LegacyRelayAssessment?
    @State private var validationMessage = ""
    @State private var relayAssessments: [LegacyRelayAssessment] = []
    @State private var validatedKey: ValidationKey?

    private struct ValidationKey: Equatable {
        let spec: ProxyChainSpec
        let payloadEdits: [ProxyPayloadDialerEdit]
        let legacyRelayMigrations: [LegacyRelayMigration]
    }

    private struct OrphanTarget: Identifiable {
        let id: String
    }

    init(
        baseResult: Result<String, Error>,
        spec: Binding<ProxyChainSpec>,
        legacyRelayMigrations: Binding<[LegacyRelayMigration]>,
        saveError: String = "",
        payloadEdits: Binding<[ProxyPayloadDialerEdit]> = .constant([]),
        measure: ((String) async -> Int?)? = nil,
        openCustomNodes: (() -> Void)? = nil,
        profileName: String? = nil
    ) {
        self.init(
            preparation: ProfileProxyChainPreparation(
                baseResult: baseResult,
                spec: spec.wrappedValue,
                legacyRelayMigrations: legacyRelayMigrations.wrappedValue,
                payloadEdits: payloadEdits.wrappedValue,
                precomputesDerived: false
            ),
            spec: spec,
            legacyRelayMigrations: legacyRelayMigrations,
            saveError: saveError,
            payloadEdits: payloadEdits,
            measure: measure,
            openCustomNodes: openCustomNodes,
            profileName: profileName
        )
    }

    init(
        preparation: ProfileProxyChainPreparation,
        spec: Binding<ProxyChainSpec>,
        legacyRelayMigrations: Binding<[LegacyRelayMigration]>,
        saveError: String = "",
        payloadEdits: Binding<[ProxyPayloadDialerEdit]> = .constant([]),
        measure: ((String) async -> Int?)? = nil,
        openCustomNodes: (() -> Void)? = nil,
        profileName: String? = nil
    ) {
        _spec = spec
        _legacyRelayMigrations = legacyRelayMigrations
        _payloadEdits = payloadEdits
        self.measure = measure
        self.openCustomNodes = openCustomNodes
        self.profileName = profileName
        self.saveError = saveError
        baseYAML = preparation.baseYAML
        inventory = preparation.inventory
        baseError = preparation.error
        _validationMessage = State(
            initialValue: preparation.derived.validationMessage
        )
        _relayAssessments = State(
            initialValue: preparation.derived.relayAssessments
        )
        _validatedKey = State(initialValue:
            preparation.hasDerivedState
                ? ValidationKey(
                    spec: spec.wrappedValue,
                    payloadEdits: payloadEdits.wrappedValue,
                    legacyRelayMigrations: legacyRelayMigrations.wrappedValue
                )
                : nil
        )
    }

    var body: some View {
        Form {
#if os(macOS)
             
             
             
            if let profileName {
                Section {
                    HakoProfileContextHeader(
                        profileName: profileName,
                        message: "Proxy chains belong to this profile. Its imported source stays unchanged."
                    ) {
                        HakoSymbolImage(symbol: .profileClipboard)
                    }
                }
            }
#endif
            if !baseError.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(baseError), kind: .error)
                }
            } else if editableInventory.isEmpty && relayAssessments.isEmpty {
                 
                 
                 
                 
                Section {
                    HakoEmptyState(
                        title: "No Proxies",
                        message: "This profile has no proxies that can be linked.",
                        symbol: .arrowTriangleBranch
                    )
                    .listRowSeparator(.hidden)
                }
                if let openCustomNodes {
                    Section {
                        HakoAddRow(Text(HakoCopy.key("Add Custom Node"))) {
                            openCustomNodes()
                        } touchLabel: {
                            Label(
                                HakoCopy.key("Add Custom Node"),
                                systemImage: HakoSymbol.plus.name
                            )
                        }
                        .accessibilityIdentifier("proxy-chains.row.add-node")
                    } footer: {
                        Text(HakoCopy.key("A chain links two nodes this profile already has. Build nodes first, then come back to link them."))
                    }
                }
            } else if !editableInventory.isEmpty {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                if chainedProxies.isEmpty {
                    Section {
                        chainRows
                    } header: {
#if !os(macOS)
                         
                         
                         
                         
                        chainsHeader
#endif
                    }
                    Section {
                        addChainRow
                    } footer: {
                        Text("Each row reads the way the traffic goes: entry first, exit last. The site you open sees the exit. Tap a chain to change or remove it.")
                    }
                } else {
                    Section {
                        chainRows
                        addChainRow
                    } header: {
                        chainsHeader
                    } footer: {
                        Text("Each row reads the way the traffic goes: entry first, exit last. The site you open sees the exit. Tap a chain to change or remove it.")
                    }
                }
            }

            if !relayAssessments.isEmpty {
                Section {
                    ForEach(relayAssessments) { relay in
                        legacyRelayRow(relay)
                    }
                } header: {
                    Text("Legacy Relay Groups")
                } footer: {
                    legacyRelayFooter
                }
            }

            if !orphanAssignments.isEmpty {
                Section {
                    ForEach(orphanAssignments, id: \.proxy) { assignment in
                        Button {
                            migrating = OrphanTarget(id: assignment.proxy)
                        } label: {
                            HakoDestinationRow(
                                title: .verbatim(assignment.proxy),
                                subtitle: "Proxy identity is missing · tap to migrate or remove",
                                symbol: .exclamationmarkTriangle,
                                tint: .orange
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "proxy-chain.orphan.\(assignment.proxy)"
                        )
                    }
                } header: {
                    Text("Needs Attention")
                } footer: {
                    Text("A subscription update or source edit renamed/deleted these proxies. Migrate the identity or remove its override before saving.")
                }
            }

            if !validationMessage.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(validationMessage), kind: .error)
                }
            }

            if !saveError.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(saveError), kind: .error)
                }
            }

        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle("Proxy Chains")
        .hakoDetailPageInsets()
        .hakoProductModalChild(title: "Proxy Chains")
        .task(id: ValidationKey(
            spec: spec,
            payloadEdits: payloadEdits,
            legacyRelayMigrations: legacyRelayMigrations
        )) {
            await refreshDerivedState()
        }
        .hakoProductModal(
            isPresented: $addingChain,
            role: .form,
            macOSPanelRole: .page
        ) {
            ChainBuilder(proxies: editableInventory) { entry, exitNode in
                addChain(entry: entry, exit: exitNode)
            }
            .hakoModalPresentation(.form)
        }
        .hakoProductModal(item: $editing, role: .page) { proxy in
            ProxyDialerEditor(proxy: proxy, inventory: overlaidInventory, spec: spec) { dialerProxy in
                if proxy.kind == .payloadProxy {
                    guard let provider = proxy.provider else {
                        throw ProfileProviderDefinitionError.missingDefinition
                    }
                    var edits = payloadEdits.filter { $0.node != proxy.name }
                    let sourceRow = inventory.first { $0.name == proxy.name }
                    if dialerProxy != sourceRow?.dialerProxy {
                        edits.append(ProxyPayloadDialerEdit(
                            provider: provider,
                            node: proxy.name,
                            dialerProxy: dialerProxy
                        ))
                    }
                    var probe = overlaidInventory
                    if let index = probe.firstIndex(where: { $0.name == proxy.name }) {
                        probe[index] = ProxyIdentity(
                            name: proxy.name,
                            type: proxy.type,
                            dialerProxy: dialerProxy,
                            kind: .payloadProxy,
                            members: proxy.members,
                            provider: provider
                        )
                    }
                    try spec.validate(in: probe)
                    payloadEdits = edits
                } else {
                    var draft = spec
                    if dialerProxy == proxy.dialerProxy {
                        draft.removeAssignment(for: proxy.name)
                    } else {
                        draft.setDialerProxy(dialerProxy, for: proxy.name)
                    }
                    try draft.validate(in: overlaidInventory)
                    spec = draft
                }
            }
            .hakoModalPresentation(.page)
        }
        .hakoProductModal(item: $migrating, role: .form) { target in
            ProxyIdentityMigrationView(
                oldName: target.id,
                candidates: inventory.map(\.name)
            ) { newName in
                var draft = spec
                try draft.renameProxy(from: target.id, to: newName)
                try draft.validate(in: inventory)
                spec = draft
            } remove: {
                spec.removeAssignment(for: target.id)
            }
            .hakoModalPresentation(.form)
        }
         
         
        .alert(
            "Enable TCP-only migration?",
            isPresented: Binding(
                get: { confirmingRelay != nil },
                set: { if !$0 { confirmingRelay = nil } }
            ),
            presenting: confirmingRelay
        ) { relay in
            Button("Enable") { setConfirmed(relay) }
            Button("Cancel", role: .cancel) {}
        } message: { relay in
            Text(
                "Hako will use \(relay.pathDescription) as a TCP-only chain for this profile. UDP stays off and the original profile is not changed."
            )
        }
        .alert(
            "Remove TCP-only migration?",
            isPresented: Binding(
                get: { confirmingRelayRemoval != nil },
                set: { if !$0 { confirmingRelayRemoval = nil } }
            ),
            presenting: confirmingRelayRemoval
        ) { relay in
            Button("Remove", role: .destructive) {
                legacyRelayMigrations.removeAll {
                    $0.groupName == relay.groupName
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This profile will stop before connection until this legacy relay is reviewed again. The downloaded source stays unchanged.")
        }
    }

    private var orphanAssignments: [ProxyDialerAssignment] {
        let names = Set(inventory.map(\.name))
        return spec.assignments.filter { !names.contains($0.proxy) }
    }

     
     
    private var overlaidInventory: [ProxyIdentity] {
        ProfileProxyChainDerivedState.overlay(
            inventory: inventory,
            payloadEdits: payloadEdits
        )
    }

    private var editableInventory: [ProxyIdentity] {
        overlaidInventory.filter(\.supportsChainEditing)
    }

     
     
     
    @ViewBuilder
    private var chainRows: some View {
        if chainedProxies.isEmpty {
            HakoEmptyState(
                title: "No Proxy Chains",
                message: "A chain sends your traffic in through one proxy and out through another. The site you open sees the exit.",
                symbol: .link
            )
            .listRowSeparator(.hidden)
            .accessibilityIdentifier("proxy-chain.empty")
        } else {
            ForEach(chainedProxies) { proxy in
                HakoMacDeletableRow(onDelete: {
                    if let index = chainedProxies.firstIndex(
                        where: { $0.id == proxy.id }
                    ) {
                        removeChains(at: IndexSet(integer: index))
                    }
                }) {
                    chainRow(proxy)
                }
            }
            .onDelete(perform: removeChains)
        }
    }

     
     
     
     
    private func removeChains(at offsets: IndexSet) {
        let names = offsets.map { chainedProxies[$0].name }
        var draft = spec
        var edits = payloadEdits
        for name in names {
            if let proxy = chainedProxies.first(where: { $0.name == name }),
               proxy.kind == .payloadProxy, let provider = proxy.provider {
                edits.removeAll { $0.node == name }
                edits.append(ProxyPayloadDialerEdit(
                    provider: provider, node: name, dialerProxy: nil
                ))
            } else {
                let sourceDialerProxy = inventory.first {
                    $0.name == name
                }?.dialerProxy
                draft.clearDialerOverride(
                    for: name,
                    sourceDialerProxy: sourceDialerProxy
                )
            }
        }
        do {
            try draft.validate(in: overlaidInventory)
            spec = draft
            payloadEdits = edits
            validationMessage = ""
        } catch {
            validationMessage = error.localizedDescription
        }
    }

     
     
     
     
     
     
     
     
    @ViewBuilder
    private func chainRow(_ proxy: ProxyIdentity) -> some View {
        let hops: [String] = {
            guard let path = try? spec.orderedPath(
                startingAt: proxy.name, in: overlaidInventory
            ) else { return [] }
            return Array(path.reversed())
        }()
        if let error = pathError(for: proxy) {
            Button {
                editing = proxy
            } label: {
                HakoStatusMessage(
                    text: .copy(error.localizedDescription), kind: .error
                )
            }
            .buttonStyle(.borderless)
            .contentShape(Rectangle())
            .accessibilityIdentifier("proxy-chain.proxy.\(proxy.name)")
        } else {
            HStack(alignment: .center, spacing: HakoTheme.Spacing.compact) {
                Button {
                    editing = proxy
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(hops.enumerated()), id: \.offset) {
                            index, hop in
                            hopLine(
                                hop,
                                role: index == 0
                                    ? "Entry"
                                    : (index == hops.count - 1
                                        ? "Exit" : "Hop"),
                                isLast: index == hops.count - 1
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .contentShape(Rectangle())
                .accessibilityIdentifier("proxy-chain.proxy.\(proxy.name)")

                Button {
                    Task { await measureChain(hops) }
                } label: {
                    Group {
                        if measuring.isDisjoint(with: hops) {
                            Image(
                                systemName: HakoSymbol
                                    .boltHorizontalCircle.rawValue
                            )
                        } else {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .foregroundStyle(.secondary)
                    .frame(
                        width: 32,
                        height: HakoClientUI.HakoTheme.Control.minimumHitTarget
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .disabled(measure == nil || !measuring.isDisjoint(with: hops))
                .accessibilityLabel("Test Chain")
                .accessibilityIdentifier("proxy-chain.test.\(proxy.name)")
            }
        }
    }

     
     
    @ViewBuilder
    private func hopLine(
        _ name: String, role: String, isLast: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(hako: .copy(role))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .leading)
                 
                Text(hako: .verbatim(name))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                 
                Text(hako: .verbatim(
                    overlaidInventory.first { $0.name == name }?.type ?? ""
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                delayText(for: name)
            }
            if !isLast {
                 
                 
                 
                Image(systemName: HakoSymbol.arrowDown.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("proxy-chain.hop.\(name)")
    }

    @ViewBuilder
    private func delayText(for name: String) -> some View {
        if measuring.contains(name) {
            ProgressView().controlSize(.mini)
        } else if let delay = delays[name] {
             
             
             
             
            Text(hako: delay > 0
                ? .verbatim("\(delay) ms")
                : .copy(HakoProbeFailureCopy.neutralBadge))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(delay > 0 ? Color.secondary : Color.red)
        }
    }

     
     
    @ViewBuilder
    private var chainsHeader: some View {
                     
                     
                     
                     
                    HStack {
#if !os(macOS)
                         
                         
                        Text("Proxy Chains")
#endif
                        Spacer()
                        if !chainedProxies.isEmpty {
                            Button {
                                Task { await measureEveryChain() }
                            } label: {
                                Group {
                                    if measuring.isEmpty {
                                        Image(
                                            systemName: HakoSymbol
                                                .boltHorizontalCircle.rawValue
                                        )
                                    } else {
                                        ProgressView().controlSize(.small)
                                    }
                                }
                                 
                                 
                                 
                                 
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(
                                    width: HakoClientUI.HakoTheme.Control
                                        .minimumHitTarget,
                                    height: 28
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(measure == nil || !measuring.isEmpty)
                            .accessibilityLabel("Test All Chains")
                            .accessibilityHint(
                                measure == nil
                                    ? "Connect before testing latency"
                                    : "Measures every chain"
                            )
                            .accessibilityIdentifier("proxy-chain.test-all")
                        }
                    }
    }

     
     
     
    @MainActor
    private func measureEveryChain() async {
        for proxy in chainedProxies {
            let hops: [String] = {
                guard let path = try? spec.orderedPath(
                    startingAt: proxy.name, in: overlaidInventory
                ) else { return [] }
                return Array(path.reversed())
            }()
            await measureChain(hops)
        }
    }

     
     
     
     
     
     
    @MainActor
    private func measureChain(_ hops: [String]) async {
        guard let measure else { return }
        for hop in hops {
            measuring.insert(hop)
        }
        for hop in hops {
            let delay = await measure(hop)
            delays[hop] = delay ?? 0
            measuring.remove(hop)
        }
    }

     
     
     
    @ViewBuilder
    private var addChainRow: some View {
        HakoAddRow(Text(HakoCopy.key("Add Proxy Chain"))) {
            addingChain = true
        } touchLabel: {
            Label(
                HakoCopy.key("Add Proxy Chain"),
                systemImage: HakoSymbol.plus.name
            )
        }
        .disabled(editableInventory.count < 2)
        .accessibilityIdentifier("proxy-chain.add")
    }

     
     
     
     
    private func addChain(entry: String, exit exitNode: String) {
        guard let exit = overlaidInventory.first(where: {
            $0.name == exitNode
        }) else {
            validationMessage = "The selected exit is no longer available."
            addingChain = false
            return
        }

        if exit.kind == .payloadProxy {
            guard let provider = exit.provider else {
                validationMessage = ProfileProviderDefinitionError
                    .missingDefinition.localizedDescription
                addingChain = false
                return
            }
            var edits = payloadEdits.filter { $0.node != exitNode }
            let sourceRow = inventory.first { $0.name == exitNode }
            if entry != sourceRow?.dialerProxy {
                edits.append(
                    ProxyPayloadDialerEdit(
                        provider: provider,
                        node: exitNode,
                        dialerProxy: entry
                    )
                )
            }
            var probe = overlaidInventory
            if let index = probe.firstIndex(where: {
                $0.name == exitNode
            }) {
                probe[index] = ProxyIdentity(
                    name: exit.name,
                    type: exit.type,
                    dialerProxy: entry,
                    kind: exit.kind,
                    members: exit.members,
                    provider: provider
                )
            }
            do {
                try spec.validate(in: probe)
                payloadEdits = edits
                validationMessage = ""
                addingChain = false
            } catch {
                validationMessage = error.localizedDescription
                addingChain = false
            }
            return
        }

        var draft = spec
        draft.setDialerProxy(entry, for: exitNode)
        do {
            try draft.validate(in: overlaidInventory)
            spec = draft
            validationMessage = ""
            addingChain = false
        } catch {
            validationMessage = error.localizedDescription
            addingChain = false
        }
    }

     
     
    private var chainedProxies: [ProxyIdentity] {
        editableInventory.filter { proxy in
            let assigned = spec.assignment(for: proxy.name)?.dialerProxy
            let pending = payloadEdits.first { $0.node == proxy.name }
            if let pending { return pending.dialerProxy?.isEmpty == false }
            if let assigned { return !assigned.isEmpty }
            return proxy.dialerProxy?.isEmpty == false
        }
    }

     
     
    private var unchainedProxies: [ProxyIdentity] {
        let chained = Set(chainedProxies.map(\.name))
        return editableInventory.filter { !chained.contains($0.name) }
    }

    private func isConfirmed(_ relay: LegacyRelayAssessment) -> Bool {
        legacyRelayMigrations.contains {
            $0.groupName == relay.groupName && $0.members == relay.members
        }
    }

    private func setConfirmed(_ relay: LegacyRelayAssessment) {
        guard relay.blocker == nil else { return }
        legacyRelayMigrations.removeAll { $0.groupName == relay.groupName }
        legacyRelayMigrations.append(
            LegacyRelayMigration(
                groupName: relay.groupName,
                members: relay.members
            )
        )
    }

    private func pathDescription(for proxy: ProxyIdentity) -> HakoDisplayText {
        if let error = pathError(for: proxy) {
            return .copy(error.localizedDescription)
        }
        let path = (try? spec.orderedPath(startingAt: proxy.name, in: overlaidInventory)) ?? [proxy.name]
        if path.count == 1 {
             
            return .format("Direct connection · %@", [proxy.type])
        }
         
         
         
         
         
         
        return .verbatim(path.reversed().joined(separator: " → "))
    }

    private func pathError(for proxy: ProxyIdentity) -> Error? {
        do {
            _ = try spec.orderedPath(startingAt: proxy.name, in: overlaidInventory)
            return nil
        } catch {
            return error
        }
    }

    @MainActor
    private func refreshDerivedState() async {
        let key = ValidationKey(
            spec: spec,
            payloadEdits: payloadEdits,
            legacyRelayMigrations: legacyRelayMigrations
        )
        guard key != validatedKey else { return }
         
        do {
            try await Task.sleep(nanoseconds: 80_000_000)
        } catch {
            return
        }
        let yaml = baseYAML
        let error = baseError
        let inventory = inventory
        let began = DispatchTime.now().uptimeNanoseconds
        let derived = await Task.detached(priority: .userInitiated) {
            ProfileProxyChainDerivedState.evaluate(
                baseYAML: yaml,
                baseError: error,
                inventory: inventory,
                spec: key.spec,
                payloadEdits: key.payloadEdits,
                legacyRelayMigrations: key.legacyRelayMigrations
            )
        }.value
        guard !Task.isCancelled,
              key == ValidationKey(
                  spec: spec,
                  payloadEdits: payloadEdits,
                  legacyRelayMigrations: legacyRelayMigrations
              ) else { return }
        relayAssessments = derived.relayAssessments
        validationMessage = derived.validationMessage
        validatedKey = key
        HakoPerf.span(
            "chains.validate",
            milliseconds: Double(
                DispatchTime.now().uptimeNanoseconds - began
            ) / 1_000_000,
            detail: "relays=\(derived.relayAssessments.count)"
        )
    }

}

 
 
 
 
 
 
 
 
 
 
private struct ChainBuilder: View {
    let proxies: [ProxyIdentity]
    let create: (_ entry: String, _ exit: String) -> Void

     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss) private var modalDismiss
    @State private var entry = ""
    @State private var exitNode = ""

    private var isComplete: Bool {
        !entry.isEmpty && !exitNode.isEmpty && entry != exitNode
    }

     
     
     
     
     
     
    private var blockingRequirement: String? {
        guard !isComplete else { return nil }
        if entry.isEmpty { return "Choose the node this chain enters through." }
        if exitNode.isEmpty { return "Choose the node this chain leaves from." }
        return "A chain needs two different nodes."
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            Form {
                Section {
                    ChainEndRow(
                        label: "Entry",
                        selection: $entry,
                        proxies: proxies,
                        excluding: exitNode,
                        allowsNone: false
                    )
                    .accessibilityIdentifier("proxy-chain.builder.entry")
                } footer: {
                    Text("Your traffic goes here first.")
                }

                Section {
                    ChainEndRow(
                        label: "Exit",
                        selection: $exitNode,
                        proxies: proxies,
                        excluding: entry,
                        allowsNone: false
                    )
                    .accessibilityIdentifier("proxy-chain.builder.exit")
                } footer: {
                    Text("The site you open sees this one.")
                }

                 
                 
                 
                 
            }
            .hakoPageTitle("New Chain")
            .hakoDetailPageInsets()
            .hakoProductModalRoot(title: "New Chain")
#if !os(macOS)
             
             
             
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissPresentation() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { commit() }
                        .disabled(!isComplete)
                        .accessibilityIdentifier("proxy-chain.builder.add")
                }
            }
#endif
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if HakoPlatformLayout.modalEditorUsesGroupedForm {
                    HakoModalActionBar(
                        primaryTitle: "Add",
                        primaryDisabled: !isComplete,
                        primaryHint: blockingRequirement,
                        onPrimary: { commit() }
                    )
                }
            }
        }
        .hakoStackNavigationViewStyle()
        .accessibilityIdentifier("proxy-chain.builder")
        .hakoCapturesDismiss(dismiss)
    }

    private func commit() {
        create(entry, exitNode)
        dismissPresentation()
    }

    private func dismissPresentation() {
        (modalDismiss ?? { dismiss() })()
    }
}

 
 
 
 
 
 
 
 
private struct ChainEndRow: View {
    let label: String
    @Binding var selection: String
    let proxies: [ProxyIdentity]
     
     
    let excluding: String
    let allowsNone: Bool

    var body: some View {
        HakoRoutedViewLink {
            ChainEndPicker(
                title: label,
                selection: $selection,
                proxies: proxies.filter { $0.name != excluding },
                allowsNone: allowsNone
            )
            .accessibilityIdentifier("profile.override.chain-end")
        } label: {
            HStack {
                Text(hako: .copy(label))
                Spacer(minLength: HakoTheme.Spacing.compact)
                Text(hako: selection.isEmpty
                    ? .copy(allowsNone ? "No Entry" : "Choose")
                    : .verbatim(selection))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

private struct ChainEndPicker: View {
    let title: String
    @Binding var selection: String
    let proxies: [ProxyIdentity]
    let allowsNone: Bool

     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPopRoute) private var popRoute
    @State private var query = ""

    private var shown: [ProxyIdentity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return proxies }
        return proxies.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        Form {
            if allowsNone {
                Button {
                    selection = ""
                    dismissRoute()
                } label: {
                    HStack {
                        Text("No Entry")
                        Spacer()
                        if selection.isEmpty {
                            Image(systemName: HakoSymbol.checkmark.rawValue)
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .hakoSelectionRowStyle()
                .accessibilityIdentifier("proxy-chain.end.none")
            }
            ForEach(shown) { proxy in
                Button {
                    selection = proxy.name
                    dismissRoute()
                } label: {
                    HStack {
                         
                        Text(hako: .verbatim(proxy.name))
                            .lineLimit(2)
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        if selection == proxy.name {
                            Image(systemName: HakoSymbol.checkmark.rawValue)
                                .foregroundStyle(.tint)
                        }
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .hakoSelectionRowStyle()
                .accessibilityIdentifier("proxy-chain.end.\(proxy.name)")
            }
        }
        .hakoProductModalSearchable(text: $query)
        .hakoPageTitle(.copy(title))
        .hakoDetailPageInsets()
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
}

private struct ProxyDialerEditor: View {
    let proxy: ProxyIdentity
    let inventory: [ProxyIdentity]
    let spec: ProxyChainSpec
    let save: (String?) throws -> Void

     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss) private var productModalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @State private var selection: String
    @State private var error = ""
     
     
     
     
    private var openedWith: String {
        Self.effectiveDialer(proxy: proxy, spec: spec)
    }

    private static func effectiveDialer(
        proxy: ProxyIdentity,
        spec: ProxyChainSpec
    ) -> String {
        let effective: String?
        if let assignment = spec.assignment(for: proxy.name) {
            effective = assignment.dialerProxy
        } else {
            effective = proxy.dialerProxy
        }
        return effective ?? Self.noDialer
    }


    private static let noDialer = "__hako_no_dialer_proxy__"

    init(
        proxy: ProxyIdentity,
        inventory: [ProxyIdentity],
        spec: ProxyChainSpec,
        save: @escaping (String?) throws -> Void
    ) {
        self.proxy = proxy
        self.inventory = inventory
        self.spec = spec
        self.save = save
         
         
         
        _selection = State(
            initialValue: Self.effectiveDialer(proxy: proxy, spec: spec)
        )
    }

     
     
     
     
     
     
     
    var body: some View {
        HakoFeatureNavigationContainer {
            Form {
                Section {
                     
                     
                     
                     
                    ChainEndRow(
                        label: "Entry",
                        selection: Binding(
                            get: { selection == Self.noDialer ? "" : selection },
                            set: { selection = $0.isEmpty ? Self.noDialer : $0 }
                        ),
                        proxies: candidates,
                        excluding: proxy.name,
                        allowsNone: true
                    )
                    .accessibilityIdentifier("proxy-chain.dialer-picker")
                } footer: {
                    Text("Your traffic goes here first. Clearing it removes the chain.")
                }

                Section {
                     
                    keyValue("Exit", proxy.name)
                } footer: {
                    Text("The site you open sees this one.")
                }

                if case .failure(let pathError) = previewedPath {
                    Section {
                        HakoStatusMessage(
                            text: .copy(pathError.localizedDescription),
                            kind: .error
                        )
                    }
                }

                if !error.isEmpty {
                    HakoStatusMessage(text: .copy(error), kind: .error)
                }
            }
            .hakoPageTitle("Edit Chain")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !insideProductModal {
                        Button("Cancel") { dismissPresentation() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                         
                         
                        HakoSaveButton(.copy("Done"), isEnabled: selection != openedWith) { persist() }
                            .accessibilityIdentifier("proxy-chain.hop.save")
                    }
                }
            }
            .hakoProductModalRoot(title: "Edit Chain")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                     
                     
                     
                    HakoModalActionBar(
                        primaryTitle: "Done",
                        primaryDisabled: selection == openedWith,
                        onPrimary: persist
                    )
                }
            }
        }
        .hakoStackNavigationViewStyle()
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
    private var candidates: [ProxyIdentity] {
        inventory.filter { candidate in
            guard candidate.name != proxy.name,
                  candidate.kind != .payloadProxy else { return false }
            return !wouldCycle(through: candidate.name)
        }
    }

    private func wouldCycle(through hop: String) -> Bool {
        var probe = inventory
        var probeSpec = spec
        if proxy.kind == .payloadProxy {
            if let index = probe.firstIndex(where: { $0.name == proxy.name }) {
                probe[index] = ProxyIdentity(
                    name: proxy.name,
                    type: proxy.type,
                    dialerProxy: hop,
                    kind: .payloadProxy,
                    members: proxy.members,
                    provider: proxy.provider
                )
            }
        } else {
            probeSpec.setDialerProxy(hop, for: proxy.name)
        }
        do {
            try probeSpec.validate(in: probe)
            return false
        } catch {
            return true
        }
    }

    private var selectedDialerProxy: String? {
        selection == Self.noDialer ? nil : selection
    }

     
     
     
     
    private var previewedPath: Result<[ProxyIdentity], Error> {
        var probeSpec = spec
        var probe = inventory
        if proxy.kind == .payloadProxy {
            if let index = probe.firstIndex(where: { $0.name == proxy.name }) {
                probe[index] = ProxyIdentity(
                    name: proxy.name,
                    type: proxy.type,
                    dialerProxy: selectedDialerProxy,
                    kind: .payloadProxy,
                    members: proxy.members,
                    provider: proxy.provider
                )
            }
        } else if selectedDialerProxy == proxy.dialerProxy {
            probeSpec.removeAssignment(for: proxy.name)
        } else {
            probeSpec.setDialerProxy(selectedDialerProxy, for: proxy.name)
        }
        do {
             
             
             
             
            let names = try probeSpec
                .orderedPath(startingAt: proxy.name, in: probe)
                .reversed()
            return .success(names.map { name in
                probe.first { $0.name == name } ?? ProxyIdentity(
                    name: name, type: "unknown", dialerProxy: nil, kind: .builtin
                )
            })
        } catch {
            return .failure(error)
        }
    }

    private func chainHopCard(_ hop: ProxyIdentity) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(hop.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(hop.type)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, HakoTheme.Spacing.row)
        .padding(.vertical, HakoTheme.Spacing.compact)
        .background(
            RoundedRectangle(cornerRadius: HakoTheme.Radius.control, style: .continuous)
                .fill(HakoTheme.raisedFill)
        )
    }

    private func persist() {
        do {
            try save(selectedDialerProxy)
            dismissPresentation()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func dismissPresentation() {
        (productModalDismiss ?? { dismiss() })()
    }

     
     
     
     
     
    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(hako: .copy(key)).foregroundStyle(.secondary)
            Spacer(minLength: HakoTheme.Spacing.standard)
            Text(hako: .verbatim(value)).multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProxyIdentityMigrationView: View {
    let oldName: String
    let candidates: [String]
    let migrate: (String) throws -> Void
    let remove: () -> Void

     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss) private var productModalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @State private var selection: String
    @State private var error = ""

    init(
        oldName: String,
        candidates: [String],
        migrate: @escaping (String) throws -> Void,
        remove: @escaping () -> Void
    ) {
        self.oldName = oldName
        self.candidates = candidates
        self.migrate = migrate
        self.remove = remove
        _selection = State(initialValue: candidates.first ?? "")
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            Form {
                Section {
                    HakoStatusMessage(
                        text: .format("Proxy \"%@\" no longer exists in the generated configuration.", [oldName]),
                        kind: .warning
                    )
                }

                if !candidates.isEmpty {
                    Section("Migrate Identity") {
                        Picker("New proxy", selection: $selection) {
                            ForEach(candidates, id: \.self) { Text($0).tag($0) }
                        }
                        .accessibilityIdentifier(
                            "proxy-chain.orphan.destination"
                        )
                    }
                }

                Section {
                    Button("Remove Chain Override", role: .destructive) {
                        remove()
                        dismissPresentation()
                    }
                    .accessibilityIdentifier("proxy-chain.orphan.remove")
                } footer: {
                    Text("Removing the override does not delete or modify the downloaded source.")
                }

                if !error.isEmpty {
                    HakoStatusMessage(text: .copy(error), kind: .error)
                }
            }
            .hakoPageTitle("Migrate Proxy")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !insideProductModal {
                        Button("Cancel") { dismissPresentation() }
                            .accessibilityIdentifier("proxy-chain.orphan.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                        Button("Migrate") {
                            persistMigration()
                        }
                        .disabled(selection.isEmpty)
                        .accessibilityIdentifier("proxy-chain.orphan.migrate")
                    }
                }
            }
            .hakoProductModalRoot(title: "Migrate Proxy")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                    HakoModalActionBar(
                        primaryTitle: "Migrate",
                        primaryDisabled: selection.isEmpty,
                        onPrimary: persistMigration
                    )
                }
            }
        }
        .hakoStackNavigationViewStyle()
        .hakoCapturesDismiss(dismiss)
    }

    private func dismissPresentation() {
        (productModalDismiss ?? { dismiss() })()
    }

    private func persistMigration() {
        do {
            try migrate(selection)
            dismissPresentation()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
