import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVHomeView: View {
    @Binding var state: HakoTVProductState
     
     
     
    @Binding var showsOutboundMode: Bool
     
     
    @Binding var showsSubscriptions: Bool
     
     
     
    @Binding var showsNodes: Bool
     
     
     
    var onPrimaryAction: (() -> Void)?

    @State private var explained: Explanation = .connect

    enum Explanation: Hashable {
        case connect, disconnect, outbound, profile, node

        var label: String {
            switch self {
            case .connect: String(localized: "START")
            case .disconnect: String(localized: "STOP")
            case .outbound: String(localized: "Outbound mode")
            case .profile: String(localized: "Configuration")
            case .node: String(localized: "Node")
            }
        }

        var detail: String {
            switch self {
            case .connect:
                String(localized: "Starts the tunnel and applies the rules in the current configuration. Until then nothing is proxied.")
            case .disconnect:
                String(localized: "Stops the tunnel. The configuration and the selected node stay as they are.")
            case .outbound:
                String(localized: "Rule matches every connection against the configuration. Global sends everything to the selected node. Direct proxies nothing.")
            case .profile:
                String(localized: "The profile this Apple TV is using. Press to see the others, switch to one, or remove one. The address is what gets remembered; what it points at is downloaded again when needed.")
            case .node:
                 
                 
                HakoTVHomePresentation.nodeExplanation(mode: .rule)
            }
        }
    }

    private var isConnected: Bool { state.isConnected }
    private var presentation: HakoTVHomePresentation { HakoTVHomePresentation.make(state: state) }

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            actions
            explanation
        }
        .task {
             
             
             
             
             
             
            explained = isConnected ? .disconnect : .connect
        }
    }

    private var actions: some View {
        list
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    private var primaryAction: some View {
        Button {
            guard presentation.isPressable else { return }
            if let onPrimaryAction {
                onPrimaryAction()
            } else {
                state.stage = isConnected ? .disconnected : .connected
            }
        } label: {
            primaryWord
        }
        .onHakoTVFocus { explained = isConnected ? .disconnect : .connect }
         
         
         
         
         
         
         
         
         
         
         
         
         
    }

     
     
     
     
     
     
     
    private var primaryWord: some View {
        HStack(spacing: 24) {
            if presentation.showsActivity {
                ProgressView()
            }
            Text(presentation.buttonTitle)
                 
                 
                 
                .font(.largeTitle)
                .fontWeight(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var list: some View {
        List {
             
             
             
             
            Section {
                primaryAction
            } footer: {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                Text(presentation.statusLine)
                    .foregroundStyle(Self.tone(presentation.tone))
                     
                     
                     
                     
                     
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if isConnected {
                Section("Throughput") {
                     
                     
                    LabeledContent("Download", value: HakoTVHomePresentation.throughput(state.downloadBytesPerSecond))
                    LabeledContent("Upload", value: HakoTVHomePresentation.throughput(state.uploadBytesPerSecond))
                }
            }

            Section("Using") {
                 
                 
                Button { showsOutboundMode = true } label: {
                    LabeledContent("Outbound mode", value: state.outboundMode.title)
                }
                    .onHakoTVFocus { explained = .outbound }
                 
                 
                Button { showsSubscriptions = true } label: {
                    LabeledContent(state.profileName, value: state.profileAge)
                }
                    .onHakoTVFocus { explained = .profile }
                 
                 
                 
                 
                 
                 
                 
                 
                Button { showsNodes = true } label: {
                    let row = HakoTVHomePresentation.nodeRow(state)
                    LabeledContent(row.title, value: row.value)
                }
                    .onHakoTVFocus { explained = .node }
            }
        }
         
         
         
        .listStyle(.grouped)
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        .safeAreaPadding(.horizontal, 44)
        .frame(maxWidth: .infinity)
    }

     

     
     
    static func statusLine(_ state: HakoTVProductState) -> String {
        HakoTVHomePresentation.make(state: state).statusLine
    }

     
    static func tone(_ tone: HakoTVHomePresentation.Tone) -> Color {
        switch tone {
        case .idle: .blue
        case .transitional: .secondary
        case .connected: .green
        case .failed: .red
        }
    }

     
     
    private var explanation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(explained.label)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)
            Text(explained == .node ? HakoTVHomePresentation.nodeExplanation(mode: state.outboundMode) : explained.detail)
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.18), value: explained)
    }
}
