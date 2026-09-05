import HakoClientUI
import SwiftUI

struct HakoOverviewCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HakoFeatureCard {
            content
        }
    }
}

struct OverviewBadge {
    let title: String
    let tint: Color
}

struct OverviewCardHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let symbol: HakoSymbol
    let tint: Color
    var badge: OverviewBadge?

    var body: some View {
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
            HStack(spacing: HakoTheme.Spacing.row) {
                iconAndTitle

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: HakoTheme.Spacing.compact)
                    badgeView
                }
            }

            if dynamicTypeSize.isAccessibilitySize {
                badgeView
            }
        }
    }

    private var iconAndTitle: some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            HakoIconWell(symbol: symbol, tint: tint)

            Text(hako: .copy(title))
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private var badgeView: some View {
        if let badge {
            HakoStatusBadge(title: badge.title, tint: badge.tint)
        }
    }
}

struct OverviewValueRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: HakoDisplayText
    let value: HakoDisplayText
     
     
     
    let valueView: AnyView?

    init(title: HakoDisplayText, value: HakoDisplayText, valueView: AnyView? = nil) {
        self.title = title
        self.value = value
        self.valueView = valueView
    }

    @ViewBuilder
    private var valueContent: some View {
        if let valueView {
            valueView
        } else {
            Text(hako: value)
        }
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                    Text(hako: title)
                    valueContent
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.row) {
                    Text(hako: title)
                    Spacer(minLength: HakoTheme.Spacing.row)
                    valueContent
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .subheadline)
        .accessibilityElement(children: .combine)
    }
}

struct ConnectionPresentation {
    let status: String

    private var normalized: String { status.lowercased() }

    var isConnected: Bool { normalized == "connected" || normalized == "reasserting" }
    var isBusy: Bool { normalized == "connecting" || normalized == "disconnecting" }
    var title: String {
        switch normalized {
        case "connected": return "Connected"
        case "reasserting": return "Reconnecting"
        case "connecting": return "Connecting"
        case "disconnecting": return "Disconnecting"
        case "invalid": return "Profile unavailable"
        default: return "Disconnected"
        }
    }
    var subtitle: String {
        switch normalized {
        case "connected": return "Traffic is routed through the Clash packet tunnel."
        case "reasserting": return "The network changed; Clash is restoring the tunnel."
        case "connecting": return "Preparing Network Extension and the core."
        case "disconnecting": return "Closing the active packet tunnel."
        case "invalid": return "Recreate the VPN profile to continue."
        default: return "Connect to start the packet tunnel."
        }
    }
    var badgeTitle: String {
        normalized.isEmpty ? "Unknown" : normalized.replacingOccurrences(of: "_", with: " ").capitalized
    }
    var actionTitle: String { normalized == "invalid" ? "Repair and connect" : "Connect" }
    var symbol: HakoSymbol {
        if isConnected { return .checkmarkShieldFill }
        if isBusy { return .arrowTriangle2Circlepath }
        if normalized == "invalid" { return .exclamationmarkShieldFill }
        return .shieldFill
    }
    var statusTint: Color {
        if isConnected { return .green }
        if isBusy { return .orange }
        if normalized == "invalid" { return .red }
        return .gray
    }
}

enum ByteRateFormatter {
    static func string(_ bytesPerSecond: Int64) -> String {
        HakoThroughputFormatter.rate(bytesPerSecond)
    }
}

 
 
enum ByteCountFormatter {
    static func string(_ bytes: Int64) -> String {
        HakoThroughputFormatter.usage(bytes)
    }
}
