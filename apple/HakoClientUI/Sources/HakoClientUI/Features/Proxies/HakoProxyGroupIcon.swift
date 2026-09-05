import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoProxyGroupIconKind: Equatable, Sendable {
     
    case emoji(String)
     
    case symbol(HakoSymbol)
     
     
    case remote(host: String)
     
    case unrecognized

    public static func of(_ value: String?) -> HakoProxyGroupIconKind? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }

        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return .remote(host: url.host ?? trimmed)
        }
        if trimmed.unicodeScalars.contains(where: \.properties.isEmojiPresentation) {
            return .emoji(trimmed)
        }
        if let symbol = HakoSymbol(rawValue: trimmed) {
            return .symbol(symbol)
        }
        return .unrecognized
    }
}
