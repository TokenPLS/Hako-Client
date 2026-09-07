import Foundation

 
 
 
 
 
 
public enum PanelName {
     
     
    public static func suggested(fromContentDisposition header: String?) -> String? {
        guard let header else { return nil }
        var candidate: String?
        for part in header.split(separator: ";") {
            let piece = part.trimmingCharacters(in: .whitespaces)
            if piece.lowercased().hasPrefix("filename*=") {
                var value = String(piece.dropFirst("filename*=".count))
                 
                 
                 
                 
                let parts = value.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
                if parts.count == 3 {
                    value = String(parts[2])
                }
                candidate = value.removingPercentEncoding ?? value
                break
            }
            if candidate == nil, piece.lowercased().hasPrefix("filename=") {
                candidate = String(piece.dropFirst("filename=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        guard var name = candidate?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        for suffix in [".yaml", ".yml"] where name.lowercased().hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
        }
        return name.isEmpty ? nil : String(name.prefix(80))
    }

     
    public static func deduplicated(_ label: String, existing: some Collection<String>) -> String {
        let taken = Set(existing)
        var candidate = label
        while taken.contains(candidate) {
            candidate = incrementingCounter(candidate)
        }
        return candidate
    }

    private static func incrementingCounter(_ label: String) -> String {
        if let open = label.lastIndex(of: "("),
           label.hasSuffix(")"),
           label.index(after: open) < label.index(before: label.endIndex),
           let number = Int(label[label.index(after: open)..<label.index(before: label.endIndex)]),
           number < Int.max {
            return "\(label[label.startIndex..<open])(\(number + 1))"
        }
         
        return "\(label)(1)"
    }
}
