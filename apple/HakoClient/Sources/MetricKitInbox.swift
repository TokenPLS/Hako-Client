import HakoClientUI
import CryptoKit
import Foundation
import MetricKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum MetricKitReportKind: String, Codable, Equatable {
    case metric
    case diagnostic

    var title: String {
        switch self {
        case .metric: return "Daily Metrics"
        case .diagnostic: return "Diagnostic Report"
        }
    }
}

struct MetricKitIncomingReport {
    let kind: MetricKitReportKind
    let receivedAt: Date
    let periodStart: Date
    let periodEnd: Date
    let categoryCounts: [String: Int]
    let payload: Data
}

struct MetricKitReport: Equatable, Identifiable {
    var id: String
    var kind: MetricKitReportKind
    var receivedAt: Date
    var periodStart: Date
    var periodEnd: Date
    var categoryCounts: [String: Int]
    var byteCount: Int64
    var fileName: String

    var categorySummary: String {
        let values = categoryCounts
            .filter { $0.value > 0 }
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key) \($0.value)" }
        return values.isEmpty ? "System summary" : values.joined(separator: " · ")
    }
}

struct MetricKitInboxStore {
    enum StoreError: LocalizedError {
        case unavailable
        case invalidReport

        var errorDescription: String? {
            switch self {
            case .unavailable: return "The local diagnostics container is unavailable."
            case .invalidReport: return "The selected diagnostics report is no longer valid."
            }
        }
    }

    private static let fileSuffix = ".hako-metrickit.json"
    private static let schemaVersion = 1
    private static let maximumPayloadBytes = 2 * 1_024 * 1_024
     
     
     
     
     
     
     
    private static let maximumPayloadDepth = 512

    let directory: URL
    let maximumReportCount: Int
    let maximumTotalBytes: Int64
    private let fileManager: FileManager

    init(
        directory: URL,
        maximumReportCount: Int = 30,
        maximumTotalBytes: Int64 = 8 * 1_024 * 1_024,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.maximumReportCount = max(1, maximumReportCount)
        self.maximumTotalBytes = max(1, maximumTotalBytes)
        self.fileManager = fileManager
    }

     
     
     
     
     
    static func live(
        containerURL: URL? = HakoAppIdentifiers.appGroupContainer,
        fileManager: FileManager = .default
    ) -> MetricKitInboxStore? {
        guard let container = containerURL else { return nil }
        return MetricKitInboxStore(
            directory: container.appendingPathComponent(
                "diagnostics/metrickit",
                isDirectory: true
            ),
            fileManager: fileManager
        )
    }

    @discardableResult
    func ingest(_ incoming: MetricKitIncomingReport) throws -> MetricKitReport {
        try prepareDirectory()
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        var stored: Data
        let depth = ConfigTransforms.jsonNestingDepth(
            String(decoding: incoming.payload, as: UTF8.self)
        )
        if depth > Self.maximumPayloadDepth {
            stored = try JSONSerialization.data(
                withJSONObject: [
                    "omitted": "Payload exceeded Clash's local nesting-depth cap.",
                    "nestingDepth": depth,
                    "payloadByteCount": incoming.payload.count,
                ],
                options: [.prettyPrinted, .sortedKeys]
            )
        } else {
            stored = incoming.payload
        }
        if stored.count > Self.maximumPayloadBytes {
            stored = try JSONSerialization.data(
                withJSONObject: [
                    "omitted": "Payload exceeded Clash's local two-megabyte size cap.",
                    "payloadByteCount": stored.count,
                ],
                options: [.prettyPrinted, .sortedKeys]
            )
        }
        let identifier = reportIdentifier(incoming: incoming, payload: stored)
        let fileName = "report-\(identifier)\(Self.fileSuffix)"
        let target = directory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: target.path),
           let existing = try list().first(where: { $0.id == identifier }) {
            return existing
        }

        let payload = try JSONSerialization.jsonObject(
            with: stored,
            options: [.fragmentsAllowed]
        )
        let metadata: [String: Any] = [
            "schemaVersion": Self.schemaVersion,
            "id": identifier,
            "kind": incoming.kind.rawValue,
            "receivedAt": incoming.receivedAt.timeIntervalSince1970,
            "periodStart": incoming.periodStart.timeIntervalSince1970,
            "periodEnd": incoming.periodEnd.timeIntervalSince1970,
            "categoryCounts": incoming.categoryCounts,
        ]
        let envelope: [String: Any] = ["_hako": metadata, "payload": payload]
        let data = try JSONSerialization.data(
            withJSONObject: envelope,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(
            to: target,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: target.path
        )
        try enforceRetention()
        guard let saved = try list().first(where: { $0.id == identifier }) else {
            throw StoreError.invalidReport
        }
        return saved
    }

    func list() throws -> [MetricKitReport] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        return try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasSuffix(Self.fileSuffix) }
        .compactMap(parseReport)
        .sorted {
            if $0.receivedAt != $1.receivedAt { return $0.receivedAt > $1.receivedAt }
            return $0.id < $1.id
        }
    }

    func data(for report: MetricKitReport) throws -> Data {
        let url = try validatedURL(for: report)
        guard let parsed = parseReport(url), parsed.id == report.id else {
            throw StoreError.invalidReport
        }
        return try Data(contentsOf: url)
    }

    func exportURL(for report: MetricKitReport) throws -> URL {
        _ = try data(for: report)
        return try validatedURL(for: report)
    }

    func delete(_ report: MetricKitReport) throws {
        let url = try validatedURL(for: report)
        guard let parsed = parseReport(url), parsed.id == report.id else {
            throw StoreError.invalidReport
        }
        try fileManager.removeItem(at: url)
    }

    func deleteAll() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        for report in try list() {
            try delete(report)
        }
    }

    private func prepareDirectory() throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ]
        )
    }

    private func parseReport(_ url: URL) -> MetricKitReport? {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metadata = root["_hako"] as? [String: Any],
              (metadata["schemaVersion"] as? NSNumber)?.intValue == Self.schemaVersion,
              let id = metadata["id"] as? String,
              let kindRaw = metadata["kind"] as? String,
              let kind = MetricKitReportKind(rawValue: kindRaw),
              let received = (metadata["receivedAt"] as? NSNumber)?.doubleValue,
              let start = (metadata["periodStart"] as? NSNumber)?.doubleValue,
              let end = (metadata["periodEnd"] as? NSNumber)?.doubleValue,
              url.lastPathComponent == "report-\(id)\(Self.fileSuffix)"
        else { return nil }
        let categories = (metadata["categoryCounts"] as? [String: NSNumber] ?? [:])
            .mapValues(\.intValue)
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
        return MetricKitReport(
            id: id,
            kind: kind,
            receivedAt: Date(timeIntervalSince1970: received),
            periodStart: Date(timeIntervalSince1970: start),
            periodEnd: Date(timeIntervalSince1970: end),
            categoryCounts: categories,
            byteCount: bytes,
            fileName: url.lastPathComponent
        )
    }

    private func validatedURL(for report: MetricKitReport) throws -> URL {
        let expected = "report-\(report.id)\(Self.fileSuffix)"
        guard !report.id.isEmpty,
              report.fileName == expected,
              URL(fileURLWithPath: report.fileName).lastPathComponent == report.fileName
        else { throw StoreError.invalidReport }
        let url = directory.appendingPathComponent(report.fileName).standardizedFileURL
        guard url.deletingLastPathComponent() == directory.standardizedFileURL,
              fileManager.fileExists(atPath: url.path)
        else { throw StoreError.invalidReport }
        return url
    }

    private func reportIdentifier(
        incoming: MetricKitIncomingReport,
        payload: Data
    ) -> String {
        var material = Data(incoming.kind.rawValue.utf8)
        material.append(Data(String(incoming.periodStart.timeIntervalSince1970).utf8))
        material.append(Data(String(incoming.periodEnd.timeIntervalSince1970).utf8))
        material.append(payload)
        return SHA256.hash(data: material).prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private func enforceRetention() throws {
        var reports = try list()
        while reports.count > maximumReportCount
            || reports.reduce(Int64(0), { $0 + $1.byteCount }) > maximumTotalBytes {
            guard let oldest = reports.last else { break }
            try delete(oldest)
            reports.removeLast()
        }
    }
}

 
 
final class MetricKitCollector: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricKitCollector()

    private let manager = MXMetricManager.shared
    private let queue = DispatchQueue(label: "org.example.hako.metrickit", qos: .utility)
    private let lock = NSLock()
    private var started = false

    func start() {
        lock.lock()
        guard !started else {
            lock.unlock()
            return
        }
        started = true
        lock.unlock()

        manager.add(self)
        let metrics = manager.pastPayloads
        let diagnostics = manager.pastDiagnosticPayloads
        ingestOnLargeStack { [weak self] in
            self?.ingest(metrics)
            self?.ingest(diagnostics)
        }
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        ingestOnLargeStack { [weak self] in self?.ingest(payloads) }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        ingestOnLargeStack { [weak self] in self?.ingest(payloads) }
    }

     
     
     
     
     
     
     
     
    private func ingestOnLargeStack(_ body: @escaping () -> Void) {
        queue.async {
            let finished = DispatchSemaphore(value: 0)
            let thread = Thread {
                body()
                finished.signal()
            }
            thread.name = "org.example.hako.metrickit.ingest"
            thread.qualityOfService = .utility
            thread.stackSize = 8 << 20
            thread.start()
            finished.wait()
        }
    }

    private func ingest(_ payloads: [MXMetricPayload]) {
        guard let store = MetricKitInboxStore.live() else { return }
        for payload in payloads {
            var categories: [String: Int] = [:]
            if payload.cpuMetrics != nil { categories["CPU"] = 1 }
            if payload.diskIOMetrics != nil { categories["Disk"] = 1 }
            if payload.applicationResponsivenessMetrics != nil {
                categories["Responsiveness"] = 1
            }
            if payload.cpuMetrics != nil || payload.gpuMetrics != nil
                || payload.networkTransferMetrics != nil {
                categories["Energy"] = 1
            }
            _ = try? store.ingest(MetricKitIncomingReport(
                kind: .metric,
                receivedAt: Date(),
                periodStart: payload.timeStampBegin,
                periodEnd: payload.timeStampEnd,
                categoryCounts: categories,
                payload: payload.jsonRepresentation()
            ))
        }
    }

    private func ingest(_ payloads: [MXDiagnosticPayload]) {
        guard let store = MetricKitInboxStore.live() else { return }
        for payload in payloads {
            var categories: [String: Int] = [:]
            categories["Crash"] = payload.crashDiagnostics?.count ?? 0
            categories["Hang"] = payload.hangDiagnostics?.count ?? 0
            categories["CPU"] = payload.cpuExceptionDiagnostics?.count ?? 0
            categories["Disk"] = payload.diskWriteExceptionDiagnostics?.count ?? 0
            _ = try? store.ingest(MetricKitIncomingReport(
                kind: .diagnostic,
                receivedAt: Date(),
                periodStart: payload.timeStampBegin,
                periodEnd: payload.timeStampEnd,
                categoryCounts: categories,
                payload: payload.jsonRepresentation()
            ))
        }
    }
}

struct MetricKitInboxView: View {
    @State private var reports: [MetricKitReport] = []
    @State private var selected: MetricKitReport?
    @State private var shared: MetricKitSharedReport?
    @State private var status = ""
    @State private var showsDeleteAll = false

    private let store: MetricKitInboxStore?

    init(store: MetricKitInboxStore? = MetricKitInboxStore.live()) {
        self.store = store
    }

    var body: some View {
        HakoMacSettingsContainer {
            Section {
                HakoStatusMessage(
                    text: "The system prepares these reports on device. Clash keeps a copy locally — the payload complete and unfiltered, under a small header of its own — and never uploads it automatically. A report past the size or nesting cap is stored as a note saying so.",
                    kind: .information
                )
                .accessibilityIdentifier("diagnostics.privacy")
            } header: {
                Text("Privacy")
            }

            Section {
                if reports.isEmpty {
                    HakoEmptyState(
                        title: "No Reports Yet",
                        message: "MetricKit reports arrive when the system has enough app usage data; delivery is not guaranteed for every event.",
                        symbol: .waveformPathEcg
                    )
                    .accessibilityIdentifier("diagnostics.empty")
                } else {
                    ForEach(reports) { report in
                        Button { selected = report } label: {
                            MetricKitReportRow(report: report)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("diagnostics.report.\(report.id)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { delete(report) } label: {
                                Label("Delete", systemImage: HakoSymbol.trash.name)
                            }
                             
                             
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button { share(report) } label: {
                                Label("Share", systemImage: HakoSymbol.squareAndArrowUp.name)
                            }
                            .tint(.blue)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Local Inbox")
                    Spacer()
                    Text(reportCountLabel)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("diagnostics.reportCount")
                }
            } footer: {
                Text("At most 30 reports or 8 MB are kept. New reports replace the oldest local copies.")
            }

            if !status.isEmpty {
                Section {
                    HakoStatusMessage(text: .copy(status), kind: .error)
                        .accessibilityIdentifier("diagnostics.status")
                }
            }
        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle("Diagnostics Inbox")
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .hakoNavigationTrailing) {
                Button(role: .destructive) { showsDeleteAll = true } label: {
                    Label("Clear", systemImage: HakoSymbol.trash.name)
                }
                .disabled(reports.isEmpty)
                .accessibilityIdentifier("diagnostics.clear")
            }
        }
        .onAppear(perform: refresh)
        .sheet(item: $selected) { report in
            MetricKitReportDetailView(
                report: report,
                exportURL: {
                    guard let url = try store?.exportURL(for: report) else {
                        throw MetricKitInboxStore.StoreError.unavailable
                    }
                    return url
                },
                delete: { delete(report); selected = nil }
            )
            .hakoModalPresentation(.page)
        }
        .sheet(item: $shared) { item in
            MetricKitActivityView(activityItems: [item.url])
                .hakoModalPresentation(.page)
        }
        .alert("Clear Local Reports?", isPresented: $showsDeleteAll) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive, action: deleteAll)
        } message: {
            Text("This removes Clash's local copies. It does not change diagnostics managed by the system.")
        }
    }

    private var reportCountLabel: String {
        reports.count == 1 ? "1 report" : "\(reports.count) reports"
    }

    private func refresh() {
        do {
            reports = try store?.list() ?? []
            status = store == nil ? "The local diagnostics container is unavailable." : ""
        } catch {
            status = error.localizedDescription
        }
    }

    private func share(_ report: MetricKitReport) {
        do {
            guard let url = try store?.exportURL(for: report) else {
                throw MetricKitInboxStore.StoreError.unavailable
            }
            shared = MetricKitSharedReport(url: url)
        } catch {
            status = error.localizedDescription
        }
    }

    private func delete(_ report: MetricKitReport) {
        do {
            guard let store else { throw MetricKitInboxStore.StoreError.unavailable }
            try store.delete(report)
            refresh()
        } catch {
            status = error.localizedDescription
        }
    }

    private func deleteAll() {
        do {
            guard let store else { throw MetricKitInboxStore.StoreError.unavailable }
            try store.deleteAll()
            refresh()
        } catch {
            status = error.localizedDescription
        }
    }
}

private struct MetricKitReportRow: View {
    let report: MetricKitReport

    var body: some View {
        HStack(alignment: .top, spacing: HakoTheme.Spacing.row) {
            HakoIconWell(
                symbol: report.kind == .diagnostic ? .exclamationmarkTriangle : .waveformPathEcg,
                tint: report.kind == .diagnostic ? .orange : .indigo
            )
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                Text(report.kind.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(hako: .copy(report.categorySummary))
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(report.periodEnd.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            Text(ByteCountFormatter.string(report.byteCount))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

private struct MetricKitReportDetailView: View {
     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    let report: MetricKitReport
     
     
     
     
     
    let exportURL: () throws -> URL
    let delete: () -> Void
    @State private var shared: MetricKitSharedReport?
    @State private var status = ""

    var body: some View {
        HakoFeatureNavigationContainer {
            Form {
                Section("Summary") {
                    OverviewValueRow(title: "Kind", value: .verbatim(report.kind.title))
                    OverviewValueRow(title: "Categories", value: .verbatim(report.categorySummary))
                    OverviewValueRow(
                        title: "Size",
                        value: .verbatim(ByteCountFormatter.string(report.byteCount))
                    )
                }
                Section("Reporting Period") {
                    OverviewValueRow(
                        title: "From",
                        value: .verbatim(report.periodStart.formatted(date: .abbreviated, time: .shortened))
                    )
                    OverviewValueRow(
                        title: "To",
                        value: .verbatim(report.periodEnd.formatted(date: .abbreviated, time: .shortened))
                    )
                }
                Section {
                    Button {
                        do { shared = MetricKitSharedReport(url: try exportURL()) }
                        catch { status = error.localizedDescription }
                    } label: {
                        Label(
                            "Share Report",
                            systemImage: HakoSymbol.squareAndArrowUp.name
                        )
                    }
                    .accessibilityIdentifier("diagnostics.share")
                    if !status.isEmpty {
                        HakoStatusMessage(text: .verbatim(status), kind: .error)
                    }
                    Button(role: .destructive, action: delete) {
                        Label("Delete Local Copy", systemImage: HakoSymbol.trash.name)
                    }
                    .accessibilityIdentifier("diagnostics.delete")
                } footer: {
                    Text("The shared JSON is what this inbox holds: the system's payload complete and unfiltered, under a small Clash header. Nothing is taken out of it, so it can name your servers and addresses. Clash has no automatic diagnostics uploader.")
                }
            }
            .hakoPageTitle("Report")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    HakoSheetCloseButton { dismiss() }
                }
            }
            .sheet(item: $shared) { item in
                MetricKitActivityView(activityItems: [item.url])
                    .hakoModalPresentation(.page)
            }
        }
        .hakoStackNavigationViewStyle()
        .hakoCapturesDismiss(dismiss)
    }
}

private struct MetricKitSharedReport: Identifiable {
    let url: URL
    var id: URL { url }
}

#if os(macOS)
private struct MetricKitActivityView: View {
    let activityItems: [Any]

    var body: some View {
        if let url = activityItems.first as? URL {
            VStack(spacing: HakoTheme.Spacing.standard) {
                Text("Diagnostic Export")
                    .font(.headline)
                ShareLink(item: url) {
                    Label(
                        "Share Report",
                        systemImage: HakoSymbol.squareAndArrowUp.name
                    )
                }
            }
            .padding()
            .frame(minWidth: 280, minHeight: 120)
        } else {
            Text("No diagnostic report is available.")
                .padding()
        }
    }
}
#else
private struct MetricKitActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
#endif


