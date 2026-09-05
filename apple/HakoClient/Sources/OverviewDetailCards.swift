import HakoClientUI
import SwiftUI

struct EgressCard: View {
    let egress: OverviewEgressSnapshot
    let checkEgress: () -> Void

    var body: some View {
        HakoOverviewCard {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.standard) {
                OverviewCardHeader(
                    title: "Egress",
                    symbol: .network,
                    tint: .green
                )

                VStack(spacing: HakoTheme.Spacing.row) {
                    OverviewValueRow(title: "Address", value: .verbatim(egress.address))
                     
                     
                    OverviewValueRow(
                        title: "Country",
                        value: .verbatim(egress.countryDisplay),
                        valueView: AnyView(
                            HakoRegionalFlag.label(egress.countryDisplay, pointSize: 15, relativeTo: .subheadline)
                        )
                    )
                        .accessibilityIdentifier("overview.egress.country")
                    OverviewValueRow(title: "Provider", value: .verbatim(egress.provider))
                    OverviewValueRow(title: "LAN", value: .verbatim(IntranetAddress.current() ?? "—"))
                }

                Button(action: checkEgress) {
                    Label(
                        egress.isChecking ? "Checking…" : "Check Egress",
                        systemImage: HakoSymbol.arrowClockwise.name
                    )
                    .frame(maxWidth: .infinity)
                }
                .hakoSecondaryActionButtonStyle()
                .controlSize(.large)
                .disabled(egress.isChecking)
                .accessibilityIdentifier("overview.egress.check")

                Text("Confirms the public address used by the active tunnel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.card.egress")
    }
}

 
 
 
struct RuntimeCard: View {
    let runtime: OverviewRuntimeSnapshot
    let collectGarbage: () -> Void

    var body: some View {
        HakoOverviewCard {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.standard) {
                OverviewCardHeader(
                    title: "Runtime",
                    symbol: .cpu,
                    tint: .indigo
                )

                VStack(spacing: HakoTheme.Spacing.row) {
                    RuntimeMetricRow(title: "Core", value: .verbatim(runtime.coreVersion), symbol: .cpu)
                    RuntimeMetricRow(
                        title: "Memory",
                        value: .verbatim(String(format: "%.1f MB", runtime.memoryMB)),
                        symbol: .memorychip
                    )
                }

                Button(action: collectGarbage) {
                    Label(
                        runtime.isCollectingMemory ? "Releasing Memory…" : "Release Memory",
                        systemImage: HakoSymbol.arrowClockwise.name
                    )
                    .frame(maxWidth: .infinity)
                }
                .hakoSecondaryActionButtonStyle()
                .controlSize(.large)
                .disabled(runtime.isCollectingMemory)
                .accessibilityIdentifier("overview.runtime.gc")

                if !runtime.memoryActionMessage.isEmpty {
                    Text(hako: .copy(runtime.memoryActionMessage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("overview.runtime.gc.status")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("overview.card.runtime")
    }
}

struct RuntimeMetricRow: View {
    let title: HakoDisplayText
    let value: HakoDisplayText
    let symbol: HakoSymbol

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.row) {
            Label { Text(hako: title) } icon: { Image(systemName: symbol.name).accessibilityHidden(true) }
                .foregroundStyle(.primary)
            Spacer(minLength: HakoTheme.Spacing.row)
            Text(hako: value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
