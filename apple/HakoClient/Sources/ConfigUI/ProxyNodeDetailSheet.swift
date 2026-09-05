import SwiftUI
import HakoClientUI
#if canImport(AppKit) && !canImport(UIKit)
import AppKit
#endif

 
struct ProxyNodeInspection: Identifiable, Equatable {
    let name: String
    var id: String { name }
}

 
 
 
 
enum ProxyNodeDetailLookup {
     
     
     
    enum Source: Equatable {
        case main
        case provider(String)
    }

    static func details(
        named name: String,
        yaml: String?,
        providersDir: URL?
    ) -> ProxyProtocolDetails? {
        locate(named: name, yaml: yaml, providersDir: providersDir)?.details
    }

    static func locate(
        named name: String,
        yaml: String?,
        providersDir: URL?
    ) -> (details: ProxyProtocolDetails, source: Source)? {
        if let yaml,
           let found = ProxyConfigurationInspector.detailsByNodeName(yaml: yaml)[name] {
            return (found, .main)
        }
        guard let providersDir,
              let catalog = ProviderCatalog.load(providersDir: providersDir) else {
            return nil
        }
        for entry in catalog.entries where entry.kind == "proxy" {
            let url = providersDir.appendingPathComponent(entry.path)
            guard let payload = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if let found = details(named: name, inProviderPayload: payload) {
                return (found, .provider(entry.name))
            }
        }
        return nil
    }

     
     
    static func details(
        named name: String,
        inProviderPayload payload: String
    ) -> ProxyProtocolDetails? {
        guard let parsed = ConfigTransforms.parsedRoot(forYAML: payload) else { return nil }
        return parsed.memo("proxies.protocolDetails") {
            ProxyConfigurationInspector.detailsByNodeName(root: parsed.root)
        }[name]
    }

     
     
     
    static func coveredValues(for details: ProxyProtocolDetails) -> [String: String] {
        guard let mapping = ProxyProtocolCatalog.mapping(from: details.configurationJSON) else {
            return [:]
        }
        var values: [String: String] = [:]
        for row in details.sections.flatMap(\.rows) {
            guard let key = row.key, let raw = mapping[key] else { continue }
            values[key] = asText(raw)
            if let nested = raw as? [String: Any] { collectLeaves(prefix: key, nested, into: &values) }
        }
        return values
    }

    private static func collectLeaves(prefix: String, _ nested: [String: Any], into values: inout [String: String]) {
        for (leaf, raw) in nested {
            if let deeper = raw as? [String: Any] { collectLeaves(prefix: "\(prefix).\(leaf)", deeper, into: &values) }
            else { values["\(prefix).\(leaf)"] = asText(raw) }
        }
    }

    private static func asText(_ raw: Any) -> String {
        switch raw {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        case let list as [Any]: return list.map(asText).joined(separator: ", ")
        default: return String(describing: raw)
        }
    }

     
     
     
     
    static func expandedRows(for details: ProxyProtocolDetails) -> [String: [ProxyProtocolDetailRow]] {
        guard let mapping = ProxyProtocolCatalog.mapping(from: details.configurationJSON) else {
            return [:]
        }
        var expanded: [String: [ProxyProtocolDetailRow]] = [:]
        for row in details.sections.flatMap(\.rows) where row.value == "Configured" {
            guard let key = row.key, let raw = mapping[key] else { continue }
            expanded[key] = leafRows(prefix: key, raw)
        }
        return expanded
    }

    private static func leafRows(prefix: String, _ raw: Any) -> [ProxyProtocolDetailRow] {
        if let nested = raw as? [String: Any] {
            return nested.keys.sorted().flatMap { leaf -> [ProxyProtocolDetailRow] in
                leafRows(prefix: "\(prefix).\(leaf)", nested[leaf] as Any)
            }
        }
        let text = asText(raw)
        let leaf = prefix.split(separator: ".").last.map(String.init) ?? prefix
        let covered = ProxyNodeDetailSheet.coveredKeys.contains(leaf.lowercased())
        return [.init(label: prefix, value: covered ? String(repeating: "•", count: 8) : text,
                      kind: covered ? .secret : .text, key: prefix)]
    }

     
     
    static func yaml(for details: ProxyProtocolDetails) -> String {
        (try? ConfigTransforms.jsonToYAML(details.configurationJSON))
            ?? details.configurationJSON
    }
}

 
 
 
 
 
struct ProxyNodeDetailSheet: View {
    let nodeName: String
    let yaml: String?
    let providersDir: URL?

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
     
     
     
     
    @Environment(\.hakoProductModalDismiss) private var productModalDismiss
    @State private var loaded = false
    @State private var details: ProxyProtocolDetails?
    @State private var covered: [String: String] = [:]
    @State private var expanded: [String: [ProxyProtocolDetailRow]] = [:]
    @State private var revealed: Set<String> = []
    @State private var copied = false

    var body: some View {
        HakoFeatureNavigationContainer {
            Form {
                if !loaded {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("proxy-detail.loading")
                } else if let details {
                    identity(details)
                    ForEach(details.sections) { section in
                        Section(HakoCopy.key(section.title)) {
                            ForEach(section.rows) { row in
                                detailRow(row)
                            }
                        }
                    }
                     
                     
                     
                    #if !os(macOS)
                    Section {
                        Button {
                            copyYAML(details)
                        } label: {
                            Label {
                                Text(HakoCopy.key(copied ? "Copied" : "Copy YAML"))
                            } icon: {
                                Image(systemName: HakoSymbol.docOnDoc.rawValue)
                            }
                        }
                        .accessibilityIdentifier("proxy-detail.copy-yaml")
                    }
                    #endif
                } else {
                    HakoEmptyState(
                        title: HakoCopy.string("No Details", locale: .current),
                        message: HakoCopy.string(
                            "This node is not in the configuration or in any of its providers.",
                            locale: .current
                        ),
                        symbol: .infoCircle
                    )
                    .accessibilityIdentifier("proxy-detail.empty")
                }
            }
            .accessibilityIdentifier("proxy-detail.sheet")
             
             
             
             
            #if os(macOS)
            .formStyle(.grouped)
             
             
             
             
             
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if loaded {
                     
                     
                     
                    macActionBar(details)
                }
            }
            #endif
            .hakoPageTitle("Node Details")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    HakoSheetCloseButton { dismiss() }
                }
            }
            .hakoProductModalRoot(title: HakoCopy.string("Node Details", locale: .current))
        }
        .task(id: nodeName) {
            let name = nodeName
            let source = yaml
            let directory = providersDir
            let found = await Task.detached(priority: .userInitiated) { () -> (ProxyProtocolDetails, [String: String], [String: [ProxyProtocolDetailRow]])? in
                guard let details = ProxyNodeDetailLookup.details(
                    named: name, yaml: source, providersDir: directory
                ) else { return nil }
                return (
                    details,
                    ProxyNodeDetailLookup.coveredValues(for: details),
                    ProxyNodeDetailLookup.expandedRows(for: details)
                )
            }.value
            details = found?.0
            covered = found?.1 ?? [:]
            expanded = found?.2 ?? [:]
            loaded = true
        }
        .hakoCapturesDismiss(dismiss)
    }

#if os(macOS)
     
     
     
    private func macActionBar(_ details: ProxyProtocolDetails?) -> some View {
        HStack(spacing: HakoTheme.Spacing.compact) {
            Spacer(minLength: 0)
            if let details {
                Button {
                    copyYAML(details)
                } label: {
                    Text(HakoCopy.key(copied ? "Copied" : "Copy YAML"))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("proxy-detail.copy-yaml")
            }
            Button {
                closePanel()
            } label: {
                Text(HakoCopy.key("Done"))
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("proxy-detail.done")
        }
        .padding(.horizontal, HakoTheme.Spacing.standard)
        .padding(.vertical, HakoTheme.Spacing.compact)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            ZStack(alignment: .top) {
                Rectangle().fill(.bar)
                Divider()
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private func closePanel() {
        if let productModalDismiss {
            productModalDismiss()
        } else {
            dismiss()
        }
    }
#endif

    private func identity(_ details: ProxyProtocolDetails) -> some View {
        Section {
            valueRow(HakoCopy.key("Name")) {
                Text(verbatim: nodeName)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("proxy-detail.name")
            }
            valueRow(HakoCopy.key("Protocol")) {
                Text(verbatim: details.displayName)
                    .accessibilityIdentifier("proxy-detail.protocol")
            }
        } footer: {
            Text(verbatim: details.summary)
        }
    }

     
     
     
     
    static let coveredKeys: Set<String> = [
        "password", "psk", "pre-shared-key", "private-key", "private-key-passphrase",
        "auth-key", "key", "obfs-password", "auth-str", "auth", "token", "secret",
        "tls-auth", "tls-crypt", "tls-crypt-v2",
    ]

    private func isCovered(_ row: ProxyProtocolDetailRow) -> Bool {
        guard let key = row.key else { return false }
        return Self.coveredKeys.contains(key.lowercased())
    }

     
     
    private func asWritten(_ row: ProxyProtocolDetailRow) -> String {
        row.key.flatMap { covered[$0] } ?? row.value
    }

    @ViewBuilder
    private func detailRow(_ row: ProxyProtocolDetailRow) -> some View {
        if row.value == "Configured", let key = row.key, let leaves = expanded[key], !leaves.isEmpty {
             
             
            ForEach(leaves) { leaf in
                leafRow(leaf)
            }
        } else if !isCovered(row) {
            valueRow(HakoCopy.key(row.label)) {
                Text(verbatim: asWritten(row))
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("proxy-detail.row.\(row.id)")
            }
        } else {
            coveredRow(row)
        }
    }

    @ViewBuilder
    private func leafRow(_ leaf: ProxyProtocolDetailRow) -> some View {
        if leaf.kind == .secret {
            coveredRow(leaf)
        } else {
            valueRow(LocalizedStringKey(leaf.label)) {
                Text(verbatim: leaf.value)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("proxy-detail.row.\(leaf.id)")
            }
        }
    }

    @ViewBuilder
    private func coveredRow(_ row: ProxyProtocolDetailRow) -> some View {
        switch row.kind {
        case .text, .toggle:
             
             
             
            valueRow(HakoCopy.key(row.label)) {
                Text(verbatim: row.value)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier("proxy-detail.row.\(row.id)")
            }
        case .secret, .privateText:
            let shown = revealed.contains(row.id)
            let written = asWritten(row)
            valueRow(HakoCopy.key(row.label)) {
                HStack(spacing: HakoTheme.Spacing.row) {
                    Text(verbatim: shown ? written : String(repeating: "•", count: 8))
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier("proxy-detail.row.\(row.id)")
                    Button {
                        if shown { revealed.remove(row.id) } else { revealed.insert(row.id) }
                    } label: {
                        Image(systemName: (shown ? HakoSymbol.eyeSlash : HakoSymbol.eye).rawValue)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text(HakoCopy.key(shown ? "Hide" : "Show")))
                    .accessibilityIdentifier("proxy-detail.reveal.\(row.id)")
                }
            }
        }
    }

     
     
    @ViewBuilder
    private func valueRow<Value: View>(
        _ label: LocalizedStringKey,
        @ViewBuilder value: () -> Value
    ) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            LabeledContent {
                value()
            } label: {
                Text(label)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.row) {
                Text(label)
                Spacer(minLength: HakoTheme.Spacing.row)
                value()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func copyYAML(_ details: ProxyProtocolDetails) {
        let text = ProxyNodeDetailLookup.yaml(for: details)
#if canImport(UIKit)
        CredentialPasteboardWrite.put(text)
#else
         
         
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copied = false
        }
    }
}

 
 
 
 
struct ProxyNodeEditorSheet: View {
    let nodeName: String
     
    let sourceYAML: String?
     
     
    let cachedProjection: String?
    let profile: Profile
    let providersDir: URL?
    @ObservedObject var profiles: ProfilesViewModel

     
    @State private var dismiss = HakoDismissHandle()
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss) private var productModalDismiss
    @State private var loaded = false
    @State private var projected: String?
    @State private var located: (details: ProxyProtocolDetails, source: ProxyNodeDetailLookup.Source)?
    @State private var overridden = false

    private func closeModal() {
        if let productModalDismiss {
            productModalDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        Group {
            if !loaded {
                HakoFeatureNavigationContainer {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("proxy-detail.loading")
                        .hakoPageTitle("Node Details")
                        .hakoToolbarUnlessInPanel {
                            ToolbarItem(placement: .cancellationAction) {
                                HakoSheetCloseButton { dismiss() }
                            }
                        }
                }
            } else if let located, located.source == .main,
                      ProxyNodeEditPolicy.isEditable(hasStoredSource: sourceYAML != nil) {
                HakoFeatureNavigationContainer {
                    ProxyNodeDetailsView(
                        record: ProxyNodeRecord(
                            name: nodeName,
                            type: located.details.typeID,
                            delay: nil,
                            groupNames: [],
                            protocolDetails: located.details
                        ),
                        retest: {},
                        saveNode: { original, edited in
                            try await profiles.updateProxyNode(originalJSON: original, editedJSON: edited)
                        },
                        allowsRename: false,
                        showsTesting: false,
                        subscriptionReset: overridden ? {
                            try profiles.removeProxyNodeOverride(named: nodeName)
                        } : nil,
                        onDone: { closeModal() }
                    )
                    .hakoToolbarUnlessInPanel {
                        ToolbarItem(placement: .cancellationAction) {
                            HakoSheetCloseButton { dismiss() }
                        }
                    }
                }
            } else {
                ProxyNodeDetailSheet(nodeName: nodeName, yaml: projected, providersDir: providersDir)
            }
        }
        .task(id: nodeName) {
            let name = nodeName
            let source = sourceYAML
            let cached = cachedProjection
            let current = profile
            let directory = providersDir
            let result = await Task.detached(priority: .userInitiated) { () -> (String?, (details: ProxyProtocolDetails, source: ProxyNodeDetailLookup.Source)?) in
                let yaml = cached ?? CustomNodesGroupMaterializer.projectForUI(sourceYAML: source, profile: current)
                return (yaml, ProxyNodeDetailLookup.locate(named: name, yaml: yaml, providersDir: directory))
            }.value
            projected = result.0
            located = result.1
            overridden = profiles.proxyNodeOverridePatch(named: name) != nil
            loaded = true
        }
        .hakoCapturesDismiss(dismiss)
    }
}
