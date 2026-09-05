import HakoClientUI
import SwiftUI

struct CustomProxyGroupsEditor: View {
    @Binding var groups: [CustomProxyGroup]
     
     
     
     
    var profileProxyNames: [String] = []
     
     
    var validationContext = CustomGroupValidationContext(
        nodeNames: [], groupNames: [], providerNames: [], siblingGroupNames: []
    )
     
     
     
     
    var onRename: ((String, String) -> Void)?
    @State private var editing: Target?
     
     
    @State private var rows = HakoIdentifiedRows()

    private struct Target: Identifiable {
        let id = UUID()
        let rowID: UUID?
        let group: CustomProxyGroup
    }

    var body: some View {
        Group {
#if os(macOS)
         
         
         
         
         
         
        Form {
            if groups.isEmpty {
                Section {
                HakoEmptyState(
                    title: "No Custom Groups",
                    message: "Add a group or return and use Quick Fill.",
                    symbol: .point3ConnectedTrianglepathDotted
                )
                .listRowSeparator(.hidden)
                }
            } else {
                Section {
            ForEach(rows.current(for: groups)) { row in
                let group = rows.index(of: row.id).map { groups[$0] }
                    ?? CustomProxyGroup(name: "")
                Button {
                    editing = Target(rowID: row.id, group: group)
                } label: {
                    HakoDestinationRow(
                         
                        title: .verbatim(group.name),
                        subtitle: group.validationError.map {
                            .copy($0.localizedDescription)
                        } ?? .format(
                            "%@ · %@ proxies · %@ providers",
                            [
                                group.type,
                                String(group.proxies.count),
                                String(group.providers.count),
                            ]
                        ),
                        symbol: .point3ConnectedTrianglepathDotted,
                        tint: group.validationError == nil ? .blue : .red
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("custom.proxy-group.row.\(group.name)")
            }
            .onDelete { rows.removeOffsets($0, from: &groups) }
            .onMove { rows.move(fromOffsets: $0, toOffset: $1, in: &groups) }
            .onAppear { rows.resync(count: groups.count) }
            .onChange(of: groups.count) { rows.resync(count: $0) }
                }
            }
            Section {
                HakoAddRow(Text(HakoCopy.key("Add Group"))) {
                    editing = Target(rowID: nil, group: CustomProxyGroup(name: ""))
                }
                .accessibilityIdentifier("custom.proxy-group.row.add")
            }
        }
#else
        List {
            if groups.isEmpty {
                HakoEmptyState(
                    title: "No Custom Groups",
                    message: "Add a group or return and use Quick Fill.",
                    symbol: .point3ConnectedTrianglepathDotted
                )
                .listRowSeparator(.hidden)
            }
            ForEach(rows.current(for: groups)) { row in
                let group = rows.index(of: row.id).map { groups[$0] }
                    ?? CustomProxyGroup(name: "")
                Button {
                    editing = Target(rowID: row.id, group: group)
                } label: {
                    HakoDestinationRow(
                         
                        title: .verbatim(group.name),
                        subtitle: group.validationError.map {
                            .copy($0.localizedDescription)
                        } ?? .format(
                            "%@ · %@ proxies · %@ providers",
                            [
                                group.type,
                                String(group.proxies.count),
                                String(group.providers.count),
                            ]
                        ),
                        symbol: .point3ConnectedTrianglepathDotted,
                        tint: group.validationError == nil ? .blue : .red
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("custom.proxy-group.row.\(group.name)")
            }
            .onDelete { rows.removeOffsets($0, from: &groups) }
            .onMove { rows.move(fromOffsets: $0, toOffset: $1, in: &groups) }
            .onAppear { rows.resync(count: groups.count) }
            .onChange(of: groups.count) { rows.resync(count: $0) }
        }
        .hakoInsetGroupedListStyle()
#endif
        }
        .hakoPageTitle("Proxy Groups")
        .hakoDetailPageInsets()
        .hakoToolbarUnlessInPanel {
            ToolbarItemGroup(placement: .hakoNavigationTrailing) {
                HakoEditButton()
            }
        }
        .hakoProductModalChild(title: "Proxy Groups")
        .hakoProductModal(item: $editing, role: .page) { target in
            CustomProxyGroupEditor(
                group: target.group,
                existingNames: Set(groups.enumerated().compactMap {
                    $0.offset == target.rowID.flatMap(rows.index(of:))
                        ? nil : $0.element.name
                }),
                profileProxyNames: profileProxyNames,
                validationContext: validationContext
            ) { group in
                if let id = target.rowID,
                   let index = rows.index(of: id) {
                    let previousName = groups[index].name
                    if previousName != group.name {
                        onRename?(previousName, group.name)
                    }
                    rows.update(id, in: &groups, to: group)
                } else {
                    rows.append(group, to: &groups)
                }
            }
            .hakoModalPresentation(.page)
        }
    }
}
private struct CustomProxyGroupEditor: View {
    let save: (CustomProxyGroup) -> Void
    let existingNames: Set<String>
    let validationContext: CustomGroupValidationContext
    let profileProxyNames: [String]

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss) private var productModalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @State private var group: CustomProxyGroup
    @State private var interval = ""
    @State private var timeout = ""
    @State private var maxFailedTimes = ""
    @State private var tolerance = ""
    @State private var error = ""
    @State private var iconHistory = ProxyGroupIconHistory.load()

    init(
        group: CustomProxyGroup,
        existingNames: Set<String>,
        profileProxyNames: [String] = [],
        validationContext: CustomGroupValidationContext =
            CustomGroupValidationContext(
                nodeNames: [], groupNames: [],
                providerNames: [], siblingGroupNames: []
            ),
        save: @escaping (CustomProxyGroup) -> Void
    ) {
        self.existingNames = existingNames
        self.validationContext = validationContext
        self.profileProxyNames = profileProxyNames
        self.save = save
        _group = State(initialValue: group)
        _interval = State(initialValue: group.interval.map(String.init) ?? "")
        _timeout = State(initialValue: group.timeout.map(String.init) ?? "")
        _maxFailedTimes = State(initialValue: group.maxFailedTimes.map(String.init) ?? "")
        _tolerance = State(initialValue: group.tolerance.map(String.init) ?? "")
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            Form {
                Section("Group") {
                    TextField("Name", text: $group.name)
                        .accessibilityIdentifier("custom.proxy-group.name")
                    Picker("Type", selection: $group.type) {
                        ForEach(CustomProxyGroup.types, id: \.self) { type in
                            Text(
                                ProxyGroupConfigurationCatalog.specification(for: type)?.displayName
                                    ?? type
                            )
                            .tag(type)
                        }
                    }
                    .accessibilityIdentifier("custom.proxy-group.type")
                }

                if let validationError = group.validationError {
                    Section {
                        HakoStatusMessage(text: .copy(validationError.localizedDescription), kind: .error)
                    } footer: {
                        Text("Choose a supported group type. Proxy chaining is configured with dialer-proxy on each proxy.")
                    }
                }

                Section("Proxies") {
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    Toggle("Include all proxies and providers", isOn: optionalBoolBinding(\.includeAll))
                        .accessibilityIdentifier("custom.proxy-group.include-all")
                    Toggle("Include all proxies", isOn: $group.includeAllProxies)
                        .accessibilityIdentifier("custom.proxy-group.include-all-proxies")
                    StringListEditor(
                        items: $group.proxies,
                        itemTitle: "Proxy",
                        placeholder: "Proxy or group name",
                        identifier: "custom.proxy-group.proxies"
                    )
                    memberCandidateMenu
                }

                Section("Proxy Providers") {
                    Toggle("Include all providers", isOn: $group.includeAllProviders)
                        .accessibilityIdentifier("custom.proxy-group.include-all-providers")
                    StringListEditor(
                        items: $group.providers,
                        itemTitle: "Provider",
                        placeholder: "Provider name",
                        identifier: "custom.proxy-group.providers"
                    )
                }

                Section {
                    switch group.type {
                    case "select":
                         
                         
                         
                        TextField("Default route", text: optionalBinding(\.defaultSelected))
                            .accessibilityIdentifier("custom.proxy-group.default-selected")
                    case "url-test":
                        TextField("Allowed latency difference (ms)", text: $tolerance)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("custom.proxy-group.tolerance")
                    case "load-balance":
                        Picker("Distribution strategy", selection: optionalBinding(\.strategy)) {
                            Text("Default (consistent hashing)").tag("")
                            Text("Consistent hashing").tag("consistent-hashing")
                            Text("Round robin").tag("round-robin")
                            Text("Sticky sessions").tag("sticky-sessions")
                        }
                        .accessibilityIdentifier("custom.proxy-group.strategy")
                    default:
                        Text("Routes are tried in the order shown above.")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Selection")
                }

                Section("Health Check") {
                    TextField("Test URL", text: optionalBinding(\.url))
                                                .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("custom.proxy-group.url")
                    TextField("Interval (seconds)", text: $interval)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("custom.proxy-group.interval")
                    TextField("Timeout (ms)", text: $timeout)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("custom.proxy-group.timeout")
                    TextField("Maximum failed times", text: $maxFailedTimes)
                        .keyboardType(.numberPad)
                        .accessibilityIdentifier("custom.proxy-group.max-failed-times")
                    TextField("Expected status", text: optionalBinding(\.expectedStatus))
                        .accessibilityIdentifier("custom.proxy-group.expected-status")
                    Toggle("Test when used", isOn: $group.lazy)
                        .accessibilityIdentifier("custom.proxy-group.lazy")
                }

                Section("Filters") {
                    TextField("Include regex", text: optionalBinding(\.filter))
                        .accessibilityIdentifier("custom.proxy-group.filter")
                    TextField("Exclude regex", text: optionalBinding(\.excludeFilter))
                        .accessibilityIdentifier("custom.proxy-group.exclude-filter")
                    TextField("Exclude types", text: optionalBinding(\.excludeType))
                        .accessibilityIdentifier("custom.proxy-group.exclude-type")
                    TextField("Use if no route remains", text: optionalBinding(\.emptyFallback))
                        .accessibilityIdentifier("custom.proxy-group.empty-fallback")
                }

                Section("Options") {
                    Toggle("Disable UDP", isOn: $group.disableUDP)
                        .accessibilityIdentifier("custom.proxy-group.disable-udp")
                    Toggle("Hide from list", isOn: $group.hidden)
                        .accessibilityIdentifier("custom.proxy-group.hidden")
                }

                Section {
                    TextField("emoji, a name, or https URL", text: optionalBinding(\.icon))
                                                .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("custom.proxy-group.icon")
                    iconEcho
                    ForEach(iconHistory, id: \.self) { icon in
                        Button(icon) { group.icon = icon }
                            .font(.caption)
                    }
                } header: {
                    Text("Icon")
                } footer: {
                    Text("Recent icons are stored locally for reuse. An emoji or a bundled name is drawn here; a URL is kept with the group but never loaded, so a subscription cannot learn when you open the app.")
                }

                if !error.isEmpty {
                    HakoStatusMessage(text: .copy(error), kind: .error)
                }
            }
            .hakoPageTitle("Proxy Group")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !insideProductModal {
                        Button("Cancel") { dismissPresentation() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                         
                         
                        HakoSaveButton(.copy("Done"), isEnabled: isNameable) { persist() }
                            .accessibilityIdentifier("custom.proxy-group.save")
                    }
                }
            }
            .hakoProductModalRoot(title: "Proxy Group")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                    HakoModalActionBar(
                        primaryTitle: "Done",
                    primaryDisabled: !isNameable,
                         
                         
                         
                         
                        primaryHint: isNameable ? nil : "Give this group a name.",
                        onPrimary: persist
                    )
                }
            }
        }
        .hakoStackNavigationViewStyle()
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
     
     
     
     
    @ViewBuilder
    private var iconEcho: some View {
        switch HakoProxyGroupIconKind.of(group.icon) {
        case .emoji(let value):
            echoRow("Shows as") { Text(verbatim: value) }
        case .symbol(let symbol):
            echoRow("Shows as") { Image(systemName: symbol.name) }
        case .remote(let host):
            echoRow("Image on") { Text(verbatim: host) }
        case .unrecognized:
            Text("Saved with the group, but nothing draws it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("custom.proxy-group.icon.echo")
        case .none:
            EmptyView()
        }
    }

     
     
     
     
     
     
    @ViewBuilder
    private var memberCandidateMenu: some View {
        let candidates = GroupMemberCandidates.offer(
            proxies: profileProxyNames,
            groups: Array(existingNames),
            excluding: group.proxies,
            selfName: group.name
        )
        if !candidates.isEmpty {
            Menu {
                ForEach(candidates, id: \.self) { name in
                    Button(name) { group.proxies.append(name) }
                }
            } label: {
                Label {
                    Text(hako: "Add from this profile")
                } icon: {
                    Image(systemName: HakoSymbol.plus.name)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityIdentifier("custom.proxy-group.add-member")
        }
    }

    private func echoRow<Value: View>(
        _ label: String,
        @ViewBuilder value: () -> Value
    ) -> some View {
        HStack {
            Text(hako: .copy(label))
            Spacer(minLength: HakoTheme.Spacing.compact)
            value().foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("custom.proxy-group.icon.echo")
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<CustomProxyGroup, String?>) -> Binding<String> {
        Binding(
            get: { group[keyPath: keyPath] ?? "" },
            set: { group[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func optionalBoolBinding(
        _ keyPath: WritableKeyPath<CustomProxyGroup, Bool?>
    ) -> Binding<Bool> {
        Binding(
            get: { group[keyPath: keyPath] ?? false },
            set: { group[keyPath: keyPath] = $0 }
        )
    }

     
     
     
     
     
     
     
     
     
    private var isNameable: Bool {
        CustomGroupSavePolicy.normalizedName(group.name) != nil
    }

    private func persist() {
         
         
         
         
         
        guard let name = CustomGroupSavePolicy.normalizedName(group.name) else {
            error = "Group name is required."
            return
        }
        guard !existingNames.contains(name) else { error = "Group names must be unique."; return }
        group.name = name
        do {
             
             
             
             
             
            var context = validationContext
            context.siblingGroupNames.formUnion(existingNames)
            if let error = group.validationError(context: context) {
                throw error
            }
        } catch {
            self.error = error.localizedDescription
            return
        }
         
         
         
         
        if let icon = group.icon, !icon.isEmpty {
            ProxyGroupIconHistory.record(icon)
        }
        group.interval = Int(interval)
        group.timeout = Int(timeout)
        group.maxFailedTimes = Int(maxFailedTimes)
        group.tolerance = Int(tolerance)
        save(group)
        dismissPresentation()
    }

    private func dismissPresentation() {
        (productModalDismiss ?? { dismiss() })()
    }
}

struct CustomRulesEditor: View {
    @Binding var rules: [String]
     
     
     
    var options: RulePolicyOptions = .empty
    @State private var editing: Target?
     
    @State private var rows = HakoIdentifiedRows()

    private struct Target: Identifiable {
        let id = UUID()
        let rowID: UUID?
        let raw: String
    }

    var body: some View {
        Group {
#if os(macOS)
         
         
         
         
         
         
        Form {
            if rules.isEmpty {
                Section {
                HakoEmptyState(
                    title: "No Custom Rules",
                    message: "Add a rule or return and use Quick Fill.",
                    symbol: .listBulletRectangle
                )
                .listRowSeparator(.hidden)
                }
            } else {
                Section {
            ForEach(rows.current(for: rules)) { row in
                let rule = rows.index(of: row.id).map { rules[$0] } ?? ""
                Button {
                    editing = Target(rowID: row.id, raw: rule)
                } label: {
                    Text(rule).font(.caption.monospaced()).foregroundStyle(.primary)
                }
                .accessibilityIdentifier("custom.rules.row.\(row.index)")
            }
            .onDelete { rows.removeOffsets($0, from: &rules) }
            .onMove { rows.move(fromOffsets: $0, toOffset: $1, in: &rules) }
            .onAppear { rows.resync(count: rules.count) }
            .onChange(of: rules.count) { rows.resync(count: $0) }
                }
            }
            Section {
                HakoAddRow(Text(HakoCopy.key("Add Rule"))) {
                    editing = Target(rowID: nil, raw: "")
                }
                .accessibilityIdentifier("custom.rules.row.add")
            }
        }
#else
        List {
            if rules.isEmpty {
                HakoEmptyState(
                    title: "No Custom Rules",
                    message: "Add a rule or return and use Quick Fill.",
                    symbol: .listBulletRectangle
                )
                .listRowSeparator(.hidden)
            }
            ForEach(rows.current(for: rules)) { row in
                let rule = rows.index(of: row.id).map { rules[$0] } ?? ""
                Button {
                    editing = Target(rowID: row.id, raw: rule)
                } label: {
                    Text(rule).font(.caption.monospaced()).foregroundStyle(.primary)
                }
                .accessibilityIdentifier("custom.rules.row.\(row.index)")
            }
            .onDelete { rows.removeOffsets($0, from: &rules) }
            .onMove { rows.move(fromOffsets: $0, toOffset: $1, in: &rules) }
            .onAppear { rows.resync(count: rules.count) }
            .onChange(of: rules.count) { rows.resync(count: $0) }
        }
        .hakoInsetGroupedListStyle()
#endif
        }
        .hakoPageTitle("Rules")
        .hakoDetailPageInsets()
        .hakoToolbarUnlessInPanel {
            ToolbarItemGroup(placement: .hakoNavigationTrailing) {
                HakoEditButton()
            }
        }
        .hakoProductModalChild(title: "Rules")
        .hakoProductModal(item: $editing, role: .form) { target in
            RuleBuilderAdapter(raw: target.raw, options: options) { rule in
                if let id = target.rowID {
                    rows.update(id, in: &rules, to: rule)
                } else if !rules.contains(rule) {
                    rows.append(rule, to: &rules)
                }
            }
            .hakoModalPresentation(.page)
        }
    }
}

private enum ProxyGroupIconHistory {
    private static let key = "proxy-group.icon-history"

    private static var defaults: UserDefaults {
        ScriptLibrary.appGroupDefaults
    }

    static func load() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    static func record(_ value: String) {
        var values = load().filter { $0 != value }
        values.insert(value, at: 0)
        defaults.set(Array(values.prefix(20)), forKey: key)
    }
}
