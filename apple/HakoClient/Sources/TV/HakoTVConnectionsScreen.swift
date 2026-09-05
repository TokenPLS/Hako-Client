import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVConnectionsScreen: View {
     
     
     
     
    enum Filter: Hashable, CaseIterable {
        case all, proxied, direct, rejected

        var title: String {
            switch self {
            case .all: String(localized: "All")
            case .proxied: String(localized: "Proxied")
            case .direct: String(localized: "Direct")
            case .rejected: String(localized: "Rejected")
            }
        }

         
         
         
         
         
         
        var identifier: String {
            switch self {
            case .all: "all"
            case .proxied: "proxied"
            case .direct: "direct"
            case .rejected: "rejected"
            }
        }
    }

     
     
     
     
     
     
     
     
     
     
    struct Door: Hashable {
        let connection: HakoActivityConnectionSnapshot

        static func == (lhs: Door, rhs: Door) -> Bool {
            lhs.connection.id == rhs.connection.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(connection.id)
        }
    }

    @Binding var state: HakoTVProductState
     
     
    @Binding var opened: Door?

    @State private var kind: Filter = .all
     
    @FocusState private var focused: HakoActivityConnectionSnapshot.ID?
     
     
    @State private var anchor: FocusAnchor?

    var body: some View {
        let rows = Self.rows(state.connections, kind: kind)
        HStack(alignment: .top, spacing: 40) {
            filters
                .frame(maxWidth: 520)
            VStack(alignment: .leading, spacing: 16) {
                Text(Self.header(count: rows.count))
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
                List {
                    if let vacancy = Self.vacancy(connections: state.connections, kind: kind, isConnected: state.isConnected) {
                         
                         
                         
                         
                        Text(vacancy)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(rows) { connection in
                        Button {
                            anchor = Self.anchor(for: connection.id, in: rows)
                            opened = Door(connection: connection)
                        } label: { row(connection) }
                        .focused($focused, equals: connection.id)
                    }
                }
                .listStyle(.grouped)
                .onChange(of: opened) { previous, current in
                    guard Self.isReturning(previous: previous, current: current), let anchor else { return }
                    self.anchor = nil
                    switch Self.focusTarget(anchor, in: Self.rows(state.connections, kind: kind)) {
                    case .row(let id): focused = id
                    case .empty: focused = nil
                    }
                }
                 
                 
                .safeAreaPadding(.horizontal, 24)
                .safeAreaPadding(.vertical, 20)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var filters: some View {
        List {
            Section("Live") {
                ForEach(Filter.allCases, id: \.self) { candidate in
                    let count = Self.rows(state.connections, kind: candidate).count
                    Button {
                        kind = candidate
                    } label: {
                        LabeledContent(candidate.title) {
                            Text(count.formatted()).monospacedDigit()
                        }
                    }
                    .onHakoTVFocus { kind = candidate }
                    .accessibilityIdentifier("tvos.connections.kind.\(candidate.identifier)")
                }
            }
        }
        .listStyle(.grouped)
        .safeAreaPadding(.horizontal, 44)
    }

    private func row(_ connection: HakoActivityConnectionSnapshot) -> some View {
        let rejected = Self.kind(of: connection) == .rejected
        return HStack(spacing: 20) {
            Text(connection.rule.isEmpty ? "—" : connection.rule)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(minWidth: 180, alignment: .leading)
            Text(connection.destination)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 20)
            Text(Self.trailing(for: connection))
                .font(.body)
                .foregroundStyle(rejected ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .lineLimit(1)
        }
    }

     

     
     
    enum FocusTarget: Equatable {
        case row(HakoActivityConnectionSnapshot.ID)
         
         
         
        case empty
    }

     
     
     
     
     
     
     
    struct FocusAnchor: Equatable {
        let id: HakoActivityConnectionSnapshot.ID
         
         
         
        let next: HakoActivityConnectionSnapshot.ID?
        let previous: HakoActivityConnectionSnapshot.ID?
    }

     
     
     
     
    static func isReturning(previous: Door?, current: Door?) -> Bool {
        previous != nil && current == nil
    }

    static func anchor(for id: HakoActivityConnectionSnapshot.ID, in rows: [HakoActivityConnectionSnapshot]) -> FocusAnchor {
        guard let index = rows.firstIndex(where: { $0.id == id }) else {
            return FocusAnchor(id: id, next: nil, previous: nil)
        }
        return FocusAnchor(
            id: id,
            next: index + 1 < rows.count ? rows[index + 1].id : nil,
            previous: index > 0 ? rows[index - 1].id : nil
        )
    }

     
     
     
     
    static func focusTarget(_ anchor: FocusAnchor, in rows: [HakoActivityConnectionSnapshot]) -> FocusTarget {
        let present = Set(rows.map(\.id))
        for candidate in [anchor.id, anchor.next, anchor.previous].compactMap({ $0 }) where present.contains(candidate) {
            return .row(candidate)
        }
        guard let first = rows.first else { return .empty }
        return .row(first.id)
    }

     
     
     
     
    static func kind(of connection: HakoActivityConnectionSnapshot) -> Filter {
        switch connection.chains.first {
        case "REJECT", "REJECT-DROP": .rejected
        case "DIRECT": .direct
        default: .proxied
        }
    }

     
     
     
    static func rows(_ connections: [HakoActivityConnectionSnapshot], kind: Filter) -> [HakoActivityConnectionSnapshot] {
        let sorted = HakoActivityProjection.connections(connections, query: "", sort: .recent, limit: nil)
        guard kind != .all else { return sorted }
        return sorted.filter { Self.kind(of: $0) == kind }
    }

     
     
     
    static func trailing(for connection: HakoActivityConnectionSnapshot) -> String {
        if kind(of: connection) == .rejected { return "REJECT" }
        let target = connection.chains.last ?? connection.route
        return "\(target) · \(bytes(connection.total))"
    }

     
     
     
     
     
     
     
    static func vacancy(connections: [HakoActivityConnectionSnapshot], kind: Filter, isConnected: Bool) -> String? {
        guard rows(connections, kind: kind).isEmpty else { return nil }
        guard isConnected else { return String(localized: "The tunnel is not running") }
        guard !connections.isEmpty else { return String(localized: "Nothing is going through the tunnel yet") }
        return String(localized: "No \(kind.title) connections")
    }

    static func header(count: Int) -> String {
        count == 1
            ? String(localized: "1 connection · newest first")
            : String(localized: "\(count.formatted()) connections · newest first")
    }

     
    static func bytes(_ count: Int64) -> String {
        HakoTVBytes.text(count)
    }

     
     
     
     
     
     
     
     
     
    static func liveTick(_ state: inout HakoTVProductState, at date: Date) {
        state.connections = state.connections.enumerated().map { position, row in
            HakoActivityConnectionSnapshot(
                id: row.id,
                destination: row.destination,
                source: row.source,
                network: row.network,
                route: row.route,
                rule: row.rule,
                 
                 
                 
                 
                 
                upload: row.upload + 64 * 1_024,
                download: row.download + Int64(512 * 1_024 + position * 8_192),
                start: row.start,
                dnsMode: row.dnsMode,
                chains: row.chains,
                rulePayload: row.rulePayload
            )
        }
        let index = state.connections.count
        let hosts = ["cdn.example.tv", "static.example.app", "video.example.net", "push.apple.com"]
        let host = hosts[index % hosts.count]
        let direct = host.hasSuffix("apple.com")
        state.connections.insert(
            HakoActivityConnectionSnapshot(
                id: "live-\(index)-\(Int(date.timeIntervalSince1970))",
                destination: "\(host):443",
                source: "192.168.1.20:\(52_000 + index)",
                network: "TCP",
                route: direct ? "DIRECT" : "Hong Kong 04 → Hong Kong → Node selection",
                rule: direct ? "GeoSite" : "DomainSuffix",
                upload: 1_024,
                download: Int64(4_096 + index * 512),
                start: date,
                chains: direct ? ["DIRECT"] : ["Hong Kong 04", "Hong Kong", "Node selection"],
                rulePayload: direct ? "apple" : host
            ),
            at: 0
        )
        state.connectionCount = state.connections.count
    }
}
