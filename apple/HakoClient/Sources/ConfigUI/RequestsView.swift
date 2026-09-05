import HakoClientUI
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

 
 
struct RequestsView: View {
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @ObservedObject var model: ConnectionsModel

    var body: some View {
        HakoClientUI.HakoRequestsView(
            snapshot: HakoActivityIOSAdapter.snapshot(
                model: model,
                isConnected: model.connected
            ),
            actions: AppleClientActions(capability: .activity) {
                action in
                guard case .activity(let activity) = action else {
                    return
                }
                switch activity {
                case .copyText(let value):
#if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
#else
                    UIPasteboard.general.string = value
#endif
                case .refresh:
                    await model.refresh()
                case .closeConnection(let id):
                    await model.close(id)
                case .closeAllConnections:
                    await model.closeAll()
                case .clearLogs, .exportLogs, .setLogRecording, .setLogRetention,
                     .setLogSeverityFilter, .openLogSettings:
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
    }
}


