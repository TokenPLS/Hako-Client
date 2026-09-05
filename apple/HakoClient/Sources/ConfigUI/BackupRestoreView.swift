import HakoClientUI
import SwiftUI
import UniformTypeIdentifiers

private struct PreparedBackupRestore: Identifiable {
    let id = UUID()
    let archive: BackupArchive
    let sourceTitle: String
}

 
 
 
 
struct BackupRestoreView: View {
    @State private var status = ""
    @State private var exportDocument: BackupDocument?
    @State private var showsImporter = false
    @State private var preparedRestore: PreparedBackupRestore?

    @State private var icloud: ICloudBackupStore?
    @State private var icloudChecked = false
    @State private var icloudBusy = false
    @State private var icloudEntries: [ICloudBackupStore.Entry] = []

    @AppStorage("backup.restore.scope", store: GlobalConfig.appGroupDefaults)
    private var restoreScopeRaw: String = BackupRestoreScope.allData.rawValue

     
    @Environment(\.hakoBackupDataScope) private var dataScope

    private var workingDir: URL? {
        BackupSandbox.workingDirectory(
            scope: dataScope,
            appGroupContainer: HakoAppIdentifiers.appGroupContainer
        )
    }

    var body: some View {
        if dataScope == .reviewUnavailable {
            reviewUnavailableBody
        } else {
            operatingBody
        }
    }

     
     
     
     
    private var reviewUnavailableBody: some View {
        HakoMacSettingsContainer {
            Section {
                Text("This review session has no disposable container, so Backup & Restore is off. It never falls back to installed data.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("backup.review.unavailable")
            }
        }
        .hakoInsetGroupedListStyle()
        .accessibilityIdentifier("backup.root")
        .hakoPageTitle("Backup & Restore")
    }

    private var operatingBody: some View {
        HakoMacSettingsContainer {
            Section("Restore Options") {
                Picker("Data", selection: $restoreScopeRaw) {
                    ForEach(BackupRestoreScope.allCases) { scope in
                        Text(hako: .copy(scope.title)).tag(scope.rawValue)
                    }
                }
                .accessibilityIdentifier("backup.restore.scope")
            }

            Section {
                if let icloud {
                    Button { backUpToICloud(store: icloud) } label: {
                        Label("Back up now", systemImage: HakoSymbol.icloudAndArrowUp.name)
                    }
                    .hakoMacFormActionChrome()
                    .disabled(icloudBusy)
                    .accessibilityIdentifier("backup.icloud.create")

                    Button { refreshICloud(store: icloud) } label: {
                        Label(
                            "Refresh backup list",
                            systemImage: HakoSymbol.arrowClockwiseIcloud.name
                        )
                    }
                    .hakoMacFormActionChrome()
                    .disabled(icloudBusy)
                    .accessibilityIdentifier("backup.icloud.refresh")

                    if icloudEntries.isEmpty {
                        Text("No iCloud backups yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(icloudEntries) { entry in
                            iCloudEntryRow(entry, store: icloud)
                        }
                    }
                } else if icloudChecked {
                    Text("iCloud unavailable — sign in to iCloud and enable iCloud Drive for Clash.")
                        .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            } header: {
                Text("iCloud")
            } footer: {
                if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                    Text("Click any backup or prior version to preview it. Remove a current backup with its trailing −; keep a conflict copy as the iCloud version with its trailing button.")
                } else {
                    Text("Tap any backup or prior version to preview it. Swipe a current backup left to delete it; swipe a conflict copy right to keep it as the iCloud version.")
                }
            }

            Section {
                Button {
                    guard let workingDir else { return }
                    do {
                        exportDocument = BackupDocument(
                            archive: try BackupArchive.collect(workingDir: workingDir)
                        )
                    } catch {
                        status = "Export failed: \(error.localizedDescription)"
                    }
                } label: {
                    Label("Export backup file", systemImage: HakoSymbol.squareAndArrowUp.name)
                }
                .hakoMacFormActionChrome()
                .accessibilityIdentifier("backup.local.export")

                Button { showsImporter = true } label: {
                    Label("Import backup file", systemImage: HakoSymbol.squareAndArrowDown.name)
                }
                .hakoMacFormActionChrome()
                .accessibilityIdentifier("backup.local.import")
            } header: {
                Text("Local")
            } footer: {
                Text("Includes everything a profile needs to run — sources, scripts, overrides and credentials — so restoring on another device works straight away. App settings stay on this device and are not in the file. Keep the file where you keep your own private data.")
            }

            if !status.isEmpty {
                Section("Last Operation") {
                    HakoStatusMessage(text: .copy(status), kind: statusKind)
                        .accessibilityIdentifier("backup.status")
                }
            }
        }
        .hakoInsetGroupedListStyle()
         
         
         
         
         
        .accessibilityIdentifier("backup.root")
        .hakoPageTitle("Backup & Restore")
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { if !$0 { exportDocument = nil } }
            ),
            document: exportDocument,
            contentType: .json,
            defaultFilename: "hako-backup"
        ) { result in
            switch result {
            case .success: status = "Backup exported"
            case .failure(let error): status = "Export failed: \(error.localizedDescription)"
            }
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.json]
        ) { result in
            importLocal(result)
        }
        .hakoProductModal(item: $preparedRestore, role: .page) { prepared in
            Group {
                if let workingDir {
                    BackupRestorePreviewSheet(
                        prepared: prepared,
                        workingDir: workingDir,
                        scopeRaw: $restoreScopeRaw,
                        onRestore: { scope in
                            performRestore(prepared, scope: scope)
                        }
                    )
                }
            }
            .hakoModalPresentation(.page)
        }
        .task { resolveICloud() }
    }

    @ViewBuilder
    private func iCloudEntryRow(
        _ entry: ICloudBackupStore.Entry,
        store: ICloudBackupStore
    ) -> some View {
         
         
         
         
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom,
           entry.kind == .conflict {
            HStack(spacing: HakoTheme.Spacing.compact) {
                iCloudEntryRowCore(entry, store: store)
                Button {
                    resolveICloudConflict(entry, store: store)
                } label: {
                    Text(HakoCopy.key("Keep Copy"))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.primary)
                .disabled(icloudBusy)
            }
        } else if entry.kind == .current {
            HakoMacDeletableRow(onDelete: {
                deleteICloud(entry, store: store)
            }) {
                iCloudEntryRowCore(entry, store: store)
            }
        } else {
            iCloudEntryRowCore(entry, store: store)
        }
    }

    @ViewBuilder
    private func iCloudEntryRowCore(
        _ entry: ICloudBackupStore.Entry,
        store: ICloudBackupStore
    ) -> some View {
        Button {
            prepareICloudRestore(entry, store: store)
        } label: {
            HStack(spacing: HakoTheme.Spacing.row) {
                Image(systemName: entrySymbol(entry).name)
                    .foregroundStyle(entryTint(entry))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.fileName)
                        .font(.body.monospaced())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(entrySubtitle(entry))
                        .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: HakoTheme.Spacing.compact)
                if let badge = entryBadge(entry) {
                    HakoStatusBadge(title: badge.title, tint: badge.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .tint(.primary)
        .disabled(icloudBusy)
        .accessibilityIdentifier("backup.icloud.restore.\(entry.id)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if entry.kind == .current {
                Button(role: .destructive) {
                    deleteICloud(entry, store: store)
                } label: {
                    Label("Delete", systemImage: HakoSymbol.trash.name)
                }
                 
                 
                 
                 
                 
                 
                .tint(.red)
                .accessibilityIdentifier("backup.icloud.delete.\(entry.id)")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if entry.kind == .conflict {
                Button {
                    resolveICloudConflict(entry, store: store)
                } label: {
                    Label("Keep Copy", systemImage: HakoSymbol.checkmarkCircle.name)
                }
                .tint(.green)
                .accessibilityIdentifier("backup.icloud.resolve.\(entry.id)")
            }
        }
    }

    private func entrySymbol(_ entry: ICloudBackupStore.Entry) -> HakoSymbol {
        switch entry.kind {
        case .conflict: return .exclamationmarkTriangle
        case .history: return .clock
        case .current:
            return entry.downloaded ? .icloudAndArrowDown : .arrowClockwiseIcloud
        }
    }

    private func entryTint(_ entry: ICloudBackupStore.Entry) -> Color {
        switch entry.kind {
        case .conflict: return .orange
        case .history: return .secondary
        case .current: return entry.downloaded ? .accentColor : .secondary
        }
    }

    private func entryBadge(
        _ entry: ICloudBackupStore.Entry
    ) -> (title: String, tint: Color)? {
        switch entry.kind {
        case .conflict: return ("Conflict", .orange)
        case .history: return ("History", .secondary)
        case .current where !entry.downloaded: return ("Download", .blue)
        case .current: return nil
        }
    }

    private func entrySubtitle(_ entry: ICloudBackupStore.Entry) -> String {
        var parts: [String] = []
        if entry.kind != .current { parts.append(entry.kind.title) }
        if let date = entry.modifiedAt {
            parts.append(date.formatted(date: .abbreviated, time: .shortened))
        }
        if let bytes = entry.byteCount {
            parts.append(ByteCountFormatter.string(bytes))
        }
        if !entry.downloaded { parts.append("Stored in iCloud") }
        return parts.isEmpty ? "Backup" : parts.joined(separator: " · ")
    }

    private func resolveICloud() {
        Task {
            let store: ICloudBackupStore?
            if BackupSandbox.usesFixtureICloud(
                scope: dataScope,
                uiTestingEnabled: false
            ) {
                 
                 
                 
                 
                store = nil
            } else {
                store = await Task.detached { ICloudBackupStore.defaultContainer() }.value
            }
            let entries = await Task.detached { store?.list() ?? [] }.value
            icloud = store
            icloudEntries = entries
            icloudChecked = true
        }
    }

    private func refreshICloud(store: ICloudBackupStore) {
        icloudBusy = true
        Task {
            icloudEntries = await Task.detached { store.list() }.value
            status = "iCloud backup list refreshed"
            icloudBusy = false
        }
    }

    private func backUpToICloud(store: ICloudBackupStore) {
        guard let workingDir else { return }
        icloudBusy = true
        status = "Backing up to iCloud…"
        Task {
            do {
                _ = try await Task.detached {
                    try store.backUp(
                        try BackupArchive.collect(workingDir: workingDir)
                    )
                }.value
                status = "Backed up to iCloud"
            } catch {
                status = "iCloud failed: \(error.localizedDescription)"
            }
            icloudEntries = await Task.detached { store.list() }.value
            icloudBusy = false
        }
    }

    private func deleteICloud(
        _ entry: ICloudBackupStore.Entry,
        store: ICloudBackupStore
    ) {
        icloudBusy = true
        Task {
            do {
                try await Task.detached { try store.delete(entry) }.value
                status = "Deleted \(entry.fileName)"
            } catch {
                status = "iCloud failed: \(error.localizedDescription)"
            }
            icloudEntries = await Task.detached { store.list() }.value
            icloudBusy = false
        }
    }

    private func resolveICloudConflict(
        _ entry: ICloudBackupStore.Entry,
        store: ICloudBackupStore
    ) {
        icloudBusy = true
        status = "Resolving iCloud conflict…"
        Task {
            do {
                try await Task.detached { try store.resolveConflict(entry) }.value
                status = "Kept selected iCloud conflict copy"
            } catch {
                status = "iCloud failed: \(error.localizedDescription)"
            }
            icloudEntries = await Task.detached { store.list() }.value
            icloudBusy = false
        }
    }

    private func prepareICloudRestore(
        _ entry: ICloudBackupStore.Entry,
        store: ICloudBackupStore
    ) {
        guard let workingDir else { return }
        icloudBusy = true
        status = entry.downloaded ? "Reading backup…" : "Requesting iCloud download…"
        Task {
            defer { icloudBusy = false }
            do {
                let outcome = try await Task.detached {
                    try store.restore(entry)
                }.value
                switch outcome {
                case .restored(let archive):
                    let scope = restoreScope
                    _ = try await Task.detached {
                        try archive.preview(
                            workingDir: workingDir,
                            scope: scope
                        )
                    }.value
                    status = ""
                    preparedRestore = PreparedBackupRestore(
                        archive: archive,
                        sourceTitle: entry.kind == .current
                            ? entry.fileName
                            : "\(entry.fileName) · \(entry.kind.title)"
                    )
                case .downloading(let name):
                    status = "\(name) is downloading from iCloud — refresh when it is available"
                    icloudEntries = await Task.detached { store.list() }.value
                case .unavailable(let name):
                    status = "\(name) is unavailable offline — reconnect and refresh"
                    icloudEntries = await Task.detached { store.list() }.value
                case .empty:
                    status = "No iCloud backups yet"
                }
            } catch {
                status = "Preview failed: \(error.localizedDescription)"
            }
        }
    }

    private var restoreScope: BackupRestoreScope {
        BackupRestoreScope(rawValue: restoreScopeRaw) ?? .allData
    }

    private func performRestore(
        _ prepared: PreparedBackupRestore,
        scope: BackupRestoreScope
    ) {
        guard let workingDir else { return }
        preparedRestore = nil
        icloudBusy = true
        status = "Restoring backup…"
        Task {
            defer { icloudBusy = false }
            do {
                let result = try await Task.detached {
                    try prepared.archive.restore(
                        workingDir: workingDir,
                        scope: scope
                    )
                }.value
                status = "Restored \(result.importedProfiles) profiles · \(result.totalProfiles) total"
                 
                 
                 
                NotificationCenter.default.post(
                    name: .hakoProfileStoreReplaced,
                    object: nil
                )
            } catch {
                status = "Restore failed; local data was rolled back: \(error.localizedDescription)"
            }
        }
    }

    private var statusKind: HakoStatusKind {
        let normalized = status.lowercased()
        if normalized.contains("failed") { return .error }
        if normalized.contains("offline") || normalized.contains("conflict") {
            return .warning
        }
        if normalized.contains("downloading") || normalized.contains("requesting")
            || normalized.contains("reading") || normalized.contains("restoring") {
            return .information
        }
        return .success
    }

    private func importLocal(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            status = "Import failed: \(error.localizedDescription)"
        case .success(let url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let archive = try BackupArchive.decode(Data(contentsOf: url))
                if let workingDir {
                    _ = try archive.preview(
                        workingDir: workingDir,
                        scope: restoreScope
                    )
                }
                preparedRestore = PreparedBackupRestore(
                    archive: archive,
                    sourceTitle: url.lastPathComponent
                )
            } catch {
                status = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

private struct BackupRestorePreviewSheet: View {
    @Environment(\.presentationMode) private var presentationMode

    let prepared: PreparedBackupRestore
    let workingDir: URL
    @Binding var scopeRaw: String
    let onRestore: (BackupRestoreScope) -> Void

    private var scope: BackupRestoreScope {
        BackupRestoreScope(rawValue: scopeRaw) ?? .allData
    }

    private var preview: Result<BackupRestorePreview, Error> {
        Result {
            try prepared.archive.preview(
                workingDir: workingDir,
                scope: scope
            )
        }
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            HakoMacSettingsContainer {
                Section("Source") {
                    Text(prepared.sourceTitle)
                        .font(.body.monospaced())
                        .lineLimit(2)
                        .accessibilityIdentifier("backup.preview.source")
                }

                Section("Restore Options") {
                    Picker("Data", selection: $scopeRaw) {
                        ForEach(BackupRestoreScope.allCases) { item in
                            Text(item.title).tag(item.rawValue)
                        }
                    }
                        .accessibilityIdentifier("backup.restore.scope")
                }

                switch preview {
                case .failure(let error):
                    Section("Preview") {
                        HakoStatusMessage(
                            text: .format("Preview failed: %@", [error.localizedDescription]),
                            kind: .error
                        )
                    }
                case .success(let preview):
                    previewSections(preview)
                }
            }
            .hakoInsetGroupedListStyle()
            
            .hakoPageTitle("Restore Preview")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    HakoSheetCloseButton {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .hakoProductModalRoot(title: "Restore Preview")
        }
    }

    @ViewBuilder
    private func previewSections(_ preview: BackupRestorePreview) -> some View {
        Section("Summary") {
            OverviewValueRow(title: "Added", value: .verbatim("\(preview.addedCount)"))
            OverviewValueRow(title: "Updated", value: .verbatim("\(preview.updatedCount)"))
            OverviewValueRow(title: "Unchanged", value: .verbatim("\(preview.unchangedCount)"))
            OverviewValueRow(title: "Removed", value: .verbatim("\(preview.removedCount)"))
            OverviewValueRow(
                title: "Profiles after restore",
                value: .verbatim("\(preview.totalProfilesAfterRestore)"))
            OverviewValueRow(
                title: "Referenced scripts",
                value: .verbatim("\(preview.referencedScriptCount)"))
            if scope == .allData {
                 
                 
                 
                 
                 
                OverviewValueRow(
                    title: "Override",
                    value: .verbatim(preview.globalConfigChanges ? "Will change" : "Unchanged")
                )
            }
        }
        .accessibilityIdentifier("backup.preview.summary")

        Section("Security") {
            HakoStatusMessage(
                text: .copy("This file carries your credentials so a restore works straight away. Treat it as private."),
                kind: .information
            )
            if preview.omittedRemoteSourceCount > 0 {
                HakoStatusMessage(
                    text: .format("%@ remote subscription link(s) were excluded. Their cached sources restore as local profiles.", [String(preview.omittedRemoteSourceCount)]),
                    kind: .information
                )
                .accessibilityIdentifier("backup.preview.omitted-remote")
            }
            if preview.rebindRequiredProviderCount > 0 {
                HakoStatusMessage(
                    text: .format(
                        "%@ provider source(s) were excluded. Those groups and rules stay empty until you point them at a source again.",
                        [String(preview.rebindRequiredProviderCount)]
                    ),
                    kind: .warning
                )
                .accessibilityIdentifier("backup.preview.rebind-required")
            }
        }

        if !preview.changes.isEmpty {
            Section("Profile Changes") {
                ForEach(preview.changes) { change in
                    HStack(spacing: HakoTheme.Spacing.row) {
                        Image(systemName: changeSymbol(change.kind).name)
                            .foregroundStyle(changeTint(change.kind))
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        Text(hako: .copy(change.label))
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        HakoStatusBadge(
                            title: change.kind.title,
                            tint: changeTint(change.kind)
                        )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("backup.preview.change.\(change.profileID)")
                }
            }
        }

        Section {
            if preview.removedCount > 0 {
                HakoStatusMessage(
                    text: .format("Restoring will remove %@ local profile(s); if it cannot finish, Clash keeps your current data.", [String(preview.removedCount)]),
                    kind: .warning
                )
            } else {
                Text("Clash replaces your data only after everything is ready; if the restore fails, your current data stays in place.")
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .caption)
                    .foregroundStyle(.secondary)
            }
            Button(role: preview.removedCount > 0 ? .destructive : nil) {
                onRestore(scope)
            } label: {
                Label(
                    "Restore \(scope.title)",
                    systemImage: HakoSymbol.arrowUturnBackward.name
                )
                .frame(maxWidth: .infinity)
            }
            .hakoPrimaryActionButtonStyle()
            .hakoCapsuleButtonBorderShape()
            .controlSize(.regular)
            .accessibilityIdentifier("backup.preview.restore")
        }
    }

    private func changeSymbol(_ kind: BackupRestorePreview.Change.Kind) -> HakoSymbol {
        switch kind {
        case .added: return .plus
        case .updated: return .arrowTriangle2Circlepath
        case .unchanged: return .checkmarkCircle
        case .removed: return .trash
        }
    }

    private func changeTint(_ kind: BackupRestorePreview.Change.Kind) -> Color {
        switch kind {
        case .added: return .green
        case .updated: return .blue
        case .unchanged: return .secondary
        case .removed: return .red
        }
    }
}

 
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var archive: BackupArchive

    init(archive: BackupArchive) { self.archive = archive }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        archive = try BackupArchive.decode(data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try archive.encoded())
    }
}
