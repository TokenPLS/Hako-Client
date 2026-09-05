import Foundation
import Hako

 
 
 
 
 
 
 
 
 
 
final class StartupMemorySampler {
    static let shared = StartupMemorySampler()

    func begin(container: URL) {
         
         
         
         
         
        let at = Date()
        queue.async {
            self.timer?.cancel()
            self.url = container.appendingPathComponent(
                MemorySampleLog.extensionFileName
            )
            self.peak = 0
            self.drainedCorePhases = 0
            self.lastCoreDiagnostic = ""
            self.append(raw: "--- launch ---")
            self.sample(phase: "begin", at: at)

             
             
             
             
             
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            var ticks = 0
            timer.schedule(deadline: .now() + 0.01, repeating: 0.01)
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                ticks += 1
                self.sample(phase: nil)
                if ticks == 300 {
                     
                    timer.schedule(deadline: .now() + 0.2, repeating: 0.2)
                }
                if ticks == 300 + 60 {
                    timer.schedule(deadline: .now() + 1, repeating: 1)
                }
                if ticks >= 300 + 75 {
                    self.finish()
                }
            }
            timer.resume()
            self.timer = timer
        }
    }

     
    func note(_ text: String) {
        let at = Date()
        queue.async {
            self.append(raw: "    " + MemorySampleLog.noteLine(at: at, text: text))
        }
    }

     
    func mark(_ phase: String) {
         
         
         
        let at = Date()
        queue.async { self.sample(phase: phase, at: at) }
    }

     
     
     
     
     
    private func drainCorePhases() {
         
         
         
        let trace = HakoStartupPhaseTrace()
        let diagnostic = "core-diag lines=\(trace.isEmpty ? 0 : trace.split(separator: "\n").count) "
            + HakoStartupPhaseDiagnostic()
        if diagnostic != lastCoreDiagnostic {
            lastCoreDiagnostic = diagnostic
            append(raw: "    " + diagnostic)
        }
        guard !trace.isEmpty else { return }
        let lines = trace.split(separator: "\n").map(String.init)
        guard lines.count > drainedCorePhases else { return }
        for line in lines[drainedCorePhases...] {
            append(raw: "    " + line)
        }
        drainedCorePhases = lines.count
    }

    private func sample(phase: String?, at: Date = Date()) {
        guard let url else { return }
        drainCorePhases()
        let footprint = HakoMemoryFootprint()
        if footprint > peak { peak = footprint }
        MemorySampleLog.append(
            MemorySampleLog.line(at: at, footprintBytes: footprint, phase: phase),
            to: url,
            maxBytes: Self.maxBytes
        )
    }

    private func finish() {
        timer?.cancel()
        timer = nil
        guard let url else { return }
        MemorySampleLog.append(
            MemorySampleLog.line(at: Date(), footprintBytes: peak, phase: "peak"),
            to: url,
            maxBytes: Self.maxBytes
        )
    }

    private func append(raw line: String) {
        guard let url else { return }
        MemorySampleLog.append(line, to: url, maxBytes: Self.maxBytes)
    }

    private static let maxBytes = 512 * 1024
    private let queue = DispatchQueue(label: "network.hako.memsample", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var url: URL?
    private var peak: Int64 = 0
    private var drainedCorePhases = 0
    private var lastCoreDiagnostic = ""
}
