import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public enum HakoMainThreadHeartbeat {
    public static let isEnabled = ProcessInfo.processInfo
        .arguments.contains("--hako-perf-heartbeat")

     
     
     
    private static let threshold: TimeInterval = 0.033

    private static let queue = DispatchQueue(
        label: "network.hako.heartbeat", qos: .userInteractive
    )
    nonisolated(unsafe) private static var timer: DispatchSourceTimer?

    public static func start() {
        guard isEnabled, timer == nil else { return }
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + 0.5, repeating: 0.02, leeway: .milliseconds(2))
        source.setEventHandler {
            let sent = DispatchTime.now().uptimeNanoseconds
            DispatchQueue.main.async {
                let latency = Double(
                    DispatchTime.now().uptimeNanoseconds - sent
                ) / 1_000_000_000
                guard latency >= threshold else { return }
                MainActor.assumeIsolated {
                    let line = String(
                        format: "mainthread blocked %.1fms", latency * 1000
                    )
                    HakoPerf.log.warning("\(line, privacy: .public)")
                    HakoPerf.emit(line)
                    emitLedgerIfDue(latency: latency)
                }
            }
        }
        source.resume()
        timer = source
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @MainActor
    private static var lastLedgerAt: UInt64 = 0

    @MainActor
    private static var ledgerOpenedAt: UInt64 = 0

     
    private static let ledgerWindow: Double = 2

     
     
    private static let ledgerFloor: TimeInterval = 0.1

    @MainActor
    private static func emitLedgerIfDue(latency: TimeInterval) {
        let now = DispatchTime.now().uptimeNanoseconds
        defer { ledgerOpenedAt = now }
        guard latency >= ledgerFloor else { return }
        let sinceLast = Double(now &- lastLedgerAt) / 1_000_000_000
        guard lastLedgerAt == 0 || sinceLast > 0.5 else { return }
        let age = Double(now &- ledgerOpenedAt) / 1_000_000_000
        guard ledgerOpenedAt != 0, age <= ledgerWindow else {
             
             
            HakoPerf.discardTallies()
            lastLedgerAt = now
            return
        }
        lastLedgerAt = now
         
         
         
         
         
        let ledger = HakoPerf.drainTallies() ?? "(no armed spans)"
        let line = String(
            format: "blocked-ledger %.0fms over=%.2fs %@",
            latency * 1000, age, ledger
        )
        HakoPerf.log.warning("\(line, privacy: .public)")
        HakoPerf.emit(line)
    }
}
