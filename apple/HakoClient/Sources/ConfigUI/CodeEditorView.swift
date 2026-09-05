import HakoClientUI
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum CodeEditorLanguage {
    case yaml
    case json
    case javascript
}

enum CodeHighlightKind: Hashable {
    case key
    case string
    case number
    case literal
    case comment
    case keyword
}

struct CodeHighlightToken: Equatable {
    let range: NSRange
    let kind: CodeHighlightKind
}

struct CodeHighlightResult: Equatable {
    let inspectedRange: NSRange
    let tokens: [CodeHighlightToken]
}

enum CodeEditorPolicy {
    static let highlightWindowUTF16 = 32_768
    static let maximumSearchMatches = 500
    static let largeFileUTF16 = 200_000
}

 
 
 
 
 
 
 
 
 
 
struct CodeEditorTextMirror {
    private(set) var text: String
    private(set) var resyncs = 0

    init(text: String) {
        self.text = text
    }

    mutating func reset(to text: String) {
        self.text = text
    }

     
     
     
    mutating func apply(editedRange: NSRange, changeInLength delta: Int, storage: NSString) {
        let replaced = NSRange(location: editedRange.location, length: editedRange.length - delta)
        if replaced.location >= 0, replaced.length >= 0,
           replaced.location + replaced.length <= text.utf16.count,
           let range = Range(replaced, in: text) {
            text.replaceSubrange(range, with: storage.substring(with: editedRange))
            if text.utf16.count == storage.length { return }
        }
        resyncs += 1
        text = CodeEditorSearch.nativeCopy(of: storage)
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum CodeEditorTextScale {
    static let range: ClosedRange<CGFloat> = 0.7...2.4
    private static let key = "hako.editor.textScale"

    static var factor: CGFloat {
        get {
            let stored = UserDefaults.standard.double(forKey: key)
            guard stored > 0 else { return 1 }
            return min(max(CGFloat(stored), range.lowerBound), range.upperBound)
        }
        set {
            UserDefaults.standard.set(
                Double(min(max(newValue, range.lowerBound), range.upperBound)),
                forKey: key
            )
        }
    }
}

 
 
enum CodeEditorSoftWrap {
    private static let key = "hako.editor.softWrap"

    static var isOn: Bool {
        get { UserDefaults.standard.object(forKey: key) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum CodeEditorLineNumbers {
    private static let key = "hako.editor.lineNumbers"

    static var isOn: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum CodeEditorChrome: Equatable {
    case full
    case minimal

    func showsFindRow(requested: Bool) -> Bool {
        switch self {
        case .full: return true
        case .minimal: return requested
        }
    }

    var showsStatusRow: Bool { self == .full }

     
    var findRowIsDismissible: Bool { self == .minimal }
}

enum CodeSyntaxHighlighter {
    private struct Pattern {
        let expression: NSRegularExpression
         
         
        let kinds: [CodeHighlightKind]

        init(_ pattern: String, kind: CodeHighlightKind, options: NSRegularExpression.Options = []) {
            expression = try! NSRegularExpression(pattern: pattern, options: options)
            kinds = [kind]
        }

         
         
         
         
         
         
        init(groups pattern: String, kinds: [CodeHighlightKind], options: NSRegularExpression.Options = []) {
            expression = try! NSRegularExpression(pattern: pattern, options: options)
            self.kinds = kinds
        }

        func kind(of match: NSTextCheckingResult) -> CodeHighlightKind {
            guard kinds.count > 1 else { return kinds[0] }
            for (index, kind) in kinds.enumerated()
            where match.range(at: index + 1).location != NSNotFound {
                return kind
            }
            return kinds[0]
        }
    }

    static func highlight(
        _ text: String,
        language: CodeEditorLanguage,
        around visibleRange: NSRange
    ) -> CodeHighlightResult {
        let length = (text as NSString).length
        guard length > 0 else {
            return CodeHighlightResult(inspectedRange: NSRange(location: 0, length: 0), tokens: [])
        }
        let inspectedRange = inspectedRange(for: visibleRange, length: length)
        let tokens = patterns(for: language).flatMap { pattern in
            pattern.expression.matches(in: text, range: inspectedRange).map {
                CodeHighlightToken(range: $0.range, kind: pattern.kind(of: $0))
            }
        }
        return CodeHighlightResult(inspectedRange: inspectedRange, tokens: tokens)
    }

     
     
     
     
     
     
     
     
    static func inspectedRange(for visibleRange: NSRange, length: Int) -> NSRange {
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let visibleLocation = min(max(0, visibleRange.location), length)
        let desiredLength = min(CodeEditorPolicy.highlightWindowUTF16, length)
        let leadingContext = max(0, (desiredLength - min(visibleRange.length, desiredLength)) / 2)
        let start = min(max(0, visibleLocation - leadingContext), length - desiredLength)
        return NSRange(location: start, length: desiredLength)
    }

    private static func patterns(for language: CodeEditorLanguage) -> [Pattern] {
        let anchors: NSRegularExpression.Options = [.anchorsMatchLines]
        switch language {
        case .yaml:
            return [
                 
                 
                 
                 
                Pattern(
                    groups: "(\\\"(?:\\\\.|[^\\\"])*\\\"|'(?:''|[^'])*')|((?:^|(?<=\\s))#.*$)",
                    kinds: [.string, .comment], options: anchors
                ),
                Pattern("\\b(?:true|false|null|yes|no|on|off)\\b", kind: .literal,
                        options: [.caseInsensitive]),
                Pattern("(?<![A-Za-z0-9_.])-?\\d+(?:\\.\\d+)?\\b", kind: .number),
                 
                 
                 
                Pattern("^[ \\t-]*[A-Za-z0-9_.\\\"']+(?=\\s*:(?:\\s|$))", kind: .key, options: anchors)
            ]
        case .json:
            return [
                Pattern("\\\"(?:\\\\.|[^\\\"])*\\\"", kind: .string),
                Pattern("\\b(?:true|false|null)\\b", kind: .literal),
                Pattern("(?<![A-Za-z0-9_.])-?\\d+(?:\\.\\d+)?(?:[eE][+-]?\\d+)?\\b", kind: .number),
                Pattern("\\\"(?:\\\\.|[^\\\"])*\\\"(?=\\s*:)", kind: .key)
            ]
        case .javascript:
            return [
                Pattern(
                    groups: "(\\\"(?:\\\\.|[^\\\"])*\\\"|'(?:\\\\.|[^'])*'|`(?:\\\\.|[^`])*`)|(//.*$|/\\*[\\s\\S]*?\\*/)",
                    kinds: [.string, .comment], options: anchors
                ),
                Pattern("\\b(?:break|case|catch|class|const|continue|default|delete|do|else|export|extends|false|finally|for|function|if|import|in|instanceof|let|new|null|return|switch|this|throw|true|try|typeof|undefined|var|void|while|yield)\\b",
                        kind: .keyword),
                Pattern("(?<![A-Za-z0-9_$])-?\\d+(?:\\.\\d+)?\\b", kind: .number)
            ]
        }
    }
}

struct CodeEditorPosition: Equatable {
    let line: Int
    let column: Int
}

enum CodeEditorSearch {
    static func ranges(
        of query: String,
        in text: String,
        limit: Int = CodeEditorPolicy.maximumSearchMatches
    ) -> [NSRange] {
        guard !query.isEmpty, limit > 0 else { return [] }
        let source = text as NSString
        var result: [NSRange] = []
        var searchRange = NSRange(location: 0, length: source.length)
        while result.count < limit, searchRange.length > 0 {
            let match = source.range(of: query, options: [.caseInsensitive], range: searchRange)
            guard match.location != NSNotFound else { break }
            result.append(match)
            let next = NSMaxRange(match)
            searchRange = NSRange(location: next, length: source.length - next)
        }
        return result
    }

    static func lineAndColumn(at utf16Offset: Int, in text: String) -> CodeEditorPosition {
        let source = text as NSString
        let offset = min(max(0, utf16Offset), source.length)
        let prefix = source.substring(to: offset) as NSString
        var line = 1
        var lastLineStart = 0
        for index in 0..<prefix.length where prefix.character(at: index) == 10 {
            line += 1
            lastLineStart = index + 1
        }
        return CodeEditorPosition(line: line, column: offset - lastLineStart + 1)
    }

     
     
     
     
     
     
     
     
    static func lineAndColumn(
        at utf16Offset: Int, lineStarts: [Int], length: Int
    ) -> CodeEditorPosition {
        guard !lineStarts.isEmpty else {
            return CodeEditorPosition(line: 1, column: max(1, utf16Offset + 1))
        }
        let offset = min(max(0, utf16Offset), length)
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return CodeEditorPosition(line: low + 1, column: offset - lineStarts[low] + 1)
    }

     
     
     
     
     
     
     
     
     
     
     
     
    static func lineStarts(in text: String) -> [Int] {
        if let starts = text.utf8.withContiguousStorageIfAvailable(Self.lineStarts(utf8:)) {
            return starts
        }
        let source = text as NSString
        var starts = [0]
        let length = source.length
        guard length > 0 else { return starts }
        var units = [unichar](repeating: 0, count: length)
        source.getCharacters(&units, range: NSRange(location: 0, length: length))
        for index in 0..<length where units[index] == 10 {
            starts.append(index + 1)
        }
        return starts
    }

     
     
     
     
     
     
     
    static func nativeCopy(of storage: NSString) -> String {
        let length = storage.length
        guard length > 0 else { return "" }
        var units = [unichar](repeating: 0, count: length)
        storage.getCharacters(&units, range: NSRange(location: 0, length: length))
        return String(utf16CodeUnits: units, count: length)
    }

    private static func lineStarts(utf8 bytes: UnsafeBufferPointer<UInt8>) -> [Int] {
        var starts = [0]
        var offset = 0
        for byte in bytes {
            if byte == 0x0A { starts.append(offset + 1) }
            if byte & 0xC0 != 0x80 {
                offset += byte >= 0xF0 ? 2 : 1
            }
        }
        return starts
    }

    static func range(ofLine line: Int, in text: String) -> NSRange? {
        guard line > 0 else { return nil }
        let source = text as NSString
        let starts = lineStarts(in: text)
        guard starts.indices.contains(line - 1) else { return nil }
        let start = starts[line - 1]
        let end = line < starts.count ? max(start, starts[line] - 1) : source.length
        return NSRange(location: start, length: end - start)
    }

    static func lineCount(in text: String) -> Int {
        let source = text as NSString
        guard source.length > 0 else { return 1 }
        var count = 1
        for index in 0..<source.length where source.character(at: index) == 10 { count += 1 }
        return count
    }
}

 
 
 
 
 
 
 
enum CodeEditorIndentation {
    static let unit = "  "

    struct Edit: Equatable {
        let text: String
        let selection: NSRange
        let replacedRange: NSRange
        let replacement: String
    }

    static func indent(_ text: String, selection: NSRange) -> Edit {
        transform(text, selection: selection) { line in (unit + line, unit.utf16.count) }
    }

    static func outdent(_ text: String, selection: NSRange) -> Edit {
        transform(text, selection: selection) { line in
            var rest = Substring(line)
            var removed = 0
            while removed < unit.utf16.count, rest.first == " " {
                rest = rest.dropFirst()
                removed += 1
            }
            return (String(rest), -removed)
        }
    }

     
     
    private static func transform(
        _ text: String,
        selection: NSRange,
        change: (String) -> (line: String, shift: Int)
    ) -> Edit {
        let whole = text as NSString
        let location = min(max(0, selection.location), whole.length)
        var end = min(location + max(0, selection.length), whole.length)
         
        if end > location, whole.character(at: end - 1) == 0x0A { end -= 1 }
        let blockStart = lineStart(before: location, in: whole)
        let blockEnd = lineEnd(from: max(end, location), in: whole)
        let replacedRange = NSRange(location: blockStart, length: blockEnd - blockStart)
        var lines = whole.substring(with: replacedRange).components(separatedBy: "\n")
        var caretShift = 0
        var lineStartOffset = blockStart
        for (index, line) in lines.enumerated() {
            let changed = change(line)
            let lineLength = (line as NSString).length
            if selection.length == 0,
               location >= lineStartOffset, location <= lineStartOffset + lineLength {
                 
                 
                let column = location - lineStartOffset
                caretShift = changed.shift < 0 ? -min(column, -changed.shift) : changed.shift
            }
            lineStartOffset += lineLength + 1
            lines[index] = changed.line
        }
        let replacement = lines.joined(separator: "\n")
        let newSelection = selection.length == 0
            ? NSRange(location: location + caretShift, length: 0)
            : NSRange(location: blockStart, length: (replacement as NSString).length)
        return Edit(
            text: whole.replacingCharacters(in: replacedRange, with: replacement),
            selection: newSelection,
            replacedRange: replacedRange,
            replacement: replacement
        )
    }

    private static func lineStart(before index: Int, in text: NSString) -> Int {
        var i = index
        while i > 0, text.character(at: i - 1) != 0x0A { i -= 1 }
        return i
    }

    private static func lineEnd(from index: Int, in text: NSString) -> Int {
        var i = index
        while i < text.length, text.character(at: i) != 0x0A { i += 1 }
        return i
    }
}

enum CodeEditorDiagnosticParser {
    static func line(in description: String) -> Int? {
        let expression = try! NSRegularExpression(
            pattern: "(?:at\\s+)?line\\s*[:#]?\\s*(\\d+)",
            options: [.caseInsensitive]
        )
        let range = NSRange(description.startIndex..., in: description)
        guard let match = expression.firstMatch(in: description, range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: description)
        else { return nil }
        return Int(description[valueRange])
    }
}

 
 
 
 
 
 
private struct CodeEditorSnapshotStack {
    private(set) var texts: [String] = []
    private var bytes = 0

    mutating func append(_ text: String, capacity: Int, budget: Int) {
        guard texts.last != text else { return }
        texts.append(text)
        bytes += text.utf8.count
        while texts.count > capacity || (bytes > budget && texts.count > 1) {
            bytes -= texts.removeFirst().utf8.count
        }
    }

    mutating func popLast() -> String? {
        let text = texts.popLast()
        if let text { bytes -= text.utf8.count }
        return text
    }

    mutating func removeAll() {
        texts.removeAll()
        bytes = 0
    }
}

final class CodeEditorHistory: ObservableObject {
    private static let historyLimit = 100
    private static let historyByteBudget = 32 * 1024 * 1024
    private static let typingGroupDelay: TimeInterval = 0.4

    private var undoStack = CodeEditorSnapshotStack()
    private var redoStack = CodeEditorSnapshotStack()
    private var typingGroupBase: String?
    private var typingGroupWorkItem: DispatchWorkItem?
    private var currentText = ""
    private var isInitialized = false

    func attach(to text: String) {
        guard !isInitialized else { return }
        currentText = text
        isInitialized = true
    }

    func reset(to text: String) {
        typingGroupWorkItem?.cancel()
        typingGroupWorkItem = nil
        typingGroupBase = nil
        undoStack.removeAll()
        redoStack.removeAll()
        currentText = text
        isInitialized = true
    }

    func recordChange(from previousText: String, to text: String) {
        attach(to: previousText)
        if typingGroupBase == nil { typingGroupBase = previousText }
        typingGroupWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.commitTypingGroup() }
        typingGroupWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.typingGroupDelay,
            execute: workItem
        )
        currentText = text
        redoStack.removeAll()
    }

    func undo(from text: String) -> String? {
        let target: String?
        if let base = typingGroupBase {
            typingGroupWorkItem?.cancel()
            typingGroupWorkItem = nil
            typingGroupBase = nil
            target = base
        } else {
            target = undoStack.popLast()
        }
        guard let target, target != text else { return nil }
        append(text, to: &redoStack)
        currentText = target
        return target
    }

    func redo(from text: String) -> String? {
        commitTypingGroup()
        guard let target = redoStack.popLast(), target != text else { return nil }
        append(text, to: &undoStack)
        currentText = target
        return target
    }

    private func commitTypingGroup() {
        guard let base = typingGroupBase else { return }
        typingGroupBase = nil
        typingGroupWorkItem = nil
        guard base != currentText else { return }
        append(base, to: &undoStack)
    }

    private func append(_ text: String, to stack: inout CodeEditorSnapshotStack) {
        stack.append(
            text,
            capacity: Self.historyLimit,
            budget: Self.historyByteBudget
        )
    }
}

struct CodeEditorCommand: Equatable {
    enum Action: Equatable {
        case undo
        case redo
        case cut
        case copy
        case paste
        case selectAll
        case select(NSRange)

         
         
         
         
         
         
         
         
         
        var claimsFocus: Bool {
            switch self {
            case .select: false
            default: true
            }
        }
    }

    let id = UUID()
    let action: Action
}

 
 
 
 
 
 
 
 
struct CodeEditorSearchState: Equatable {
    private(set) var query = ""
    private(set) var matches: [NSRange] = []
    private(set) var index = 0

     
    mutating func queryChanged(to query: String, in text: String) -> NSRange? {
        self.query = query
        matches = CodeEditorSearch.ranges(of: query, in: text)
        index = 0
        return matches.first
    }

     
     
    mutating func textChanged(to text: String) -> NSRange? {
        guard !query.isEmpty else {
            matches = []
            index = 0
            return nil
        }
        matches = CodeEditorSearch.ranges(of: query, in: text)
         
         
        index = min(index, max(0, matches.count - 1))
        return nil
    }

     
    mutating func step(by delta: Int) -> NSRange? {
        guard !matches.isEmpty else { return nil }
        index = (index + delta + matches.count) % matches.count
        return matches[index]
    }

    var currentMatch: Int? { matches.indices.contains(index) ? index : nil }
}

 
 
 
struct CodeEditorPanel: View {
    @Binding var text: String
    let language: CodeEditorLanguage
    var minHeight: CGFloat = 300
    var diagnosticLine: Int?
    var isEditable = true
    var expandsVertically = false
    var chrome: CodeEditorChrome = .full
     
    var showsLineNumbers = true
    var softWrap = true
     
     
    var findPresented: Binding<Bool>?
     
     
    var typing: Binding<Bool>?

    @State private var query = ""
    @FocusState private var findFieldFocused: Bool
    @State private var search = CodeEditorSearchState()
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var command: CodeEditorCommand?
     
     
    @State private var lineStarts: [Int] = [0]
    @State private var textLength = 0
    @State private var lineIndexTask: Task<Void, Never>?
    @StateObject private var history = CodeEditorHistory()

     
     
     
    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: HakoTheme.Spacing.compact) {
            Image(systemName: HakoSymbol.magnifyingglass.name)
                .foregroundStyle(CodeEditorPalette.secondaryText)
                .accessibilityHidden(true)
            TextField(
                "",
                text: $query,
                prompt: Text("Find in configuration")
                    .foregroundColor(CodeEditorPalette.secondaryText)
            )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(CodeEditorPalette.primaryText)
                .tint(CodeEditorPalette.accent)
                .focused($findFieldFocused)
                .accessibilityIdentifier("codeEditor.find")
            if !query.isEmpty {
                Text(search.matches.isEmpty ? "0" : "\(search.index + 1)/\(search.matches.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(CodeEditorPalette.secondaryText)
                    .fixedSize()
                    .accessibilityIdentifier("codeEditor.matchCount")
                Button { selectMatch(delta: -1) } label: {
                    Image(systemName: HakoSymbol.arrowUp.name)
                }
                .disabled(search.matches.isEmpty)
                .accessibilityLabel("Previous Match")
                Button { selectMatch(delta: 1) } label: {
                    Image(systemName: HakoSymbol.arrowDown.name)
                }
                .disabled(search.matches.isEmpty)
                .accessibilityLabel("Next Match")
            }
            if chrome.findRowIsDismissible {
                Button {
                    query = ""
                    findPresented?.wrappedValue = false
                } label: {
                    Image(systemName: HakoSymbol.xmarkCircle.name)
                }
                .accessibilityLabel("Done")
                .accessibilityIdentifier("codeEditor.find.done")
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(CodeEditorPalette.primaryText)
        .padding(.horizontal, HakoTheme.Spacing.row)
        .frame(
            minHeight: HakoClientUI.HakoTheme.Control.minimumHitTarget
        )
    }

     
     
     
     
    @ViewBuilder
    private var commandControls: some View {
        if isEditable {
            Button { send(.undo) } label: {
                Image(systemName: HakoSymbol.arrowUturnBackward.name)
            }
            .accessibilityLabel("Undo")
            .accessibilityIdentifier("codeEditor.undo")
            .keyboardShortcut("z", modifiers: .command)
            Button { send(.redo) } label: {
                Image(systemName: HakoSymbol.arrowUturnForward.name)
            }
            .accessibilityLabel("Redo")
            .accessibilityIdentifier("codeEditor.redo")
            .keyboardShortcut("z", modifiers: [.command, .shift])
            Menu {
                Button("Select All") { send(.selectAll) }
                Button("Copy") { send(.copy) }
                Button("Cut") { send(.cut) }
                Button("Paste") { send(.paste) }
            } label: {
                Label("Edit", systemImage: HakoSymbol.pencil.name)
            }
            .accessibilityIdentifier("codeEditor.editMenu")
        } else {
            Label("Read only", systemImage: HakoSymbol.eye.name)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: HakoTheme.Spacing.standard) {
            commandControls
            Spacer(minLength: HakoTheme.Spacing.compact)
            Text(hako: .copy(positionSummary))
                .font(.caption.monospacedDigit())
                .foregroundStyle(CodeEditorPalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(CodeEditorPalette.secondaryText)
        .padding(.horizontal, HakoTheme.Spacing.row)
        .padding(.bottom, HakoTheme.Spacing.compact)
    }

    @ViewBuilder
    private var largeFileNotice: some View {
        if text.utf16.count > CodeEditorPolicy.largeFileUTF16 {
            Label("Large file mode · visible-range highlighting", systemImage: HakoSymbol.infoCircle.name)
                .font(.caption)
                .foregroundStyle(CodeEditorPalette.secondaryText)
                .padding(.horizontal, HakoTheme.Spacing.row)
                .padding(.bottom, HakoTheme.Spacing.compact)
        }
    }

    private var findRequested: Bool { findPresented?.wrappedValue ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if chrome.showsFindRow(requested: findRequested) {
                searchBar
            }

            if chrome.showsStatusRow {
                statusRow
            }

            largeFileNotice

            CodeTextEditor(
                text: $text,
                language: language,
                selection: $selection,
                command: command,
                history: history,
                isEditable: isEditable,
                matches: search.matches,
                currentMatch: search.currentMatch,
                showsKeyBar: chrome == .minimal,
                showsLineNumbers: showsLineNumbers,
                softWrap: softWrap,
                onFind: { findPresented?.wrappedValue = true },
                typing: typing
            )
            .frame(
                minHeight: minHeight,
                maxHeight: expandsVertically ? .infinity : nil
            )
            .accessibilityIdentifier("codeEditor.text")
        }
        .background(CodeEditorPalette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: HakoTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: HakoTheme.Radius.card, style: .continuous)
                .stroke(CodeEditorPalette.border, lineWidth: 0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            jump(to: search.queryChanged(to: query, in: text))
            refreshLineIndex()
        }
        .onChange(of: query) { newQuery in
            jump(to: search.queryChanged(to: newQuery, in: text))
        }
        .onChange(of: findRequested) { requested in
             
             
             
            if requested {
                findFieldFocused = true
            } else if !query.isEmpty {
                query = ""
            }
        }
        .onChange(of: text) { newText in
             
             
             
            lineIndexTask?.cancel()
            lineIndexTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                refreshLineIndex()
            }
             
            jump(to: search.textChanged(to: newText))
        }
        .onChange(of: diagnosticLine) { line in
            guard let line, let range = CodeEditorSearch.range(ofLine: line, in: text) else { return }
            command = CodeEditorCommand(action: .select(range))
        }
         
         
         
         
        .hakoFrameWatch("Code Editor")
    }

     
     
     
     
    private var positionSummary: String {
        let position = CodeEditorSearch.lineAndColumn(
            at: selection.location,
            lineStarts: lineStarts,
            length: textLength
        )
        return "Ln \(position.line), Col \(position.column) · \(lineStarts.count) lines"
    }

    private func refreshLineIndex() {
        lineStarts = CodeEditorSearch.lineStarts(in: text)
        textLength = (text as NSString).length
    }

    private func jump(to range: NSRange?) {
        guard let range else { return }
        command = CodeEditorCommand(action: .select(range))
    }

    private func selectMatch(delta: Int) {
        jump(to: search.step(by: delta))
    }

    private func send(_ action: CodeEditorCommand.Action) {
        command = CodeEditorCommand(action: action)
    }
}

#if canImport(UIKit)
private struct CodeTextEditor: UIViewRepresentable {
    @Binding var text: String
    let language: CodeEditorLanguage
    @Binding var selection: NSRange
    let command: CodeEditorCommand?
    let history: CodeEditorHistory
    let isEditable: Bool
     
     
     
     
     
     
     
    var matches: [NSRange] = []
    var currentMatch: Int?
     
    var showsKeyBar = false
    var showsLineNumbers = true
    var softWrap = true
    var onFind: (() -> Void)?
     
    var typing: Binding<Bool>?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> LineNumberTextView {
        let view = LineNumberTextView()
        view.delegate = context.coordinator
        view.language = language
        view.isEditable = isEditable
        view.isSelectable = true
        view.text = text
        view.selectedRange = selection
        history.attach(to: text)
        context.coordinator.lastEmittedText = text
        context.coordinator.mirror.reset(to: text)
         
        view.textStorage.delegate = context.coordinator
        view.showsLineNumbers = showsLineNumbers
        view.softWrap = softWrap
        view.rebuildLineStarts()
        if showsKeyBar {
            view.inputAccessoryView = CodeEditorKeyBar(keys: context.coordinator.keys(for: view))
        }
        DispatchQueue.main.async { view.highlightVisibleSyntax() }
        return view
    }

    func updateUIView(_ view: LineNumberTextView, context: Context) {
        context.coordinator.parent = self
        view.language = language
        view.isEditable = isEditable
        view.showsLineNumbers = showsLineNumbers
        view.softWrap = softWrap
        view.searchMatches = matches
        view.currentSearchMatch = currentMatch
        var externallyReplacedText = false
         
         
        if text != context.coordinator.lastEmittedText,
           !view.isFirstResponder {
            context.coordinator.isUpdating = true
            view.text = text
            view.rebuildLineStarts()
            view.undoManager?.removeAllActions()
            history.reset(to: text)
            context.coordinator.lastEmittedText = text
            context.coordinator.mirror.reset(to: text)
            context.coordinator.isUpdating = false
            externallyReplacedText = true
        }
        if let command, context.coordinator.lastCommandID != command.id {
            context.coordinator.lastCommandID = command.id
            let action = command.action
            DispatchQueue.main.async { [weak view, weak coordinator = context.coordinator] in
                guard let view, let coordinator else { return }
                coordinator.perform(action, in: view)
            }
        }
        if externallyReplacedText { view.highlightVisibleSyntax() }
    }

    final class Coordinator: NSObject, UITextViewDelegate, NSTextStorageDelegate {
        var mirror = CodeEditorTextMirror(text: "")

        func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorage.EditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard !isUpdating, editedMask.contains(.editedCharacters) else { return }
            mirror.apply(
                editedRange: editedRange,
                changeInLength: delta,
                storage: textStorage.mutableString
            )
        }
        var parent: CodeTextEditor
        var lastCommandID: UUID?
        var isUpdating = false
        var highlightWorkItem: DispatchWorkItem?
        var scrollHighlightWorkItem: DispatchWorkItem?
        var lastEmittedText = ""

        init(parent: CodeTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdating, let view = textView as? LineNumberTextView else { return }
             
             
             
            let emitted = mirror.text
            parent.history.recordChange(from: lastEmittedText, to: emitted)
            lastEmittedText = emitted
            parent.text = emitted
            if parent.showsKeyBar, view.isFirstResponder, parent.typing?.wrappedValue == false {
                parent.typing?.wrappedValue = true
            }
            highlightWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak view] in
                view?.rebuildLineStarts()
                view?.highlightVisibleSyntax()
            }
            highlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isUpdating else { return }
            parent.selection = textView.selectedRange
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.typing?.wrappedValue == true { parent.typing?.wrappedValue = false }
        }

        private var lastContentOffsetY: CGFloat = 0

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let view = scrollView as? LineNumberTextView else { return }
             
             
            let offsetY = scrollView.contentOffset.y
            if scrollView.isTracking, offsetY < lastContentOffsetY - 6,
               parent.typing?.wrappedValue == true {
                parent.typing?.wrappedValue = false
            }
            lastContentOffsetY = offsetY
             
             
            view.layoutGutter()
            scrollHighlightWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak view] in
                view?.highlightVisibleSyntax()
            }
            scrollHighlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04, execute: workItem)
        }

        func perform(_ action: CodeEditorCommand.Action, in view: LineNumberTextView) {
            switch action {
            case .undo:
                view.becomeFirstResponder()
                undo(in: view)
            case .redo:
                view.becomeFirstResponder()
                redo(in: view)
            case .cut:
                view.becomeFirstResponder()
                view.cut(nil)
            case .copy:
                view.becomeFirstResponder()
                view.copy(nil)
            case .paste:
                view.becomeFirstResponder()
                view.paste(nil)
            case .selectAll:
                view.becomeFirstResponder()
                view.selectAll(nil)
            case .select(let range):
                let safeLocation = min(max(0, range.location), (view.text as NSString).length)
                let safeLength = min(max(0, range.length), (view.text as NSString).length - safeLocation)
                view.selectedRange = NSRange(location: safeLocation, length: safeLength)
                view.scrollRangeToVisible(view.selectedRange)
            }
        }

        private func undo(in view: LineNumberTextView) {
            guard let target = parent.history.undo(from: view.text) else { return }
            restore(target, in: view)
        }

        private func redo(in view: LineNumberTextView) {
            guard let target = parent.history.redo(from: view.text) else { return }
            restore(target, in: view)
        }

        private func restore(_ text: String, in view: LineNumberTextView) {
            isUpdating = true
            let selectedLocation = min(view.selectedRange.location, (text as NSString).length)
            view.text = text
            view.selectedRange = NSRange(location: selectedLocation, length: 0)
            view.rebuildLineStarts()
            lastEmittedText = text
            parent.text = text
            parent.selection = view.selectedRange
            isUpdating = false
            view.highlightVisibleSyntax()
        }

         

         
         
        func keys(for view: LineNumberTextView) -> [CodeEditorKeyBar.Key] {
            [
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.indent", label: String(localized: "Indent"), symbol: .arrowRightToLine, title: nil) { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.apply(CodeEditorIndentation.indent(view.text, selection: view.selectedRange), in: view)
                },
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.outdent", label: String(localized: "Outdent"), symbol: .arrowLeftToLine, title: nil) { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.apply(CodeEditorIndentation.outdent(view.text, selection: view.selectedRange), in: view)
                },
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.dash", label: "-", symbol: nil, title: "-") { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.insert("-", in: view)
                },
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.colon", label: ":", symbol: nil, title: ":") { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.insert(":", in: view)
                },
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.quote", label: "\"", symbol: nil, title: "\"") { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.insert("\"", in: view)
                },
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.hash", label: "#", symbol: nil, title: "#") { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.insert("#", in: view)
                },
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.undo", label: String(localized: "Undo"), symbol: .arrowUturnBackward, title: nil) { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.undo(in: view)
                },
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.redo", label: String(localized: "Redo"), symbol: .arrowUturnForward, title: nil) { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.redo(in: view)
                },
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.find", label: String(localized: "Find"), symbol: .magnifyingglass, title: nil) { [weak self] in
                    self?.parent.onFind?()
                },
                CodeEditorKeyBar.Key(identifier: "codeEditor.keyBar.hideKeyboard", label: String(localized: "Hide Keyboard"), symbol: .keyboardChevronCompactDown, title: nil) { [weak view] in
                    view?.resignFirstResponder()
                },
            ]
        }

         
         
         
        private func apply(_ edit: CodeEditorIndentation.Edit, in view: LineNumberTextView) {
            guard let start = view.position(from: view.beginningOfDocument, offset: edit.replacedRange.location),
                  let end = view.position(from: start, offset: edit.replacedRange.length),
                  let range = view.textRange(from: start, to: end) else { return }
            view.replace(range, withText: edit.replacement)
            view.selectedRange = edit.selection
            if lastEmittedText != mirror.text { textViewDidChange(view) }
        }

        private func insert(_ token: String, in view: LineNumberTextView) {
            view.insertText(token)
            if lastEmittedText != mirror.text { textViewDidChange(view) }
        }
    }
}

 
 
 
 
private final class CodeEditorKeyBar: UIInputView {
    struct Key {
        let identifier: String
        let label: String
        let symbol: HakoSymbol?
        let title: String?
        let action: () -> Void
    }

    static let height: CGFloat = 44

    init(keys: [Key]) {
        super.init(
            frame: CGRect(x: 0, y: 0, width: 0, height: Self.height),
            inputViewStyle: .keyboard
        )
        allowsSelfSizing = true
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.height).isActive = true

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        let stack = UIStackView(arrangedSubviews: keys.map(Self.button(for:)))
        stack.axis = .horizontal
         
         
         
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
             
            stack.widthAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.widthAnchor, constant: -16),
            stack.widthAnchor.constraint(greaterThanOrEqualToConstant: CGFloat(keys.count) * 34),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func button(for key: Key) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        if let symbol = key.symbol {
            configuration.image = UIImage(
                systemName: symbol.name,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            )
        } else if let title = key.title {
            var attributed = AttributedString(title)
            attributed.font = UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
            configuration.attributedTitle = attributed
        }
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4)
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in key.action() })
        button.tintColor = .label
        button.accessibilityIdentifier = key.identifier
        button.accessibilityLabel = key.label
        return button
    }
}

private final class LineNumberTextView: UITextView {
    private let gutterWidth: CGFloat = 42
     
     
    private var pinchBaseline: CGFloat = 1

     
     
    var softWrap = CodeEditorSoftWrap.isOn {
        didSet {
            guard softWrap != oldValue else { return }
            applyWrapping()
        }
    }

    var textScale = CodeEditorTextScale.factor {
        didSet {
            guard textScale != oldValue else { return }
            applyFont()
        }
    }

    var showsLineNumbers = CodeEditorLineNumbers.isOn {
        didSet {
            guard showsLineNumbers != oldValue else { return }
            applyGutterInset()
            gutterView.isHidden = !showsLineNumbers
            layoutGutter()
        }
    }
    private var lineStarts = [0]
    private var highlightedRange = NSRange(location: 0, length: 0)
     
     
    private var lastHighlightedVisibleRange: NSRange?
     
     
    var searchMatches: [NSRange] = [] {
        didSet {
            guard searchMatches != oldValue else { return }
            lastHighlightedVisibleRange = nil
            highlightVisibleSyntax()
        }
    }
    var currentSearchMatch: Int? {
        didSet {
            guard currentSearchMatch != oldValue else { return }
            lastHighlightedVisibleRange = nil
            highlightVisibleSyntax()
        }
    }
    var language: CodeEditorLanguage = .yaml
    fileprivate let gutterView = GutterView()

    init() {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        layout.allowsNonContiguousLayout = true
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure() {
        backgroundColor = CodeEditorPalette.uiCanvas
        textColor = CodeEditorPalette.uiPrimaryText
        keyboardDismissMode = .interactive
        applyGutterInset()
        textContainer.lineFragmentPadding = 0
        alwaysBounceVertical = true
        autocorrectionType = .no
        autocapitalizationType = .none
        smartQuotesType = .no
        smartDashesType = .no
        spellCheckingType = .no
        adjustsFontForContentSizeCategory = true
        applyFont()
        applyWrapping()
        addGestureRecognizer(
            UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        )
        accessibilityLabel = "Code Editor"
        accessibilityIdentifier = "codeEditor.text"
        gutterView.owner = self
        gutterView.isHidden = !showsLineNumbers
        gutterView.backgroundColor = .clear
        gutterView.isOpaque = false
        gutterView.isUserInteractionEnabled = false
        gutterView.contentMode = .redraw
        addSubview(gutterView)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutGutter()
    }

     
     
     
     
     
     
     
    private func applySearchHighlight(in inspected: NSRange) {
        textStorage.removeAttribute(.backgroundColor, range: inspected)
        guard !searchMatches.isEmpty else { return }
        for (index, match) in searchMatches.enumerated() {
            let visible = NSIntersectionRange(match, inspected)
            guard visible.length > 0 else { continue }
            textStorage.addAttribute(
                .backgroundColor,
                value: index == currentSearchMatch
                    ? UIColor.systemYellow.withAlphaComponent(0.65)
                    : UIColor.systemYellow.withAlphaComponent(0.28),
                range: visible
            )
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            font = UIFont.monospacedSystemFont(
                ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize,
                weight: .regular
            )
            typingAttributes[.font] = font
        }
        highlightVisibleSyntax()
        gutterView.setNeedsDisplay()
    }

    func rebuildLineStarts() {
        let began = DispatchTime.now().uptimeNanoseconds
        defer {
            HakoPerf.span(
                "editor.lineStarts",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail: "lines=\(lineStarts.count)"
            )
        }
         
         
        lastHighlightedVisibleRange = nil
        let source = text as NSString
        lineStarts = [0]
        if source.length > 0 {
            for index in 0..<source.length where source.character(at: index) == 10 {
                lineStarts.append(index + 1)
            }
        }
        gutterView.setNeedsDisplay()
    }

    func highlightVisibleSyntax() {
        let began = DispatchTime.now().uptimeNanoseconds
        defer {
            HakoPerf.span(
                "editor.highlight",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail: "chars=\(text.utf16.count)"
            )
        }
        guard window != nil, !text.isEmpty else { return }
        let visible = CGRect(origin: contentOffset, size: bounds.size)
         
         
         
         
         
         
         
         
        layoutManager.ensureLayout(forBoundingRect: visible, in: textContainer)
        let glyphs = layoutManager.glyphRange(forBoundingRect: visible, in: textContainer)
        let characters = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
         
         
         
         
         
         
         
         
         
         
         
         
        let inspected = CodeSyntaxHighlighter.inspectedRange(
            for: characters, length: textStorage.length
        )
        if let lastInspected = lastHighlightedVisibleRange,
           NSEqualRanges(lastInspected, inspected) {
            return
        }
        lastHighlightedVisibleRange = inspected
        let result = CodeSyntaxHighlighter.highlight(text, language: language, around: characters)
        let storageLength = textStorage.length
        let oldLocation = min(highlightedRange.location, storageLength)
        let oldLength = min(highlightedRange.length, storageLength - oldLocation)
        undoManager?.disableUndoRegistration()
        textStorage.beginEditing()
        if oldLength > 0 {
            textStorage.addAttribute(
                .foregroundColor,
                value: CodeEditorPalette.uiPrimaryText,
                range: NSRange(location: oldLocation, length: oldLength)
            )
        }
        highlightedRange = result.inspectedRange
        for token in result.tokens {
            textStorage.addAttribute(
                .foregroundColor,
                value: color(for: token.kind),
                range: token.range
            )
        }
        applySearchHighlight(in: result.inspectedRange)
        textStorage.endEditing()
        undoManager?.enableUndoRegistration()
        typingAttributes[.foregroundColor] = CodeEditorPalette.uiPrimaryText
    }

     
     
     
     
     
     
     
    final class GutterView: UIView {
        weak var owner: LineNumberTextView?

        override func draw(_ rect: CGRect) {
            guard let owner, let context = UIGraphicsGetCurrentContext() else { return }
            owner.drawGutter(in: context, bounds: bounds)
        }
    }

    func drawGutter(in context: CGContext, bounds gutterBounds: CGRect) {
        let began = DispatchTime.now().uptimeNanoseconds
        defer {
            HakoPerf.span(
                "editor.gutter",
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - began
                ) / 1_000_000,
                detail: "lines=\(lineStarts.count)"
            )
        }
        context.setFillColor(CodeEditorPalette.uiGutter.cgColor)
        context.fill(gutterBounds)
        context.setFillColor(UIColor.separator.cgColor)
        context.fill(
            CGRect(x: gutterBounds.maxX - 0.5, y: gutterBounds.minY,
                   width: 0.5, height: gutterBounds.height)
        )

        let visible = CGRect(origin: contentOffset, size: bounds.size)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: textContainer)
        let characterRange = layoutManager.characterRange(
            forGlyphRange: glyphRange,
            actualGlyphRange: nil
        )
        let firstLine = max(0, lowerBound(lineStarts, characterRange.location) - 1)
        let end = NSMaxRange(characterRange)
        let numberFont = UIFont.monospacedDigitSystemFont(
            ofSize: max(9, (font?.pointSize ?? 12) - 2),
            weight: .regular
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: CodeEditorPalette.uiSecondaryText
        ]
         
         
        let source = text as NSString
        let lastCharacter = max(0, source.length - 1)
        let isEmpty = source.length == 0

        for lineIndex in firstLine..<lineStarts.count {
            let character = lineStarts[lineIndex]
            if character > end { break }
            let y: CGFloat
            if isEmpty {
                y = textContainerInset.top
            } else {
                let glyph = layoutManager.glyphIndexForCharacter(
                    at: min(character, lastCharacter)
                )
                y = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
                    + textContainerInset.top
            }
            let value = "\(lineIndex + 1)" as NSString
            let size = value.size(withAttributes: attributes)
            value.draw(
                 
                 
                at: CGPoint(x: gutterWidth - size.width - 7, y: y - contentOffset.y),
                withAttributes: attributes
            )
        }
    }

     
     
     
     
     
    private func applyFont() {
        let size = UIFont.preferredFont(forTextStyle: .caption1).pointSize * textScale
        font = UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
        typingAttributes = [
            .font: font as Any,
            .foregroundColor: CodeEditorPalette.uiPrimaryText
        ]
        lastHighlightedVisibleRange = nil
        highlightVisibleSyntax()
        layoutGutter()
    }

    private func applyWrapping() {
        textContainer.widthTracksTextView = softWrap
        textContainer.size = CGSize(
            width: softWrap ? bounds.width : CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        isDirectionalLockEnabled = softWrap
        alwaysBounceHorizontal = !softWrap
        setNeedsLayout()
    }

     
     
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            pinchBaseline = textScale
        case .changed:
            textScale = min(
                max(pinchBaseline * gesture.scale, CodeEditorTextScale.range.lowerBound),
                CodeEditorTextScale.range.upperBound
            )
        case .ended, .cancelled, .failed:
            CodeEditorTextScale.factor = textScale
        default:
            break
        }
    }

    private func applyGutterInset() {
        textContainerInset = UIEdgeInsets(
            top: 12,
            left: showsLineNumbers ? gutterWidth + 8 : HakoTheme.Spacing.row,
            bottom: 12,
            right: 12
        )
    }

    func layoutGutter() {
        guard showsLineNumbers else { return }
        let frame = CGRect(x: contentOffset.x, y: contentOffset.y,
                           width: gutterWidth, height: bounds.height)
        if gutterView.frame != frame {
            gutterView.frame = frame
        }
        gutterView.setNeedsDisplay()
    }

    private func lowerBound(_ values: [Int], _ target: Int) -> Int {
        var low = 0
        var high = values.count
        while low < high {
            let mid = (low + high) / 2
            if values[mid] < target { low = mid + 1 } else { high = mid }
        }
        return low
    }

    private func color(for kind: CodeHighlightKind) -> UIColor {
        switch kind {
        case .key: return CodeEditorPalette.uiKey
        case .string: return CodeEditorPalette.uiString
        case .number: return CodeEditorPalette.uiNumber
        case .literal: return CodeEditorPalette.uiLiteral
        case .comment: return CodeEditorPalette.uiComment
        case .keyword: return CodeEditorPalette.uiLiteral
        }
    }
}
#else
private struct CodeTextEditor: NSViewRepresentable {
    @Binding var text: String
    let language: CodeEditorLanguage
    @Binding var selection: NSRange
    let command: CodeEditorCommand?
    let history: CodeEditorHistory
    let isEditable: Bool
     
     
    var matches: [NSRange] = []
    var currentMatch: Int?
     
    var showsKeyBar = false
     
    var showsLineNumbers = true
    var softWrap = true
    var onFind: (() -> Void)?
    var typing: Binding<Bool>?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

     
     
     
     
     
    func makeNSView(context: Context) -> NSScrollView {
        HakoPerf.measure("editor.makeNSView") { madeNSView(context: context) }
    }

    private func madeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = CodeEditorPalette.uiCanvas
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let view = LineNumberTextView(frame: .zero)
        view.delegate = context.coordinator
        view.language = language
        view.isEditable = isEditable
        view.isSelectable = true
        view.minSize = .zero
        view.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        view.textContainer?.widthTracksTextView = true
        scrollView.documentView = view
         
         
        scrollView.verticalRulerView = HakoMacLineNumberRuler(
            textView: view, scrollView: scrollView
        )
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = showsLineNumbers
         
         
         
         
         
         
         
         
        view.string = text
        view.setSelectedRange(selection)
        context.coordinator.observeScrolling(of: scrollView, textView: view)

        history.attach(to: text)
        context.coordinator.lastEmittedText = text
        context.coordinator.mirror.reset(to: text)
         
        view.textStorage?.delegate = context.coordinator
        DispatchQueue.main.async { view.highlightVisibleSyntax() }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        HakoPerf.measure("editor.updateNSView") {
            updatedNSView(scrollView, context: context)
        }
    }

    private func updatedNSView(
        _ scrollView: NSScrollView, context: Context
    ) {
        guard let view = scrollView.documentView as? LineNumberTextView else {
            return
        }
        context.coordinator.parent = self
        view.language = language
        view.isEditable = isEditable
        view.searchMatches = matches
        view.currentSearchMatch = currentMatch
        if scrollView.rulersVisible != showsLineNumbers {
            scrollView.rulersVisible = showsLineNumbers
        }
        var externallyReplacedText = false
         
         
         
         
         
        if text != context.coordinator.lastEmittedText,
           view.window?.firstResponder !== view
        {
            context.coordinator.isUpdating = true
            view.string = text
            view.undoManager?.removeAllActions()
            history.reset(to: text)
            context.coordinator.lastEmittedText = text
            context.coordinator.mirror.reset(to: text)
            context.coordinator.isUpdating = false
             
             
            view.invalidateHighlightCache()
            externallyReplacedText = true
        }
        if let command, context.coordinator.lastCommandID != command.id {
            context.coordinator.lastCommandID = command.id
            let action = command.action
            DispatchQueue.main.async {
                [weak view, weak coordinator = context.coordinator] in
                guard let view, let coordinator else { return }
                coordinator.perform(action, in: view)
            }
        }
        if externallyReplacedText { view.highlightVisibleSyntax() }
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSTextStorageDelegate {
        var parent: CodeTextEditor
        var mirror = CodeEditorTextMirror(text: "")

        func textStorage(
            _ textStorage: NSTextStorage,
            didProcessEditing editedMask: NSTextStorageEditActions,
            range editedRange: NSRange,
            changeInLength delta: Int
        ) {
            guard !isUpdating, editedMask.contains(.editedCharacters) else { return }
            mirror.apply(
                editedRange: editedRange,
                changeInLength: delta,
                storage: textStorage.mutableString
            )
        }
        var lastCommandID: UUID?
        var isUpdating = false
        var highlightWorkItem: DispatchWorkItem?
        var scrollHighlightWorkItem: DispatchWorkItem?
        var lastEmittedText = ""
        weak var observedTextView: LineNumberTextView?

        init(parent: CodeTextEditor) { self.parent = parent }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

         
         
         
         
         
         
        func observeScrolling(
            of scrollView: NSScrollView,
            textView: LineNumberTextView
        ) {
            NotificationCenter.default.removeObserver(
                self,
                name: NSView.boundsDidChangeNotification,
                object: nil
            )
            observedTextView = textView
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(visibleBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

         
         
        @objc private func visibleBoundsDidChange(_ notification: Notification) {
            guard notification.object is NSClipView else { return }
            scrollHighlightWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak view = observedTextView] in
                view?.highlightVisibleSyntax()
            }
            scrollHighlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.04,
                execute: workItem
            )
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating,
                  let view = notification.object as? LineNumberTextView
            else { return }
             
             
             
             
             
             
             
            let emitted = mirror.text
            parent.history.recordChange(
                from: lastEmittedText,
                to: emitted
            )
            lastEmittedText = emitted
            parent.text = emitted
             
             
             
             
            view.invalidateHighlightCache()
            highlightWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak view] in
                view?.highlightVisibleSyntax()
            }
            highlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.12,
                execute: workItem
            )
        }

        func textViewDidChangeSelection(
            _ notification: Notification
        ) {
            guard !isUpdating,
                  let view = notification.object as? NSTextView
            else { return }
            parent.selection = view.selectedRange()
        }

        func perform(
            _ action: CodeEditorCommand.Action,
            in view: LineNumberTextView
        ) {
            if action.claimsFocus {
                view.window?.makeFirstResponder(view)
            }
            switch action {
            case .undo:
                undo(in: view)
            case .redo:
                redo(in: view)
            case .cut:
                view.cut(nil)
            case .copy:
                view.copy(nil)
            case .paste:
                view.paste(nil)
            case .selectAll:
                view.selectAll(nil)
            case .select(let range):
                let length = (view.string as NSString).length
                let safeLocation = min(max(0, range.location), length)
                let safeLength = min(
                    max(0, range.length),
                    length - safeLocation
                )
                let safeRange = NSRange(
                    location: safeLocation,
                    length: safeLength
                )
                view.setSelectedRange(safeRange)
                view.scrollRangeToVisible(safeRange)
            }
        }

        private func undo(in view: LineNumberTextView) {
            guard let target = parent.history.undo(from: view.string) else {
                return
            }
            restore(target, in: view)
        }

        private func redo(in view: LineNumberTextView) {
            guard let target = parent.history.redo(from: view.string) else {
                return
            }
            restore(target, in: view)
        }

        private func restore(
            _ text: String,
            in view: LineNumberTextView
        ) {
            isUpdating = true
            let selectedLocation = min(
                view.selectedRange().location,
                (text as NSString).length
            )
            view.string = text
            let selectedRange = NSRange(
                location: selectedLocation,
                length: 0
            )
            view.setSelectedRange(selectedRange)
            lastEmittedText = text
            parent.text = text
            parent.selection = selectedRange
            isUpdating = false
             
             
             
            view.invalidateHighlightCache()
            view.highlightVisibleSyntax()
        }
    }
}

private final class LineNumberTextView: NSTextView {
    private var highlightedRange = NSRange(location: 0, length: 0)
     
     
     
     
     
     
     
    private var lastHighlightedInspectedRange: NSRange?

     
     
     
     
    func invalidateHighlightCache() {
        lastHighlightedInspectedRange = nil
    }
    var language: CodeEditorLanguage = .yaml

     
     
     
     
     
     
     
    var searchMatches: [NSRange] = [] {
        didSet {
            guard searchMatches != oldValue else { return }
            lastHighlightedInspectedRange = nil
            highlightVisibleSyntax()
        }
    }

    var currentSearchMatch: Int? {
        didSet {
            guard currentSearchMatch != oldValue else { return }
            lastHighlightedInspectedRange = nil
            highlightVisibleSyntax()
        }
    }

    override init(frame frameRect: NSRect) {
         
         
        super.init(frame: frameRect)
    }

    override init(
        frame frameRect: NSRect,
        textContainer container: NSTextContainer?
    ) {
        super.init(frame: frameRect, textContainer: container)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

     
     
     
     
     
     
     
     
     
     
     
    private var timedFirstDraw = false

    override func viewDidMoveToWindow() {
        HakoPerf.measure("editor.viewDidMoveToWindow") {
            super.viewDidMoveToWindow()
        }
    }

    override func layout() {
        HakoPerf.measure("editor.layout") { super.layout() }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !timedFirstDraw else {
            super.draw(dirtyRect)
            return
        }
        timedFirstDraw = true
        HakoPerf.measure("editor.firstDraw") { super.draw(dirtyRect) }
    }

    private func configure() {
        drawsBackground = true
        backgroundColor = CodeEditorPalette.uiCanvas
        textColor = CodeEditorPalette.uiPrimaryText
        textContainerInset = NSSize(width: 12, height: 12)
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        font = NSFont.monospacedSystemFont(
            ofSize: NSFont.systemFontSize(for: .small),
            weight: .regular
        )
        typingAttributes = [
            .font: font as Any,
            .foregroundColor: CodeEditorPalette.uiPrimaryText,
        ]
        setAccessibilityLabel("Code Editor")
        setAccessibilityIdentifier("codeEditor.text")
    }

    func highlightVisibleSyntax() {
        guard window != nil, !string.isEmpty,
              let layoutManager,
              let textContainer,
              let textStorage
        else { return }
         
         
         
         
         
         
         
         
         
         
        layoutManager.ensureLayout(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        let glyphs = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        let characters = layoutManager.characterRange(
            forGlyphRange: glyphs,
            actualGlyphRange: nil
        )
         
         
         
         
         
         
        let inspected = CodeSyntaxHighlighter.inspectedRange(
            for: characters, length: textStorage.length
        )
        if let last = lastHighlightedInspectedRange,
           NSEqualRanges(last, inspected) {
            return
        }
        lastHighlightedInspectedRange = inspected
        let result = CodeSyntaxHighlighter.highlight(
            string,
            language: language,
            around: characters
        )
         
         
         
         
         
         
         
         
         
         
        let storageLength = textStorage.length
        let oldLocation = min(highlightedRange.location, storageLength)
        let oldLength = min(
            highlightedRange.length,
            storageLength - oldLocation
        )
        if oldLength > 0 {
            layoutManager.removeTemporaryAttribute(
                .foregroundColor,
                forCharacterRange: NSRange(
                    location: oldLocation, length: oldLength
                )
            )
        }
        highlightedRange = result.inspectedRange
        for token in result.tokens {
            layoutManager.addTemporaryAttribute(
                .foregroundColor,
                value: color(for: token.kind),
                forCharacterRange: token.range
            )
        }
        applySearchHighlight(in: inspected, layoutManager: layoutManager)
        typingAttributes[.foregroundColor] =
            CodeEditorPalette.uiPrimaryText
    }

     
     
     
    private func applySearchHighlight(
        in inspected: NSRange,
        layoutManager: NSLayoutManager
    ) {
        layoutManager.removeTemporaryAttribute(
            .backgroundColor, forCharacterRange: inspected
        )
        guard !searchMatches.isEmpty else { return }
        for (index, match) in searchMatches.enumerated() {
            let visible = NSIntersectionRange(match, inspected)
            guard visible.length > 0 else { continue }
            layoutManager.addTemporaryAttribute(
                .backgroundColor,
                value: index == currentSearchMatch
                    ? NSColor.systemYellow.withAlphaComponent(0.65)
                    : NSColor.systemYellow.withAlphaComponent(0.28),
                forCharacterRange: visible
            )
        }
    }

    private func color(for kind: CodeHighlightKind) -> NSColor {
        switch kind {
        case .key: CodeEditorPalette.uiKey
        case .string: CodeEditorPalette.uiString
        case .number: CodeEditorPalette.uiNumber
        case .literal, .keyword: CodeEditorPalette.uiLiteral
        case .comment: CodeEditorPalette.uiComment
        }
    }
}
#endif

 
 
private enum CodeEditorPalette {
#if canImport(UIKit)
    private static func adaptive(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }

    static let uiCanvas = adaptive(
        light: .secondarySystemGroupedBackground,
        dark: UIColor(red: 0.075, green: 0.075, blue: 0.085, alpha: 1)
    )
    static let uiGutter = adaptive(
        light: .systemGroupedBackground,
        dark: UIColor(red: 0.105, green: 0.105, blue: 0.115, alpha: 1)
    )
    static let uiPrimaryText = UIColor.label
    static let uiSecondaryText = UIColor.secondaryLabel
    static let uiKey = adaptive(
        light: UIColor(red: 0.55, green: 0.35, blue: 0.02, alpha: 1),
        dark: UIColor(red: 0.78, green: 0.57, blue: 0.13, alpha: 1)
    )
    static let uiString = adaptive(
        light: UIColor(red: 0.05, green: 0.48, blue: 0.18, alpha: 1),
        dark: UIColor(red: 0.20, green: 0.82, blue: 0.37, alpha: 1)
    )
    static let uiNumber = adaptive(
        light: UIColor(red: 0.72, green: 0.32, blue: 0.02, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.63, blue: 0.16, alpha: 1)
    )
    static let uiLiteral = adaptive(
        light: UIColor(red: 0.00, green: 0.35, blue: 0.72, alpha: 1),
        dark: UIColor(red: 0.20, green: 0.68, blue: 0.91, alpha: 1)
    )
    static let uiComment = UIColor.tertiaryLabel

    static let canvas = Color(uiColor: uiCanvas)
    static let primaryText = Color(uiColor: uiPrimaryText)
    static let secondaryText = Color(uiColor: uiSecondaryText)
    static let accent = Color(uiColor: .systemBlue)
    static let border = Color(uiColor: .separator)
#else
    private static func adaptive(
        light: NSColor,
        dark: NSColor
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? dark
                : light
        }
    }

    static let uiCanvas = adaptive(
        light: .controlBackgroundColor,
        dark: NSColor(
            calibratedRed: 0.075,
            green: 0.075,
            blue: 0.085,
            alpha: 1
        )
    )
    static let uiGutter = adaptive(
        light: .windowBackgroundColor,
        dark: NSColor(
            calibratedRed: 0.105,
            green: 0.105,
            blue: 0.115,
            alpha: 1
        )
    )
    static let uiPrimaryText = NSColor.labelColor
    static let uiSecondaryText = NSColor.secondaryLabelColor
    static let uiKey = adaptive(
        light: NSColor(
            calibratedRed: 0.55,
            green: 0.35,
            blue: 0.02,
            alpha: 1
        ),
        dark: NSColor(
            calibratedRed: 0.78,
            green: 0.57,
            blue: 0.13,
            alpha: 1
        )
    )
    static let uiString = adaptive(
        light: NSColor(
            calibratedRed: 0.05,
            green: 0.48,
            blue: 0.18,
            alpha: 1
        ),
        dark: NSColor(
            calibratedRed: 0.20,
            green: 0.82,
            blue: 0.37,
            alpha: 1
        )
    )
    static let uiNumber = adaptive(
        light: NSColor(
            calibratedRed: 0.72,
            green: 0.32,
            blue: 0.02,
            alpha: 1
        ),
        dark: NSColor(
            calibratedRed: 0.96,
            green: 0.63,
            blue: 0.16,
            alpha: 1
        )
    )
    static let uiLiteral = adaptive(
        light: NSColor(
            calibratedRed: 0.00,
            green: 0.35,
            blue: 0.72,
            alpha: 1
        ),
        dark: NSColor(
            calibratedRed: 0.20,
            green: 0.68,
            blue: 0.91,
            alpha: 1
        )
    )
    static let uiComment = NSColor.tertiaryLabelColor

    static let canvas = Color(nsColor: uiCanvas)
    static let primaryText = Color(nsColor: uiPrimaryText)
    static let secondaryText = Color(nsColor: uiSecondaryText)
    static let accent = Color(nsColor: .systemBlue)
    static let border = Color(nsColor: .separatorColor)
#endif
}
