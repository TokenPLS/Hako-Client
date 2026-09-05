import Foundation

 
 
 
 
 
 
 
 
 
enum MemorySampleLog {
     
     
     
     
    static let extensionFileName = "hako-extension-memory.log"

     
     
    static let startupPhaseFileName = "hako-core-phases.log"

     
    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

     
     
     
    static func noteLine(at date: Date, text: String) -> String {
        clock.string(from: date) + "  " + text
    }

     
     
    static func line(at date: Date, footprintBytes: Int64, phase: String? = nil) -> String {
        let mebibytes = Double(footprintBytes) / 1_048_576
        var line = String(
            format: "%@  mem fp=%.1fMiB", clock.string(from: date), mebibytes
        )
        if let phase {
            line += " phase=" + phase
        }
        return line
    }

     
     
     
    static func append(_ line: String, to url: URL, maxBytes: Int) {
        let data = Data((line + "\n").utf8)
        var size = UInt64(0)
        if let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
             
             
             
            size = (try? handle.offset()) ?? UInt64(maxBytes) + 1
            try? handle.close()
        } else {
            try? data.write(to: url)
            size = UInt64(data.count)
        }
        guard size > UInt64(maxBytes) else { return }
        dropOldestHalfIfNeeded(at: url, maxBytes: maxBytes)
    }

     
     
     
    @discardableResult
    static func mirror(from source: URL, to destination: URL) -> Bool {
        guard let data = try? Data(contentsOf: source) else { return false }
        return (try? data.write(to: destination, options: .atomic)) != nil
    }

    private static func dropOldestHalfIfNeeded(at url: URL, maxBytes: Int) {
        guard let full = try? Data(contentsOf: url), full.count > maxBytes else {
            return
        }
        var keep = full.suffix(maxBytes / 2)
         
        if let newline = keep.firstIndex(of: 0x0A) {
            keep = keep[keep.index(after: newline)...]
        }
        try? keep.write(to: url, options: .atomic)
    }
}
