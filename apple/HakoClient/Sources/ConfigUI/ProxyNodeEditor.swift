import Foundation
import HakoClientUI
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

 
 
 
 
@MainActor
final class ProxyNodeEditorDraft: ObservableObject {
    let originalJSON: String
    private(set) var mapping: [String: Any] {
        didSet { cachedEditedJSON = nil }
    }

     
     
     
     
     
     
     
     
     
    private var cachedEditedJSON: String?

    init(configurationJSON: String, fallbackName: String, fallbackType: String) {
        let decoded = ProxyProtocolCatalog.mapping(from: configurationJSON) ?? [:]
        var value = decoded
        if value["name"] == nil { value["name"] = fallbackName }
        if value["type"] == nil { value["type"] = fallbackType }
        mapping = value
        originalJSON = Self.json(value)
    }

    var typeID: String { string("type") }
     
     
     
     
     
     
     
    var editedJSON: String {
        if let cachedEditedJSON { return cachedEditedJSON }
        let value = Self.json(mapping)
        cachedEditedJSON = value
        return value
    }

    var isDirty: Bool { editedJSON != originalJSON }

     
     
     
     
     
     
     
     
    func firstMissingRequiredFieldKey() -> String? {
        for field in ProxyProtocolEditorSchema.fields(for: typeID)
        where field.required && field.key != "type" {
            if field.key == "port", typeID == "hysteria2",
               !string("ports").trimmingCharacters(
                    in: .whitespacesAndNewlines
               ).isEmpty {
                continue
            }
            if string(field.key).trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty {
                return field.key
            }
        }
        return nil
    }

     
     
     
     
     
     
    func detachedCopy() -> ProxyNodeEditorDraft {
        ProxyNodeEditorDraft(
            configurationJSON: editedJSON,
            fallbackName: string("name"),
            fallbackType: typeID
        )
    }

     
     
     
     
     
    func synchronize(from source: ProxyNodeEditorDraft) {
        guard editedJSON != source.editedJSON,
              let replacement = ProxyProtocolCatalog.mapping(
                from: source.editedJSON
              )
        else { return }
        objectWillChange.send()
        mapping = replacement
    }

     
     
     
     
     
     
     
     
     
     
    func prepare(from source: ProxyNodeEditorDraft) {
        guard editedJSON != source.editedJSON,
              let replacement = ProxyProtocolCatalog.mapping(
                from: source.editedJSON
              )
        else { return }
        mapping = replacement
    }

    func string(_ key: String) -> String {
        string(path: [key])
    }

    func string(path: [String]) -> String {
        Self.render(value(path: path))
    }

     
     
     
     
     
    func list(_ key: String) -> [String] {
        guard let array = value(path: [key]) as? [Any] else { return [] }
        return array.map(Self.render)
    }

     
     
     
     
    func elementLists(_ key: String, _ subKey: String) -> [[String]] {
        guard let array = value(path: [key]) as? [[String: Any]] else { return [] }
        return array.map { element in
            (element[subKey] as? [Any])?.map(Self.render) ?? []
        }
    }

    private static func render(_ value: Any?) -> String {
        guard let value else { return "" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber {
             
             
             
             
             
             
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        }
        return ""
    }

    func bool(_ key: String) -> Bool { bool(path: [key]) }

    func bool(path: [String]) -> Bool {
        (value(path: path) as? NSNumber)?.boolValue ?? false
    }

    func stringList(_ key: String) -> String {
        stringList(path: [key])
    }

    func stringList(path: [String]) -> String {
        ((value(path: path) as? [String]) ?? []).joined(separator: ", ")
    }

    func setString(
        _ value: String,
        key: String,
        number: Bool = false,
        omitWhenEmpty: Bool = true
    ) {
        setString(value, path: [key], number: number, omitWhenEmpty: omitWhenEmpty)
    }

    func setString(
        _ value: String,
        path: [String],
        number: Bool = false,
        omitWhenEmpty: Bool = true
    ) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if omitWhenEmpty && trimmed.isEmpty {
            set(nil, path: path)
        } else if number, let integer = Int(trimmed) {
            set(integer, path: path)
        } else {
            set(value, path: path)
        }
    }

    func setBool(_ value: Bool, key: String) { setBool(value, path: [key]) }
    func setBool(_ value: Bool, path: [String]) { set(value, path: path) }

    func setStringList(_ value: String, key: String) {
        setStringList(value, path: [key])
    }

    func setStringList(_ value: String, path: [String]) {
        let items = value.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }
        set(items.isEmpty ? nil : items, path: path)
    }

     
     
     
     
     
     
     
     
     
    func changeType(to typeID: String) {
        let schema = Set(ProxyProtocolEditorSchema.fields(for: typeID).map(\.key))
        guard !schema.isEmpty else {
            setString(typeID, key: "type", omitWhenEmpty: false)
            return
        }
        let kept: Set<String> = ["name", "type", "dialer-proxy"]
        objectWillChange.send()
        for key in mapping.keys where !kept.contains(key) && !schema.contains(key) {
            mapping.removeValue(forKey: key)
        }
         
         
         
         
         
         
         
        for key in mapping.keys where !kept.contains(key) {
            let choices = ProxyEditorFieldChoices.choices(
                forType: typeID, key: key
            )
            guard !choices.isEmpty,
                  let current = mapping[key] as? String,
                  !current.isEmpty,
                  !choices.contains(current) else { continue }
            mapping.removeValue(forKey: key)
        }
        mapping["type"] = typeID
         
         
         
        ProxyEditorNewNodeDefaults.applying(to: &mapping, typeID: typeID)
    }

    func replaceJSONValue(_ value: Any?, key: String) { set(value, path: [key]) }

    func replaceJSONValue(_ value: Any?, path: [String]) { set(value, path: path) }

    func hasValue(path: [String]) -> Bool { value(path: path) != nil }

    func removeValue(path: [String]) { set(nil, path: path) }

    func jsonValue(_ key: String) -> String {
        jsonValue(path: [key])
    }

    func jsonValue(path: [String]) -> String {
        guard let value = value(path: path), JSONSerialization.isValidJSONObject([value]),
              let data = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]
              ) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    private func value(path: [String]) -> Any? {
        guard !path.isEmpty else { return nil }
        var current: Any = mapping
        for key in path {
            guard let object = current as? [String: Any], let next = object[key] else {
                return nil
            }
            current = next
        }
        return current
    }

    private func set(_ value: Any?, path: [String]) {
        guard let first = path.first else { return }
         
         
         
         
         
         
         
        if Self.valuesEqual(self.value(path: path), value) { return }
        objectWillChange.send()
        if path.count == 1 {
            if let value { mapping[first] = value } else { mapping.removeValue(forKey: first) }
            return
        }
        var child = mapping[first] as? [String: Any] ?? [:]
        Self.set(value, path: Array(path.dropFirst()), dictionary: &child)
        if child.isEmpty { mapping.removeValue(forKey: first) } else { mapping[first] = child }
    }

    private static func valuesEqual(_ lhs: Any?, _ rhs: Any?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case (nil, _), (_, nil):
            return false
        case let (lhs?, rhs?):
            return (lhs as AnyObject).isEqual(rhs)
        }
    }

    private static func set(_ value: Any?, path: [String], dictionary: inout [String: Any]) {
        guard let first = path.first else { return }
        if path.count == 1 {
            if let value { dictionary[first] = value } else { dictionary.removeValue(forKey: first) }
            return
        }
        var child = dictionary[first] as? [String: Any] ?? [:]
        set(value, path: Array(path.dropFirst()), dictionary: &child)
        if child.isEmpty { dictionary.removeValue(forKey: first) } else { dictionary[first] = child }
    }

    private static func json(_ mapping: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(mapping),
              let data = try? JSONSerialization.data(
                withJSONObject: mapping,
                options: [.sortedKeys]
              ) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}

 
 
 
 
 
 
 
struct DialerProxyCandidates {
    let groups: [(name: String, type: String)]
    let proxies: [(name: String, type: String)]

    static let empty = DialerProxyCandidates(groups: [], proxies: [])

    static func make(sourceYAML: String?, excluding selfName: String) -> DialerProxyCandidates {
         
         
         
         
         
        let started = DispatchTime.now()
        defer {
            HakoPageProbe.stamp(
                "dialer-candidates",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds
                ) / 1_000_000
            )
        }
        let model = ProxiesOverviewModel.cached(sourceYAML: sourceYAML)
        return DialerProxyCandidates(
            groups: model.groups
                .filter { $0.name != selfName && !$0.isSynthesized }
                .map { ($0.name, $0.type) },
            proxies: model.proxies
                .filter { $0.name != selfName }
                .map { ($0.name, $0.type) }
        )
    }
}

 
enum ProxyDialerRouting {
     
     
    case payloadField
     
     
     
    case chainAssignment(current: String?, save: (String?) throws -> Void)
}

struct ProxyNodeDetailsView: View {
     
     
     
     
     
     
     
     
     
    var commitTitle: String = "Save"
    let record: ProxyNodeRecord
    let retest: () -> Void
    let saveNode: (String, String) async throws -> Void
     
     
     
     
     
     
    let allowsRename: Bool
     
    let showsTesting: Bool
     
     
    let isNew: Bool
    let dialerRouting: ProxyDialerRouting?
     
     
     
     
     
     
    let dialerCandidates: () -> DialerProxyCandidates
     
     
     
    let subscriptionReset: (() throws -> Void)?
    @State private var confirmsSubscriptionReset = false
     
     
     
     
     
    let onDone: (() -> Void)?

    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.hakoPopRoute) private var popRoute
    @StateObject private var draft: ProxyNodeEditorDraft
    @State private var errorMessage = ""
    @State private var revealsPassword = false
    @State private var revealsObfsPassword = false
    @State private var revealedSecretKeys: Set<String> = []
    @State private var chainDialer: String?

    init(
        record: ProxyNodeRecord,
        retest: @escaping () -> Void,
        saveNode: @escaping (String, String) async throws -> Void,
        allowsRename: Bool = true,
        showsTesting: Bool = true,
        isNew: Bool = false,
        dialerRouting: ProxyDialerRouting? = nil,
        dialerCandidates: @escaping () -> DialerProxyCandidates = { .empty },
        subscriptionReset: (() throws -> Void)? = nil,
        onDone: (() -> Void)? = nil,
        commitTitle: String = "Save"
    ) {
        self.commitTitle = commitTitle
        self.record = record
        self.retest = retest
        self.isNew = isNew
        self.saveNode = saveNode
        self.allowsRename = allowsRename
        self.showsTesting = showsTesting
        self.dialerRouting = dialerRouting
        self.dialerCandidates = dialerCandidates
        self.subscriptionReset = subscriptionReset
        self.onDone = onDone
        _draft = StateObject(wrappedValue: ProxyNodeEditorDraft(
            configurationJSON: record.protocolDetails?.configurationJSON ?? "{}",
            fallbackName: record.name,
            fallbackType: record.protocolDetails?.typeID ?? record.type
        ))
        _chainDialer = State(initialValue: {
            if case .chainAssignment(let current, _) = dialerRouting { return current }
            return nil
        }())
    }

    var body: some View {
        editorContainer
        .navigationTitle(isNew ? "Add Node" : "Edit Node")
        .hakoDetailPageInsets()
         
         
         
         
         
        .onAppear {
            let appeared = DispatchTime.now()
            DispatchQueue.main.async {
                HakoPageProbe.stamp(
                    "editor-frame-committed",
                    milliseconds: Double(
                        DispatchTime.now().uptimeNanoseconds - appeared.uptimeNanoseconds
                    ) / 1_000_000
                )
            }
        }
        .hakoStableNavigationDestination(for: ProxyEditorRoute.self) { route in
            switch route {
            case .dialerProxy:
                if let dialerRouting {
                    DialerProxyPickerView(
                        prepare: dialerCandidates,
                        current: currentDialer
                    ) { selection in
                        applyDialer(selection, routing: dialerRouting)
                    }
                    .hakoPushedDetailPage()
                }
            }
        }
         
         
         
         
         
         
        .safeAreaInset(edge: .bottom) {
            if !insideProductModal, let sentence = missingFieldSentence {
                Text(hako: .copy(sentence))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.bar)
                     
                     
                    .accessibilityHidden(true)
            }
        }
        .hakoPageProbe("node-editor")
        .accessibilityIdentifier("proxies.nodeEditor.\(draft.typeID)")
        .toolbar {
            ToolbarItem(placement: .hakoNavigationTrailing) {
                 
                 
                if !insideProductModal {
                    HakoSaveButton(.copy(commitTitle)) { save() }
                        .font(.body.weight(.semibold))
                        .disabled(saveDisabled)
                         
                         
                         
                         
                         
                         
                        .accessibilityValue(missingFieldSentence ?? "")
                        .accessibilityIdentifier("proxies.nodeEditor.save")
                }
            }
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: draft.isDirty,
            save: { completion in
                save()
                completion(true)
            },
             
             
            discard: {}
        )
        .hakoProductModalRoot(title: isNew ? "Add Node" : "Edit Node")
         
         
        .alert(
            HakoCopy.key("Could Not Save"),
            isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = "" }
        } message: {
            Text(hako: .copy(errorMessage))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                HakoModalActionBar(
                    primaryTitle: commitTitle,
                    primaryDisabled: saveDisabled,
                     
                     
                     
                     
                     
                    primaryHint: draft.firstMissingRequiredFieldKey()
                        .map { humanLabel($0) },
                    onPrimary: save
                )
            }
        }
    }

    @ViewBuilder
    private var hysteria2Form: some View {
        Section {
            editableRow("Address", key: "server", textContentType: .URL)
             
             
             
             
             
            editableRow("Port", key: "port", number: true)
            editableRow("Port Range", key: "ports", placeholder: "443-8443")
            secretRow("Password", key: "password", reveals: $revealsPassword)
             
             
             
             
             
             
            ProxyStringMenuRow(
                "Obfuscation",
                selection: stringBinding("obfs"),
                values: [""] + ProxyEditorFieldChoices.choices(
                    forType: "hysteria2", key: "obfs"
                ),
                identifier: "proxies.nodeEditor.option.obfs"
            ) {
                $0.isEmpty ? "None" : $0
            }
            if !draft.string("obfs").isEmpty {
                secretRow(
                    "Obfuscation Password",
                    key: "obfs-password",
                    reveals: $revealsObfsPassword
                )
            }
            ProxyNodeDraftNavigationLink(source: draft) { local in
                ProxyTLSEditorView(draft: local)
            } label: {
                valueRow("TLS", "On")
            }
            .accessibilityIdentifier("proxies.nodeEditor.tls")
            valueRow("UDP Relay", "Built in")
        }

        HakoSection("Bandwidth and port hopping") {
            editableRow("Upload Speed", key: "up", placeholder: "auto")
            editableRow("Download Speed", key: "down", placeholder: "auto")
             
             
             
             
             
            editableRow("Hop Interval", key: "hop-interval", placeholder: "15 or 15-30")
        } footer: {
            Text("Leave upload and download empty or set them to 0 to use BBR flow control.")
        }

        HakoSection("Obfuscation packet size") {
            editableRow("Minimum", key: "obfs-min-packet-size", number: true)
            editableRow("Maximum", key: "obfs-max-packet-size", number: true)
        } footer: {
            Text("Packet-size bounds are used only by Gecko obfuscation.")
        }

        HakoSection("QUIC tuning") {
             
             
            ProxyStringMenuRow(
                "BBR Profile",
                selection: stringBinding("bbr-profile"),
                values: [""] + ProxyEditorFieldChoices.choices(
                    forType: draft.typeID, key: "bbr-profile"
                ),
                identifier: "proxies.nodeEditor.option.bbr-profile"
            ) {
                $0.isEmpty ? "Default" : $0
            }
            editableRow("CWND", key: "cwnd", number: true)
            editableRow("UDP MTU", key: "udp-mtu", number: true)
            editableRow("Initial Stream Window", key: "initial-stream-receive-window", number: true)
            editableRow("Maximum Stream Window", key: "max-stream-receive-window", number: true)
            editableRow("Initial Connection Window", key: "initial-connection-receive-window", number: true)
            editableRow("Maximum Connection Window", key: "max-connection-receive-window", number: true)
        } footer: {
            Text("Advanced QUIC values should normally remain unchanged.")
        }

         
         
         
         
        HakoSection("Dialing") {
            editableRow("IP Version", key: "ip-version", placeholder: "dual")
        }

        advancedOptionsSection
    }

    @ViewBuilder
    private var anyTLSForm: some View {
        Section {
            editableRow("Address", key: "server", textContentType: .URL)
            editableRow("Port", key: "port", number: true)
            secretRow("Password", key: "password", reveals: $revealsPassword)
            ProxyNodeDraftNavigationLink(source: draft) { local in
                ProxyTLSEditorView(draft: local)
            } label: {
                valueRow("TLS", "On")
            }
            .accessibilityIdentifier("proxies.nodeEditor.tls")
            HakoSettingsToggleRow(
                Text("UDP Relay"),
                isOn: boolBinding("udp")
            )
            .accessibilityIdentifier("proxies.nodeEditor.option.udp")
        }

        HakoSection("Session Pool") {
            editableRow("Idle Check Interval", key: "idle-session-check-interval", placeholder: "30", number: true)
            editableRow("Idle Session Timeout", key: "idle-session-timeout", placeholder: "30", number: true)
            editableRow("Minimum Idle Sessions", key: "min-idle-session", placeholder: "0", number: true)
        } footer: {
            Text("Values are seconds. Leave them empty to use the core's AnyTLS defaults.")
        }

        HakoSection("Dialing") {
            HakoSettingsToggleRow(
                Text("TCP Fast Open"),
                isOn: boolBinding("tfo")
            )
            .accessibilityIdentifier("proxies.nodeEditor.option.tfo")
            HakoSettingsToggleRow(
                Text("Multipath TCP"),
                isOn: boolBinding("mptcp")
            )
            .accessibilityIdentifier("proxies.nodeEditor.option.mptcp")
            editableRow("IP Version", key: "ip-version", placeholder: "dual")
        }

        advancedOptionsSection
    }

    @ViewBuilder
    private var genericForm: some View {
        if !editableKeys.isEmpty {
            HakoSection("Configured Options") {
                ForEach(editableKeys, id: \.self) { key in
                    genericRow(key)
                }
            }
        }
        if supportsTLS {
            HakoSection("Security") {
                ProxyNodeDraftNavigationLink(source: draft) { local in
                    HakoLazyView {
                        ProxyTLSEditorView(draft: local)
                    }
                } label: {
                    valueRow("TLS", tlsStateTitle)
                }
                .accessibilityIdentifier("proxies.nodeEditor.tls")
            }
        }
        advancedOptionsSection
    }

     
     
     
     
     
     
     
     
     
     
    private var editableKeys: [String] {
#if os(macOS)
         
         
         
        let plan = Self.keyPlan(for: draft.typeID)
        let hidden = plan.hidden
        let schemaKeys = plan.schemaFields
        let defaultKeys = plan.defaultKeys
#else
        let hidden = dedicatedKeys
            .union(ProxyEditorFieldOwnership.dedicatedSections)
            .union(ProxyEditorHiddenFields.platformUnsupported)
        let schemaKeys = ProxyProtocolEditorSchema.fields(for: draft.typeID)
        let defaultKeys = ProxyEditorDefaultFields.keys(for: draft.typeID)
#endif
        var keys: [String] = []
        var seen = Set<String>()
        for key in defaultKeys
        where !hidden.contains(key) && key != "name" {
            if seen.insert(key).inserted { keys.append(key) }
        }
        for field in schemaKeys where !hidden.contains(field.key) {
            let present = draft.mapping[field.key] != nil
            if (field.required || present), field.key != "name",
               seen.insert(field.key).inserted {
                keys.append(field.key)
            }
        }
        let extras = draft.mapping.keys
            .filter { !hidden.contains($0) && !seen.contains($0) && $0 != "name" }
#if os(macOS)
             
             
             
            .filter { !plan.schemaKeySet.contains($0) }
#else
            .filter { key in !schemaKeys.contains { $0.key == key } }
#endif
            .sorted()
        return keys + extras
    }

     
     
     
     
    @ViewBuilder
    private var editorSections: some View {
        HakoSection("Identity") {
             
             
             
             
             
             
             
             
             
             
            if let macProxyTypeRow = ProxyNodeEditorMacOverrides.proxyTypeRow {
                 
                 
                 
                 
                 
                macProxyTypeRow(draft, isNew)
            } else {
                ProxyNodeDraftNavigationLink(source: draft) { local in
                    ProxyTypeSelectionView(
                        draft: local,
                        hidesNonServerTypes: isNew
                    )
                } label: {
                    valueRow("Proxy Type", protocolDisplayName)
                }
                .accessibilityIdentifier("proxies.nodeEditor.type")
            }

             
             
             
             
             
             
             
             
             
             
             
             
             
            if isNew || allowsRename {
                HakoFieldRow(
                    "Name",
                    hint: "Required",
                    text: stringBinding("name"),
                    identifier: "proxies.nodeEditor.name"
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            } else {
                valueRow("Name", draft.string("name"))
            }
        }

        if draft.typeID == "hysteria2" {
            hysteria2Form
        } else if draft.typeID == "anytls" {
            anyTLSForm
        } else {
            genericForm
        }

        dialerProxySection

        if showsTesting {
            HakoSection("Testing") {
                valueRow("Latency", delayTitle)
                Button(action: retest) {
                    HStack(spacing: HakoTheme.Spacing.compact) {
                        Label(
                            "Retest Latency",
                            systemImage: HakoSymbol.speedometer.name
                        )
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("proxies.nodeEditor.retest")
            }
        }

         
         
         
         
         
         
         
         
    }

     
     
    @ViewBuilder
    private var editorContainer: some View {
        if let macEditorContainer = ProxyNodeEditorMacOverrides.editorContainer {
             
             
             
            macEditorContainer(AnyView(Group {
                if subscriptionReset != nil {
                    subscriptionSection
                }
                editorSections
            }))
        } else {
            Form {
                if subscriptionReset != nil {
                    subscriptionSection
                }
                editorSections
            }
            .hakoInsetGroupedListStyle()
        }
    }

     
     
     
    private var subscriptionSection: some View {
        Section {
            Text(hako: .copy("Edited from the subscription"))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("proxies.nodeEditor.overridden")
            Button(role: .destructive) {
                confirmsSubscriptionReset = true
            } label: {
                Text(hako: .copy("Reset to Subscription"))
            }
            .accessibilityIdentifier("proxies.nodeEditor.reset")
            .confirmationDialog(
                "Reset to Subscription",
                isPresented: $confirmsSubscriptionReset,
                titleVisibility: .visible
            ) {
                Button("Reset to Subscription", role: .destructive) {
                    do {
                        try subscriptionReset?()
                         
                         
                         
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            onDone?()
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } message: {
                Text(hako: .copy("The subscription's own values come back; the edit is discarded."))
            }
        }
    }

#if os(macOS)
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private struct ProtocolKeyPlan {
        let hidden: Set<String>
        let schemaFields: [ProxyEditorSchemaField]
        let schemaKeySet: Set<String>
        let defaultKeys: [String]
    }

    nonisolated(unsafe) private static var keyPlans: [String: ProtocolKeyPlan] = [:]
    private static let keyPlanLock = NSLock()

    private static func keyPlan(for typeID: String) -> ProtocolKeyPlan {
        keyPlanLock.lock()
        defer { keyPlanLock.unlock() }
        if let hit = keyPlans[typeID] { return hit }
        let schemaFields = ProxyProtocolEditorSchema.fields(for: typeID)
         
         
        let plan = ProtocolKeyPlan(
            hidden: Set(["name", "type"])
                .union(ProxyEditorFieldOwnership.tlsKeys(typeID: typeID))
                .union(ProxyEditorFieldOwnership.dedicatedSections)
                .union(ProxyEditorHiddenFields.platformUnsupported),
            schemaFields: schemaFields,
            schemaKeySet: Set(schemaFields.map(\.key)),
            defaultKeys: ProxyEditorDefaultFields.keys(for: typeID)
        )
        keyPlans[typeID] = plan
        return plan
    }
#endif

     
     
     
    private var advancedFieldCount: Int {
        ProxyProtocolAdvancedOptionsView.fields(
            typeID: draft.typeID,
            supportsTLS: supportsTLS
        ).count
    }

    private func isRequiredKey(_ key: String) -> Bool {
        ProxyProtocolEditorSchema.fields(for: draft.typeID)
            .first { $0.key == key }?.required ?? false
    }

    @ViewBuilder
    private var advancedOptionsSection: some View {
        Section {
            ProxyNodeDraftNavigationLink(source: draft) { local in
                ProxyProtocolAdvancedOptionsView(draft: local)
            } label: {
                valueRow(
                    "All Supported Fields",
                    "\(advancedFieldCount) fields"
                )
            }
            .accessibilityIdentifier("proxies.nodeEditor.advanced")
        } footer: {
            Text("This inventory follows the exact core revision pinned by this client.")
        }
    }

    private var supportsTLS: Bool {
        ProxyEditorFieldOwnership.supportsTLS(typeID: draft.typeID)
    }

    private var tlsStateTitle: String {
        if ProxyProtocolEditorSchema.supports("tls", typeID: draft.typeID) {
            return draft.bool("tls") ? "On" : "Off"
        }
        return "On"
    }

    private var dedicatedKeys: Set<String> {
         
         
         
         
         
         
         
        return Set(["name", "type"])
            .union(ProxyEditorFieldOwnership.tlsKeys(typeID: draft.typeID))
    }

    @ViewBuilder
    private func genericRow(_ key: String) -> some View {
         
         
         
         
         
        if let managed = ProxyEditorPlatformNotes.clientManagedNote(forKey: key) {
             
             
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
                valueRow(humanLabel(key), "Automatic")
                Text(managed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if key == "username",
                  ProxyNodeEditorSecretFields.plainUsernameTypes
                      .contains(draft.typeID.lowercased()) {
            editableRow(
                humanLabel(key),
                key: key,
                placeholder: isRequiredKey(key) ? "Required" : "Optional",
                identifier: "proxies.nodeEditor.option.\(key)"
            )
        } else if !ProxyEditorFieldChoices.choices(
            forType: draft.typeID, key: key
        ).isEmpty {
             
             
            ProxyStringMenuRow(
                humanLabel(key),
                selection: stringBinding(key),
                values: ProxyEditorMenuOptions.values(
                    choices: ProxyEditorFieldChoices.choices(
                        forType: draft.typeID,
                        key: key
                    ),
                    isRequired: isRequiredKey(key)
                ),
                identifier: "proxies.nodeEditor.option.\(key)"
            ) {
                $0.isEmpty
                    ? (isRequiredKey(key) ? "Required" : "Not set")
                    : $0
            }
        } else if let field = ProxyProtocolEditorSchema.fields(for: draft.typeID)
            .first(where: { $0.key == key }),
            field.editorControlKind != .text,
            !isSecret(key) {
            ProxySchemaFieldRow(
                draft: draft,
                field: field,
                pathPrefix: [],
                identifierOverride: "proxies.nodeEditor.option.\(key)"
            )
        } else if draft.mapping[key] is Bool || draft.mapping[key] is NSNumber
            && CFGetTypeID(draft.mapping[key] as CFTypeRef) == CFBooleanGetTypeID() {
            HakoSettingsToggleRow(
                Text(humanLabel(key)),
                isOn: boolBinding(key)
            )
            .accessibilityIdentifier("proxies.nodeEditor.option.\(key)")
        } else if isSecret(key) {
            secretRow(
                humanLabel(key),
                key: key,
                reveals: Binding(
                    get: { revealedSecretKeys.contains(key) },
                    set: { shown in
                        if shown { revealedSecretKeys.insert(key) }
                        else { revealedSecretKeys.remove(key) }
                    }
                ),
                placeholder: isRequiredKey(key) ? "Required" : "Optional",
                identifier: "proxies.nodeEditor.option.\(key)"
            )
        } else if draft.mapping[key] is [Any] || draft.mapping[key] is [String: Any] {
            ProxyNodeDraftNavigationLink(source: draft) { local in
                ProxyJSONValueEditorView(draft: local, key: key)
            } label: {
                valueRow(humanLabel(key), "Edit")
            }
        } else {
            editableRow(
                humanLabel(key),
                key: key,
                placeholder: isRequiredKey(key) ? "Required" : "Optional",
                number: draft.mapping[key] is NSNumber,
                identifier: "proxies.nodeEditor.option.\(key)"
            )
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func isDocumentField(_ key: String, typeID: String) -> Bool {
        let key = key.lowercased()
        guard documentKeys.contains(key) else { return false }
        return !fixedWidthKeyFields.contains("\(typeID.lowercased()).\(key)")
    }

     
     
    private static let fixedWidthKeyFields: Set<String> = [
        "wireguard.private-key",
    ]

    static let documentKeys: Set<String> = [
        "ca", "certificate", "private-key", "client-certificate", "client-key",
        "tls-cert", "tls-key",
         
         
        "cert", "key", "tls-auth", "tls-crypt", "tls-crypt-v2",
    ]

     
     
     
     
     
     
     
     
    private func editableRow(
        _ label: String,
        key: String,
        placeholder: String? = nil,
        number: Bool = false,
        textContentType: UITextContentType? = nil,
        identifier: String? = nil
    ) -> some View {
        let identifier = identifier ?? "proxies.nodeEditor.option.\(key)"
         
         
         
        let placeholder = placeholder ?? ProxyEditorFieldHint.text(
            forKey: key, typeID: draft.typeID
        )
#if os(macOS)
        return VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
            if Self.isDocumentField(key, typeID: draft.typeID) {
                ProxyDocumentFieldRow(
                    title: label,
                    hint: placeholder,
                    text: stringBinding(key, number: number),
                    identifier: identifier
                )
            } else {
                let binding = stringBinding(key, number: number)
                HakoFieldRow(
                    label,
                    hint: placeholder,
                    text: binding,
                    suffix: ProxyEditorFieldUnits.displayUnit(
                        forKey: key,
                        value: binding.wrappedValue
                    ),
                    compactValue: ProxyEditorFieldUnits.unit(forKey: key)
                        != nil,
                    identifier: identifier
                )
                .textContentType(textContentType)
                .keyboardType(number ? .numbersAndPunctuation : .default)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .id(identifier)
            }
        }
#else
         
         
        return VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
            if Self.isDocumentField(key, typeID: draft.typeID) {
                 
                 
                 
                 
                 
                 
                ProxyDocumentFieldRow(
                    title: label,
                    hint: placeholder,
                    text: stringBinding(key, number: number),
                    identifier: identifier
                )
            } else {
            HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.standard) {
                Text(hako: .copy(label))
                Spacer(minLength: HakoTheme.Spacing.compact)
                 
                 
                 
                HakoValueField(
                    hint: placeholder,
                    label: label,
                    text: stringBinding(key, number: number)
                )
                    .textContentType(textContentType)
                    .keyboardType(number ? .numbersAndPunctuation : .default)
                    .multilineTextAlignment(.trailing)
                     
                     
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier(identifier)
            }
            }
        }
        .accessibilityElement(children: .contain)
#endif
    }

     
     
    private func secretRow(
        _ label: String,
        key: String,
        reveals: Binding<Bool>,
        placeholder: String? = nil,
        identifier: String? = nil
    ) -> some View {
        let identifier = identifier ?? "proxies.nodeEditor.option.\(key)"
         
         
         
        let placeholder = placeholder ?? ProxyEditorFieldHint.text(
            forKey: key, typeID: draft.typeID
        )
#if os(macOS)
        return Group {
            if Self.isDocumentField(key, typeID: draft.typeID) {
                ProxyRevealingFieldRow(
                    title: label,
                    hint: placeholder,
                    text: stringBinding(key),
                    reveals: reveals,
                    multiline: true,
                    identifier: identifier
                )
            } else {
                HakoFieldRow(
                    label,
                    hint: placeholder,
                    text: stringBinding(key),
                    secure: true,
                    reveals: reveals,
                    monospaced: true,
                    identifier: identifier
                )
                 
                 
                 
                 
                .id(identifier)
                .textContentType(.oneTimeCode)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
            }
        }
#else
         
         
         
         
         
        return ProxyRevealingFieldRow(
            title: label,
            hint: placeholder,
            text: stringBinding(key),
            reveals: reveals,
            multiline: Self.isDocumentField(key, typeID: draft.typeID),
            identifier: identifier
        )
#endif
    }

    private func valueRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(hako: .copy(label))
            Spacer(minLength: HakoTheme.Spacing.standard)
            Text(value.isEmpty ? "Not set" : value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
        .contentShape(Rectangle())
    }

    private func stringBinding(_ key: String, number: Bool = false) -> Binding<String> {
        Binding(
            get: { draft.string(key) },
             
             
            set: { draft.setString($0, key: key, number: number, omitWhenEmpty: false) }
        )
    }

    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { draft.bool(key) }, set: { draft.setBool($0, key: key) })
    }

    private var protocolDisplayName: String {
        ProxyProtocolCatalog.specification(for: draft.typeID)?.displayName ?? draft.typeID
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    private var delayTitle: String {
        guard let delay = record.delay else { return "Not tested" }
        return delay > 0 ? "\(delay) ms" : HakoProbeFailureCopy.neutralBadge
    }

     
     
     
    @ViewBuilder
    private var dialerProxySection: some View {
        if let dialerRouting {
            HakoSection("Routing") {
                HakoStableNavigationLink(value: ProxyEditorRoute.dialerProxy) {
                    DialerProxyPickerView(
                        prepare: dialerCandidates,
                        current: currentDialer
                    ) { selection in
                        applyDialer(selection, routing: dialerRouting)
                    }
                    .hakoPushedDetailPage()
                } label: {
                    valueRow("Dialer Proxy", currentDialer ?? "Not set")
                }
                .accessibilityIdentifier("proxies.nodeEditor.dialer-proxy")
            } footer: {
                switch dialerRouting {
                case .payloadField:
                    Text("dialer-proxy: this node connects through the chosen group or proxy. Saved with the node.")
                case .chainAssignment:
                    Text("dialer-proxy: this node connects through the chosen group or proxy. Saved with the node; the imported source stays unchanged.")
                }
            }
        }
    }

    private var currentDialer: String? {
        guard let dialerRouting else { return nil }
        switch dialerRouting {
        case .payloadField:
            let value = draft.string("dialer-proxy")
            return value.isEmpty ? nil : value
        case .chainAssignment:
            return chainDialer
        }
    }

    private func applyDialer(_ selection: String?, routing: ProxyDialerRouting) {
        switch routing {
        case .payloadField:
            draft.setString(selection ?? "", key: "dialer-proxy")
        case .chainAssignment:
             
             
            chainDialer = selection
        }
    }

    private var chainDialerChanged: Bool {
        guard case .chainAssignment(let current, _) = dialerRouting else { return false }
        return chainDialer != current
    }

     
     
     
     
    private var missingFieldSentence: String? {
        draft.firstMissingRequiredFieldKey().map {
            String.localizedStringWithFormat(
                String(localized: "Needs %@"),
                humanLabel($0)
            )
        }
    }

    private var saveDisabled: Bool {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        Self.saveIsDisabled(
            isNew: isNew,
            isDirty: draft.isDirty,
            chainDialerChanged: chainDialerChanged,
            missingRequiredFieldKey: draft.firstMissingRequiredFieldKey()
        )
    }

     
    static func saveIsDisabled(
        isNew: Bool,
        isDirty: Bool,
        chainDialerChanged: Bool,
        missingRequiredFieldKey: String?
    ) -> Bool {
        if missingRequiredFieldKey != nil { return true }
        if isNew { return false }
        return !isDirty && !chainDialerChanged
    }

    private func save() {
         
         
        errorMessage = ""
        do {
            try validate()
        } catch {
            errorMessage = error.localizedDescription
            return
        }
         
         
         
         
         
#if os(macOS)
        NSApplication.shared.keyWindow?.makeFirstResponder(nil)
#else
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
#endif
        Task { @MainActor in await finishSave() }
    }

    private func finishSave() async {
        do {
            if draft.isDirty || isNew {
                 
                 
                 
                 
                 
                try await saveNode(draft.originalJSON, Self.strippingEmptyStrings(draft.editedJSON))
            }
            if case .chainAssignment(_, let saveAssignment) = dialerRouting,
               chainDialerChanged {
                try saveAssignment(chainDialer)
            }
#if os(macOS)
            if let onDone {
                onDone()
            } else if let popRoute {
                popRoute(HakoPopToken())
            } else {
                presentationMode.wrappedValue.dismiss()
            }
#else
             
             
             
             
             
             
             
             
            presentationMode.wrappedValue.dismiss()
#endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

     
     
    static func strippingEmptyStrings(_ json: String) -> String {
        guard let value = try? JSONSerialization.jsonObject(with: Data(json.utf8)),
              var root = value as? [String: Any] else { return json }
        root = root.filter { !(($0.value as? String)?.isEmpty ?? false) }
        for (key, nested) in root {
            if var child = nested as? [String: Any] {
                child = child.filter { !(($0.value as? String)?.isEmpty ?? false) }
                if child.isEmpty { root.removeValue(forKey: key) } else { root[key] = child }
            }
        }
        guard let data = try? JSONSerialization.data(
            withJSONObject: root, options: [.sortedKeys]
        ) else { return json }
        return String(decoding: data, as: UTF8.self)
    }

    private func validate() throws {
         
         
        if let key = draft.firstMissingRequiredFieldKey() {
            throw ProxyNodeEditorError.missingField(humanLabel(key))
        }
         
         
         
        if let violation = ProxyEditorCrossFieldRules.violations(
            typeID: draft.typeID,
            value: { draft.string($0) },
            nested: { draft.string(path: [$0, $1]) },
            hasObject: { draft.mapping[$0] is [String: Any] },
            list: { draft.list($0) },
            elementLists: { draft.elementLists($0, $1) }
        ).first {
            throw ProxyNodeEditorError.refusedCombination(violation.message)
        }
         
         
         
         
         
         
         
         
         
         
         
        if let key = ProxyEditorNumericFields.firstNonNumeric(
            typeID: draft.typeID,
            mapping: draft.mapping
        ) {
            throw ProxyNodeEditorError.notANumber(humanLabel(key))
        }
    }

    private func humanLabel(_ key: String) -> String {
        ProxyNodeFieldLabel.text(for: key)
    }

    private static let secretKeys = ProxyNodeEditorSecretFields.keys

     
     
     
     
     
     
     
     
     
    private func isSecret(_ key: String) -> Bool {
        let lowered = key.lowercased()
        guard Self.secretKeys.contains(lowered) else { return false }
        let type = draft.typeID.lowercased()
        if lowered == "auth",
           ProxyNodeEditorSecretFields.plaintextAuthTypes.contains(type) {
            return false
        }
        if lowered == "username",
           ProxyNodeEditorSecretFields.plainUsernameTypes.contains(type) {
            return false
        }
        return true
    }


}

private enum ProxyNodeEditorError: LocalizedError {
    case missingServer
    case missingPort
    case missingPassword
    case missingField(String)
     
     
    case refusedCombination(String)
     
    case notANumber(String)

    var errorDescription: String? {
        switch self {
        case .refusedCombination(let message): return message
        case .missingField(let label): return "\(label) is required."
        case .notANumber(let label): return "\(label) must be a number."
        case .missingServer: return "Enter the proxy server address."
        case .missingPort: return "Enter a port or port range."
        case .missingPassword: return "Enter the Hysteria 2 password."
        }
    }
}

private struct DialerProxyPickerView: View {
     
     
     
     
     
     
     
     
     
     
     
     
    let prepare: () -> DialerProxyCandidates
    let current: String?
    let pick: (String?) -> Void

    @State private var candidates: DialerProxyCandidates?

     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPopRoute) private var popRoute
    @Environment(\.locale) private var locale

     
     
     
     
     
     
     
     
    @ViewBuilder
    private func dialerSeat<C: View>(
        @ViewBuilder _ content: @escaping () -> C
    ) -> some View {
#if os(macOS)
        List {
            content()
        }
        .listStyle(.inset)
         
         
        .environment(\.defaultMinListRowHeight, 0)
#else
        ProxyEditorSeat {
            content()
        }
#endif
    }

     
     
     
    var body: some View {
        pageBody.hakoCapturesDismiss(dismiss)
    }
    @ViewBuilder
    private var pageBody: some View {
         
         
         
         
         
         
         
         
         
#if os(macOS)
         
         
         
         
         
        if let candidates {
            HakoRulePolicyPickerView(
                title: "Dialer Proxy",
                builtIns: [(
                    name: "None",
                    caption: HakoCopy.string(
                        "This node connects out through the group or proxy you pick here. None connects directly.",
                        locale: locale
                    )
                )],
                builtInsTitle: nil,
                axPrefix: "dialer-proxy",
                offersGlobal: false,
                options: HakoRulePolicyOptions(
                    groups: candidates.groups.map {
                        HakoRulePolicySnapshot(name: $0.name, type: $0.type)
                    },
                    proxies: candidates.proxies.map {
                        HakoRulePolicySnapshot(name: $0.name, type: $0.type)
                    }
                ),
                current: current ?? "None",
                icon: { symbol in Image(systemName: symbol.name) },
                pick: { name in
                    pick(name == "None" ? nil : name)
                }
            )
            .task(prepareTask)
            .onAppear(perform: stampFirstFrame)
        } else {
            dialerSeat {
                HakoSection("") {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("proxies.nodeEditor.dialer-proxy.loading")
                }
            }
            .hakoProductModalChild(title: "Dialer Proxy")
            .task(prepareTask)
        }
#else
        dialerSeat {
             
             
             
            HakoSection("") {
                Text(HakoCopy.key(
                    "This node connects out through the group or proxy you pick here. None connects directly."
                ))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .listRowSeparator(.hidden)

                 
                 
                 
                row(title: HakoCopy.string("None", locale: locale), value: nil)
            }
            if let candidates {
                if !candidates.groups.isEmpty {
                    HakoSection("Groups") {
                        ForEach(candidates.groups, id: \.name) { group in
                            row(title: group.name, value: group.name, caption: group.type)
                        }
                    }
                }
                if !candidates.proxies.isEmpty {
                    HakoSection("Proxies") {
                        ForEach(candidates.proxies, id: \.name) { proxy in
                            row(title: proxy.name, value: proxy.name, caption: proxy.type)
                        }
                    }
                }
            } else {
                HakoSection("") {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("proxies.nodeEditor.dialer-proxy.loading")
                }
            }
        }
        .task(prepareTask)
         
         
         
        .onAppear(perform: stampFirstFrame)
        .hakoPageTitle("Dialer Proxy")
        .hakoPageProbe("dialer-proxy")
        .hakoDetailPageInsets()
        .accessibilityIdentifier("proxies.nodeEditor.dialer-proxy.picker")
        .hakoProductModalChild(title: "Dialer Proxy")
#endif
    }

     
    @Sendable
    private func prepareTask() async {
         
         
         
        guard candidates == nil else { return }
        let build = prepare
        candidates = await Task.detached(priority: .userInitiated) {
            build()
        }.value
    }

     
     
     
    private func stampFirstFrame() {
        let appeared = DispatchTime.now()
        DispatchQueue.main.async {
            HakoPageProbe.stamp(
                "dialer-proxy-frame-committed",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - appeared.uptimeNanoseconds
                ) / 1_000_000
            )
        }
    }

    private func row(title: String, value: String?, caption: String? = nil) -> some View {
        Button {
            pick(value)
             
             
#if os(macOS)
            if let popRoute {
                popRoute(HakoPopToken())
            } else {
                dismiss()
            }
#else
             
             
             
            dismiss()
#endif
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(hako: .copy(title)).foregroundStyle(.primary)
                    if let caption {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: HakoTheme.Spacing.compact)
                HakoSelectionMark(isSelected: current == value)
            }
            .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dialer-proxy.\(value ?? "none")")
    }
}

 
 
 
 
 
enum ProxyEditorRoute: Hashable {
    case dialerProxy
}

 
 
 
 
 
 
 
 
 
private struct ProxyNodeDraftNavigationLink<
    Destination: View,
    Label: View
>: View {
    @ObservedObject private var source: ProxyNodeEditorDraft
    private let destination: (ProxyNodeEditorDraft) -> Destination
    private let label: () -> Label

#if os(macOS)
    @StateObject private var local: ProxyNodeEditorDraft
#endif

    init(
        source: ProxyNodeEditorDraft,
        @ViewBuilder destination: @escaping (
            ProxyNodeEditorDraft
        ) -> Destination,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.source = source
        self.destination = destination
        self.label = label
#if os(macOS)
        _local = StateObject(wrappedValue: source.detachedCopy())
#endif
    }

    @ViewBuilder
    var body: some View {
#if os(macOS)
        HakoRoutedViewLink(
            onNavigate: prepare,
            onReturn: commit
        ) {
            destination(local)
        } label: {
            label()
        }
#else
        HakoRoutedViewLink {
            destination(source)
        } label: {
            label()
        }
#endif
    }

#if os(macOS)
    private func prepare() {
        local.prepare(from: source)
    }

    private func commit() {
        source.synchronize(from: local)
    }
#endif
}

 
 
 
 
 
enum ProxyTypeGrouping {
     
    static let commonTypeIDs = [
        "ss", "vmess", "vless", "trojan", "hysteria2", "tuic", "wireguard", "socks5",
    ]

     
     
    static let nonServerTypeIDs: Set<String> = [
        "direct", "dns", "reject", "rematch",
    ]
}

 
 
 
 
 
 
 
enum ProxyNodeEditorMacOverrides {
    nonisolated(unsafe) static var proxyTypeRow:
        ((ProxyNodeEditorDraft, _ hidesNonServerTypes: Bool) -> AnyView)?

     
     
     
     
     
    nonisolated(unsafe) static var editorContainer: ((AnyView) -> AnyView)?
}

 
 
 
 
 
 
 
 
 
 
private struct ProxyEditorSeat<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if let macEditorContainer = ProxyNodeEditorMacOverrides.editorContainer {
            macEditorContainer(AnyView(content()))
        } else {
            Form {
                content()
            }
            .hakoInsetGroupedListStyle()
        }
    }
}

private struct ProxyTypeSelectionView: View {
    @ObservedObject var draft: ProxyNodeEditorDraft
     
     
    var hidesNonServerTypes: Bool = false
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPopRoute) private var popRoute

    var body: some View {
         
         
        Form {
            HakoSection("Common") {
                ForEach(commonSpecifications, id: \.typeID, content: typeRow)
            }
            HakoSection("All Protocols") {
                ForEach(remainingSpecifications, id: \.typeID, content: typeRow)
            }
        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle("Proxy Type")
        .hakoPageProbe("proxy-type")
        .hakoDetailPageInsets()
        .hakoProductModalChild(title: "Proxy Type")
        .hakoCapturesDismiss(dismiss)
    }

    private var commonSpecifications: [ProxyProtocolSpecification] {
        ProxyTypeGrouping.commonTypeIDs.compactMap { id in
            ProxyProtocolCatalog.specifications.first { $0.typeID == id }
        }
    }

    private var remainingSpecifications: [ProxyProtocolSpecification] {
        ProxyProtocolCatalog.specifications.filter {
            !ProxyTypeGrouping.commonTypeIDs.contains($0.typeID)
                && !(hidesNonServerTypes
                    && ProxyTypeGrouping.nonServerTypeIDs.contains($0.typeID))
        }
    }

    private func typeRow(_ item: ProxyProtocolSpecification) -> some View {
        Button {
            draft.changeType(to: item.typeID)
#if os(macOS)
             
             
             
             
             
            if let popRoute {
                popRoute(HakoPopToken())
            } else {
                dismiss()
            }
#else
             
             
             
             
             
             
             
             
             
            dismiss()
#endif
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayName).foregroundStyle(.primary)
                    Text(hako: .verbatim(item.summary))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: HakoTheme.Spacing.compact)
                HakoSelectionMark(isSelected: draft.typeID == item.typeID)
            }
            .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("proxy-type.\(item.typeID)")
    }
}

 
 
 
 
 
 
enum ProxyEditorMenuOptions {
    static func values(
        choices: [String],
        isRequired: Bool
    ) -> [String] {
        (isRequired ? [] : [""]) + choices
    }

    static func offeredValues(
        selection: String,
        values: [String]
    ) -> [String] {
         
         
         
         
        if selection.isEmpty, !values.contains("") {
            return values
        }
        return values.contains(selection) ? values : [selection] + values
    }
}

private struct ProxyStringMenuRow: View {
    let title: String
    @Binding var selection: String
    let values: [String]
    let identifier: String?
    let displayName: (String) -> String

    init(
        _ title: String,
        selection: Binding<String>,
        values: [String],
        identifier: String? = nil,
        displayName: @escaping (String) -> String = { $0 }
    ) {
        self.title = title
        _selection = selection
        self.values = values
        self.identifier = identifier
        self.displayName = displayName
    }

    private var offeredValues: [String] {
        ProxyEditorMenuOptions.offeredValues(
            selection: selection,
            values: values
        )
    }

    var body: some View {
#if os(macOS)
        Menu {
            Picker(title, selection: $selection) {
                ForEach(offeredValues, id: \.self) { value in
                    Text(displayName(value))
                        .tag(value)
                        .accessibilityIdentifier(
                            "\(identifier ?? "proxy-menu.\(title)").choice.\(value.isEmpty ? "default" : value)"
                        )
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
             
             
             
             
             
             
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(hako: .copy(displayName(selection)))
                    .foregroundStyle(.secondary)
                Image(
                    systemName:
                        HakoSymbol.chevronUpChevronDown.name
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityValue(displayName(selection))
            .optionalProxyAccessibilityIdentifier(identifier)
        }
        .buttonStyle(.plain)
        .fixedSize()
         
         
         
         
         
        .id(identifier ?? title)
        .hakoSettingsMenuRow(title)
#else
        Picker(title, selection: $selection) {
            ForEach(offeredValues, id: \.self) { value in
                Text(displayName(value))
                    .tag(value)
                    .accessibilityIdentifier(
                        "\(identifier ?? "proxy-menu.\(title)").choice.\(value.isEmpty ? "default" : value)"
                    )
            }
        }
        .optionalProxyAccessibilityIdentifier(identifier)
#endif
    }
}

 
 
private struct ProxyDocumentFieldRow: View {
    let title: String
    let hint: String
    @Binding var text: String
    let identifier: String?
    @FocusState private var focused: Bool

    var body: some View {
         
         
         
         
        if #available(iOS 16.0, macOS 13.0, *) {
            stacked
        } else {
            HakoFieldRow(
                title,
                hint: hint,
                text: $text,
                monospaced: true,
                identifier: identifier
            )
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @available(iOS 16.0, macOS 13.0, *)
    private var stacked: some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(hako: .copy(title))
                    .lineLimit(1)
                Spacer(minLength: HakoTheme.Spacing.compact)
                if text.isEmpty {
                    Text(HakoCopy.key(hint))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            TextField(
                text: $text,
                prompt: nil,
                axis: .vertical,
                label: { EmptyView() }
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .font(.body.monospaced())
            .lineLimit(4...16)
            .multilineTextAlignment(.leading)
            .textContentType(.oneTimeCode)
            .disableAutocorrection(true)
            .focused($focused)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(HakoCopy.key(title)))
            .optionalProxyAccessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .optionalProxyAccessibilityIdentifier(
            identifier.map { "\($0).row" }
        )
    }
}

private struct ProxyRevealingFieldRow: View {
    let title: String
    let hint: String
    @Binding var text: String
    @Binding var reveals: Bool
    let multiline: Bool
    let identifier: String?
    @FocusState private var focused: Bool

    var body: some View {
         
         
         
        if multiline,
           reveals,
           #available(iOS 16.0, macOS 13.0, *) {
             
             
             
             
            stacked
        } else {
            inline
        }
    }

    private var inline: some View {
        HStack(alignment: multiline && reveals ? .top : .center) {
            Text(hako: .copy(title))
                .lineLimit(1)
                .layoutPriority(1)
                .padding(.top, multiline && reveals ? 4 : 0)
                 
                 
                .onTapGesture { focused = true }
            Spacer(minLength: HakoTheme.Spacing.compact)
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
                !(multiline && reveals)
            {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                field
                    .focused($focused)
                    .optionalProxyAccessibilityIdentifier(identifier)
            } else {
                field
                    .focused($focused)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .optionalProxyAccessibilityIdentifier(identifier)
            }
            revealButton
        }
        .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { focused = true }
        )
         
         
         
        .onDisappear { focused = false }
        .accessibilityElement(children: .contain)
        .optionalProxyAccessibilityIdentifier(
            identifier.map { "\($0).row" }
        )
    }

    private var revealButton: some View {
        Button {
            reveals.toggle()
        } label: {
            Image(
                systemName:
                    (reveals ? HakoSymbol.eyeSlash : HakoSymbol.eye).name
            )
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(reveals ? "Hide value" : "Show value")
    }

     
     
     
     
    @available(iOS 16.0, macOS 13.0, *)
    private var stacked: some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(hako: .copy(title))
                    .lineLimit(1)
                    .onTapGesture { focused = true }
                Spacer(minLength: HakoTheme.Spacing.compact)
                if text.isEmpty {
                    Text(HakoCopy.key(hint))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                revealButton
            }
            TextField(
                text: $text,
                prompt: nil,
                axis: .vertical,
                label: { EmptyView() }
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .font(.body.monospaced())
            .lineLimit(4...16)
            .multilineTextAlignment(.leading)
            .textContentType(.oneTimeCode)
            .disableAutocorrection(true)
            .focused($focused)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(HakoCopy.key(title)))
            .optionalProxyAccessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
         
         
        .onDisappear { focused = false }
        .accessibilityElement(children: .contain)
        .optionalProxyAccessibilityIdentifier(
            identifier.map { "\($0).row" }
        )
    }

    @ViewBuilder
    private var field: some View {
        if reveals {
            if multiline, #available(iOS 16.0, macOS 13.0, *) {
                TextField("", text: $text, axis: .vertical)
                    .lineLimit(3...12)
                    .textFieldStyle(.plain)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.leading)
                    .disableAutocorrection(true)
                    .textInputAutocapitalization(.never)
                    .overlay(alignment: .trailing) {
                        if text.isEmpty {
                            Text(HakoCopy.key(hint))
                                .foregroundStyle(.tertiary)
                                .allowsHitTesting(false)
                        }
                    }
                    .accessibilityLabel(Text(HakoCopy.key(title)))
            } else {
                 
                 
                 
                 
                 
                 
                HakoValueField(
                    hint: hint,
                    label: title,
                    bordered: HakoPlatformLayout.pageUsesSystemSettingsIdiom,
                    text: $text
                )
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.trailing)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .hakoMacFieldValueWidth()
            }
        } else {
            HakoSecureValueField(
                hint: hint,
                label: title,
                bordered: HakoPlatformLayout.pageUsesSystemSettingsIdiom,
                text: $text
            )
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.trailing)
            .hakoMacFieldValueWidth()
        }
    }

}

private extension View {
    @ViewBuilder
    func optionalProxyAccessibilityIdentifier(
        _ identifier: String?
    ) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

private struct ProxyProtocolAdvancedOptionsView: View {
    @ObservedObject var draft: ProxyNodeEditorDraft

     
     
     
     
     
    static func fields(
        typeID: String,
        supportsTLS: Bool
    ) -> [ProxyEditorSchemaField] {
        ProxyEditorFieldOwnership.advancedFields(typeID: typeID)
    }

    var body: some View {
        ProxyEditorSeat {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                HakoSection(section.title) {
                    ForEach(section.fields) { field in
                        ProxySchemaFieldRow(
                            draft: draft,
                            field: field,
                            pathPrefix: []
                        )
                    }
                }
            }
        }
        .hakoPageTitle("Supported Fields")
        .hakoPageProbe("supported-fields")
        .hakoDetailPageInsets()
        .hakoProductModalChild(title: "Supported Fields")
    }

     
     
     
     
    private var sections: [(title: String, fields: [ProxyEditorSchemaField])] {
        let fields = Self.fields(typeID: draft.typeID, supportsTLS: supportsTLS)
        let order = ["Connection", "Authentication", "Protocol", "Dialing"]
        return order.compactMap { title in
            let matching = fields.filter { category(for: $0.key) == title }
            return matching.isEmpty ? nil : (title, matching)
        }
    }

    private func category(for key: String) -> String {
        if Self.connectionKeys.contains(key) { return "Connection" }
        if Self.authenticationKeys.contains(key) { return "Authentication" }
        if Self.dialingKeys.contains(key) { return "Dialing" }
        return "Protocol"
    }

    private var supportsTLS: Bool {
        ProxyEditorFieldOwnership.supportsTLS(typeID: draft.typeID)
    }

    private static let connectionKeys: Set<String> = [
        "server", "port", "ports", "port-range", "ip", "ipv6", "uri",
    ]
    private static let authenticationKeys: Set<String> = [
        "username", "password", "uuid", "token", "auth", "auth-str", "psk",
        "key", "auth-key", "private-key", "private-key-passphrase", "public-key",
        "pre-shared-key", "ca", "cert", "tls-auth", "tls-crypt", "tls-crypt-v2",
    ]
    private static let dialingKeys: Set<String> = [
        "tfo", "mptcp", "interface-name", "routing-mark", "ip-version", "dialer-proxy",
    ]
}

private struct ProxySchemaNestedOptionsView: View {
    @ObservedObject var draft: ProxyNodeEditorDraft
    let title: String
    let fields: [ProxyEditorSchemaField]
    let pathPrefix: [String]

    var body: some View {
        ProxyEditorSeat {
            ForEach(ProxyNestedFieldGrouping.groups(for: fields), id: \.title) {
                group in
                HakoSection(group.title) {
                    ForEach(group.fields) { field in
                        ProxySchemaFieldRow(
                            draft: draft,
                            field: field,
                            pathPrefix: pathPrefix
                        )
                    }
                }
            }
        }
        .hakoPageTitle(.copy(title))
        .hakoPageProbe("nested-options")
        .hakoDetailPageInsets()
        .hakoProductModalChild(title: title)
    }
}

 
 
 
 
 
 
 
 
 
 
 
enum ProxyNestedFieldGrouping {
    struct Group {
        let title: String
        let fields: [ProxyEditorSchemaField]
    }

    private static let buckets: [(title: String, keys: Set<String>)] = [
        (
            "Transport",
            [
                "mode", "host", "path", "headers", "version", "service-name",
                "grpc-service-name", "obfs", "obfs-param", "obfs-host",
            ]
        ),
        (
            "Authentication",
            ["username", "password", "uuid", "auth", "auth-str", "token", "psk"]
        ),
        (
            "Security",
            [
                "tls", "sni", "servername", "alpn", "fingerprint",
                "client-fingerprint", "skip-cert-verify", "certificate",
                "private-key", "ca", "ca-str", "name-cert-verify",
                "version-hint", "reality-opts",
            ]
        ),
        ("Multiplexing", ["mux", "smux", "brutal", "max-streams"]),
    ]

    static func groups(for fields: [ProxyEditorSchemaField]) -> [Group] {
        var remaining = fields
        var grouped: [Group] = []

        for bucket in buckets {
            let matched = remaining.filter { bucket.keys.contains($0.key.lowercased()) }
            guard !matched.isEmpty else { continue }
            grouped.append(Group(title: bucket.title, fields: matched))
            remaining.removeAll { bucket.keys.contains($0.key.lowercased()) }
        }

        if !remaining.isEmpty {
            grouped.insert(Group(title: "", fields: remaining), at: 0)
        }
        return grouped
    }
}

private struct ProxySchemaFieldRow: View {
    @ObservedObject var draft: ProxyNodeEditorDraft
    let field: ProxyEditorSchemaField
    let pathPrefix: [String]
     
     
    var identifierOverride: String? = nil
    @State private var revealsSecret = false

    var body: some View {
        Group {
            if field.editorControlKind == .bool {
                HakoSettingsToggleRow(
                    Text(label),
                    isOn: boolBinding
                )
                    .accessibilityIdentifier(fieldIdentifier)
            } else if field.editorControlKind == .optionalBool {
                optionalBoolPicker
                    .accessibilityIdentifier(fieldIdentifier)
            } else if field.editorControlKind == .nestedObject {
                ProxyNodeDraftNavigationLink(source: draft) { local in
                    ProxySchemaNestedOptionsView(
                        draft: local,
                        title: label,
                        fields: field.children,
                        pathPrefix: path
                    )
                } label: {
                    valueRow(label, draft.hasValue(path: path) ? "Configured" : "Not set")
                }
                .accessibilityIdentifier(fieldIdentifier)
            } else if field.editorControlKind == .json {
                ProxyNodeDraftNavigationLink(source: draft) { local in
                    ProxyJSONPathEditorView(
                        draft: local,
                        path: path,
                        title: label,
                        goType: field.goType
                    )
                } label: {
                    valueRow(label, draft.hasValue(path: path) ? "Configured" : "Not set")
                }
                .accessibilityIdentifier(fieldIdentifier)
            } else if !pickerChoices.isEmpty {
                 
                 
                 
                 
                 
                 
                 
                ProxyStringMenuRow(
                    label,
                    selection: textBinding,
                    values: ProxyEditorMenuOptions.values(
                        choices: pickerChoices,
                        isRequired: field.required
                    ),
                    identifier: fieldIdentifier
                ) {
                    $0.isEmpty
                        ? (field.required ? "Required" : "Not set")
                        : $0
                }
            } else if field.editorControlKind == .stringList {
                textRow(binding: listBinding)
            } else if field.editorControlKind == .secret {
                secretRow
            } else {
                textRow(binding: textBinding)
            }
        }
    }

    private var path: [String] { pathPrefix + [field.key] }

     
     
     
    private var pickerChoices: [String] {
        let typeID = draft.typeID
        let byPath = ProxyEditorFieldChoices.choices(
            forType: typeID, key: path.joined(separator: ".")
        )
        if !byPath.isEmpty { return byPath }
        guard pathPrefix.isEmpty else { return [] }
        return ProxyEditorFieldChoices.choices(forType: typeID, key: field.key)
    }

    private var label: String {
        ProxyNodeFieldLabel.text(for: field.key)
    }

    private var isNumeric: Bool { field.editorControlKind == .number }

    private var fieldIdentifier: String {
        identifierOverride
            ?? "proxies.nodeEditor.field.\(path.joined(separator: "."))"
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { draft.string(path: path) },
            set: { draft.setString($0, path: path, number: isNumeric) }
        )
    }

    private var listBinding: Binding<String> {
        Binding(
            get: { draft.stringList(path: path) },
            set: { draft.setStringList($0, path: path) }
        )
    }

    private var boolBinding: Binding<Bool> {
        Binding(
            get: { draft.bool(path: path) },
            set: { draft.setBool($0, path: path) }
        )
    }

    private var optionalBoolSelection: Binding<String> {
        Binding(
            get: {
                guard draft.hasValue(path: path) else { return "default" }
                return draft.bool(path: path) ? "on" : "off"
            },
            set: { value in
                switch value {
                case "on": draft.setBool(true, path: path)
                case "off": draft.setBool(false, path: path)
                default: draft.removeValue(path: path)
                }
            }
        )
    }

    private var optionalBoolPicker: some View {
        ProxyStringMenuRow(
            label,
            selection: optionalBoolSelection,
            values: ["default", "on", "off"],
            identifier: fieldIdentifier
        ) {
            switch $0 {
            case "on": "On"
            case "off": "Off"
            default: "Default"
            }
        }
    }

     
     
     
     
     
     
    private func textRow(binding: Binding<String>) -> some View {
        HakoFieldRow(
            label,
            hint: field.required ? "Required" : "Optional",
            text: binding,
            suffix: unitSuffix(for: binding.wrappedValue),
            compactValue: hasUnit,
            identifier: fieldIdentifier
        )
        .keyboardType(isNumeric ? .numbersAndPunctuation : .default)
        .disableAutocorrection(true)
        .textInputAutocapitalization(.never)
    }

     
     
    private func unitSuffix(for value: String) -> String? {
#if os(macOS)
        ProxyEditorFieldUnits.displayUnit(forKey: field.key, value: value)
#else
        nil
#endif
    }

    private var hasUnit: Bool {
#if os(macOS)
        ProxyEditorFieldUnits.unit(forKey: field.key) != nil
#else
        false
#endif
    }

    private var secretRow: some View {
        ProxyRevealingFieldRow(
            title: label,
            hint: field.required ? "Required" : "Optional",
            text: textBinding,
            reveals: $revealsSecret,
            multiline: ProxyNodeDetailsView.isDocumentField(
                field.key,
                typeID: draft.typeID
            ),
            identifier: fieldIdentifier
        )
    }

    private func valueRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(hako: .copy(label))
            Spacer(minLength: HakoTheme.Spacing.standard)
            Text(value).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
        .contentShape(Rectangle())
    }

}

 
 
 
private enum ProxyNodeFieldLabel {
    private static let replacements = [
        "addr": "Address",
        "alpn": "ALPN",
        "auth": "Authentication",
        "bbr": "BBR",
        "ca": "CA",
        "cdn": "CDN",
        "cert": "Certificate",
        "cwnd": "CWND",
        "dns": "DNS",
        "ech": "ECH",
        "grpc": "gRPC",
        "h2": "H2",
        "http": "HTTP",
        "id": "ID",
        "ip": "IP",
        "ipv4": "IPv4",
        "ipv6": "IPv6",
        "jls": "JLS",
        "max": "Maximum",
        "mkcp": "mKCP",
        "min": "Minimum",
        "mptcp": "MPTCP",
        "mtu": "MTU",
        "nat": "NAT",
        "opts": "Options",
        "param": "Parameter",
        "quic": "QUIC",
        "rtt": "RTT",
        "smux": "SMUX",
        "sni": "SNI",
        "ssh": "SSH",
        "str": "String",
        "down": "Download",
        "tcp": "TCP",
        "tfo": "TFO",
        "tls": "TLS",
        "tlsmirror": "TLS Mirror",
        "udp": "UDP",
        "up": "Upload",
        "uri": "URI",
        "url": "URL",
        "uuid": "UUID",
        "ws": "WebSocket",
        "xudp": "XUDP",
    ]

    static func text(for key: String) -> String {
        words(in: key).map { word in
            replacements[word.lowercased()] ?? word.capitalized
        }.joined(separator: " ")
    }

    private static func words(in key: String) -> [String] {
        var words: [String] = []
        var current = ""
        for character in key {
            if character == "-" || character == "_" {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            } else if character.isUppercase, !current.isEmpty {
                words.append(current)
                current = String(character)
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { words.append(current) }
        return words
    }
}

private struct ProxyTLSEditorView: View {
    @ObservedObject var draft: ProxyNodeEditorDraft
    @State private var revealsPrivateKey = false

     
    @ViewBuilder
    private func documentRow(
        _ label: String,
        path: [String],
        identifier: String
    ) -> some View {
        ProxyDocumentFieldRow(
            title: label,
            hint: "Optional",
            text: textBinding(path),
            identifier: identifier
        )
    }

    var body: some View {
        ProxyEditorSeat {
            Section {
                HakoSettingsToggleRow(
                    Text("TLS"),
                    isOn: tlsBinding
                )
                    .disabled(tlsRequired)
                    .accessibilityIdentifier("proxies.nodeEditor.tls.tls")
            } footer: {
                if tlsRequired {
                    Text("\(protocolDisplayName) always uses TLS.")
                }
            }

            Section {
                if supports("skip-cert-verify") {
                    HakoSettingsToggleRow(
                        Text("Allow Insecure"),
                        isOn: boolBinding(["skip-cert-verify"])
                    )
                        .accessibilityIdentifier("proxies.nodeEditor.tls.skip-cert-verify")
                }
                if let sniKey {
                    textRow(
                        "SNI",
                        path: [sniKey],
                        identifier: "proxies.nodeEditor.tls.sni"
                    )
                }
                if supports("ech-opts") {
                    ProxyNodeDraftNavigationLink(source: draft) { local in
                        ProxyECHEditorView(draft: local)
                    } label: {
                        valueRow("ECH", draft.bool(path: ["ech-opts", "enable"]) ? "On" : "Off")
                    }
                    .accessibilityIdentifier("proxies.nodeEditor.tls.ech")
                }
                if supports("alpn") {
                    textRow(
                        "ALPN",
                        path: ["alpn"],
                        list: true,
                        identifier: "proxies.nodeEditor.tls.alpn"
                    )
                }
                if supports("client-fingerprint") {
                    textRow(
                        "Client Fingerprint",
                        path: ["client-fingerprint"],
                        identifier: "proxies.nodeEditor.tls.client-fingerprint"
                    )
                }
                if supports("reality-opts") {
                    ProxyNodeDraftNavigationLink(source: draft) { local in
                        ProxyRealityEditorView(draft: local)
                    } label: {
                        valueRow(
                            "Reality",
                            draft.string(path: ["reality-opts", "public-key"]).isEmpty ? "Off" : "Configured"
                        )
                    }
                    .accessibilityIdentifier("proxies.nodeEditor.tls.reality")
                }
            }

            if supports("fingerprint") {
                Section {
                    textRow(
                        "SHA256",
                        path: ["fingerprint"],
                        identifier: "proxies.nodeEditor.tls.fingerprint"
                    )
                } footer: {
                    Text("Use a SHA-256 certificate fingerprint to pin the server certificate.")
                }
            }

            if supports("certificate") || supports("private-key") {
                HakoSection("Mutual TLS") {
                    if supports("certificate") {
                         
                         
                         
                         
                         
                         
                        documentRow(
                            "Certificate",
                            path: ["certificate"],
                            identifier: "proxies.nodeEditor.tls.certificate"
                        )
                    }
                    if supports("private-key") {
                        ProxyRevealingFieldRow(
                            title: "Private Key",
                            hint: "Optional",
                            text: textBinding(["private-key"]),
                            reveals: $revealsPrivateKey,
                            multiline: true,
                            identifier: "proxies.nodeEditor.tls.private-key"
                        )
                    }
                } footer: {
                    Text("Certificate and private key must be configured together.")
                }
            }
        }
        .hakoPageTitle("TLS")
        .hakoDetailPageInsets()
        .hakoProductModalChild(title: "TLS")
    }

    private func textRow(
        _ label: String,
        path: [String],
        list: Bool = false,
        identifier: String
    ) -> some View {
        HakoFieldRow(
            label,
            hint: "Optional",
            text: list ? listBinding(path[0]) : textBinding(path),
            identifier: identifier
        )
        .disableAutocorrection(true)
        .textInputAutocapitalization(.never)
    }

    private func textBinding(_ path: [String]) -> Binding<String> {
        Binding(
            get: { draft.string(path: path) },
            set: { draft.setString($0, path: path) }
        )
    }

    private func listBinding(_ key: String) -> Binding<String> {
        Binding(get: { draft.stringList(key) }, set: { draft.setStringList($0, key: key) })
    }

    private func boolBinding(_ path: [String]) -> Binding<Bool> {
        Binding(get: { draft.bool(path: path) }, set: { draft.setBool($0, path: path) })
    }

    private var tlsBinding: Binding<Bool> {
        guard !tlsRequired else { return .constant(true) }
        return boolBinding(["tls"])
    }

    private var tlsRequired: Bool {
        !supports("tls")
    }

     
     
     
     
     
    private func supports(_ key: String) -> Bool {
        ProxyEditorFieldOwnership.tlsKeys(typeID: draft.typeID).contains(key)
    }

    private var sniKey: String? {
        if supports("sni") { return "sni" }
        if supports("servername") { return "servername" }
        return nil
    }

    private var protocolDisplayName: String {
        ProxyProtocolCatalog.specification(for: draft.typeID)?.displayName ?? draft.typeID
    }

    private func valueRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(hako: .copy(label))
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
        .contentShape(Rectangle())
    }
}

private struct ProxyECHEditorView: View {
    @ObservedObject var draft: ProxyNodeEditorDraft

    var body: some View {
        ProxyEditorSeat {
            Section {
                HakoSettingsToggleRow(
                    Text("ECH"),
                    isOn: boolBinding(["ech-opts", "enable"])
                )
                .accessibilityIdentifier("proxies.nodeEditor.tls.ech.enabled")
                textRow(
                    "Configuration",
                    path: ["ech-opts", "config"],
                    identifier: "proxies.nodeEditor.tls.ech.config"
                )
                textRow(
                    "Query Server Name",
                    path: ["ech-opts", "query-server-name"],
                    identifier: "proxies.nodeEditor.tls.ech.query-server-name"
                )
            } footer: {
                Text("When configuration is empty, the core resolves the ECH HTTPS record using DNS.")
            }
        }
        .hakoPageTitle("ECH")
        .hakoDetailPageInsets()
        .hakoProductModalChild(title: "ECH")
    }

    private func textRow(
        _ label: String,
        path: [String],
        identifier: String
    ) -> some View {
        HakoFieldRow(
            label,
            hint: "Optional",
            text: Binding(
                get: { draft.string(path: path) },
                set: { draft.setString($0, path: path) }
            ),
            identifier: identifier
        )
        .disableAutocorrection(true)
        .textInputAutocapitalization(.never)
    }

    private func boolBinding(_ path: [String]) -> Binding<Bool> {
        Binding(get: { draft.bool(path: path) }, set: { draft.setBool($0, path: path) })
    }
}

private struct ProxyRealityEditorView: View {
    @ObservedObject var draft: ProxyNodeEditorDraft
    @State private var revealsPublicKey = false

    var body: some View {
        ProxyEditorSeat {
            Section {
                ProxyRevealingFieldRow(
                    title: "Public Key",
                    hint: "Required",
                    text: textBinding("public-key"),
                    reveals: $revealsPublicKey,
                    multiline: false,
                    identifier: "proxies.nodeEditor.tls.reality.public-key"
                )
                textRow(
                    "Short ID",
                    key: "short-id",
                    identifier: "proxies.nodeEditor.tls.reality.short-id"
                )
                HakoSettingsToggleRow(
                    Text("X25519 + ML-KEM-768"),
                    isOn: Binding(
                        get: { draft.bool(path: ["reality-opts", "support-x25519mlkem768"]) },
                        set: { draft.setBool($0, path: ["reality-opts", "support-x25519mlkem768"]) }
                    )
                )
                .accessibilityIdentifier(
                    "proxies.nodeEditor.tls.reality.support-x25519mlkem768"
                )
            } footer: {
                Text("Reality is supported by VMess, VLESS, and Trojan only when their Core option schema exposes reality-opts.")
            }
        }
        .hakoPageTitle("Reality")
        .hakoDetailPageInsets()
        .hakoProductModalChild(title: "Reality")
    }

    private func textRow(
        _ label: String,
        key: String,
        identifier: String
    ) -> some View {
        HakoFieldRow(
            label,
            hint: "Optional",
            text: textBinding(key),
            identifier: identifier
        )
        .disableAutocorrection(true)
        .textInputAutocapitalization(.never)
    }

    private func textBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { draft.string(path: ["reality-opts", key]) },
            set: { draft.setString($0, path: ["reality-opts", key]) }
        )
    }
}

private struct ProxyJSONValueEditorView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @ObservedObject var draft: ProxyNodeEditorDraft
    let key: String
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.hakoPopRoute) private var popRoute
    @State private var text: String
    @State private var errorMessage = ""
     
     
    private let openedWith: String

    init(draft: ProxyNodeEditorDraft, key: String) {
        self.draft = draft
        self.key = key
        _text = State(initialValue: draft.jsonValue(key))
        openedWith = _text.wrappedValue
    }

    var body: some View {
        ProxyEditorSeat {
            HakoSection("JSON") {
                TextEditor(text: $text)
                    .accessibilityIdentifier("proxies.nodeEditor.field.\(key).json")
                    .font(.body.monospaced())
                    .frame(minHeight: 280)
            } footer: {
                if !errorMessage.isEmpty {
                    HakoStatusMessage(
                        text: .copy(errorMessage),
                        kind: .error
                    )
                    .accessibilityLabel("Invalid JSON")
                    .accessibilityValue(Text(HakoCopy.key(errorMessage)))
                    .accessibilityIdentifier(
                        "proxies.nodeEditor.field.\(key).json.error"
                    )
                }
            }
        }
            .hakoPageTitle(.verbatim(key), watchAs: "node-editor-field")
            .hakoDetailPageInsets()
            .toolbar {
                ToolbarItem(placement: .hakoNavigationTrailing) {
                     
                    if !insideProductModal {
                        HakoSaveButton(.copy("Done")) { save() }.font(.body.weight(.semibold))
                            .accessibilityIdentifier("proxies.nodeEditor.field.\(key).json.save")
                    }
                }
            }
            .hakoProductModalChild(title: key)
             
             
             
             
             
             
             
             
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                     
                     
                     
                     
                     
                     
                     
                    HakoModalActionBar(primaryTitle: "Done",
                                                 
                         
                         
                         
                         
                         
                        primaryDisabled: text == openedWith,
                        onPrimary: save)
                }
            }
    }

    private func save() {
        do {
            let data = Data(text.utf8)
            let value = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            guard ProxyJSONShapeValidator.acceptsContainer(value) else {
                errorMessage = "Enter a valid JSON array or object."
                return
            }
            draft.replaceJSONValue(value, key: key)
            finish()
        } catch {
            errorMessage = "Enter a valid JSON array or object."
        }
    }

    private func finish() {
#if os(macOS)
        if let popRoute {
            popRoute(HakoPopToken())
        } else {
            presentationMode.wrappedValue.dismiss()
        }
#else
         
         
         
        presentationMode.wrappedValue.dismiss()
#endif
    }
}

private struct ProxyJSONPathEditorView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @ObservedObject var draft: ProxyNodeEditorDraft
    let path: [String]
    let title: String
    let goType: String
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.hakoPopRoute) private var popRoute
    @State private var text: String
    @State private var errorMessage = ""
     
     
     
    private let openedWith: String

    init(
        draft: ProxyNodeEditorDraft,
        path: [String],
        title: String,
        goType: String
    ) {
        self.draft = draft
        self.path = path
        self.title = title
        self.goType = goType
        _text = State(initialValue: draft.jsonValue(path: path))
        openedWith = _text.wrappedValue
    }

    var body: some View {
        ProxyEditorSeat {
            HakoSection("JSON") {
                TextEditor(text: $text)
                    .accessibilityIdentifier(
                        "proxies.nodeEditor.field.\(path.joined(separator: ".")).json"
                    )
                    .font(.body.monospaced())
                    .frame(minHeight: 280)
            } footer: {
                if !errorMessage.isEmpty {
                    HakoStatusMessage(
                        text: .copy(errorMessage),
                        kind: .error
                    )
                    .accessibilityLabel("Invalid JSON")
                    .accessibilityValue(Text(HakoCopy.key(errorMessage)))
                    .accessibilityIdentifier(
                        "proxies.nodeEditor.field.\(path.joined(separator: ".")).json.error"
                    )
                }
            }
        }
            .hakoPageTitle(.copy(title))
            .hakoDetailPageInsets()
            .toolbar {
                ToolbarItem(placement: .hakoNavigationTrailing) {
                     
                    if !insideProductModal {
                        HakoSaveButton(.copy("Done")) { save() }.font(.body.weight(.semibold))
                            .accessibilityIdentifier(
                                "proxies.nodeEditor.field.\(path.joined(separator: ".")).json.save"
                            )
                    }
                }
            }
            .hakoProductModalChild(title: title)
             
             
             
             
             
             
             
             
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                     
                     
                     
                     
                     
                     
                     
                    HakoModalActionBar(primaryTitle: "Done",
                        primaryDisabled: text == openedWith,
                        onPrimary: save)
                }
            }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            draft.removeValue(path: path)
            finish()
            return
        }
        do {
            let value = try JSONSerialization.jsonObject(
                with: Data(trimmed.utf8),
                options: [.fragmentsAllowed]
            )
            guard ProxyJSONShapeValidator.accepts(value, goType: goType) else {
                errorMessage = ProxyJSONShapeValidator.errorMessage(
                    goType: goType
                )
                return
            }
            draft.replaceJSONValue(value, path: path)
            finish()
        } catch {
            errorMessage = "Enter a valid JSON value, array, or object."
        }
    }

    private func finish() {
#if os(macOS)
        if let popRoute {
            popRoute(HakoPopToken())
        } else {
            presentationMode.wrappedValue.dismiss()
        }
#else
         
         
         
        presentationMode.wrappedValue.dismiss()
#endif
    }
}

 
 
 
 
enum ProxyJSONShapeValidator {
    static func accepts(_ value: Any, goType: String) -> Bool {
        let type = String(goType.drop(while: { $0 == "*" }))
        if type.hasPrefix("map[") { return value is [String: Any] }
        if type.hasPrefix("[]") { return value is [Any] }
        return acceptsContainer(value)
    }

    static func acceptsContainer(_ value: Any) -> Bool {
        value is [String: Any] || value is [Any]
    }

    static func errorMessage(goType: String) -> String {
        let type = String(goType.drop(while: { $0 == "*" }))
        if type.hasPrefix("map[") {
            return "Enter a valid JSON object for this field."
        }
        if type.hasPrefix("[]") {
            return "Enter a valid JSON array for this field."
        }
        return "Enter a valid JSON array or object."
    }
}


 
 
 
 
 
 
 
 
 

 
 
 
 
 
 
 
 
 
 
 
 
 
 

 
 
 
 
 
enum ProxyNodeEditorDocumentFields {
    static let keys: Set<String> = [
        "ca", "certificate", "private-key", "client-certificate", "client-key",
        "tls-cert", "tls-key",
         
         
        "cert", "key", "tls-auth", "tls-crypt", "tls-crypt-v2",
    ]
}

enum ProxyNodeEditorSecretFields {
    static let keys: Set<String> = [
        "auth", "auth-key", "auth-str", "key", "obfs-password", "password", "pre-shared-key",
        "primary-key",
        "private-key", "private-key-passphrase", "psk", "secret", "tls-auth", "tls-crypt",
        "tls-crypt-v2", "token", "username", "uuid",
    ]

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static let plaintextAuthTypes: Set<String> = ["openvpn"]

    static let plainUsernameTypes: Set<String> = [
        "http", "socks5", "ssh", "mieru", "trusttunnel", "openvpn", "gost-relay",
    ]
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxyEditorFieldHint {
    static func text(forKey key: String, typeID: String) -> String {
        isRequired(key: key, typeID: typeID) ? "Required" : "Optional"
    }

     
     
     
    static func isRequired(key: String, typeID: String) -> Bool {
        ProxyProtocolEditorSchema.fields(for: typeID)
            .first { $0.key == key }?.required ?? false
    }
}

enum ProxyEditorPlatformNotes {
    private static let clientManagedKeys: Set<String> = ["state-dir"]

     
     
    static func clientManagedNote(forKey key: String) -> String? {
        guard clientManagedKeys.contains(key.lowercased()) else { return nil }
        return "Managed by Clash — the on-device state path is assigned automatically; edits here have no effect."
    }
}

