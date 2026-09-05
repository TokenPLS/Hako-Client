import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct CoreMemoryPressure: Equatable {
    let footprintBytes: Int64
    let limitBytes: Int64

    var exceededItsLimit: Bool {
        limitBytes > 0 && footprintBytes > limitBytes
    }

     
     
     
     
    static func observed(in raw: [String]) -> CoreMemoryPressure? {
        for line in raw.reversed() {
             
             
             
             
             
             
             
             
             
             
            guard line.contains("critical pressure"),
                  let footprint = value(of: "footprint=", in: line)
            else { continue }
            return CoreMemoryPressure(
                footprintBytes: footprint,
                limitBytes: value(of: "softLimit=", in: line) ?? 0
            )
        }
        return nil
    }

    static func observed(
        limit: Int = 400,
        store: HakoLogStore = .shared
    ) -> CoreMemoryPressure? {
        observed(in: store.tail(.core, limit: limit))
    }

    private static func value(of key: String, in line: String) -> Int64? {
        guard let range = line.range(of: key) else { return nil }
        let digits = line[range.upperBound...].prefix { $0.isNumber }
        return digits.isEmpty ? nil : Int64(digits)
    }
}
