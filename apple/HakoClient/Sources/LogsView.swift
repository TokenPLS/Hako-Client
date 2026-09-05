import HakoClientUI
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import UniformTypeIdentifiers

 
 
 
 
 
 
 
 
 
 
#if os(macOS)
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
enum MacSavePanel {
     
     
     
     
     
     
     
     
     
     
     
     
    static func write(
        suggestedName: String,
        writing body: @escaping @Sendable (URL) -> Bool,
        onFailure: @escaping @MainActor (String) -> Void
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let destination = panel.url else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                 
                 
                 
                guard body(destination) else {
                    Task { @MainActor in
                        onFailure("Could not write the log to that location.")
                    }
                    return
                }
            }
        }
    }
}
#else
struct LogShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _: UIActivityViewController,
        context _: Context
    ) {}
}
#endif

struct LogSettingsView: View {
    let onChange: () -> Void

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoInsideProductModalPresentation) private var insideProductModal
    @State private var recording = HakoLogSettings.isRecording(
        from: GlobalConfig.appGroupDefaults
    )
    @State private var retention = HakoLogSettings.retention(
        from: GlobalConfig.appGroupDefaults
    )

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                Toggle("Recording", isOn: $recording)
                    .accessibilityIdentifier("logs.settings.recording")
                    .onChange(of: recording) { value in
                        HakoLogSettings.setRecording(
                            value,
                            in: GlobalConfig.appGroupDefaults
                        )
                        onChange()
                    }
                Picker("Keep", selection: $retention) {
                    ForEach(HakoLogRetention.allCases, id: \.self) { option in
                        Text(hako: .copy(option.title)).tag(option)
                    }
                }
                .accessibilityIdentifier("logs.settings.keep")
                .onChange(of: retention) { value in
                    HakoLogSettings.setRetention(
                        value,
                        in: GlobalConfig.appGroupDefaults
                    )
                    onChange()
                }
            } footer: {
                Text(
                    LogRetentionCopy.summary(retention)
                        + " Turning recording off stops new lines; what is already here stays until you clear it."
                )
            }
        }
        
        .hakoPageTitle("Log Settings")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if !insideProductModal {
                    HakoSheetCloseButton { dismiss() }
                }
            }
        }
        .hakoCapturesDismiss(dismiss)
    }
}

 
 
 
 
 
 
 
 
enum LogExportName {
     
     
     
     
    static func write(now: Date = Date()) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(current(now)).log")
        guard HakoLogStore.shared.writeExport(to: url) else { return nil }
        return url
    }

    static func current(_ now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
         
         
         
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "hako-logs-\(formatter.string(from: now))"
    }
}

enum LogRetentionCopy {
     
     
     
     
     
    static func summary(_ retention: HakoLogRetention) -> String {
        "Keeping \(retention.title), up to 20 MB a day — whichever runs out first."
    }
}

struct LogsContent: View {
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    let lines: [String]
    let isConnected: Bool
    let clear: () -> Void

    @State private var exportDocument =
        LogsTextDocument(text: "")
    @State private var exportError = ""
     
     
    @State private var recordingGeneration = 0
     
     
     
    private struct ShareTarget: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var shareTarget: ShareTarget?
    @State private var confirmsExport = false
    @State private var showsSettings = false

    var body: some View {
        let sharedSnapshot =
            HakoActivityIOSAdapter.snapshot(
                isConnected: isConnected,
                logLines: lines,
                exposesLogActions: true,
                isRecordingLogs: HakoLogSettings.isRecording(
                    from: GlobalConfig.appGroupDefaults
                ),
                logRetentionOptions: HakoLogRetention.allCases.map {
                    HakoLogRetentionOption(id: $0.rawValue, title: $0.title)
                },
                logRetention: HakoLogSettings.retention(
                    from: GlobalConfig.appGroupDefaults
                ).rawValue,
                logRetentionSummary: LogRetentionCopy.summary(
                    HakoLogSettings.retention(
                        from: GlobalConfig.appGroupDefaults
                    )
                ),
                 
                 
                logSeverityFilter: HakoLogSettings.severityFilter(
                    from: GlobalConfig.appGroupDefaults
                )
            )
        HakoClientUI.HakoLogsView(
            snapshot: sharedSnapshot,
            actions: AppleClientActions(capability: .activity) {
                action in
                guard case .activity(let activity) = action else {
                    return
                }
                switch activity {
                case .clearLogs:
                    clear()
                case .exportLogs:
                     
                     
                     
                     
                     
                    exportError = ""
                    confirmsExport = true
                    return
                case .setLogRecording(let value):
                    HakoLogSettings.setRecording(
                        value,
                        in: GlobalConfig.appGroupDefaults
                    )
                    recordingGeneration &+= 1
                case .openLogSettings:
                    showsSettings = true
                case .setLogRetention(let raw):
                    guard let value = HakoLogRetention(rawValue: raw) else {
                        return
                    }
                    HakoLogSettings.setRetention(
                        value,
                        in: GlobalConfig.appGroupDefaults
                    )
                    recordingGeneration &+= 1
                case .setLogSeverityFilter(let levels):
                     
                     
                    HakoLogSettings.setSeverityFilter(
                        levels,
                        in: GlobalConfig.appGroupDefaults
                    )
                case .copyText(let value):
#if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
#else
                    UIPasteboard.general.string = value
#endif
                case .refresh,
                     .closeConnection,
                     .closeAllConnections:
                    break
                }
            },
            presentationClass:
                horizontalSizeClass == .regular
                    ? .regularTouch
                    : .compactTouch,
            palette: HakoActivityIOSAdapter.palette
        ) { symbol in
            HakoSymbolImage(symbol: symbol)
        }
#if !os(macOS)
        .sheet(item: $shareTarget) { target in
            LogShareSheet(activityItems: [target.url])
                .hakoModalPresentation(.page)
        }
#endif
        .hakoProductModal(isPresented: $showsSettings, role: .form) {
            HakoFeatureNavigationContainer {
                LogSettingsView { recordingGeneration &+= 1 }
            }
            .hakoModalPresentation(.form)
        }
        .alert("Export This Log?", isPresented: $confirmsExport) {
            Button("Export", role: .destructive) { performExport() }
            Button("Cancel", role: .cancel) { confirmsExport = false }
        } message: {
            Text("The log is exported exactly as written, so it can contain your servers and any credential a line mentions. Share it only with someone you would show your configuration to.")
        }
        .alert(
            "Export Failed",
            isPresented: Binding(
                get: { !exportError.isEmpty },
                set: { presented in
                    if !presented {
                        exportError = ""
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                exportError = ""
            }
        } message: {
            Text(exportError)
        }
    }

     
     
     
     
     
     
     
    private func performExport() {
        confirmsExport = false
        exportError = ""
#if os(macOS)
        MacSavePanel.write(
            suggestedName: "\(LogExportName.current()).log",
            writing: { HakoLogStore.shared.writeExport(to: $0) },
            onFailure: { message in exportError = message }
        )
#else
        if let url = LogExportName.write() {
            shareTarget = ShareTarget(url: url)
        } else {
            exportError = "Could not prepare the log for sharing."
        }
#endif
    }
}

private struct LogsTextDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.plainText]
    }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data =
                configuration.file.regularFileContents,
              let text = String(
                data: data,
                encoding: .utf8
              )
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(
        configuration _: WriteConfiguration
    ) throws -> FileWrapper {
        FileWrapper(
            regularFileWithContents: Data(text.utf8)
        )
    }
}


