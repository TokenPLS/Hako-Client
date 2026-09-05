import HakoClientUI
import SwiftUI

enum CustomNodeAppendError: LocalizedError {
    case missingName

    var errorDescription: String? {
        switch self {
        case .missingName:
             
             
            return "Give the node a name before saving."
        }
    }
}

private enum CustomNodeRoute: Hashable, Identifiable {
    case add
     
     
    case addFromLink(String)
    case edit(String)

    var id: String {
        switch self {
        case .add: return "add"
         
         
         
        case .addFromLink(let json): return "add-from-link:\(json)"
        case .edit(let rowID): return "edit:\(rowID)"
        }
    }
}

 
 
 
enum CustomNodeAppend {
    static func appended(
        payload: [[String: Any]],
        editedJSON: String
    ) throws -> [[String: Any]] {
        guard var node = try JSONSerialization.jsonObject(with: Data(editedJSON.utf8))
                as? [String: Any] else {
            throw ProfileProviderDefinitionError.invalidPayload
        }
         
         
         
        let name = (node["name"] as? String) ?? ""
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CustomNodeAppendError.missingName
        }
        node["name"] = ProfileLabelPolicy.deduplicate(
            name,
            existing: payload.compactMap { $0["name"] as? String }
        )
        return payload + [node]
    }
}

 
 
 
 
 
 
 
 
struct CustomNodesView: View {
    let profile: Profile
    let sourceYAML: String?
    let loadDraft: () throws -> ProfileProviderDefinitionsDraft
    let prepareDraft: (() async throws -> ProfileProviderDefinitionsDraft)?
    let saveDraft: (ProfileProviderDefinitionsDraft) throws -> Void
     
     
     
     
     
     
     
    let savePayload: ((String?) throws -> Void)?
     
    let applyEdits: (() -> Void)?
     
     
     
     
     
     
     
    let isApplying: Bool
     
     
     
    let renameNode: (_ old: String, _ new: String) throws -> Void
    let ownsNavigationContainer: Bool
     
     

    static let customProviderName = "hako-custom"

     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoPushRoute) private var pushRoute
     
     
    @State private var addRequested = false
    @State private var draft: ProfileProviderDefinitionsDraft?
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @State private var hasLoadedOnce = false
    @State private var asksAboutUnsaved = false

     
     
     
     
     
     
    @State private var openedWith: [InlineProxyRow] = []
     
     
     
     
     
    @State private var pendingRenames: [(old: String, new: String)] = []

    private var hasUnsavedEdits: Bool {
         
         
         
         
        UnsavedEditPolicy.decision(
            original: openedWith.map(\.json).joined(separator: "\n"),
            current: customRows.map(\.json).joined(separator: "\n")
        ) == .offerToSave
    }
    @State private var customRows: [InlineProxyRow] = []
    @State private var errorMessage = ""
     
    @State private var fieldsLeftBehind = ""
     
     
     
     
    @State private var pastedNode: PastedNode?

    init(
        profile: Profile,
        sourceYAML: String?,
        ownsNavigationContainer: Bool = true,
        loadDraft: @escaping () throws -> ProfileProviderDefinitionsDraft,
        prepareDraft: (() async throws -> ProfileProviderDefinitionsDraft)? = nil,
        saveDraft: @escaping (ProfileProviderDefinitionsDraft) throws -> Void,
        savePayload: ((String?) throws -> Void)? = nil,
        applyEdits: (() -> Void)? = nil,
        isApplying: Bool = false,
        renameNode: @escaping (_ old: String, _ new: String) throws -> Void
    ) {
        self.profile = profile
        self.sourceYAML = sourceYAML
        self.ownsNavigationContainer = ownsNavigationContainer
        self.loadDraft = loadDraft
        self.prepareDraft = prepareDraft
        self.saveDraft = saveDraft
        self.savePayload = savePayload
        self.applyEdits = applyEdits
        self.isApplying = isApplying
        self.renameNode = renameNode
    }

    private var customPayload: [[String: Any]] {
        customRows.compactMap {
            try? JSONSerialization.jsonObject(with: Data($0.json.utf8))
                as? [String: Any]
        }
    }

    var body: some View {
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            content
        }
        .accessibilityIdentifier("custom-nodes")
        .onChange(of: addRequested) { requested in
            guard requested else { return }
            addRequested = false
             
             
            editorSelection = .add
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        .hakoProductModal(item: $editorSelection, role: .form) { route in
            HakoFeatureNavigationContainer {
                nodeDestination(for: route)
            }
            .hakoPageSizedSheet()
        }
         
         
         
         
         
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: hasUnsavedEdits || !pendingRenames.isEmpty,
            isBusy: isApplying,
            save: { completion in
                commitEdits()
                completion(true)
            },
            discard: { discardEdits() }
        )
        .hakoPageProbe("custom-nodes")
        .hakoCapturesDismiss(dismiss)
    }

     
    @State private var editorSelection: CustomNodeRoute?

    private var content: some View {
        HakoClientUI.HakoProfileCollectionPage(
            profileName: profile.label,
            message:
                "Hand-built nodes and subscription-node edits belong to this profile. Its imported source stays unchanged."
        ) {
            HakoSymbolImage(symbol: .profileClipboard)
        } content: {
            customSection
            shareLinkSection
        }
        .navigationTitle(HakoCopy.key("Custom Nodes"))
        .hakoStableNavigationDestination(for: CustomNodeRoute.self) {
            route in
            nodeDestination(for: route)
        }
        .hakoFeaturePresentation(
            ownsNavigationContainer: ownsNavigationContainer
        )
        .toolbar {
             
             
             
             
             
             
             
            ToolbarItem(placement: .cancellationAction) {
                 
                if ownsNavigationContainer, !insideProductModal {
                    Button("Cancel") {
                        if hasUnsavedEdits {
                            asksAboutUnsaved = true
                        } else {
                            dismiss()
                        }
                    }
                    .accessibilityIdentifier("custom-nodes.cancel")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                 
                 
                 
                 
                 
                Button {
                    commitEdits()
                } label: {
                     
                     
                     
                    if isApplying {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(hako: .copy("Saving…"))
                        }
                    } else {
                        Text(hako: .copy("Save"))
                    }
                }
                .disabled(isApplying || !hasUnsavedEdits)
                .accessibilityIdentifier("custom-nodes.save")
            }
        }
        .alert("Save your changes?", isPresented: $asksAboutUnsaved) {
             
             
            Button("Save") {
                commitEdits()
                 
                 
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    dismiss()
                }
            }
             
             
             
             
             
             
            Button("Discard", role: .destructive) {
                discardEdits()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    dismiss()
                }
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("These nodes have changes that have not been saved.")
        }
         
         
        .alert(
            HakoCopy.key("Could Not Save"),
            isPresented: showsError
        ) {
            Button("OK", role: .cancel) { errorMessage = "" }
        } message: {
            Text(hako: .copy(errorMessage))
        }
         
         
         
        .task { await reload() }
    }


    private var showsError: Binding<Bool> {
        Binding(get: { !errorMessage.isEmpty }, set: { if !$0 { errorMessage = "" } })
    }

     

    @ViewBuilder
    private var customSection: some View {
#if os(macOS)
         
         
         
         
         
         
         
        if customPayload.isEmpty {
            Section {
                emptyHint
            }
            Section {
                macAddRow
            } footer: {
                customFooter
            }
        } else {
            Section {
                nodeRows
                macAddRow
            } footer: {
                customFooter
            }
        }
#else
         
         
         
         
         
        if customPayload.isEmpty {
            Section { emptyHint }
            Section { touchAddRow } footer: { customFooter }
        } else {
            Section {
                touchNodeRows
                touchAddRow
            } footer: {
                customFooter
            }
        }
#endif
    }

     
     
     
    private var shareLinkSection: some View {
        Section {
            HStack {
                Text(HakoCopy.key("Add from a link"))
                Spacer()
                HakoPasteControl { importShareLinks($0) }
            }

             
             
            if let pastedNode {
#if os(macOS)
                Button {
                    editorSelection = .addFromLink(pastedNode.json)
                } label: {
                     
                     
                     
                     
                     
                     
                     
                     
                    nodeRow(name: pastedNode.name, type: pastedNode.type)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("custom-nodes.pasted.\(pastedNode.name)")
#else
                HakoStableNavigationLink(
                    value: CustomNodeRoute.addFromLink(pastedNode.json)
                ) {
                    ProxyNodeDetailsView(
                        record: Self.record(fromNodeJSON: pastedNode.json)
                            ?? Self.newNodeTemplate,
                        retest: {},
                        saveNode: { _, edited in
                            try appendCustomNode(json: edited)
                        },
                        showsTesting: false,
                        isNew: true,
                        dialerRouting: .payloadField,
                        dialerCandidates: { DialerProxyCandidates.make(
                            sourceYAML: sourceYAML,
                            excluding: ""
                        ) }
                    )
                } label: {
                    nodeRow(name: pastedNode.name, type: pastedNode.type)
                }
                .accessibilityIdentifier("custom-nodes.pasted")
#endif
                 
                 
                 
                 
                 
                if !fieldsLeftBehind.isEmpty {
                    Text(hako: .copy(fieldsLeftBehind))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("custom-nodes.pasted.fields-left-behind")
                }
            }
        } footer: {
            Text(HakoCopy.key("Paste a share link such as ss:// or vmess://. Its fields open in the editor for you to check before saving."))
        }
    }

     
    struct PastedNode: Equatable {
        let json: String
        let name: String
        let type: String
    }

     
     
     
     
     
     
     
     
     
    private var emptyHint: some View {
         
         
         
         
        HakoEmptyState(
            title: "No Custom Nodes",
            message: "A custom node is built by hand and belongs to this profile.",
            symbol: .serverRack
        )
        .listRowSeparator(.hidden)
    }

#if os(macOS)
    private var nodeRows: some View {
        ForEach(customRows) { row in
            if let record = Self.record(for: row) {
                Button {
                    editorSelection = .edit(row.id)
                } label: {
                     
                     
                     
                    nodeRow(name: record.name, type: record.type)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("custom-nodes.node.\(record.name)")
            }
        }
        .onDelete(perform: removeCustomNodes)
    }
#endif

#if os(macOS)
     
     
     
     
     
    private var macAddRow: some View {
        HakoAddRow(Text(HakoCopy.key("Add Node"))) {
            addRequested = true
        }
        .accessibilityIdentifier("custom-nodes.row.add")
    }
#else
     
     
    private var touchAddRow: some View {
        HakoAddRow(Text(HakoCopy.key("Add Node"))) {
            editorSelection = .add
        } touchLabel: {
            Label(HakoCopy.key("Add Node"), systemImage: HakoSymbol.plus.name)
        }
        .accessibilityIdentifier("custom-nodes.row.add")
    }

    private var touchNodeRows: some View {
        ForEach(customRows) { row in
            if let record = Self.record(for: row) {
                Button {
                    editorSelection = .edit(row.id)
                } label: {
                     
                     
                     
                    nodeRow(name: record.name, type: record.type)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("custom-nodes.node.\(record.name)")
            }
        }
        .onDelete(perform: removeCustomNodes)
    }
#endif

     
     
     
     
     
    private var customFooter: some View {
        Text(HakoCopy.key("Hand-built nodes appear under the Custom Nodes group, ready to pick in routes and as a rule policy."))
    }

    @ViewBuilder
    private func nodeDestination(
        for route: CustomNodeRoute
    ) -> some View {
        switch route {
        case .addFromLink(let json):
            ProxyNodeDetailsView(
                record: Self.record(fromNodeJSON: json) ?? Self.newNodeTemplate,
                retest: {},
                saveNode: { _, edited in
                    try appendCustomNode(json: edited)
                },
                showsTesting: false,
                isNew: true,
                dialerRouting: .payloadField,
                dialerCandidates: { DialerProxyCandidates.make(
                    sourceYAML: sourceYAML,
                    excluding: ""
                ) },
                onDone: { editorSelection = nil }
            )
        case .add:
            ProxyNodeDetailsView(
                record: Self.newNodeTemplate,
                retest: {},
                saveNode: { _, edited in
                    try appendCustomNode(json: edited)
                },
                showsTesting: false,
                isNew: true,
                dialerRouting: .payloadField,
                dialerCandidates: { DialerProxyCandidates.make(
                    sourceYAML: sourceYAML,
                    excluding: ""
                ) },
                onDone: { editorSelection = nil }
            )
        case .edit(let id):
            if let row = customRows.first(where: { $0.id == id }),
               let record = Self.record(for: row)
            {
                ProxyNodeDetailsView(
                    record: record,
                    retest: {},
                    saveNode: { _, edited in
                        try replaceCustomNode(id: row.id, json: edited)
                    },
                    showsTesting: false,
                    dialerRouting: .payloadField,
                    dialerCandidates: { DialerProxyCandidates.make(
                        sourceYAML: sourceYAML,
                        excluding: record.name
                    ) },
                    onDone: { editorSelection = nil }
                )
            } else {
                Text(hako: .copy("This node no longer exists."))
                    .foregroundStyle(.secondary)
                    .hakoPageTitle("Custom Nodes")
                    .hakoDetailPageInsets()
            }
        }
    }

     
     
     
     
     
    static func record(fromNodeJSON json: String) -> ProxyNodeRecord? {
        guard let node = try? JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any],
              let name = node["name"] as? String,
              let type = node["type"] as? String else { return nil }
        return ProxyNodeRecord(
            name: name,
            type: type,
            delay: nil,
            groupNames: [],
            protocolDetails: ProxyProtocolCatalog.details(for: node)
        )
    }

     
     
     
    private func importShareLinks(_ raw: String) {
        errorMessage = ""
        do {
            let (nodes, notHonoured) = try ShareLinkNodeImport.imported(from: raw)
            guard nodes.count == 1, let node = nodes.first else {
                errorMessage = "Paste one share link at a time. A whole panel's worth of links is a subscription — add it as a profile."
                return
            }
            guard let record = Self.record(fromNodeJSON: node) else {
                errorMessage = ShareLinkNodeImportError.notNodes.localizedDescription
                return
            }
            pastedNode = PastedNode(json: node, name: record.name, type: record.type)
             
             
             
            fieldsLeftBehind = notHonoured.map(\.message).joined(separator: "\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

     
     
    static var newNodeTemplate: ProxyNodeRecord {
         
         
         
         
        var template: [String: Any] = [
            "name": "",
            "type": "ss",
            "server": "",
            "cipher": "aes-128-gcm",
            "password": "",
        ]
        ProxyEditorNewNodeDefaults.applying(to: &template, typeID: "ss")
        return ProxyNodeRecord(
            name: "",
            type: "ss",
            delay: nil,
            groupNames: [],
            protocolDetails: ProxyProtocolCatalog.details(for: template)
        )
    }

    private func appendCustomNode(json: String) throws {
        try persistCustomPayloadOrThrow(
            try CustomNodeAppend.appended(payload: customPayload, editedJSON: json)
        )
    }

     
     
     
    private func replaceCustomNode(id: String, json: String) throws {
        guard let value = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw ProfileProviderDefinitionError.invalidPayload
        }
        guard let index = customRows.firstIndex(where: { $0.id == id }) else {
            throw ProfileProviderDefinitionError.invalidPayload
        }
        var payload = customPayload
        guard payload.indices.contains(index) else {
            throw ProfileProviderDefinitionError.invalidPayload
        }
         
         
         
         
        let previousName = payload[index]["name"] as? String
         
         
         
         
        let normalized = value
        let newName = normalized["name"] as? String
        if let newName, newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProfileProviderDefinitionError.invalidPayload
        }
         
         
        if let newName, newName != previousName,
           payload.enumerated().contains(where: {
               $0.offset != index && ($0.element["name"] as? String) == newName
           }) {
            throw ProfileProviderDefinitionError.invalidPayload
        }
        payload[index] = normalized
        let renamed = newName.flatMap { new in
            previousName.flatMap { old in old == new ? nil : (old, new) }
        }
        try persistCustomPayloadOrThrow(payload, renaming: renamed)
    }

    private func removeCustomNodes(at offsets: IndexSet) {
        let doomed = Set(offsets.compactMap { customRows.indices.contains($0) ? customRows[$0].id : nil })
        persistCustomPayload(
            customRows.filter { !doomed.contains($0.id) }.compactMap(\.mapping)
        )
    }

    private func persistCustomPayload(_ payload: [[String: Any]]) {
        do {
            try persistCustomPayloadOrThrow(payload)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

     
     
     
     
     
     
    private func persistCustomPayloadOrThrow(
        _ payload: [[String: Any]],
        renaming: (old: String, new: String)? = nil
    ) throws {
        let began = DispatchTime.now().uptimeNanoseconds
        defer {
            HakoPerf.note(
                "stage.node \(Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000)ms"
                    + " rows=\(customRows.count)"
            )
        }
        if let renaming { pendingRenames.append(renaming) }
        customRows = InlineProxyRow.rows(from: payload)
    }

     
     
     
     
     
     
     
     
    private func commitEdits() {
        let began = DispatchTime.now().uptimeNanoseconds
        defer {
            HakoPerf.note(
                "commit.nodes \(Double(DispatchTime.now().uptimeNanoseconds - began) / 1_000_000)ms"
                    + " rows=\(customRows.count) renames=\(pendingRenames.count)"
            )
        }
        guard hasUnsavedEdits || !pendingRenames.isEmpty else {
            dismiss()
            return
        }
        do {
            var payload = customPayload
            for rename in pendingRenames {
                payload = ProxyNodeRename.applying(
                    to: payload, from: rename.old, to: rename.new
                )
            }
            if let savePayload {
                try savePayload(CustomNodePayload.definitionJSON(for: payload))
            } else {
                 
                 
                 
                 
                guard var working = draft ?? (try? loadDraft()) else {
                    throw ProfileProviderDefinitionError.profileChanged
                }
                 
                 
                try CustomNodePayload.write(payload, into: &working)
                try saveDraft(working)
                draft = working
            }
            for rename in pendingRenames {
                try renameNode(rename.old, rename.new)
            }
            pendingRenames = []
            customRows = InlineProxyRow.rows(from: payload)
            openedWith = customRows
            applyEdits?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

     
     
    private func discardEdits() {
        customRows = openedWith
        pendingRenames = []
    }

     

    private static func record(for proxy: [String: Any]) -> ProxyNodeRecord? {
        guard let name = proxy["name"] as? String,
              let type = proxy["type"] as? String,
              let details = ProxyProtocolCatalog.details(for: proxy) else { return nil }
        return ProxyNodeRecord(
            name: name,
            type: type,
            delay: nil,
            groupNames: [],
            protocolDetails: details
        )
    }

     
     
    private static func record(for row: InlineProxyRow) -> ProxyNodeRecord? {
        guard let mapping = row.mapping else { return nil }
        return record(for: mapping)
    }

    private func nodeRow(name: String, type: String) -> some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            Text(name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(type)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var payloadFromOverride: String?? {
        guard let spec = profile.providerDefinitions else { return .some(nil) }
        guard let row = spec.proxyProviders.first(
            where: { $0.name == Self.customProviderName }
        ) else { return .some(nil) }
        return .some(row.definitionJSON)
    }

    @MainActor
    private func reload() async {
        do {
             
             
             
             
            if let stored = payloadFromOverride, !hasUnsavedEdits {
                hasLoadedOnce = true
                customRows = try CustomNodePayload.rows(inDefinition: stored)
                 
                 
                 
                openedWith = customRows
                return
            }
            guard prepareDraft != nil || !hasUnsavedEdits else { return }
            let loaded: ProfileProviderDefinitionsDraft
            if let prepareDraft {
                loaded = try await prepareDraft()
            } else {
                loaded = try loadDraft()
            }
            try apply(loaded)
        } catch {
            draft = nil
            customRows = []
            openedWith = []
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func apply(_ loaded: ProfileProviderDefinitionsDraft) throws {
        draft = loaded
        customRows = try CustomNodePayload.rows(
            inDefinition: loaded.records(kind: .proxy)
                .first { $0.name == Self.customProviderName }?
                .definitionJSON
        )
        openedWith = customRows
    }
}
