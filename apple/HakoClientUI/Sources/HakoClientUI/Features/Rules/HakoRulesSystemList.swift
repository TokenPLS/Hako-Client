import SwiftUI

 
 
 
 
 
 
 

 
struct HakoRuleBucketFrozenRow: Equatable, Hashable, Identifiable {
    let target: String
    let count: Int
    var id: String { target }
}

 
struct HakoRuleFrozenRow: Equatable, Hashable, Identifiable {
    let raw: String
    let type: String
    let payload: String
    let target: String
    var id: String { raw }

    init(_ rule: HakoRuleLineSnapshot) {
        raw = rule.raw
        type = rule.type
        payload = rule.payload
        target = rule.target
    }
}

 
 
 
struct HakoRulesSystemOverview<Icon: View>: View {
    let overview: HakoRulesOverviewSnapshot
    let query: String
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon
    let activeRulesEntry: AnyView

     
     
     
     
    @State private var searchHits: [HakoRuleFrozenRow] = []
    @State private var searchHitCount = 0
    @State private var searchedQuery = ""

    var body: some View {
        let _ = HakoPerf.count("rules.list.body")
        return List {
            if query.isEmpty {
                overviewSections
            } else {
                searchSection
            }
            Section {
                activeRulesEntry
            }
        }
        .task(id: query) {
            let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                searchHits = []; searchHitCount = 0; searchedQuery = ""
                return
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            let raws = overview.searchableRules.map(\.raw)
            let indices = await Task.detached(priority: .userInitiated) { () -> [Int] in
                var out: [Int] = []
                for (i, raw) in raws.enumerated() where raw.localizedCaseInsensitiveContains(normalized) {
                    out.append(i)
                }
                return out
            }.value
            if Task.isCancelled { return }
             
             
             
             
            searchHitCount = indices.count
            searchHits = indices.prefix(50).map { HakoRuleFrozenRow(overview.searchableRules[$0]) }
            searchedQuery = normalized
        }
    }

    @ViewBuilder
    private var overviewSections: some View {
        if !overview.buckets.isEmpty {
            Section {
                ForEach(overview.buckets.map { HakoRuleBucketFrozenRow(target: $0.target, count: $0.rules.count) }) { row in
                    HakoRuleBucketListRow(row: row)
                        .equatable()
                }
            } header: {
                Text(hako: .format("Subscription Rules (%@)", [String(overview.inlineCount)]))
            } footer: {
                Text("Grouped by destination. Updates from the subscription replace these rules.")
            }
        }
        if !overview.ruleSets.isEmpty {
            Section {
                ForEach(overview.ruleSets) { ruleSet in
                    HakoRuleSetListRow(ruleSet: ruleSet)
                }
            } header: {
                Text(hako: .format("Rule Sets (%@)", [String(overview.ruleSets.count)]))
            }
        }
        if !overview.fallback.isEmpty {
            Section {
                ForEach(overview.fallback.map(HakoRuleFrozenRow.init)) { row in
                    HakoRuleListRow(row: row, palette: palette)
                        .equatable()
                }
            } header: {
                Text("Fallback")
            } footer: {
                Text("Traffic that matches nothing above.")
            }
        }
        if overview.buckets.isEmpty && overview.ruleSets.isEmpty && overview.fallback.isEmpty {
            Section {
                HakoEmptyState(
                    title: "No Rules",
                    message: "This profile does not declare routing rules or rule providers."
                ) {
                    icon(.listBulletRectangle)
                }
            }
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        Section {
            if searchedQuery.isEmpty && searchHits.isEmpty {
                 
                ProgressView()
                    .controlSize(.small)
            } else if searchHits.isEmpty {
                Text("No matching rules")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(searchHits) { row in
                    HakoRuleListRow(row: row, palette: palette)
                        .equatable()
                }
                if searchHitCount > 50 {
                    Text("\(searchHitCount - 50) more matches…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(hako: .format("%@ matches", [String(searchHitCount)]))
        }
    }
}

 
 
struct HakoRuleBucketListRow: View, Equatable {
    let row: HakoRuleBucketFrozenRow

    var body: some View {
        let _ = HakoPerf.count("rules.list.bucket")
        return Group {
            if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
                NavigationLink(value: HakoRuleBucketRoute(target: row.target)) {
                    label
                }
            } else {
                label
            }
        }
        .accessibilityLabel("\(row.count) rules to \(row.target)")
        .accessibilityIdentifier("rules.bucket.\(row.target)")
    }

    private var label: some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            Text(row.target)
                .font(.body.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("\(row.count)")
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

 
 
struct HakoRuleListRow: View, Equatable {
    nonisolated static func == (a: Self, b: Self) -> Bool { a.row == b.row }

    let row: HakoRuleFrozenRow
    let palette: HakoProductPalette

    var body: some View {
        let _ = HakoPerf.count("rules.list.row")
        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.payload.isEmpty ? row.type : row.payload)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if HakoRuleRowLayout.showsTypeLine(payload: row.payload) {
                    Text(row.type)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(row.target)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(palette.raisedFill))
        }
    }
}

 
 
struct HakoRuleSetListRow: View {
    let ruleSet: HakoRuleSetSnapshot
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HakoRegionalFlag.label(ruleSet.name, pointSize: 17, relativeTo: .body)
                .font(.body.weight(.semibold))
            Text(hako: .verbatim(ruleSet.subtitle(locale: locale)))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let reason = ruleSet.blockedReason {
                Text(hako: .copy("Not in the runtime"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("rules.rule-set.blocked.\(ruleSet.name)")
                Text(hako: .verbatim(reason))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

 
 
struct HakoRuleBucketSystemPage: View {
    let bucket: HakoRuleBucketSnapshot
    let jumpCard: AnyView?
    let palette: HakoProductPalette
    @Environment(\.locale) private var locale

    static var renderedRowCap: Int { HakoRuleBucketLazyPage.renderedRowCap }

    var body: some View {
        let _ = HakoPerf.count("rules.list.bucket-page")
        let rows = Array(bucket.rules.prefix(Self.renderedRowCap)).map(HakoRuleFrozenRow.init)
        return List {
            if let jumpCard {
                Section { jumpCard }
            }
            Section {
                ForEach(rows) { row in
                    HakoRuleListRow(row: row, palette: palette)
                        .equatable()
                }
            } header: {
                Text(hako: .verbatim(HakoCopy.format("%d rules", locale: locale, bucket.rules.count)))
            }
        }
    }
}
