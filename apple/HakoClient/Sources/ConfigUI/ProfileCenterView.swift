import HakoClientKit
import HakoClientUI
import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

 
 
 
 
 
struct ProfileCenterAdapter: View {
     
     
    @Environment(\.locale)
    private var locale
    @Environment(\.hakoShellLayout) private var shellLayout
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ObservedObject private var importRouter: ProfileImportRouter
     
     
     
     
     
     
    @ObservedObject private var model: ProfilesViewModel

    private let initialDestination: AppNavigationDestination
    private let onActiveRuntimeChanged: () -> Void

     
     
     
     
     
     
    private var activeFailure: ProfileSwitchAlertFailure? {
        model.lastFailure.map { ProfileSwitchAlertFailure($0) }
    }
    @State private var exportDocument: ConfigTextDocument?
    @State private var exportName = ""
    @State private var adaptationNoticeCounts: [String: Int] = [:]

     
     
    private let ownsNavigationContainer: Bool

    private let palette: HakoClientUI.HakoProductPalette

     
     
    private let listPresentation:
        ((HakoClientUI.HakoProfilesListPresentation) -> AnyView)?
     
    private let capabilityInterceptor:
        ((HakoClientUI.HakoProfilesCapabilityDestination) -> Bool)?

    init(
        profiles: ProfilesViewModel,
        importRouter: ProfileImportRouter,
        initialDestination: AppNavigationDestination = .profiles,
        ownsNavigationContainer: Bool = true,
         
         
         
         
        palette: HakoClientUI.HakoProductPalette = .hakoProduct,
        onActiveRuntimeChanged: @escaping () -> Void = {},
        capabilityInterceptor: (
            (HakoClientUI.HakoProfilesCapabilityDestination) -> Bool
        )? = nil,
        listPresentation: (
            (HakoClientUI.HakoProfilesListPresentation) -> AnyView
        )? = nil
    ) {
        self.ownsNavigationContainer = ownsNavigationContainer
        self.importRouter = importRouter
        self.initialDestination = initialDestination
        self.palette = palette
        self.onActiveRuntimeChanged = onActiveRuntimeChanged
        self.listPresentation = listPresentation
        self.capabilityInterceptor = capabilityInterceptor
        _model = ObservedObject(wrappedValue: profiles)
    }

    var body: some View {
        HakoOptionalNavigationContainer(owns: ownsNavigationContainer) {
            HakoClientUI.HakoProfilesView(
                snapshot: sharedSnapshot,
                actions: sharedActions,
                initialProfileID: initialProfileID,
                opensImportInitially: opensImportInitially,
                presentationClass:
                    shellLayout == .regularSidebar
                        ? .regularTouch
                        : .compactTouch,
                showsDismissControl: ownsNavigationContainer,
                palette: productPalette,
                pagePresentation: { content in
                    AnyView(
            content
                    )
                },
                listPresentation: listPresentation,
                capabilityInterceptor: capabilityInterceptor,
                icon: { symbol in
                    HakoSymbolImage(symbol: symbol)
                },
                capabilityContent: { destination in
                    capabilityView(destination)
                }
            )
        }
        .alert(
            isPresented: Binding(
                get: { activeFailure != nil },
                set: { if !$0 { model.dismissFailure() } }
            ),
            error: activeFailure
        ) { _ in
             
             
             
            if model.lastFailure?.recoveryActions.contains(.retry) == true {
                Button("Try Again") { model.retryLastFailure() }
            }
            Button("OK", role: .cancel) { model.dismissFailure() }
        } message: { failure in
            Text(verbatim: failure.messageText)
        }
        .fileExporter(
            isPresented: Binding(
                get: { exportDocument != nil },
                set: { presented in
                    if !presented {
                        exportDocument = nil
                    }
                }
            ),
            document: exportDocument,
            contentType: .yaml,
            defaultFilename: exportName
        ) { _ in
            exportDocument = nil
        }
        .onAppear {
            model.load()
            model.selectSoleProfileIfNeeded()
            importRouter.importSharedFiles()
        }
        .onReceive(
            importRouter.$pendingImport.compactMap { $0 }
        ) { _ in
             
             
            if let request = importRouter.take() { consume(request) }
        }
        .task(id: activeRevisionKey) {
            await loadAdaptationNoticeCount()
        }
    }

    private var initialProfileID: HakoClientKit.Profile.ID? {
        guard case .profileDetail(let rawID) = initialDestination else {
            return nil
        }
        return try? HakoClientKit.Profile.ID(rawID)
    }

    private var opensImportInitially: Bool {
        initialDestination == .profileImport
    }

    private var productPalette: HakoClientUI.HakoProductPalette {
        palette
    }

    private var sharedSnapshot: AppleClientSnapshot {
        AppleClientSnapshot(
            revision: 0,
            connection: AppleClientConnectionSnapshot(
                phase: .unavailable
            ),
            profiles: HakoProfilesSnapshot(
                profiles: model.profiles.compactMap(profileSnapshot),
                 
                 
                 
                 
                 
                 
                 
                 
                 
                failure: nil,
                statusMessage: model.statusMessage,
                batchReport: model.batchReport.map(batchSnapshot)
            ),
            capabilities: AppleClientCapabilities([
                .profiles: .available,
            ])
        )
    }

    private var sharedActions: AppleClientActions {
        AppleClientActions(
            resultCapability: .profiles
        ) { action in
            guard case .profiles(let command) = action else {
                return .none
            }
            return try await handle(command)
        }
    }

    private func profileSnapshot(
        _ profile: Profile
    ) -> HakoProfileSnapshot? {
        guard let id = try? HakoClientKit.Profile.ID(profile.id) else {
            return nil
        }
        let isCurrent = profile.id == model.activeProfileID
        let canDelete = ProfileCenterPolicy.canDelete(
            profileID: profile.id,
            activeProfileID: model.activeProfileID
        )

        return HakoProfileSnapshot(
            id: id,
            label: profile.label,
            source: sourceKind(profile.source),
            sourceSummary: sourceSummary(profile),
            subscription: profile.subscriptionInfo.map {
                HakoProfileSubscriptionSnapshot(
                    uploadBytes: $0.upload,
                    downloadBytes: $0.download,
                    totalBytes: $0.total,
                    expiration: $0.expire > 0
                        ? Date(
                            timeIntervalSince1970:
                                TimeInterval($0.expire)
                        )
                        : nil
                )
            },
            lastUpdatedAt: profile.lastUpdatedAt,
            autoUpdate: profile.autoUpdate,
            updateIntervalHours: profile.updateIntervalHours,
            isCurrent: isCurrent,
            isBusy: profile.id == model.busyProfileID,
            canEditSource: model.hasEditableSource(for: profile),
            canDelete: canDelete,
            deleteSubtitle: deleteSubtitle(
                profile,
                canDelete: canDelete
            ),
            runtimeSummary: runtimeSummary(profile),
            requiresPlaintextExportConfirmation:
                profile.externalResources?.isEmpty == false,
            featureAvailability: featureAvailability(profile),
            heldBackUpdates: (profile.suppressedUpdates ?? []).map {
                HakoProfileHeldBackUpdate(
                    keyPath: $0.keyPath,
                    change: HakoProfileHeldBackUpdate.Change(rawValue: $0.change.rawValue) ?? .changed,
                    newValue: $0.newValue,
                    appValue: $0.appValue
                )
            }
        )
    }

     
     
     
     
     
     
     
    private func featureAvailability(
        _ profile: Profile
    ) -> HakoProfileFeatureAvailabilitySnapshot {
        let isRemote: Bool
        if case .url = profile.source {
            isRemote = true
        } else {
            isRemote = false
        }
        return HakoProfileFeatureAvailabilitySnapshot(
            canSync: isRemote,
            canConfigureSubscription: isRemote,
            canCopySubscriptionLink: isRemote,
            canExport: model.hasEditableSource(for: profile),
            canOpenRuntimePreview: true
        )
    }

    private func sourceKind(
        _ source: Profile.Source
    ) -> HakoProfileSourceKind {
        switch source {
        case .url:
            .remote
        case .file:
            .file
        case .clipboard:
            .clipboard
        }
    }

    private func sourceSummary(_ profile: Profile) -> HakoDisplayText {
        switch profile.source {
        case .url(let rawURL):
            let host = SubscriptionURLPresentation.hostDescription(
                rawURL,
                locale: locale
            )
            if let updated = profile.lastUpdatedAt {
                return .verbatim(
                    "\(host) · \(updated.formatted(.relative(presentation: .named)))"
                )
            }
            return .verbatim(host)
        case .file:
            return "Local · Imported file"
        case .clipboard:
            return "Local · Manually managed"
        }
    }

    private func deleteSubtitle(
        _ profile: Profile,
        canDelete: Bool
    ) -> HakoDisplayText {
        if profile.id == LocalDefaultProfileProvisioner.profileID {
            return "Clash keeps Direct as a safe system fallback"
        }
        return canDelete
            ? "Remove this profile from Clash"
            : "Switch to another profile before deleting"
    }

    private func runtimeSummary(_ profile: Profile) -> HakoDisplayText {
        if profile.id == model.activeProfileID,
           let count = adaptationNoticeCounts[profile.id],
           let summary = ProfileAdaptationPresenter.summary(
               noticesCount: count,
               locale: locale
           ) {
             
             
             
            return .verbatim(
                summary + " · " + HakoCopy.string("read-only", locale: locale)
            )
        }
        return "Local cache · read-only"
    }

    private func batchSnapshot(
        _ report: BatchUpdateReport
    ) -> HakoProfileBatchReportSnapshot {
        HakoProfileBatchReportSnapshot(
            id: report.id,
            title: report.title,
            expectedCount: report.expectedCount,
            items: report.items.compactMap { item in
                guard let id = try? HakoClientKit.Profile.ID(
                    item.id
                ) else {
                    return nil
                }
                return HakoProfileBatchItemSnapshot(
                    id: id,
                    label: item.label,
                    state: batchState(item.state),
                    message:
                        item.failure?.message
                        ?? item.message
                        ?? item.state.title,
                    diagnosticCode:
                        item.failure?.diagnosticCode
                )
            },
            wasCancelled: report.wasCancelled,
            isRunning: model.isBatchSyncing
        )
    }

    private func batchState(
        _ state: BatchUpdateState
    ) -> HakoProfileBatchUpdateState {
        switch state {
        case .updated:
            .updated
        case .unchanged:
            .unchanged
        case .failed:
            .failed
        }
    }

    @ViewBuilder
    private func capabilityView(
        _ destination: HakoProfilesCapabilityDestination
    ) -> some View {
        switch destination {
        case .importProfile:
            AddProfileView(
                 
                 
                createEmpty: { Task { _ = try? await handle(.createEmpty) } }
            ) { label, source, rawYAML, resources in
                model.add(
                    label: label,
                    source: source,
                    rawYAML: rawYAML,
                    resourceFiles: resources
                )
                model.selectSoleProfileIfNeeded()
            }
        case .backupRestore:
            BackupRestoreView()
        case .subscriptionSettings(let id):
            if let profile = appProfile(id) {
                ProfileSubscriptionSettingsAdapter(
                    profile: profile,
                    model: model
                )
            } else {
                EmptyView()
            }
        case .rules(let id):
            if let profile = appProfile(id) {
                 
                 
                ProfileRulesAdapter(
                    profile: profile,
                    sourceYAML: model.uiProjectedYAML(for: profile)
                ) { draft in
                    try model.updateRules(draft)
                }
            } else {
                EmptyView()
            }
        case .override(let id):
            if let profile = appProfile(id) {
                ProfileOverrideView(
                    profile: profile,
                    rawYAML: model.uiProjectedYAML(for: profile)
                ) { updated in
                    model.update(updated)
                }
            } else {
                EmptyView()
            }
        case .sourceEditor(let id):
            if let profile = appProfile(id) {
                 
                 
                 
                 
                 
                 
                 
                ProfileSourceEditorLoader(profile: profile, model: model)
            } else {
                EmptyView()
            }
        case .runtimePreview(let id):
            if let profile = appProfile(id) {
                ProfilePreviewView(title: .verbatim(profile.label)) {
                    await model.loadCachedPreviewText(
                        for: profile.id
                    )
                }
            } else {
                EmptyView()
            }
        }
    }

    private func appProfile(
        _ id: HakoClientKit.Profile.ID
    ) -> Profile? {
        model.profiles.first { $0.id == id.rawValue }
    }

    private func handle(
        _ command: HakoProfilesCommand
    ) async throws -> AppleClientActionResult {
        switch command {
        case .createEmpty:
            guard let profile = model.addDirectProfile(),
                  let id = try? HakoClientKit.Profile.ID(
                      profile.id
                  ) else {
                return .none
            }
            model.selectSoleProfileIfNeeded()
            return .profileCreated(id: id)

        case .openImport, .openBackup, .openSourceEditor,
             .openRuntimePreview, .restoreLastKnownGood:
            return .none

        case .syncAll:
            model.syncAll()
            return .none

        case .select(let id):
            guard let profile = appProfile(id) else {
                return .none
            }
             
             
             
             
             
            let succeeded = await model.selectAndWait(profile)
            guard !Task.isCancelled else {
                throw CancellationError()
            }
            if succeeded {
                onActiveRuntimeChanged()
#if canImport(UIKit)
                UINotificationFeedbackGenerator()
                    .notificationOccurred(.success)
#endif
                return .profileSelected(id: id)
            }
            if model.lastFailure != nil {
                 
                 
                 
                return .profileSelectionFailurePresented
            }
            return .none

        case .reorder(let ids):
            applyOrder(ids)
            return .none

        case .sync(let id):
            if let profile = appProfile(id) {
                model.sync(profile)
            }
            return .none
        case let .adoptHeldBackUpdate(id, keyPath):
            if let profile = appProfile(id) {
                try model.adoptHeldBackUpdate(profile, keyPath: keyPath)
                onActiveRuntimeChanged()
            }
            return .none
        case .dismissHeldBackUpdates(let id):
            if let profile = appProfile(id) {
                try model.dismissHeldBackUpdates(profile)
            }
            return .none

        case let .rename(id, label):
            guard let profile = appProfile(id) else {
                return .none
            }
            try model.updateMetadata(
                profile,
                label: label,
                subscriptionURL: subscriptionURL(profile),
                autoUpdate: profile.autoUpdate,
                updateIntervalHours: profile.updateIntervalHours
            )
            return .none

        case let .saveSubscription(
            id,
            url,
            autoUpdate,
            intervalHours
        ):
            guard let profile = appProfile(id) else {
                return .none
            }
            try model.updateMetadata(
                profile,
                label: profile.label,
                subscriptionURL: url,
                autoUpdate: autoUpdate,
                updateIntervalHours: intervalHours
            )
            return .none

        case .copySubscriptionLink(let id):
            if let profile = appProfile(id) {
#if os(macOS)
                if let link = model.subscriptionLink(for: profile) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        link,
                        forType: .string
                    )
                }
#else
                UIPasteboard.general.string =
                    model.subscriptionLink(for: profile)
#endif
            }
            return .none

        case .duplicate(let id):
             
             
             
             
            guard let profile = appProfile(id) else { return .none }
            guard let copy = await model.duplicate(profile),
                  let copyID = try? HakoClientKit.Profile.ID(copy.id)
            else {
                 
                 
                 
                return .profileActionRefused(reason: model.statusMessage)
            }
            return .profileCreated(id: copyID)

        case .export(let id):
            guard let profile = appProfile(id) else {
                return .none
            }
            guard let (name, text) =
                await model.loadCachedExportDocument(
                    for: profile.id
                ) else {
#if os(macOS)
                presentMacExportUnavailableAlert()
#endif
                return .none
            }
#if os(macOS)
            presentMacExportPanel(
                defaultFilename: name,
                text: text
            )
#else
            exportName = name
            exportDocument = ConfigTextDocument(text: text)
#endif
            return .none

        case .delete(let id):
            guard let profile = appProfile(id) else {
                return .none
            }
            model.delete(profile)
            return model.profiles.contains {
                $0.id == id.rawValue
            }
                ? .profileActionRefused(reason: model.statusMessage)
                : .profileDeleted(id: id)

        case .retryFailure:
            model.retryLastFailure()
            return .none

        case .cancelBatch:
            model.cancelBatchSync()
            return .none

        case .retryBatchItem(let id):
            model.retryBatchItem(id: id.rawValue)
            return .none

        case .dismissBatch:
            model.dismissBatchReport()
            return .none
        }
    }

#if os(macOS)
     
     
     
    private func presentMacExportUnavailableAlert() {
        let alert = NSAlert()
        alert.messageText = HakoCopy.string(
            "No Local Configuration",
            locale: locale
        )
        alert.informativeText = HakoCopy.string(
            "Sync or import this profile to cache its configuration on this device.",
            locale: locale
        )
        alert.addButton(
            withTitle: HakoCopy.string("Done", locale: locale)
        )
        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

     
     
     
     
    private func presentMacExportPanel(
        defaultFilename: String,
        text: String
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.yaml]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultFilename

        let completion: (NSApplication.ModalResponse) -> Void = {
            response in
            guard response == .OK, let destination = panel.url else {
                return
            }
            try? text.write(
                to: destination,
                atomically: true,
                encoding: .utf8
            )
        }

        if let window = NSApp.keyWindow {
            panel.beginSheetModal(
                for: window,
                completionHandler: completion
            )
        } else {
            panel.begin(completionHandler: completion)
        }
    }
#endif

    private func applyOrder(
        _ desiredIDs: [HakoClientKit.Profile.ID]
    ) {
        let desired = desiredIDs.map(\.rawValue)
        guard desired.count == model.profiles.count,
              Set(desired) == Set(model.profiles.map(\.id)) else {
            return
        }

        for targetIndex in desired.indices {
            guard let currentIndex = model.profiles.firstIndex(
                where: { $0.id == desired[targetIndex] }
            ), currentIndex != targetIndex else {
                continue
            }
            model.move(
                from: IndexSet(integer: currentIndex),
                to:
                    currentIndex < targetIndex
                        ? targetIndex + 1
                        : targetIndex
            )
        }
    }

    private func subscriptionURL(_ profile: Profile) -> String? {
        if case .url(let url) = profile.source {
            return url
        }
        return nil
    }

    private func consume(_ request: ProfileImportRequest) {
        switch request {
        case .subscription(let subscription):
            model.installSubscription(subscription)
        case let .configuration(fileName, yaml):
            let label = URL(fileURLWithPath: fileName)
                .deletingPathExtension()
                .lastPathComponent
            model.add(
                label:
                    label.isEmpty
                        ? "Imported Configuration"
                        : label,
                source: .file(fileName),
                rawYAML: yaml
            )
        }
        model.selectSoleProfileIfNeeded()
    }

    private var activeRevisionKey: String {
        guard let activeID = model.activeProfileID,
              let revision = model.profiles.first(
                  where: { $0.id == activeID }
              )?.activeRevision else {
            return ""
        }
        return "\(activeID)|\(revision)"
    }

    private func loadAdaptationNoticeCount() async {
        guard let activeID = model.activeProfileID,
              model.profiles.first(
                  where: { $0.id == activeID }
              )?.activeRevision != nil,
              let container = HakoAppIdentifiers.appGroupContainer else {
            adaptationNoticeCounts = [:]
            return
        }

        let count = await Task.detached(
            priority: .utility
        ) { () -> Int in
            guard let store = try? ConfigResourceStore(
                containerURL: container
            ),
                let activeYAML = try? store.loadCurrent().text
            else {
                return 0
            }
            return (
                try? ConfigTransforms.planResources(
                    mergedYAML: activeYAML
                ).notices.count
            ) ?? 0
        }.value
        adaptationNoticeCounts = [activeID: count]
    }
}

 
 
typealias ProfileCenterView = ProfileCenterAdapter

 
enum ProfileAdaptationPresenter {
    static func summary(noticesCount: Int, locale: Locale) -> String? {
        guard noticesCount > 0 else {
            return nil
        }
        return HakoCopy.format(
            "%d items adapted automatically",
            locale: locale,
            noticesCount
        )
    }
}

 
 
 
private struct ProfileSubscriptionSettingsAdapter: View {
    let profile: Profile
    @ObservedObject var model: ProfilesViewModel

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoProductModalDismiss)
    private var productModalDismiss
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @State private var subscriptionURL: String
    @State private var autoUpdate: Bool
    @State private var updateIntervalHours: Int
    @State private var errorMessage = ""
     
     
     
    @State private var openedWith: (url: String, auto: Bool, hours: Int)?

    init(profile: Profile, model: ProfilesViewModel) {
        self.profile = profile
        self.model = model
        if case .url(let url) = profile.source {
             
             
             
            _subscriptionURL = State(
                initialValue: ProfileImportRouter.confirmationText(for: url)
            )
        } else {
            _subscriptionURL = State(initialValue: "")
        }
        _autoUpdate = State(initialValue: profile.autoUpdate)
        _updateIntervalHours = State(
            initialValue: profile.updateIntervalHours
        )
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            Form {
                Section {
                     
                     
                     
                     
                     
                    TextField(
                        "",
                        text: $subscriptionURL,
                        prompt: Text(verbatim: "https://example.com/subscription")
                    )
                    .labelsHidden()
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("profile-metadata.url")

                    Toggle(
                        "Automatic Updates",
                        isOn: $autoUpdate
                    )
                    .accessibilityIdentifier(
                        "profile-metadata.auto-update"
                    )

                    if autoUpdate {
                        Stepper(
                            value: $updateIntervalHours,
                            in: 1...168
                        ) {
                            HStack {
                                Text("Interval")
                                Spacer()
                                Text(
                                    "\(updateIntervalHours) hours"
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier(
                            "profile-metadata.interval"
                        )
                    }
                } header: {
                    Text("Subscription")
                } footer: {
                    Text(
                        "Changing the link clears cached update metadata. The current working revision remains available if the next sync fails."
                    )
                }

                if ProfileMetadataUpdate.strippingSourceCredentials(
                    from: profile
                ) != nil {
                    Section {
                        Button(role: .destructive) {
                            stripStoredCredentials()
                        } label: {
                            Text("Remove Stored Link Credentials")
                        }
                        .accessibilityIdentifier("profile-metadata.strip-credentials")
                    } footer: {
                        Text(
                            "The saved link carries sign-in details or query values. Removing them keeps the scheme, host and path only, and may require re-importing if the provider needs them."
                        )
                    }
                }

                if !errorMessage.isEmpty {
                    Section {
                        HakoStatusMessage(
                            text: .copy(errorMessage),
                            kind: .error
                        )
                    }
                }
            }
            .hakoPageTitle("Subscription Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !insideProductModal {
                        Button("Cancel") {
                            dismissPresentation()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                        Button("Save") {
                            save()
                        }
                        .accessibilityIdentifier(
                            "profile-metadata.save"
                        )
                    }
                }
            }
            .hakoProductModalRoot(title: "Subscription Settings")
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                     
                    HakoModalActionBar(
                        primaryTitle: "Save",
                        primaryDisabled: !hasChanges,
                        onPrimary: save
                    )
                }
            }
        }
        .hakoStackNavigationViewStyle()
        .hakoCapturesDismiss(dismiss)
        .onAppear {
            if openedWith == nil {
                openedWith = (subscriptionURL, autoUpdate, updateIntervalHours)
            }
        }
    }

    private func stripStoredCredentials() {
        do {
            try model.stripSourceCredentials(profile)
            dismissPresentation()
        } catch {
            errorMessage =
                (error as? LocalizedError)?.errorDescription
                ?? "Profile settings could not be saved."
        }
    }

     
    private var hasChanges: Bool {
        guard let openedWith else { return false }
        return openedWith.url != subscriptionURL
            || openedWith.auto != autoUpdate
            || openedWith.hours != updateIntervalHours
    }

    private func save() {
        do {
            try model.updateMetadata(
                profile,
                label: profile.label,
                subscriptionURL: subscriptionURL,
                autoUpdate: autoUpdate,
                updateIntervalHours: updateIntervalHours
            )
            dismissPresentation()
        } catch {
            errorMessage =
                (error as? LocalizedError)?.errorDescription
                ?? "Profile settings could not be saved."
        }
    }

    private func dismissPresentation() {
        (productModalDismiss ?? { dismiss() })()
    }
}

 
 
 
 
 
struct HakoOptionalNavigationContainer<Content: View>: View {
    let owns: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        if owns {
             
             
             
             
            if #available(iOS 16.0, *) {
                 
                 
                 
                 
                 
                HakoPushableNavigationStack { content() }
            } else {
                NavigationView { content() }
                    .hakoStackNavigationViewStyle()
            }
        } else {
            content()
        }
    }
}


 
@available(iOS 16.0, *)
private struct HakoPushableNavigationStack<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) { content() }
            .environment(
                \.hakoPushRoute,
                HakoClientUI.HakoRoutePusher { route in
                    path.append(route)
                }
            )
    }
}


 
 
 
 
 
 
private struct ProfileSourceEditorLoader: View {
    let profile: Profile
    @ObservedObject var model: ProfilesViewModel
    @State private var source: String?
    @State private var read = false

    var body: some View {
        Group {
            if read {
                ProfileEditView(
                    profile: profile,
                    rawYAML: source
                ) { updated, rawYAML, resources, disablingAutoUpdate in
                    try await model.updateEdited(
                        updated,
                        sourceYAML: rawYAML,
                        resourceFiles: resources,
                        disablingAutoUpdate: disablingAutoUpdate
                    )
                }
            } else {
                VStack(spacing: HakoTheme.Spacing.compact) {
                    Spacer()
                    ProgressView()
                    Text(hako: .copy("Opening Editor"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HakoTheme.canvas.ignoresSafeArea())
                .accessibilityIdentifier("profile.sourceEditor.loading")
            }
        }
        .task(id: profile.id) {
            source = await model.loadSourceYAML(for: profile)
            read = true
        }
    }
}
