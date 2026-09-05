import HakoClientUI
import SwiftUI
import UniformTypeIdentifiers

 
enum ProviderInventory {
    struct Entry: Equatable {
        let name: String
        let sizeBytes: Int?
        let updatedAt: Date?
    }

    static func scan(providersDir: URL) -> [Entry] {
        guard let names = try? FileManager.default
            .contentsOfDirectory(atPath: providersDir.path) else { return [] }
        return names.sorted()
            .filter { $0 != "providers.json" }   
            .map { name in
                let attributes = try? FileManager.default.attributesOfItem(
                    atPath: providersDir.appendingPathComponent(name).path)
                return Entry(name: name,
                             sizeBytes: (attributes?[.size] as? NSNumber)?.intValue,
                             updatedAt: attributes?[.modificationDate] as? Date)
            }
    }
}

 
 
 
 
 
 
@MainActor
final class ProvidersModel: ObservableObject {
    struct Row: Equatable, Identifiable {
        let name: String        
        let kind: String?       
        let sizeBytes: Int?
        let updatedAt: Date?
        let count: Int?
        let subscriptionInfo: SubscriptionInfo?
        let canRefresh: Bool
         
         
         
         
         
        var loadFailure: String? = nil
        var runtime: ProviderRuntimeSummary? = nil
        var id: String { name }

         
         
         
         
         
         
         
         
        var loadFailureText: HakoDisplayText? {
            guard let loadFailure else { return nil }
            return loadFailure == ProviderValidationWarning.clientAuthoredReason
                ? .copy(ProviderValidationWarning.clientAuthoredReason)
                : .verbatim(loadFailure)
        }
    }

    @Published private(set) var rows: [Row] = []
    @Published private(set) var activeProfile: Profile?
    @Published private(set) var busy = false
    @Published private(set) var busyProvider: String?
    @Published private(set) var healthCheckingProvider: String?
    @Published private(set) var runtimeLoading = false
    @Published private(set) var runtimeStatus = ""
    @Published private(set) var status = ""
    @Published private(set) var lastFailure: ConfigurationFailure?
    @Published private(set) var batchReport: BatchUpdateReport?

    private let vpn: VPNController
    private let command: ClashCommandClient
    private var localRows: [Row] = []
    private var runtimeCatalog: ProviderRuntimeCatalog?
    private var runtimeTask: Task<Void, Never>?
    private var runtimeGeneration: UInt64 = 0
    private var retryOperation: RetryOperation?
    private var batchTask: Task<Void, Never>?

    private enum RetryOperation {
        case all
        case provider(String)
    }

    init(vpn: VPNController, command: ClashCommandClient) {
        self.vpn = vpn
        self.command = command
    }

    private var container: URL? {
        HakoAppIdentifiers.appGroupContainer
    }

    func load() {
        runtimeTask?.cancel()
        runtimeGeneration &+= 1
        runtimeCatalog = nil
        guard let container,
              let store = try? ConfigResourceStore(containerURL: container) else { return }
        if let dir = try? store.activeProvidersDirectory() {
            localRows = Self.rows(providersDir: dir)
        } else {
            localRows = []
        }
        rows = localRows
        let profiles = ProfileStore(
            fileURL: container.appendingPathComponent("working/store/profiles.json")).load()
         
         
         
         
         
         
         
        let activeID = (try? store.activeIdentity())?.profileID
        activeProfile = profiles.first { $0.id == activeID }
        refreshRuntimeCatalog()
    }

    static func rows(providersDir: URL) -> [Row] {
        if let catalog = ProviderCatalog.load(providersDir: providersDir) {
            return catalog.entries
                .sorted { $0.name < $1.name }
                .map { entry in
                    let attributes = try? FileManager.default.attributesOfItem(
                        atPath: providersDir.appendingPathComponent(entry.path).path)
                    return Row(name: entry.name, kind: entry.kind,
                               sizeBytes: (attributes?[.size] as? NSNumber)?.intValue,
                               updatedAt: entry.lastUpdatedAt
                                   ?? attributes?[.modificationDate] as? Date,
                               count: entry.count,
                               subscriptionInfo: entry.subscriptionInfo,
                               canRefresh: true,
                               loadFailure: entry.loadFailure)
                }
        }
         
        return ProviderInventory.scan(providersDir: providersDir).map {
            Row(name: $0.name, kind: nil, sizeBytes: $0.sizeBytes,
                updatedAt: $0.updatedAt, count: nil,
                subscriptionInfo: nil, canRefresh: false)
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    nonisolated static func unreadableRuleSets(
        providersDir: URL
    ) -> [Row] {
        guard let catalog = ProviderCatalog.load(providersDir: providersDir)
        else { return [] }
        return catalog.entries
            .filter { $0.kind == "rule" && $0.loadFailure != nil }
            .sorted { $0.name < $1.name }
            .map {
                Row(name: $0.name, kind: $0.kind, sizeBytes: nil,
                    updatedAt: $0.lastUpdatedAt, count: $0.count,
                    subscriptionInfo: nil, canRefresh: true,
                    loadFailure: $0.loadFailure)
            }
    }

    static func mergingRuntime(
        _ runtime: ProviderRuntimeCatalog,
        into localRows: [Row]
    ) -> [Row] {
        localRows.map { row in
            var merged = row
            merged.runtime = runtime.summary(name: row.name, kind: row.kind)
            return merged
        }
    }

    func refreshRuntimeCatalog() {
        runtimeTask?.cancel()
        runtimeGeneration &+= 1
        let token = runtimeGeneration
        guard command.isConnected else {
            runtimeLoading = false
            runtimeCatalog = nil
            rows = localRows
            runtimeStatus = "Connect Clash to view live provider status."
            return
        }
        runtimeLoading = true
        runtimeStatus = "Loading live provider status…"
        runtimeTask = Task { [weak self] in
            guard let self else { return }
            do {
                let catalog = try await self.command.providerRuntimeCatalog()
                guard !Task.isCancelled, token == self.runtimeGeneration else { return }
                self.runtimeCatalog = catalog
                self.rows = Self.mergingRuntime(catalog, into: self.localRows)
                self.runtimeStatus = "Live provider status is up to date."
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, token == self.runtimeGeneration else { return }
                self.runtimeCatalog = nil
                self.rows = self.localRows
                self.runtimeStatus = "Live provider status is unavailable."
            }
            guard token == self.runtimeGeneration else { return }
            self.runtimeLoading = false
            self.runtimeTask = nil
        }
    }

    func checkHealth(provider name: String) {
        guard !busy,
              healthCheckingProvider == nil,
              command.isConnected,
              rows.contains(where: {
                  $0.name == name && $0.kind?.lowercased() == "proxy"
              }) else { return }
        healthCheckingProvider = name
        runtimeStatus = "Checking proxy provider health…"
        Task { [weak self] in
            guard let self else { return }
            defer { self.healthCheckingProvider = nil }
            do {
                let provider = try await self.command.healthCheckProxyProvider(named: name)
                var catalog = self.runtimeCatalog ?? .empty
                catalog.proxyProviders[name] = provider
                self.runtimeCatalog = catalog
                self.rows = Self.mergingRuntime(catalog, into: self.localRows)
                self.runtimeStatus = "Proxy provider health check completed."
            } catch {
                self.runtimeStatus = "Proxy provider health check failed."
            }
        }
    }

    func refreshAll() {
        guard !busy, let container, let profile = activeProfile,
              let store = try? ConfigResourceStore(containerURL: container) else { return }
        let refreshable = rows.filter(\.canRefresh)
        guard !refreshable.isEmpty else {
            refreshLegacyRevision(profile: profile, store: store, container: container)
            return
        }
        batchReport = BatchUpdateReport(
            title: "Provider Sync",
            expectedCount: refreshable.count
        )
        busy = true
        clearFailure()
        status = "Refreshing providers…"
        batchTask = Task { [weak self] in
            guard let self else { return }
            var changed = false
            var requiresFullApply = false
            for row in refreshable {
                if Task.isCancelled {
                    self.markBatchCancelled()
                    break
                }
                self.busyProvider = row.name
                self.status = "Updating \(row.name)…"
                do {
                    let application = try await self.performProviderRefresh(
                        name: row.name,
                        profile: profile,
                        store: store,
                        container: container
                    )
                    changed = true
                    if application == .requiresFullApply {
                        requiresFullApply = true
                    }
                    self.recordBatchItem(
                        name: row.name,
                        state: .updated,
                        message: application == .applied
                            ? "Published and applied without restarting the tunnel."
                            : "Published for complete configuration apply."
                    )
                } catch is CancellationError {
                    self.markBatchCancelled()
                    break
                } catch {
                    self.recordBatchFailure(error, name: row.name)
                }
            }
            self.busyProvider = nil
            if changed && requiresFullApply {
                await self.applyToTunnel(store: store)
            }
            self.busy = false
            self.batchTask = nil
            self.load()
            if let report = self.batchReport {
                self.status = report.wasCancelled
                    ? "Provider sync cancelled"
                    : "Provider sync finished"
            }
        }
    }

    func refresh(provider name: String) {
        guard !busy, let container, let profile = activeProfile,
              let store = try? ConfigResourceStore(containerURL: container) else { return }
        busy = true
        clearFailure()
        busyProvider = name
        status = "Updating \(name)…"
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.busy = false
                self.busyProvider = nil
                self.load()
            }
            do {
                let application = try await self.performProviderRefresh(
                    name: name,
                    profile: profile,
                    store: store,
                    container: container
                )
                if application == .requiresFullApply {
                    await self.applyToTunnel(store: store)
                }
                self.status = "\(name) updated"
                self.clearFailure()
            } catch PipelineError.sourceUnavailable {
                self.status = "No cached source; run “Refresh all providers” once first"
            } catch {
                self.recordFailure(error, operation: .provider(name))
            }
        }
    }

    func cancelBatchRefresh() {
        batchTask?.cancel()
    }

    func dismissBatchReport() {
        guard !busy else { return }
        batchReport = nil
    }

    func retryBatchItem(id: String) {
        guard !busy, rows.contains(where: { $0.id == id }),
              let container, let profile = activeProfile,
              let store = try? ConfigResourceStore(containerURL: container) else { return }
        busy = true
        busyProvider = id
        batchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let application = try await self.performProviderRefresh(
                    name: id,
                    profile: profile,
                    store: store,
                    container: container
                )
                if application == .requiresFullApply {
                    await self.applyToTunnel(store: store)
                }
                self.recordBatchItem(
                    name: id,
                    state: .updated,
                    message: application == .applied
                        ? "Published and applied without restarting the tunnel."
                        : "Published for complete configuration apply."
                )
            } catch is CancellationError {
                self.markBatchCancelled()
            } catch {
                self.recordBatchFailure(error, name: id)
            }
            self.busy = false
            self.busyProvider = nil
            self.batchTask = nil
            self.load()
        }
    }

    func sideLoad(provider name: String, fileURL: URL) {
        guard !busy, let container, let profile = activeProfile,
              let store = try? ConfigResourceStore(containerURL: container) else { return }
        busy = true
        clearFailure()
        busyProvider = name
        status = "Loading local file for \(name)…"
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.busy = false
                self.busyProvider = nil
                self.load()
            }
            let accessed = fileURL.startAccessingSecurityScopedResource()
            defer { if accessed { fileURL.stopAccessingSecurityScopedResource() } }
            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let size = values.fileSize,
                   size > ProfileActivationCoordinator.maxProviderBytes {
                    throw DownloadError.tooLarge(size)
                }
                let data = try Data(
                    contentsOf: fileURL,
                    options: [.mappedIfSafe, .uncached]
                )
                let coordinator = vpn.activationCoordinator(store: store, container: container)
                let publication = try await coordinator.sideLoadProvider(
                    named: name,
                    data: data,
                    profile: profile
                )
                let application = if let update = publication.runtimeUpdate {
                    await self.command.sideUpdateProvider(update)
                } else {
                    ProviderSideUpdateOutcome.requiresFullApply
                }
                if application == .requiresFullApply {
                    await self.applyToTunnel(store: store)
                }
                self.status = "\(name) loaded from local file"
                self.clearFailure()
            } catch PipelineError.sourceUnavailable {
                self.status = "No cached source; activate the profile once first"
            } catch {
                self.recordFailure(error, context: .localImport, operation: nil)
            }
        }
    }

    func reportImportFailure(_ error: Error) {
        recordFailure(error, context: .localImport, operation: nil)
    }

    func retryLastFailure() {
        guard let retryOperation else { return }
        switch retryOperation {
        case .all: refreshAll()
        case .provider(let name): refresh(provider: name)
        }
    }

    func updateActiveProfile(_ profile: Profile) {
        guard let container else { return }
        let store = ProfileStore(
            fileURL: container.appendingPathComponent("working/store/profiles.json")
        )
        try? store.upsert(profile)
        activeProfile = profile
    }

    private func clearFailure() {
        lastFailure = nil
        retryOperation = nil
    }

    private func performProviderRefresh(
        name: String,
        profile: Profile,
        store: ConfigResourceStore,
        container: URL
    ) async throws -> ProviderSideUpdateOutcome {
        try await ProviderRefreshService.refresh(
            name: name,
            profile: profile,
            store: store,
            container: container,
            vpn: vpn,
            command: command
        )
    }

     
     
     
    private func refreshLegacyRevision(
        profile: Profile,
        store: ConfigResourceStore,
        container: URL
    ) {
        busy = true
        clearFailure()
        batchReport = nil
        status = "Re-materializing providers…"
        Task { [weak self] in
            guard let self else { return }
            defer {
                self.busy = false
                self.load()
            }
            do {
                let coordinator = self.vpn.activationCoordinator(
                    store: store,
                    container: container
                )
                _ = try await coordinator.activate(
                    profile: profile,
                    sourceYAML: self.sidecarYAML(for: profile)
                )
                await self.applyToTunnel(store: store)
                self.status = "Providers refreshed"
                self.clearFailure()
            } catch {
                self.recordFailure(error, operation: .all)
            }
        }
    }

    private func recordBatchFailure(_ error: Error, name: String) {
        guard let failure = ConfigurationFailureClassifier.classify(
            error,
            context: .provider,
            preservesLastKnownGood: true
        ) else { return }
        recordBatchItem(
            name: name,
            state: .failed,
            message: failure.message,
            failure: failure
        )
    }

    private func recordBatchItem(
        name: String,
        state: BatchUpdateState,
        message: String?,
        failure: ConfigurationFailure? = nil
    ) {
        guard var report = batchReport else { return }
        report.wasCancelled = false
        report.record(BatchUpdateItem(
            id: name,
            label: name,
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

    private func recordFailure(
        _ error: Error,
        context: ConfigurationFailureContext = .provider,
        operation: RetryOperation?
    ) {
        guard let failure = ConfigurationFailureClassifier.classify(
            error,
            context: context,
            preservesLastKnownGood: true
        ) else {
            clearFailure()
            return
        }
        lastFailure = failure
        retryOperation = operation
        status = failure.title
    }

     
     
    private func applyToTunnel(store: ConfigResourceStore) async {
        guard let activeYAML = try? store.loadCurrent().text else { return }
         
         
        let outcome = await Task.detached(priority: .userInitiated) {
            PreflightService.check(finalYAML: activeYAML)
        }.value
        guard let intentJSON = outcome.intentJSON,
              let intent = try? JSONDecoder().decode(PlatformConfigIntent.self,
                                                     from: Data(intentJSON.utf8)) else { return }
        await vpn.applyActiveConfiguration(nextIntent: intent)
    }

    private func sidecarYAML(for profile: Profile) -> String? {
        if case .url = profile.source { return nil }
        guard let container else { return nil }
        let sidecar = container
            .appendingPathComponent("working/store/\(profile.id)/source.yaml")
        return try? String(contentsOf: sidecar, encoding: .utf8)
    }
}

enum ProviderDisplayScope: Equatable {
    case all
    case proxy
    case rule

    var title: String {
        switch self {
        case .all: return "Providers"
        case .proxy: return "Proxy Sources"
        case .rule: return "Rule Sets"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: return "No materialized providers are available in the active revision."
        case .proxy: return "No materialized proxy sources are available in the active revision."
        case .rule: return "No materialized rule sets are available in the active revision."
        }
    }

    func filtered(_ rows: [ProvidersModel.Row]) -> [ProvidersModel.Row] {
        switch self {
        case .all:
            return rows
        case .proxy:
            return rows.filter { $0.kind?.lowercased() == "proxy" }
        case .rule:
            return rows.filter { $0.kind?.lowercased() == "rule" }
        }
    }
}

struct ProvidersView: View {
    @StateObject private var model: ProvidersModel
    @ObservedObject private var command: ClashCommandClient
    private let scope: ProviderDisplayScope
    @State private var importProvider: ProvidersModel.Row?
    @State private var isImporterPresented = false
    @State private var overridingProfile: Profile?

    init(
        vpn: VPNController,
        command: ClashCommandClient,
        scope: ProviderDisplayScope = .all
    ) {
        _command = ObservedObject(wrappedValue: command)
        self.scope = scope
        _model = StateObject(
            wrappedValue: ProvidersModel(vpn: vpn, command: command)
        )
    }

    var body: some View {
        HakoMacSettingsContainer {
            if let profile = model.activeProfile {
                Section {
                    Button {
                        model.refreshAll()
                    } label: {
                        if model.busy && model.busyProvider == nil {
                            ProgressView()
                        } else {
                            Label("Refresh all providers", systemImage: HakoSymbol.arrowTriangle2Circlepath.name)
                        }
                    }
                    .disabled(model.busy)
                    Button {
                        model.refreshRuntimeCatalog()
                    } label: {
                        HStack(spacing: HakoTheme.Spacing.compact) {
                             
                             
                            Label {
                                Text(hako: .copy(
                                    model.runtimeStatus.isEmpty
                                        ? "Refresh live status"
                                        : model.runtimeStatus
                                ))
                            } icon: {
                                Image(systemName: HakoSymbol.network.name)
                                    .accessibilityHidden(true)
                            }
                            Spacer()
                            if model.runtimeLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(model.runtimeLoading)
                    .accessibilityIdentifier("providers.runtime.refresh")
                    if !model.status.isEmpty {
                        if let failure = model.lastFailure {
                            ConfigurationFailureView(
                                failure: failure,
                                recover: { action in
                                    switch action {
                                    case .retry:
                                        model.retryLastFailure()
                                    case .editCredentials, .editProfile, .openProxyChains:
                                        overridingProfile = model.activeProfile
                                    case .viewDiagnostics:
                                        break
                                    }
                                }
                            )
                        } else {
                            HakoStatusMessage(text: .copy(model.status), kind: statusKind)
                        }
                    }
                } header: {
                    Text(hako: .format("Active profile · %@", [profile.label]))
                } footer: {
                    Text("Clash checks every update and keeps the current working copy if the update cannot be used.")
                }
            }

            if visibleRows.isEmpty {
                Section {
                    HakoEmptyState(
                        title: "No Providers",
                        message: scope.emptyMessage,
                        symbol: .shippingbox
                    )
                    .listRowSeparator(.hidden)
                }
            } else {
                if scope != .rule {
                    providerSection(title: "Proxy Sources", rows: proxyRows)
                }
                if scope != .proxy {
                    providerSection(title: "Rule Sets", rows: ruleRows)
                }
                if scope == .all {
                    providerSection(title: "Other Providers", rows: otherRows)
                }
            }
        }
        .hakoInsetGroupedListStyle()
        .hakoPageTitle(.copy(scope.title))
        .hakoDetailPageInsets()
        .onAppear { model.load() }
        .onChange(of: command.isConnected) { _ in
            model.refreshRuntimeCatalog()
        }
        .sheet(item: $overridingProfile) { profile in
            ProfileOverrideView(profile: profile, rawYAML: nil) {
                model.updateActiveProfile($0)
            }
            .hakoModalPresentation(.page)
        }
        .sheet(isPresented: Binding(
            get: { model.batchReport != nil },
            set: { if !$0 { model.dismissBatchReport() } }
        )) {
            Group {
                if let report = model.batchReport {
                    BatchUpdateReportView(
                        report: report,
                        isRunning: model.busy,
                        cancel: { model.cancelBatchRefresh() },
                        retry: { model.retryBatchItem(id: $0) },
                        dismiss: { model.dismissBatchReport() }
                    )
                }
            }
            .hakoModalPresentation(.page)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let row = importProvider, let url = urls.first else { return }
                model.sideLoad(provider: row.name, fileURL: url)
            case .failure(let error):
                model.reportImportFailure(error)
            }
            importProvider = nil
        }
    }

    private var visibleRows: [ProvidersModel.Row] {
        scope.filtered(model.rows)
    }

    private var proxyRows: [ProvidersModel.Row] {
        model.rows.filter { $0.kind?.lowercased() == "proxy" }
    }

    private var ruleRows: [ProvidersModel.Row] {
        model.rows.filter { $0.kind?.lowercased() == "rule" }
    }

    private var otherRows: [ProvidersModel.Row] {
        model.rows.filter {
            guard let kind = $0.kind?.lowercased() else { return true }
            return kind != "proxy" && kind != "rule"
        }
    }

    private var statusKind: HakoStatusKind {
        let normalized = model.status.lowercased()
        if normalized.contains("failed") || normalized.hasPrefix("no ") { return .error }
        if normalized.contains("updating") || normalized.contains("materializing")
            || normalized.contains("loading") { return .information }
        return .success
    }

    @ViewBuilder
    private func providerSection(title: String, rows: [ProvidersModel.Row]) -> some View {
        if !rows.isEmpty {
            Section(title) {
                ForEach(rows) { row in
                    ProviderRow(
                        row: row,
                        status: statusLine(row),
                        isBusy: model.busyProvider == row.name
                            || model.healthCheckingProvider == row.name,
                        canCheckHealth: command.isConnected
                            && row.runtime?.healthCheckAvailable == true,
                        canConfigure: true,
                        checkHealth: { model.checkHealth(provider: row.name) },
                        sideLoad: {
                            importProvider = row
                            isImporterPresented = true
                        },
                        refresh: { model.refresh(provider: row.name) }
                    )
                    .disabled(
                        (model.busy && model.busyProvider != row.name)
                            || (model.healthCheckingProvider != nil
                                && model.healthCheckingProvider != row.name)
                    )
                }
            }
        }
    }

    private func statusLine(_ row: ProvidersModel.Row) -> String {
        var parts: [String] = []
        if let vehicleType = row.runtime?.vehicleType, !vehicleType.isEmpty {
            parts.append(vehicleType)
        } else if let kind = row.kind {
            parts.append(kind)
        }
        if let runtime = row.runtime {
            let singular = row.kind?.lowercased() == "rule" ? "rule" : "proxy"
            let plural = row.kind?.lowercased() == "rule" ? "rules" : "proxies"
            let unit = runtime.entryCount == 1 ? singular : plural
            parts.append("\(runtime.entryCount) \(unit)")
        } else if let count = row.count {
            parts.append("\(count) \(count == 1 ? "entry" : "entries")")
        }
        if let size = row.sizeBytes { parts.append(ByteCountFormatter.string(Int64(size))) }
        if let updatedAt = row.runtime?.updatedAt ?? row.updatedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            parts.append(formatter.localizedString(for: updatedAt, relativeTo: Date()))
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

private struct ProviderRow: View {
    let row: ProvidersModel.Row
    let status: String
    let isBusy: Bool
    let canCheckHealth: Bool
    let canConfigure: Bool
    let checkHealth: () -> Void
    let sideLoad: () -> Void
    let refresh: () -> Void

    private var isRule: Bool { row.kind?.lowercased() == "rule" }

    var body: some View {
        HStack(alignment: .top, spacing: HakoTheme.Spacing.row) {
            HakoIconWell(
                symbol: isRule ? .listBulletRectangle : .serverRack,
                tint: isRule ? .orange : .purple
            )

            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                Text(row.name)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status)
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .caption)
                    .foregroundStyle(.secondary)
                if let failure = row.loadFailureText {
                     
                     
                     
                     
                     
                    Label {
                        Text(hako: failure)
                    } icon: {
                        Image(systemName: HakoSymbol.exclamationmarkTriangle.name)
                    }
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("providers.row.loadFailure.\(row.name)")
                }
                if !isRule, let runtime = row.runtime {
                    Label(healthText(runtime), systemImage: healthSymbol(runtime).name)
                        .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .caption)
                        .foregroundStyle(healthColor(runtime))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let info = row.subscriptionInfo {
                    SubscriptionInfoView(info: info)
                }
                 
                 
                 
                if let kind = row.kind,
                   !HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                    HakoStatusBadge(
                        title: kind.capitalized,
                        tint: isRule ? .orange : .purple,
                        role: .category
                    )
                }
            }

            Spacer(minLength: HakoTheme.Spacing.compact)

            if isBusy {
                ProgressView()
                    .frame(
                        width: HakoClientUI.HakoTheme.Control
                            .minimumHitTarget,
                        height: HakoClientUI.HakoTheme.Control
                            .minimumHitTarget
                    )
            } else if canConfigure || (!isRule && canCheckHealth) {
                Menu {
                    if !isRule {
                        Button(action: checkHealth) {
                            Label("Check health", systemImage: HakoSymbol.waveformPathEcg.name)
                        }
                        .disabled(!canCheckHealth)
                        .accessibilityIdentifier("provider.health.\(row.name)")
                        if canConfigure { Divider() }
                    }
                    if canConfigure, row.canRefresh {
                        Button(action: refresh) {
                            Label("Sync provider", systemImage: HakoSymbol.arrowClockwise.name)
                        }
                        .accessibilityLabel("Refresh \(row.name)")
                        .accessibilityIdentifier("provider.refresh.\(row.name)")
                    }
                    if canConfigure {
                        Button(action: sideLoad) {
                            Label("Load local file", systemImage: HakoSymbol.squareAndArrowDown.name)
                        }
                        .accessibilityIdentifier("provider.sideload.\(row.name)")
                    }
                } label: {
                    Image(systemName: HakoSymbol.ellipsisCircle.name)
                        .font(.title3)
                        .frame(
                            width: HakoClientUI.HakoTheme.Control
                                .minimumHitTarget,
                            height: HakoClientUI.HakoTheme.Control
                                .minimumHitTarget
                        )
                }
                .accessibilityLabel("Actions for \(row.name)")
                .accessibilityIdentifier("provider.menu.\(row.name)")
            }
        }
        .padding(.vertical, HakoTheme.Spacing.tight)
    }

    private func healthText(_ runtime: ProviderRuntimeSummary) -> String {
        guard runtime.healthCheckAvailable else { return "Health check not configured" }
        if runtime.entryCount == 0 { return "No proxy health results" }
        return "\(runtime.healthyCount ?? 0) available · \(runtime.unhealthyCount ?? 0) unavailable"
    }

    private func healthSymbol(_ runtime: ProviderRuntimeSummary) -> HakoSymbol {
        guard runtime.healthCheckAvailable else { return .infoCircle }
        return (runtime.unhealthyCount ?? 0) == 0 ? .checkmarkCircleFill : .exclamationmarkTriangleFill
    }

    private func healthColor(_ runtime: ProviderRuntimeSummary) -> Color {
        guard runtime.healthCheckAvailable else { return .secondary }
        return (runtime.unhealthyCount ?? 0) == 0 ? .green : .orange
    }
}

 
 
 
 
 
enum ProviderRefreshService {
    @MainActor
    static func refresh(
        name: String,
        profile: Profile,
        store: ConfigResourceStore,
        container: URL,
        vpn: VPNController,
        command: ClashCommandClient
    ) async throws -> ProviderSideUpdateOutcome {
        try Task.checkCancellation()
        let coordinator = vpn.activationCoordinator(
            store: store,
            container: container
        )
        let publication = try await coordinator.refreshProvider(
            named: name,
            profile: profile
        )
        guard let update = publication.runtimeUpdate else {
            return .requiresFullApply
        }
        return await command.sideUpdateProvider(update)
    }
}
