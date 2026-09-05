import SwiftUI
import HakoClientUI

 
 
 
 
 
 
 
struct MemoryBillSection: View {
    struct Line: Equatable, Identifiable {
        enum Detail: Equatable {
            case none
             
            case manage
             
            case breakdown
             
            case unprobed
        }

        let id: String
        let name: HakoDisplayText
        let count: Int?
        let bytes: Int64
        let detail: Detail
    }

    let lines: [Line]
    var onOpen: (String) -> Void = { _ in }

    var body: some View {
        Section {
            ForEach(lines) { line in
                row(line)
            }
        } header: {
            Text("Memory Went To")
        } footer: {
             
             
             
             
             
            if lines.contains(where: { $0.id == "geo" }) {
                Text(hako: .copy("GEO Rules shows the compiled artifacts' size on disk — a trim price tag; their memory is already inside Config Parse."))
            }
        }
    }

    @ViewBuilder
    private func row(_ line: Line) -> some View {
        HStack(spacing: HakoTheme.Spacing.compact) {
            Text(hako: line.name)
            if let count = line.count {
                Text(hako: .verbatim("· \(count)"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if line.detail == .unprobed {
                Text("Awaiting core probes")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(.tertiary)
                    )
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Text(hako: .verbatim(HakoStartupExplanation.megabytes(line.bytes)))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            switch line.detail {
            case .manage, .breakdown:
                Image(systemName: HakoSymbol.chevronForward.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            case .none, .unprobed:
                EmptyView()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard line.detail == .manage || line.detail == .breakdown
            else { return }
            onOpen(line.id)
        }
        .accessibilityIdentifier("memory.bill.row.\(line.id)")
    }
}

extension MemoryBillSection {
     
     
     
     
     
    static func lines(
        ledger: HakoMemoryLedger,
        pressureFootprintBytes: Int64?,
        ruleSetCensusCount: Int? = nil,
        ruleSetCensusBytes: Int64? = nil,
        dnsCensusCount: Int? = nil,
        providerCensusCount: Int? = nil,
        geoCensusCount: Int? = nil,
        geoCensusBytes: Int64? = nil
    ) -> [Line] {
        guard let first = ledger.rows.first else { return [] }
        var out: [Line] = [
             
             
             
            Line(id: "runtime", name: .copy("Core Runtime"), count: nil,
                 bytes: first.footprintBytes, detail: .none),
        ]
        var parse: Int64 = 0
        var dns: Int64 = 0
        var ruleSets: (bytes: Int64, count: Int) = (0, 0)
        var providers: Int64 = 0
        var post: Int64 = 0
         
         
         
        var reclaimed: Int64 = 0
        for row in ledger.rows.dropFirst() {
            guard row.deltaBytes >= 0 else {
                reclaimed += row.deltaBytes
                if row.name.hasPrefix("apply:rule-provider:") {
                    ruleSets.count += 1
                }
                continue
            }
            switch true {
            case row.name == "parse:dns":
                dns += row.deltaBytes
            case row.name.hasPrefix("apply:rule-provider:"):
                 
                 
                 
                 
                 
                 
                 
                 
                 
                ruleSets.bytes += row.peakSpendBytes
                ruleSets.count += 1
             
             
             
             
             
             
             
            case row.name.hasPrefix("apply:rule-provider-begin:"):
                ruleSets.bytes += row.deltaBytes
            case row.name.hasPrefix("apply:proxy-provider")
                || row.name == "apply:proxy-providers-loaded":
                providers += row.deltaBytes
            case row.name.hasPrefix("parse:") || row.name.hasPrefix("bind:")
                || row.name == "config-parsed"
                || row.name == "config-finalized":
                parse += row.deltaBytes
            default:
                post += row.deltaBytes
            }
        }
        if parse > 0 {
            out.append(Line(id: "parse", name: .copy("Config Parse"),
                            count: nil, bytes: parse, detail: .none))
        }
        if dns > 0 {
            out.append(Line(id: "dns", name: .copy("DNS Routing Rules"),
                            count: dnsCensusCount, bytes: dns,
                            detail: .manage))
        }
        if ruleSets.bytes > 0 || (ruleSetCensusBytes ?? 0) > 0 {
             
             
             
             
             
             
             
             
             
             
             
            let censusBytes = ruleSetCensusBytes ?? 0
            out.append(Line(id: "rule-sets", name: .copy("Rule Sets"),
                            count: ruleSetCensusCount ?? ruleSets.count,
                            bytes: censusBytes > 0 ? censusBytes : ruleSets.bytes,
                            detail: .manage))
        }
        if let geoCount = geoCensusCount, geoCount > 0 {
             
             
            out.append(Line(id: "geo", name: .copy("GEO Rules"),
                            count: geoCount, bytes: geoCensusBytes ?? 0,
                            detail: .manage))
        }
        if providers > 0 {
             
             
            out.append(Line(id: "providers", name: .copy("Provider Load"),
                            count: providerCensusCount, bytes: providers,
                            detail: .breakdown))
        }
        if post > 0 {
            out.append(Line(id: "post", name: .copy("After Start"),
                            count: nil, bytes: post, detail: .none))
        }
         
         
         
         
        _ = reclaimed
        if let pressure = pressureFootprintBytes,
           let rawGap = ledger.unprobedRemainder(
               pressureFootprintBytes: pressure
           )
        {
             
             
             
             
             
             
             
             
             
             
             
            let alreadyPriced = max(0, (ruleSetCensusBytes ?? 0) - ruleSets.bytes)
            let gap = max(0, rawGap - alreadyPriced)
            guard gap > 0 else { return out }
             
             
             
             
             
             
             
             
            let last = ledger.rows.last?.name
             
             
             
             
             
            let inFlight = ["apply:rule-provider-begin:",
                            "apply:proxy-provider-begin:"]
                .lazy
                .compactMap { last?.hasPrefix($0) == true
                    ? String(last!.dropFirst($0.count)) : nil }
                .first
             
             
             
             
             
             
            let endedInRuleSets = last == "apply:profile"
                || last?.hasPrefix("apply:rule-provider:") == true
            out.append(Line(
                id: "unprobed",
                name: inFlight.map {
                    .format("Loading “%@” When It Stopped", [$0])
                } ?? (endedInRuleSets
                      ? .copy("Rule Sets, Not Yet Itemised")
                      : .copy("Unprobed")),
                count: nil, bytes: gap, detail: .unprobed
            ))
        }
        return out
    }
}
