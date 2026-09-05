import AppKit

 
 
 
 
 
 
 
 
final class HakoMacLineNumberRuler: NSRulerView {
    private weak var textView: NSTextView?
     
     
    private var lineStarts: [Int] = [0]
     
     
     
     
    private var indexedLength = 0
    private var observers: [NSObjectProtocol] = []
    private let padding: CGFloat = 6

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        let center = NotificationCenter.default
         
         
         
        if let storage = textView.textStorage {
            observers.append(center.addObserver(
                forName: NSTextStorage.didProcessEditingNotification, object: storage, queue: .main
            ) { [weak self] note in
                guard let self, let storage = note.object as? NSTextStorage,
                      storage.editedMask.contains(.editedCharacters)
                else { return }
                 
                 
                 
                 
                self.patchIndex(
                    editedRange: storage.editedRange,
                    changeInLength: storage.changeInLength,
                    in: storage.string as NSString
                )
                self.needsDisplay = true
            })
        }
        if let clip = scrollView.contentView as NSClipView? {
            clip.postsBoundsChangedNotifications = true
            observers.append(center.addObserver(
                forName: NSView.boundsDidChangeNotification, object: clip, queue: .main
            ) { [weak self] _ in
                self?.needsDisplay = true
            })
        }
        textView.postsFrameChangedNotifications = true
        observers.append(center.addObserver(
            forName: NSView.frameDidChangeNotification, object: textView, queue: .main
        ) { [weak self] _ in
            self?.needsDisplay = true
        })
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

     
    override var isFlipped: Bool { true }

    private var numberFont: NSFont {
        let size = max(9, (textView?.font?.pointSize ?? 12) - 2)
        return NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
    }

    private var numberAttributes: [NSAttributedString.Key: Any] {
        [.font: numberFont, .foregroundColor: NSColor.secondaryLabelColor]
    }

     
     
     
     
     
     
     
     
     
    private static func lineStarts(in source: NSString, range: NSRange) -> [Int] {
        var starts: [Int] = []
        source.enumerateSubstrings(
            in: range, options: [.byLines, .substringNotRequired]
        ) { _, _, enclosing, _ in
            starts.append(enclosing.location)
        }
        if starts.first != range.location { starts.insert(range.location, at: 0) }
        if range.length > 0 {
            let last = source.character(at: NSMaxRange(range) - 1)
            if last == 10 || last == 13 || last == 0x2028 || last == 0x2029 {
                starts.append(NSMaxRange(range))
            }
        }
        return starts
    }

     
     
     
    private func patchIndex(editedRange: NSRange, changeInLength delta: Int, in source: NSString) {
        guard indexedLength >= 0, lineStarts.first == 0 else {
            indexedLength = -1
            return
        }
        let location = editedRange.location
        let oldLength = editedRange.length - delta
        let oldEnd = location + oldLength
         
         
        let firstAffected = lineStarts.firstIndex { $0 > location } ?? lineStarts.count
        let firstAfter = lineStarts[firstAffected...].firstIndex { $0 > oldEnd } ?? lineStarts.count
         
         
        var replacement = Self.lineStarts(in: source, range: editedRange)
        replacement.removeFirst()   
        if firstAfter < lineStarts.count {
            for index in firstAfter..<lineStarts.count { lineStarts[index] += delta }
        }
        lineStarts.replaceSubrange(firstAffected..<firstAfter, with: replacement)
        indexedLength = source.length
        scheduleThickness(deferred: true)
    }

    private var isDrawing = false

     
     
     
    private var sizedDigits = 0

    private func scheduleThickness(deferred: Bool) {
        let digits = max(2, String(lineStarts.count).count)
        if digits == sizedDigits, !deferred { return }
        sizedDigits = digits
        let width = (String(repeating: "8", count: digits) as NSString)
            .size(withAttributes: numberAttributes).width
        let thickness = ceil(width + padding * 2)
        guard abs(thickness - ruleThickness) >= 1 else { return }
        if deferred || isDrawing {
            DispatchQueue.main.async { [weak self] in
                guard let self, abs(thickness - self.ruleThickness) >= 1 else { return }
                self.ruleThickness = thickness
            }
        } else {
            ruleThickness = thickness
        }
    }

    func rebuildLineStarts() {
        let source = (textView?.string ?? "") as NSString
        lineStarts = Self.lineStarts(in: source, range: NSRange(location: 0, length: source.length))
        indexedLength = source.length
        scheduleThickness(deferred: false)
    }


     
    var lineStartsForTesting: [Int] {
        if (textView?.string as NSString?)?.length != indexedLength { rebuildLineStarts() }
        return lineStarts
    }

     
    func visibleLineNumbers() -> [Int] {
        visibleLines().map { $0.number }
    }

     
     
    private func visibleLines() -> [(number: Int, top: CGFloat)] {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer
        else { return [] }
        let source = textView.string as NSString
        if source.length != indexedLength {
            rebuildLineStarts()
        }
         
         
         
        scheduleThickness(deferred: isDrawing)
        if source.length == 0 {
            return [(1, textView.textContainerInset.height)]
        }
        let visible = textView.visibleRect
         
         
         
         
        layoutManager.ensureLayout(forBoundingRect: visible, in: container)
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let characterRange = layoutManager.characterRange(
            forGlyphRange: glyphRange, actualGlyphRange: nil
        )
        let firstLine = max(0, lowerBound(lineStarts, characterRange.location) - 1)
        let end = NSMaxRange(characterRange)
        let lastCharacter = source.length - 1
        var lines: [(Int, CGFloat)] = []
        for lineIndex in firstLine..<lineStarts.count {
            let character = lineStarts[lineIndex]
            if character > end { break }
            let glyph = layoutManager.glyphIndexForCharacter(at: min(character, lastCharacter))
            var top = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
            if character > lastCharacter {
                 
                 
                top = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).maxY
            }
            lines.append((lineIndex + 1, top + textView.textContainerInset.height))
        }
        return lines
    }

     
    private func lowerBound(_ values: [Int], _ value: Int) -> Int {
        var low = 0
        var high = values.count
        while low < high {
            let mid = (low + high) / 2
            if values[mid] <= value { low = mid + 1 } else { high = mid }
        }
        return low
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView else { return }
        isDrawing = true
        defer { isDrawing = false }
         
        (textView.backgroundColor.blended(withFraction: 0.06, of: .secondaryLabelColor)
            ?? NSColor.windowBackgroundColor).setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()
        let attributes = numberAttributes
        let lineHeight = textView.layoutManager?.defaultLineHeight(for: textView.font ?? numberFont) ?? 0
        let numberHeight = numberFont.ascender - numberFont.descender
        for line in visibleLines() {
             
             
             
            let point = convert(NSPoint(x: 0, y: line.top), from: textView)
            let label = "\(line.number)" as NSString
            let size = label.size(withAttributes: attributes)
            let y = point.y + max(0, (lineHeight - numberHeight) / 2)
            label.draw(
                at: NSPoint(x: ruleThickness - size.width - padding, y: y),
                withAttributes: attributes
            )
        }
    }
}
