import Foundation
import HakoClientKit
import SwiftUI

public enum HakoProfilesCapabilityDestination:
    Hashable,
    Identifiable,
    Sendable
{
    case importProfile
    case backupRestore
    case subscriptionSettings(Profile.ID)
    case sourceEditor(Profile.ID)
    case runtimePreview(Profile.ID)
     
     
     
     
     
    case rules(Profile.ID)
    case override(Profile.ID)

     
     
     
     
     
    public var presentsImmersively: Bool {
        if case .sourceEditor = self { return true }
        return false
    }

    public var id: String {
        switch self {
        case .importProfile:
            "import"
        case .backupRestore:
            "backup"
        case .subscriptionSettings(let id):
            "subscription|\(id.rawValue)"
        case .rules(let id):
            "rules|\(id.rawValue)"
        case .override(let id):
            "override|\(id.rawValue)"
        case .sourceEditor(let id):
            "source|\(id.rawValue)"
        case .runtimePreview(let id):
            "runtime|\(id.rawValue)"
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoProfilesListPresentation {
    public let profiles: [HakoProfileSnapshot]
     
     
     
    public let selectingProfileID: Profile.ID?
     
     
    public let selectionFailure: (Profile.ID) -> HakoDisplayText?
    public let select: (Profile.ID) -> Void
    public let openDetail: (Profile.ID) -> Void
     
     
     
     
    public let openImport: () -> Void
     
     
    public let reorder: ([Profile.ID]) -> Void
    public let perform: (HakoProfilesCommand) -> Void
}

 
 
 
 
 
 
public struct HakoProfilesView<Icon: View, CapabilityContent: View>: View {
    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let presentationClass: HakoPresentationClass
     
    private let showsDismissControl: Bool
    private let palette: HakoProductPalette
    private let opensImportInitially: Bool
    private let pagePresentation: (AnyView) -> AnyView
    private let icon: (HakoSymbol) -> Icon
    private let capabilityContent:
        (HakoProfilesCapabilityDestination) -> CapabilityContent
     
     
     
    private let capabilityInterceptor:
        ((HakoProfilesCapabilityDestination) -> Bool)?
     
     
     
     
    private let listPresentation:
        ((HakoProfilesListPresentation) -> AnyView)?

     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var requestedProfileID: Profile.ID?
    @Environment(\.hakoPushRoute) private var pushRoute
    @Environment(\.hakoPopRoute) private var popRoute
    @State private var activeCapability:
        HakoProfilesCapabilityDestination?
    @State private var showsReorder = false
    @State private var displayedProfiles: [HakoProfileSnapshot]
    @State private var draggedProfileID: String?
    @State private var reorderDropTarget: HakoReorderDropTarget?
    @State private var pendingSelectionID: Profile.ID?
    @State private var selectionFailure: HakoProfileSelectionFailure?
    @State private var didPresentInitialImport = false

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        initialProfileID: Profile.ID? = nil,
        opensImportInitially: Bool = false,
        presentationClass: HakoPresentationClass,
        showsDismissControl: Bool = true,
        palette: HakoProductPalette,
        pagePresentation: @escaping (AnyView) -> AnyView = { $0 },
        listPresentation:
            ((HakoProfilesListPresentation) -> AnyView)? = nil,
        capabilityInterceptor:
            ((HakoProfilesCapabilityDestination) -> Bool)? = nil,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        @ViewBuilder capabilityContent: @escaping (
            HakoProfilesCapabilityDestination
        ) -> CapabilityContent
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.presentationClass = presentationClass
        self.showsDismissControl = showsDismissControl
        self.palette = palette
        self.opensImportInitially = opensImportInitially
        self.pagePresentation = pagePresentation
        self.listPresentation = listPresentation
        self.capabilityInterceptor = capabilityInterceptor
        self.icon = icon
        self.capabilityContent = capabilityContent
        _requestedProfileID = State(initialValue: initialProfileID)
        _displayedProfiles = State(
            initialValue: snapshot.profiles.profiles
        )
    }

    public var body: some View {
        pagePresentation(AnyView(routedRootPage))
            .hakoProductModal(
                item: $activeCapability,
                role: .page,
                immersive: { $0.presentsImmersively }
            ) { destination in
                capabilityContent(destination)
                    .hakoModalPresentation(.page)
            }
            .hakoProductModal(
                isPresented: $showsReorder,
                role: .form
            ) {
                HakoProfileReorderView(
                    profiles: snapshot.profiles.profiles,
                    snapshot: snapshot,
                    actions: actions,
                    palette: palette
                )
                .hakoModalPresentation(.form)
            }
            .hakoProductModal(
                isPresented: Binding(
                    get: { snapshot.profiles.batchReport != nil },
                    set: { presented in
                        if !presented {
                            send(.dismissBatch)
                        }
                    }
                ),
                role: .page,
                refreshID: batchModalRefreshID
            ) {
                Group {
                    if let report = snapshot.profiles.batchReport {
                        HakoProfileBatchReportView(
                            report: report,
                            snapshot: snapshot,
                            actions: actions,
                            icon: icon
                        )
                    }
                }
                .hakoModalPresentation(.page)
            }
            .onAppear {
                guard opensImportInitially, !didPresentInitialImport else {
                    return
                }
                didPresentInitialImport = true
                activeCapability = .importProfile
            }
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
    private var batchModalRefreshID: AnyHashable {
        guard let report = snapshot.profiles.batchReport else {
            return AnyHashable(["profile-batch", "none"])
        }
        var components = [
            "profile-batch",
            report.id.uuidString,
            report.title,
            String(report.expectedCount),
            report.wasCancelled ? "cancelled" : "active",
            report.isRunning ? "running" : "finished",
        ]
        components.append(contentsOf: report.items.flatMap { item in
            [
                item.id.rawValue,
                item.label,
                item.state.rawValue,
                item.message,
                item.diagnosticCode ?? "",
            ]
        })
        return AnyHashable(components)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private var routedRootPage: some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            rootPage
                .navigationDestination(
                    for: HakoProfileRoute.self
                ) { route in
                    HakoLazyView {
                        switch route {
                        case .detail(let id):
                            pagePresentation(
                                AnyView(
                                    HakoProfileDetailView(
                                        profileID: id,
                                        snapshot: snapshot,
                                        actions: actions,
                                        presentationClass: presentationClass,
                                        palette: palette,
                                        pagePresentation: pagePresentation,
                                        capabilityInterceptor: capabilityInterceptor,
                                        icon: icon,
                                        capabilityContent: capabilityContent
                                    )
                                )
                            )
                            .hakoPushedDetailPage()
                            .environment(\.hakoPushRoute, pushRoute)
                            .environment(\.hakoPopRoute, popRoute)
                            .modifier(HakoSetterRoutedBack())
                             
                             
                             
                            .environment(
                                \.hakoRegularShellOwnsCanvas,
                                presentationClass == .regularTouch
                                    || presentationClass == .desktop
                            )
                        }
                    }
                }
        } else {
            rootPage
        }
    }

     
     
     
     
     
    @ViewBuilder
    private var rootPageContent: some View {
        if let listPresentation {
            listPresentation(
                HakoProfilesListPresentation(
                    profiles: displayedProfiles,
                    selectingProfileID: pendingSelectionID,
                    selectionFailure: { id in
                        selectionFailure?.profileID == id
                            ? selectionFailure?.message
                            : nil
                    },
                     
                     
                     
                     
                    select: { id in
                        guard let profile = displayedProfiles.first(where: {
                            $0.id == id
                        }) else { return }
                        performSelection(profile, closesPage: false)
                    },
                    openDetail: { pushRoute?(HakoProfileRoute.detail($0)) },
                    openImport: { activeCapability = .importProfile },
                    reorder: applyReorder,
                    perform: send
                )
            )
        } else {
            ownRootPage
        }
    }

    private var ownRootPage: some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "profile-center.root"
        ) {
            profilesSection
            if snapshot.profiles.canCreateEmpty
                || snapshot.profiles.canImport
            {
                addSection
            }
            if snapshot.profiles.canBackup {
                dataSection
            }
            failureSection
        }
    }

    private var rootPage: some View {
        rootPageContent
        .background(initialDetailLink)
        .environment(\.hakoDetailCanvas, palette.canvas)
        .onChange(of: snapshot.profiles.profiles) { profiles in
             
             
             
             
            selectionFailure = nil
            displayedProfiles = profiles
        }
         
         
         
        .modifier(
            HakoProfilesRootTitleModifier(
                showsDismissControl: showsDismissControl
            )
        )
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .cancellationAction) {
                 
                 
                if showsDismissControl {
                    HakoSheetCloseButton {
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .primaryAction) {
                 
                 
                 
                 
                 
                 
                 
                if showsReorderControl || showsAddControl {
                    ControlGroup {
                        if showsReorderControl {
                            Button {
                                showsReorder = true
                            } label: {
                                icon(.arrowUpArrowDown)
                                    .hakoToolbarGlyph()
                            }
                            .accessibilityLabel("Reorder Profiles")
                            .accessibilityIdentifier("profile-center.reorder")

                             
                             
                             
                             
                            if showsAddControl {
                                HakoToolbarDivider()
                            }
                        }

                        if showsAddControl {
                             
                             
                             
                             
                             
                             
                             
                            Button {
                                activeCapability = .importProfile
                            } label: {
                                icon(.plusCircle)
                                    .hakoToolbarGlyph()
                            }
                            .accessibilityLabel("Add Profile")
                            .accessibilityIdentifier(
                                "profile-center.add.toolbar"
                            )
                        }
                    }
                    .hakoReaderControlGroupStyle()
                }
            }
        }
    }

     
     
    private var showsReorderControl: Bool {
        HakoPlatformLayout.profileReorderingUsesDedicatedTask
            && snapshot.profiles.canReorder
            && snapshot.profiles.profiles.count > 1
    }

     
     
     
     
     
     
     
     
    private var showsAddControl: Bool {
        listPresentation == nil
            && (snapshot.profiles.canCreateEmpty
                || snapshot.profiles.canImport)
    }

     
     
     
     
     
     
    @ViewBuilder
    private var profilesSection: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            Section {
                if displayedProfiles.isEmpty {
                    profilesEmptyState
                } else {
                ForEach(
                    Array(
                        displayedProfiles.enumerated()
                    ),
                    id: \.element.id
                ) { index, profile in
                    HakoProfileRow(
                        profile: profile,
                        isSelecting:
                            pendingSelectionID == profile.id,
                         
                         
                         
                         
                        isBlocked: pendingSelectionID != nil
                            && pendingSelectionID != profile.id,
                        destination: {
                            pagePresentation(
                            AnyView(
                                HakoProfileDetailView(
                                    profileID: profile.id,
                                    snapshot: snapshot,
                                    actions: actions,
                                    presentationClass:
                                        presentationClass,
                                    palette: palette,
                                    pagePresentation:
                                        pagePresentation,
                                    capabilityInterceptor: capabilityInterceptor,
                                    icon: icon,
                                    capabilityContent:
                                        capabilityContent
                                )
                            )
                            )
                        },
                        select: {
                            select(profile)
                        },
                        palette: palette,
                        icon: icon
                    )
                    .hakoDirectReorderRow(
                        id: profile.id.rawValue,
                        label: profile.label,
                        enabled: snapshot.profiles.canReorder
                            && displayedProfiles.count > 1,
                        draggedID: $draggedProfileID,
                        dropTarget: $reorderDropTarget,
                        canMoveUp: index > displayedProfiles.startIndex,
                        canMoveDown: index
                            < displayedProfiles.index(
                                before: displayedProfiles.endIndex
                            ),
                        onMove: reorderProfile,
                        onMoveUp: {
                            moveDisplayedProfile(
                                id: profile.id,
                                offset: -1
                            )
                        },
                        onMoveDown: {
                            moveDisplayedProfile(
                                id: profile.id,
                                offset: 1
                            )
                        }
                    )

                    if let failure = selectionFailure,
                       failure.profileID == profile.id {
                        Text(hako: failure.message)
                            .font(.caption)
                            .foregroundStyle(Color.red)
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .padding(
                                .horizontal,
                                HakoTheme.Spacing.standard
                            )
                            .padding(
                                .bottom,
                                HakoTheme.Spacing.row
                            )
                            .accessibilityIdentifier(
                                "profile-center.select-failure"
                            )
                    }

                    if index
                        < displayedProfiles.count - 1
                    {
                        HakoRowDivider()
                            .padding(
                                .leading,
                                HakoTheme.Spacing.standard
                            )
                    }
                }
                }
            } header: {
                profilesHeader
            }
        } else {
            traditionalProfilesSection
        }
    }

    private var profilesEmptyState: some View {
        HakoEmptyState(
            title: "No Profiles",
            message:
                "Create a direct profile or import a subscription to get started."
        ) {
            icon(.listBulletRectangle)
        }
        .padding(HakoTheme.Spacing.standard)
        
    }

    private var traditionalProfilesSection: some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.row) {
            profilesHeader

            if displayedProfiles.isEmpty {
                HakoCardSurface(
                    fill: palette.card,
                    separator: palette.separator
                ) {
                    HakoEmptyState(
                        title: "No Profiles",
                        message:
                            "Create a direct profile or import a subscription to get started."
                    ) {
                        icon(.listBulletRectangle)
                    }
                    .padding(HakoTheme.Spacing.standard)
                }
            } else {
                HakoCardSurface(
                    fill: palette.card,
                    separator: palette.separator
                ) {
                    VStack(spacing: 0) {
                        ForEach(
                            Array(
                                displayedProfiles.enumerated()
                            ),
                            id: \.element.id
                        ) { index, profile in
                            HakoProfileRow(
                                profile: profile,
                                isSelecting:
                                    pendingSelectionID == profile.id,
                                 
                                 
                                 
                                 
                                isBlocked: pendingSelectionID != nil
                                    && pendingSelectionID != profile.id,
                                destination: {
                                    pagePresentation(
                                    AnyView(
                                        HakoProfileDetailView(
                                            profileID: profile.id,
                                            snapshot: snapshot,
                                            actions: actions,
                                            presentationClass:
                                                presentationClass,
                                            palette: palette,
                                            pagePresentation:
                                                pagePresentation,
                                            capabilityInterceptor: capabilityInterceptor,
                                            icon: icon,
                                            capabilityContent:
                                                capabilityContent
                                        )
                                    )
                                    )
                                },
                                select: {
                                    select(profile)
                                },
                                palette: palette,
                                icon: icon
                            )
                            .hakoDirectReorderRow(
                                id: profile.id.rawValue,
                                label: profile.label,
                                enabled: snapshot.profiles.canReorder
                                    && displayedProfiles.count > 1,
                                draggedID: $draggedProfileID,
                                dropTarget: $reorderDropTarget,
                                canMoveUp: index > displayedProfiles.startIndex,
                                canMoveDown: index
                                    < displayedProfiles.index(
                                        before: displayedProfiles.endIndex
                                    ),
                                onMove: reorderProfile,
                                onMoveUp: {
                                    moveDisplayedProfile(
                                        id: profile.id,
                                        offset: -1
                                    )
                                },
                                onMoveDown: {
                                    moveDisplayedProfile(
                                        id: profile.id,
                                        offset: 1
                                    )
                                }
                            )

                            if let failure = selectionFailure,
                               failure.profileID == profile.id {
                                Text(hako: failure.message)
                                    .font(.caption)
                                    .foregroundStyle(Color.red)
                                    .frame(
                                        maxWidth: .infinity,
                                        alignment: .leading
                                    )
                                    .padding(
                                        .horizontal,
                                        HakoTheme.Spacing.standard
                                    )
                                    .padding(
                                        .bottom,
                                        HakoTheme.Spacing.row
                                    )
                                    .accessibilityIdentifier(
                                        "profile-center.select-failure"
                                    )
                            }

                            if index
                                < displayedProfiles.count - 1
                            {
                                HakoRowDivider()
                                    .padding(
                                        .leading,
                                        HakoTheme.Spacing.standard
                                    )
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

     
     
     
     
     
     
     
    private var addSection: some View {
        HakoProfileGroup(
            title: "Add",
            palette: palette,
            presentationClass: presentationClass
        ) {
            Button {
                activeCapability = .importProfile
            } label: {
                HakoProfileActionRow(
                    title: "Add Profile",
                    subtitle: "Subscription link · config file · from scratch",
                    symbol: .plusCircle,
                    tint: .primary,
                    icon: icon
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile-center.add")
        }
    }

    private var dataSection: some View {
        HakoProfileGroup(
            title: "Data",
            palette: palette,
            presentationClass: presentationClass
        ) {
            HakoRoutedViewLink(
                showsDisclosureIndicator: false
            ) {
                capabilityContent(.backupRestore)
            } label: {
                HakoProfileActionRow(
                    title: "iCloud Backup & Restore",
                    subtitle: "Everything a profile needs to run",
                    symbol: .icloudAndArrowUp,
                    tint: .primary,
                    icon: icon
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile-center.backup")
        }
    }

    @ViewBuilder
    private var failureSection: some View {
        if let failure = snapshot.profiles.failure {
            HakoCardSurface(
                fill: palette.card,
                separator: palette.separator
            ) {
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.row
                ) {
                    Text(hako: failure.message)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    if failure.canRetry {
                        Button("Try Again") {
                            send(.retryFailure)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(HakoTheme.Spacing.standard)
            }
            .accessibilityIdentifier("profile-center.error")
        }
    }

     
     
     
    private var profileCountTitle: HakoDisplayText {
        let count = snapshot.profiles.profiles.count
        return .format(
            count == 1 ? "%@ profile" : "%@ profiles",
            [String(count)]
        )
    }

    @ViewBuilder
    private var profilesHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityProfilesHeader
        } else {
            HStack(alignment: .firstTextBaseline) {
                profileCountLabel
                Spacer()
                if hasRemoteProfile,
                   snapshot.profiles.canSyncAll {
                    syncAllButton
                }
            }
        }
    }

    private var accessibilityProfilesHeader: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.row
        ) {
            profileCountLabel
            if hasRemoteProfile,
               snapshot.profiles.canSyncAll {
                syncAllButton
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var profileCountLabel: some View {
        Text(hako: profileCountTitle)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var hasRemoteProfile: Bool {
        snapshot.profiles.profiles.contains {
            $0.source == .remote
        }
    }

    private var syncAllButton: some View {
        Button {
            send(.syncAll)
        } label: {
            Label {
                Text("Update All")
            } icon: {
                icon(.arrowTriangle2Circlepath)
            }
            .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.borderless)
        .disabled(snapshot.profiles.batchReport?.isRunning == true)
        .accessibilityIdentifier("profile-center.sync-all")
    }

     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private var initialDetailLink: some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
             
             
             
             
             
             
            if let requested = requestedProfileID,
               snapshot.profiles.profile(id: requested) != nil {
                Color.clear
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                    .onAppear {
                         
                         
                         
                        guard let pushRoute else { return }
                        requestedProfileID = nil
                        pushRoute(HakoProfileRoute.detail(requested))
                    }
            }
        } else {
            NavigationLink(
                destination: HakoLazyView {
                    requestedDetail.hakoPushedDetailPage()
                },
                isActive: requestedDetailPresented
            ) {
                EmptyView()
            }
            .hidden()
        }
    }

    private var requestedDetailPresented: Binding<Bool> {
        Binding(
            get: {
                guard let requestedProfileID else {
                    return false
                }
                return snapshot.profiles.profile(
                    id: requestedProfileID
                ) != nil
            },
            set: { active in
                if !active {
                    requestedProfileID = nil
                }
            }
        )
    }

    @ViewBuilder
    private var requestedDetail: some View {
        if let requestedProfileID {
            pagePresentation(
                AnyView(
                    HakoProfileDetailView(
                        profileID: requestedProfileID,
                        snapshot: snapshot,
                        actions: actions,
                        presentationClass: presentationClass,
                        palette: palette,
                        pagePresentation: pagePresentation,
                        capabilityInterceptor: capabilityInterceptor,
                        icon: icon,
                        capabilityContent: capabilityContent
                    )
                )
            )
        } else {
            EmptyView()
        }
    }

    private func select(_ profile: HakoProfileSnapshot) {
        performSelection(profile, closesPage: true)
    }

     
     
     
     
     
     
     
    private func performSelection(
        _ profile: HakoProfileSnapshot,
        closesPage: Bool
    ) {
        guard !profile.isCurrent, pendingSelectionID == nil else {
            return
        }
        pendingSelectionID = profile.id
        selectionFailure = nil
        Task { @MainActor in
            defer { pendingSelectionID = nil }
            do {
                let result = try await actions.performForResult(
                    .profiles(.select(id: profile.id)),
                    allowedBy: snapshot
                )
                if case .profileSelected(let id) = result,
                   id == profile.id {
                    if closesPage {
                        dismiss()
                    }
                } else if case .profileSelectionFailurePresented = result {
                     
                     
                } else {
                     
                     
                     
                     
                     
                    selectionFailure = HakoProfileSelectionFailure(
                        profileID: profile.id,
                        message: "Clash could not switch to this profile."
                    )
                }
            } catch {
                 
                 
                 
                selectionFailure = HakoProfileSelectionFailure(
                    profileID: profile.id,
                     
                     
                     
                     
                     
                    message: .copy(error.localizedDescription)
                )
            }
        }
    }

    private func reorderProfile(
        _ sourceID: String,
        _ destinationID: String,
        _ edge: HakoReorderDropEdge
    ) {
        guard sourceID != destinationID,
              let sourceIndex = displayedProfiles.firstIndex(where: {
                  $0.id.rawValue == sourceID
              }) else {
            return
        }

        var reordered = displayedProfiles
        let moved = reordered.remove(at: sourceIndex)
        guard let targetIndex = reordered.firstIndex(where: {
            $0.id.rawValue == destinationID
        }) else {
            return
        }
        let insertionIndex = edge == .before
            ? targetIndex
            : reordered.index(after: targetIndex)
        reordered.insert(moved, at: insertionIndex)
        guard reordered.map(\.id) != displayedProfiles.map(\.id) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.16)) {
            displayedProfiles = reordered
        }
        send(.reorder(ids: reordered.map(\.id)))
    }

     
     
     
     
     
     
    private func applyReorder(_ ids: [Profile.ID]) {
        guard Set(ids) == Set(displayedProfiles.map(\.id)),
              ids.count == displayedProfiles.count,
              ids != displayedProfiles.map(\.id) else {
            return
        }
        let byID = Dictionary(
            displayedProfiles.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        withAnimation(.easeInOut(duration: 0.16)) {
            displayedProfiles = ids.compactMap { byID[$0] }
        }
        send(.reorder(ids: ids))
    }

    private func moveDisplayedProfile(id: Profile.ID, offset: Int) {
        guard let index = displayedProfiles.firstIndex(where: {
            $0.id == id
        }) else {
            return
        }
        let destination = index + offset
        guard displayedProfiles.indices.contains(destination) else {
            return
        }

        var reordered = displayedProfiles
        reordered.swapAt(index, destination)
        withAnimation(.easeInOut(duration: 0.16)) {
            displayedProfiles = reordered
        }
        send(.reorder(ids: reordered.map(\.id)))
    }

    private func send(_ command: HakoProfilesCommand) {
        Task { @MainActor in
            try? await actions.perform(
                .profiles(command),
                allowedBy: snapshot
            )
        }
    }
}

 
 
enum HakoProfileRoute: Hashable {
    case detail(Profile.ID)
}

 
 
 
private struct HakoProfilesRootTitleModifier: ViewModifier {
    let showsDismissControl: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if showsDismissControl {
            content.navigationTitle("Profiles")
        } else {
            content
        }
    }
}

 
private struct HakoProfileSelectionFailure: Equatable {
    let profileID: Profile.ID
     
    let message: HakoDisplayText
}

private struct HakoProfileRow<
    Icon: View,
    Destination: View
>: View {
    let profile: HakoProfileSnapshot
    let isSelecting: Bool
    let isBlocked: Bool
     
     
     
     
     
     
    let destination: () -> Destination
    let select: () -> Void
    let palette: HakoProductPalette
    let icon: (HakoSymbol) -> Icon

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityProfileRow
        } else {
            standardProfileRow
        }
    }

     
     
     
    @ViewBuilder
    private func rowLink<Label: View>(
        @ViewBuilder label: () -> Label
    ) -> some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
             
             
             
             
             
             
             
             
            HakoValueRowLink(
                value: HakoProfileRoute.detail(profile.id)
            ) {
                label()
            }
        } else {
            NavigationLink(
                destination: HakoLazyView {
                    destination().hakoPushedDetailPage()
                }
            ) {
                label()
            }
        }
    }

     
     
     
     
     
     
     
    private var standardProfileRow: some View {
        HStack(
            alignment: .center,
            spacing: HakoTheme.Spacing.compact
        ) {
            Button(action: select) {
                HStack(
                    alignment: .center,
                    spacing: HakoTheme.Spacing.row
                ) {
                    statusSlot
                    VStack(
                        alignment: .leading,
                        spacing: HakoTheme.Spacing.compact
                    ) {
                        HStack(
                            alignment: .firstTextBaseline,
                            spacing: HakoTheme.Spacing.compact
                        ) {
                            Text(profile.label)
                                .font(
                                    .body.weight(
                                        profile.isCurrent
                                            ? .semibold
                                            : .regular
                                    )
                                )
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let subscription = profile.subscription,
                               let used = HakoSubscriptionUsageView
                                   .usedText(subscription) {
                                Spacer(minLength: HakoTheme.Spacing.compact)
                                used
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                    .lineLimit(1)
                            }
                        }

                        if let subscription = profile.subscription {
                            HakoSubscriptionUsageView(
                                subscription: subscription,
                                style: .row
                            )
                        }

                        Text(hako: profile.sourceSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: HakoTheme.Spacing.compact)
                }
                .padding(.leading, HakoTheme.Spacing.standard)
                .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.row
            )
        )
                .contentShape(Rectangle())
            }
            .disabled(isBlocked)
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(isSelecting || profile.isBusy)
            .accessibilityLabel(
                profile.isCurrent
                    ? "\(profile.label), current"
                    : "Switch to \(profile.label)"
            )
            .accessibilityIdentifier(
                "profile-center.select.\(profile.id)"
            )

            detailButton
                .padding(.trailing, HakoTheme.Spacing.standard)
        }
    }

     
    @ViewBuilder
    private var statusSlot: some View {
        Group {
            if isSelecting || profile.isBusy {
                ProgressView()
                    .controlSize(.small)
            } else if profile.isCurrent {
                icon(.checkmark)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .accessibilityLabel(Text(hako: .copy("Current")))
                    .accessibilityIdentifier(
                        "profile-center.current.\(profile.id)"
                    )
            } else {
                Color.clear
            }
        }
        .frame(width: 24, height: 24)
    }

    private var detailButton: some View {
        rowLink {
            icon(.infoCircle)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(
                    width: HakoTheme.Control.minimumHitTarget,
                    height: HakoTheme.Control.minimumHitTarget
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(profile.label) details")
        .accessibilityIdentifier(
            "profile-center.detail.\(profile.id)"
        )
    }

     
     
     
    private var accessibilityProfileRow: some View {
        VStack(spacing: 0) {
            Button(action: select) {
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.row
                ) {
                    HStack(
                        alignment: .firstTextBaseline,
                        spacing: HakoTheme.Spacing.row
                    ) {
                        statusSlot
                        Text(profile.label)
                            .font(
                                .body.weight(
                                    profile.isCurrent
                                        ? .semibold
                                        : .regular
                                )
                            )
                            .foregroundStyle(.primary)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        Spacer(
                            minLength: HakoTheme.Spacing.compact
                        )
                    }

                    if let subscription = profile.subscription {
                        HakoSubscriptionUsageView(
                            subscription: subscription,
                            style: .row
                        )
                    }

                    Text(hako: profile.sourceSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, HakoTheme.Spacing.standard)
                .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.row
            )
        )
                .contentShape(Rectangle())
            }
            .disabled(isBlocked)
            .buttonStyle(.plain)
            .disabled(isSelecting || profile.isBusy)
            .accessibilityLabel(
                profile.isCurrent
                    ? "\(profile.label), current"
                    : "Switch to \(profile.label)"
            )
            .accessibilityIdentifier(
                "profile-center.select.\(profile.id)"
            )

            HakoRowDivider(leadingInset: HakoTheme.Spacing.standard)

            rowLink {
                HStack(spacing: HakoTheme.Spacing.row) {
                    icon(.infoCircle)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("Details")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                    Spacer()
                }
                .padding(.horizontal, HakoTheme.Spacing.standard)
                .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.row
            )
        )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(profile.label) details")
            .accessibilityIdentifier(
                "profile-center.detail.\(profile.id)"
            )
        }
    }
}

private struct HakoProfileDetailView<
    Icon: View,
    CapabilityContent: View
>: View {
    let profileID: Profile.ID
    let snapshot: AppleClientSnapshot
    let actions: AppleClientActions
    let presentationClass: HakoPresentationClass
    let palette: HakoProductPalette
    let pagePresentation: (AnyView) -> AnyView
     
     
    let capabilityInterceptor:
        ((HakoProfilesCapabilityDestination) -> Bool)?
    let icon: (HakoSymbol) -> Icon
    let capabilityContent:
        (HakoProfilesCapabilityDestination) -> CapabilityContent

     
    private func present(_ capability: HakoProfilesCapabilityDestination) {
        if capabilityInterceptor?(capability) == true { return }
        activeCapability = capability
    }

    @Environment(\.dismiss) private var dismiss
    @State private var isDuplicating = false
     
     
     
     
    @State private var showsActionFailure: ActionFailure?

    struct ActionFailure: Equatable {
        enum Action { case duplicate, delete }
        let action: Action
        let message: HakoDisplayText
    }

    @ViewBuilder
    private func actionFailureLine(for action: ActionFailure.Action) -> some View {
        if let showsActionFailure, showsActionFailure.action == action {
            Text(hako: showsActionFailure.message)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, HakoTheme.Spacing.standard)
                .padding(.bottom, HakoTheme.Spacing.tight)
                .accessibilityIdentifier("profile-detail.action-failure")
        }
    }
     
     
     
    @Environment(\.hakoProductModalDismiss) private var productModalDismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var activeCapability:
        HakoProfilesCapabilityDestination?
    @State private var showsDeleteConfirmation = false
    @State private var showsPlaintextExportConfirmation = false
    @State private var draftName = ""
    @FocusState private var editingName: Bool

    private var profile: HakoProfileSnapshot? {
        snapshot.profiles.profile(id: profileID)
    }

    var body: some View {
        Group {
            if let profile {
                detailPage(profile)
            } else {
                HakoEmptyState(
                    title: "Profile Unavailable",
                    message:
                        "Return to Profiles and choose another item."
                ) {
                    icon(.exclamationmarkTriangle)
                }
            }
        }
        .hakoProductModal(
            item: $activeCapability,
            role: .page,
            immersive: { $0.presentsImmersively }
        ) { destination in
            capabilityContent(destination)
                .hakoModalPresentation(.page)
        }
        .onAppear {
            if draftName.isEmpty {
                draftName = profile?.label ?? ""
            }
        }
        .onChange(of: profile?.label) { label in
            if !editingName, let label {
                draftName = label
            }
        }
    }

    private func detailPage(
        _ profile: HakoProfileSnapshot
    ) -> some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "profile-detail.root"
        ) {
            identitySection(profile)
            if profile.source == .remote,
               profile.subscription != nil
                || profile.canSync
                || profile.canConfigureSubscription
                || profile.canCopySubscriptionLink
            {
                subscriptionSection(profile)
            }
            if !profile.heldBackUpdates.isEmpty {
                heldBackSection(profile)
            }
            if profile.canEditSource
                || profile.canDuplicate
                || profile.canExport
            {
                manageSection(profile)
            }
            if profile.canOpenRuntimePreview
                || profile.canRestoreLastKnownGood
            {
                runtimeSection(profile)
            }
            deleteSection(profile)
            statusSection
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        .hakoRegistersDeparture(
            isDirty: hasUnsavedName(profile),
            save: { completion in
                commitRename(profile)
                completion(true)
            },
            discard: { draftName = profile.label }
        )
        .hakoPageTitle(.verbatim(profile.label), watchAs: "profile-detail")
        .hakoToolbarUnlessInPanel {
             
             
             
             
            ToolbarItem(placement: .confirmationAction) {
                if hasUnsavedName(profile) {
                    Button("Save") {
                        commitRename(profile)
                        editingName = false
                    }
                    .accessibilityIdentifier("profile-detail.save")
                }
            }
        }
        .alert(
            "Delete Profile?",
            isPresented: $showsDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                delete(profile)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
             
             
             
             
            Text(hako: .format(
                "Delete %@? This cannot be undone.",
                [profile.label]
            ))
        }
        .alert(
            "Export Configuration Text Only?",
            isPresented: $showsPlaintextExportConfirmation
        ) {
            Button("Export Text") {
                send(.export(id: profile.id))
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Imported certificate files are not included. Everything else — your credentials included — is exported as plaintext."
            )
        }
    }

    private func identitySection(
        _ profile: HakoProfileSnapshot
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.compact
        ) {
            identityHeader(profile)
            .padding(.horizontal, HakoTheme.Spacing.standard)

            HakoCardSurface(
                fill: palette.card,
                separator: palette.separator
            ) {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        accessibilityIdentityEditor
                    } else {
                        HStack(
                            alignment: .firstTextBaseline,
                            spacing: HakoTheme.Spacing.standard
                        ) {
                            Text("Name")
                            Spacer(minLength: HakoTheme.Spacing.compact)
                            if profile.canRename {
                                nameEditor
                                    .multilineTextAlignment(.trailing)
                            } else {
                                Text(profile.label)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, HakoTheme.Spacing.standard)
                .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.row
            )
        )
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(hako: profile.sourceSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(
                    dynamicTypeSize.isAccessibilitySize ? 2 : 1
                )
                .truncationMode(.middle)
                .fixedSize(
                    horizontal: false,
                    vertical: dynamicTypeSize.isAccessibilitySize
                )
                .padding(.leading, HakoTheme.Spacing.standard)
        }
        .onChange(of: editingName) { focused in
            if profile.canRename, !focused {
                commitRename(profile)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile-detail.identity")
    }

    @ViewBuilder
    private func identityHeader(
        _ profile: HakoProfileSnapshot
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.row
            ) {
                identityTitle
                if profile.isCurrent {
                    activeProfileLabel
                }
            }
        } else {
            HStack {
                identityTitle
                Spacer()
                if profile.isCurrent {
                    activeProfileLabel
                }
            }
        }
    }

    private var identityTitle: some View {
        Text("IDENTITY")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var activeProfileLabel: some View {
        Label {
            Text("Active")
        } icon: {
            icon(.checkmarkCircleFill)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tint)
        .accessibilityIdentifier("profile-detail.active")
    }

    private var accessibilityIdentityEditor: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.compact
        ) {
            Text("Name")
                .font(.caption)
                .foregroundStyle(.secondary)
            if profile?.canRename == true {
                nameEditor
                    .multilineTextAlignment(.leading)
            } else {
                Text(profile?.label ?? "")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nameEditor: some View {
         
         
         
         
         
         
         
        TextField("Name", text: $draftName)
            .hakoLabelsHiddenInSettingsIdiom()
            .submitLabel(.done)
            .focused($editingName)
            .onSubmit { editingName = false }
            .accessibilityIdentifier("profile-detail.name")
    }

     
     
     
     
    private func heldBackSection(
        _ profile: HakoProfileSnapshot
    ) -> some View {
        HakoProfileGroup(
            title: "Held Back by Your Settings",
            palette: palette,
            presentationClass: presentationClass
        ) {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.row) {
                Text(hako: .format(
                    "The last update changed %@ setting(s) that your app-wide settings override. Each is shown with the new value; adopt it or keep yours.",
                    [String(profile.heldBackUpdates.count)]
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                ForEach(profile.heldBackUpdates) { item in
                    HStack(alignment: .top, spacing: HakoTheme.Spacing.row) {
                        VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                            Text(verbatim: item.keyPath)
                                .font(.subheadline.monospaced())
                            Text(hako: heldBackLine(item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        Button {
                            send(.adoptHeldBackUpdate(id: profile.id, keyPath: item.keyPath))
                        } label: {
                            Text(hako: item.change == .removed ? .copy("Follow Removal") : .copy("Use New Value"))
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("profile-detail.held-back.adopt.\(item.keyPath)")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("profile-detail.held-back.item.\(item.keyPath)")
                }
                Button {
                    send(.dismissHeldBackUpdates(id: profile.id))
                } label: {
                    Text(hako: .copy("Keep My Settings"))
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("profile-detail.held-back.dismiss")
            }
            .padding(.vertical, HakoTheme.Spacing.standard)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("profile-detail.held-back")
        }
    }

    private func heldBackLine(_ item: HakoProfileHeldBackUpdate) -> HakoDisplayText {
        switch item.change {
        case .removed:
            return .format("Removed by the subscription · yours: %@", [item.appValue])
        case .added, .changed:
            return .format("Subscription now: %@ · yours: %@", [item.newValue ?? "", item.appValue])
        }
    }

    private func subscriptionSection(
        _ profile: HakoProfileSnapshot
    ) -> some View {
        HakoProfileGroup(
            title: "Subscription",
            palette: palette,
            presentationClass: presentationClass
        ) {
            if let subscription = profile.subscription {
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.row
                ) {
                    HakoSubscriptionUsageView(
                        subscription: subscription
                    )
                    Text(lastSyncValue(profile))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.vertical, HakoTheme.Spacing.standard)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(
                    "profile-detail.subscription-status"
                )

                if profile.canSync
                    || profile.canConfigureSubscription
                    || profile.canCopySubscriptionLink
                {
                    HakoRowDivider()
                }
            }

            if profile.canSync {
                Button {
                    send(.sync(id: profile.id))
                } label: {
                    HakoProfileActionRow(
                        title: "Sync Now",
                        subtitle: "Fetch the latest nodes and rules",
                        symbol: .arrowTriangle2Circlepath,
                        tint: .primary,
                        showsDisclosure: false,
                        icon: icon
                    )
                }
                .buttonStyle(.plain)
                .disabled(
                    snapshot.profiles.profiles.contains {
                        $0.isBusy
                    }
                )
                .accessibilityIdentifier("profile-detail.sync")
            }

            if profile.canSync
                && (profile.canConfigureSubscription
                    || profile.canCopySubscriptionLink)
            {
                HakoRowDivider()
            }

            if profile.canConfigureSubscription {
                Button {
                    activeCapability =
                        .subscriptionSettings(profile.id)
                } label: {
                    HakoProfileActionRow(
                        title: "Subscription Settings",
                        subtitle: "Source · automatic updates · interval",
                        symbol: .link,
                        tint: .primary,
                        icon: icon
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "profile-detail.subscription"
                )
            }

            if profile.canConfigureSubscription
                && profile.canCopySubscriptionLink
            {
                HakoRowDivider()
            }

            if profile.canCopySubscriptionLink {
                Button {
                    send(.copySubscriptionLink(id: profile.id))
                } label: {
                    HakoProfileActionRow(
                        title: "Copy Subscription Link",
                        subtitle: "Copied only when you ask",
                        symbol: .docOnDoc,
                        tint: .primary,
                        showsDisclosure: false,
                        icon: icon
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "profile-detail.copy-link"
                )
            }
        }
    }

    private func manageSection(
        _ profile: HakoProfileSnapshot
    ) -> some View {
        HakoProfileGroup(
            title: "Manage",
            palette: palette,
            presentationClass: presentationClass
        ) {
            Button {
                activeCapability = .rules(profile.id)
            } label: {
                HakoProfileActionRow(
                    title: "Rules",
                    subtitle: "Personal rules for this profile",
                    symbol: .listTriangle,
                    tint: .primary,
                    icon: icon
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.detail.rules")

            Button {
                activeCapability = .override(profile.id)
            } label: {
                HakoProfileActionRow(
                    title: "Override",
                    subtitle: "Change what this profile sends to the core",
                    symbol: .sliderHorizontal3,
                    tint: .primary,
                    icon: icon
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.detail.override")

            if profile.canEditSource {
                Button {
                    present(.sourceEditor(profile.id))
                } label: {
                    HakoProfileActionRow(
                        title: "Edit Source",
                        subtitle:
                            "Edit this profile's raw configuration text",
                        symbol: .curlybraces,
                        tint: .primary,
                        icon: icon
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "profile-detail.edit-source"
                )

                if profile.canDuplicate || profile.canExport {
                    HakoRowDivider()
                }
            }

            if profile.canDuplicate {
                 
                 
                 
                Button {
                    duplicate(profile)
                } label: {
                    HakoProfileActionRow(
                        title: "Duplicate Profile",
                        subtitle: isDuplicating ? "Creating the copy…" : "Create an independent local copy",
                        symbol: .docOnDoc,
                        tint: .primary,
                        showsDisclosure: false,
                        icon: icon
                    )
                }
                .overlay(alignment: .trailing) {
                    if isDuplicating {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, HakoTheme.Spacing.standard)
                            .accessibilityIdentifier("profile-detail.duplicating")
                    }
                }
                .disabled(isDuplicating)
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "profile-detail.duplicate"
                )
            }

            actionFailureLine(for: .duplicate)

            if profile.canDuplicate && profile.canExport {
                HakoRowDivider()
            }

            if profile.canExport {
                Button {
                    if profile.requiresPlaintextExportConfirmation {
                        showsPlaintextExportConfirmation = true
                    } else {
                        send(.export(id: profile.id))
                    }
                } label: {
                    HakoProfileActionRow(
                        title: "Export",
                        subtitle: "The complete configuration text",
                        symbol: .squareAndArrowUp,
                        tint: .primary,
                        showsDisclosure: false,
                        icon: icon
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile-detail.export")
            }
        }
    }

    private func runtimeSection(
        _ profile: HakoProfileSnapshot
    ) -> some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            VStack(spacing: 0) {
                if profile.canOpenRuntimePreview {
                    Button {
                        HakoPageProbe.markNavigation()
                        activeCapability =
                            .runtimePreview(profile.id)
                    } label: {
                        HakoProfileActionRow(
                            title: "View Runtime Configuration",
                            subtitle: profile.runtimeSummary,
                            symbol: .eye,
                            tint: .primary,
                            icon: icon
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "profile-detail.preview"
                    )
                }

                if profile.canOpenRuntimePreview
                    && profile.canRestoreLastKnownGood
                {
                    HakoRowDivider()
                }

                if profile.canRestoreLastKnownGood {
                    Button {
                        send(
                            .restoreLastKnownGood(id: profile.id)
                        )
                    } label: {
                        HakoProfileActionRow(
                            title: "Restore Last Known Good",
                            subtitle:
                                "Reapply this profile's validated runtime",
                            symbol: .arrowTriangle2Circlepath,
                            tint: .primary,
                            showsDisclosure: false,
                            icon: icon
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "profile-detail.restore-lkg"
                    )
                }
            }
            .padding(.horizontal, HakoTheme.Spacing.standard)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deleteSection(
        _ profile: HakoProfileSnapshot
    ) -> some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                HakoProfileActionRow(
                    title: "Delete Profile",
                    subtitle: profile.deleteSubtitle,
                    symbol: .trash,
                    tint: .red,
                    titleColor: .red,
                    showsDisclosure: false,
                    icon: icon
                )
            }
            .buttonStyle(.plain)
            .disabled(!profile.canDelete)
            .accessibilityIdentifier("profile-detail.delete")
            .padding(.horizontal, HakoTheme.Spacing.standard)
            actionFailureLine(for: .delete)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var statusSection: some View {
        if !snapshot.profiles.statusMessage.rawValue.isEmpty {
            HakoProfileGroup(
                title: "Last Action",
                palette: palette,
                presentationClass: presentationClass
            ) {
                Text(hako: snapshot.profiles.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(
                        snapshot.profiles.failure == nil
                            ? Color.secondary
                            : Color.red
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.row
            )
        )
                    .accessibilityIdentifier(
                        "profile-detail.status"
                    )
            }
        }
    }

    private func lastSyncValue(
        _ profile: HakoProfileSnapshot
    ) -> String {
        let sync = profile.lastUpdatedAt.map {
            $0.formatted(.relative(presentation: .named))
        } ?? "never"
        var value = "Last sync \(sync)"
        if profile.autoUpdate {
            value +=
                " · every \(profile.updateIntervalHours) h automatically"
        }
        return value
    }

     
    private func hasUnsavedName(_ profile: HakoProfileSnapshot) -> Bool {
        guard profile.canRename else { return false }
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != profile.label
    }

    private func commitRename(
        _ profile: HakoProfileSnapshot
    ) {
        let trimmed = draftName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmed.isEmpty else {
            draftName = profile.label
            return
        }
        guard trimmed != profile.label else {
            return
        }
        send(.rename(id: profile.id, label: trimmed))
    }

    private func delete(_ profile: HakoProfileSnapshot) {
        showsActionFailure = nil
        Task { @MainActor in
            do {
                let result = try await actions.performForResult(
                    .profiles(.delete(id: profile.id)),
                    allowedBy: snapshot
                )
                switch result {
                case .profileDeleted(let id) where id == profile.id:
                    leave()
                case .profileActionRefused(let reason):
                    showsActionFailure = ActionFailure(action: .delete, message: reason)
                default:
                    showsActionFailure = ActionFailure(
                        action: .delete, message: .copy("The profile was not deleted."))
                }
            } catch is CancellationError {
                 
            } catch {
                showsActionFailure = ActionFailure(
                    action: .delete, message: .copy(error.localizedDescription))
            }
        }
    }

     
     
     
     
     
    private func duplicate(_ profile: HakoProfileSnapshot) {
        guard !isDuplicating else { return }
        isDuplicating = true
        showsActionFailure = nil
        Task { @MainActor in
            defer { isDuplicating = false }
            do {
                let result = try await actions.performForResult(
                    .profiles(.duplicate(id: profile.id)),
                    allowedBy: snapshot
                )
                switch result {
                case .profileCreated:
                    leave()
                case .profileActionRefused(let reason):
                     
                     
                     
                    showsActionFailure = ActionFailure(action: .duplicate, message: reason)
                default:
                    showsActionFailure = ActionFailure(
                        action: .duplicate, message: .copy("The copy was not created."))
                }
            } catch is CancellationError {
                 
            } catch {
                 
                 
                showsActionFailure = ActionFailure(
                    action: .duplicate, message: .copy(error.localizedDescription))
            }
        }
    }

     
     
     
    private func leave() {
        if let productModalDismiss {
            productModalDismiss()
        } else {
            dismiss()
        }
    }

    private func send(_ command: HakoProfilesCommand) {
        Task { @MainActor in
            try? await actions.perform(
                .profiles(command),
                allowedBy: snapshot
            )
        }
    }
}

private struct HakoProfileReorderView: View {
    let snapshot: AppleClientSnapshot
    let actions: AppleClientActions
    let palette: HakoProductPalette

    @Environment(\.dismiss) private var dismiss
    @State private var profiles: [HakoProfileSnapshot]

    init(
        profiles: [HakoProfileSnapshot],
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        palette: HakoProductPalette
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.palette = palette
        _profiles = State(initialValue: profiles)
    }

    var body: some View {
        HakoSingleColumnNavigationContainer {
            List {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                ForEach(
                    Array(profiles.enumerated()),
                    id: \.element.id
                ) { index, profile in
                    HStack(spacing: HakoTheme.Spacing.row) {
                        Text(profile.label)
                            .lineLimit(1)
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        if profile.isCurrent {
                            Text("Active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(
                        minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform
                    )
                    .contentShape(Rectangle())
                    .accessibilityHint("Drag to reorder")
                    .accessibilityAction(named: "Move Up") {
                        moveProfile(at: index, offset: -1)
                    }
                    .accessibilityAction(named: "Move Down") {
                        moveProfile(at: index, offset: 1)
                    }
                    .contextMenu {
                        Button("Move Up") {
                            moveProfile(at: index, offset: -1)
                        }
                        .disabled(index == profiles.startIndex)

                        Button("Move Down") {
                            moveProfile(at: index, offset: 1)
                        }
                        .disabled(
                            index == profiles.index(before: profiles.endIndex)
                        )
                    }
                    .accessibilityIdentifier(
                        "profile-reorder.row.\(profile.label)"
                    )
                }
                .onMove(perform: moveProfiles)
            }
             
             
             
            .hakoExplicitReorderMode()
            .hakoPageTitle("Reorder Profiles")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    HakoSheetCloseButton {
                        dismiss()
                    }
                }
            }
            .hakoProductModalRoot(title: "Reorder Profiles")
        }
        .accessibilityIdentifier("profile-reorder.screen")
    }

    private func moveProfile(at index: Int, offset: Int) {
        let destination = index + offset
        guard profiles.indices.contains(index),
              profiles.indices.contains(destination) else {
            return
        }
        profiles.swapAt(index, destination)
        sendOrder()
    }

    private func moveProfiles(
        from source: IndexSet,
        to destination: Int
    ) {
        profiles.move(fromOffsets: source, toOffset: destination)
        sendOrder()
    }

    private func sendOrder() {
        let ids = profiles.map(\.id)
        Task { @MainActor in
            try? await actions.perform(
                .profiles(.reorder(ids: ids)),
                allowedBy: snapshot
            )
        }
    }
}

private struct HakoProfileBatchReportView<Icon: View>: View {
    let report: HakoProfileBatchReportSnapshot
    let snapshot: AppleClientSnapshot
    let actions: AppleClientActions
    let icon: (HakoSymbol) -> Icon
     
     
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal

    var body: some View {
        HakoSingleColumnNavigationContainer {
            List {
                Section {
                    VStack(
                        alignment: .leading,
                        spacing: HakoTheme.Spacing.tight
                    ) {
                        HStack(spacing: 4) {
                            ForEach(
                                Array(report.summaryParts.enumerated()),
                                id: \.offset
                            ) { index, part in
                                if index > 0 {
                                    Text(verbatim: " · ")
                                }
                                Text(hako: part)
                            }
                        }
                            .font(.headline)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        if report.isRunning {
                            ProgressView(
                                value: Double(report.items.count),
                                total: Double(
                                    max(report.expectedCount, 1)
                                )
                            )
                            Text(
                                "\(report.items.count) of \(report.expectedCount) complete"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, HakoTheme.Spacing.tight)
                }

                Section("Results") {
                    if report.items.isEmpty, !report.isRunning {
                        Text("Nothing needed an update.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(report.items) { item in
                        HStack(
                            alignment: .top,
                            spacing: HakoTheme.Spacing.row
                        ) {
                            icon(symbol(for: item.state))
                                .foregroundStyle(tint(for: item.state))
                                .frame(width: 24, height: 24)
                                .accessibilityHidden(true)
                            VStack(
                                alignment: .leading,
                                spacing: HakoTheme.Spacing.tight
                            ) {
                                Text(item.label)
                                    .font(.body.weight(.semibold))
                                    .fixedSize(
                                        horizontal: false,
                                        vertical: true
                                    )
                                Text(hako: .copy(item.message))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(
                                        horizontal: false,
                                        vertical: true
                                    )
                                if let code = item.diagnosticCode {
                                    Text(code)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(
                                minLength: HakoTheme.Spacing.compact
                            )
                            if item.state == .failed,
                               !report.isRunning {
                                Button("Try Again") {
                                    send(
                                        .retryBatchItem(id: item.id)
                                    )
                                }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier(
                                    "batch.retry.\(item.id)"
                                )
                            }
                        }
                        .padding(.vertical, HakoTheme.Spacing.tight)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier(
                            "batch.result.\(item.id)"
                        )
                    }
                }
            }
            .hakoPageTitle(.copy(report.title))
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    if report.isRunning {
                        Button("Cancel", role: .cancel) {
                            send(.cancelBatch)
                        }
                        .accessibilityIdentifier("batch.cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !report.isRunning {
                        Button("Done") {
                            send(.dismissBatch)
                        }
                        .accessibilityIdentifier("batch.done")
                    }
                }
            }
            .hakoProductModalRoot(
                title: report.title
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                     
                     
                     
                     
                     
                     
                    HakoModalActionBar(
                        primaryTitle: "Done",
                        primaryDisabled: report.isRunning
                    ) {
                        send(.dismissBatch)
                    }
                }
            }
        }
        .interactiveDismissDisabled(report.isRunning)
    }

    private func symbol(
        for state: HakoProfileBatchUpdateState
    ) -> HakoSymbol {
        switch state {
        case .updated:
            .checkmarkCircleFill
        case .unchanged:
             
             
             
             
            .checkmarkCircle
        case .failed:
            .exclamationmarkTriangleFill
        }
    }

    private func tint(
        for state: HakoProfileBatchUpdateState
    ) -> Color {
        switch state {
        case .updated:
            .green
        case .unchanged:
            .green
        case .failed:
            .red
        }
    }

    private func send(_ command: HakoProfilesCommand) {
        Task { @MainActor in
            try? await actions.perform(
                .profiles(command),
                allowedBy: snapshot
            )
        }
    }
}

private struct HakoProfileGroup<
    Content: View
>: View {
    let title: HakoDisplayText
    let palette: HakoProductPalette
    let presentationClass: HakoPresentationClass
    let content: Content

    init(
        title: HakoDisplayText,
        palette: HakoProductPalette,
        presentationClass: HakoPresentationClass,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.palette = palette
        self.presentationClass = presentationClass
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
             
             
             
             
             
             
             
            Section {
                content
            } header: {
                Text(hako: title)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            traditionalGroup
        }
    }

    private var traditionalGroup: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.compact
        ) {
             
             
             
             
             
            Text(hako: title)
                .textCase(.uppercase)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, HakoTheme.Spacing.standard)
            HakoCardSurface(
                fill: palette.card,
                separator: palette.separator
            ) {
                VStack(spacing: 0) {
                    content
                }
                .padding(.horizontal, HakoTheme.Spacing.standard)
                .padding(
                    .vertical,
                    presentationClass == .regularTouch
                        || presentationClass == .desktop
                        ? HakoTheme.Spacing.compact
                        : 0
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HakoProfileActionRow<Icon: View>: View {
    let title: HakoDisplayText
    let subtitle: HakoDisplayText
    let symbol: HakoSymbol
    let tint: Color
    var titleColor: Color = .primary
    var showsDisclosure: Bool = true
    let icon: (HakoSymbol) -> Icon

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityActionRow
            } else {
                HStack(spacing: HakoTheme.Spacing.row) {
                    leadingIcon
                    actionCopy
                    Spacer(minLength: HakoTheme.Spacing.compact)
                    if showsDisclosure {
                        disclosureIcon
                    }
                }
                .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.row
            )
        )
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessibilityActionRow: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.row
        ) {
            HStack {
                leadingIcon
                Spacer(minLength: HakoTheme.Spacing.standard)
                if showsDisclosure {
                    disclosureIcon
                }
            }
            actionCopy
        }
        .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.row
            )
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var leadingIcon: some View {
        icon(symbol)
            .font(.body.weight(.medium))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .accessibilityHidden(true)
    }

    private var actionCopy: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            Text(hako: title)
                .font(.body)
                .foregroundStyle(titleColor)
                .fixedSize(horizontal: false, vertical: true)
            Text(hako: subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var disclosureIcon: some View {
         
         
        if !HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            icon(.chevronForward)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

private struct HakoSubscriptionUsageView: View {
    enum Style {
         
         
         
         
        case row
         
        case detail
    }

    let subscription: HakoProfileSubscriptionSnapshot
    var style: Style = .detail

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

     
     
     
     
     
    static func usedText(
        _ subscription: HakoProfileSubscriptionSnapshot
    ) -> Text? {
        subscription.usageFraction.map {
             
             
             
            Text(hako: .format("%@ used", ["\(Int($0 * 100))%"]))
        }
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityUsageSummary
            } else if style == .detail {
                 
                 
                 
                 
                 
                HStack(
                    alignment: .firstTextBaseline,
                    spacing: HakoTheme.Spacing.compact
                ) {
                    if subscription.totalBytes > 0 {
                        Text(
                            "\(compactBytes(subscription.usedBytes)) of \(compactBytes(subscription.totalBytes))"
                        )
                        .font(.caption)
                        .foregroundStyle(.primary)
                    }
                    Spacer(minLength: HakoTheme.Spacing.compact)
                    if let used = Self.usedText(subscription) {
                        used
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
            }
            if let fraction = subscription.usageFraction {
                HakoUsageGauge(fraction: fraction)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                if style == .detail {
                     
                     
                     
                     
                    detailMetaLine
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else if let expiration = subscription.expiration {
                    Text(hako: .format(
                        "until %@", [dateString(expiration)]
                    ))
                        .font(.caption)
                        .foregroundColor(expiryTint(expiration))
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }


     
     
    private var detailMetaLine: Text {
        var line = Text(
            "↑ \(compactBytes(subscription.uploadBytes)) · ↓ \(compactBytes(subscription.downloadBytes))"
        )
        if let expiration = subscription.expiration {
            line = Text(hako: .format(
                "until %@", [dateString(expiration)]
            ))
                .foregroundColor(expiryTint(expiration))
                + Text(" · ")
                + line
        }
        return line
    }

    private var accessibilityUsageSummary: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            Text(
                "Uploaded \(compactBytes(subscription.uploadBytes))"
            )
            Text(
                "Downloaded \(compactBytes(subscription.downloadBytes))"
            )
            if subscription.totalBytes > 0 {
                Text(
                    "Total \(compactBytes(subscription.totalBytes))"
                )
            }
            if let expiration = subscription.expiration {
                Text("Expires \(dateString(expiration))")
                    .foregroundStyle(expiryTint(expiration))
            }
        }
        .font(.caption2)
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }



    private func compactBytes(_ bytes: Int64) -> String {
        let units = ["K", "M", "G", "T"]
        var value = Double(max(0, bytes)) / 1_024
        var unit = 0
        while value >= 1_000, unit < units.count - 1 {
            value /= 1_024
            unit += 1
        }
        let text = value < 100
            ? String(format: "%.1f", value)
            : String(format: "%.0f", value)
        return text.replacingOccurrences(
            of: ".0",
            with: ""
        ) + units[unit]
    }

     
     
     
     
     
     
     
     
     
    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private func dateString(_ date: Date) -> String {
        Self.expiryFormatter.string(from: date)
    }

    private func expiryTint(_ expiration: Date) -> Color {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone =
            TimeZone(identifier: "UTC")
            ?? TimeZone(secondsFromGMT: 0)!
        let days =
            calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: Date()),
                to: calendar.startOfDay(for: expiration)
            ).day ?? 0
        if days <= 0 {
            return .red
        }
        if days <= 7 {
            return .orange
        }
        return .secondary
    }
}
