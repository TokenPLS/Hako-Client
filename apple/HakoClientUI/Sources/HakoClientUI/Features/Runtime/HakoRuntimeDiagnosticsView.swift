import Foundation
import SwiftUI

public struct HakoRuntimeRule:
    Codable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    public let type: String
    public let payload: String
    public let target: String
    public let size: Int?

    public init(
        type: String,
        payload: String,
        target: String,
        size: Int? = nil
    ) {
        self.type = type
        self.payload = payload
        self.target = target
        self.size = size
    }

    public var id: String {
        "\(type)|\(payload)|\(target)|\(size.map(String.init) ?? "")"
    }

    public var sizeText: String? {
        guard let size, size >= 0 else { return nil }
        return "\(size)"
    }

    public func matches(_ query: String) -> Bool {
        let needle = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !needle.isEmpty else { return true }
        return type.lowercased().contains(needle)
            || payload.lowercased().contains(needle)
            || target.lowercased().contains(needle)
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
        case target = "proxy"
        case size
    }
}

public enum HakoRuntimeRulesPayload {
    public static let maximumDocumentBytes = 4 * 1_024 * 1_024
    public static let maximumRuleCount = 4_096

    public static func decode(_ data: Data?) -> [HakoRuntimeRule] {
        guard let data,
              !data.isEmpty,
              data.count <= maximumDocumentBytes,
              let payload = try? JSONDecoder().decode(
                Payload.self,
                from: data
              )
        else {
            return []
        }
        return Array(payload.rules.prefix(maximumRuleCount))
    }

    private struct Payload: Decodable {
        let rules: [HakoRuntimeRule]
    }
}

public struct HakoActiveRulesView: View {
    private let rules: [HakoRuntimeRule]
    private let isConnected: Bool
    private let isRefreshing: Bool
    private let refresh: @MainActor () async -> Void

    @State private var query = ""

    public init(
        rules: [HakoRuntimeRule],
        isConnected: Bool,
        isRefreshing: Bool = false,
        refresh: @escaping @MainActor () async -> Void
    ) {
        self.rules = Array(
            rules.prefix(HakoRuntimeRulesPayload.maximumRuleCount)
        )
        self.isConnected = isConnected
        self.isRefreshing = isRefreshing
        self.refresh = refresh
    }

    public var body: some View {
        List {
            if rules.isEmpty {
                Section {
                    HStack(spacing: HakoTheme.Spacing.row) {
                        Image(
                            systemName: HakoSymbol
                                .exclamationmarkTriangleFill
                                .rawValue
                        )
                        .foregroundStyle(.secondary)

                        Text(hako: .copy(emptyMessage))
                            .foregroundStyle(.secondary)

                        if isRefreshing {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            } else {
                Section {
                    HStack {
                        Text("Rules")
                        Spacer()
                        Text("\(filteredRules.count) / \(rules.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Section {
                    ForEach(
                        Array(filteredRules.enumerated()),
                        id: \.offset
                    ) { _, rule in
                        VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                            HStack {
                                Text(rule.type)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(rule.target)
                                    .font(.caption.weight(.semibold))
                            }

                            Text(rule.payload.isEmpty ? "—" : rule.payload)
                                .font(.callout)
                                .hakoTextSelectionEnabled()

                            if let sizeText = rule.sizeText {
                                Text("Matched entries: \(sizeText)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search active rules")
        .hakoPageTitle("Active Rules")
        .task {
            await refresh()
        }
        .refreshable {
            await refresh()
        }
        .accessibilityIdentifier("runtime.active-rules.list")
    }

    private var filteredRules: [HakoRuntimeRule] {
        rules.filter { $0.matches(query) }
    }

    private var emptyMessage: String {
        if isConnected {
            "No active rules were returned. Pull to refresh."
        } else {
            "Connect Clash, then pull to refresh."
        }
    }
}

public struct HakoDNSQueryAnswer:
    Codable,
    Equatable,
    Hashable,
    Identifiable,
    Sendable
{
    public let name: String?
    public let type: Int?
    public let ttl: Int?
    public let data: String?

    public init(
        name: String?,
        type: Int?,
        ttl: Int?,
        data: String?
    ) {
        self.name = name
        self.type = type
        self.ttl = ttl
        self.data = data
    }

    public var id: String {
        "\(name ?? "")|\(type ?? 0)|\(data ?? "")|\(ttl ?? 0)"
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case ttl = "TTL"
        case data
    }
}

public struct HakoDNSQueryResult: Equatable, Sendable {
    public static let maximumRawResponseBytes = 128 * 1_024
    public static let maximumAnswerCount = 128

    public let answers: [HakoDNSQueryAnswer]
    public let rawResponse: String?
    public let errorMessage: String?

    public init(
        rawResponse: String?,
        errorMessage: String?
    ) {
        let boundedRawResponse = rawResponse.flatMap { value in
            value.utf8.count <= Self.maximumRawResponseBytes
                ? value
                : nil
        }
        self.rawResponse = boundedRawResponse
        self.errorMessage =
            errorMessage
            ?? (
                rawResponse != nil && boundedRawResponse == nil
                    ? "The DNS response exceeded the safe display limit."
                    : nil
            )
        self.answers = Self.decodeAnswers(boundedRawResponse)
    }

    public init(
        answers: [HakoDNSQueryAnswer],
        rawResponse: String? = nil,
        errorMessage: String? = nil
    ) {
        self.answers = Array(answers.prefix(Self.maximumAnswerCount))
        self.rawResponse = rawResponse
        self.errorMessage = errorMessage
    }

    private static func decodeAnswers(
        _ rawResponse: String?
    ) -> [HakoDNSQueryAnswer] {
        guard let rawResponse,
              let data = rawResponse.data(using: .utf8),
              data.count <= maximumRawResponseBytes,
              let response = try? JSONDecoder().decode(
                Response.self,
                from: data
              )
        else {
            return []
        }
        return Array(
            (response.answer ?? []).prefix(maximumAnswerCount)
        )
    }

    private struct Response: Decodable {
        let answer: [HakoDNSQueryAnswer]?

        private enum CodingKeys: String, CodingKey {
            case answer = "Answer"
        }
    }
}

public enum HakoDNSCacheMaintenanceAction:
    String,
    CaseIterable,
    Codable,
    Identifiable,
    Sendable
{
    case dns
    case fakeIP

    public var id: Self { self }

    public var buttonTitle: String {
        switch self {
        case .dns:
            "Flush DNS Cache"
        case .fakeIP:
            "Flush Fake-IP Cache"
        }
    }

    public var confirmationTitle: String {
        switch self {
        case .dns:
            "Clear the DNS cache?"
        case .fakeIP:
            "Clear the Fake-IP cache?"
        }
    }

    public var successMessage: String {
        switch self {
        case .dns:
            "DNS cache cleared."
        case .fakeIP:
            "Fake-IP cache cleared."
        }
    }
}

 
 
 
 
 
 
 
public struct HakoDNSResolution: Equatable, Sendable {
     
     
     
     
     
     
     
     
    public enum AnswerSource: Equatable, Sendable {
         
         
         
        case systemResolver
         
        case core
    }

    public let result: HakoDNSQueryResult
    public let answerSource: AnswerSource
     
    public let explain: HakoDNSExplain?

    public init(
        result: HakoDNSQueryResult,
        answerSource: AnswerSource,
        explain: HakoDNSExplain? = nil
    ) {
        self.result = result
        self.answerSource = answerSource
        self.explain = explain
    }
}

public struct HakoDNSQueryCapabilities {
    public typealias Query = @MainActor (
        String,
        String
    ) async -> HakoDNSResolution
    public typealias Maintain = @MainActor (
        HakoDNSCacheMaintenanceAction
    ) async -> String?

    public static let recordTypes = [
        "A",
        "AAAA",
        "CNAME",
        "TXT",
        "MX",
        "NS",
        "SRV",
        "PTR",
    ]

     
     
     
     
     
     
     
     
     
     
    public typealias Explain = @MainActor (
        String,
        String
    ) async -> HakoDNSExplain?

    public let query: Query
    public let explain: Explain?
    public let maintain: Maintain

    public init(
        query: @escaping Query,
        explain: Explain? = nil,
        maintain: @escaping Maintain
    ) {
        self.query = query
        self.explain = explain
        self.maintain = maintain
    }
}

public struct HakoDNSQueryView: View {
    private let isConnected: Bool
    private let capabilities: HakoDNSQueryCapabilities

    @State private var name = ""
    @State private var type = "A"
    @State private var result: HakoDNSQueryResult?
    @State private var explain: HakoDNSExplain?
    @State private var answerSource: HakoDNSResolution.AnswerSource?
    @State private var isQuerying = false
    @State private var pendingMaintenance:
        HakoDNSCacheMaintenanceAction?
    @State private var isMaintainingCache = false
    @State private var maintenanceResult: String?

    public init(
        isConnected: Bool,
        capabilities: HakoDNSQueryCapabilities
    ) {
        self.isConnected = isConnected
        self.capabilities = capabilities
    }

    public var body: some View {
        List {
            Section {
                 
                 
                 
                 
                TextField(
                    "",
                    text: $name,
                    prompt: Text(verbatim: "example.com")
                )
                    .labelsHidden()
                    .hakoDNSNameEntryBehavior()
                    .accessibilityIdentifier(
                        "runtime.dns-query.name"
                    )

                Picker("Type", selection: $type) {
                    ForEach(
                        HakoDNSQueryCapabilities.recordTypes,
                        id: \.self
                    ) {
                        Text($0).tag($0)
                    }
                }
                    .accessibilityIdentifier("diagnostics.runtime.type")

                Button {
                    Task {
                        await runQuery()
                    }
                } label: {
                    HStack {
                        Label(
                            "Query",
                            systemImage: HakoSymbol
                                .globeAsiaAustralia
                                .rawValue
                        )
                        if isQuerying {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(
                    !isConnected
                        || normalizedName.isEmpty
                        || isQuerying
                )
                .accessibilityIdentifier(
                    "runtime.dns-query.run"
                )
            } footer: {
                Text(
                    "A and AAAA take the same path your traffic takes, so Local Mappings and Fake-IP appear here as they do in use. Other record types are asked of the core's resolvers, honoring nameserver-policy. Read-only."
                )
            }

             
             
             
             
             
            if let explain {
                explainSection(explain, answerSource: answerSource)
            }

            if let result {
                resultSections(result)
            }

            Section {
                ForEach(
                    HakoDNSCacheMaintenanceAction.allCases
                ) { action in
                    Button(role: .destructive) {
                        pendingMaintenance = action
                    } label: {
                        Label {
                            Text(hako: .copy(action.buttonTitle))
                        } icon: {
                            Image(systemName: HakoSymbol.trash.rawValue)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(.red)
                    }
                    .disabled(
                        !isConnected || isMaintainingCache
                    )
                    .accessibilityIdentifier(
                        action == .dns
                            ? "dns-query.cache.flush-dns"
                            : "dns-query.cache.flush-fakeip"
                    )
                }

                if isMaintainingCache {
                    HStack {
                        ProgressView()
                        Text("Clearing cache…")
                            .foregroundStyle(.secondary)
                    }
                } else if let maintenanceResult {
                    Text(hako: .copy(maintenanceResult))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            "dns-query.cache.result"
                        )
                }
            } header: {
                Text("DNS Cache Maintenance")
            } footer: {
                Text(
                    "Clear these caches only after DNS changes or when a stale answer persists. The tunnel stays connected."
                )
            }
        }
        .hakoRuntimeGroupedFormStyle()
        .hakoPageTitle("DNS Query")
        .confirmationDialog(
            pendingMaintenance?.confirmationTitle
                ?? "Clear DNS cache?",
            isPresented: Binding(
                get: { pendingMaintenance != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingMaintenance = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let pendingMaintenance {
                Button(role: .destructive) {
                    let action = pendingMaintenance
                    self.pendingMaintenance = nil
                    Task {
                        await performMaintenance(action)
                    }
                } label: {
                    Text(hako: .copy(pendingMaintenance.buttonTitle))
                }
                .accessibilityIdentifier(
                    "dns-query.cache.confirm"
                )
            }

            Button("Cancel", role: .cancel) {
                pendingMaintenance = nil
            }
            .accessibilityIdentifier(
                "dns-query.cache.cancel"
            )
        } message: {
            Text(
                "This removes cached answers from the running core. It does not disconnect the tunnel or change the profile."
            )
        }
        .accessibilityIdentifier("runtime.dns-query.form")
    }

    @ViewBuilder
    private func explainSection(
        _ explain: HakoDNSExplain,
        answerSource: HakoDNSResolution.AnswerSource?
    ) -> some View {
        Section {
            explainRow(
                "Rule",
                explain.reason,
                identifier: "runtime.dns-query.explain.reason"
            )

            if !explain.candidates.isEmpty {
                explainRow(
                    "Resolvers",
                     
                     
                    .verbatim(explain.candidates.joined(separator: "\n")),
                    monospaced: true,
                    identifier: "runtime.dns-query.explain.candidates"
                )
            }

            if let cache = explain.cacheSentence(durationText: Self.duration) {
                explainRow(
                    "Cache",
                    cache,
                    identifier: "runtime.dns-query.explain.cache"
                )
            }
        } header: {
            Text(hako: "Route")
        } footer: {
             
             
             
             
            if answerSource == .systemResolver {
                Text(
                    hako:
                        "A and AAAA are answered by the system resolver, so no single upstream can be credited for the address below."
                )
            }
        }
    }

     
     
     
     
     
     
    private func explainRow(
        _ title: HakoDisplayText,
        _ value: HakoDisplayText,
        monospaced: Bool = false,
        identifier: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            Text(hako: title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(hako: value)
                .font(monospaced ? .callout.monospaced() : .callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

     
     
     
     
     
     
     
     
     
     
     
    static func readableFailure(_ raw: String) -> HakoDisplayText {
        let lowered = raw.lowercased()
        if lowered.contains("deadline exceeded")
            || lowered.contains("timeout")
            || lowered.contains("timed out")
        {
            return .copy(
                "No resolver answered in time. The record type may not exist for this name, or the resolvers are unreachable right now."
            )
        }
        if lowered.contains("invalid query type") {
            return .copy("This core does not recognise that record type.")
        }
        if lowered.contains("dns is not running") {
            return .copy(
                "DNS is switched off in this configuration, so there is nothing to ask."
            )
        }
        if lowered.contains("no address was returned") {
            return .verbatim(raw)
        }
        return .copy("The query did not complete.")
    }

     
     
     
     
    static func duration(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = seconds >= 60 ? [.minute] : [.second]
        formatter.maximumUnitCount = 1
        return formatter.string(from: TimeInterval(max(seconds, 1)))
            ?? "\(seconds)"
    }

    @ViewBuilder
    private func resultSections(
        _ result: HakoDNSQueryResult
    ) -> some View {
        if let errorMessage = result.errorMessage,
           !errorMessage.isEmpty
        {
            Section("Query Error") {
                Text(hako: Self.readableFailure(errorMessage))
                    .foregroundStyle(.secondary)
                 
                 
                 
                Text(hako: .verbatim(errorMessage))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .hakoTextSelectionEnabled()
            }
        } else if !result.answers.isEmpty {
            Section("Answers") {
                ForEach(result.answers) { answer in
                    VStack(
                        alignment: .leading,
                        spacing: HakoTheme.Spacing.tight
                    ) {
                        Text(answer.data ?? "—")
                            .font(.callout.monospaced())
                            .hakoTextSelectionEnabled()
                        if let ttl = answer.ttl {
                            Text("TTL \(ttl)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                 
                 
                 
                if let attribution = explain?.attributionSentence {
                    Text(hako: attribution)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier(
                            "runtime.dns-query.answered-by"
                        )
                }
            }
        } else if let rawResponse = result.rawResponse {
            Section("Raw Response") {
                Text(rawResponse)
                    .font(.caption.monospaced())
                    .hakoTextSelectionEnabled()
            }
        }
    }

    private var normalizedName: String {
        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    private func runQuery() async {
        guard !normalizedName.isEmpty else { return }
        isQuerying = true
         
         
         
         
         
         
         
         
         
         
         
        defer { isQuerying = false }
         
         
        result = nil
        explain = nil
        answerSource = nil

         
         
         
         
         
        if let explainer = capabilities.explain {
            explain = await explainer(normalizedName, type)
        }

        let answer = await capabilities.query(normalizedName, type)
        result = answer.result
        answerSource = answer.answerSource

         
         
         
         
         
        if let produced = answer.explain {
            explain = produced
        }
    }

    private func performMaintenance(
        _ action: HakoDNSCacheMaintenanceAction
    ) async {
        isMaintainingCache = true
        maintenanceResult = nil
        let error = await capabilities.maintain(action)
        maintenanceResult = error.map {
            "Couldn’t clear the cache: \($0)"
        } ?? action.successMessage
        isMaintainingCache = false
    }
}

private extension View {
    @ViewBuilder
    func hakoDNSNameEntryBehavior() -> some View {
        #if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }

    @ViewBuilder
    func hakoRuntimeGroupedFormStyle() -> some View {
        if #available(iOS 16.0, *) {
            formStyle(.grouped)
        } else {
            self
        }
    }
}
