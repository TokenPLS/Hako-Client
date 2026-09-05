import Foundation
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoCopy {
     
     
     
     
     
     
     
     
     
    public static func key(_ value: String) -> LocalizedStringKey {
        LocalizedStringKey(value)
    }

     
     
     
     
     
     
     
     
     
    public static func string(_ value: String, locale: Locale) -> String {
        let bundle = languageBundle(for: locale) ?? .main
        return bundle.localizedString(forKey: value, value: value, table: nil)
    }

     
     
    public static func composedString(_ value: String, locale: Locale) -> String {
        let exact = string(value, locale: locale)
        guard exact == value, value.contains(" · ") else {
            return exact
        }
        return value
            .components(separatedBy: " · ")
            .map { string($0, locale: locale) }
            .joined(separator: " · ")
    }

     
     
     
    public static func string(
        for text: HakoDisplayText,
        locale: Locale
    ) -> String {
        switch text {
        case .copy(let value):
            return string(value, locale: locale)
        case .verbatim(let value):
            return value
        case .format(let format, let arguments), .formatCopy(let format, let arguments):
             
             
             
             
            var arguments = arguments
            if case .formatCopy = text { arguments = arguments.map { string($0, locale: locale) } }
            let source = HakoDisplayText.formatSegments(of: format)
            var pieces = string(format, locale: locale)
                .components(separatedBy: "%@")
            if pieces.count != source.count {
                pieces = source
            }
            var line = pieces.removeFirst()
            for (index, piece) in pieces.enumerated() {
                line += (index < arguments.count ? arguments[index] : "%@")
                line += piece
            }
            return line
        }
    }

     
     
     
    public static func count(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }

     
    public static func format(
        _ value: String,
        locale: Locale,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(value, locale: locale),
            locale: locale,
            arguments: arguments
        )
    }

     
     
    nonisolated(unsafe) private static let languageBundles = NSCache<NSString, Bundle>()

    private static func languageBundle(for locale: Locale) -> Bundle? {
        let code = locale.identifier.replacingOccurrences(of: "_", with: "-")
        if let cached = languageBundles.object(forKey: code as NSString) {
            return cached
        }
         
         
        var candidate = code
        while !candidate.isEmpty {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                languageBundles.setObject(bundle, forKey: code as NSString)
                return bundle
            }
            guard let cut = candidate.lastIndex(of: "-") else { break }
            candidate = String(candidate[candidate.startIndex..<cut])
        }
        return nil
    }
}

public extension HakoDisplayText {
     
     
     
     
    func resolved(locale: Locale) -> String {
        switch self {
        case .verbatim(let value):
            return value
        case .copy(let value):
            return HakoCopy.string(value, locale: locale)
        case .format(let format, let arguments), .formatCopy(let format, let arguments):
            var line = HakoCopy.string(format, locale: locale)
            var arguments = arguments
            if case .formatCopy = self { arguments = arguments.map { HakoCopy.string($0, locale: locale) } }
            for argument in arguments {
                guard let range = line.range(of: "%@")
                    ?? line.range(of: "%d")
                    ?? line.range(of: "%@", options: .literal)
                else { break }
                line.replaceSubrange(range, with: argument)
            }
            return line
        }
    }
}

public extension String {
     
    var hakoLocalized: LocalizedStringKey {
        HakoCopy.key(self)
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoDisplayText:
    Codable,
    Equatable,
    Hashable,
    Sendable,
    ExpressibleByStringLiteral
{
     
    case copy(String)
     
    case verbatim(String)
     
     
     
     
    case format(String, [String])
     
     
     
     
     
     
     
     
     
    case formatCopy(String, [String])

    public init(stringLiteral value: String) {
        self = .copy(value)
    }

     
     
     
     
     
     
    var frameWatchLabel: String {
        switch self {
        case .copy(let value): return value
        case .verbatim: return "(verbatim)"
        case .format(let format, _), .formatCopy(let format, _): return format
        }
    }

     
     
     
     
     
     
     
    func frameWatchLabel(overriddenBy explicit: String?) -> String {
        explicit ?? frameWatchLabel
    }

     
     
    public var rawValue: String {
        switch self {
        case .copy(let value), .verbatim(let value): return value
        case .format(let format, let arguments), .formatCopy(let format, let arguments):
            var pieces = Self.formatSegments(of: format)
            var line = pieces.removeFirst()
            for (index, piece) in pieces.enumerated() {
                line += (index < arguments.count ? arguments[index] : "%@")
                line += piece
            }
            return line
        }
    }

     
     
     
     
     
     
    func bounded(to limit: Int) -> HakoDisplayText {
        switch self {
        case .copy(let value):
            return .copy(String(value.prefix(limit)))
        case .verbatim(let value):
            return .verbatim(String(value.prefix(limit)))
        case .format(let format, let arguments):
            return .format(
                String(format.prefix(limit)),
                arguments.map { String($0.prefix(limit)) }
            )
        case .formatCopy(let format, let arguments):
            return .formatCopy(
                String(format.prefix(limit)),
                arguments.map { String($0.prefix(limit)) }
            )
        }
    }

     
     
     
     
     
     
     
    static func formatSegments(of format: String) -> [String] {
        format.components(separatedBy: "%@")
    }
}

public extension Text {
     
    init(hako text: HakoDisplayText) {
        switch text {
        case .copy(let value):
            self.init(HakoCopy.key(value))
        case .verbatim(let value):
            self.init(verbatim: value)
        case .format(let format, let arguments), .formatCopy(let format, let arguments):
             
             
             
             
             
             
             
            let translatesArguments: Bool
            if case .formatCopy = text { translatesArguments = true } else { translatesArguments = false }
            var interpolation = LocalizedStringKey.StringInterpolation(
                literalCapacity: format.count,
                interpolationCount: arguments.count
            )
            var pieces = HakoDisplayText.formatSegments(of: format)
            interpolation.appendLiteral(pieces.removeFirst())
            for (index, piece) in pieces.enumerated() {
                let argument = index < arguments.count ? arguments[index] : "%@"
                if translatesArguments {
                    interpolation.appendInterpolation(Text(HakoCopy.key(argument)))
                } else {
                    interpolation.appendInterpolation(argument)
                }
                interpolation.appendLiteral(piece)
            }
            self.init(LocalizedStringKey(stringInterpolation: interpolation))
        }
    }
}

