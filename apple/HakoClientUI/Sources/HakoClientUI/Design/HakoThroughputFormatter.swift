import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoThroughputFormatter {
    private static let bitsPerByte: Double = 8
    private static let bitsPerKilobit: Double = 1_000
    private static let bitsPerMegabit: Double = 1_000_000

     
     
     
     
     
    public static func rate(_ bytesPerSecond: Int64) -> String {
        let bitsPerSecond = Double(max(bytesPerSecond, 0)) * bitsPerByte
        if bitsPerSecond < bitsPerMegabit {
            return String(format: "%.0f Kbps", bitsPerSecond / bitsPerKilobit)
        }
        return String(format: "%.1f Mbps", bitsPerSecond / bitsPerMegabit)
    }

     
     
     
     
     
     
     
    public static func usage(_ bytes: Int64) -> String {
        let absolute = Double(max(bytes, 0))
        if absolute < 1_024 { return String(format: "%.0f B", absolute) }
        if absolute < 1_048_576 { return String(format: "%.1f KB", absolute / 1_024) }
        if absolute < 1_073_741_824 { return String(format: "%.1f MB", absolute / 1_048_576) }
        return String(format: "%.2f GB", absolute / 1_073_741_824)
    }
}
