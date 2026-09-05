import SwiftUI

public struct HakoConnectionsView<Icon: View>: View {
    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let presentationClass: HakoPresentationClass
    private let palette: HakoProductPalette
    private let icon: (HakoSymbol) -> Icon

    @State private var query = ""
    @State private var sort: HakoActivityConnectionSort =
        .recent
    @State private var keywords: Set<String> = []
    @State private var confirmsCloseAll = false
     
     
     
     
     
     
     
     
    @State private var prepared: [HakoActivityConnectionSnapshot] = []
     
     
    @State private var preparedTotal = 0
     
     
     
    @State private var preparedSummaries: [HakoActivityChainSummary] = []
     
     
    @State private var hasPrepared = false
    @State private var selected:
        HakoActivityConnectionSnapshot?

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        presentationClass: HakoPresentationClass,
        palette: HakoProductPalette,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.presentationClass = presentationClass
        self.palette = palette
        self.icon = icon
    }

    public var body: some View {
        List {
            if !keywords.isEmpty {
                filterSection
            }

            if let error = snapshot.activity.errorDescription,
               !error.isEmpty
            {
                Section {
                    VStack(
                        alignment: .leading,
                        spacing: HakoTheme.Spacing.compact
                    ) {
                        Text(error)
                            .foregroundStyle(.red)
                        if snapshot.activity.phase == .failed {
                            Button {
                                send(.refresh)
                            } label: {
                                Label(
                                    "Retry",
                                    systemImage:
                                        HakoSymbol
                                        .arrowClockwise
                                        .rawValue
                                )
                            }
                        }
                    }
                }
            }

            if hasPrepared && visibleConnections.isEmpty {
                emptyState
            }

            if !chainSummaries.isEmpty {
                Section("Chain Totals") {
                    ForEach(chainSummaries) { summary in
                        VStack(
                            alignment: .leading,
                            spacing: HakoTheme.Spacing.tight
                        ) {
                            Text(summary.path)
                                .font(.subheadline.weight(.medium))
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                            Text(
                                "\(summary.connectionCount) connections · ↑ \(HakoActivityByteFormatter.count(summary.upload)) · ↓ \(HakoActivityByteFormatter.count(summary.download))"
                            )
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            ForEach(visibleConnections) { connection in
                HakoActivityConnectionRow(
                    connection: connection,
                    detailTitle: "Connection Details",
                    actions: actions,
                    snapshot: snapshot,
                    isBusy:
                        snapshot.activity.closingConnectionIDs
                        .contains(connection.id),
                    showsCloseAction:
                        snapshot.activity.canManageConnections,
                    isCloseDisabled:
                        snapshot.activity.isClosingAll
                        || snapshot.activity
                        .closingConnectionIDs
                        .contains(connection.id),
                    palette: palette,
                    onKeyword: { keywords.insert($0) },
                    onClose: {
                        send(
                            .closeConnection(
                                id: connection.id
                            )
                        )
                    }
                )
                .modifier(
                    HakoActivityTouchSelection(
                        selected: $selected,
                        connection: connection
                    )
                )
            }

             
             
            if preparedTotal > visibleConnections.count {
                Text(hako: .format(
                    "Showing first %@ of %@ connections",
                    ["\(visibleConnections.count)", "\(preparedTotal)"]
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("connections.renderCap")
            }
        }
        .hakoGroupedList()
         
         
         
        .hakoListRetainsRowSelection()
        .hakoActivityListCanvas(palette.canvas)
        .accessibilityIdentifier("connections.overview")
        .accessibilityValue(activityAccessibilityValue)
        .hakoRootHeading("Connections")
        .task(id: preparationKey) { await prepareConnections() }
        .searchable(
            text: $query,
            prompt: "Destination, route, or rule"
        )
        .refreshable {
            await perform(.refresh)
        }
        .hakoToolbarUnlessInPanel { toolbarContent }
        .confirmationDialog(
            "Close all active connections?",
            isPresented: $confirmsCloseAll
        ) {
            Button("Close All", role: .destructive) {
                send(.closeAllConnections)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apps may reconnect automatically.")
        }
        .modifier(
            HakoActivityDetailHost(
                selected: $selected,
                title: "Connection Details",
                actions: actions,
                snapshot: snapshot
            )
        )
    }

    private var visibleConnections:
        [HakoActivityConnectionSnapshot]
    { prepared }

    private struct ConnectionsPreparationKey: Equatable {
        let count: Int
        let firstID: String?
        let lastID: String?
        let trafficChecksum: UInt64
        let query: String
        let sort: HakoActivityConnectionSort
        let keywords: Set<String>
    }

    private var preparationKey: ConnectionsPreparationKey {
         
         
         
         
         
        var checksum: UInt64 = 0
        for connection in snapshot.activity.connections {
            checksum = checksum
                &+ UInt64(bitPattern: Int64(connection.upload))
                &+ UInt64(bitPattern: Int64(connection.download)) &* 31
        }
        return ConnectionsPreparationKey(
            count: snapshot.activity.connections.count,
            firstID: snapshot.activity.connections.first?.id,
            lastID: snapshot.activity.connections.last?.id,
            trafficChecksum: checksum,
            query: query,
            sort: sort,
            keywords: keywords
        )
    }

    @MainActor
    private func prepareConnections() async {
        let values = snapshot.activity.connections
        let query = query
        let sort = sort
        let keywords = keywords
         
         
        let result = await Task.detached(priority: .userInitiated) {
            () -> (
                rows: [HakoActivityConnectionSnapshot],
                total: Int,
                summaries: [HakoActivityChainSummary]
            ) in
            let full = HakoActivityProjection.connections(
                values, query: query, sort: sort, keywords: keywords,
                limit: nil
            )
            return (
                rows: Array(
                    full.prefix(HakoActivityProjection.connectionRenderCap)
                ),
                total: full.count,
                summaries: HakoActivityProjection.chainSummaries(full)
            )
        }.value
         
         
        if Task.isCancelled { return }
        prepared = result.rows
        preparedTotal = result.total
        preparedSummaries = result.summaries
        hasPrepared = true
    }

    private var chainSummaries:
        [HakoActivityChainSummary]
    { preparedSummaries }

    private var filterSection: some View {
        Section("Filters") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: HakoTheme.Spacing.compact) {
                    ForEach(keywords.sorted(), id: \.self) {
                        keyword in
                        HakoActivityKeywordButton(
                            title: .verbatim(keyword)
                        ) {
                            keywords.remove(keyword)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator,
            cornerRadius: HakoTheme.Radius.groupedSection
        ) {
            HakoEmptyState(
                title: emptyTitle,
                message: emptyMessage,
                isLoading: snapshot.activity.phase == .loading
            ) {
                icon(
                    snapshot.activity.phase == .disconnected
                        ? .boltSlash
                        : query.isEmpty && keywords.isEmpty
                            ? .rectangleStack
                            : .magnifyingglass
                )
            }
            .padding(.vertical, HakoTheme.Spacing.section)
        }
        .listRowBackground(Color.clear)
    }

    private var emptyTitle: String {
        switch snapshot.activity.phase {
        case .loading:
            "Loading Connections"
        case .disconnected:
            "Clash Is Disconnected"
        case .failed:
            "Connections Unavailable"
        case .ready:
            query.isEmpty && keywords.isEmpty
                ? "No Active Connections"
                : "No Matches"
        }
    }

    private var emptyMessage: String {
        switch snapshot.activity.phase {
        case .loading:
            "Reading the live connection snapshot."
        case .disconnected:
            "Connect Clash to inspect live sessions."
        case .failed:
            "Retry after the current connection is available."
        case .ready:
            query.isEmpty && keywords.isEmpty
                ? "Connections appear here while apps use the tunnel."
                : "Try a different search term or remove a filter."
        }
    }

    private var activityAccessibilityValue: String {
        switch snapshot.activity.phase {
        case .ready:
            "Connected"
        case .loading:
            "Loading"
        case .disconnected, .failed:
            "Disconnected"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
         
         
        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                Menu {
                    Picker("Sort", selection: $sort) {
                        ForEach(
                            HakoActivityConnectionSort.allCases
                        ) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                        .accessibilityIdentifier("activity.detail.sort")
                    .hakoFlattensMenuChoices()
                } label: {
                    Label(
                        "Sort",
                        systemImage:
                            HakoSymbol.arrowUpArrowDown.rawValue
                    )
                }
                .accessibilityIdentifier("connections.sort")

                if snapshot.activity.canManageConnections {
                     
                     
                     
                    HakoToolbarDivider()

                    Button(role: .destructive) {
                        confirmsCloseAll = true
                    } label: {
                        Label(
                            "Close All",
                            systemImage:
                                HakoSymbol.xmark.rawValue
                        )
                    }
                    .disabled(
                        snapshot.activity.activeConnectionCount == 0
                            || snapshot.activity.isClosingAll
                            || !snapshot.activity
                            .closingConnectionIDs.isEmpty
                    )
                    .accessibilityIdentifier("connections.closeAll")
                }
            }
            .hakoReaderControlGroupStyle()
        }
    }

    private func send(_ command: HakoActivityCommand) {
        Task { @MainActor in
            await perform(command)
        }
    }

    @MainActor
    private func perform(
        _ command: HakoActivityCommand
    ) async {
        try? await actions.perform(
            .activity(command),
            allowedBy: snapshot
        )
    }
}

public struct HakoRequestsView<Icon: View>: View {
    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let palette: HakoProductPalette
    private let icon: (HakoSymbol) -> Icon

    @State private var query = ""
    @State private var keywords: Set<String> = []
    @State private var autoScrollToNewest = true
    @State private var selected:
        HakoActivityConnectionSnapshot?

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        presentationClass: HakoPresentationClass,
        palette: HakoProductPalette,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.snapshot = snapshot
        self.actions = actions
        _ = presentationClass
        self.palette = palette
        self.icon = icon
    }

    public var body: some View {
        ScrollViewReader { proxy in
            List {
                if !keywords.isEmpty {
                    Section("Filters") {
                        ScrollView(
                            .horizontal,
                            showsIndicators: false
                        ) {
                            HStack(
                                spacing:
                                    HakoTheme.Spacing.compact
                            ) {
                                ForEach(
                                    keywords.sorted(),
                                    id: \.self
                                ) { keyword in
                                    HakoActivityKeywordButton(
                                        title: .verbatim(keyword)
                                    ) {
                                        keywords.remove(
                                            keyword
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                if entries.isEmpty {
                    HakoCardSurface(
                        fill: palette.card,
                        separator: palette.separator,
                        cornerRadius:
                            HakoTheme.Radius.groupedSection
                    ) {
                        HakoEmptyState(
                            title:
                                query.isEmpty
                                    && keywords.isEmpty
                                    ? "No Requests"
                                    : "No Matches",
                            message:
                                requestEmptyMessage,
                            isLoading:
                                snapshot.activity.phase
                                    == .loading
                        ) {
                            icon(
                                query.isEmpty
                                    && keywords.isEmpty
                                    ? .listBulletRectanglePortrait
                                    : .magnifyingglass
                            )
                        }
                        .padding(
                            .vertical,
                            HakoTheme.Spacing.section
                        )
                    }
                    .listRowBackground(Color.clear)
                }

                ForEach(entries) { entry in
                    HakoActivityRequestRow(
                        entry: entry,
                        detailTitle: "Request Details",
                        actions: actions,
                        snapshot: snapshot,
                        palette: palette,
                        onKeyword: {
                            keywords.insert($0)
                        }
                    )
                    .id(entry.id)
                    .modifier(
                        HakoActivityTouchSelection(
                            selected: $selected,
                            connection: entry.connection
                        )
                    )
                }
            }
            .hakoGroupedList()
            .hakoListRetainsRowSelection()
            .hakoActivityListCanvas(palette.canvas)
            .onChange(of: entries.first?.id) {
                newestID in
                guard autoScrollToNewest,
                      let newestID
                else {
                    return
                }
                withAnimation {
                    proxy.scrollTo(newestID, anchor: .top)
                }
            }
        }
        .hakoRootHeading("Requests")
        .searchable(
            text: $query,
            prompt: "Destination, route, or rule"
        )
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    autoScrollToNewest.toggle()
                } label: {
                     
                     
                     
                     
                     
                     
                     
                    Label(
                        autoScrollToNewest
                            ? "Pause auto-scroll"
                            : "Resume auto-scroll",
                        systemImage:
                            autoScrollToNewest
                            ? HakoSymbol.pause.rawValue
                            : HakoSymbol.playFill.rawValue
                    )
                }
                .accessibilityIdentifier("requests.autoScroll")
            }
        }
        .modifier(
            HakoActivityDetailHost(
                selected: $selected,
                title: "Request Details",
                actions: actions,
                snapshot: snapshot
            )
        )
        .accessibilityIdentifier("requests.overview")
    }

     
    @State private var projection = HakoActivityProjectionMemo()

    private var entries: [HakoActivityRequestSnapshot] {
        projection.requests(
            snapshot.activity.requests,
            query: query,
            keywords: keywords
        )
    }

    private var requestEmptyMessage: String {
        if !query.isEmpty || !keywords.isEmpty {
            return
                "Try a different search term or remove a filter."
        }
        return snapshot.activity.phase == .ready
            ? "Requests appear here as apps use the tunnel."
            : "Connect Clash to record requests."
    }
}

public struct HakoLogsView<Icon: View>: View {
    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let palette: HakoProductPalette
    private let icon: (HakoSymbol) -> Icon

    @State private var query = ""
     
     
    @State private var severities: Set<HakoActivityLogSeverity>
    @State private var autoScrollToEnd = true

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        presentationClass: HakoPresentationClass,
        palette: HakoProductPalette,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.snapshot = snapshot
        self.actions = actions
        _ = presentationClass
        self.palette = palette
        self.icon = icon
        _severities = State(
            initialValue: HakoActivityLogSeverity.severities(
                fromRawValues: snapshot.activity.logSeverityFilter
            )
        )
    }

    public var body: some View {
         
         
         
         
         
         
         
         
        HakoDeferredPageContent {
            listBody
        } placeholder: {
            HakoPageLoadingPlaceholder(title: .copy("Loading Logs"))
        }
        .hakoRootHeading("Logs")
        .searchable(text: $query, prompt: "Search logs")
        .hakoToolbarUnlessInPanel { toolbarContent }
        .accessibilityIdentifier("logs.overview")
    }

    @ViewBuilder
    private var listBody: some View {
        ScrollViewReader { proxy in
            List {
                if !severities.isEmpty {
                    Section("Filters") {
                        ScrollView(
                            .horizontal,
                            showsIndicators: false
                        ) {
                            HStack(
                                spacing:
                                    HakoTheme.Spacing.compact
                            ) {
                                ForEach(
                                    severities.sorted {
                                        $0.title < $1.title
                                    }
                                ) { severity in
                                    HakoActivityKeywordButton(
                                        title: .copy(severity.title)
                                    ) {
                                        severities.remove(
                                            severity
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                if entries.isEmpty {
                    HakoCardSurface(
                        fill: palette.card,
                        separator: palette.separator,
                        cornerRadius:
                            HakoTheme.Radius.groupedSection
                    ) {
                        HakoEmptyState(
                            title: logEmptyTitle,
                            message: logEmptyMessage,
                            isLoading:
                                snapshot.activity.phase
                                    == .loading
                        ) {
                            icon(
                                query.isEmpty
                                    && severities.isEmpty
                                    ? .textAlignleft
                                    : .magnifyingglass
                            )
                        }
                        .padding(
                            .vertical,
                            HakoTheme.Spacing.section
                        )
                    }
                    .listRowBackground(Color.clear)
                }

                ForEach(entries) { entry in
                    HakoActivityLogRow(
                        entry: entry,
                        palette: palette,
                        onSeverity: {
                            severities.insert($0)
                        },
                        onCopy: {
                            send(.copyText(entry.message))
                        }
                    )
                    .id(entry.id)
                }
            }
            .hakoGroupedList()
            .hakoActivityListCanvas(palette.canvas)
             
             
             
             
            .onChange(of: snapshot.activity.logLines.last) { _ in
                guard autoScrollToEnd, let lastID = entries.last?.id else {
                    return
                }
                withAnimation {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
             
             
             
             
            .onChange(of: severities) { severities in
                send(
                    .setLogSeverityFilter(
                        HakoActivityLogSeverity.allCases
                            .filter(severities.contains)
                            .map(\.rawValue)
                    )
                )
            }
        }
    }

     
     
     
    @State private var projection = HakoActivityProjectionMemo()

    private var entries: [HakoActivityLogEntry] {
        projection.logs(
            snapshot.activity.logLines,
            query: query,
            severities: severities
        )
    }

    private var logEmptyTitle: String {
        if snapshot.activity.phase == .loading {
            return "Connecting to Live Logs"
        }
        return query.isEmpty && severities.isEmpty
            ? (snapshot.activity.isRecordingLogs == false
                ? "Recording Off"
                : "No Logs Yet")
            : "No Matches"
    }

    private var logEmptyMessage: String {
        if !query.isEmpty || !severities.isEmpty {
            return
                "Try a different search term or remove a filter."
        }
         
         
         
         
        if snapshot.activity.isRecordingLogs == false {
            return "Recording is off. Earlier logs are kept; switch it back on to record new ones."
        }
        let kept = snapshot.activity.logRetentionSummary.map { " \($0)" } ?? ""
        return snapshot.activity.phase == .ready
            ? "Nothing has been recorded yet.\(kept)"
            : "Logs are recorded whenever the tunnel runs, and kept after it stops.\(kept)"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
         
         
         
         
         
         
         
         
         
         
         
        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                levelsMenu
                    .hakoToolbarGlyph()
                    .accessibilityIdentifier("logs.levels")

                if snapshot.activity.canExportLogs {
                    HakoToolbarDivider()

                    Button {
                        send(.exportLogs)
                    } label: {
                        Label(
                            "Export Logs",
                            systemImage: HakoSymbol.squareAndArrowUp.rawValue
                        )
                    }
                    .hakoToolbarGlyph()
                    .disabled(snapshot.activity.logLines.isEmpty)
                    .accessibilityIdentifier("logs.export")
                }

                if snapshot.activity.isRecordingLogs != nil
                    || snapshot.activity.canClearLogs {
                    HakoToolbarDivider()

                    Menu {
                        if snapshot.activity.isRecordingLogs != nil {
                            Button {
                                send(.openLogSettings)
                            } label: {
                                Label(
                                    "Log Settings",
                                    systemImage: HakoSymbol.gearshape.rawValue
                                )
                            }
                            .accessibilityIdentifier("logs.settings")
                        }
                        if snapshot.activity.canClearLogs {
                            Button(role: .destructive) {
                                send(.clearLogs)
                            } label: {
                                Label(
                                    "Clear",
                                    systemImage: HakoSymbol.trash.rawValue
                                )
                            }
                            .disabled(snapshot.activity.logLines.isEmpty)
                            .accessibilityIdentifier("logs.clear")
                        }
                    } label: {
                        Label(
                            "More",
                            systemImage: HakoSymbol.ellipsis.rawValue
                        )
                    }
                    .accessibilityIdentifier("logs.more")
                }
            }
            .hakoReaderControlGroupStyle()
        }
    }

    private var levelsMenu: some View {
        Menu {
             
             
            Button {
                severities.removeAll()
            } label: {
                Label(
                    "All",
                    systemImage: severities.isEmpty
                        ? HakoSymbol.checkmark.rawValue
                        : HakoSymbol.circle.rawValue
                )
            }

            Divider()

            ForEach(HakoActivityLogSeverity.allCases) { severity in
                Button {
                    if severities.contains(severity) {
                        severities.remove(severity)
                    } else {
                        severities.insert(severity)
                    }
                     
                     
                     
                    if severities.count
                        == HakoActivityLogSeverity.allCases.count {
                        severities.removeAll()
                    }
                } label: {
                    Label(
                        severity.title,
                        systemImage: severities.contains(severity)
                            ? HakoSymbol.checkmark.rawValue
                            : HakoSymbol.circle.rawValue
                    )
                }
            }
        } label: {
             
             
            Label(
                severities.isEmpty
                    ? "Levels"
                    : "Levels · \(severities.count)",
                systemImage: HakoSymbol.line3HorizontalDecrease.rawValue
            )
        }
    }

    private func send(_ command: HakoActivityCommand) {
        Task { @MainActor in
            try? await actions.perform(
                .activity(command),
                allowedBy: snapshot
            )
        }
    }
}

 
 
private struct HakoActivityListCanvas: ViewModifier {
    @Environment(\.hakoRegularShellOwnsCanvas)
    private var regularShellOwnsCanvas

    let canvas: Color

    func body(content: Content) -> some View {
        content.background(regularShellOwnsCanvas ? Color.clear : canvas)
    }
}

private extension View {
    func hakoActivityListCanvas(_ canvas: Color) -> some View {
        modifier(HakoActivityListCanvas(canvas: canvas))
    }
}

private struct HakoActivityConnectionRow: View {
    let connection: HakoActivityConnectionSnapshot
    let detailTitle: String
    let actions: AppleClientActions
    let snapshot: AppleClientSnapshot
    let isBusy: Bool
    let showsCloseAction: Bool
    let isCloseDisabled: Bool
    let palette: HakoProductPalette
    let onKeyword: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: HakoTheme.Spacing.row) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.tight
            ) {
                HakoActivityInspectLink(
                    connection: connection,
                    title: detailTitle,
                    actions: actions,
                    snapshot: snapshot
                ) {
                    HStack(
                        alignment: .firstTextBaseline,
                        spacing: HakoTheme.Spacing.compact
                    ) {
                        Text(connection.destination)
                            .font(.body.weight(.medium))
                            .lineLimit(2)
                        Spacer(minLength: HakoTheme.Spacing.tight)
                        if !connection.network.isEmpty {
                            HakoStatusBadge(
                                title: connection.network,
                                tint: .cyan,
                                role: .category,
                                categoryFill: palette.raisedFill,
                                requirementFill: palette.raisedFill,
                                separator: palette.separator
                            )
                        }
                    }
                }

                if !connection.source.isEmpty {
                    Text("From \(connection.source)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !connection.process.isEmpty
                    || !connection.chains.isEmpty
                {
                    ScrollView(
                        .horizontal,
                        showsIndicators: false
                    ) {
                        HStack(
                            spacing: HakoTheme.Spacing.compact
                        ) {
                            if !connection.process.isEmpty {
                                HakoActivityKeywordButton(
                                    title: .verbatim(connection.process)
                                ) {
                                    onKeyword(
                                        connection.process
                                    )
                                }
                            }
                            ForEach(
                                Array(
                                    connection.chains
                                        .enumerated()
                                ),
                                id: \.offset
                            ) { _, chain in
                                HakoActivityKeywordButton(
                                    title: .verbatim(chain)
                                ) {
                                    onKeyword(chain)
                                }
                            }
                        }
                    }
                }

                 
                 
                 
                 
                 
                 
                 
                 
                let detail = [
                    connection.chains.isEmpty ? connection.route : "",
                    connection.rule,
                ]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
                if !detail.isEmpty {
                    Text(hako: .copy(detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(
                    "↑ \(HakoActivityByteFormatter.count(connection.upload))  ↓ \(HakoActivityByteFormatter.count(connection.download))"
                )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Spacer()

            if isBusy {
                ProgressView()
                    .controlSize(.small)
            } else if showsCloseAction {
                Button(
                    role: .destructive,
                    action: onClose
                ) {
                    Image(
                        systemName:
                            HakoSymbol.xmarkCircle.rawValue
                    )
                }
                .buttonStyle(.borderless)
                .disabled(isCloseDisabled)
                .accessibilityLabel("Close connection")
            }
        }
        .padding(.vertical, HakoTheme.Spacing.tight)
        .accessibilityElement(children: .contain)
    }
}

private struct HakoActivityRequestRow: View {
    let entry: HakoActivityRequestSnapshot
    let detailTitle: String
    let actions: AppleClientActions
    let snapshot: AppleClientSnapshot
    let palette: HakoProductPalette
    let onKeyword: (String) -> Void

    var body: some View {
        let connection = entry.connection
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.compact
        ) {
            HakoActivityInspectLink(
                connection: connection,
                title: detailTitle,
                actions: actions,
                snapshot: snapshot
            ) {
                HStack(
                    alignment: .firstTextBaseline,
                    spacing: HakoTheme.Spacing.compact
                ) {
                    Text(connection.destination)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    Spacer(minLength: HakoTheme.Spacing.compact)
                    HakoStatusBadge(
                        title: entry.isActive ? "Live" : "Closed",
                        tint: entry.isActive ? .green : .secondary,
                        categoryFill: palette.raisedFill,
                        requirementFill: palette.raisedFill,
                        separator: palette.separator
                    )
                }
            }

            HStack(spacing: HakoTheme.Spacing.compact) {
                if !connection.network.isEmpty {
                    HakoStatusBadge(
                        title: connection.network,
                        tint: .cyan,
                        role: .category,
                        categoryFill: palette.raisedFill,
                        requirementFill: palette.raisedFill,
                        separator: palette.separator
                    )
                }
                let detail = [
                    connection.rule,
                    connection.route,
                ]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
                if !detail.isEmpty {
                    Text(hako: .copy(detail)).lineLimit(2)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !connection.process.isEmpty
                || !connection.chains.isEmpty
            {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(
                        spacing: HakoTheme.Spacing.compact
                    ) {
                        if !connection.process.isEmpty {
                            HakoActivityKeywordButton(
                                title: .verbatim(connection.process)
                            ) {
                                onKeyword(connection.process)
                            }
                        }
                        ForEach(
                            Array(
                                connection.chains.enumerated()
                            ),
                            id: \.offset
                        ) { _, chain in
                            HakoActivityKeywordButton(
                                title: .verbatim(chain)
                            ) {
                                onKeyword(chain)
                            }
                        }
                    }
                }
            }

            HStack(
                alignment: .firstTextBaseline,
                spacing: HakoTheme.Spacing.compact
            ) {
                Text(
                    entry.lastSeen.formatted(
                        date: .omitted,
                        time: .standard
                    )
                )
                Spacer(minLength: HakoTheme.Spacing.compact)
                Text(
                    "↑ \(HakoActivityByteFormatter.count(connection.upload))  ↓ \(HakoActivityByteFormatter.count(connection.download))"
                )
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, HakoTheme.Spacing.compact)

        .accessibilityElement(children: .combine)
    }
}

private struct HakoActivityLogRow: View {
    let entry: HakoActivityLogEntry
    let palette: HakoProductPalette
    let onSeverity: (HakoActivityLogSeverity) -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.compact
        ) {
             
             
             
             
             
             
            Text(entry.message)
                .font(
                    .system(
                        .caption,
                        design: .monospaced
                    )
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
                .frame(maxWidth: .infinity, alignment: .leading)

            if let severity = entry.severity {
                Button {
                    onSeverity(severity)
                } label: {
                    HakoStatusBadge(
                        title: severity.title,
                        tint: tint(for: severity),
                        categoryFill: palette.raisedFill,
                        requirementFill: palette.raisedFill,
                        separator: palette.separator
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text(hako: .format("Filter by %@", [severity.title]))
                )
            }
        }
        .padding(.vertical, HakoTheme.Spacing.tight)
        .accessibilityElement(children: .contain)
    }

    private func tint(
        for severity: HakoActivityLogSeverity
    ) -> Color {
        switch severity {
        case .debug:
            .purple
        case .info:
            .blue
        case .warning:
            .orange
        case .error:
            .red
        }
    }
}

private struct HakoActivityKeywordButton: View {
     
     
     
     
     
    let title: HakoDisplayText
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(hako: title)
                .font(.caption)
                .lineLimit(1)
                .padding(
                    .horizontal,
                    HakoTheme.Spacing.compact
                )
                .padding(
                    .vertical,
                    HakoTheme.Spacing.tight
                )
                .background(
                    Capsule().fill(
                        Color.secondary.opacity(0.12)
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(hako: .format("Filter by %@", [title.rawValue]))
        )
    }
}

 
 
private struct HakoActivityDetailHost: ViewModifier {
    @Binding var selected: HakoActivityConnectionSnapshot?
    let title: String
    let actions: AppleClientActions
    let snapshot: AppleClientSnapshot

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        content
#else
        content.sheet(item: $selected) { connection in
            HakoSingleColumnNavigationContainer {
                HakoActivityConnectionDetailView(
                    connection: connection,
                    title: title,
                    actions: actions,
                    snapshot: snapshot
                )
                .hakoToolbarUnlessInPanel {
                    ToolbarItem(placement: .cancellationAction) {
                        HakoSheetCloseButton { selected = nil }
                    }
                }
            }
            .hakoModalPresentation(.page)
        }
#endif
    }
}

 
 
 
private struct HakoActivityInspectLink<Label: View>: View {
    let connection: HakoActivityConnectionSnapshot
    let title: String
    let actions: AppleClientActions
    let snapshot: AppleClientSnapshot
    let label: Label

    init(
        connection: HakoActivityConnectionSnapshot,
        title: String,
        actions: AppleClientActions,
        snapshot: AppleClientSnapshot,
        @ViewBuilder label: () -> Label
    ) {
        self.connection = connection
        self.title = title
        self.actions = actions
        self.snapshot = snapshot
        self.label = label()
    }

    @ViewBuilder
    var body: some View {
#if os(macOS)
        HakoRoutedViewLink(
            showsDisclosureIndicator: true
        ) {
            HakoActivityConnectionDetailView(
                connection: connection,
                title: title,
                actions: actions,
                snapshot: snapshot
            )
        } label: {
            label
        }
#else
        label
#endif
    }
}

 
 
private struct HakoActivityTouchSelection: ViewModifier {
    @Binding var selected: HakoActivityConnectionSnapshot?
    let connection: HakoActivityConnectionSnapshot

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        content
#else
        content
            .contentShape(Rectangle())
            .onTapGesture { selected = connection }
#endif
    }
}

private struct HakoActivityConnectionDetailView: View {
    let connection: HakoActivityConnectionSnapshot
    let title: String
    let actions: AppleClientActions
    let snapshot: AppleClientSnapshot

    var body: some View {
        List {
            Section("Session") {
                if let start = connection.start {
                    detailRow(
                        "Created",
                        start.formatted(
                            date: .abbreviated,
                            time: .standard
                        )
                    )
                }
                detailRow("Network", connection.network)
                detailRow(
                    "Process",
                    connection.processDescription,
                    copyable: true
                )
                detailRow(
                    "Process path",
                    connection.processPath,
                    copyable: true
                )
                detailRow(
                    "Rule",
                    connection.ruleDescription
                )
            }

            Section("Endpoints") {
                detailRow(
                    "Host",
                    connection.host,
                    copyable: true
                )
                detailRow(
                    "Source",
                    connection.source,
                    copyable: true
                )
                detailRow(
                    "Destination",
                    ipDestination,
                    copyable: true
                )
                detailRow(
                    "Remote destination",
                    connection.remoteDestination,
                    copyable: true
                )
            }

            Section("Traffic") {
                detailRow(
                    "Upload",
                    HakoActivityByteFormatter.count(
                        connection.upload
                    )
                )
                detailRow(
                    "Download",
                    HakoActivityByteFormatter.count(
                        connection.download
                    )
                )
                if let speed = connection.uploadSpeed {
                    detailRow(
                        "Upload speed",
                        HakoActivityByteFormatter.rate(speed)
                    )
                }
                if let speed = connection.downloadSpeed {
                    detailRow(
                        "Download speed",
                        HakoActivityByteFormatter.rate(speed)
                    )
                }
            }

            if !connection.chains.isEmpty {
                Section("Proxy chain") {
                    ForEach(
                        Array(connection.chains.enumerated()),
                        id: \.offset
                    ) { _, chain in
                        detailRow("Proxy", chain)
                    }
                }
            }

            Section("Metadata") {
                detailRow(
                    "Destination GeoIP",
                    connection.destinationGeoIP.joined(
                        separator: " "
                    )
                )
                detailRow(
                    "Destination ASN",
                    connection.destinationIPASN
                )
                detailRow(
                    "Source GeoIP",
                    connection.sourceGeoIP.joined(
                        separator: " "
                    )
                )
                detailRow(
                    "Source ASN",
                    connection.sourceIPASN
                )
                detailRow("DNS mode", connection.dnsMode)
                detailRow(
                    "Special proxy",
                    connection.specialProxy
                )
                detailRow(
                    "Special rules",
                    connection.specialRules
                )
            }
        }
        .hakoPageTitle(.copy(title))
    }

    private var ipDestination: String {
        guard !connection.destinationIP.isEmpty else {
            return connection.destination
        }
        guard !connection.destinationPort.isEmpty,
              connection.destinationPort != "0"
        else {
            return connection.destinationIP
        }
        if connection.destinationIP.contains(":") {
            return
                "[\(connection.destinationIP)]:\(connection.destinationPort)"
        }
        return
            "\(connection.destinationIP):\(connection.destinationPort)"
    }

    @ViewBuilder
    private func detailRow(
        _ label: String,
        _ value: String,
        copyable: Bool = false
    ) -> some View {
        if !value.isEmpty {
            HStack(
                alignment: .firstTextBaseline,
                spacing: HakoTheme.Spacing.standard
            ) {
                Text(hako: .copy(label))
                    .foregroundStyle(.secondary)
                Spacer(minLength: HakoTheme.Spacing.standard)
                Text(value)
                    .multilineTextAlignment(.trailing)
                if copyable {
                    Button {
                        send(.copyText(value))
                    } label: {
                        Image(
                            systemName:
                                HakoSymbol
                                .docOnClipboard.rawValue
                        )
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Copy \(label)")
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func send(_ command: HakoActivityCommand) {
        Task { @MainActor in
            try? await actions.perform(
                .activity(command),
                allowedBy: snapshot
            )
        }
    }
}
