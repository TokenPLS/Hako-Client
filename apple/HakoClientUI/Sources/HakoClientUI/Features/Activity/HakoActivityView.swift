import Foundation
import SwiftUI

 
 
 
 
 
public struct HakoActivityView<Icon: View>: View {
    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let presentationClass: HakoPresentationClass
    private let palette: HakoProductPalette
    private let showsCloseAction: Bool
    private let icon: (HakoSymbol) -> Icon

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        presentationClass: HakoPresentationClass,
        palette: HakoProductPalette,
        showsCloseAction: Bool = false,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.presentationClass = presentationClass
        self.palette = palette
        self.showsCloseAction = showsCloseAction
        self.icon = icon
    }

    public var body: some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "activity.product.root"
        ) {
            switch snapshot.activity.phase {
            case .disconnected:
                stateCard(
                    title: "Connect to View Activity",
                    message:
                        "Live traffic and session totals appear while Clash is connected.",
                    symbol: .waveformPathEcg
                )
            case .loading:
                stateCard(
                    title: "Loading Activity",
                    message:
                        "Reading privacy-bounded activity from the current connection.",
                    symbol: .waveformPathEcg,
                    isLoading: true
                )
            case .failed:
                stateCard(
                    title: "Activity Unavailable",
                    message:
                        snapshot.activity.errorDescription
                            ?? "Clash could not read the current activity snapshot.",
                    symbol: .exclamationmarkTriangle
                )
            case .ready:
                trafficCard
                sessionCard
            }
        }
        .hakoPageTitle("Activity")
        .hakoToolbarUnlessInPanel { toolbarContent }
        .accessibilityIdentifier("activity.overview")
    }

    private func stateCard(
        title: String,
        message: String,
        symbol: HakoSymbol,
        isLoading: Bool = false
    ) -> some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            HakoEmptyState(
                title: title,
                message: message,
                isLoading: isLoading
            ) {
                icon(symbol)
            }
        }
        .accessibilityIdentifier(
            isLoading ? "activity.state.loading" : "activity.state.empty"
        )
    }

    private var trafficCard: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.standard
            ) {
                HakoCardTitle(tint: .orange) {
                    Text("Live Traffic")
                } icon: {
                    icon(.waveformPathEcg)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: HakoTheme.Spacing.row) {
                        uploadMetric
                        downloadMetric
                    }
                } else {
                    HStack(
                        alignment: .top,
                        spacing: HakoTheme.Spacing.row
                    ) {
                        uploadMetric
                        downloadMetric
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity.card.traffic")
    }

    private var uploadMetric: some View {
        HakoActivityMetric(
            title: "Upload",
            symbolName: "arrow.up",
            rate: HakoActivityByteFormatter.rate(
                snapshot.activity.traffic.uploadBytesPerSecond
            ),
            total: HakoActivityByteFormatter.count(
                snapshot.activity.traffic.uploadTotalBytes
            ),
            fill: palette.raisedFill
        )
    }

    private var downloadMetric: some View {
        HakoActivityMetric(
            title: "Download",
            symbolName: "arrow.down",
            rate: HakoActivityByteFormatter.rate(
                snapshot.activity.traffic.downloadBytesPerSecond
            ),
            total: HakoActivityByteFormatter.count(
                snapshot.activity.traffic.downloadTotalBytes
            ),
            fill: palette.raisedFill
        )
    }

    private var sessionCard: some View {
        HakoCardSurface(
            fill: palette.card,
            separator: palette.separator
        ) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.standard
            ) {
                HakoCardTitle(tint: .cyan) {
                    Text("Current Session")
                } icon: {
                    icon(.arrowUpArrowDownCircle)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: HakoTheme.Spacing.row) {
                        connectionMetric
                        logMetric
                    }
                } else {
                    HStack(
                        alignment: .top,
                        spacing: HakoTheme.Spacing.row
                    ) {
                        connectionMetric
                        logMetric
                    }
                }

                if snapshot.activity.detailAvailability == .summaryOnly {
                    Text(
                        "Activity shows totals only. Destinations, addresses, rules, and log messages remain in the platform Adapter."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activity.card.session")
    }

    private var connectionMetric: some View {
        HakoActivityCountMetric(
            title: "Connections",
            symbolName: HakoSymbol.arrowUpArrowDownCircle.rawValue,
            value: snapshot.activity.activeConnectionCount,
            subtitle: "Active now",
            fill: palette.raisedFill
        )
    }

    private var logMetric: some View {
        HakoActivityCountMetric(
            title: "Recent Logs",
            symbolName: HakoSymbol.textAlignleft.rawValue,
            value: snapshot.activity.recentLogCount,
            subtitle: "Current buffer",
            fill: palette.raisedFill
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if showsCloseAction {
                Button("Done") {
                    dismiss()
                }
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                send(.refresh)
            } label: {
                icon(.arrowClockwise)
            }
            .disabled(snapshot.activity.phase == .loading)
            .accessibilityLabel("Refresh Activity")
            .accessibilityIdentifier("activity.refresh")
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

private struct HakoActivityMetric: View {
    let title: String
    let symbolName: String
    let rate: String
    let total: String
    let fill: Color

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            Label { Text(hako: .copy(title)) } icon: { Image(systemName: symbolName).accessibilityHidden(true) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(rate)
                .font(.system(.headline, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("Total \(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(HakoTheme.Spacing.row)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: HakoTheme.Radius.control,
                style: .continuous
            )
            .fill(fill)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct HakoActivityCountMetric: View {
    let title: String
    let symbolName: String
    let value: Int
    let subtitle: String
    let fill: Color

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            Label { Text(hako: .copy(title)) } icon: { Image(systemName: symbolName).accessibilityHidden(true) }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value, format: .number)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text(hako: .copy(subtitle))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(HakoTheme.Spacing.row)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: HakoTheme.Radius.control,
                style: .continuous
            )
            .fill(fill)
        )
        .accessibilityElement(children: .combine)
    }
}

enum HakoActivityByteFormatter {
    static func count(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.includesUnit = true
        return formatter.string(fromByteCount: max(0, bytes))
    }

    static func rate(_ bytes: Int64) -> String {
        "\(count(bytes))/s"
    }
}
