import HakoClientUI
import SwiftUI

 
 
struct OnDemandConfigView: View {
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @ObservedObject var vpn: VPNController
    @State private var draft = OnDemandConfiguration.disabled
    @State private var error = ""
    @State private var isSaving = false
    @State private var showingAddRule = false
     
     
     
    @State private var ruleDoor: HakoDoorPayload?
    @State private var hasLoaded = false
    let usesRegularDetailLayout: Bool

    var body: some View {
        shadowrocketBody
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
     
     
     

    private var shadowrocketBody: some View {
        HakoMacSettingsFormContainer {
            Section {
                Toggle("Always On", isOn: setting(\.alwaysOn))
                    .accessibilityIdentifier("onDemand.alwaysOn")
            } header: {
                Text("Always On")
            } footer: {
                Text("If YES, the VPN connection will be always on. The default is NO")
            }

            Section {
                Toggle("On Demand", isOn: setting(\.enabled))
                    .accessibilityIdentifier("onDemand.enabled")
            } header: {
                Text("On Demand")
            } footer: {
                Text("Toggles VPN On Demand.")
            }

            Section {
                Toggle("Disconnect on Sleep", isOn: setting(\.disconnectOnSleep))
                    .accessibilityIdentifier("onDemand.disconnectOnSleep")
                Toggle("Show Disconnect Message", isOn: setting(\.showDisconnectMessage))
                    .accessibilityIdentifier("onDemand.showDisconnectMessage")
            } header: {
                Text("Other")
            } footer: {
                Text("If YES, the VPN connection will be disconnected when the device goes to sleep. The default is NO")
            }

            Section {
                ForEach($draft.rules) { $rule in
                    HakoPayloadDoorLink(
                        id: rule.id.uuidString,
                        title: rule.action.title,
                        selection: $ruleDoor
                    ) {
                        HakoLazyView {
                            OnDemandRuleEditor(
                                rule: rule,
                                usesRegularDetailLayout: usesRegularDetailLayout
                            ) { edited in
                                rule = edited
                                commit(draft)
                            }
                        }
                        .hakoRegularDetailPageLayout(enabled: usesRegularDetailLayout)
                    } label: {
                        HStack {
                            Text(rule.action.title)
                            Spacer()
                            Text(rule.interface.title)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                        macRuleControls(for: rule.id)
                    }
                }
                .onDelete { offsets in
                    var next = draft
                    next.rules.remove(atOffsets: offsets)
                    commit(next)
                }
                .onMove { source, destination in
                    var next = draft
                    next.rules.move(fromOffsets: source, toOffset: destination)
                    commit(next)
                }
            } header: {
                HStack {
                    Text("On Demand Rules")
                    Spacer()
                    Button(action: appendRule) {
                        Label("Add Rule", systemImage: HakoSymbol.plus.name)
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityIdentifier("onDemand.rules.add")
                }
            }

            if !error.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(error), kind: .error)
                        .accessibilityIdentifier("onDemand.error")
                }
            }
        }
        .hakoDoorPresenter(payload: $ruleDoor)
        .hakoPageTitle("On Demand")
        .onAppear {
            guard !hasLoaded else { return }
            draft = OnDemandSettings.configuration()
            hasLoaded = true
        }
        .hakoToolbarUnlessInPanel {
            ToolbarItemGroup(placement: .hakoNavigationTrailing) {
                HakoEditButton()
                Button(action: appendRule) {
                    Label("Add Rule", systemImage: HakoSymbol.plus.name)
                }
                .accessibilityIdentifier("onDemand.addRule")
            }
        }
    }

    private func setting(_ keyPath: WritableKeyPath<OnDemandConfiguration, Bool>) -> Binding<Bool> {
        Binding(
            get: { draft[keyPath: keyPath] },
            set: { value in
                var next = draft
                next[keyPath: keyPath] = value
                if keyPath == \.showDisconnectMessage, value {
                    VPNDisconnectNotice.requestAuthorization()
                }
                commit(next)
            }
        )
    }

     
     
     
    private func macRuleControls(for id: UUID) -> some View {
        let index = draft.rules.firstIndex { $0.id == id }
        let isFirst = index == draft.rules.startIndex
        let isLast = index.map { $0 == draft.rules.count - 1 } ?? true
        return HStack(spacing: 6) {
            Button {
                var next = draft
                OnDemandRuleSurgery.move(&next.rules, id: id, offset: -1)
                commit(next)
            } label: {
                HakoSymbolImage(symbol: .chevronUp)
            }
            .disabled(isFirst)
            .accessibilityIdentifier("onDemand.rule.moveUp")
            Button {
                var next = draft
                OnDemandRuleSurgery.move(&next.rules, id: id, offset: 1)
                commit(next)
            } label: {
                HakoSymbolImage(symbol: .chevronDown)
            }
            .disabled(isLast)
            .accessibilityIdentifier("onDemand.rule.moveDown")
            Button(role: .destructive) {
                var next = draft
                OnDemandRuleSurgery.remove(&next.rules, id: id)
                commit(next)
            } label: {
                HakoSymbolImage(symbol: .minusCircle)
            }
            .accessibilityIdentifier("onDemand.rule.remove")
        }
        .buttonStyle(.plain)
    }

    private func appendRule() {
        var next = draft
        next.rules.append(OnDemandRuleSpec(action: .connect))
        commit(next)
    }

     
     
     
     
    private func commit(_ next: OnDemandConfiguration) {
        let previous = draft
        draft = next
        error = ""
        do {
            try OnDemandSettings.save(next)
        } catch {
            self.error = error.localizedDescription
            draft = previous
            return
        }
        isSaving = true
        Task {
            switch await vpn.applyOnDemandSettingsReportingOutcome() {
            case .applied:
                break
            case .refused(let reason):
                try? OnDemandSettings.save(previous)
                draft = previous
                self.error = reason
            case .indeterminate(let reason):
                self.error = reason
            }
            isSaving = false
        }
    }

}

private struct OnDemandRuleEditor: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
     
     
    private let openedWith: OnDemandRuleSpec
    @State private var draft: OnDemandRuleSpec
    @State private var error = ""
    @State private var showingAddConnectionRule = false
    let usesRegularDetailLayout: Bool
    let onSave: (OnDemandRuleSpec) -> Void

    init(
        rule: OnDemandRuleSpec,
        usesRegularDetailLayout: Bool,
        onSave: @escaping (OnDemandRuleSpec) -> Void
    ) {
        _draft = State(initialValue: rule)
        openedWith = rule
        self.usesRegularDetailLayout = usesRegularDetailLayout
        self.onSave = onSave
    }

    var body: some View {
        HakoMacSettingsFormContainer {
            Section("Action") {
                Picker("Action", selection: $draft.action) {
                    ForEach(OnDemandRuleAction.allCases) { action in
                        Text(hako: .copy(action.title)).tag(action)
                    }
                }
                .accessibilityIdentifier("onDemand.rule.action")
                Picker("Interface", selection: $draft.interface) {
                    ForEach(OnDemandInterface.platformCases) { interface in
                        Text(hako: .copy(interface.title)).tag(interface)
                    }
                }
                .accessibilityIdentifier("onDemand.rule.interface")
            }

            Section {
                StringListEditor(
                    items: $draft.ssids,
                    itemTitle: "SSID Match",
                    placeholder: "Wi-Fi SSID"
                )
                .accessibilityIdentifier("onDemand.rule.ssids")
            } header: {
                Text("SSID Match")
            } footer: {
                Text("Leave empty to ignore SSID. Use Connect for inclusion or Disconnect for exclusion.")
            }

            Section("DNS Search Domain Match") {
                StringListEditor(
                    items: $draft.dnsSearchDomains,
                    itemTitle: "Domain",
                    placeholder: "example.com"
                )
                .accessibilityIdentifier("onDemand.rule.dnsSearchDomains")
            }

            Section {
                StringListEditor(
                    items: $draft.dnsServerAddresses,
                    itemTitle: "Address",
                    placeholder: "1.1.1.1"
                )
                .accessibilityIdentifier("onDemand.rule.dnsServerAddresses")
            } header: {
                Text("DNS Server Address Match")
            } footer: {
                Text("IP addresses only.")
            }

            Section {
                hakoPromptField(
                    "https://example.com/health",
                    text: $draft.probeURL
                )
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .caption.monospaced())
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("onDemand.rule.probeURL")
            } header: {
                Text("Probe URL")
            } footer: {
                Text("Optional. Clash accepts credential-free HTTPS probes only; Apple requires HTTP 200 for a match.")
            }

            if draft.action == .evaluate {
                Section {
                    ForEach($draft.connectionRules) { $rule in
                        HakoRoutedViewLink {
                            HakoLazyView {
                                OnDemandEvaluateRuleEditor(rule: rule) { rule = $0 }
                            }
                                .hakoRegularDetailPageLayout(enabled: usesRegularDetailLayout)
                        } label: {
                            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                                Text(rule.action.title)
                                Text(rule.matchDomains.isEmpty
                                     ? "Add match domains"
                                     : rule.matchDomains.joined(separator: ", "))
                                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete { draft.connectionRules.remove(atOffsets: $0) }
                    .onMove { draft.connectionRules.move(fromOffsets: $0, toOffset: $1) }

                    HakoAddRow(Text("Add Connection Rule")) {
                        showingAddConnectionRule = true
                    } touchLabel: {
                        Label("Add Connection Rule", systemImage: HakoSymbol.plus.name)
                    }
                    .accessibilityIdentifier("onDemand.rule.addConnectionRule")
                } header: {
                    Text("Connection Rules")
                } footer: {
                    Text("Destination domains are evaluated in this order after the outer rule matches.")
                }
            }

            if !error.isEmpty {
                Section { HakoStatusMessage(text: .copy(error), kind: .error) }
            }
        }
        
         
         
         
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: draft != openedWith,
            save: { completion in
                save()
                completion(true)
            },
            discard: { draft = openedWith }
        )
        .hakoPageTitle("On Demand Rule")
        .confirmationDialog("Add Connection Rule", isPresented: $showingAddConnectionRule) {
            ForEach(OnDemandEvaluateAction.allCases) { action in
                     
                     
                     
                     
                     
                     
                Button {
                    draft.connectionRules.append(OnDemandEvaluateRuleSpec(action: action))
                } label: {
                    Text(hako: .copy(action.title))
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .toolbar {
            ToolbarItemGroup(placement: .hakoNavigationTrailing) {
                if draft.action == .evaluate { HakoEditButton() }
                 
                 
                 
                if !insideProductModal {
                    HakoSaveButton { save() }
                        .accessibilityIdentifier("onDemand.rule.save")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                HakoModalActionBar(primaryTitle: "Save",
                    onPrimary: save)
            }
        }
         
         
         
         
        .hakoPageProbe("on-demand-rule")
        .hakoCapturesDismiss(dismiss)
    }

    private func save() {
        do {
            _ = try OnDemandSettings.rules(configuration: OnDemandConfiguration(
                enabled: true,
                rules: [draft]
            ))
            onSave(draft.normalized())
            closePage()
        } catch {
            self.error = error.localizedDescription
        }
    }

     
    private func closePage() {
        if let productModalDismiss {
            productModalDismiss()
        } else {
            dismiss()
        }
    }
}

private struct OnDemandEvaluateRuleEditor: View {
    @Environment(\.hakoPopRoute) private var popRoute
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
     
     
    private let openedWith: OnDemandEvaluateRuleSpec
    @State private var draft: OnDemandEvaluateRuleSpec
    @State private var error = ""
    let onSave: (OnDemandEvaluateRuleSpec) -> Void

    init(rule: OnDemandEvaluateRuleSpec, onSave: @escaping (OnDemandEvaluateRuleSpec) -> Void) {
        _draft = State(initialValue: rule)
        openedWith = rule
        self.onSave = onSave
    }

    var body: some View {
        HakoMacSettingsFormContainer {
            Section("Action") {
                Picker("Action", selection: $draft.action) {
                    ForEach(OnDemandEvaluateAction.allCases) { action in
                        Text(hako: .copy(action.title)).tag(action)
                    }
                }
                .accessibilityIdentifier("onDemand.evaluate.action")
            }
            Section {
                StringListEditor(
                    items: $draft.matchDomains,
                    itemTitle: "Domain",
                    placeholder: "example.com"
                )
                .accessibilityIdentifier("onDemand.evaluate.matchDomains")
            } header: {
                Text("Match Domains")
            } footer: {
                Text("Required. Destination host suffixes matched by this connection rule.")
            }
            Section {
                StringListEditor(
                    items: $draft.dnsServers,
                    itemTitle: "Address",
                    placeholder: "1.1.1.1"
                )
                .accessibilityIdentifier("onDemand.evaluate.dnsServers")
            } header: {
                Text("Evaluation DNS Servers")
            } footer: {
                Text("Optional IP addresses used by Connect If Needed while checking direct reachability.")
            }
            Section {
                hakoPromptField(
                    "https://example.com/health",
                    text: $draft.probeURL
                )
                .accessibilityIdentifier("onDemand.evaluate.probeURL")
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .caption.monospaced())
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Evaluation Probe URL")
            } footer: {
                Text("Optional credential-free HTTPS URL used by Connect If Needed.")
            }
            if !error.isEmpty {
                Section { HakoStatusMessage(text: .copy(error), kind: .error) }
            }
        }
        
         
         
         
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: draft != openedWith,
            save: { completion in
                save()
                completion(true)
            },
            discard: { draft = openedWith }
        )
        .hakoPageTitle("Connection Rule")
        .toolbar {
            ToolbarItem(placement: .hakoNavigationTrailing) {
                 
                 
                 
                if !insideProductModal {
                    HakoSaveButton { save() }
                        .accessibilityIdentifier("onDemand.connectionRule.save")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                HakoModalActionBar(primaryTitle: "Save",
                    onPrimary: save)
            }
        }
         
         
         
         
        .hakoPageProbe("on-demand-connection-rule")
        .hakoCapturesDismiss(dismiss)
    }

    private func save() {
        let outer = OnDemandRuleSpec(action: .evaluate, connectionRules: [draft])
        do {
            _ = try OnDemandSettings.rules(configuration: OnDemandConfiguration(
                enabled: true,
                rules: [outer]
            ))
            onSave(draft.normalized())
            closePage()
        } catch {
            self.error = error.localizedDescription
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func closePage() {
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
