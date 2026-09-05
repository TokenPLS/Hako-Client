import Hako
import HakoClientUI
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum RuntimeMemoryPresentation {
    struct Row: Equatable {
        let title: String
        let value: HakoDisplayText
    }

    static func headline(
        footprintBytes: Int64?,
        residentBytes: Int64
    ) -> Row {
        let bytes = (footprintBytes ?? -1) > 0 ? footprintBytes! : residentBytes
        return Row(
            title: "Memory used",
            value: .verbatim(megabytes(Double(bytes)))
        )
    }

     
     
     
    static func details(
        footprintBytes: Int64?,
        goHeapBytes: UInt64?,
        residentBytes: Int64
    ) -> [Row] {
        var rows: [Row] = []
        if let goHeapBytes {
            rows.append(Row(
                title: "Go heap",
                value: .verbatim(megabytes(Double(goHeapBytes)))
            ))
        }
        if (footprintBytes ?? -1) > 0 {
            rows.append(Row(
                title: "Resident memory",
                value: .verbatim(megabytes(Double(residentBytes)))
            ))
        }
        return rows
    }

    private static func megabytes(_ bytes: Double) -> String {
        String(format: "%.1f MB", bytes / 1_048_576)
    }
}

 
 
 
struct RuntimeDetailView: View {
    @ObservedObject var command: ClashCommandClient
    let usesRegularDetailLayout: Bool
     
    var restart: (() -> Void)?

    @State private var asksAboutRestart = false
    @State private var crashReportToShare: String?

    private func memoryRow(_ row: RuntimeMemoryPresentation.Row) -> some View {
        RuntimeMetricRow(
            title: .copy(row.title),
            value: row.value,
            symbol: .memorychip)
    }

    var body: some View {
        Form {
            Section {
                RuntimeMetricRow(
                    title: "Version",
                    value: .verbatim(
                        command.runtimeDiagnostics?.lowMemoryBuild == true
                        ? "\(HakoVersion()) · low-memory"
                        : HakoVersion()
                    ),
                    symbol: .cpu)
                memoryRow(RuntimeMemoryPresentation.headline(
                    footprintBytes: command.runtimeDiagnostics?
                        .extensionMemoryFootprintBytes,
                    residentBytes: command.memoryBytes
                ))
                let details = RuntimeMemoryPresentation.details(
                    footprintBytes: command.runtimeDiagnostics?
                        .extensionMemoryFootprintBytes,
                    goHeapBytes: command.runtimeDiagnostics?.goHeapInuseBytes,
                    residentBytes: command.memoryBytes
                )
                if !details.isEmpty {
                    DisclosureGroup {
                        ForEach(details, id: \.title) { row in
                            memoryRow(row)
                        }
                    } label: {
                        Text(hako: .copy("Technical details"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                     
                     
                     
                     
                    .hakoRowDisclosure()
                    .accessibilityIdentifier("runtime.memory.details")
                }

                if let restart,
                   CoreRestartPolicy.isOffered(isConnected: command.isConnected) {
                    Button(role: .destructive) {
                        asksAboutRestart = true
                    } label: {
                        Label("Restart Core", systemImage: HakoSymbol.arrowClockwise.rawValue)
                    }
                    .accessibilityIdentifier("runtime.restart")
                    .confirmationDialog(
                        "Restart Core?",
                        isPresented: $asksAboutRestart,
                        titleVisibility: .visible
                    ) {
                        Button("Restart", role: .destructive, action: restart)
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(hako: .copy(CoreRestartPolicy.confirmation))
                    }
                }
            } header: {
                Text(hako: .copy("Core"))
            }

            if let d = command.runtimeDiagnostics {
                Section("Diagnostics") {
                    RuntimeMetricRow(
                        title: "Started",
                        value: .verbatim(
                            Date(timeIntervalSince1970: TimeInterval(d.startTimeUnix))
                            .formatted(date: .abbreviated, time: .standard)
                        ),
                        symbol: .clock)
                    RuntimeMetricRow(title: "Goroutines", value: .verbatim(String(d.goroutines)),
                                     symbol: .point3FilledConnectedTrianglepathDotted)
                    RuntimeMetricRow(
                        title: "In / Out / Connections",
                        value: .verbatim("\(d.inboundCount) / \(d.outboundCount) / \(d.connectionCount)"),
                        symbol: .arrowLeftArrowRight)
                    RuntimeMetricRow(
                        title: "Apple routes v4 / v6",
                        value: .verbatim("\(d.appleIPv4IncludedRouteCount) / \(d.appleIPv6IncludedRouteCount)"),
                        symbol: .arrowTriangleBranch)
                    RuntimeMetricRow(
                        title: "Physical v4 / v6",
                        value: .verbatim("\(d.physicalPathSupportsIPv4 ? "yes" : "no") / \(d.physicalPathSupportsIPv6 ? "yes" : "no")"),
                        symbol: .network)
                    RuntimeMetricRow(
                        title: "NAT64 applied / failed",
                        value: .verbatim("\(d.nat64SynthesisApplied) / \(d.nat64SynthesisFailures)"),
                        symbol: .arrowTriangleSwap)
                }
            } else {
                Section {
                    HakoStatusMessage(
                        text: .copy("Connect Clash to read core diagnostics."),
                        kind: .information
                    )
                }
            }

            if let report = command.previousGoCrashReport {
                Section("Previous run ended unexpectedly") {
                    VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                        HakoStatusMessage(
                            text: "The core stopped on an internal error during its last run.",
                            kind: .error
                        )
                         
                         
                         
                        if #available(iOS 16.0, *) {
                            ShareLink(item: report) {
                                Label(
                                    "Export Technical Details",
                                    systemImage: HakoSymbol.squareAndArrowUp.name
                                )
                            }
                            .accessibilityIdentifier("runtime.crash-report.export")
                        } else {
                            Button {
                                crashReportToShare = report
                            } label: {
                                Label(
                                    "Export Technical Details",
                                    systemImage: HakoSymbol.squareAndArrowUp.name
                                )
                            }
                            .accessibilityIdentifier("runtime.crash-report.export")
                        }
                    }
                }
            }

             
             
             
             
            if let diagnostics = command.runtimeDiagnostics,
               let triggers = diagnostics.memoryThresholdTriggerCount {
                let predicted = diagnostics.memoryThresholdPredictedCount ?? 0
                let shed = diagnostics.memoryThresholdShedCount ?? 0
                Section("Memory pressure") {
                    if triggers == 0, predicted == 0, shed == 0 {
                        RuntimeMetricRow(
                            title: "Pressure",
                            value: "None recorded",
                            symbol: .memorychip)
                    } else {
                        RuntimeMetricRow(
                            title: "State",
                            value: .verbatim(diagnostics.memoryThresholdState ?? "—"),
                            symbol: .memorychip)
                        RuntimeMetricRow(
                            title: "Triggers",
                            value: .verbatim("\(triggers)"),
                            symbol: .memorychip)
                        RuntimeMetricRow(
                            title: "Predicted",
                            value: .verbatim("\(predicted)"),
                            symbol: .memorychip)
                        RuntimeMetricRow(
                            title: "Connections shed",
                            value: .verbatim(
                                diagnostics.memoryThresholdShedEnabled == true
                                ? "\(shed)"
                                : "Reporting only"
                            ),
                            symbol: .memorychip)
                    }
                }
            }

            if let evidence = command.previousOOMEvidence {
                Section("Previous memory pressure") {
                    VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                        HakoStatusMessage(text: .copy(evidence.interpretation), kind: .warning)
                        Text(Date(timeIntervalSince1970: TimeInterval(evidence.recordedAtUnix))
                            .formatted(date: .abbreviated, time: .standard))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
         
         
         
#if !os(macOS)
        .sheet(isPresented: Binding(
            get: { crashReportToShare != nil },
            set: { if !$0 { crashReportToShare = nil } }
        )) {
            Group {
                if let crashReportToShare {
                    LogShareSheet(activityItems: [crashReportToShare])
                }
            }
            .hakoModalPresentation(.page)
        }
#endif
        .hakoPageTitle("Core Runtime")
    }
}
