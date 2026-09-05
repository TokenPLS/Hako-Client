import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
public final class HakoActivityProjectionMemo {
    public init() {}

    private struct LogsKey: Equatable {
        let lines: [String]
        let query: String
        let severities: Set<HakoActivityLogSeverity>
    }

    private var logsKey: LogsKey?
    private var logsValue: [HakoActivityLogEntry] = []
     
     
     
     
    private var logEntries: [HakoActivityLogEntry.ID: HakoActivityLogEntry] = [:]
    private let logEntryLimit = 8192

     
     
    public private(set) var builds = 0

    private struct RequestsKey: Equatable {
        let values: [HakoActivityRequestSnapshot]
        let query: String
        let keywords: Set<String>
    }

    private var requestsKey: RequestsKey?
    private var requestsValue: [HakoActivityRequestSnapshot] = []

     
     
     
     
     
    public func requests(
        _ values: [HakoActivityRequestSnapshot],
        query: String,
        keywords: Set<String>
    ) -> [HakoActivityRequestSnapshot] {
        let key = RequestsKey(values: values, query: query, keywords: keywords)
        if let requestsKey, requestsKey == key { return requestsValue }
        builds += 1
        let value = HakoActivityProjection.requests(
            values, query: query, keywords: keywords
        )
        requestsKey = key
        requestsValue = value
        return value
    }

    public func logs(
        _ lines: [String],
        query: String,
        severities: Set<HakoActivityLogSeverity>
    ) -> [HakoActivityLogEntry] {
        let key = LogsKey(lines: lines, query: query, severities: severities)
        if let logsKey, logsKey == key { return logsValue }
        builds += 1
        if logEntries.count >= logEntryLimit {
            logEntries.removeAll(keepingCapacity: true)
        }
        let value = HakoActivityProjection.logs(
            lines, query: query, severities: severities, entries: &logEntries
        )
        logsKey = key
        logsValue = value
        return value
    }
}
