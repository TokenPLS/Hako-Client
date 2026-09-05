import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoInstant {
     
    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

     
     
    nonisolated(unsafe) private static let whole = ISO8601DateFormatter()

     
     
     
     
     
     
     
     
     
    private static let guardrail = NSLock()

     
     
     
     
    public static func parse(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        guardrail.lock()
        defer { guardrail.unlock() }
        if let date = fractional.date(from: value) { return date }
        return whole.date(from: value)
    }
}
