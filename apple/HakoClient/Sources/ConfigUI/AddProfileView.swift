import HakoClientUI
import SwiftUI
import UniformTypeIdentifiers

 
 
 
 
 
 
 
 
 
 
 
 
struct AddProfileView: View {
     
     
    let createEmpty: () -> Void
    let save: (String, Profile.Source, String?, [ExternalResourceImportFile]) -> Void

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal

    @State private var draft = AddProfileDraft()
    @State private var importedResourceFiles: [ExternalResourceImportFile] = []
    @State private var showsImporter = false
    @State private var showsQRCapture = false
    @State private var showsQRPhotoPicker = false
    @State private var showsPastedEditor = false

    var body: some View {
        HakoFeatureNavigationContainer {
            VStack(spacing: 0) {
             
             
             
             
             
             
            tabPickerBar
            Form {
                switch draft.tab {
                case .link:
                    linkSection
                case .file:
                    fileSection
                case .blank:
                    blankPane
                }
                 
                 
                 
                nameSection
                if let requirement = draft.blockingRequirement,
                    !HakoPlatformLayout.pageUsesSystemSettingsIdiom
                {
                     
                     
                     
                     
                     
                     
                     
                    Section {
                        Text(hako: .copy(requirement))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                             
                             
                             
                             
                            .listRowBackground(
                                HakoPlatformLayout.pageUsesSystemSettingsIdiom
                                    ? Color.clear : nil
                            )
                            .accessibilityIdentifier("profile.add.blocked-reason")
                    }
                }
            }
            }
            .hakoPageTitle("Add Profile")
             
             
             
             
             
             
             
             
             
             
             
            .hakoRegistersDeparture(
                 
                 
                 
                 
                 
                isDirty: draft != AddProfileDraft(),
                save: { completion in
                    submit()
                    completion(true)
                },
                discard: { draft = AddProfileDraft() }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !insideProductModal {
                        Button("Cancel") { dismissPresentation() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                         
                         
                         
                        if draft.tab == .blank {
                            Button("Create") { submit() }
                        } else {
                            Button("Add") { submit() }
                                .disabled(!draft.canSubmit)
                        }
                    }
                }
            }
            .hakoProductModalRoot(title: "Add Profile")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                    HakoModalActionBar(
                        primaryTitle: draft.tab == .blank ? "Create" : "Add",
                        primaryDisabled: !draft.canSubmit,
                         
                         
                         
                         
                         
                         
                         
                        primaryHint: draft.blockingRequirement,
                        onPrimary: submit
                    )
                }
            }
             
             
             
             
             
            .fileImporter(isPresented: $showsImporter,
                          allowedContentTypes: [.yaml, .plainText, .data],
                          allowsMultipleSelection: false) { result in
                importFile(result)
            }
            .hakoProductModal(
                isPresented: $showsQRCapture,
                role: .page
            ) {
                 
                 
                 
                HakoFeatureNavigationContainer {
                    qrCapturePage
                        .hakoPageTitle("Scan QR Code")
                        .hakoToolbarUnlessInPanel {
                            ToolbarItem(placement: .cancellationAction) {
                                HakoSheetCloseButton { showsQRCapture = false }
                            }
                        }
                         
                         
                         
                         
                        .hakoProductModalRoot(title: "Scan QR Code")
                }
                .hakoModalPresentation(.page)
            }
            .hakoProductModal(
                isPresented: $showsPastedEditor,
                role: .page
            ) {
                HakoFeatureNavigationContainer {
                    ZStack {
                        HakoTheme.canvas.ignoresSafeArea()
                        CodeEditorPanel(
                            text: $draft.pastedConfigText,
                            language: .yaml,
                            minHeight: 360,
                            expandsVertically: true
                        )
                        .padding(HakoTheme.Spacing.standard)
                    }
                    .hakoPageTitle("Configuration")
                    .hakoToolbarUnlessInPanel {
                        ToolbarItem(placement: .cancellationAction) {
                            HakoSheetCloseButton { showsPastedEditor = false }
                        }
                    }
                    .hakoProductModalRoot(title: "Configuration")
                }
                .hakoModalPresentation(.page)
            }
            .hakoProductModal(
                isPresented: $showsQRPhotoPicker,
                role: .page
            ) {
                QRPhotoPicker { result in
                    showsQRPhotoPicker = false
                    acceptQRResult(result)
                }
                .hakoModalPresentation(.page)
                .hakoProductModalRoot(title: "Choose QR from Photos")
            }
        }
        .hakoCapturesDismiss(dismiss)
    }

     

     
     
     
     
     
     
    private var tabPickerBar: some View {
         
         
         
         
         
         
         
         
         
         
         
         
         
         
#if os(macOS)
        HStack(spacing: 2) {
            addTabSegment(.link, "Link", identifier: "profile.add.tab.link")
            addTabSegment(.file, "File", identifier: "profile.add.tab.file")
            addTabSegment(.blank, "Blank", identifier: "profile.add.blank")
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.07))
        )
         
         
         
         
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 2)
#else
         
         
         
         
         
        Picker(HakoCopy.key("Type"), selection: $draft.tab) {
            Text(HakoCopy.key("Link")).tag(AddProfileDraft.Tab.link)
            Text(HakoCopy.key("File")).tag(AddProfileDraft.Tab.file)
            Text(HakoCopy.key("Blank")).tag(AddProfileDraft.Tab.blank)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("profile.add.tab")
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 2)
#endif
    }

    private func addTabSegment(
        _ tab: AddProfileDraft.Tab,
        _ key: String,
         
         
         
        identifier: String
    ) -> some View {
        Button {
            draft.tab = tab
        } label: {
            Text(HakoCopy.key(key))
                .font(.callout.weight(draft.tab == tab ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if draft.tab == tab {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selectedSegmentFill)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            }
        }
        .accessibilityIdentifier(identifier)
         
         
         
         
        .accessibilityAddTraits(draft.tab == tab ? .isSelected : [])
    }

    private var selectedSegmentFill: Color {
#if os(macOS)
        Color(nsColor: .controlColor)
#else
        Color(uiColor: .secondarySystemGroupedBackground)
#endif
    }

     
     
    private var nameSection: some View {
        Section {
            HakoFieldRow(
                "Name",
                hint: "Optional",
                text: $draft.label,
                identifier: "profile.add.name"
            )
        } footer: {
            Text(HakoCopy.key(
                "Leave this empty and the profile takes its name from the source."
            ))
                .addPanelMacLeadingFooter()
        }
    }

     
     
     
     
     
     
     
     
    private var linkSection: some View {
        Section {
            HStack(spacing: HakoTheme.Spacing.compact) {
                linkField
                HakoPasteControl { draft.acceptPaste($0) }
            }

             
             
             
             
             
            switch draft.crossReference {
            case .configTextBelongsInFile:
                 
                 
                 
                 
                 
                HStack(alignment: .firstTextBaseline) {
                    HakoStatusMessage(
                        text: .copy("That is a configuration, not a link."),
                        kind: .warning
                    )
                    Spacer(minLength: HakoTheme.Spacing.compact)
                    Button(HakoCopy.key("Move to File")) {
                        draft.movePendingConfigTextToFileTab()
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("profile.add.cross-reference")
                }
            case .nodeBelongsInCustomNodes:
                 
                 
                 
                HakoStatusMessage(
                    text: .copy("That is a node, not a subscription. Add it under a profile's Custom Nodes."),
                    kind: .warning
                )
                .accessibilityIdentifier("profile.add.cross-reference")
            case nil:
                EmptyView()
            }

            Button {
                showsQRCapture = true
            } label: {
                Label("Scan QR Code", systemImage: HakoSymbol.qrcodeViewfinder.name)
                     
                     
                     
                    .frame(
                        maxWidth: HakoPlatformLayout.pageUsesSystemSettingsIdiom
                            ? nil : .infinity,
                        alignment: .leading
                    )
            }
            .hakoMacListAddChrome()
            .accessibilityIdentifier("profile.add.qr")

            if !draft.importError.isEmpty {
                HakoStatusMessage(text: .copy(draft.importError), kind: .error)
            }
            if !draft.importNotice.isEmpty {
                HakoStatusMessage(text: .copy(draft.importNotice), kind: .warning)
                    .accessibilityIdentifier("profile.add.skipped")
            }
        } footer: {
            Text(hako: linkFooterText)
                .addPanelMacLeadingFooter()
        }
    }

     
     
     
     
    @ViewBuilder
    private var linkField: some View {
        Group {
             
             
             
            if #available(iOS 16.0, macOS 13.0, *) {
                TextField(
                    "",
                    text: $draft.linkText,
                     
                     
                     
                     
                     
                    prompt: Text(verbatim: "https://example.com/subscription"),
                    axis: .vertical
                )
                    .accessibilityIdentifier("profile.add.link")
                .lineLimit(1...6)
            } else {
                TextField(
                    "",
                    text: $draft.linkText,
                    prompt: Text(verbatim: "https://example.com/subscription")
                )
                    .accessibilityIdentifier("profile.add.paste")
            }
        }
#if !os(macOS)
        .keyboardType(.URL)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
#endif
        .frame(maxWidth: .infinity)
         
         
         
         
         
        .labelsHidden()
        .multilineTextAlignment(.leading)
        .accessibilityIdentifier("profile.add.link")
        .onChange(of: draft.linkText) { _ in draft.normalizeLinkText() }
    }

     
     
     
    @ViewBuilder
    private var fileSection: some View {
        Section {
            Button {
                showsImporter = true
            } label: {
                 
                 
                 
                 
                Label {
                    if draft.importedFileName.isEmpty {
                        Text(HakoCopy.key("Choose config file"))
                    } else {
                        Text(verbatim: draft.importedFileName)
                    }
                } icon: {
                    Image(systemName: HakoSymbol.docBadgePlus.name)
                }
            }
            .hakoMacListAddChrome()
            .accessibilityIdentifier("profile.add.file")

             
             
            ForEach(draft.importedResourceNames, id: \.self) { name in
                Label(name, systemImage: HakoSymbol.docText.name)
                    .foregroundStyle(.secondary)
            }

            if !draft.importError.isEmpty {
                HakoStatusMessage(text: .copy(draft.importError), kind: .error)
            }
            if !draft.importNotice.isEmpty {
                HakoStatusMessage(text: .copy(draft.importNotice), kind: .warning)
                    .accessibilityIdentifier("profile.add.skipped")
            }
        } footer: {
            Text(HakoCopy.key(
                "Select one YAML file plus any certificates or keys it references. Clash copies only the files you explicitly select."
            ))
                .addPanelMacLeadingFooter()
        }

        Section {
            HStack {
                Text(HakoCopy.key("Paste config text"))
                Spacer()
                HakoPasteControl { pasted in
                    draft.acceptConfigTextPaste(pasted)
                     
                     
                     
                    guard !draft.pastedConfigText.isEmpty else { return }
                    if let derived = try? ProxyImportBridge.derivedSubscription(
                        from: Data(draft.pastedConfigText.utf8)
                    ) {
                        draft.importNotice = Self.skippedNotice(derived.kept, derived.skipped)
                    }
                }
            }

             
             
            if !draft.configPreviewLines.isEmpty {
                VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                    ForEach(Array(draft.configPreviewLines.enumerated()), id: \.offset) {
                        Text($0.element)
                    }
                }
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("profile.add.config-preview")
            }

             
             
             
             
            if !draft.pastedConfigText.isEmpty {
                Button {
                    showsPastedEditor = true
                } label: {
                    HStack {
                        Text(hako: draft.pastedConfigSummary.map {
                            .format("Review all %@ lines", [$0])
                        } ?? .copy("Review the configuration"))
                        Spacer()
                        Image(systemName: HakoSymbol.chevronForward.name)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("profile.add.review-config")
            }
        } footer: {
            Text(HakoCopy.key("Read a configuration from the clipboard."))
                .addPanelMacLeadingFooter()
        }
    }

     
     
     
     
    private var blankPane: some View {
        Section {
        } footer: {
            Text(HakoCopy.key(
                "You can start without a subscription: everything goes direct, and you add nodes and rules yourself."
            ))
                .addPanelMacLeadingFooter()
        }
    }

     
     
     
    @ViewBuilder
    private var qrCapturePage: some View {
#if os(macOS)
         
         
        Form {
            Section {
                Button {
                    showsQRCapture = false
                    showsQRPhotoPicker = true
                } label: {
                    Label("Choose QR Image", systemImage: HakoSymbol.photo.name)
                }
                .accessibilityIdentifier("profile.add.qr.file")
            }
        }
#else
        Form {
            Section {
                QRScannerView { code in
                    showsQRCapture = false
                    acceptQRCode(code)
                }
                .frame(height: 240)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: HakoTheme.Radius.card,
                        style: .continuous
                    )
                )
            }
            Section {
                Button {
                    showsQRCapture = false
                    showsQRPhotoPicker = true
                } label: {
                    Label("Choose QR from Photos", systemImage: HakoSymbol.photo.name)
                }
                .accessibilityIdentifier("profile.add.qr.photos")
            }
        }
#endif
    }

     

    private var linkFooterText: HakoDisplayText {
        switch draft.linkFooter {
        case .accepts:
            return .copy("Subscription links and install links both work.")
        case .downloadsOverHTTPS:
            return .copy(
                "Clash downloads the subscription when the profile is activated."
            )
        case .cleartextWarning:
            return .copy(
                "This link is not encrypted. Credentials in the address travel in the clear."
            )
        case .unwrappedInstallLink(let host):
            return .format("Install link. The subscription inside is %@.", [host])
        }
    }

     

    private func submit() {
        do {
            switch draft.tab {
            case .blank:
                createEmpty()
            case .link:
                save(draft.label, .url(draft.resolvedLink), nil, [])
            case .file:
                if !draft.importedYAML.isEmpty {
                    try ConfigTransforms.validateSource(draft.importedYAML)
                    save(
                        draft.label,
                        .file(draft.importedFileName),
                        draft.importedYAML,
                        importedResourceFiles
                    )
                } else {
                     
                     
                     
                    let yaml = try ProxyImportBridge.derivedSubscriptionYAML(
                        from: Data(draft.pastedConfigText.utf8)
                    )
                    save(draft.label, .clipboard, yaml, [])
                }
            }
            dismissPresentation()
        } catch {
            draft.importError = safeImportMessage(error)
        }
    }

    private func dismissPresentation() {
        (productModalDismiss ?? { dismiss() })()
    }

    private func acceptQRResult(_ result: Result<String, Error>?) {
        guard let result else { return }
        switch result {
        case .success(let code): acceptQRCode(code)
        case .failure(let error): draft.importError = error.localizedDescription
        }
    }

     
     
     
    private func acceptQRCode(_ code: String) {
        draft.importError = ""
        draft.tab = .link
        draft.acceptPaste(code)
    }

    private func importFile(_ result: Result<[URL], Error>) {
        draft.importError = ""
        switch result {
        case .failure(let error):
            draft.importError = safeImportMessage(error)
        case .success(let urls):
            do {
                guard let yamlURL = AddProfileDraft.configurationFile(among: urls) else {
                    throw ProfileInstallLinkError.unsupportedFile
                }
                let selected = try urls.map { url -> ExternalResourceImportFile in
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    guard !data.isEmpty,
                          data.count <= ProfileExternalResourceImporter.maximumResourceBytes else {
                        throw data.isEmpty
                            ? ProfileInstallLinkError.unreadableFile
                            : ProfileInstallLinkError.fileTooLarge
                    }
                    return ExternalResourceImportFile(
                        fileName: url.lastPathComponent,
                        data: data
                    )
                }
                guard let yamlFile = selected.first(where: {
                    $0.fileName == yamlURL.lastPathComponent
                }) else {
                    throw ProfileInstallLinkError.unreadableFile
                }
                 
                 
                 
                 
                 
                 
                let derived = try ProxyImportBridge.derivedSubscription(from: yamlFile.data)
                let yaml = derived.yaml
                importedResourceFiles = selected.filter {
                    $0.fileName != yamlURL.lastPathComponent
                }
                draft.acceptImportedFile(
                    name: yamlURL.lastPathComponent,
                    yaml: yaml,
                    resourceNames: importedResourceFiles.map(\.fileName)
                )
                draft.importNotice = Self.skippedNotice(derived.kept, derived.skipped)
            } catch {
                draft.importError = safeImportMessage(error)
            }
        }
    }

     
     
     
     
     
    static func skippedNotice(
        _ kept: Int,
        _ skipped: [ProxyImportIssue],
        locale: Locale = .current
    ) -> String {
        guard !skipped.isEmpty else { return "" }
         
         
         
         
        let head = String(
            format: HakoCopy.string("Added %d, skipped %d.", locale: locale),
            kept, skipped.count
        )
         
         
         
        return ([head] + skipped.map { issue in
            issue.line.map { "\($0): \(issue.message)" } ?? issue.message
        }).joined(separator: "\n")
    }

    private func safeImportMessage(_ error: Error) -> String {
        ConfigurationFailureClassifier.classify(
            error,
            context: .localImport,
            preservesLastKnownGood: false
        )?.localizedDescription ?? "The configuration could not be imported."
    }
}

 
 
 
private extension View {
     
     
     
    @ViewBuilder
    func addPanelMacLeadingFooter() -> some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
             
             
             
             
            multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            self
        }
    }
}
