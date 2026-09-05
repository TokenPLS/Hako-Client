import Foundation
import SwiftUI
 
 
 
 
 
 
 
 
 
 
public enum HakoPushClock {
    public static let isEnabled: Bool = {

        false

    }()

    private static func write(_ line: String) {
        if handle == nil {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("push-clock.log")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try? FileHandle(forWritingTo: url)
        }
        try? handle?.write(contentsOf: Data(line.utf8))
    }

    nonisolated(unsafe) private static var tappedAt: TimeInterval?
    nonisolated(unsafe) private static var handle: FileHandle?
    private static let lock = NSLock()

     
     

     
     
    public static func note(_ what: String) {
        guard isEnabled else { return }
        lock.lock(); defer { lock.unlock() }
        let since = tappedAt.map { (Date().timeIntervalSinceReferenceDate - $0) * 1000 } ?? -1
        write(String(format: "note %@ %.1f\n", what, since))
    }

     
    public static func tap() {
        guard isEnabled else { return }
        lock.lock()
        tappedAt = Date().timeIntervalSinceReferenceDate
        lock.unlock()
        Task { @MainActor in Self.display.taps += 1 }
    }

     
    @discardableResult
    public static func arrived() -> Double? {
        guard isEnabled else { return nil }
        lock.lock(); defer { lock.unlock() }
        guard let tappedAt else { return nil }
        let ms = (Date().timeIntervalSinceReferenceDate - tappedAt) * 1000
        Self.tappedAt = nil
        write(String(format: "push %.1f\n", ms))
        Task { @MainActor in
            Self.display.lastMilliseconds = ms
            Self.display.arrivals += 1
        }
        return ms
    }
}

 
 
 
 
@MainActor
public final class HakoPushClockDisplay: ObservableObject {
    @Published public var lastMilliseconds: Double?
     
     
    @Published public var arrivals: Int = 0
     
     
    @Published public var taps: Int = 0
    public init() {}
}

public extension HakoPushClock {
    @MainActor static let display = HakoPushClockDisplay()
}

 
public struct HakoPushClockMarker: View {
    @ObservedObject private var display = HakoPushClock.display

    public init() {}

    public var body: some View {
        if HakoPushClock.isEnabled {
            let ms = display.lastMilliseconds ?? -1
            Text(String(format: "%.1f|%d|%d", ms, display.arrivals, display.taps))
                .font(.system(size: 1))
                .opacity(0.02)
                .allowsHitTesting(false)
                .accessibilityIdentifier("hako-push-clock")
        }
    }
}
