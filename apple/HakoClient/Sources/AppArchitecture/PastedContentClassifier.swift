import Foundation

 
 
 
 
 
 
 
enum PastedContent: Equatable {
    case empty
    case link(url: String, unwrapped: Unwrap?)
    case nodeShareLinks([String])
    case configText(String)
    case unrecognized

    enum Unwrap: Equatable {
        case installLink
        case subScheme
    }
}

enum PastedContentClassifier {
     
     
     
     
     
    static let nodeSchemes = ProxyImportBridge.profilePasteNodeSchemes

    private static let installSchemes: Set<String> = ["clash", "clashmeta", "flclash"]

    static func classify(_ raw: String) -> PastedContent {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        if let inner = installLinkTarget(trimmed) {
            return .link(url: inner, unwrapped: .installLink)
        }
        if let inner = subSchemeTarget(trimmed) {
             
             
             
            if nodeShareLinks(inner) != nil { return .configText(inner) }
            return .link(url: inner, unwrapped: .subScheme)
        }
        if let links = nodeShareLinks(trimmed) {
            return .nodeShareLinks(links)
        }
        if !trimmed.contains("\n"), scheme(of: trimmed) != nil {
            return .link(url: trimmed, unwrapped: nil)
        }
        if trimmed.contains("\n") || trimmed.contains(":") {
            return .configText(raw)
        }
         
         
         
         
         
        if let decoded = base64Body(trimmed), nodeShareLinks(decoded) != nil {
            return .configText(raw)
        }
        return .unrecognized
    }

     
     
    private static func base64Body(_ text: String) -> String? {
        guard !text.contains(where: \.isNewline), text.count >= 8 else { return nil }
        var padded = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded.append("=") }
        guard let data = Data(base64Encoded: padded),
              let decoded = String(data: data, encoding: .utf8) else { return nil }
        let inner = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return inner.isEmpty ? nil : inner
    }

    private static func scheme(of text: String) -> String? {
        guard let range = text.range(of: "://"), range.lowerBound != text.startIndex else {
            return nil
        }
        let candidate = String(text[text.startIndex..<range.lowerBound]).lowercased()
        return candidate.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "+" }
            ? candidate : nil
    }

    private static func installLinkTarget(_ text: String) -> String? {
        guard let components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(),
              installSchemes.contains(scheme),
              components.host?.lowercased() == "install-config",
              let target = components.queryItems?
                  .first(where: { $0.name == "url" })?.value,
              !target.isEmpty else { return nil }
        return target
    }

    private static func subSchemeTarget(_ text: String) -> String? {
        guard scheme(of: text) == "sub" else { return nil }
        let payload = String(text.dropFirst("sub://".count))
         
        var padded = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while padded.count % 4 != 0 { padded.append("=") }
        guard let data = Data(base64Encoded: padded),
              let decoded = String(data: data, encoding: .utf8) else { return nil }
        let inner = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return inner.isEmpty ? nil : inner
    }

    private static func nodeShareLinks(_ text: String) -> [String]? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        guard lines.allSatisfy({ line in
            guard let scheme = scheme(of: line) else { return false }
            return nodeSchemes.contains(scheme)
        }) else { return nil }
        return lines
    }
}
