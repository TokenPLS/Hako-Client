import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 

 

 
public struct HakoWidgetSlots {
     
    public var power: AnyView
     
     
    public var mode: (HakoWidgetMode, AnyView) -> AnyView
     
    public var member: (String, AnyView) -> AnyView
     
     
    public var accent: (AnyView) -> AnyView
     
     
     
    public var needsSetup: Bool

    public init(
        power: AnyView,
        mode: @escaping (HakoWidgetMode, AnyView) -> AnyView,
        member: @escaping (String, AnyView) -> AnyView,
        accent: @escaping (AnyView) -> AnyView = { $0 },
        needsSetup: Bool = false
    ) {
        self.power = power
        self.mode = mode
        self.member = member
        self.accent = accent
        self.needsSetup = needsSetup
    }
}

 
public enum HakoWidgetSize {
    case small
    case medium
    case large
}

 

 
public struct HakoWidgetMainModel: Equatable {
    public let title: String
    public let node: String?
    public let phase: HakoWidgetPhase
    public let mode: HakoWidgetMode?
     
    public let since: Date?
     
    public let updatedAt: Date?
    public let down: String
    public let up: String
    public let connections: String

    public init(snapshot: HakoWidgetSnapshot?, facts: HakoWidgetAppFacts?, now: Date, locale: Locale) {
        let fresh = snapshot.flatMap { $0.isFresh(now: now) ? $0 : nil }
        title = snapshot?.profile ?? facts?.profile ?? HakoCopy.string("No Profile", locale: locale)
        phase = fresh?.phase ?? .disconnected
        let connected = fresh?.phase == .connected
        node = connected ? fresh?.egress : nil
        mode = connected ? fresh?.mode : nil
        since = connected ? fresh?.startedAt : nil
        updatedAt = fresh?.at
         
         
         
        down = HakoWidgetFormat.rate(fresh?.downRate)
        up = HakoWidgetFormat.rate(fresh?.upRate)
        connections = HakoWidgetFormat.count(fresh?.connections?.opened, locale: locale)
    }

     
    public static func hintKey(needsSetup: Bool) -> String {
        needsSetup ? "Open Clash to finish setting up the VPN." : "Tap the power button to connect."
    }

     
    public var statusKey: String {
        switch phase {
        case .connected: return "Connected"
        case .connecting, .reasserting: return "Connecting…"
        case .disconnecting: return "Disconnecting…"
        case .disconnected: return "Not Connected"
        }
    }
}

 
public struct HakoWidgetGroupModel: Equatable {
    public static let rowLimit = 4
    public static let wideRowLimit = 8
    public static let largeRowLimit = 12
     
     
    public static let maxMembers = HakoWidgetMailbox.groupMemberLimit

    public let header: String
    public let rows: [String]
    public let current: String?

    public init(snapshot: HakoWidgetSnapshot?, facts: HakoWidgetAppFacts?, group: String?, now: Date, rowLimit: Int = HakoWidgetGroupModel.rowLimit) {
        let wanted = group ?? facts?.firstGroup ?? snapshot?.group?.name ?? ""
        header = wanted
        let fresh = snapshot.flatMap { $0.isFresh(now: now) ? $0 : nil }
        if let slice = fresh?.group, slice.name == wanted {
            rows = Array(slice.all.prefix(rowLimit))
            current = slice.now
        } else if let members = facts?.members[wanted] {
             
             
            rows = Array(members.prefix(rowLimit))
            current = facts?.selections[wanted]
        } else {
            rows = []
            current = nil
        }
    }
}

 
public struct HakoWidgetStatsModel: Equatable {
    public struct Cell: Equatable {
        public let key: String
        public let symbol: String
        public let value: String
    }

    public let cells: [Cell]
    public let updatedAt: Date?
     
     
    public let hasData: Bool

    private func value(_ key: String) -> String { cells.first { $0.key == key }?.value ?? HakoWidgetFormat.unknown }
    public var wifi: String { value("Wi-Fi") }
    public var cellular: String { cells.first { $0.key == "Cellular" || $0.key == "Wired" }?.value ?? HakoWidgetFormat.unknown }
    public var proxy: String { value("Proxy") }
    public var direct: String { value("Direct") }
    public var reject: String { value("Rejected") }

    public init(snapshot: HakoWidgetSnapshot?, now: Date, locale: Locale, extended: Bool = false) {
        let fresh = snapshot.flatMap { $0.isFresh(now: now) ? $0 : nil }
        let sum: (HakoWidgetBytes?) -> Int64? = { $0.map { $0.up + $0.down } }
         
         
         
        let totals: [Cell] = extended ? [
            Cell(key: "Download", symbol: "arrow.down", value: HakoWidgetFormat.rate(fresh?.downRate)),
            Cell(key: "Upload", symbol: "arrow.up", value: HakoWidgetFormat.rate(fresh?.upRate)),
        ] : []
         
         
         
        let second: Cell = fresh?.cellular == nil && fresh?.wired != nil
            ? Cell(key: "Wired", symbol: "cable.connector", value: HakoWidgetFormat.bytes(sum(fresh?.wired)))
            : Cell(key: "Cellular", symbol: "cellularbars", value: HakoWidgetFormat.bytes(sum(fresh?.cellular)))
        cells = totals + [
            Cell(key: "Wi-Fi", symbol: "wifi", value: HakoWidgetFormat.bytes(sum(fresh?.wifi))),
            second,
            Cell(key: "Proxy", symbol: "arrow.triangle.branch", value: HakoWidgetFormat.bytes(sum(fresh?.proxy))),
            Cell(key: "Direct", symbol: "arrow.right", value: HakoWidgetFormat.bytes(sum(fresh?.direct))),
            Cell(key: "Rejected", symbol: "nosign", value: HakoWidgetFormat.count(fresh?.rejectCount, locale: locale)),
            Cell(key: "Connections", symbol: "link",
                 value: HakoWidgetFormat.count(fresh?.connections?.opened, locale: locale)),
        ]
        updatedAt = fresh?.at
        hasData = fresh?.phase == .connected
    }
}

 

 
 
private struct HakoWidgetPlaceholder: View {
    let symbol: String
    let key: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(hako: .copy(key))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

 
 
 
private struct HakoWidgetFreshness: View {
    let at: Date?

    var body: some View {
        if let at {
            HStack(spacing: 3) {
                Image(systemName: "clock")
                Text(at, style: .time)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
    }
}

private struct HakoWidgetStatusLine: View {
    let model: HakoWidgetMainModel
    let slots: HakoWidgetSlots

    var body: some View {
        HStack(spacing: 6) {
            slots.accent(AnyView(
                Circle()
                    .fill(model.phase == .connected ? Color.green : Color.secondary.opacity(0.5))
                    .frame(width: 8, height: 8)
            ))
            Text(hako: .copy(model.statusKey))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }
}

 
private struct HakoWidgetModeRow: View {
    let current: HakoWidgetMode?
    let slots: HakoWidgetSlots

    var body: some View {
        HStack(spacing: 6) {
            ForEach(HakoWidgetMode.allCases, id: \.rawValue) { mode in
                let isCurrent = mode == current
                slots.mode(mode, AnyView(
                    Text(hako: .copy(HakoWidgetFormat.modeKey(mode)))
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 12)
                        .background(
                            slots.accent(AnyView(
                                 
                                Capsule().fill(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear))
                            ))
                        )
                        .overlay(
                            Capsule().strokeBorder(Color.secondary.opacity(isCurrent ? 0 : 0.35), lineWidth: 1)
                        )
                        .foregroundStyle(isCurrent ? Color.white : Color.primary)
                ))
            }
        }
    }
}

private struct HakoWidgetStatCell: View {
    let cell: HakoWidgetStatsModel.Cell
     
     
     
     
    var large = false

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 2 : 1) {
            HStack(spacing: 4) {
                Image(systemName: cell.symbol)
                Text(hako: .copy(cell.key))
            }
            .font(large ? .caption : .caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            Text(hako: .verbatim(cell.value))
                .font((large ? Font.title3 : Font.subheadline).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(hako: .copy(cell.key)))
        .accessibilityValue(Text(hako: .verbatim(cell.value)))
    }
}

 

public struct HakoWidgetMainView: View {
    private let model: HakoWidgetMainModel
    private let stats: HakoWidgetStatsModel
    private let size: HakoWidgetSize
    private let slots: HakoWidgetSlots

    public init(snapshot: HakoWidgetSnapshot?, facts: HakoWidgetAppFacts?, now: Date, locale: Locale, size: HakoWidgetSize, slots: HakoWidgetSlots) {
        model = HakoWidgetMainModel(snapshot: snapshot, facts: facts, now: now, locale: locale)
        stats = HakoWidgetStatsModel(snapshot: snapshot, now: now, locale: locale, extended: true)
        self.size = size
        self.slots = slots
    }

    public var body: some View {
        switch size {
        case .small: small
        case .medium: medium
        case .large: large
        }
    }

     
     
     
     
    private var large: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HakoWidgetStatusLine(model: model, slots: slots)
                    identity
                }
                Spacer(minLength: 8)
                slots.power
            }
            if model.phase == .connected {
                HStack(alignment: .center) {
                    HakoWidgetModeRow(current: model.mode, slots: slots)
                    Spacer(minLength: 8)
                    HakoWidgetFreshness(at: model.updatedAt)
                }
                 
                 
                 
                 
                VStack(spacing: 0) {
                    ForEach(Array(stride(from: 0, to: stats.cells.count, by: 2)), id: \.self) { start in
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(stats.cells[start..<min(start + 2, stats.cells.count)], id: \.key) { cell in
                                HakoWidgetStatCell(cell: cell, large: true)
                            }
                        }
                         
                         
                         
                         
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
            } else {
                HakoWidgetPlaceholder(symbol: "power", key: HakoWidgetMainModel.hintKey(needsSetup: slots.needsSetup))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            HakoRegionalFlag.label(model.title, pointSize: 17, relativeTo: .headline)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
            if let node = model.node {
                HakoRegionalFlag.label(node, pointSize: 15, relativeTo: .subheadline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if let since = model.since {
                HStack(spacing: 4) {
                    if let mode = model.mode {
                        Text(hako: .copy(HakoWidgetFormat.modeKey(mode)))
                        Text(hako: .verbatim("·"))
                    }
                     
                    if #available(iOS 16.0, *) {
                        Text(timerInterval: since ... Date.distantFuture, countsDown: false)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
        }
    }

    private var hint: some View {
        Text(hako: .copy(HakoWidgetMainModel.hintKey(needsSetup: slots.needsSetup)))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HakoWidgetStatusLine(model: model, slots: slots)
            identity
            if model.phase != .connected { hint }
            Spacer(minLength: 0)
            HStack {
                HakoWidgetFreshness(at: model.updatedAt)
                Spacer()
                slots.power
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HakoWidgetStatusLine(model: model, slots: slots)
                    identity
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 6) {
                    slots.power
                    if model.phase == .connected {
                        VStack(alignment: .trailing, spacing: 2) {
                            stat("arrow.down", model.down)
                            stat("arrow.up", model.up)
                            stat("link", model.connections)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .center) {
                if model.phase == .connected {
                    HakoWidgetModeRow(current: model.mode, slots: slots)
                } else {
                    hint
                }
                Spacer(minLength: 8)
                HakoWidgetFreshness(at: model.updatedAt)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func stat(_ symbol: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2).foregroundStyle(.secondary)
            Text(hako: .verbatim(value)).font(.caption).monospacedDigit()
        }
    }
}

 

public struct HakoWidgetGroupView: View {
    private let model: HakoWidgetGroupModel
    private let size: HakoWidgetSize
    private let slots: HakoWidgetSlots

    public init(snapshot: HakoWidgetSnapshot?, facts: HakoWidgetAppFacts?, group: String?, now: Date, size: HakoWidgetSize, slots: HakoWidgetSlots) {
        let limit: Int
        switch size {
        case .small: limit = HakoWidgetGroupModel.rowLimit
        case .medium: limit = HakoWidgetGroupModel.wideRowLimit
        case .large: limit = HakoWidgetGroupModel.largeRowLimit
        }
        model = HakoWidgetGroupModel(snapshot: snapshot, facts: facts, group: group, now: now, rowLimit: limit)
        self.size = size
        self.slots = slots
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "network")
                HakoRegionalFlag.label(model.header, pointSize: 12, relativeTo: .caption)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            if model.rows.isEmpty {
                HakoWidgetPlaceholder(symbol: "network", key: "Connect to see the nodes.")
            } else if size == .medium, model.rows.count > HakoWidgetGroupModel.rowLimit {
                HStack(alignment: .top, spacing: 12) {
                    column(Array(model.rows.prefix(HakoWidgetGroupModel.rowLimit)))
                    column(Array(model.rows.dropFirst(HakoWidgetGroupModel.rowLimit)))
                }
            } else {
                column(model.rows)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func column(_ rows: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.self) { name in
                slots.member(name, AnyView(row(name)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ name: String) -> some View {
        HStack(spacing: 6) {
            HakoRegionalFlag.label(name, pointSize: 15, relativeTo: .subheadline)
                .font(.subheadline)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if name == model.current {
                slots.accent(AnyView(
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)
                ))
            }
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }
}

 

public struct HakoWidgetStatsView: View {
    private let model: HakoWidgetStatsModel
    private let size: HakoWidgetSize

    public init(snapshot: HakoWidgetSnapshot?, now: Date, locale: Locale, size: HakoWidgetSize) {
        model = HakoWidgetStatsModel(snapshot: snapshot, now: now, locale: locale, extended: size == .large)
        self.size = size
    }

    public var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: size == .medium ? 3 : 2)
        VStack(alignment: .leading, spacing: 8) {
            if model.hasData {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(model.cells, id: \.key) { cell in
                        HakoWidgetStatCell(cell: cell)
                    }
                }
                Spacer(minLength: 0)
                HakoWidgetFreshness(at: model.updatedAt)
            } else {
                HakoWidgetPlaceholder(symbol: "chart.bar.xaxis", key: "Connect to see traffic.")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
