import HakoClientUI
import SwiftUI
import UniformTypeIdentifiers

 
 
 
struct ProfileEditView: View {
    let save: (Profile, String?, [ExternalResourceImportFile], Bool) async throws -> Void

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal

    private let original: Profile
     
     
     
     
     
     
     
     
    @State private var departureCompletion: ((Bool) -> Void)?
    private let originalRawText: String
    private let hadRawSource: Bool
    @State private var rawText: String
    @State private var importedResourceFiles: [ExternalResourceImportFile] = []
    @State private var showsFileImporter = false
    @State private var errorMessage = ""
    @State private var diagnosticLine: Int?
    @State private var asksAboutAutoUpdate = false
    @State private var asksAboutUnsaved = false
     
    @State private var isSaving = false
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @State private var editorReady = false
    @State private var findPresented = false
    @State private var typing = false
    @State private var showsLineNumbers = CodeEditorLineNumbers.isOn
    @State private var softWrap = CodeEditorSoftWrap.isOn

     
     
     
     
     
    private var editWillBeOverwrittenByAutoUpdate: Bool {
        guard case .url = original.source else { return false }
        return original.autoUpdate && rawChanged
    }

    init(
        profile: Profile,
        rawYAML: String?,
        save: @escaping (
            Profile, String?, [ExternalResourceImportFile], Bool
        ) async throws -> Void
    ) {
        self.save = save
        original = profile
        originalRawText = rawYAML ?? ""
        hadRawSource = rawYAML != nil
        _rawText = State(initialValue: rawYAML ?? "")
    }

    private var rawChanged: Bool { rawText != originalRawText }

     
     
     
    private var canSave: Bool {
        rawChanged && !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

     
     
     
     
     
     
     
    private var blockingRequirement: String? {
        guard !canSave else { return nil }
        if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "The configuration cannot be empty."
        }
        return "Edit the configuration to save it."
    }

     
     
     
     
    @ViewBuilder
    private var editor: some View {
         
         
        CodeEditorPanel(
            text: $rawText,
            language: .yaml,
            minHeight: 200,
            diagnosticLine: diagnosticLine,
            expandsVertically: true,
             
             
            chrome: .minimal,
            showsLineNumbers: showsLineNumbers,
            softWrap: softWrap,
            findPresented: $findPresented,
            typing: $typing
        )
        .padding(.horizontal, HakoTheme.Spacing.standard)
        .padding(.vertical, HakoTheme.Spacing.compact)
    }

     
     
     
    @ViewBuilder
    private var moreMenu: some View {
        Button {
            findPresented = true
        } label: {
            Label("Find", systemImage: HakoSymbol.magnifyingglass.name)
        }
        .keyboardShortcut("f", modifiers: .command)
        .accessibilityIdentifier("profile.edit.find")
        Button {
            showsLineNumbers.toggle()
            CodeEditorLineNumbers.isOn = showsLineNumbers
        } label: {
            Label(
                "Line Numbers",
                systemImage: showsLineNumbers ? HakoSymbol.checkmark.name : HakoSymbol.listBullet.name
            )
        }
        .accessibilityIdentifier("profile.edit.lineNumbers")
        Button {
            softWrap.toggle()
            CodeEditorSoftWrap.isOn = softWrap
        } label: {
            Label(
                "Wrap Long Lines",
                systemImage: softWrap ? HakoSymbol.checkmark.name : HakoSymbol.arrowRightToLine.name
            )
        }
        .accessibilityIdentifier("profile.edit.softWrap")
        Button {
            showsFileImporter = true
        } label: {
            Label("Replace from File…", systemImage: HakoSymbol.squareAndArrowDown.name)
        }
        .accessibilityIdentifier("profile.edit.replace-file")
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            Group {
                if !editorReady {
                    VStack(spacing: HakoTheme.Spacing.compact) {
                        Spacer()
                        ProgressView()
                        Text(hako: .copy("Opening Editor"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .accessibilityIdentifier("profile.sourceEditor.loading")
                } else if hadRawSource || !rawText.isEmpty {
                    editor
                } else {
                    VStack {
                        Spacer()
                        Text("The source is downloaded on first Sync or activation.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HakoTheme.canvas.ignoresSafeArea())
             
             
             
            .task { editorReady = true }
             
             
             
            .hakoPageTitle(.copy(original.label), watchAs: "Edit Source")
             
             
            .modifier(HakoBarFadesWhileTyping(typing: $typing))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !insideProductModal {
                        Button("Cancel") {
                            switch UnsavedEditPolicy.decision(
                                original: originalRawText,
                                current: rawText
                            ) {
                            case .leave: dismissPresentation()
                            case .offerToSave: asksAboutUnsaved = true
                            }
                        }
                    }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if !insideProductModal {
                        Menu {
                            moreMenu
                        } label: {
                            Image(systemName: HakoSymbol.ellipsisCircle.name)
                        }
                        .accessibilityLabel("More")
                        .accessibilityIdentifier("profile.edit.more")

                        HakoSaveButton(
                            isEnabled: canSave,
                            identifier: "profile.edit.save"
                        ) {
                            await requestSave()
                        }
                    }
                }
            }
            .hakoProductModalRoot(
                title: "Edit Source",
                 
                 
                 
                actionTitle: "Replace from File…",
                action: { showsFileImporter = true }
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                    HakoModalActionBar(
                        primaryTitle: "Save",
                        primaryDisabled: !canSave,
                        primaryHint: blockingRequirement,
                        isBusy: isSaving,
                        busyTitle: "Saving…",
                        onPrimary: {
                             
                             
                             
                            isSaving = true
                            Task { await requestSave() }
                        }
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !errorMessage.isEmpty {
                    HakoStatusMessage(text: .copy(errorMessage), kind: .error)
                        .padding(.horizontal, HakoTheme.Spacing.standard)
                        .padding(.bottom, HakoTheme.Spacing.compact)
                }
            }
             
            .fileImporter(
                isPresented: $showsFileImporter,
                allowedContentTypes: [.yaml, .plainText, .data],
                allowsMultipleSelection: false
            ) { result in
                importFile(result)
            }
        }
                 
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: UnsavedEditPolicy.decision(
                original: originalRawText,
                current: rawText
            ) == .offerToSave,
            save: { completion in
                 
                 
                 
                 
                 
                 
                 
                departureCompletion = completion
                Task { await requestSave() }
            },
            discard: { rawText = originalRawText }
        )
        .hakoStackNavigationViewStyle()
        .alert("Save your changes?", isPresented: $asksAboutUnsaved) {
            Button("Save") {
                if editWillBeOverwrittenByAutoUpdate {
                    asksAboutAutoUpdate = true
                } else {
                    Task { await persist() }
                }
            }
            Button("Discard", role: .destructive) {
                dismissPresentation()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("This source has changes that have not been saved.")
        }
        .alert("Auto update will replace this edit", isPresented: $asksAboutAutoUpdate) {
            Button("Turn Off Auto Update") {
                Task {
                    await persist(disablingAutoUpdate: true)
                    settleDeparture(true)
                }
            }
            Button("Keep Auto Update") {
                Task {
                    await persist()
                    settleDeparture(true)
                }
            }
             
             
            Button("Cancel", role: .cancel) { settleDeparture(false) }
        } message: {
            Text(
                "This profile updates from its subscription. The next update overwrites what you edited here."
            )
        }
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func persist(disablingAutoUpdate: Bool = false) async {
        await Task.yield()
        defer { isSaving = false }
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if rawChanged,
            let sites = ConfigTransforms.invalidDomainSites(
                in: rawText, runtimeProfile: hakoAppleRuntimeProfileValue
            ), !sites.isEmpty
        {
            errorMessage = Self.invalidDomainMessage(sites)
            diagnosticLine = nil
            return
        }
        do {
            try await save(
                original,
                rawChanged ? rawText : nil,
                rawChanged ? importedResourceFiles : [],
                disablingAutoUpdate
            )
            dismissPresentation()
        } catch {
            diagnosticLine = CodeEditorDiagnosticParser.line(in: error.localizedDescription)
            errorMessage = safeEditMessage(error)
        }
    }

     
     
     
     
     
     
     
    private var hakoAppleRuntimeProfileValue: String {
        switch hakoAppleRuntimeProfile {
        case .macosPacketTunnel: return HakoAppleRuntimeProfile.macosPacketTunnel.rawValue
        case .iosPacketTunnel, .tvosPacketTunnel: return ""
        }
    }

     
     
     
     
     
     
     
    private static func invalidDomainMessage(_ sites: [InvalidDomainSite]) -> String {
        let lines = sites.prefix(8).map { site -> String in
            let place: String
            switch site.locator {
            case .index(let index): place = "\(site.field)[\(index)]"
            case .key(let key): place = "\(site.field)[\"\(key)\"]"
            }
            let why: String
            switch site.reason {
            case .barePlus: why = "a lone + matches nothing"
            case .plusOutsideLeadingLabel: why = "+ is only allowed as the whole first label"
            case .starInsideLabel: why = "* cannot sit inside a label"
            case .trailingDot: why = "a trailing dot"
            case .whitespace: why = "surrounding whitespace"
            case .empty: why = "an empty value"
            case .emptySegment: why = "an empty label"
            case .other: why = "the core refuses this pattern"
            }
            return "\(place) “\(site.entry)” — \(why)"
        }
        let more = sites.count > 8 ? "\n… and \(sites.count - 8) more" : ""
         
         
         
         
        let heading = "The core will refuse this configuration:"
        return ([heading] + lines).joined(separator: "\n") + more
    }

    private func settleDeparture(_ saved: Bool) {
        let completion = departureCompletion
        departureCompletion = nil
        completion?(saved)
    }

    private func requestSave() async {
        if editWillBeOverwrittenByAutoUpdate {
             
             
             
            isSaving = false
            asksAboutAutoUpdate = true
        } else {
            await persist()
             
             
            settleDeparture(true)
        }
    }

    private func dismissPresentation() {
        (productModalDismiss ?? { dismiss() })()
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
             
             
             
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
                return ExternalResourceImportFile(fileName: url.lastPathComponent, data: data)
            }
            guard let yamlFile = selected.first(where: {
                $0.fileName == yamlURL.lastPathComponent
            }), let text = String(data: yamlFile.data, encoding: .utf8) else {
                throw CocoaError(.fileReadInapplicableStringEncoding)
            }
            try ConfigTransforms.validateSource(text)
            rawText = text
            importedResourceFiles = selected.filter {
                $0.fileName != yamlURL.lastPathComponent
            }
            diagnosticLine = nil
            errorMessage = ""
        } catch {
            diagnosticLine = CodeEditorDiagnosticParser.line(in: error.localizedDescription)
            errorMessage = safeEditMessage(error)
        }
    }

    private func safeEditMessage(_ error: Error) -> String {
        let classified = ConfigurationFailureClassifier.classify(
            error,
            context: .activation,
            preservesLastKnownGood: true
        )
         
         
         
         
         
         
        if case .yamlSyntax = classified?.kind {
            return "This is not valid YAML. Check the line the editor marked, then save again."
        }
        return classified?.localizedDescription
            ?? "The profile could not be saved."
    }
}

 
 
 
private struct HakoBarFadesWhileTyping: ViewModifier {
    @Binding var typing: Bool

    func body(content: Content) -> some View {
#if os(iOS)
        barHidden(content)
            .overlay(alignment: .top) {
                if typing {
                    Color.clear
                        .frame(height: 24)
                        .contentShape(Rectangle())
                        .onTapGesture { typing = false }
                        .accessibilityHidden(true)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: typing)
#else
        content
#endif
    }

#if os(iOS)
    @ViewBuilder
    private func barHidden(_ content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.toolbar(typing ? .hidden : .visible, for: .navigationBar)
        } else {
            content.navigationBarHidden(typing)
        }
    }
#endif
}
