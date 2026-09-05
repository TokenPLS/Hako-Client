import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoMemoryLedger: Equatable {
    struct Row: Equatable {
         
         
        let name: String
         
        let footprintBytes: Int64
         
        let deltaBytes: Int64
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        var peakBytes: Int64?

         
         
         
         
         
         
         
         
         
         
         
         
        var peakSpendBytes: Int64 {
            guard let peakBytes else { return deltaBytes }
            return max(peakBytes - (footprintBytes - deltaBytes), deltaBytes)
        }
    }

    let rows: [Row]

     
     
     
     
    static func lastRun(from lines: [String]) -> HakoMemoryLedger {
         
        func mebibytes(after key: String, in line: String) -> Int64? {
            guard let range = line.range(of: key) else { return nil }
            let magnitude = line[range.upperBound...]
                .prefix { $0.isNumber || $0 == "." }
            guard let value = Double(magnitude) else { return nil }
            return Int64((value * 1_048_576).rounded())
        }
        var parsed: [(String, Int64, Int64?)] = []
        for line in lines {
            guard let phaseRange = line.range(of: "go-phase="),
                  let fpRange = line.range(of: "fp=")
            else { continue }
             
             
             
             
            let name = line[phaseRange.upperBound..<fpRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty,
                  let footprint = mebibytes(after: "fp=", in: line)
            else { continue }
             
             
             
             
             
            parsed.append((
                name,
                footprint,
                mebibytes(after: "peak=", in: line)
            ))
        }
        if let start = parsed.lastIndex(where: {
            $0.0 == "start-first-statement"
        }) {
            parsed = Array(parsed[start...])
        }
        var rows: [Row] = []
        for (index, probe) in parsed.enumerated() {
            rows.append(Row(
                name: probe.0,
                footprintBytes: probe.1,
                deltaBytes: index == 0 ? 0 : probe.1 - parsed[index - 1].1,
                peakBytes: probe.2
            ))
        }
        return HakoMemoryLedger(rows: rows)
    }

     
     
     
     
     
    func unprobedRemainder(pressureFootprintBytes: Int64) -> Int64? {
        guard let last = rows.last else { return nil }
        let gap = pressureFootprintBytes - last.footprintBytes
        return gap > 0 ? gap : nil
    }
}
