import Combine
import SwiftUI

 
 
 
 
 
 
 
 
 
public struct HakoProxiesToolbar<Icon: View>: ToolbarContent {
    let showsDismissControl: Bool
    let hasExpandedGroups: Bool
    let canRefreshCatalog: Bool
    let refreshDisabled: Bool
    @Binding var preferences: HakoProxiesDisplayPreferences
    let onDismiss: () -> Void
    let onToggleFold: () -> Void
    let onRefresh: () -> Void
    let onShowDisplayOptions: () -> Void
     
     
    let isTestingLatency: Bool
    let sweepDisabled: Bool
    let sweepCompleted: Int
    let sweepTotal: Int
    let sweepPulse: AnyPublisher<HakoLatencyPulse, Never>?
    let onSweepStart: (() -> Void)?
    let onSweepCancel: (() -> Void)?
    let icon: (HakoSymbol) -> Icon

    public init(
        showsDismissControl: Bool,
        hasExpandedGroups: Bool,
        canRefreshCatalog: Bool,
        refreshDisabled: Bool,
        preferences: Binding<HakoProxiesDisplayPreferences>,
        onDismiss: @escaping () -> Void,
        onToggleFold: @escaping () -> Void,
        onRefresh: @escaping () -> Void,
        onShowDisplayOptions: @escaping () -> Void,
        isTestingLatency: Bool = false,
        sweepDisabled: Bool = false,
        sweepCompleted: Int = 0,
        sweepTotal: Int = 0,
        sweepPulse: AnyPublisher<HakoLatencyPulse, Never>? = nil,
        onSweepStart: (() -> Void)? = nil,
        onSweepCancel: (() -> Void)? = nil,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.showsDismissControl = showsDismissControl
        self.hasExpandedGroups = hasExpandedGroups
        self.canRefreshCatalog = canRefreshCatalog
        self.refreshDisabled = refreshDisabled
        self._preferences = preferences
        self.onDismiss = onDismiss
        self.onToggleFold = onToggleFold
        self.onRefresh = onRefresh
        self.onShowDisplayOptions = onShowDisplayOptions
        self.isTestingLatency = isTestingLatency
        self.sweepDisabled = sweepDisabled
        self.sweepCompleted = sweepCompleted
        self.sweepTotal = sweepTotal
        self.sweepPulse = sweepPulse
        self.onSweepStart = onSweepStart
        self.onSweepCancel = onSweepCancel
        self.icon = icon
    }

     
    private var sweepLivesHere: Bool {
        onSweepStart != nil && onSweepCancel != nil
            && HakoPlatformLayout.proxiesSweepLivesInToolbar
    }

    public var body: some ToolbarContent {
         
         
         
         
        ToolbarItem(placement: .cancellationAction) {
            if showsDismissControl {
                HakoSheetCloseButton {
                    onDismiss()
                }
            }
        }

         
         
         
         
         
        ToolbarItem(placement: .primaryAction) {
            ControlGroup {
                if let onSweepStart, let onSweepCancel,
                   HakoPlatformLayout.proxiesSweepLivesInToolbar {
                     
                    HakoSweepToolbarButton(
                        initialIsTesting: isTestingLatency,
                        initialCompleted: sweepCompleted,
                        initialTotal: sweepTotal,
                        disabled: sweepDisabled,
                        pulse: sweepPulse,
                        onStart: onSweepStart,
                        onCancel: onSweepCancel,
                        icon: icon
                    )
                    .hakoToolbarCapsuleEnd(.leading)

                    HakoToolbarDivider()
                }

                 
                 
                 
                 
                 
                Button {
                    onToggleFold()
                } label: {
                    icon(
                        hasExpandedGroups
                            ? .arrowUpRightAndArrowDownLeft
                            : .arrowDownLeftAndArrowUpRight
                    )
                    .hakoToolbarGlyph()
                }
                 
                .hakoToolbarCapsuleEnd(sweepLivesHere ? [] : .leading)
                .accessibilityLabel(
                     
                     
                     
                     
                     
                    hasExpandedGroups
                        ? "Collapse All Groups"
                        : "Expand Last Group"
                )
                .accessibilityIdentifier("proxies.toggleAllGroups")

                 
                 
                 
                 
                 
                HakoToolbarDivider()

                if canRefreshCatalog {
                    Button {
                        onRefresh()
                    } label: {
                        icon(.arrowClockwise)
                            .hakoToolbarGlyph()
                    }
                    .disabled(refreshDisabled)
                    .accessibilityLabel("Refresh Proxies")
                    .accessibilityIdentifier("proxies.refresh")

                    HakoToolbarDivider()
                }

                 
                if HakoPlatformLayout.immediateDisplayOptionsUseMenu {
                    Menu {
                        displayOptionsMenu
                    } label: {
                        icon(.sliderHorizontal3)
                            .hakoToolbarGlyph()
                            .hakoToolbarCapsuleEnd(.trailing)
                    }
                    .accessibilityLabel("Display Options")
                    .accessibilityIdentifier("proxies.display.options")
                } else {
                    Button {
                        onShowDisplayOptions()
                    } label: {
                        icon(.sliderHorizontal3)
                            .hakoToolbarGlyph()
                            .hakoToolbarCapsuleEnd(.trailing)
                    }
                    .accessibilityLabel("Display Options")
                    .accessibilityIdentifier("proxies.display.options")
                }
            }
            .hakoReaderControlGroupStyle()
        }
    }

    @ViewBuilder
    private var displayOptionsMenu: some View {
         
         
         
         
        Picker("Icons", selection: $preferences.groupIconImages) {
            Text("Off").tag(false)
            Text("Show").tag(true)
        }
        .accessibilityIdentifier("proxies.display.groupIconImages")

        Picker("Style", selection: $preferences.style) {
            Text("List").tag(HakoProxiesDisplayPreferences.Style.list)
            Text("Tabs").tag(HakoProxiesDisplayPreferences.Style.tabs)
        }

        Picker("Sort", selection: $preferences.sort) {
            Text("Default").tag(HakoProxiesDisplayPreferences.Sort.standard)
            Text("Delay").tag(HakoProxiesDisplayPreferences.Sort.delay)
            Text("Name").tag(HakoProxiesDisplayPreferences.Sort.name)
        }
            .accessibilityIdentifier("proxies.display.sort")

        Picker("Layout", selection: $preferences.layout) {
            Text("Loose").tag(HakoProxiesDisplayPreferences.Layout.loose)
            Text("Compact").tag(HakoProxiesDisplayPreferences.Layout.compact)
        }
            .accessibilityIdentifier("proxies.display.layout")

        Picker("Size", selection: $preferences.size) {
            Text("Standard").tag(HakoProxiesDisplayPreferences.Size.standard)
            Text("Compact").tag(HakoProxiesDisplayPreferences.Size.compact)
            Text("Minimal").tag(HakoProxiesDisplayPreferences.Size.minimal)
        }
            .accessibilityIdentifier("proxies.display.size")
    }
}

 
 
 
 
 
 
 
 
 
private struct HakoSweepToolbarButton<Icon: View>: View {
    let initialIsTesting: Bool
    let initialCompleted: Int
    let initialTotal: Int
    let disabled: Bool
    let pulse: AnyPublisher<HakoLatencyPulse, Never>?
    let onStart: () -> Void
    let onCancel: () -> Void
    let icon: (HakoSymbol) -> Icon

    @State private var isTesting: Bool?
    @State private var completed: Int?
    @State private var total: Int?

    private var showsTesting: Bool { isTesting ?? initialIsTesting }

    var body: some View {
        Button {
            if showsTesting {
                onCancel()
                 
                 
                 
                isTesting = false
            } else {
                onStart()
                isTesting = true
                completed = 0
                total = nil
            }
        } label: {
            if showsTesting {
                HStack(spacing: 4) {
                    ProgressView()
                        .controlSize(.small)
                    if let total, total > 0 {
                        Text(hako: .verbatim("\(completed ?? 0)/\(total)"))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                icon(.bolt)
                    .hakoToolbarGlyph()
            }
        }
        .disabled(disabled)
        .accessibilityLabel(showsTesting ? "Cancel" : "Test All")
        .accessibilityIdentifier(
            showsTesting ? "proxies.testAll.cancel" : "proxies.testAll"
        )
        .onReceive(
            pulse ?? Empty<HakoLatencyPulse, Never>().eraseToAnyPublisher()
        ) { batch in
            isTesting = batch.isTesting
            completed = batch.completed
            total = batch.total
        }
    }
}
