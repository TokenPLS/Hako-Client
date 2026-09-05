import Foundation
import SwiftUI
import os.log

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoPageProbe {
    private static let log = OSLog(subsystem: "com.hako.probe", category: "page")

     
     
     
     
     
     
     
     
    nonisolated(unsafe) public static var sink: ((String) -> Void)?

    private static func emit(_ line: String) {
        sink?(line)
    }

     
     
     
     
     
     
    public static let isEnabled: Bool = {
        let process = ProcessInfo.processInfo
        let on = false
            || process.environment["HAKO_PAGE_PROBE"] == "1"
         
         
         
        os_log(
            "probe enabled=%{public}@ args=%{public}d",
            log: log,
            type: .info,
            on ? "yes" : "no",
            process.arguments.count
        )
        return on
    }()

    nonisolated(unsafe) private static var counts: [String: Int] = [:]
    nonisolated(unsafe) private static var seen: Set<String> = []
    nonisolated(unsafe) private static var lastPush: DispatchTime?
    nonisolated(unsafe) private static var rowEvaluations = 0
    private static let lock = NSLock()

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    public static func countRowEvaluation(_ label: String) {
        guard isEnabled else { return }
        lock.lock()
        rowEvaluations += 1
        let sequence = rowEvaluations
        lock.unlock()
        os_log(
            "row-eval #%{public}d %{public}@",
            log: log,
            type: .info,
            sequence,
            label
        )
        emit("probe row-eval #\(sequence) \(label)")
    }

     
     
     
     
     
     
     
    public static func markNavigation() {
        guard isEnabled else { return }
        lock.lock()
        lastPush = DispatchTime.now()
        seen.removeAll()
        lock.unlock()
        os_log("navigation-push", log: log, type: .info)
        emit("probe navigation-push")
    }

     
     
     
    public static func stamp(_ label: String, milliseconds: Double) {
        record(label, milliseconds: milliseconds)
    }

    static func record(_ label: String, milliseconds: Double) {
        guard isEnabled else { return }
        lock.lock()
        let count = (counts[label] ?? 0) + 1
        counts[label] = count
         
         
         
        var sincePush: Double?
        if seen.insert(label).inserted, let lastPush {
            sincePush = Double(
                DispatchTime.now().uptimeNanoseconds - lastPush.uptimeNanoseconds
            ) / 1_000_000
        }
        lock.unlock()

        if let sincePush {
            os_log(
                "first-draw %{public}@ %{public}.1fms-after-push",
                log: log,
                type: .info,
                label,
                sincePush
            )
            emit(String(format: "probe first-draw %@ %.1fms-after-push", label, sincePush))
        }

        os_log(
            "%{public}@ #%{public}d %{public}.2fms",
            log: log,
            type: .info,
            label,
            count,
            milliseconds
        )
        emit(String(format: "probe %@ #%d %.2fms", label, count, milliseconds))
    }
}

public extension View {
     
     
     
     
     
     
    @ViewBuilder
    func hakoPageProbe(_ label: String) -> some View {
        if HakoPageProbe.isEnabled {
            HakoPageProbeView(label: label, content: self)
        } else {
            self
        }
    }
}

 
 
 
 
 
 
 
 
 
private struct HakoPageProbeView<Content: View>: View {
    let label: String
    let content: Content

    var body: some View {
        let started = DispatchTime.now()
        defer {
            HakoPageProbe.record(
                label,
                milliseconds: Double(
                    DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds
                ) / 1_000_000
            )
        }
        return content
    }
}
