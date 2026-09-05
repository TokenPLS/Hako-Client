import HakoClientUI
import SwiftUI
#if os(macOS)
import AppKit
#endif

 
 
 
 
@MainActor
final class GeoResourcesModel: ObservableObject {
    @Published private(set) var entries: [GeoResourceInventory.Entry] = []
    @Published private(set) var syncing: Set<GeoResource> = []
    @Published private(set) var errors: [GeoResource: ConfigurationFailure] = [:]
    @Published private(set) var successes: [GeoResource: String] = [:]
    @Published private(set) var batchReport: BatchUpdateReport?
    @Published private(set) var isBatchSyncing = false
    @Published var autoUpdate: Bool
    @Published var intervalHours: Int
    private var batchTask: Task<Void, Never>?

    private var homeDir: URL? {
        HakoAppIdentifiers.appGroupContainer?
            .appendingPathComponent("working")
    }

    init() {
        autoUpdate = GeoResourceSettings.autoUpdateEnabled()
        intervalHours = GeoResourceSettings.autoUpdateIntervalHours()
    }

    func load() {
        guard let homeDir else { return }
        entries = GeoResourceInventory.scan(homeDir: homeDir)
    }

    var lastFullSyncDescription: String {
        guard let date = GeoResourceSettings.lastSync() else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func saveAutoUpdate() {
        GeoResourceSettings.setAutoUpdate(enabled: autoUpdate, intervalHours: intervalHours)
    }

    func url(for resource: GeoResource) -> String {
        GeoResourceSettings.url(for: resource)
    }

     
    func setURL(_ raw: String, for resource: GeoResource) -> Bool {
        GeoResourceSettings.setURL(raw, for: resource)
    }

    func sync(_ resource: GeoResource) {
        guard let homeDir, !syncing.contains(resource) else { return }
        syncing.insert(resource)
        errors[resource] = nil
        successes[resource] = nil
        let url = GeoResourceSettings.url(for: resource)
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.syncing.remove(resource)
                self.load()
            }
            do {
                try await self.syncResource(resource, url: url, homeDir: homeDir)
                self.successes[resource] = "\(resource.fileName) synced"
            } catch {
                self.errors[resource] = ConfigurationFailureClassifier.classify(
                    error,
                    context: .geodata,
                    preservesLastKnownGood: true
                )
            }
        }
    }

    func syncAll() {
        guard batchTask == nil, let homeDir else { return }
        batchReport = BatchUpdateReport(
            title: "Geo Resource Sync",
            expectedCount: GeoResource.allCases.count
        )
        isBatchSyncing = true
        batchTask = Task { [weak self] in
            guard let self else { return }
            for resource in GeoResource.allCases {
                if Task.isCancelled {
                    self.markBatchCancelled()
                    break
                }
                self.syncing.insert(resource)
                self.errors[resource] = nil
                self.successes[resource] = nil
                do {
                    try await self.syncResource(
                        resource,
                        url: GeoResourceSettings.url(for: resource),
                        homeDir: homeDir
                    )
                    self.successes[resource] = "\(resource.fileName) synced"
                    self.recordBatchItem(
                        resource: resource,
                        state: .updated,
                        message: "The resource was validated and saved atomically."
                    )
                } catch is CancellationError {
                    self.markBatchCancelled()
                    self.syncing.remove(resource)
                    break
                } catch {
                    self.recordBatchFailure(error, resource: resource)
                }
                self.syncing.remove(resource)
                self.load()
            }
            if self.batchIsCompleteAndSuccessful {
                GeoResourceSettings.recordSync()
            }
            self.syncing.removeAll()
            self.isBatchSyncing = false
            self.batchTask = nil
            self.load()
        }
    }

    func cancelBatchSync() {
        batchTask?.cancel()
    }

    func dismissBatchReport() {
        guard !isBatchSyncing else { return }
        batchReport = nil
    }

    func retryBatchItem(id: String) {
        guard batchTask == nil,
              let resource = GeoResource(rawValue: id),
              let homeDir else { return }
        isBatchSyncing = true
        syncing.insert(resource)
        batchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.syncResource(
                    resource,
                    url: GeoResourceSettings.url(for: resource),
                    homeDir: homeDir
                )
                self.successes[resource] = "\(resource.fileName) synced"
                self.errors[resource] = nil
                self.recordBatchItem(
                    resource: resource,
                    state: .updated,
                    message: "The resource was validated and saved atomically."
                )
            } catch is CancellationError {
                self.markBatchCancelled()
            } catch {
                self.recordBatchFailure(error, resource: resource)
            }
            if self.batchIsCompleteAndSuccessful {
                GeoResourceSettings.recordSync()
            }
            self.syncing.remove(resource)
            self.isBatchSyncing = false
            self.batchTask = nil
            self.load()
        }
    }

    private func syncResource(_ resource: GeoResource, url: String, homeDir: URL) async throws {
        try Task.checkCancellation()
        let plan = RemoteResourcePlan(
            providers: [],
            geodata: [.init(kind: resource.planKind, url: url)],
            notices: [],
            errors: []
        )
        try await GeodataManager(downloader: ResourceDownloader()).stage(
            plan: plan,
            homeDir: homeDir,
            maxBytesEach: ProfileActivationCoordinator.maxGeodataBytes
        )
    }

    private var batchIsCompleteAndSuccessful: Bool {
        guard let report = batchReport else { return false }
        return !report.wasCancelled
            && report.completedCount == report.expectedCount
            && report.failedCount == 0
    }

    private func recordBatchFailure(_ error: Error, resource: GeoResource) {
        let failure = ConfigurationFailureClassifier.classify(
            error,
            context: .geodata,
            preservesLastKnownGood: true
        )
        errors[resource] = failure
        guard let failure else { return }
        recordBatchItem(
            resource: resource,
            state: .failed,
            message: failure.message,
            failure: failure
        )
    }

    private func recordBatchItem(
        resource: GeoResource,
        state: BatchUpdateState,
        message: String?,
        failure: ConfigurationFailure? = nil
    ) {
        guard var report = batchReport else { return }
        report.wasCancelled = false
        report.record(BatchUpdateItem(
            id: resource.rawValue,
            label: resource.title,
            state: state,
            message: message,
            failure: failure
        ))
        batchReport = report
    }

    private func markBatchCancelled() {
        guard var report = batchReport else { return }
        report.wasCancelled = true
        batchReport = report
    }
}

struct ResourcesView: View {
    @Environment(\.locale) private var locale
    @StateObject private var model = GeoResourcesModel()

     
     
     
     
     
     
     
     
     
    @State private var deviations: ConfigDeviationReport?

    var body: some View {
        HakoMacSettingsContainer {
            Section {
                Toggle("Auto update", isOn: $model.autoUpdate)
                    .accessibilityIdentifier("resource.auto-update")
                    .onChange(of: model.autoUpdate) { _ in model.saveAutoUpdate() }
                        .accessibilityIdentifier("resource.update-interval")
                Stepper(value: $model.intervalHours, in: 1...168) {
                    HStack {
                        Text("Interval")
                        Spacer()
                        Text("\(model.intervalHours) h").foregroundStyle(.secondary)
                    }
                }
                .onChange(of: model.intervalHours) { _ in model.saveAutoUpdate() }
                Button {
                    model.syncAll()
                } label: {
                    if model.isBatchSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Sync all Geo resources", systemImage: HakoSymbol.arrowTriangle2Circlepath.name)
                    }
                }
                .hakoMacFormActionChrome()
                .disabled(model.isBatchSyncing)
                .accessibilityIdentifier("resources.sync-all")
            } header: {
                Text("Geo auto update")
            } footer: {
                 
                 
                 
                 
                 
                Text(hako: .format(
                    "%@ Last full refresh: %@.",
                    [
                        HakoCopy.string(
                            BackgroundRefreshPolicy.explanation,
                            locale: locale
                        ),
                        model.lastFullSyncDescription == "Never"
                            ? HakoCopy.string("Never", locale: locale)
                            : model.lastFullSyncDescription,
                    ]
                ))
            }

            ForEach(model.entries, id: \.resource) { entry in
                GeoResourceSection(
                    entry: entry,
                    url: model.url(for: entry.resource),
                    isSyncing: model.syncing.contains(entry.resource),
                    error: model.errors[entry.resource],
                    success: model.successes[entry.resource],
                    setURL: { model.setURL($0, for: entry.resource) },
                    sync: { model.sync(entry.resource) })
            }
            ConfigDeviationSection(
                report: deviations,
                fields: RunningCoreDeviations.fields(for: [.geoData]),
                identifierPrefix: "resource.deviation"
            )
        }
        .hakoInsetGroupedListStyle()
         
         
         
         
         
         
        .hakoPageTitle("Resources")
        .onAppear { model.load() }
        .task {
            deviations = await Task.detached(priority: .utility) {
                RunningCoreDeviations.activeProfileReport()
            }.value
        }
        .sheet(isPresented: Binding(
            get: { model.batchReport != nil },
            set: { if !$0 { model.dismissBatchReport() } }
        )) {
            Group {
                if let report = model.batchReport {
                    BatchUpdateReportView(
                        report: report,
                        isRunning: model.isBatchSyncing,
                        cancel: { model.cancelBatchSync() },
                        retry: { model.retryBatchItem(id: $0) },
                        dismiss: { model.dismissBatchReport() }
                    )
                }
            }
            .hakoModalPresentation(.page)
        }
    }
}

private struct GeoResourceSection: View {
    let entry: GeoResourceInventory.Entry
    let url: String
    let isSyncing: Bool
    let error: ConfigurationFailure?
    let success: String?
    let setURL: (String) -> Bool
    let sync: () -> Void

    @State private var editing = false
    @FocusState private var urlFieldFocused: Bool
    @State private var urlText = ""
    @State private var rejected = false

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: HakoTheme.Spacing.row) {
                HakoIconWell(symbol: resourceSymbol, tint: resourceTint)
                VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                    Text(entry.resource.fileName)
                        .font(.body)
                    Text(statusLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("resource.status.\(entry.resource.rawValue)")
            if editing {
                hakoPromptField(
                    entry.resource.defaultURL,
                    text: $urlText
                )
                    .focused($urlFieldFocused)
                     
                     
                    .onAppear {
                         
                         
                         
                         
                         
                         
                        urlFieldFocused = true
                    }
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .caption.monospaced())
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if rejected {
                    HakoStatusMessage(
                        text: .copy("HTTPS URL with a host required; empty resets to the default."),
                        kind: .error
                    )
                }
            } else {
                Text(url)
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            HakoGlassEffectContainer(spacing: HakoTheme.Spacing.row) {
                HStack(spacing: HakoTheme.Spacing.row) {
                    Button(editing ? "Save URL" : "Edit URL") {
                        if editing {
                            rejected = !setURL(urlText)
                            if !rejected { editing = false }
                        } else {
                            urlText = url
                            rejected = false
                            editing = true
                        }
                    }
                    .hakoSecondaryActionButtonStyle()
                    .hakoMacFormActionChrome()
                    Button {
                        sync()
                    } label: {
                        if isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Sync", systemImage: HakoSymbol.arrowTriangle2Circlepath.name)
                        }
                    }
                    .hakoSecondaryActionButtonStyle()
                    .hakoMacFormActionChrome()
                    .disabled(isSyncing)
                    .accessibilityIdentifier("resource.sync.\(entry.resource.rawValue)")
                }
            }
            if let error {
                ConfigurationFailureView(failure: error) { action in
                    if action == .retry { sync() }
                }
                    .accessibilityIdentifier("resource.error.\(entry.resource.rawValue)")
            } else if let success {
                HakoStatusMessage(text: .copy(success), kind: .success)
                    .accessibilityIdentifier("resource.success.\(entry.resource.rawValue)")
            }
        } header: {
            Text(entry.resource.title)
        }
    }

    private var statusLine: String {
        guard let size = entry.sizeBytes else { return "Not downloaded" }
        var line = ByteCountFormatter.string(Int64(size))
        if let updatedAt = entry.updatedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            line += " · " + formatter.localizedString(for: updatedAt, relativeTo: Date())
        }
        return line
    }

    private var resourceSymbol: HakoSymbol {
        switch entry.resource {
        case .geoip: return .map
        case .geosite: return .globeAsiaAustralia
        case .mmdb: return .externaldrive
        case .asn: return .point3ConnectedTrianglepathDotted
        }
    }

    private var resourceTint: Color {
        switch entry.resource {
        case .geoip: return .blue
        case .geosite: return .green
        case .mmdb: return .purple
        case .asn: return .orange
        }
    }
}
