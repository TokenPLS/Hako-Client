import Foundation

 
 
public enum HakoWidgetFormat {
    public static let unknown = "—"

     
     
    public static func bytes(_ value: Int64?) -> String {
        guard let value else { return unknown }
        return HakoThroughputFormatter.usage(value)
    }

     
     
    public static func rate(_ bytesPerSecond: Int64?) -> String {
        guard let bytesPerSecond else { return unknown }
        return HakoThroughputFormatter.rate(bytesPerSecond)
    }

    public static func count(_ value: Int?, locale: Locale) -> String {
        guard let value else { return unknown }
        return HakoCopy.count(value, locale: locale)
    }

     
     
    public static func modeKey(_ mode: HakoWidgetMode) -> String {
        switch mode {
        case .rule: return "Rule"
        case .global: return "Global"
        case .direct: return "Direct"
        }
    }
}
