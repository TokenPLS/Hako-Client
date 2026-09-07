import HakoClientUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct ActivityView: View, Equatable {
    let command: ClashCommandClient
    let connections: ConnectionsModel
    @Binding var lens: HakoActivityLens
    var loadsPersistedLogs = true

    static func == (lhs: ActivityView, rhs: ActivityView) -> Bool {
        lhs.command === rhs.command
            && lhs.connections === rhs.connections
            && lhs.lens == rhs.lens
            && lhs.loadsPersistedLogs == rhs.loadsPersistedLogs
    }

     
     
    private static var searchFieldStyle: HakoActivitySearchFieldStyle {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? .phoneBottomBar : .standard
        #else
        .standard
        #endif
    }

    var body: some View {
        HakoActivityPageView(
            lens: $lens,
            palette: HakoActivityIOSAdapter.palette,
            searchFieldStyle: Self.searchFieldStyle
        ) { query, isShown in
             
             
             
            ConnectionsView(
                model: connections,
                command: command,
                autoStart: false,
                query: query,
                isShown: isShown
            )
        } requests: { query, isShown in
            RequestsView(model: connections, query: query, isShown: isShown)
        } logs: { query, isShown in
            LogsDestinationView(
                command: command,
                loadsPersistedLogs: loadsPersistedLogs,
                query: query,
                isShown: isShown
            )
        }
    }
}
