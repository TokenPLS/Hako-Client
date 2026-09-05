import Foundation

public enum HakoActivityConnectionSort:
    String,
    CaseIterable,
    Codable,
    Identifiable,
    Sendable
{
    case recent = "Recent"
    case traffic = "Traffic"
    case destination = "Destination"

    public var id: String { rawValue }
}

public struct HakoActivityConnectionSnapshot:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let id: String
    public let destination: String
    public let source: String
    public let network: String
    public let route: String
    public let rule: String
    public let upload: Int64
    public let download: Int64
    public let start: Date?
    public let uid: Int64
    public let host: String
    public let sourceIP: String
    public let sourcePort: String
    public let destinationIP: String
    public let destinationPort: String
    public let dnsMode: String
    public let process: String
    public let processPath: String
    public let remoteDestination: String
    public let sourceGeoIP: [String]
    public let destinationGeoIP: [String]
    public let destinationIPASN: String
    public let sourceIPASN: String
    public let specialRules: String
    public let specialProxy: String
    public let chains: [String]
    public let rulePayload: String
    public let uploadSpeed: Int64?
    public let downloadSpeed: Int64?

    public init(
        id: String,
        destination: String,
        source: String,
        network: String,
        route: String,
        rule: String,
        upload: Int64,
        download: Int64,
        start: Date?,
        uid: Int64 = 0,
        host: String = "",
        sourceIP: String = "",
        sourcePort: String = "",
        destinationIP: String = "",
        destinationPort: String = "",
        dnsMode: String = "",
        process: String = "",
        processPath: String = "",
        remoteDestination: String = "",
        sourceGeoIP: [String] = [],
        destinationGeoIP: [String] = [],
        destinationIPASN: String = "",
        sourceIPASN: String = "",
        specialRules: String = "",
        specialProxy: String = "",
        chains: [String] = [],
        rulePayload: String = "",
        uploadSpeed: Int64? = nil,
        downloadSpeed: Int64? = nil
    ) {
        self.id = id
        self.destination = destination
        self.source = source
        self.network = network
        self.route = route
        self.rule = rule
        self.upload = max(0, upload)
        self.download = max(0, download)
        self.start = start
        self.uid = uid
        self.host = host
        self.sourceIP = sourceIP
        self.sourcePort = sourcePort
        self.destinationIP = destinationIP
        self.destinationPort = destinationPort
        self.dnsMode = dnsMode
        self.process = process
        self.processPath = processPath
        self.remoteDestination = remoteDestination
        self.sourceGeoIP = sourceGeoIP
        self.destinationGeoIP = destinationGeoIP
        self.destinationIPASN = destinationIPASN
        self.sourceIPASN = sourceIPASN
        self.specialRules = specialRules
        self.specialProxy = specialProxy
        self.chains = chains
        self.rulePayload = rulePayload
        self.uploadSpeed = uploadSpeed.map { max(0, $0) }
        self.downloadSpeed = downloadSpeed.map { max(0, $0) }
    }

    public var total: Int64 {
        let (value, overflow) =
            upload.addingReportingOverflow(download)
        return overflow ? .max : value
    }

    public var ruleDescription: String {
        rulePayload.isEmpty
            ? rule
            : "\(rule)(\(rulePayload))"
    }

    public var processDescription: String {
        guard uid != 0 else { return process }
        return process.isEmpty
            ? String(uid)
            : "\(process)(\(uid))"
    }
}

public struct HakoActivityRequestSnapshot:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let connection: HakoActivityConnectionSnapshot
    public let firstSeen: Date
    public let lastSeen: Date
    public let closedAt: Date?

    public init(
        connection: HakoActivityConnectionSnapshot,
        firstSeen: Date,
        lastSeen: Date,
        closedAt: Date? = nil
    ) {
        self.connection = connection
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
        self.closedAt = closedAt
    }

    public var id: String { connection.id }
    public var isActive: Bool { closedAt == nil }
}

public enum HakoActivityLogSeverity:
    String,
    CaseIterable,
    Codable,
    Identifiable,
    Sendable
{
    case debug
    case info
    case warning
    case error

    public var id: String { rawValue }

    public var title: String {
        rawValue.capitalized
    }

     
     
     
    public static func severities(
        fromRawValues rawValues: [String]
    ) -> Set<HakoActivityLogSeverity> {
        Set(rawValues.compactMap(HakoActivityLogSeverity.init(rawValue:)))
    }
}

 
 
 
public struct HakoLogRetentionOption:
    Codable,
    Equatable,
    Identifiable,
    Sendable
{
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct HakoActivityLogEntry:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public struct ID: Hashable, Codable, Sendable {
        public let text: String
        public let occurrence: Int

        public init(text: String, occurrence: Int) {
            self.text = text
            self.occurrence = occurrence
        }
    }

    public let text: String
    public let occurrence: Int

     
     
     
     
     
     
     
     
     
     
     
     
    public let severity: HakoActivityLogSeverity?
    public let message: String

    public init(text: String, occurrence: Int) {
        self.text = text
        self.occurrence = max(0, occurrence)
        let level = Self.level(in: text)
        self.severity = level?.severity
        self.message = level.map { String(text[$0.messageStart...]) } ?? text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            text: try container.decode(String.self, forKey: .text),
            occurrence: try container.decode(Int.self, forKey: .occurrence)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(occurrence, forKey: .occurrence)
    }

    private enum CodingKeys: String, CodingKey {
        case text
        case occurrence
    }

    public var id: ID {
        ID(text: text, occurrence: occurrence)
    }

     
     
     
     
     
    private static func level(
        in text: String
    ) -> (severity: HakoActivityLogSeverity, messageStart: String.Index)? {
        var cursor = text.startIndex
        for _ in 0..<2 {
            while cursor < text.endIndex, text[cursor].isWhitespace {
                cursor = text.index(after: cursor)
            }
            guard cursor < text.endIndex else { return nil }
            let end = text[cursor...].firstIndex(where: \.isWhitespace)
                ?? text.endIndex
            if let severity = severity(named: String(text[cursor..<end])) {
                var start = end
                while start < text.endIndex, text[start].isWhitespace {
                    start = text.index(after: start)
                }
                return (severity, start)
            }
            cursor = end
        }
        return nil
    }

    private static func severity(
        named token: String
    ) -> HakoActivityLogSeverity? {
        switch token.uppercased() {
        case "DEBUG": return .debug
        case "INFO": return .info
        case "WARN", "WARNING": return .warning
        case "ERROR": return .error
        default: return nil
        }
    }
}

public struct HakoActivityChainSummary:
    Identifiable,
    Codable,
    Equatable,
    Sendable
{
    public let chains: [String]
    public let connectionCount: Int
    public let upload: Int64
    public let download: Int64

    public init(
        chains: [String],
        connectionCount: Int,
        upload: Int64,
        download: Int64
    ) {
        self.chains = chains
        self.connectionCount = max(0, connectionCount)
        self.upload = max(0, upload)
        self.download = max(0, download)
    }

    public var id: String {
        chains.joined(separator: "\u{1f}")
    }

    public var path: String {
        chains.joined(separator: " → ")
    }

    public var total: Int64 {
        let (value, overflow) =
            upload.addingReportingOverflow(download)
        return overflow ? .max : value
    }
}

public enum HakoActivityProjection {
     
     
     
     
     
     
     
     
    public static let connectionRenderCap = 500

    public static func connectionCount(
        _ values: [HakoActivityConnectionSnapshot],
        query: String,
        keywords: Set<String> = []
    ) -> Int {
        filtered(values, query: query, keywords: keywords).count
    }

    private static func filtered(
        _ values: [HakoActivityConnectionSnapshot],
        query: String,
        keywords: Set<String>
    ) -> [HakoActivityConnectionSnapshot] {
        connections(values, query: query, sort: .recent, keywords: keywords, limit: nil)
    }

    public static func connections(
        _ values: [HakoActivityConnectionSnapshot],
        query: String,
        sort: HakoActivityConnectionSort,
        keywords: Set<String> = [],
        limit: Int? = connectionRenderCap
    ) -> [HakoActivityConnectionSnapshot] {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedKeywords =
            Set(keywords.map { $0.lowercased() })

         
         
         
         
         
         
         
        return values
            .filter { connection in
                if !normalizedKeywords.isEmpty {
                    let matchesEvery = normalizedKeywords.allSatisfy { keyword in
                        if connection.process.lowercased() == keyword {
                            return true
                        }
                        return connection.chains.contains {
                            $0.lowercased() == keyword
                        }
                    }
                    if !matchesEvery { return false }
                }
                if normalizedQuery.isEmpty { return true }
                return searchableText(for: connection)
                    .contains(normalizedQuery)
            }
            .sorted { lhs, rhs in
                switch sort {
                case .recent:
                    let lhsStart = lhs.start ?? .distantPast
                    let rhsStart = rhs.start ?? .distantPast
                    if lhsStart == rhsStart {
                        return lhs.id < rhs.id
                    }
                    return lhsStart > rhsStart
                case .traffic:
                    if lhs.total == rhs.total {
                        return lhs.id < rhs.id
                    }
                    return lhs.total > rhs.total
                case .destination:
                    let comparison =
                        lhs.destination
                        .localizedCaseInsensitiveCompare(
                            rhs.destination
                        )
                    if comparison == .orderedSame {
                        return lhs.id < rhs.id
                    }
                    return comparison == .orderedAscending
                }
            }
            .hakoPrefixed(by: limit)
    }

    public static func requests(
        _ values: [HakoActivityRequestSnapshot],
        query: String,
        keywords: Set<String>
    ) -> [HakoActivityRequestSnapshot] {
        let normalizedKeywords =
            Set(keywords.map { $0.lowercased() })
        return values.filter { entry in
            let connection = entry.connection
            let universe = Set(
                (connection.chains + [connection.process])
                    .filter { !$0.isEmpty }
                    .map { $0.lowercased() }
            )
            let matchesQuery =
                query.isEmpty
                    || [
                        connection.destination,
                        connection.source,
                        connection.network,
                        connection.route,
                        connection.ruleDescription,
                        connection.process,
                        connection.destinationIPASN,
                    ].contains {
                        $0.localizedCaseInsensitiveContains(query)
                    }
            return normalizedKeywords.isSubset(of: universe)
                && matchesQuery
        }
    }

    public static func logs(
        _ lines: [String],
        query: String,
        severities: Set<HakoActivityLogSeverity>
    ) -> [HakoActivityLogEntry] {
        var cache: [HakoActivityLogEntry.ID: HakoActivityLogEntry] = [:]
        return logs(
            lines, query: query, severities: severities, entries: &cache
        )
    }

     
     
     
     
     
     
     
     
     
     
    public static func logs(
        _ lines: [String],
        query: String,
        severities: Set<HakoActivityLogSeverity>,
        entries cache: inout [HakoActivityLogEntry.ID: HakoActivityLogEntry]
    ) -> [HakoActivityLogEntry] {
        var occurrences: [String: Int] = [:]
        return lines.compactMap { line in
            let occurrence = occurrences[line, default: 0]
            occurrences[line] = occurrence + 1
            let id = HakoActivityLogEntry.ID(
                text: line, occurrence: occurrence
            )
            let entry: HakoActivityLogEntry
            if let hit = cache[id] {
                entry = hit
            } else {
                entry = HakoActivityLogEntry(
                    text: line, occurrence: occurrence
                )
                cache[id] = entry
            }
            guard query.isEmpty
                    || line.localizedCaseInsensitiveContains(query)
            else {
                return nil
            }
            guard severities.isEmpty
                    || entry.severity.map(severities.contains) == true
            else {
                return nil
            }
            return entry
        }
    }

    public static func chainSummaries(
        _ connections: [HakoActivityConnectionSnapshot]
    ) -> [HakoActivityChainSummary] {
        struct Accumulator {
            var count = 0
            var upload: Int64 = 0
            var download: Int64 = 0
        }
        var grouped: [[String]: Accumulator] = [:]
        for connection in connections
        where !connection.chains.isEmpty {
            var value =
                grouped[connection.chains] ?? Accumulator()
            value.count += 1
            value.upload = adding(
                value.upload,
                connection.upload
            )
            value.download = adding(
                value.download,
                connection.download
            )
            grouped[connection.chains] = value
        }
        return grouped.map { chains, value in
            HakoActivityChainSummary(
                chains: chains,
                connectionCount: value.count,
                upload: value.upload,
                download: value.download
            )
        }
        .sorted { lhs, rhs in
            if lhs.total == rhs.total {
                return lhs.path.localizedCaseInsensitiveCompare(
                    rhs.path
                ) == .orderedAscending
            }
            return lhs.total > rhs.total
        }
    }

     
     
    fileprivate static func prefixMarker() {}

    private static func searchableText(
        for connection: HakoActivityConnectionSnapshot
    ) -> String {
        [
            connection.destination,
            connection.source,
            connection.route,
            connection.ruleDescription,
            connection.network,
            connection.host,
            connection.destinationIP,
            connection.process,
            connection.processPath,
            connection.destinationIPASN,
            connection.destinationGeoIP.joined(separator: " "),
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private static func adding(
        _ lhs: Int64,
        _ rhs: Int64
    ) -> Int64 {
        let (value, overflow) =
            lhs.addingReportingOverflow(rhs)
        return overflow ? .max : value
    }
}


private extension Array {
    func hakoPrefixed(by limit: Int?) -> [Element] {
        guard let limit, count > limit else { return self }
        return Array(prefix(limit))
    }
}
