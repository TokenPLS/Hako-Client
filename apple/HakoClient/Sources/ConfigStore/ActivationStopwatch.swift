import Foundation
import os

 
 
 
 
 
 
 
 
final class ActivationStopwatch {
    private struct Stage {
        let name: String
        let seconds: Double
        let count: Int?
        let detail: String?
    }

    private static let system = Logger(subsystem: "org.example.hako", category: "activation")

     
     
     
     
     
     
    private static let buildStamp: String = {
        guard let executable = Bundle.main.executableURL,
              let modified = (try? executable.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate else { return "?" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd-HHmm"
        return formatter.string(from: modified)
    }()

    private var stages: [Stage] = []
    private var last = Date()
    private let started = Date()

    func mark(_ name: String, count: Int? = nil, detail: String? = nil) {
        let now = Date()
        stages.append(Stage(
            name: name, seconds: now.timeIntervalSince(last), count: count, detail: detail))
        last = now
    }

    func report() {
        let total = Date().timeIntervalSince(started)
        let breakdown = stages
             
            .filter { $0.seconds >= 0.01 }
            .map { stage -> String in
                let millis = Int((stage.seconds * 1000).rounded())
                var text = "\(stage.name)=\(millis)ms"
                if let count = stage.count { text += "(n=\(count)" }
                if let detail = stage.detail {
                    text += stage.count == nil ? "(\(detail)" : " \(detail)"
                }
                if stage.count != nil || stage.detail != nil { text += ")" }
                return text
            }
            .joined(separator: " ")
        let line = "activation  build=\(Self.buildStamp)  total=\(Int((total * 1000).rounded()))ms  \(breakdown)"
        HakoLogStore.shared.append(line, stream: .app)
         
         
         
         
        Self.system.info("\(line, privacy: .public)")
    }
}
