import SwiftUI

 
 
 
 
 
 
 
struct HakoRegularPathDepthMarker: ViewModifier {
    let depth: Int

    func body(content: Content) -> some View {
            content
    }
}

 
 
public enum HakoRegularSidebarBehavior: Sendable {
     
    case locked

     
    case system

     
     
    case systemMenuOnly

    fileprivate var removesSidebarToolbarToggle: Bool {
        switch self {
        case .locked, .systemMenuOnly:
            true
        case .system:
            false
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    var usesFixedSidebarWidth: Bool {
        switch self {
        case .locked, .systemMenuOnly:
            true
        case .system:
            false
        }
    }
}

private enum HakoRegularColumnVisibility: Sendable {
    case automatic
    case all
    case doubleColumn
    case detailOnly
}

 
 
 
 
 
 
 
 
 
public struct HakoRoutePusher: Equatable {
     
     
     
     
     
     
     
     
     
     
    private let token: UUID
    private let push: (any Hashable) -> Void

    public init(
        token: UUID = UUID(),
        _ push: @escaping (any Hashable) -> Void
    ) {
        self.token = token
        self.push = push
    }

    public func callAsFunction(_ route: any Hashable) {
        push(route)
    }

    public static func == (a: Self, b: Self) -> Bool {
        a.token == b.token
    }
}

public struct HakoRoutePusherKey: EnvironmentKey {
     
     
    nonisolated(unsafe) public static let defaultValue: HakoRoutePusher? = nil
}

public extension EnvironmentValues {
    var hakoPushRoute: HakoRoutePusher? {
        get { self[HakoRoutePusherKey.self] }
        set { self[HakoRoutePusherKey.self] = newValue }
    }

     
     
     
     
     
     
     
     
    var hakoPopRoute: HakoRoutePusher? {
        get { self[HakoPopRouteKey.self] }
        set { self[HakoPopRouteKey.self] = newValue }
    }
}

public struct HakoPopRouteKey: EnvironmentKey {
    nonisolated(unsafe) public static let defaultValue: HakoRoutePusher? = nil
}

#if !os(tvOS)
 
 
 
 
 
public struct HakoRegularClientShell<
    Icon: View,
    RootContent: View,
    DestinationContent: View,
    DetailOverlay: View
>: View {
    @Binding private var navigationState: AppleClientNavigationState
    @State private var columnVisibility: HakoRegularColumnVisibility
    @State private var rootScrollTopVisible = true
     
     
     
     
     
     
     
     
     
     
     
    @State private var presentedPathBox = HakoPresentedPathBox()
     
     
    @State private var pushTokens = HakoRoutePusherTokens()
     
     
     
     
     
     
     
     
     
    @State private var tallestRootBarInset: CGFloat = 0
    @State private var currentRootBarInset: CGFloat = 0
     
     
     
     
     
     
    @State private var stackContentOrigin: CGPoint = .zero
    @StateObject private var rootDepartureGuard = HakoRootDepartureGuard()
    @ObservedObject private var modalCenter = HakoModalCenter.shared
     
     
     
     
    @Environment(\.dynamicTypeSize) private var shellDynamicTypeSize

    private let sidebarBehavior: HakoRegularSidebarBehavior
    private let background: Color
    private let sidebarBackground: Color

    private let icon: (HakoRootDestination) -> Icon
    private let rootContent: (HakoRootDestination) -> RootContent
    private let destinationContent: (AppleClientDestination) -> DestinationContent
     
     
     
     
     
     
     
     
     
    private let detailOverlay: (HakoRootDestination?) -> DetailOverlay

    public init(
        navigationState: Binding<AppleClientNavigationState>,
        sidebarBehavior: HakoRegularSidebarBehavior,
        background: Color,
        sidebarBackground: Color,
        @ViewBuilder icon: @escaping (HakoRootDestination) -> Icon,
        @ViewBuilder rootContent: @escaping (HakoRootDestination) -> RootContent,
        @ViewBuilder destinationContent: @escaping (
            AppleClientDestination
        ) -> DestinationContent,
        @ViewBuilder detailOverlay: @escaping (
            HakoRootDestination?
        ) -> DetailOverlay
    ) {
        _navigationState = navigationState
        _columnVisibility = State(
            initialValue: sidebarBehavior == .locked ? .all : .automatic
        )
        self.sidebarBehavior = sidebarBehavior
        self.background = background
        self.sidebarBackground = sidebarBackground
        self.icon = icon
        self.rootContent = rootContent
        self.destinationContent = destinationContent
        self.detailOverlay = detailOverlay
    }

    @ViewBuilder
    public var body: some View {
        Group {
            if #available(iOS 16.0, macOS 13.0, *) {
                splitView
            } else {
                legacySplitView
            }
        }
         
         
         
         
        .allowsHitTesting(!modalCenter.isPresenting)
        .accessibilityHidden(modalCenter.isPresenting)
         
         
         
        .modifier(HakoWindowToolbarHiddenWhilePanelUp())
         
         
         
        .overlay {
            HakoProductModalLayer()
        }
        .environment(\.hakoRootDepartureGuard, rootDepartureGuard)
        .alert(
            "Save your changes?",
            isPresented: Binding(
                get: { rootDepartureGuard.isPromptPresented },
                 
                 
                 
                set: { _ in }
            )
        ) {
            Button("Save") { rootDepartureGuard.saveAndLeave() }
            Button("Discard", role: .destructive) {
                rootDepartureGuard.discardAndLeave()
            }
            Button("Keep Editing", role: .cancel) {
                rootDepartureGuard.keepEditing()
            }
        } message: {
            Text("This page has changes that have not been saved.")
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @available(iOS 16.0, macOS 13.0, *)
    @ViewBuilder
    private func hostedDetailStack<C: View>(
        @ViewBuilder _ content: () -> C
    ) -> some View {
        NavigationStack(path: presentedPathBinding) {
            content()
        }
         
         
         
         
         
         
         
         
         
         
        .id(
            HakoPlatformLayout.regularShellKeepsContainer
                ? AnyHashable(navigationState.selectedRoot)
                : AnyHashable("hako.detail.stack")
        )

         
         
         
         
         
         
        .environment(
            \.hakoPushRoute,
            HakoRoutePusher(token: pushTokens.push) { route in
                var updated = presentedPathBinding.wrappedValue
                updated.append(route)
                presentedPathBinding.wrappedValue = updated
            }
        )
        .environment(\.hakoNavigationHostContext, .regularDetail)
        .onAppear {
            HakoNavigationHooks.pop = {
                var updated = presentedPathBinding.wrappedValue
                guard !updated.isEmpty else { return }
                updated.removeLast()
                presentedPathBinding.wrappedValue = updated
            }
        }
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        .hakoRegularStackCanvas(background)
    }

    @available(iOS 16.0, macOS 13.0, *)
    private var presentedPathBinding: Binding<NavigationPath> {
        Binding(
            get: { presentedPathBox.path },
            set: { presented in
                 
                 
                 
                HakoNavigationTransaction.applyPathChange {
                let previous = presentedPathBox.path
                 
                 
                HakoPageProbe.markNavigation()
                presentedPathBox.path = presented
                 
                 
                 
                 
                 
                 
                 
                guard presented.count < previous.count,
                      presented.count < navigationState.path.count
                else { return }
                _ = navigationState.replacePath(
                    Array(navigationState.path.prefix(presented.count))
                )
                }
            }
        )
    }

    @available(iOS 16.0, macOS 13.0, *)
    private var splitView: some View {
        NavigationSplitView(columnVisibility: columnVisibilityBinding) {
            withSidebarColumnWidth(sidebarColumn)
        } detail: {
            ZStack {
                detailBackground

                stackAndOverlay
            }
        }
        .navigationSplitViewStyle(.balanced)
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        .id(
            HakoPlatformLayout.regularShellKeepsContainer
                ? AnyHashable("hako.regular.container")
                : AnyHashable(navigationState.selectedRoot)
        )
        .hakoWindowContainerBackground(background)
    }

     
     
     
     
     
     
     
     
     
    @available(iOS 16.0, macOS 13.0, *)
    @ViewBuilder
    private var stackAndOverlay: some View {
        ZStack {
                hostedDetailStack {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                HakoRegularDetailNavigationFrame(background: background) {
                    VStack(alignment: .leading, spacing: 0) {
                        if usesInContentRegularRootTitle {
                            Text(hako: .copy(regularRootTitle))
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("regular.detail.title")
                                .padding(.horizontal, HakoTheme.Spacing.standard)
                                 
                                 
                                 
                                 
                                .padding(.top, HakoTheme.Spacing.section)
                                .padding(.top, reservedBarInset)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        regularRootContent(shellDrawsHeading: true)
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                            .environment(\.hakoNavigationDepth, 0)
                    }
                }
                .background(barInsetProbe)
                 
                 
                 
                 
                 
                 
                 
                 
                .navigationTitle(
                    modalCenter.isPresenting
                        ? "" : regularNavigationTitle.hakoLocalized
                )
                .onPreferenceChange(
                    HakoRegularRootTopVisibilityPreferenceKey.self
                ) {
                     
                     
                    if rootScrollTopVisible != $0 {
                        rootScrollTopVisible = $0
                    }
                }
                .toolbar {
                    if showsCompensatingInlineRootTitle {
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 0) {
                                Text(hako: .copy(regularRootTitle))
                                    .font(.headline)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(regularRootTitle.hakoLocalized)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier(
                                "regular.collapsed.title"
                            )
                        }
                    }
                }
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                .hakoWithoutSidebarToggle(
                    when: sidebarBehavior.removesSidebarToolbarToggle
                )
                 
                 
                 
                 
                 
                .navigationDestination(for: HakoViewRoute.self) { route in
                    HakoLazyView {
                        HakoViewRouteRegistry.view(for: route)
                    }
                        .hakoPushedDetailPage()
                         
                         
                         
                         
                         
                        .modifier(HakoSetterRoutedBack())
                         
                         
                         
                         
                         
                        .environment(
                            \.hakoPushRoute,
                            HakoRoutePusher(token: pushTokens.push) { nestedRoute in
                                var updated = presentedPathBinding.wrappedValue
                                updated.append(nestedRoute)
                                presentedPathBinding.wrappedValue = updated
                            }
                        )
                        .environment(
                            \.hakoPopRoute,
                            HakoRoutePusher(token: pushTokens.pop) { _ in
                                var updated = presentedPathBinding.wrappedValue
                                guard !updated.isEmpty else { return }
                                updated.removeLast()
                                presentedPathBinding.wrappedValue = updated
                                DispatchQueue.main.async {
                                    HakoViewRouteRegistry.returnFrom(route)
                                }
                            }
                        )
                        .environment(
                            \.hakoRegularShellOwnsCanvas,
                            HakoPushedCanvasOwnership.shellOwnsPushedCanvas
                        )
                         
                         
                         
                         
                         
                        .environment(\.hakoDetailCanvas, background)
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                        .environment(
                            \.hakoNavigationHostContext,
                            .regularDetail
                        )
                }
                .navigationDestination(for: AppleClientDestination.self) {
                    destination in
                     
                     
                     
                     
                     
                     
                     
                     
                    HakoRegularDetailNavigationFrame(background: background) {
                        HakoLazyView {
                            destinationContent(destination)
                        }
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                            .environment(
                                \.hakoNavigationHostContext, .regularDetail
                            )
                            .hakoPushedDetailPage()
                    }
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    .environment(
                        \.hakoPushRoute,
                        HakoRoutePusher(token: pushTokens.push) { route in
                            var updated = presentedPathBinding.wrappedValue
                            updated.append(route)
                            presentedPathBinding.wrappedValue = updated
                        }
                    )
                    .environment(
                        \.hakoPopRoute,
                        HakoRoutePusher(token: pushTokens.pop) { _ in
                            var updated = presentedPathBinding.wrappedValue
                            guard !updated.isEmpty else { return }
                            updated.removeLast()
                            presentedPathBinding.wrappedValue = updated
                        }
                    )
                    .modifier(HakoSetterRoutedBack())
                     
                     
                     
                     
                     
                     
                     
                    .environment(
                        \.hakoRegularShellOwnsCanvas,
                        HakoPushedCanvasOwnership.shellOwnsPushedCanvas
                    )
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    .hakoWithoutSidebarToggle(
                        when: sidebarBehavior.removesSidebarToolbarToggle
                    )
                     
                     
                     
                     
                     
                     
                }
                }
                .modifier(
                    HakoRegularPathDepthMarker(
                        depth: navigationState.path.count
                    )
                )
                .onChange(of: shellDynamicTypeSize) { _ in
                    tallestRootBarInset = 0
                    currentRootBarInset = 0
                }
                .onChange(of: navigationState.selectedRoot) { _ in
                    HakoPerf.markShellRootChange(
                        to: String(describing: navigationState.selectedRoot)
                    )
                    rootScrollTopVisible = true
                     
                     
                     
                     
                     
                     
                     
                    presentedPathBox.path = NavigationPath(
                        navigationState.path
                    )
                }
                 
                 
                 
                 
                 
                 
                 
                .onChange(of: navigationState.path) { typed in
                    presentedPathBox.path = NavigationPath(typed)
                    reassertLockedSidebar()
                }
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                .onChange(of: presentedPathBox.path.count) { _ in
                    reassertLockedSidebar()
                }
                .onAppear {
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    if presentedPathBox.path.isEmpty {
                        presentedPathBox.path = NavigationPath(
                            navigationState.path
                        )
                    }
                }

             
             
             
             
            detailOverlay(
                presentedPathBox.path.isEmpty
                    ? navigationState.selectedRoot
                    : nil
            )
                .padding(.top, stackContentOrigin.y)
                .padding(.leading, stackContentOrigin.x)
                 
                 
                 
                 
                 
                .environment(
                    \.hakoPushRoute,
                    HakoRoutePusher(token: pushTokens.push) { route in
                        var updated = presentedPathBinding.wrappedValue
                        updated.append(route)
                        presentedPathBinding.wrappedValue = updated
                    }
                )
                .environment(
                    \.hakoPopRoute,
                    HakoRoutePusher(token: pushTokens.pop) { _ in
                        var updated = presentedPathBinding.wrappedValue
                        guard !updated.isEmpty else { return }
                        updated.removeLast()
                        presentedPathBinding.wrappedValue = updated
                    }
                )
        }
        .coordinateSpace(name: Self.detailSpace)
    }

    private static var detailSpace: String { "hako.regular.detail" }

    private var legacySplitView: some View {
        NavigationView {
            sidebar
                .frame(width: HakoTheme.Regular.Sidebar.width)

            HakoRegularDetailNavigationFrame(background: background) {
                regularRootContent(shellDrawsHeading: false)
            }
        }
        .navigationViewStyle(.columns)
    }

    @ViewBuilder
    @available(iOS 16.0, macOS 13.0, *)
    private var sidebarColumn: some View {
        if sidebarBehavior == .locked {
            lockedSidebarColumn
                .hakoWithoutSidebarToggle()
                .hakoWithoutNavigationBar()
        } else {
            sidebar
                .hakoWithoutSidebarToggle(
                    when: sidebarBehavior.removesSidebarToolbarToggle
                )
                .toolbar {
                    if sidebarBehavior == .systemMenuOnly {
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                        if #available(iOS 26.0, macOS 26.0, *) {
                            ToolbarItem(placement: .automatic) {
                                sidebarToolbarPlaceholder
                            }
                            .sharedBackgroundVisibility(.hidden)
                        } else {
                            ToolbarItem(placement: .automatic) {
                                sidebarToolbarPlaceholder
                            }
                        }
                    }
                }
        }
    }

     
     
    private var sidebarToolbarPlaceholder: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityHidden(true)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    @available(iOS 16.0, macOS 13.0, *)
    private func withSidebarColumnWidth<C: View>(_ column: C) -> some View {
        if sidebarBehavior == .locked {
            column
        } else if sidebarBehavior.usesFixedSidebarWidth {
            column
                .navigationSplitViewColumnWidth(
                    HakoTheme.Regular.Sidebar.width
                )
        } else {
            column
                .navigationSplitViewColumnWidth(
                    min: HakoTheme.Regular.Sidebar.minimumWidth,
                    ideal: HakoTheme.Regular.Sidebar.width,
                    max: HakoTheme.Regular.Sidebar.maximumWidth
                )
        }
    }

    @available(iOS 16.0, macOS 13.0, *)
    private var lockedSidebarColumn: some View {
        sidebar
            .navigationSplitViewColumnWidth(
                min: HakoTheme.Regular.Sidebar.width,
                ideal: HakoTheme.Regular.Sidebar.width,
                max: HakoTheme.Regular.Sidebar.width
            )
    }

    @ViewBuilder
    private var sidebar: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            sidebarList
                .scrollContentBackground(.hidden)
                .background(sidebarSurfaceBackground)
        } else {
            sidebarList
                .background(sidebarSurfaceBackground)
        }
    }

     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private var sidebarList: some View {
        if HakoPlatformLayout.sidebarFooterConsumesOwnLayoutSpace {
             
             
             
             
            VStack(spacing: 0) {
                sidebarScrollingList
                    .safeAreaInset(edge: .top, spacing: 0) {
                        sidebarTopInset
                    }
                sidebarFoot
            }
            .background(sidebarSurfaceBackground)
        } else {
            sidebarScrollingList
                .safeAreaInset(edge: .top, spacing: 0) {
                    sidebarTopInset
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    sidebarFoot
                }
        }
    }

    private var sidebarScrollingList: some View {
        List {
             
             
             
             
            ForEach(HakoRootSidebarGroup.allCases, id: \.self) { group in
                if group != .footer, group != .hub {
                    sidebarSection(group)
                }
            }
        }
        .modifier(HakoSidebarFlushContentMargins())
        .accessibilityIdentifier("app.sidebar")
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func sidebarSection(_ group: HakoRootSidebarGroup) -> some View {
        let rows = HakoRootDestination.sidebarRows(in: group)
        if !rows.isEmpty {
            if let title = group.title {
                Section {
                    ForEach(rows) { navigationRow($0) }
                } header: {
                     
                     
                     
                    Text(hako: .copy(title))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                         
                         
                         
                         
                         
                         
                         
                         
                        .padding(
                            .leading,
                            HakoTheme.Regular.Sidebar
                                .sectionHeaderLeadingCompensation
                        )
                        .listRowInsets(
                            EdgeInsets(
                                top: 10,
                                leading:
                                    HakoTheme.Regular.Sidebar.rowLeadingInset
                                    + HakoTheme.Spacing.compact,
                                bottom: 4,
                                trailing: 12
                            )
                        )
                }
            } else {
                Section {
                    ForEach(rows) { navigationRow($0) }
                }
            }
        }
    }

     
     
     
     
     
    @ViewBuilder
    private var sidebarFoot: some View {
        let hubs = HakoRootDestination.sidebarRows(in: .hub)
        let footer = HakoRootDestination.sidebarRows(in: .footer)
        if !hubs.isEmpty || !footer.isEmpty {
            VStack(spacing: 0) {
                if !hubs.isEmpty {
                     
                     
                     
                     
                     
                     
                    Color.clear
                        .frame(height: 12)
                        .accessibilityHidden(true)
                    ForEach(hubs) { destination in
                        navigationRow(destination)
                             
                             
                             
                             
                             
                            .padding(
                                .leading,
                                HakoTheme.Regular.Sidebar.rowLeadingInset
                                    + HakoTheme.Regular.Sidebar
                                        .pinnedRowSectionIndent
                            )
                            .padding(.trailing, 12)
                            .padding(.vertical, 2)
                    }
                }
                if !footer.isEmpty {
                    Divider()
                        .padding(.top, 6)
                    ForEach(footer) { destination in
                        navigationRow(destination)
                            .padding(
                                .leading,
                                HakoTheme.Regular.Sidebar.rowLeadingInset
                                    + HakoTheme.Regular.Sidebar
                                        .pinnedRowSectionIndent
                            )
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                    }
                }
            }
            .background(sidebarSurfaceBackground)
        }
    }

     
     
     
     
     
     
     
     
     
     
     
    private struct SidebarRow<RowIcon: View>: View, Equatable {
        let destination: HakoRootDestination
        let isSelected: Bool
        let isDisabled: Bool
        let icon: () -> RowIcon
        let activate: () -> Void

        nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.destination == rhs.destination
                && lhs.isSelected == rhs.isSelected
                && lhs.isDisabled == rhs.isDisabled
        }

        var body: some View {
            Button(action: activate) {
                HakoRootSidebarRow(
                    destination: destination,
                    isSelected: isSelected
                ) {
                    icon()
                        .foregroundStyle(
                            isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
                        )
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
        }
    }

    private func navigationRow(
        _ destination: HakoRootDestination
    ) -> some View {
        let isSelected = navigationState.selectedRoot == destination
        return SidebarRow(
            destination: destination,
            isSelected: isSelected,
            isDisabled: rootDepartureGuard.isBusy && !isSelected,
            icon: { icon(destination) },
            activate: {
                 
                 
                 
                guard !isSelected else {
                    selectRoot(destination)
                    return
                }
                rootDepartureGuard.requestDeparture {
                    selectRoot(destination)
                }
            }
        )
        .equatable()
        .listRowInsets(
            EdgeInsets(
                top: 2,
                leading: HakoTheme.Regular.Sidebar.rowLeadingInset,
                bottom: 2,
                trailing: 12
            )
        )
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(
            isSelected ? [.isButton, .isSelected] : .isButton
        )
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityIdentifier("sidebar.\(destination.rawValue)")
         
         
         
         
        .accessibilityHidden(modalCenter.isPresenting)
    }

    private func legacyNavigationRow(
        _ destination: HakoRootDestination
    ) -> some View {
        Button {
             
             
             
            guard destination != navigationState.selectedRoot else {
                selectRoot(destination)
                return
            }
            rootDepartureGuard.requestDeparture {
                selectRoot(destination)
            }
        } label: {
            HakoRootSidebarRow(
                destination: destination,
                isSelected: navigationState.selectedRoot == destination
            ) {
                icon(destination)
                    .foregroundStyle(
                        navigationState.selectedRoot == destination
                            ? AnyShapeStyle(.tint)
                            : AnyShapeStyle(.secondary)
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(
            rootDepartureGuard.isBusy
                && navigationState.selectedRoot != destination
        )
        .listRowInsets(
            EdgeInsets(
                top: 2,
                leading: HakoTheme.Regular.Sidebar.rowLeadingInset,
                bottom: 2,
                trailing: 12
            )
        )
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(
            navigationState.selectedRoot == destination
                ? [.isButton, .isSelected]
                : .isButton
        )
        .accessibilityValue(
            navigationState.selectedRoot == destination
                ? "Selected"
                : ""
        )
        .accessibilityIdentifier("sidebar.\(destination.rawValue)")
         
         
         
         
        .accessibilityHidden(modalCenter.isPresenting)
        .allowsHitTesting(!modalCenter.isPresenting)
        .disabled(modalCenter.isPresenting)
        .modifier(
            HakoOptionalCommandShortcut(
                key: keyboardShortcut(for: destination)
            )
        )
    }

    private func selectRoot(_ destination: HakoRootDestination) {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            let intercepted = HakoNavigationTransaction
                .interceptRootSelection(
                    isCurrentRoot:
                        navigationState.selectedRoot == destination,
                    hasPresentedPath: !presentedPathBox.path.isEmpty
                ) {
                presentedPathBinding.wrappedValue = NavigationPath()
                }
            if intercepted { return }
        }
        navigationState.selectRoot(destination)
    }

    private var sidebarTopInset: some View {
        Color.clear
            .frame(height: HakoTheme.Regular.Sidebar.topInset)
            .accessibilityHidden(true)
    }

    @ViewBuilder
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func regularRootContent(shellDrawsHeading: Bool) -> some View {
        Group {
             
             
            rootContent(navigationState.selectedRoot)
                .environment(\.hakoRegularRootScrollsContent, false)
        }
        .id(navigationState.selectedRoot)
         
         
         
         
         
        .environment(
            \.hakoRegularRootLargeTitle,
            shellDrawsHeading
                ? nil
                : (usesInContentRegularRootTitle ? regularRootTitle : nil)
        )
        .environment(\.hakoRegularShellOwnsCanvas, true)
        .environment(\.hakoShellDrawsRootHeading, shellDrawsHeading)
    }

     
     
     
    private var barInsetProbe: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .named(Self.detailSpace)).origin
            Color.clear
                .onAppear {
                    recordBarInset(proxy.safeAreaInsets.top)
                    recordStackContentOrigin(origin)
                }
                .onChange(of: proxy.safeAreaInsets.top) {
                    recordBarInset($0)
                }
                .onChange(of: origin) {
                    recordStackContentOrigin($0)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func recordStackContentOrigin(_ origin: CGPoint) {
         
         
         
        let clamped = CGPoint(
            x: Self.quantised(max(0, origin.x)),
            y: Self.quantised(max(0, origin.y))
        )
        if stackContentOrigin != clamped {
            stackContentOrigin = clamped
        }
    }

    private func recordBarInset(_ inset: CGFloat) {
        let quantised = Self.quantised(inset)
         
         
        if currentRootBarInset != quantised {
            currentRootBarInset = quantised
        }
        if quantised > tallestRootBarInset {
            tallestRootBarInset = quantised
        }
    }

     
     
    private static func quantised(_ value: CGFloat) -> CGFloat {
        (value * 2).rounded() / 2
    }

     
     
    private var reservedBarInset: CGFloat {
        max(0, tallestRootBarInset - currentRootBarInset)
    }

    private var regularRootTitle: String {
        navigationState.selectedRoot == .home
            ? ""
            : navigationState.selectedRoot.title
    }

    private var regularNavigationTitle: String {
        usesInContentRegularRootTitle ? "" : regularRootTitle
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var usesInContentRegularRootTitle: Bool {
         
         
         
        !HakoPlatformLayout.pageUsesSystemSettingsIdiom
            && sidebarBehavior.usesFixedSidebarWidth
            && navigationState.selectedRoot != .home
    }

    private var showsCompensatingInlineRootTitle: Bool {
        HakoPlatformLayout.installsCompensatingInlineRootTitle
            && usesInContentRegularRootTitle
            && navigationState.path.isEmpty
            && !rootScrollTopVisible
    }

    @ViewBuilder
    private var sidebarSurfaceBackground: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            Color.clear
        } else {
            sidebarBackground.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var detailBackground: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            background
                .ignoresSafeArea()
                .backgroundExtensionEffect()
        } else {
            background.ignoresSafeArea()
        }
    }


     
     
    private func reassertLockedSidebar() {
        guard sidebarBehavior == .locked, columnVisibility != .all else {
            return
        }
        columnVisibility = .all
    }

    @available(iOS 16.0, macOS 13.0, *)
    private var columnVisibilityBinding:
        Binding<NavigationSplitViewVisibility>
    {
        Binding(
            get: {
                switch columnVisibility {
                case .automatic:
                    .automatic
                case .all:
                    .all
                case .doubleColumn:
                    .doubleColumn
                case .detailOnly:
                    .detailOnly
                }
            },
            set: { visibility in
                if sidebarBehavior == .locked {
                    columnVisibility = .all
                } else if visibility == .all {
                    columnVisibility = .all
                } else if visibility == .doubleColumn {
                    columnVisibility = .doubleColumn
                } else if visibility == .detailOnly {
                    columnVisibility = .detailOnly
                } else {
                    columnVisibility = .automatic
                }
            }
        )
    }



     
    private func keyboardShortcut(
        for destination: HakoRootDestination
    ) -> KeyEquivalent? {
        guard let index = HakoRootDestination.sidebarRows
            .firstIndex(of: destination),
            index < 9,
            let scalar = Unicode.Scalar(String(index + 1)) else {
            return nil
        }
        return KeyEquivalent(Character(scalar))
    }
}

 
 
 
 
 
private struct HakoSidebarFlushContentMargins: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            content.contentMargins(.horizontal, 0, for: .scrollContent)
        } else {
            content
        }
    }
}

private struct HakoOptionalCommandShortcut: ViewModifier {
    let key: KeyEquivalent?

    func body(content: Content) -> some View {
        if let key {
            content.keyboardShortcut(key, modifiers: .command)
        } else {
            content
        }
    }
}

 
 
 
struct HakoPresentedPathBox {
    private var storage: Any?

    @available(iOS 16.0, macOS 13.0, *)
    var path: NavigationPath {
        get { storage as? NavigationPath ?? NavigationPath() }
        set { storage = newValue }
    }
}



extension View {
     
     
     
     
     
    @ViewBuilder
    func hakoWithoutSidebarToggle(when shouldRemove: Bool = true) -> some View {
        if shouldRemove, #available(iOS 17.0, macOS 14.0, *) {
            self.toolbar(removing: .sidebarToggle)
        } else {
            self
        }
    }

     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoWithoutNavigationBar() -> some View {
         
         
         
         
         
        if #available(iOS 16.0, macOS 13.0, *) {
            self.toolbar(.hidden, for: .automatic)
        } else {
            self
        }
    }
}
#endif


 
struct HakoRoutePusherTokens {
    let push = UUID()
    let pop = UUID()
}

#if !os(tvOS)
public extension HakoRegularClientShell where DetailOverlay == EmptyView {
     
    init(
        navigationState: Binding<AppleClientNavigationState>,
        sidebarBehavior: HakoRegularSidebarBehavior,
        background: Color,
        sidebarBackground: Color,
        @ViewBuilder icon: @escaping (HakoRootDestination) -> Icon,
        @ViewBuilder rootContent: @escaping (HakoRootDestination) -> RootContent,
        @ViewBuilder destinationContent: @escaping (
            AppleClientDestination
        ) -> DestinationContent
    ) {
        self.init(
            navigationState: navigationState,
            sidebarBehavior: sidebarBehavior,
            background: background,
            sidebarBackground: sidebarBackground,
            icon: icon,
            rootContent: rootContent,
            destinationContent: destinationContent,
            detailOverlay: { _ in EmptyView() }
        )
    }
}
#endif
