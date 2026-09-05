import Foundation

 
 
 
 
 
 
 
 
 
public enum HakoConnectionDuration {
     
     
     
     
     
    public static func text(secondsElapsed: Int) -> String {
        let clamped = min(max(secondsElapsed, 0), 99 * 3600 + 59 * 60 + 59)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let seconds = clamped % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

     
     
     
    public static func secondsElapsed(
        sinceUnixSeconds start: Int64,
        now: Date = Date()
    ) -> Int? {
        guard start > 0 else { return nil }
        return Int(now.timeIntervalSince1970) - Int(start)
    }
}

 
 
 
 
public enum HakoTrafficSeries {
     
     
     
    public static func normalized(_ samples: [Int64]) -> [Double] {
        guard let peak = samples.max(), peak > 0 else {
            return samples.map { _ in 0 }
        }
        return samples.map { Double(max($0, 0)) / Double(peak) }
    }

     
     
     
     
     
     
    public static func normalizedPair(
        upload: [Int64],
        download: [Int64]
    ) -> (upload: [Double], download: [Double]) {
        let peak = max(upload.max() ?? 0, download.max() ?? 0)
        guard peak > 0 else {
            return (upload.map { _ in 0 }, download.map { _ in 0 })
        }
        let scale = { (samples: [Int64]) in
            samples.map { Double(max($0, 0)) / Double(peak) }
        }
        return (scale(upload), scale(download))
    }
}
