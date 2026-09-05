import Foundation

 
 
struct AddProfileDraft: Equatable {
    enum Tab: String, CaseIterable, Identifiable, Equatable {
        case link
        case file
         
         
         
         
         
         
        case blank
        var id: String { rawValue }
    }

    enum LinkFooter: Equatable {
        case accepts
        case downloadsOverHTTPS
        case cleartextWarning
        case unwrappedInstallLink(host: String)
    }

    enum CrossReference: Equatable {
        case configTextBelongsInFile
        case nodeBelongsInCustomNodes
    }

    var tab: Tab = .link
    var label = ""
    var linkText = ""
    var pastedConfigText = ""
    var importedFileName = ""
    var importedYAML = ""
    var importedResourceNames: [String] = []
    var importError = ""
     
     
    var importNotice = ""

     
     
    var resolvedLink: String {
        if case .link(let url, _) = PastedContentClassifier.classify(linkText) {
            return url
        }
        return linkText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        switch tab {
        case .link:
            return !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file:
            return !importedYAML.isEmpty || !pastedConfigText.isEmpty
        case .blank:
             
            return true
        }
    }

     
     
     
     
     
     
     
    var blockingRequirement: String? {
        guard !canSubmit else { return nil }
        switch tab {
        case .link:
            return "Paste a subscription link or configuration text to continue."
        case .file:
            return "Choose a configuration file, or paste its text, to continue."
        case .blank:
            return nil
        }
    }

    var linkFooter: LinkFooter {
        switch PastedContentClassifier.classify(linkText) {
        case .empty, .unrecognized, .configText, .nodeShareLinks:
            return .accepts
        case .link(let url, let unwrapped):
            if unwrapped != nil {
                return .unwrappedInstallLink(host: URL(string: url)?.host ?? url)
            }
             
             
             
             
             
            switch URL(string: url)?.scheme?.lowercased() {
            case "http": return .cleartextWarning
            case "https": return .downloadsOverHTTPS
            default: return .accepts
            }
        }
    }

     
     
     
    var crossReference: CrossReference? {
        if !pendingConfigText.isEmpty { return .configTextBelongsInFile }
        if case .nodeShareLinks = PastedContentClassifier.classify(linkText) {
            return .nodeBelongsInCustomNodes
        }
        return nil
    }

     
     
     
    mutating func normalizeLinkText() {
        guard linkText.contains(where: \.isNewline) else { return }
        linkText = linkText.split(whereSeparator: \.isNewline).joined()
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func configurationFile(among urls: [URL]) -> URL? {
        let yaml = urls.filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }
        if yaml.count == 1 { return yaml.first }
        if yaml.isEmpty, urls.count == 1 { return urls.first }
        return nil
    }

     
     
     
     
     
     
     
     
     
     
     
    static let maximumPastedBytes = 8 * 1024 * 1024

     
     
     
    var configPreviewLines: [String] {
        let window = pastedConfigText.prefix(4 * 1_024)
        return Array(window.split(whereSeparator: \.isNewline).prefix(4).map(String.init))
    }

     
     
    var pastedConfigSummary: String? {
        guard !pastedConfigText.isEmpty else { return nil }
        let lines = pastedConfigText.reduce(into: 1) { count, character in
            if character.isNewline { count += 1 }
        }
        return lines > configPreviewLines.count ? String(lines) : nil
    }

    mutating func acceptPaste(_ raw: String) {
        importError = ""
        importNotice = ""
        switch PastedContentClassifier.classify(raw) {
        case .configText(let body):
            pendingConfigText = body
        case .empty:
            break
        case .link(let url, let unwrapped):
            linkText = unwrapped == nil
                ? url
                : raw.trimmingCharacters(in: .whitespacesAndNewlines)
        case .nodeShareLinks, .unrecognized:
            linkText = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

     
     
     
    mutating func acceptConfigTextPaste(_ raw: String) {
        importError = ""
        importNotice = ""
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard raw.utf8.count <= Self.maximumPastedBytes else {
            importError = "That configuration is too large to paste. Import it as a file instead."
            return
        }
        pastedConfigText = raw
        importedFileName = ""
        importedYAML = ""
        importedResourceNames = []
    }

     
     
    mutating func acceptImportedFile(name: String, yaml: String, resourceNames: [String]) {
        importError = ""
        importedFileName = name
        importedYAML = yaml
        importedResourceNames = resourceNames
        pastedConfigText = ""
    }

     
     
    private(set) var pendingConfigText = ""

    mutating func movePendingConfigTextToFileTab() {
        guard !pendingConfigText.isEmpty else { return }
        let held = pendingConfigText
        pendingConfigText = ""
        acceptConfigTextPaste(held)
        tab = .file
    }
}
