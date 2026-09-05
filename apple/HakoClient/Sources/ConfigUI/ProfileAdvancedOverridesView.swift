import HakoClientUI
import SwiftUI
import UniformTypeIdentifiers

 
 
 
 
private enum AdvOverridesModalRoute: String, Identifiable {
    case trust
    case scripts
    case groups
    case rules

    var id: String { rawValue }
}

struct ProfileAdvancedOverridesView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    let profile: Profile
    let sourceYAML: String?
    let ownsNavigationContainer: Bool
    let save: (ProfileAdvancedOverridesDraft) throws -> Void

     
     
     
    @State private var dismiss = HakoDismissHandle()
    @State private var draft: ProfileAdvancedOverridesDraft
     
     
     
    @State private var openedWith: ProfileAdvancedOverridesDraft
    @State private var scripts: [ConfigScript]
    @State private var error = ""
    @State private var showsRawPatchEditor = false
    @State private var rawPatchModalDraft = ""
    @State private var rulePolicyOptions: RulePolicyOptions?
    @State private var isCopyingFromProfile = false

     
     
    @ViewBuilder
     
     
     
     
     
     
     
     
     
    private func door<DoorLabel: View>(
        macOS route: AdvOverridesModalRoute,
        @ViewBuilder destination: @escaping () -> some View,
        @ViewBuilder label: () -> DoorLabel
    ) -> some View {
        HakoRoutedViewLink {
            destination()
        } label: {
            label()
        }
    }

    init(
        profile: Profile,
        sourceYAML: String?,
        ownsNavigationContainer: Bool = true,
        save: @escaping (ProfileAdvancedOverridesDraft) throws -> Void
    ) {
        self.profile = profile
        self.sourceYAML = sourceYAML
        self.ownsNavigationContainer = ownsNavigationContainer
        self.save = save
        _draft = State(initialValue: ProfileAdvancedOverridesDraft(profile: profile))
        _openedWith = State(initialValue: ProfileAdvancedOverridesDraft(profile: profile))
        _scripts = State(initialValue: ScriptLibrary.load())
        _rulePolicyOptions = State(initialValue: nil)
    }

    var body: some View {
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            Form {
                Section {
                    HakoProfileContextHeader(
                        profileName: profile.label,
                        message: .copy(
                            "Standard, Script, and Custom overrides belong only to this profile. App-wide runtime behavior is under More > Core Settings."
                        )
                    ) {
                        HakoSymbolImage(symbol: .profileClipboard)
                    }
                }

                Section {
                    modeButton(.standard)
                    modeButton(.script)
                    modeButton(.custom)
                } footer: {
                    Text(hako: .copy(modeFooter))
                }

                editorSection

                if !error.isEmpty {
                    Section {
                        HakoStatusMessage(text: .copy(error), kind: .error)
                    }
                }
            }
            .hakoProductModal(isPresented: $showsRawPatchEditor, role: .page) {
                RawPatchModal(
                    text: $rawPatchModalDraft,
                    onSave: {
                        draft.rawPatchJSON = rawPatchModalDraft
                        showsRawPatchEditor = false
                    }
                )
                .hakoModalPresentation(.page)
            }
            .hakoPageTitle("Advanced Overrides")
             
             
             
             
             
             
             
            .onReceive(
                NotificationCenter.default.publisher(for: ScriptLibrary.didChange)
            ) { _ in
                scripts = ScriptLibrary.load()
            }
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
                            .accessibilityIdentifier("profile-advanced.save")
                    }
                }
            }
        }
        .task(id: sourceYAML) { await prepareRulePolicyOptions() }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                 
                 
                HakoModalActionBar(primaryTitle: "Save",
                    primaryDisabled: draft == openedWith,
                    onPrimary: persist)
            }
        }
         
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: draft != openedWith,
            save: { completion in
                persist()
                completion(true)
            },
            discard: { draft = openedWith }
        )
        .hakoPageProbe("profile-advanced")
        .accessibilityIdentifier("profile-advanced.screen")
        .hakoCapturesDismiss(dismiss)
    }

    private func modeButton(_ mode: Profile.OverwriteMode) -> some View {
        Button {
            draft.mode = mode
            error = ""
        } label: {
            HStack(alignment: .top, spacing: HakoTheme.Spacing.row) {
                HakoSelectionMark(isSelected: draft.mode == mode)
                VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                    Text(hako: .copy(modeTitle(mode)))
                        .foregroundStyle(.primary)
                    Text(hako: .copy(modeSubtitle(mode)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
             
             
             
             
             
             
             
             
             
             
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(draft.mode == mode ? "Selected" : "")
        .accessibilityIdentifier("profile-advanced.mode.\(mode.rawValue)")
    }

    @ViewBuilder
    private var editorSection: some View {
        switch draft.mode {
        case .standard:
            Section {
                door(macOS: .trust) {
                    trustDestination
                } label: {
                    HakoDestinationRow(
                        title: "Compatibility & Trust",
                        subtitle: runtimeTrustSubtitle,
                        symbol: .lockShield,
                        tint: .indigo
                    )
                }
                .accessibilityIdentifier("profile-advanced.runtime-trust")

#if os(macOS)
                 
                 
                 
                Button {
                    rawPatchModalDraft = draft.rawPatchJSON
                    showsRawPatchEditor = true
                } label: {
                    HakoDestinationRow(
                        title: "Raw Fields",
                        subtitle: rawPatchSubtitle,
                        symbol: .docText,
                        tint: .purple
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile-advanced.raw-patch")
#else
                HakoRoutedViewLink {
                    HakoDeferredDraftHost(source: $draft.rawPatchJSON) {
                        ProfileRawPatchEditor(text: $0)
                    }
                } label: {
                    HakoDestinationRow(
                        title: "Raw Fields",
                        subtitle: rawPatchSubtitle,
                        symbol: .docText,
                        tint: .purple
                    )
                }
                .accessibilityIdentifier("profile-advanced.raw-patch")
#endif
            } footer: {
                Text("Add only profile-specific fields not available in Personal Rules, Profile Network, or Resources. App-wide fields are ignored here.")
            }
        case .script:
            Section {
                if scripts.isEmpty {
                    HakoEmptyState(
                        title: "No Local Scripts",
                        message: "Create a local script before selecting Script mode.",
                        symbol: .curlybraces
                    )
                    .listRowSeparator(.hidden)
                } else {
                    Picker("Selected Script", selection: $draft.selectedScriptID) {
                        Text("Choose a Script").tag(String?.none)
                        ForEach(scripts) { script in
                            Text(script.label).tag(Optional(script.id))
                        }
                    }
                    .accessibilityIdentifier("profile-advanced.script-picker")
                }
                door(macOS: .scripts) {
                    scriptsDestination
                } label: {
                    HakoDestinationRow(
                        title: "Manage Local Scripts",
                        subtitle: .format("%@ scripts", [String(scripts.count)]),
                        symbol: .curlybraces,
                        tint: .purple
                    )
                }
                .accessibilityIdentifier("profile-advanced.manage-scripts")
            } header: {
                Text("Local Script")
            } footer: {
                Text("The selected script adjusts this profile before it starts.")
            }

        case .custom:
            Section {
                door(macOS: .groups) {
                    groupsDestination
                } label: {
                    HakoDestinationRow(
                        title: "Proxy Groups",
                        subtitle: countText(
                            draft.customOverwrite.proxyGroups.count,
                            singular: "%@ group",
                            plural: "%@ groups"
                        ),
                        symbol: .point3ConnectedTrianglepathDotted,
                        tint: .blue
                    )
                }
                .accessibilityIdentifier("profile-advanced.custom-groups")

                door(macOS: .rules) {
                    rulesDestination
                } label: {
                    HakoDestinationRow(
                        title: "Rules",
                        subtitle: countText(
                            draft.customOverwrite.rules.count,
                            singular: "%@ rule",
                            plural: "%@ rules"
                        ),
                        symbol: .listBulletRectangle,
                        tint: .orange
                    )
                }
                .accessibilityIdentifier("profile-advanced.custom-rules")

                Button {
                    Task { await copyFromProfile() }
                } label: {
                    HStack(spacing: HakoTheme.Spacing.compact) {
                        if isCopyingFromProfile {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Label(
                            "Copy Groups and Rules from Profile",
                            systemImage: HakoSymbol.docOnClipboard.name
                        )
                    }
                }
                .disabled(sourceYAML == nil || isCopyingFromProfile)
                .accessibilityValue(isCopyingFromProfile ? "Loading" : "Ready")
                .accessibilityIdentifier("profile-advanced.copy-source")
            } header: {
                Text("Custom Configuration")
            } footer: {
                Text("Custom mode uses only the proxy groups and rules you define here.")
            }
        }
    }

     
     
    private var trustDestination: some View {
        ProfileRuntimeTrustEditor(
            profile: profile,
            sourceYAML: sourceYAML,
            patchJSON: draft.rawPatchJSON
        ) { patchJSON in
            draft.rawPatchJSON = patchJSON
            draft.mode = .standard
        }
    }

    private var scriptsDestination: some View {
        HakoLazyView {
            ScriptLibraryView()
        }
    }

    private var groupsDestination: some View {
        HakoLazyView {
            ProfileAdvancedGroupsHost(
                sourceYAML: sourceYAML,
                profile: profile,
                overwrite: $draft.customOverwrite
            )
        }
    }

    @ViewBuilder
    private var rulesDestination: some View {
        if let rulePolicyOptions {
            HakoDeferredDraftHost(
                source: $draft.customOverwrite.rules
            ) { rules in
                CustomRulesEditor(
                    rules: rules,
                    options: rulePolicyOptions.including(
                        customGroups: draft.customOverwrite.proxyGroups
                    )
                )
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }





    private var rawPatchSubtitle: HakoDisplayText {
        let count = draft.rawPatchFieldCount
        return count == 0
            ? "No additional fields"
            : countText(count, singular: "%@ top-level field", plural: "%@ top-level fields")
    }

    private var runtimeTrustSubtitle: HakoDisplayText {
        var working = profile
        working.override.patchJSON = draft.rawPatchJSON
        let count = ProfileRuntimeTrustDraft(profile: working).customizedFieldCount
        return count == 0
            ? "Default"
            : countText(count, singular: "%@ custom setting", plural: "%@ custom settings")
    }

    private var modeFooter: String {
        switch draft.mode {
        case .standard:
            return "Keep the visual settings and optionally add advanced fields."
        case .script:
            return "Use a local script to adjust this profile."
        case .custom:
            return "Use your own proxy groups and routing rules."
        }
    }

    private func modeTitle(_ mode: Profile.OverwriteMode) -> String {
        switch mode {
        case .standard: return "Standard"
        case .script: return "Script"
        case .custom: return "Custom"
        }
    }

    private func modeSubtitle(_ mode: Profile.OverwriteMode) -> String {
        switch mode {
        case .standard: return "Use visual settings with optional advanced fields"
        case .script: return "Adjust this profile with a local script"
        case .custom: return "Use your own proxy groups and routing rules"
        }
    }

    @MainActor
    private func copyFromProfile() async {
        guard let sourceYAML else { return }
        isCopyingFromProfile = true
        defer { isCopyingFromProfile = false }
        do {
            let parsed = try await Task.detached(priority: .userInitiated) {
                try CustomOverwriteSpec.parse(sourceYAML: sourceYAML)
            }.value
            draft.customOverwrite = parsed
            error = ""
        } catch {
            self.error = "The current profile cannot be copied into a custom override."
        }
    }

    private func persist() {
        do {
            try save(draft)
            closePage()
        } catch let bounded as ProfileAdvancedOverridesError {
            error = bounded.localizedDescription
        } catch {
            self.error = "Advanced overrides could not be saved. The previous configuration remains available."
        }
    }

    @MainActor
    private func prepareRulePolicyOptions() async {
        let sourceYAML = sourceYAML
        rulePolicyOptions = await Task.detached(priority: .userInitiated) {
            RulePolicyOptions.make(sourceYAML: sourceYAML)
        }.value
    }

    private func countText(
        _ count: Int, singular: String, plural: String
    ) -> HakoDisplayText {
         
         
        .format(count == 1 ? singular : plural, [String(count)])
    }

     
    private func closePage() {
        if let productModalDismiss {
            productModalDismiss()
        } else {
            dismiss()
        }
    }
}

 
 
 
 
 
private struct ProfileAdvancedGroupsHost: View {
    let sourceYAML: String?
    let profile: Profile
    @Binding var overwrite: CustomOverwriteSpec

    @State private var preparation: Preparation?

    private struct Preparation {
        let names: [String]
        let context: CustomGroupValidationContext
    }

    private struct PreparationKey: Equatable {
        let sourceYAML: String?
        let profile: Profile
        let groups: [CustomProxyGroup]
    }

    var body: some View {
        Group {
            if let preparation {
                 
                 
                 
                HakoDeferredDraftHost(source: $overwrite) { local in
                    CustomProxyGroupsEditor(
                        groups: local.proxyGroups,
                        profileProxyNames: preparation.names,
                        validationContext: preparation.context,
                        onRename: { old, new in
                            local.wrappedValue.renameProxyGroup(
                                from: old,
                                to: new
                            )
                        }
                    )
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: PreparationKey(
            sourceYAML: sourceYAML,
            profile: profile,
            groups: overwrite.proxyGroups
        )) {
            await prepare()
        }
    }

    @MainActor
    private func prepare() async {
        let sourceYAML = sourceYAML
        let profile = profile
        let groups = overwrite.proxyGroups
        preparation = await Task.detached(priority: .userInitiated) {
            let names = sourceYAML.flatMap {
                try? ProxyChainSpec.inventory(from: $0).map(\.name)
            } ?? []
            return Preparation(
                names: names,
                context: GroupMemberCandidates.validationContext(
                    sourceYAML: sourceYAML,
                    profile: profile,
                    draftGroups: groups
                )
            )
        }.value
    }
}

 
 
 
private struct ProfileRuntimeTrustEditor: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    let profile: Profile
    let baselinePatchJSON: String
    let commit: (String) -> Void

     
     
     
     
     
     
     
    @State private var openedWith: ProfileRuntimeTrustDraft?
    @State private var dismiss = HakoDismissHandle()
    @State private var draft: ProfileRuntimeTrustDraft
    @State private var error = ""
    @State private var showsCertificateImporter = false
     
    @State private var certificateRows = HakoIdentifiedRows()

    init(
        profile: Profile,
        sourceYAML: String? = nil,
        patchJSON: String,
        commit: @escaping (String) -> Void
    ) {
        self.profile = profile
        baselinePatchJSON = patchJSON
        self.commit = commit
        var working = profile
        working.override.patchJSON = patchJSON
        _draft = State(initialValue: ProfileRuntimeTrustDraft(profile: working, sourceYAML: sourceYAML))
    }

    var body: some View {
        Form {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            Section {
                HakoSettingsToggleRow(
                    Text("Override Trusted Certificates"),
                    isOn: certificatesEnabled
                )
                    .accessibilityIdentifier("profile-runtime-trust.certificates.enabled")

                if let certificates = draft.customTrustCertificates {
                     
                     
                     
                     
                    ForEach(certificateRows.current(for: certificates)) { row in
                        let index = row.index
                        let value = certificateRows.index(of: row.id)
                            .map { certificates[$0] } ?? ""
                        HStack {
                            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                                Text("Certificate \(index + 1)")
                                Text("Public PEM · \(Self.byteCount(value))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                guard var kept = draft.customTrustCertificates
                                else { return }
                                certificateRows.remove(row.id, from: &kept)
                                draft.customTrustCertificates = kept
                            } label: {
                                Image(systemName: HakoSymbol.trash.name)
                                    .frame(width: 28, height: 28)
                            }
                            .accessibilityLabel("Remove Certificate \(index + 1)")
                        }
                        .frame(maxWidth: .infinity, minHeight: HakoClientUI.HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
                        .accessibilityIdentifier("profile-runtime-trust.certificate.\(index)")
                    }
                    .onAppear {
                        certificateRows.resync(count: certificates.count)
                    }
                    .onChange(of: certificates.count) {
                        certificateRows.resync(count: $0)
                    }

                    HakoAddRow(Text("Import Public Certificate")) {
                        showsCertificateImporter = true
                    }
                    .accessibilityIdentifier("profile-runtime-trust.certificate.import")
                }
            } header: {
                Text("Custom Trust")
            } footer: {
                Text("Only public PEM certificates are accepted. Private keys are rejected and never stored by this editor.")
            }

            Section {
                HStack(alignment: .top, spacing: HakoTheme.Spacing.row) {
                    HakoIconWell(symbol: .lockShield, tint: .gray)
                    VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                        Text("Certificate and Private Key")
                            .font(.headline)
                        Text(hako: .copy(serverTLSMessage))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, HakoTheme.Spacing.tight)
                .accessibilityIdentifier("profile-runtime-trust.server-tls")
            } header: {
                Text("External Controller TLS")
            } footer: {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                Text("Certificate, private-key, client-auth and ECH server-key fields are kept in the source and handed to Clash, which serves the controller over HTTPS when this profile sets external-controller-tls.")
            }

            if draft.originalOverwriteMode != .standard {
                Section {
                    Label(
                        "Saving switches this profile to Standard overrides. Your existing script or custom draft is kept for later use.",
                        systemImage: HakoSymbol.infoCircle.name
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if !error.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(error), kind: .error)
                }
            }
        }
         
        .hakoRegistersDeparture(
            isDirty: hasChanges,
            save: { completion in
                persist()
                completion(true)
            },
            discard: { if let openedWith { draft = openedWith } }
        )
        .onAppear { if openedWith == nil { openedWith = draft } }
        .hakoPageTitle("Compatibility & Trust")
        .hakoDetailPageInsets()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if !insideProductModal {
                    Button("Done", action: persist)
                        .accessibilityIdentifier("profile-runtime-trust.done")
                }
            }
        }
        .fileImporter(
            isPresented: $showsCertificateImporter,
            allowedContentTypes: [.data, .plainText],
            allowsMultipleSelection: false,
            onCompletion: importCertificate
        )
        .accessibilityIdentifier("profile-runtime-trust.screen")
        .hakoCapturesDismiss(dismiss)
         
         
         
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                     
                     
                     
                     
                     
                     
                     
                HakoModalActionBar(primaryTitle: "Done",
                    primaryDisabled: !hasChanges,
                    onPrimary: persist)
            }
        }
    }

    private var certificatesEnabled: Binding<Bool> {
        Binding(
            get: { draft.customTrustCertificates != nil },
            set: { enabled in
                draft.customTrustCertificates = enabled
                    ? (draft.customTrustCertificates ?? []) : nil
            }
        )
    }

    private var serverTLSMessage: String {
        draft.hasUnsupportedServerTLSFields
            ? "External controller TLS material is present. Clash keeps it and uses it when the controller is served over HTTPS."
            : "This profile sets no external controller TLS material."
    }

     
     
     
     
     
     
     
    private var hasChanges: Bool {
        var working = profile
        working.override.patchJSON = baselinePatchJSON
        guard let updated = try? draft.applying(to: working) else { return true }
        return updated.override.patchJSON != baselinePatchJSON
    }

    private func persist() {
        do {
            var working = profile
            working.override.patchJSON = baselinePatchJSON
            let updated = try draft.applying(to: working)
            commit(updated.override.patchJSON)
            dismiss()
        } catch let bounded as ProfileRuntimeTrustError {
            error = bounded.localizedDescription
        } catch {
            self.error = "Runtime and trust settings could not be prepared. The previous configuration remains unchanged."
        }
    }

    private func importCertificate(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            guard let raw = String(data: data, encoding: .utf8) else {
                throw ProfileRuntimeTrustError.invalidCertificate
            }
            let certificate = try ProfileRuntimeTrustDraft.normalizedCertificate(raw)
            if draft.customTrustCertificates == nil { draft.customTrustCertificates = [] }
            if draft.customTrustCertificates?.contains(certificate) == false {
                draft.customTrustCertificates?.append(certificate)
            }
            error = ""
        } catch let bounded as ProfileRuntimeTrustError {
            error = bounded.localizedDescription
        } catch {
            self.error = ProfileRuntimeTrustError.invalidCertificate.localizedDescription
        }
    }

    private static func byteCount(_ value: String) -> String {
        let bytes = value.utf8.count
        return bytes < 1_024 ? "\(bytes) B" : "\((bytes + 1_023) / 1_024) KB"
    }
}

 
 
 
struct ProfileAdditionalFieldsView: View {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
     
     
     
     
     
     
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    let profile: Profile
    let ownsNavigationContainer: Bool
    let save: (ProfileAdvancedOverridesDraft) throws -> Void

     
    @State private var dismiss = HakoDismissHandle()
    @State private var draft: ProfileAdvancedOverridesDraft
     
     
     
    @State private var openedWith: ProfileAdvancedOverridesDraft
    @State private var error = ""

    init(
        profile: Profile,
        ownsNavigationContainer: Bool = true,
        save: @escaping (ProfileAdvancedOverridesDraft) throws -> Void
    ) {
        self.profile = profile
        self.ownsNavigationContainer = ownsNavigationContainer
        self.save = save
        _draft = State(initialValue: ProfileAdvancedOverridesDraft(profile: profile))
        _openedWith = State(initialValue: ProfileAdvancedOverridesDraft(profile: profile))
    }

    var body: some View {
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            Form {
                Section {
                    CodeEditorPanel(
                        text: $draft.rawPatchJSON,
                        language: .json,
                        minHeight: 300
                    )
                    .accessibilityIdentifier("profile-advanced.raw-patch.editor")
                } header: {
                    Text("Raw Fields")
                } footer: {
                    Text("These fields are applied in Standard mode when the profile starts; the original profile remains unchanged.")
                }

                if draft.mode != .standard {
                    Section {
                        Label(
                            "Saving switches this profile to Standard overrides.",
                            systemImage: HakoSymbol.infoCircle.name
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                if !error.isEmpty {
                    Section {
                        HakoStatusMessage(text: .copy(error), kind: .error)
                    }
                }
            }
            .hakoPageTitle("Raw Fields")
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
                            .accessibilityIdentifier("profile-additional-fields.save")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if insideProductModal {
                 
                HakoModalActionBar(primaryTitle: "Save",
                    primaryDisabled: draft == openedWith,
                    onPrimary: persist)
            }
        }
         
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: draft != openedWith,
            save: { completion in
                persist()
                completion(true)
            },
            discard: { draft = openedWith }
        )
        .hakoPageProbe("profile-additional-fields")
        .accessibilityIdentifier("profile-additional-fields.screen")
        .hakoCapturesDismiss(dismiss)
    }

    private func persist() {
        do {
            draft.mode = .standard
            try save(draft)
            closePage()
        } catch let bounded as ProfileAdvancedOverridesError {
            error = bounded.localizedDescription
        } catch {
            self.error = "Additional fields could not be saved. The previous configuration remains available."
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

 
 
 
 
 
private struct RawPatchModal: View {
    @Binding var text: String
     
     
     
     
    @State private var openedWith: String?
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CodeEditorPanel(
                text: $text,
                language: .json,
                minHeight: 420
            )
            .padding(.horizontal, HakoTheme.Spacing.standard)
            .accessibilityIdentifier("profile-advanced.raw-patch.editor")
            Text("These fields are added when the profile starts; the original profile stays unchanged.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, HakoTheme.Spacing.standard)
                .padding(.top, HakoTheme.Spacing.compact)
             
             
             
             
             
             
             
            HakoModalActionBar(
                primaryTitle: "Done",
                primaryDisabled: text == (openedWith ?? text),
                onPrimary: onSave
            )
            .accessibilityIdentifier("profile-advanced.raw-patch.save")
        }
        .frame(minWidth: 680, minHeight: 600)
        .hakoProductModalRoot(title: "Raw Fields")
        .onAppear { if openedWith == nil { openedWith = text } }
    }
}

private struct ProfileRawPatchEditor: View {
    @Binding var text: String

    var body: some View {
        Form {
            Section {
                CodeEditorPanel(
                    text: $text,
                    language: .json,
                    minHeight: 300
                )
                .accessibilityIdentifier("profile-advanced.raw-patch.editor")
            } header: {
                Text("Raw Fields")
            } footer: {
                Text("These fields are added when the profile starts; the original profile stays unchanged.")
            }
        }
        .hakoPageTitle("Raw Fields")
        .hakoDetailPageInsets()
    }
}
