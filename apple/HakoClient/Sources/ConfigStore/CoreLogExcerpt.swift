import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum CoreLogExcerpt {
     
    static let maximumLines = 12

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func lines(from raw: [String]) -> [String] {
         
         
         
         
         
         
        var scoped = raw[...]
        for marker in [
            "before the interface monitor",
            "Start initial configuration in progress",
        ] {
            if let start = raw.lastIndex(where: { $0.contains(marker) }) {
                scoped = raw[start...]
                break
            }
        }
        var order: [String] = []
        var firstSeen: [String: Entry] = [:]
        for line in scoped {
            guard let entry = parse(line) else { continue }
            let key = shape(of: entry.message)
            if firstSeen[key] == nil {
                order.append(key)
                firstSeen[key] = entry
            } else {
                firstSeen[key]?.count += 1
            }
        }
        let ranked = order.compactMap { firstSeen[$0] }
            .enumerated()
            .sorted { left, right in
                if left.element.isError != right.element.isError {
                    return left.element.isError
                }
                return left.offset < right.offset
            }
            .map(\.element)
        return ranked.prefix(maximumLines).map { entry in
            entry.count > 1
                ? "\(entry.message) ×\(entry.count)"
                : entry.message
        }
    }

    private struct Entry {
        let message: String
        let isError: Bool
        var count = 1
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private static let selfDeclaredBenign = [
        "the config still starts",
        "the configuration still starts",
        "matches nothing, falls through",
        "provider evaluation falls through",
        "the remaining rules still load",
        "(report only",
    ]

     
     
     
     
     
     
     
     
     
     
    private static func shape(of message: String) -> String {
        var key = message
        for pattern in [#"\[[^\]]*\]"#, #""[^"]*""#, #"\d+"#] {
            guard let expression = try? NSRegularExpression(pattern: pattern)
            else { continue }
            key = expression.stringByReplacingMatches(
                in: key,
                range: NSRange(key.startIndex..<key.endIndex, in: key),
                withTemplate: "·"
            )
        }
         
         
        if let colon = key.range(of: ": ", options: .backwards) {
            key = String(key[..<colon.lowerBound])
        }
        return key
    }

     
    static func recent(
        limit: Int = 400,
        store: HakoLogStore = .shared
    ) -> [String] {
        lines(from: store.tail(.core, limit: limit))
    }

     
     
     
     
     
     
    static func strippedThisRun(
        limit: Int = 400,
        store: HakoLogStore = .shared
    ) -> [String] {
        strippedNotices(in: store.tail(.core, limit: limit))
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func lanExposureNotices(
        limit: Int = 400,
        store: HakoLogStore = .shared
    ) -> [String] {
        lanExposureNotices(in: store.tail(.core, limit: limit))
    }

     
     
     
     
    private static let lanExposureNeedle =
        ["is", "reachable", "from", "the", "local", "network"].joined(separator: " ")

    static func lanExposureNotices(in raw: [String]) -> [String] {
        strippedNotices(in: raw).filter { $0.contains(lanExposureNeedle) }
    }

    static func strippedNotices(in raw: [String]) -> [String] {
        var scoped = raw[...]
        for marker in [
            "before the interface monitor",
            "Start initial configuration in progress",
        ] {
            if let start = raw.lastIndex(where: { $0.contains(marker) }) {
                scoped = raw[start...]
                break
            }
        }
        var seen = Set<String>()
        var out: [String] = []
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        for line in scoped where line.contains("[Apple")
            && !line.contains("level=info")
            && !line.contains("level=debug")
        {
            guard let msgRange = line.range(of: "msg=\"") else { continue }
            var message = String(line[msgRange.upperBound...])
            if message.hasSuffix("\"") { message.removeLast() }
            let cleaned = message
            if seen.insert(cleaned).inserted { out.append(cleaned) }
        }
        return out
    }

     
     
     
     
     
     
     
     
    private static func parse(_ line: String) -> Entry? {
        guard let levelRange = line.range(of: "level=") else {
            guard !line.contains(" INFO  "), !line.contains(" DEBUG  ")
            else { return nil }
            return Entry(message: line, isError: true)
        }
        let afterLevel = line[levelRange.upperBound...]
        let level = afterLevel.prefix { !$0.isWhitespace }
        guard level == "error" || level == "warning" || level == "fatal" else {
            return nil
        }
        let isError = level != "warning"
        guard let messageRange = afterLevel.range(of: #"msg=""#) else {
            return Entry(
                message: String(afterLevel).trimmingCharacters(in: .whitespaces),
                isError: isError
            )
        }
        var message = String(afterLevel[messageRange.upperBound...])
        if message.hasSuffix("\"") { message.removeLast() }
         
         
         
        message = message
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: " ")
        guard !Self.selfDeclaredBenign.contains(where: message.contains) else {
            return nil
        }
        return Entry(message: message, isError: isError)
    }
}
