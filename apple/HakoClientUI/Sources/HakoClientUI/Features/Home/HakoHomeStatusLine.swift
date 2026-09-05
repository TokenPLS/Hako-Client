import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoHomeStatusLine {
    public static let separator = " · "

     
     
     
     
    public static func text(
        subtitle: String,
        duration: String?,
        isConnected: Bool = true
    ) -> String {
        parts(subtitle: subtitle, tail: isConnected ? duration : nil)
    }

     
     
     
    public static func accessibilityLabel(
        subtitle: String,
        secondsElapsed: Int?,
        isConnected: Bool = true,
        locale: Locale = .current
    ) -> String {
        parts(
            subtitle: subtitle,
            tail: isConnected
                ? secondsElapsed.map {
                    HakoCopy.format(
                        "Connected for %@ seconds",
                        locale: locale,
                        "\($0)"
                    )
                }
                : nil
        )
    }

    private static func parts(subtitle: String, tail: String?) -> String {
        [subtitle, tail ?? ""]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }
}
