import HakoClientUI
import SwiftUI
import UniformTypeIdentifiers

struct ProfileResourcesView: View {
    let profile: Profile
    let canManageProviders: Bool
    @ObservedObject private var vpn: VPNController
    @ObservedObject private var command: ClashCommandClient

     
     
     
    @State private var dismiss = HakoDismissHandle()
    private let summary: ProfileResourceSummary?
    private let summaryError: ProfileResourceSummaryError?

    init(
        profile: Profile,
        sourceYAML: String?,
        canManageProviders: Bool,
        vpn: VPNController,
        command: ClashCommandClient
    ) {
        self.profile = profile
        self.canManageProviders = canManageProviders
        _vpn = ObservedObject(wrappedValue: vpn)
        _command = ObservedObject(wrappedValue: command)
        guard let sourceYAML else {
            summary = nil
            summaryError = .sourceUnavailable
            return
        }
        do {
            summary = try ProfileResourceSummary(profile: profile, sourceYAML: sourceYAML)
            summaryError = nil
        } catch let bounded as ProfileResourceSummaryError {
            summary = nil
            summaryError = bounded
        } catch {
            summary = nil
            summaryError = .invalidConfiguration
        }
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            Form {
                Section {
                    HakoProfileContextHeader(
                        profileName: profile.label,
                        message:
                            "These proxy sources and rule sets belong to this profile and update without changing the original file."
                    ) {
                        HakoSymbolImage(symbol: .profileClipboard)
                    }
                }

                if let summaryError {
                    Section {
                        HakoStatusMessage(
                            text: .copy(summaryError.localizedDescription),
                            kind: .error
                        )
                    }
                } else if let summary {
                    if summary.proxyProviderCount > 0 || summary.ruleProviderCount > 0 {
                        Section {
                            if summary.proxyProviderCount > 0 {
                                providerDestination(
                                    title: "Proxy Sources",
                                    subtitle: countText(
                                        summary.proxyProviderCount,
                                        singular: "source",
                                        plural: "sources"
                                    ),
                                    symbol: .serverRack,
                                    tint: .purple,
                                    scope: .proxy,
                                    identifier: "profile-resources.proxy-providers"
                                )
                            }
                            if summary.ruleProviderCount > 0 {
                                providerDestination(
                                    title: "Rule Sets",
                                    subtitle: countText(
                                        summary.ruleProviderCount,
                                        singular: "set",
                                        plural: "sets"
                                    ),
                                    symbol: .listBulletRectangle,
                                    tint: .orange,
                                    scope: .rule,
                                    identifier: "profile-resources.rule-providers"
                                )
                            }
                        } header: {
                            Text("Profile Providers")
                        } footer: {
                            Text(canManageProviders
                                 ? "Sync and health actions use the validated provider copies for this profile."
                                 : "Prepare this profile once to sync providers or view their live status.")
                        }
                    }

                    if summary.supportingFileCount > 0 {
                        Section {
                            HStack(spacing: HakoTheme.Spacing.row) {
                                HakoIconWell(symbol: .docText, tint: .blue)
                                VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                                    Text("Supporting Files")
                                    Text(countText(
                                        summary.supportingFileCount,
                                        singular: "managed file",
                                        plural: "managed files"
                                    ))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, HakoTheme.Spacing.tight)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("profile-resources.supporting-files")
                        } header: {
                            Text("Imported With This Profile")
                        } footer: {
                            Text("Local paths and credentials stay private. Re-import the profile if one of its supporting files is missing.")
                        }
                    }

                    if !summary.hasResources {
                        Section {
                            HakoEmptyState(
                                title: "No External Resources",
                                message: "This profile keeps its proxies and rules directly in the configuration, so there is nothing separate to sync.",
                                symbol: .shippingbox
                            )
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .hakoInsetGroupedListStyle()
            .hakoPageTitle("Resources")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    HakoSheetCloseButton { dismiss() }
                }
            }
        }
        .hakoStackNavigationViewStyle()
        .accessibilityIdentifier("profile-resources.screen")
        .hakoCapturesDismiss(dismiss)
    }

    @ViewBuilder
    private func providerDestination(
        title: String,
        subtitle: String,
        symbol: HakoSymbol,
        tint: Color,
        scope: ProviderDisplayScope,
        identifier: String
    ) -> some View {
        if canManageProviders {
            HakoRoutedViewLink {
                ProvidersView(vpn: vpn, command: command, scope: scope)
            } label: {
                destinationLabel(
                    title: title,
                    subtitle: subtitle,
                    symbol: symbol,
                    tint: tint
                )
            }
            .accessibilityIdentifier(identifier)
        } else {
            destinationLabel(
                title: title,
                subtitle: subtitle,
                symbol: symbol,
                tint: tint
            )
            .accessibilityElement(children: .combine)
            .accessibilityHint("Prepare this profile to manage providers")
            .accessibilityIdentifier(identifier)
        }
    }

    private func destinationLabel(
        title: String,
        subtitle: String,
        symbol: HakoSymbol,
        tint: Color
    ) -> some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            HakoIconWell(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                Text(hako: .copy(title))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, HakoTheme.Spacing.tight)
    }

    private func countText(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}

 
 
 
struct ProfileProviderDefinitionsView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    let profile: Profile
    let kind: ProfileProviderKind
    let ownsNavigationContainer: Bool
    let load: () async throws -> ProfileProviderDefinitionsDraft
    let save: (ProfileProviderDefinitionsDraft) throws -> Void

     
    @State private var dismiss = HakoDismissHandle()
    @State private var draft: ProfileProviderDefinitionsDraft?

    @State private var editor: ProviderEditorSelection?
    @State private var errorMessage = ""
    @State private var isSaving = false

    init(
        profile: Profile,
        kind: ProfileProviderKind,
        ownsNavigationContainer: Bool = true,
        load: @escaping () async throws -> ProfileProviderDefinitionsDraft,
        save: @escaping (ProfileProviderDefinitionsDraft) throws -> Void
    ) {
        self.profile = profile
        self.kind = kind
        self.ownsNavigationContainer = ownsNavigationContainer
        self.load = load
        self.save = save
    }

    var body: some View {
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            Group {
                if let draft {
                    providerList(draft)
                } else if errorMessage.isEmpty {
                    HakoAsyncLoadingView()
                } else {
                    Form {
                        Section {
                            HakoStatusMessage(text: .copy(errorMessage), kind: .error)
                        }
                    }
                    .hakoInsetGroupedListStyle()
                }
            }
            .navigationTitle(kind == .proxy ? "Proxy Sources" : "Rule Sets")
            .hakoFeaturePresentation(
                ownsNavigationContainer: ownsNavigationContainer
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if ownsNavigationContainer {
                        Button("Cancel") { closePage() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                     
                     
                    if !insideProductModal {
                        HakoSaveButton { persist() }
                            .font(.body.weight(.semibold))
                            .disabled(draft == nil || isSaving)
                            .accessibilityIdentifier("provider-definitions.save")
                    }
                }
            }
        }
        .task { await loadDraftIfNeeded() }
        .hakoProductModal(
            item: $editor,
            role: .form,
            macOSPanelRole: .page
        ) { selection in
            HakoFeatureNavigationContainer {
                ProfileProviderDefinitionEditorView(
                    record: selection.record,
                    kind: kind,
                    save: applyEditorResult
                )
            }
            .hakoPageSizedSheet()
        }
        .alert(
            "Provider settings could not be saved",
            isPresented: Binding(
                get: { !errorMessage.isEmpty && draft != nil },
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
                    primaryTitle: "Save",
                    primaryDisabled: draft == nil,
                    isBusy: isSaving,
                    busyTitle: "Saving…",
                    onPrimary: persist
                )
            }
        }
         
         
         
         
         
        .hakoRegistersDeparture(
             
             
            isDirty: draft?.hasUnsavedChanges == true,
            isBusy: isSaving,
            save: { completion in
                persist()
                completion(true)
            },
             
             
            discard: { Task { draft = try? await load() } }
        )
        .hakoPageProbe("provider-definitions")
        .accessibilityIdentifier("provider-definitions.\(kind.rawValue).screen")
        .hakoCapturesDismiss(dismiss)
    }

    private func providerList(_ value: ProfileProviderDefinitionsDraft) -> some View {
        let records = value.records(kind: kind)
        return Form {
            Section {
                HakoProfileContextHeader(
                    profileName: profile.label,
                    message:
                        kind == .proxy
                            ? "These proxy sources supply nodes to this profile without changing its imported source."
                            : "These rule sets supply matching data to this profile without changing its imported source."
                ) {
                    HakoSymbolImage(symbol: .profileClipboard)
                }
            }

            Section {
#if os(macOS)
                 
                 
                 
                 
                if records.isEmpty {
                    HakoEmptyState(
                        title: kind == .proxy
                            ? "No Proxy Sources"
                            : "No Rule Sets",
                        message: kind == .proxy
                            ? "A proxy source supplies nodes to this profile. It is not itself a selectable route."
                            : "A rule set supplies reusable matching data to this profile’s routing rules.",
                        symbol: kind == .proxy
                            ? .serverRack
                            : .listBulletRectangle
                    )
                    .listRowSeparator(.hidden)
                }
#endif
                ForEach(records) { record in
                    Button {
                        editor = ProviderEditorSelection(record: record)
                    } label: {
                        HStack(spacing: HakoTheme.Spacing.row) {
                            HakoIconWell(
                                symbol: kind == .proxy ? .serverRack : .listBulletRectangle,
                                tint: kind == .proxy ? .purple : .orange
                            )
                            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                                Text(record.name)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(transportTitle(record.transport))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: HakoTheme.Spacing.compact)
                            Image(systemName: HakoSymbol.chevronForward.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, HakoTheme.Spacing.tight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "provider-definitions.\(kind.rawValue).\(record.name)"
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            remove(record)
                        } label: {
                            Label("Delete", systemImage: HakoSymbol.trash.name)
                        }
                        .tint(.red)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            remove(record)
                        } label: {
                            Label("Delete", systemImage: HakoSymbol.trash.name)
                        }
                        .accessibilityIdentifier(
                            "provider-definitions.\(kind.rawValue).\(record.name).delete"
                        )
                    }
                }
            } footer: {
#if os(macOS)
                 
                 
                 
                if !records.isEmpty {
                    Text(kind == .proxy
                         ? "A proxy source supplies nodes to this profile. It is not itself a selectable route."
                         : "A rule set supplies reusable matching data to this profile’s routing rules.")
                }
#else
                Text(kind == .proxy
                     ? "A proxy source supplies nodes to this profile. It is not itself a selectable route."
                     : "A rule set supplies reusable matching data to this profile’s routing rules.")
#endif
            }

            Section {
                HakoAddRow(
                    Text(HakoCopy.key(
                        kind == .proxy ? "Add Proxy Source" : "Add Rule Set"
                    ))
                ) {
                    editor = ProviderEditorSelection(record: nil)
                } touchLabel: {
                    Label(
                        kind == .proxy ? "Add Proxy Source" : "Add Rule Set",
                        systemImage: HakoSymbol.plus.name
                    )
                }
                .accessibilityIdentifier("provider-definitions.\(kind.rawValue).add")
            }
        }
        .hakoInsetGroupedListStyle()
    }

    @MainActor
    private func loadDraftIfNeeded() async {
        guard draft == nil else { return }
        do {
            draft = try await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyEditorResult(_ result: ProviderEditorResult) throws {
        guard var value = draft else {
            throw ProfileProviderDefinitionError.profileChanged
        }
        if let original = result.originalName {
            if original != result.name {
                try value.renameDefinition(named: original, to: result.name, kind: kind)
            }
            try value.updateDefinition(
                named: result.name,
                kind: kind,
                definitionJSON: result.definitionJSON
            )
        } else {
            try value.addDefinition(
                named: result.name,
                kind: kind,
                definitionJSON: result.definitionJSON
            )
        }
        if result.transport == .file {
            try value.setManagedFile(result.managedFile, for: result.name, kind: kind)
        }
        draft = value
    }

    private func remove(_ record: ProfileProviderDefinitionRecord) {
        guard var value = draft else { return }
        do {
            try value.removeDefinition(named: record.name, kind: kind)
            draft = value
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persist() {
        guard let value = draft else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try save(value)
            closePage()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func transportTitle(_ transport: ProfileProviderTransport) -> String {
        switch transport {
        case .http: return "http · downloaded by the app"
        case .file: return "file · managed local copy"
        case .inline: return "inline · stored in this profile"
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

private struct ProviderEditorSelection: Identifiable {
    let id = UUID()
    let record: ProfileProviderDefinitionRecord?
}

private struct ProviderEditorResult {
    let originalName: String?
    let name: String
    let transport: ProfileProviderTransport
    let definitionJSON: String
    let managedFile: ExternalResourceImportFile?
}

private enum ProviderEditorModalChild {
    case healthCheck
    case proxyOverride
}

private struct ProfileProviderDefinitionEditorView: View {
    let save: (ProviderEditorResult) throws -> Void

     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss) private var modalDismiss
    @StateObject private var draft: ProfileProviderDefinitionEditorDraft
    @State private var selectedFile: ExternalResourceImportFile?
    @State private var showsFileImporter = false
    @State private var errorMessage = ""
    @State private var modalChild: ProviderEditorModalChild?

    init(
        record: ProfileProviderDefinitionRecord?,
        kind: ProfileProviderKind,
        save: @escaping (ProviderEditorResult) throws -> Void
    ) {
        self.save = save
        _draft = StateObject(wrappedValue: ProfileProviderDefinitionEditorDraft(
            record: record,
            kind: kind
        ))
    }

    var body: some View {
        Group {
#if os(macOS)
            if let modalChild {
                modalChildView(modalChild)
            } else {
                editorForm
            }
#else
            editorForm
#endif
        }
        .hakoCapturesDismiss(dismiss)
    }

    private var editorForm: some View {
        Form {
            identitySection
            sourceSection
            if draft.kind == .rule { ruleShapeSection }
            if draft.kind == .proxy { proxySelectionSection }
            if draft.unknownFieldCount > 0 {
                Section {
                    HStack {
                        Text("Raw fields")
                        Spacer()
                        Text("\(draft.unknownFieldCount) preserved")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Fields not yet represented by a native control remain byte-for-byte equivalent in the generated provider object.")
                }
            }
        }
#if os(macOS)
         
         
         
        .formStyle(.grouped)
#else
        .hakoInsetGroupedListStyle()
#endif
        .navigationTitle(editorTitle)
#if !os(macOS)
         
         
         
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done", action: persist)
                    .font(.body.weight(.semibold))
                    .accessibilityIdentifier("provider-definition.done")
            }
        }
#endif
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if HakoPlatformLayout.modalEditorUsesGroupedForm {
                 
                 
                 
                HakoModalActionBar(
                    primaryTitle: "Done",
                    primaryDisabled: draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onPrimary: persist
                )
            }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.data, .text],
            allowsMultipleSelection: false,
            onCompletion: importFile
        )
        .alert(
            "Provider could not be saved",
            isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = "" }
        } message: {
            Text(hako: .copy(errorMessage))
        }
        .accessibilityIdentifier(
            "provider-definition.\(draft.kind.rawValue).\(draft.transport.rawValue)"
        )
         
        .hakoRegistersDeparture(
            isDirty: draft.hasUnsavedChanges,
            save: { completion in
                persist()
                completion(true)
            },
            discard: {}
        )
        .hakoProductModalRoot(title: editorTitle)
    }

    private var editorTitle: String {
        draft.originalName == nil ? "Add Provider" : "Edit Provider"
    }

    @ViewBuilder
    private func modalChildView(_ child: ProviderEditorModalChild) -> some View {
        switch child {
        case .healthCheck:
            ProviderHealthCheckEditorView(draft: draft)
                .hakoProductModalChild(
                    title: "Health Check",
                    backAction: { modalChild = nil }
                )
        case .proxyOverride:
            ProviderProxyOverrideEditorView(draft: draft)
                .hakoProductModalChild(
                    title: "Node Overrides",
                    backAction: { modalChild = nil }
                )
        }
    }

    private var identitySection: some View {
        Section {
            HakoFieldRow(
                "Name",
                hint: "provider1",
                text: $draft.name,
                monospaced: true,
                identifier: "provider-definition.name"
            )
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
            transportRow
        }
    }

    private func transportDetail(_ transport: ProfileProviderTransport) -> String {
        switch transport {
        case .http: return "Downloaded by the app over HTTP or HTTPS"
        case .file: return "A local file copied into the protected store"
        case .inline: return "Content stored inside this profile"
        }
    }

    @ViewBuilder
    private var transportRow: some View {
        let selection = Binding(
            get: { draft.transport },
            set: { draft.transport = $0 }
        )
#if os(macOS)
        Menu {
            Picker("Source", selection: selection) {
                Text(verbatim: "http")
                    .tag(ProfileProviderTransport.http)
                Text(verbatim: "file")
                    .tag(ProfileProviderTransport.file)
                Text(verbatim: "inline")
                    .tag(ProfileProviderTransport.inline)
            }
                .accessibilityIdentifier("provider-definition.source")
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
             
             
             
             
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(verbatim: draft.transport.rawValue)
                    .font(.body.monospaced())
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
            .accessibilityLabel("Source")
            .accessibilityValue(draft.transport.rawValue)
            .accessibilityIdentifier("provider-definition.transport")
        }
        .buttonStyle(.plain)
        .fixedSize()
        .hakoProviderSourceRowLabel(detail: transportDetail(draft.transport))
#else
        HStack(alignment: .center, spacing: HakoTheme.Spacing.row) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Source")
                Text(transportDetail(draft.transport))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            Picker("Source", selection: selection) {
                Text(verbatim: "http")
                    .tag(ProfileProviderTransport.http)
                Text(verbatim: "file")
                    .tag(ProfileProviderTransport.file)
                Text(verbatim: "inline")
                    .tag(ProfileProviderTransport.inline)
            }
            .labelsHidden()
        }
        .accessibilityIdentifier("provider-definition.transport")
#endif
    }

    @ViewBuilder
    private var sourceSection: some View {
        switch draft.transport {
        case .http:
            Section {
                providerTextRow("URL", path: ["url"], placeholder: "https://example.com/provider.yaml")
                providerNumberRow("Update every", path: ["interval"],
                                  placeholder: "3600", suffix: "sec")
                providerNumberRow("Size limit", path: ["size-limit"],
                                  suffix: "bytes")
                HakoRoutedViewLink {
                    ProviderHeadersEditorView(draft: draft)
                } label: {
                    HStack {
                        Text("Request Headers")
                        Spacer()
                        Text(draft.headers().isEmpty ? "None" : "\(draft.headers().count) configured")
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier(
                    "provider-definition.headers-link"
                )
                if draft.kind == .proxy {
                    HakoFieldRow(
                        "Age secret key",
                        hint: "AGE-SECRET-KEY-…",
                        text: textBinding(["age-secret-key"]),
                        secure: true,
                        identifier: "provider-definition.age-secret-key"
                    )
                }
                if !draft.string(path: ["proxy"])
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label(
                        "The source fetch proxy is preserved. On iOS, Clash downloads this provider directly and uses the cached copy if refresh fails.",
                        systemImage: HakoSymbol.infoCircle.name
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Download")
            } footer: {
                Text("Empty size limit means no limit. Clash downloads HTTPS providers in the app, validates them, and publishes an immutable local copy before Core loads it.")
            }
        case .file:
            Section {
#if os(macOS)
                 
                 
                 
                Button {
                    showsFileImporter = true
                } label: {
                    HStack {
                        Text("Selected File")
                            .lineLimit(1)
                            .layoutPriority(1)
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        Text(draft.string(path: ["path"]).isEmpty
                             ? "Required"
                             : draft.string(path: ["path"]))
                            .foregroundStyle(draft.string(path: ["path"]).isEmpty
                                             ? Color.secondary.opacity(0.6)
                                             : Color.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("Choose…")
                            .font(.callout)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(Color.white.opacity(0.09))
                            )
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeight,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("provider-definition.choose-file")
#else
                HStack {
                    Text("Selected File")
                    Spacer()
                    Text(draft.string(path: ["path"]).isEmpty
                         ? "Required" : draft.string(path: ["path"]))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Button("Choose File") { showsFileImporter = true }
                    .accessibilityIdentifier("provider-definition.file.choose")
#endif
            } header: {
                Text("Managed Local File")
            } footer: {
                Text("The selected public provider file is copied into this profile’s protected resource store. Its original device path is never used at runtime.")
            }
        case .inline:
            Section {
                if draft.kind == .proxy {
                    HakoRoutedViewLink {
                        ProviderInlineProxyPayloadView(draft: draft)
                    } label: {
                        HStack {
                            Text("Proxy Nodes")
                            Spacer()
                            Text("\(draft.proxyPayload().count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("provider-definition.inline.proxy-payload-link")
                } else {
                    HakoRoutedViewLink {
                        ProviderInlineRulePayloadView(draft: draft)
                    } label: {
                        HStack {
                            Text("Rules")
                            Spacer()
                            Text("\(draft.rulePayload().count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("provider-definition.inline.rule-payload-link")
                }
            } header: {
                Text("Inline Content")
            } footer: {
                Text("Inline content belongs to this profile overlay and survives subscription refresh without changing the imported source.")
            }
        }
    }

    private var ruleShapeSection: some View {
        Section {
            providerShapeMenuRow(
                "Behavior",
                selection: behaviorBinding,
                values: ["classical", "domain", "ipcidr"],
                identifier: "provider-definition.behavior"
            )
            providerShapeMenuRow(
                "Format",
                selection: textBinding(
                    ["format"],
                    defaultValue: "yaml"
                ),
                values:
                    draft.string(path: ["behavior"])
                        == "classical"
                    ? ["yaml", "text"]
                    : ["yaml", "text", "mrs"],
                identifier: "provider-definition.format"
            )
        } footer: {
            Text("Behavior says what each line in the file is. mrs is binary and only carries domain or ipcidr.")
        }
    }

    @ViewBuilder
    private func providerShapeMenuRow(
        _ title: String,
        selection: Binding<String>,
        values: [String],
        identifier: String
    ) -> some View {
#if os(macOS)
        Menu {
            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text(verbatim: value).tag(value)
                }
            }
                .accessibilityIdentifier("provider-definition.choice")
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
             
             
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(verbatim: selection.wrappedValue)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                Image(
                    systemName:
                        HakoSymbol.chevronUpChevronDown.name
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .frame(
                minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeight,
                alignment: .leading
            )
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(title)
            .accessibilityValue(selection.wrappedValue)
            .accessibilityIdentifier(identifier)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .hakoSettingsMenuRow(title)
#else
        Picker(title, selection: selection) {
            ForEach(values, id: \.self) { value in
                Text(verbatim: value).tag(value)
            }
        }
        .accessibilityIdentifier(identifier)
#endif
    }

    private var proxySelectionSection: some View {
        Group {
            Section {
                providerTextRow("Include filter", path: ["filter"],
                                placeholder: "(?i)hk|港")
                providerTextRow("Exclude filter", path: ["exclude-filter"])
                providerTextRow("Exclude types", path: ["exclude-type"],
                                placeholder: "ss|http")
            } header: {
                Text("Selection")
            } footer: {
                Text("Filters are regular expressions; join several with |. Exclude types lists node types, | separated, no regex.")
            }
            Section {
#if os(macOS)
                providerModalChildButton(
                    "Health Check",
                    child: .healthCheck,
                    identifier: "provider-definition.health-check-link"
                )
                providerModalChildButton(
                    "Node Overrides",
                    child: .proxyOverride,
                    identifier: "provider-definition.override-link"
                )
#else
                HakoRoutedViewLink {
                    ProviderHealthCheckEditorView(draft: draft)
                } label: {
                    Text("Health Check")
                }
                .accessibilityIdentifier(
                    "provider-definition.health-check-link"
                )
                HakoRoutedViewLink {
                    ProviderProxyOverrideEditorView(draft: draft)
                } label: {
                    Text("Node Overrides")
                }
                .accessibilityIdentifier(
                    "provider-definition.override-link"
                )
#endif
            } footer: {
                Text("Health checks and overrides are applied by Core after the provider has been validated and materialized.")
            }
        }
    }

#if os(macOS)
    private func providerModalChildButton(
        _ title: String,
        child: ProviderEditorModalChild,
        identifier: String
    ) -> some View {
        Button {
            modalChild = child
        } label: {
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(hako: .copy(title))
                Spacer(minLength: HakoTheme.Spacing.compact)
                Image(systemName: HakoSymbol.chevronForward.rawValue)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
#endif

    private func providerTextRow(
        _ title: String,
        path: [String],
        placeholder: String = "Optional"
    ) -> some View {
        HakoFieldRow(
            title,
            hint: placeholder,
            text: textBinding(path),
            identifier:
                "provider-definition.\(path.joined(separator: "."))"
        )
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
    }

    private func providerNumberRow(
        _ title: String,
        path: [String],
        placeholder: String = "Optional",
        suffix: String? = nil
    ) -> some View {
        HakoFieldRow(
            title,
            hint: placeholder,
            text: numberBinding(path),
            suffix: suffix,
            identifier:
                "provider-definition.\(path.joined(separator: "."))"
        )
        .keyboardType(.numberPad)
    }

    private func textBinding(
        _ path: [String],
        defaultValue: String = ""
    ) -> Binding<String> {
        Binding(
            get: {
                let value = draft.string(path: path)
                return value.isEmpty ? defaultValue : value
            },
            set: { draft.setString($0, path: path) }
        )
    }

     
     
     
     
    private var behaviorBinding: Binding<String> {
        Binding(
            get: {
                let value = draft.string(path: ["behavior"])
                return value.isEmpty ? "classical" : value
            },
            set: { newValue in
                draft.setString(newValue, path: ["behavior"])
                if newValue == "classical", draft.string(path: ["format"]) == "mrs" {
                    draft.setString("yaml", path: ["format"])
                }
            }
        )
    }

    private func numberBinding(_ path: [String]) -> Binding<String> {
        Binding(
            get: { draft.string(path: path) },
            set: { draft.setString($0, path: path, number: true) }
        )
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                throw ProfileProviderDefinitionError.missingManagedFile
            }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
             
             
             
            let requiresUTF8Text = draft.string(path: ["format"]).lowercased() != "mrs"
            guard !data.isEmpty,
                  data.count <= ProfileExternalResourceImporter.maximumResourceBytes,
                  !requiresUTF8Text || String(data: data, encoding: .utf8) != nil else {
                throw ProfileProviderDefinitionError.missingManagedFile
            }
            let file = ExternalResourceImportFile(fileName: url.lastPathComponent, data: data)
            selectedFile = file
            draft.setString(file.fileName, path: ["path"], omitWhenEmpty: false)
        } catch {
            errorMessage = ProfileProviderDefinitionError.missingManagedFile.localizedDescription
        }
    }

    private func persist() {
        do {
             
             
             
             
            if let rejection = ProfileProviderDefinitionError.rejecting(draft.name) {
                throw rejection
            }
            let definition = try draft.validatedDefinitionJSON()
            try save(ProviderEditorResult(
                originalName: draft.originalName,
                name: draft.name,
                transport: draft.transport,
                definitionJSON: definition,
                managedFile: selectedFile
            ))
            (modalDismiss ?? { dismiss() })()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ProviderHeaderDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var value: String

    init(id: UUID = UUID(), name: String = "", value: String = "") {
        self.id = id
        self.name = name
        self.value = value
    }
}

private struct ProviderHeadersEditorView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @Environment(\.hakoPopRoute) private var popRoute
    @ObservedObject var draft: ProfileProviderDefinitionEditorDraft
    @Environment(\.presentationMode) private var presentationMode
    @State private var rows: [ProviderHeaderDraft]
     
     
    @State private var openedWith: [ProviderHeaderDraft] = []
    @State private var errorMessage = ""

    init(draft: ProfileProviderDefinitionEditorDraft) {
        self.draft = draft
        _rows = State(initialValue: draft.headers().map {
            ProviderHeaderDraft(name: $0.name, value: $0.value)
        })
    }

    var body: some View {
        Form {
            Section {
                ForEach($rows) { $row in
                    HakoMacDeletableRow(onDelete: {
                        if let index = rows.firstIndex(
                            where: { $0.id == row.id }
                        ) {
                            rows.remove(at: index)
                        }
                    }) {
                    VStack(alignment: .leading, spacing: 0) {
                        HakoFieldRow(
                            "Header Name",
                            hint: "Required",
                            text: $row.name,
                            identifier:
                                "provider-definition.header.name"
                        )
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                        Divider()
                        HakoFieldRow(
                            "Header Value",
                            hint: "Required",
                            text: $row.value,
                            secure: true,
                            identifier:
                                "provider-definition.header.value"
                        )
                    }
                    }
                }
                .onDelete { rows.remove(atOffsets: $0) }
                HakoAddRow(Text("Add Header")) {
                    rows.append(ProviderHeaderDraft())
                } touchLabel: {
                    Label("Add Header", systemImage: HakoSymbol.plus.name)
                }
                .accessibilityIdentifier(
                    "provider-definition.headers.add"
                )
            } footer: {
                Text("Header values are treated as credentials and are never shown in previews or diagnostics.")
            }
        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle("Request Headers")
        .hakoDetailPageInsets()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                 
                if !insideProductModal {
                    Button("Done", action: persist)
                        .font(.body.weight(.semibold))
                        .accessibilityIdentifier("provider-headers.done")
                }
            }
        }
        .alert(
            "Headers could not be saved",
            isPresented: Binding(
                get: { !errorMessage.isEmpty },
                set: { if !$0 { errorMessage = "" } }
            )
        ) {
            Button("OK", role: .cancel) { errorMessage = "" }
        } message: {
            Text(hako: .copy(errorMessage))
        }
        .hakoProductModalChild(title: "Request Headers")
             
             
             
             
             
             
             
             
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                     
                     
                     
                     
                     
                     
                     
                HakoModalActionBar(primaryTitle: "Done",
                                         
                     
                     
                     
                     
                     
                    primaryDisabled: rows == openedWith,
                    onPrimary: persist)
            }
        }
        .onAppear { if openedWith.isEmpty { openedWith = rows } }
    }

    private func persist() {
        let cleaned = rows.map {
            (name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), value: $0.value)
        }.filter { !$0.name.isEmpty || !$0.value.isEmpty }
        guard cleaned.allSatisfy({ !$0.name.isEmpty && !$0.value.isEmpty }),
              Set(cleaned.map { $0.name.lowercased() }).count == cleaned.count else {
            errorMessage = ProfileProviderDefinitionError.invalidHeader.localizedDescription
            return
        }
        draft.replaceHeaders(cleaned)
        closeAfterCommit()
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func closeAfterCommit() {
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

private struct ProviderHealthCheckEditorView: View {
    @ObservedObject var draft: ProfileProviderDefinitionEditorDraft

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: boolBinding(["health-check", "enable"]))
                    .frame(minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
                    .accessibilityIdentifier(
                        "provider-definition.health-check.enable"
                    )
                textRow("Test URL", path: ["health-check", "url"], placeholder: "https://www.gstatic.com/generate_204")
                numberRow("Check every", path: ["health-check", "interval"], suffix: "sec")
                numberRow("Timeout", path: ["health-check", "timeout"], suffix: "ms")
                Toggle(isOn: boolBinding(["health-check", "lazy"])) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lazy")
                        Text("Skip testing while this provider's nodes are unused")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
                .accessibilityIdentifier(
                    "provider-definition.health-check.lazy"
                )
                textRow("Expected status", path: ["health-check", "expected-status"],
                        placeholder: "204")
            } footer: {
                Text("Core runs this check against provider nodes after the provider is available. Empty values use the core's defaults.")
            }
        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle("Health Check")
        .hakoDetailPageInsets()
        .accessibilityIdentifier("provider-definition.health-check")
    }

    private func textRow(
        _ title: String,
        path: [String],
        placeholder: String = "Optional"
    ) -> some View {
        HakoFieldRow(
            title,
            hint: placeholder,
            text: Binding(
                get: { draft.string(path: path) },
                set: { draft.setString($0, path: path) }
            ),
            identifier:
                "provider-definition.\(path.joined(separator: "."))"
        )
        .disableAutocorrection(true)
        .textInputAutocapitalization(.never)
    }

    private func numberRow(
        _ title: String,
        path: [String],
        suffix: String? = nil
    ) -> some View {
        HakoFieldRow(
            title,
            hint: "Optional",
            text: Binding(
                get: { draft.string(path: path) },
                set: { draft.setString($0, path: path, number: true) }
            ),
            suffix: suffix,
            identifier:
                "provider-definition.\(path.joined(separator: "."))"
        )
        .keyboardType(.numberPad)
    }

    private func boolBinding(_ path: [String]) -> Binding<Bool> {
        Binding(
            get: { draft.bool(path: path) },
            set: { draft.setBool($0, path: path) }
        )
    }
}

private struct ProviderProxyOverrideEditorView: View {
    @ObservedObject var draft: ProfileProviderDefinitionEditorDraft

    private let optionalBooleans: [(String, String)] = [
        ("TCP Fast Open", "tfo"),
        ("Multipath TCP", "mptcp"),
        ("UDP", "udp"),
        ("UDP over TCP", "udp-over-tcp"),
        ("Skip Certificate Verification", "skip-cert-verify"),
    ]
    private let numbers: [(String, String)] = [
        ("Upload Rate", "up"),
        ("Download Rate", "down"),
         
         
         
         
    ]
    private let strings: [(String, String)] = [
        ("Dialer Proxy", "dialer-proxy"),
        ("IP Version", "ip-version"),
        ("Cert Verify Hostname", "name-cert-verify"),
        ("Name Prefix", "additional-prefix"),
        ("Name Suffix", "additional-suffix"),
    ]

    var body: some View {
        Form {
            Section("Capabilities") {
                ForEach(optionalBooleans, id: \.1) { title, key in
                    Picker(title, selection: optionalBoolBinding(key)) {
                        Text("Use Node Value").tag(Optional<Bool>.none)
                        Text("On").tag(Optional(true))
                        Text("Off").tag(Optional(false))
                    }
                    .frame(
                        maxWidth: .infinity,
                        minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform,
                        alignment: .leading
                    )
                    .accessibilityIdentifier("provider-definition.override.\(key)")
                }
            }
            Section("Limits") {
                ForEach(numbers, id: \.1) { title, key in
                    textRow(title, key: key, number: true)
                }
            }
            Section("Identity & Dialing") {
                ForEach(strings, id: \.1) { title, key in
                    textRow(title, key: key, number: false)
                }
                 
                 
                 
                HStack {
                    Text("Proxy Name Rules")
                    Spacer(minLength: HakoTheme.Spacing.compact)
                    Text(draft.overrideProxyNameSummary() ?? "None")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Proxy Name Rules")
                .accessibilityValue(
                    draft.overrideProxyNameSummary() ?? "None"
                )
                .accessibilityIdentifier("provider-definition.override.proxy-name")
                 
                 
                 
                HStack {
                    Text("Rewrite Expressions")
                    Spacer(minLength: HakoTheme.Spacing.compact)
                    Text(draft.overrideExprSummary() ?? "None")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rewrite Expressions")
                .accessibilityValue(
                    draft.overrideExprSummary() ?? "None"
                )
                .accessibilityIdentifier("provider-definition.override.override-expr")
            }
        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle("Node Overrides")
        .hakoDetailPageInsets()
        .accessibilityIdentifier("provider-definition.override")
    }

    private func textRow(_ title: String, key: String, number: Bool) -> some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
            HakoFieldRow(
                title,
                hint: "Optional",
                text: Binding(
                    get: { draft.string(path: ["override", key]) },
                    set: { draft.setString($0, path: ["override", key], number: number) }
                ),
                identifier: "provider-definition.override.\(key)"
            )
            .keyboardType(number ? .numberPad : .default)
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
        }
    }

    private func optionalBoolBinding(_ key: String) -> Binding<Bool?> {
        Binding(
            get: { draft.optionalBool(path: ["override", key]) },
            set: { draft.setOptionalBool($0, path: ["override", key]) }
        )
    }
}

private struct ProviderInlineProxyPayloadView: View {
    @ObservedObject var draft: ProfileProviderDefinitionEditorDraft

    var body: some View {
        Form {
            Section {
                ForEach(InlineProxyRow.rows(from: draft.proxyPayload())) { row in
                    if let mapping = row.mapping, let record = record(for: mapping) {
                        HakoRoutedViewLink {
                            HakoLazyView {
                                ProxyNodeDetailsView(
                                    record: record,
                                    retest: {},
                                    saveNode: { _, edited in
                                        try replaceProxy(id: row.id, json: edited)
                                    },
                                     
                                     
                                     
                                    allowsRename: false,
                                    showsTesting: false,
                                     
                                     
                                     
                                     
                                     
                                     
                                     
                                    commitTitle: "Done"
                                )
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                                Text(record.name)
                                    .foregroundStyle(.primary)
                                Text(record.protocolDetails?.displayName ?? record.type)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier(
                            "provider-definition.inline.proxy.\(record.name)"
                        )
                        .contextMenu {
                            Button(role: .destructive) {
                                remove(id: row.id)
                            } label: {
                                Label(
                                    "Delete Node",
                                    systemImage: HakoSymbol.trash.name
                                )
                            }
                            .accessibilityIdentifier(
                                "provider-definition.inline.proxy.\(record.name).delete"
                            )
                        }
                    }
                }
                .onDelete(perform: remove)
            } footer: {
                Text("Each inline node uses the same field-complete editor as the Proxies tab.")
            }
            Section {
                HakoAddRow(Text("Add Node"), action: addProxy) {
                    Label("Add Node", systemImage: HakoSymbol.plus.name)
                }
                .accessibilityIdentifier(
                    "provider-definition.inline.proxy.add"
                )
            }
        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle("Proxy Nodes")
        .hakoDetailPageInsets()
        .accessibilityIdentifier("provider-definition.inline.proxy-payload")
        .hakoProductModalChild(title: "Proxy Nodes")
    }

    private func record(for proxy: [String: Any]) -> ProxyNodeRecord? {
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

     
     
     
    private func replaceProxy(id: String, json: String) throws {
        guard let value = try JSONSerialization.jsonObject(with: Data(json.utf8))
                as? [String: Any] else {
            throw ProfileProviderDefinitionError.invalidPayload
        }
        var payload = draft.proxyPayload()
        guard let index = InlineProxyRow.rows(from: payload)
            .firstIndex(where: { $0.id == id }),
              payload.indices.contains(index) else {
            throw ProfileProviderDefinitionError.invalidPayload
        }
        payload[index] = value
        draft.replaceProxyPayload(payload)
    }

    private func addProxy() {
        var payload = draft.proxyPayload()
        let names = Set(payload.compactMap { $0["name"] as? String })
        var candidate = "New Node"
        var suffix = 2
        while names.contains(candidate) {
            candidate = "New Node \(suffix)"
            suffix += 1
        }
        payload.append(["name": candidate, "type": "direct"])
        draft.replaceProxyPayload(payload)
    }

    private func remove(_ offsets: IndexSet) {
        let payload = draft.proxyPayload()
        let rows = InlineProxyRow.rows(from: payload)
         
         
         
        let doomed = Set(offsets.compactMap { rows.indices.contains($0) ? rows[$0].id : nil })
         
         
        draft.replaceProxyPayload(
            zip(payload, InlineProxyRow.identities(for: payload))
                .filter { _, id in id.map { !doomed.contains($0) } ?? true }
                .map(\.0)
        )
    }

    private func remove(id: String) {
        let payload = draft.proxyPayload()
        draft.replaceProxyPayload(
            zip(payload, InlineProxyRow.identities(for: payload))
                .filter { _, candidate in candidate != id }
                .map(\.0)
        )
    }
}

private struct ProviderInlineRuleRow: Identifiable, Equatable {
    let id = UUID()
    var value: String
}

private struct ProviderInlineRulePayloadView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @Environment(\.hakoPopRoute) private var popRoute
    @ObservedObject var draft: ProfileProviderDefinitionEditorDraft
    @Environment(\.presentationMode) private var presentationMode
    @State private var rows: [ProviderInlineRuleRow]
     
     
    @State private var openedWith: [ProviderInlineRuleRow] = []

    init(draft: ProfileProviderDefinitionEditorDraft) {
        self.draft = draft
        _rows = State(initialValue: draft.rulePayload().map(ProviderInlineRuleRow.init))
    }

    var body: some View {
        Form {
            Section {
                ForEach($rows) { $row in
                    HStack(spacing: HakoTheme.Spacing.compact) {
                        TextField("Rule", text: $row.value)
                            .font(.body.monospaced())
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier(
                                "provider-definition.inline.rule-value"
                            )
#if os(macOS)
                        Button(role: .destructive) {
                            rows.removeAll { $0.id == row.id }
                        } label: {
                            Image(systemName: HakoSymbol.trash.name)
                                .frame(
                                    width: HakoClientUI.HakoTheme.Control
                                        .minimumHitTarget,
                                    height: HakoClientUI.HakoTheme.Control
                                        .minimumHitTarget
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Delete Rule")
                        .accessibilityIdentifier(
                            "provider-definition.inline.rule.\(row.id).delete"
                        )
#endif
                    }
                }
                .onDelete { rows.remove(atOffsets: $0) }
            } footer: {
                VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
                    Text("Enter the payload syntax required by the selected rule-set behavior.")
                    Text(
                        hakoAppleRuntimeProfile
                            .inlineRuleEditorNotice
                    )
                }
            }
            Section {
                HakoAddRow(Text("Add Rule")) {
                    rows.append(ProviderInlineRuleRow(value: ""))
                } touchLabel: {
                    Label("Add Rule", systemImage: HakoSymbol.plus.name)
                }
                .accessibilityIdentifier(
                    "provider-definition.inline.rule.add"
                )
            }
        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle("Inline Rules")
        .hakoDetailPageInsets()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                 
                if !insideProductModal {
                    Button("Done", action: persist)
                        .font(.body.weight(.semibold))
                }
            }
        }
        .accessibilityIdentifier("provider-definition.inline.rule-payload")
        .hakoProductModalChild(title: "Inline Rules")
             
             
             
             
             
             
             
             
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                     
                     
                     
                     
                     
                     
                     
                HakoModalActionBar(primaryTitle: "Done",
                                         
                     
                     
                     
                     
                     
                    primaryDisabled: rows == openedWith,
                    onPrimary: persist)
            }
        }
        .onAppear { if openedWith.isEmpty { openedWith = rows } }
    }

    private func persist() {
        draft.replaceRulePayload(rows.map { $0.value }.filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
        closeAfterCommit()
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func closeAfterCommit() {
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

private extension View {
     
     
    @ViewBuilder
    func hakoProviderSourceRowLabel(detail: String) -> some View {
        HStack(alignment: .center, spacing: HakoTheme.Spacing.row) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Source")
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            self
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
