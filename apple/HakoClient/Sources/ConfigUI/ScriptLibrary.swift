import Foundation
import HakoClientUI
import SwiftUI
import UniformTypeIdentifiers

struct ConfigScript: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    var body: String
}

enum ScriptImportError: LocalizedError, Equatable {
    case emptyAddress
    case notAnAddress
    case unsupportedScheme(String)
    case notText
    case empty

    var errorDescription: String? {
        switch self {
        case .emptyAddress:
            return "Enter the address of the script you want to import."
        case .notAnAddress:
             
             
            return "That is not a web address. Paste the link to the script file, not the script."
        case let .unsupportedScheme(scheme):
            return HakoCopy.format(
                "Scripts are imported over http or https. This address uses %@.",
                locale: .current,
                scheme
            )
        case .notText:
            return "The address answered with something that is not text."
        case .empty:
            return "The address answered with an empty document."
        }
    }
}

 
 
 
 
 
 
 
enum ScriptEditorSource: Hashable { case write, url, file }

 
 
 
 
 
 
 
 
 
enum ScriptEditorSaveIntent: Equatable {
    case save
    case importThenSave

    static func decide(source: ScriptEditorSource, address: String) -> ScriptEditorSaveIntent {
        guard source == .url,
              !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .save }
        return .importThenSave
    }
}

 
 
 
 
 
 
 
 
enum ScriptImport {
     
     
    static let maxBytes = 1 << 20

     
    static func address(_ raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ScriptImportError.emptyAddress }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host, !host.isEmpty,
              let url = components.url
        else { throw ScriptImportError.notAnAddress }
        guard scheme == "http" || scheme == "https" else {
            throw ScriptImportError.unsupportedScheme(scheme)
        }
        return url
    }

     
     
     
     
     
    static func suggestedName(for url: URL) -> String? {
        let stem = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stem.isEmpty, stem != "/", !stem.contains("..") else { return nil }
        return String(stem.prefix(64))
    }

     
     
     
     
     
     
     
    static func body(
        at raw: String,
        using downloader: HTTPFetching = ResourceDownloader()
    ) async throws -> String {
        var request = URLRequest(url: try address(raw))
        request.setValue(ClientUserAgent.resolved(), forHTTPHeaderField: "User-Agent")
        let result = try await downloader.fetch(
            request,
            maxBytes: maxBytes,
            redirectPolicy: .followAcrossOrigins(maxHops: 5)
        )
        guard let text = String(data: result.data, encoding: .utf8) else {
            throw ScriptImportError.notText
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScriptImportError.empty
        }
        return text
    }
}

enum ScriptLibraryError: LocalizedError {
    case missing(String)

    var errorDescription: String? {
        switch self {
        case let .missing(id): return "Selected override script '\(id)' no longer exists."
        }
    }
}

 
 
 
 
 
 
 
 
enum UnsavedEditPolicy: Equatable {
    case leave
    case offerToSave

    static func decision(original: String, current: String) -> UnsavedEditPolicy {
         
         
         
        current == original ? .leave : .offerToSave
    }
}

enum ScriptLibrary {
    private static let key = "script.library"

    static var appGroupDefaults: UserDefaults {


        return UserDefaults(suiteName: HakoAppIdentifiers.appGroup) ?? .standard
    }



     
    static let defaultLabel = "New Script"

    static func load(from defaults: UserDefaults = appGroupDefaults) -> [ConfigScript] {
        guard let data = defaults.data(forKey: key),
              let scripts = try? JSONDecoder().decode([ConfigScript].self, from: data) else {
            return []
        }
        return scripts
    }

     
     
     
     
     
     
     
    static let didChange = Notification.Name("HakoScriptLibraryDidChange")

    static func save(_ scripts: [ConfigScript], in defaults: UserDefaults = appGroupDefaults) {
        guard let data = try? JSONEncoder().encode(scripts) else { return }
        defaults.set(data, forKey: key)
        NotificationCenter.default.post(name: didChange, object: defaults)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static let testConfigYAML = """
    mode: rule
    log-level: info
    proxies:
      - name: "HK-01"
        type: trojan
        server: hk01.example.com
        port: 443
        password: "test-only"
      - name: "JP-01 2x"
        type: ss
        server: jp01.example.com
        port: 8388
        cipher: aes-128-gcm
        password: "test-only"
    proxy-providers: {}
    proxy-groups:
      - name: PROXY
        type: select
        proxies:
          - HK-01
          - JP-01 2x
          - DIRECT
    rules:
      - MATCH,PROXY
    """

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func editedScript(
        id: String,
        label: String,
        body: String,
        existing: [ConfigScript] = []
    ) -> ConfigScript? {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let taken = existing.contains {
            $0.id != id
                && $0.label.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !taken else { return nil }
        return ConfigScript(id: id, label: trimmed, body: body)
    }

    static func upsert(_ script: ConfigScript, in defaults: UserDefaults = appGroupDefaults) {
        var scripts = load(from: defaults)
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index] = script
        } else {
            scripts.append(script)
        }
        save(scripts, in: defaults)
    }

    static func remove(
        id: String,
        in defaults: UserDefaults = appGroupDefaults,
        unlinkProfiles: Bool = true
    ) {
        save(load(from: defaults).filter { $0.id != id }, in: defaults)
        guard unlinkProfiles else { return }
        guard let container = HakoAppIdentifiers.appGroupContainer else { return }
        let store = ProfileStore(
            fileURL: container.appendingPathComponent("working/store/profiles.json")
        )
        let profiles = unlinkReferences(to: id, from: store.load())
        try? store.save(profiles)
    }

     
     
     
     
    static func activeProfileName() -> String {
        guard let container = HakoAppIdentifiers.appGroupContainer,
              let configStore = try? ConfigResourceStore(containerURL: container),
              let activeID = (try? configStore.activeIdentity())?.profileID
        else { return "" }
        let profiles = ProfileStore(
            fileURL: container.appendingPathComponent("working/store/profiles.json")
        )
        return profiles.load().first { $0.id == activeID }?.label ?? ""
    }

    static func unlinkReferences(to id: String, from profiles: [Profile]) -> [Profile] {
        profiles.map { profile in
            guard profile.selectedScriptID == id || profile.postMergeScriptID == id else {
                return profile
            }
            var updated = profile
            if updated.selectedScriptID == id {
                updated.selectedScriptID = nil
            }
            if updated.postMergeScriptID == id {
                updated.postMergeScriptID = nil
            }
            return updated
        }
    }

    static func apply(id: String?, to yaml: String,
                      profileName: String = "",
                      from defaults: UserDefaults = appGroupDefaults) throws -> String {
        try apply(
            id: id, to: yaml, scripts: load(from: defaults), profileName: profileName
        )
    }

    static func apply(
        id: String?,
        to yaml: String,
        scripts: [ConfigScript],
        profileName: String = ""
    ) throws -> String {
        guard let id else { return yaml }
        guard let script = scripts.first(where: { $0.id == id }) else {
            throw ScriptLibraryError.missing(id)
        }
        let configJSON = try ConfigTransforms.yamlToJSON(yaml)
        let rewritten = try ScriptEngine.run(
            script: script.body, configJSON: configJSON, profileName: profileName
        )
        return try ConfigTransforms.jsonToYAML(rewritten)
    }
}

struct ScriptLibraryView: View {
    @State private var scripts = ScriptLibrary.load()
    @State private var editing: ConfigScript?
    @State private var adding = false

    var body: some View {
        Group {
#if os(macOS)
         
         
         
         
         
         
        Form {
            if scripts.isEmpty {
                Section {
                HakoEmptyState(
                    title: "No Scripts",
                    message: "Create a reusable main(config) transform, then select it in a profile override.",
                    symbol: .curlybraces
                )
                .listRowSeparator(.hidden)
                }
            } else {
                Section {
            ForEach(scripts) { script in
                Button { editing = script } label: {
                    HakoDestinationRow(
                         
                        title: .verbatim(script.label),
                        subtitle: "JavaScript main(config)",
                        symbol: .curlybraces,
                        tint: .purple
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("scripts.row.\(script.id)")
            }
            .onDelete { offsets in
                let ids = offsets.compactMap { scripts.indices.contains($0) ? scripts[$0].id : nil }
                ids.forEach { ScriptLibrary.remove(id: $0) }
                scripts = ScriptLibrary.load()
            }
                }
            }
            Section {
                HakoAddRow(Text(HakoCopy.key("Add Script"))) {
                    adding = true
                }
                .accessibilityIdentifier("scripts.row.add")
            }
        }
#else
        List {
            if scripts.isEmpty {
                HakoEmptyState(
                    title: "No Scripts",
                    message: "Create a reusable main(config) transform, then select it in a profile override.",
                    symbol: .curlybraces
                )
                .listRowSeparator(.hidden)
            }
            ForEach(scripts) { script in
                Button { editing = script } label: {
                    HakoDestinationRow(
                         
                        title: .verbatim(script.label),
                        subtitle: "JavaScript main(config)",
                        symbol: .curlybraces,
                        tint: .purple
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("scripts.row.\(script.id)")
            }
            .onDelete { offsets in
                let ids = offsets.compactMap { scripts.indices.contains($0) ? scripts[$0].id : nil }
                ids.forEach { ScriptLibrary.remove(id: $0) }
                scripts = ScriptLibrary.load()
            }
        }
        .hakoInsetGroupedListStyle()
#endif
        }
        .hakoPageTitle("Scripts")
        .hakoDetailPageInsets()
        .accessibilityIdentifier("scripts.screen")
        .hakoToolbarUnlessInPanel {
            ToolbarItemGroup(placement: .hakoNavigationTrailing) {
                HakoEditButton()
                Button { adding = true } label: {
                    Label("Add Script", systemImage: HakoSymbol.plus.name)
                }
            }
        }
        .hakoProductModal(item: $editing, role: .page) { script in
            ScriptEditorView(script: script) { save($0) }
                .hakoModalPresentation(.page)
        }
        .hakoProductModal(isPresented: $adding, role: .page) {
            ScriptEditorView(
                script: ConfigScript(
                    id: UUID().uuidString.lowercased(),
                    label: ScriptLibrary.defaultLabel,
                    body: ScriptSettings.template
                )
            ) { save($0) }
            .hakoModalPresentation(.page)
        }
    }

    private func save(_ script: ConfigScript) {
        ScriptLibrary.upsert(script)
        scripts = ScriptLibrary.load()
        editing = nil
        adding = false
    }
}

private struct ScriptEditorView: View {
    let script: ConfigScript
    let save: (ConfigScript) -> Void

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss) private var productModalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @State private var label: String
    @State private var bodyText: String
    @State private var result = ""
     
     
     
     
     
     
     
     
     
     
    @State private var activeProfileName: String?
     
     
    @State private var activeProfileNameLoad: Task<String, Never>?
    @State private var diagnosticLine: Int?
    @State private var asksAboutUnsaved = false

    @State private var source: ScriptEditorSource = .write
    @State private var importAddress = ""
    @State private var showsFileImporter = false
    @State private var importing = false
     
     
     
     
    @State private var importResult = ""
     
     
     
    @State private var saveResult = ""
    private let originalBody: String

    init(script: ConfigScript, save: @escaping (ConfigScript) -> Void) {
        self.script = script
        self.save = save
        originalBody = script.body
        _label = State(initialValue: script.label)
        _bodyText = State(initialValue: script.body)
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            VStack(spacing: 0) {
            sourceBar
            Form {
                Section {
                    TextField("Script name", text: $label)
                        .accessibilityIdentifier("scripts.editor.name")
                    if !saveResult.isEmpty {
                        HakoStatusMessage(text: .copy(saveResult), kind: .error)
                            .accessibilityIdentifier("scripts.editor.save.result")
                    }
                } header: {
                    Text("Name")
                }
                switch source {
                case .write: EmptyView()
                case .url: urlPane
                case .file: filePane
                }
                Section("Script") {
                    CodeEditorPanel(
                        text: $bodyText,
                        language: .javascript,
                        minHeight: 320,
                        diagnosticLine: diagnosticLine
                    )
                }
                Section {
                     
                     
                     
                     
                     
                    Button("Test Run") { Task { await test() } }
                        .accessibilityIdentifier("scripts.editor.test")
                    if !result.isEmpty {
                        HakoStatusMessage(
                            text: .copy(result),
                            kind: result.hasPrefix("OK") ? .success : .error
                        )
                        .accessibilityIdentifier("scripts.editor.result")
                    }
                }
            }
            }
            .hakoPageTitle("Script")
            .fileImporter(
                isPresented: $showsFileImporter,
                allowedContentTypes: [.javaScript, .plainText, .text],
                allowsMultipleSelection: false
            ) { outcome in
                importFromFile(outcome)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !insideProductModal {
                        Button("Cancel") {
                            switch UnsavedEditPolicy.decision(
                                original: originalBody,
                                current: bodyText
                            ) {
                            case .leave: dismissPresentation()
                            case .offerToSave: asksAboutUnsaved = true
                            }
                        }
                        .accessibilityIdentifier("scripts.editor.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                        Button("Save") {
                            persist()
                        }
                        .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("scripts.editor.save")
                    }
                }
            }
            .hakoProductModalRoot(title: "Script")
            .task { await loadActiveProfileName() }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                    HakoModalActionBar(
                        primaryTitle: "Save",
                        primaryDisabled: label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        onPrimary: persist
                    )
                }
            }
        }
        .hakoStackNavigationViewStyle()
         
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: UnsavedEditPolicy.decision(
                original: originalBody,
                current: bodyText
            ) == .offerToSave,
            save: { completion in
                persist()
                completion(true)
            },
            discard: { bodyText = originalBody }
        )
        .alert("Save your changes?", isPresented: $asksAboutUnsaved) {
            Button("Save") {
                persist()
            }
            Button("Discard", role: .destructive) {
                dismissPresentation()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("This script has changes that have not been saved.")
        }
        .accessibilityIdentifier("scripts.editor.screen")
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
     
     
     
     
     
    @discardableResult
    private func loadActiveProfileName() async -> String {
        if let activeProfileName { return activeProfileName }
        if let inFlight = activeProfileNameLoad { return await inFlight.value }
        let load = Task.detached(priority: .utility) {
            ScriptLibrary.activeProfileName()
        }
        activeProfileNameLoad = load
        let name = await load.value
        activeProfileName = name
        activeProfileNameLoad = nil
        return name
    }

    @discardableResult
    private func validate(name: String) -> Bool {
        do {
            let json = try ConfigTransforms.yamlToJSON(ScriptLibrary.testConfigYAML)
             
             
             
             
             
            let output = try ScriptEngine.run(
                script: bodyText,
                configJSON: json,
                profileName: name
            )
            _ = try ConfigTransforms.jsonToYAML(output)
            result = "OK — script returned a valid config object."
            diagnosticLine = nil
            return true
        } catch {
            diagnosticLine = CodeEditorDiagnosticParser.line(in: error.localizedDescription)
            result = "Error: \(error.localizedDescription)"
            return false
        }
    }

     
     
     
     
     
    private var sourceBar: some View {
#if os(macOS)
        HStack(spacing: 2) {
            sourceSegment(.write, "Write", identifier: "scripts.editor.source.write")
            sourceSegment(.url, "URL", identifier: "scripts.editor.source.url")
            sourceSegment(.file, "File", identifier: "scripts.editor.source.file")
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
        Picker(HakoCopy.key("Source"), selection: $source) {
            Text(HakoCopy.key("Write")).tag(ScriptEditorSource.write)
            Text(HakoCopy.key("URL")).tag(ScriptEditorSource.url)
            Text(HakoCopy.key("File")).tag(ScriptEditorSource.file)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("scripts.editor.source")
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 2)
#endif
    }

#if os(macOS)
    private func sourceSegment(
        _ value: ScriptEditorSource,
        _ key: String,
        identifier: String
    ) -> some View {
        Button { source = value } label: {
            Text(HakoCopy.key(key))
                .font(.callout.weight(source == value ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if source == value {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .controlColor))
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
            }
        }
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(source == value ? .isSelected : [])
    }
#endif

    private var urlPane: some View {
        Section {
             
             
             
            TextField(
                HakoCopy.key("Script URL"),
                text: $importAddress,
                prompt: Text(verbatim: "https://example.com/script.js")
            )
                .textContentType(.URL)
#if !os(macOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
#endif
                .autocorrectionDisabled()
                .accessibilityIdentifier("scripts.editor.import.address")
            Button(importing ? "Importing…" : "Import") {
                Task { @MainActor in await importFromAddress() }
            }
            .disabled(importing || importAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("scripts.editor.import.url")
            if !importResult.isEmpty {
                HakoStatusMessage(text: .copy(importResult), kind: .error)
                    .accessibilityIdentifier("scripts.editor.import.result")
            }
        } footer: {
            Text("Paste the link to the script file. Its text replaces what is in the editor.")
        }
    }

    private var filePane: some View {
        Section {
            Button("Choose File…") { showsFileImporter = true }
                .accessibilityIdentifier("scripts.editor.import.file")
            if !importResult.isEmpty {
                HakoStatusMessage(text: .copy(importResult), kind: .error)
                    .accessibilityIdentifier("scripts.editor.import.result")
            }
        } footer: {
            Text("Pick a .js file. Its text replaces what is in the editor.")
        }
    }

     
     
     
     
     
    @MainActor
    private func importFromAddress() async {
        importing = true
        importResult = ""
        defer { importing = false }
        do {
            let text = try await ScriptImport.body(at: importAddress)
            bodyText = text
            result = ""
            diagnosticLine = nil
            if label == ScriptLibrary.defaultLabel || label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let url = try? ScriptImport.address(importAddress),
               let suggested = ScriptImport.suggestedName(for: url) {
                label = suggested
            }
            source = .write
        } catch {
            importResult = (error as NSError).localizedDescription
        }
    }

    private func importFromFile(_ outcome: Result<[URL], Error>) {
        switch outcome {
        case let .success(urls):
            guard let url = urls.first else { return }
             
             
             
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            importResult = ""
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    importResult = ScriptImportError.empty.localizedDescription
                    return
                }
                bodyText = text
                result = ""
                diagnosticLine = nil
                source = .write
            } catch {
                importResult = ScriptImportError.notText.localizedDescription
            }
        case let .failure(error):
            importResult = (error as NSError).localizedDescription
        }
    }

    private func test() async { _ = validate(name: await loadActiveProfileName()) }

    private func persist() {
        switch ScriptEditorSaveIntent.decide(source: source, address: importAddress) {
        case .importThenSave:
             
             
             
             
             
             
             
            Task { @MainActor in
                await importFromAddress()
                 
                 
                guard importResult.isEmpty else { return }
                commit()
            }
        case .save:
            commit()
        }
    }

    private func commit() {
        guard let edited = ScriptLibrary.editedScript(
            id: script.id,
            label: label,
            body: bodyText,
            existing: ScriptLibrary.load()
        ) else {
            saveResult = "Another script already uses that name."
            return
        }
        saveResult = ""
        save(edited)
        dismissPresentation()
    }

    private func dismissPresentation() {
        (productModalDismiss ?? { dismiss() })()
    }
}
