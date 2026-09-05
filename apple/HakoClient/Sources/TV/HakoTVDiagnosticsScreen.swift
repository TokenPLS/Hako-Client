import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVDiagnosticsScreen: View {
    enum Row: Hashable, CaseIterable {
        case tunnel, lastProblem, memory, geodata, providers, resolvers

        var title: String {
            switch self {
            case .tunnel: String(localized: "Tunnel")
            case .lastProblem: String(localized: "Last problem")
            case .memory: String(localized: "Memory")
            case .geodata: String(localized: "Geo data")
            case .providers: String(localized: "Providers")
            case .resolvers: String(localized: "Resolvers")
            }
        }

         
         
         
         
         
         
        var identifier: String {
            switch self {
            case .tunnel: "tunnel"
            case .lastProblem: "lastProblem"
            case .memory: "memory"
            case .geodata: "geodata"
            case .providers: "providers"
            case .resolvers: "resolvers"
            }
        }

        var explanation: String {
            switch self {
            case .tunnel:
                String(localized: "Whether the packet tunnel is up. Everything else on this screen is read from it while it runs.")
            case .memory:
                String(localized: "What the tunnel is using now. The system stops an extension that grows too large; if that happens, the item below prices every rule set and resource by name.")
            case .geodata:
                String(localized: "Which copy of the GeoIP and GeoSite databases the tunnel loaded.")
            case .lastProblem:
                String(localized: "The most recent thing that went wrong, kept after it stopped being true. It covers this app session only; it does not know about a start that failed while the app was closed.")
            case .providers:
                String(localized: "The profile's rule sets and node lists, of both kinds, and whether the tunnel can read each one. Press to see them by name.")
            case .resolvers:
                String(localized: "The tunnel's own resolvers, as the profile names them.")
            }
        }
    }

    static var memoryCeilingLine: String { String(localized: "The ceiling on this device has not been measured.") }

    @Binding var state: HakoTVProductState
    var openDNS: () -> Void = {}
    var openProviders: () -> Void = {}

    @State private var explained: Row = .tunnel

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            List {
                Section("Runtime") {
                    row(.tunnel, value: Self.tunnelValue(state)) {}
                    row(.lastProblem, value: Self.lastProblemValue(state.lastProblem)) {}
                        .lineLimit(2)
                    row(.memory, value: Self.memoryValue(state.memoryBytes)) {}
                    row(.geodata, value: state.geodataSource.localizedForTelevision) {}
                    row(.providers, value: Self.providersValue(ready: state.providers.count { $0.failure == nil }, total: state.providers.count), action: openProviders)
                }
                Section("Resolution") {
                    row(.resolvers, value: "\(state.dnsNameservers.count)", action: openDNS)
                }
            }
            .listStyle(.grouped)
            .safeAreaPadding(.horizontal, 44)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                Text(explained.title)
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
                if explained == .memory {
                     
                     
                    Text(Self.memoryValue(state.memoryBytes))
                        .font(.largeTitle)
                        .monospacedDigit()
                }
                if explained == .lastProblem, let problem = state.lastProblem {
                     
                     
                     
                     
                     
                    Text(problem.sentence)
                        .font(.title3)
                    Text(Self.lastProblemWhen(problem) ?? "")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Text(explained.explanation)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                if explained == .lastProblem, state.lastProblem != nil {
                     
                     
                     
                     
                     
                     
                    Text(Self.lastProblemAdvice)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                if explained == .memory {
                    Text(Self.memoryCeilingLine)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.18), value: explained)
        }
         
    }

    private func row(_ row: Row, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            LabeledContent(row.title, value: value)
        }
        .onHakoTVFocus { explained = row }
        .accessibilityIdentifier("tvos.diagnostics.\(row.identifier)")
    }

     

    static func tunnelValue(_ state: HakoTVProductState) -> String {
        state.isConnected ? String(localized: "Running") : String(localized: "Not running")
    }

     
     
     
     
     
     
    static func providersValue(ready: Int, total: Int) -> String {
        guard total > 0 else { return String(localized: "None") }
        return String(localized: "\(ready) of \(total)")
    }

    static func lastProblemValue(_ problem: HakoTVProductState.Problem?) -> String {
        problem?.sentence ?? String(localized: "None since this app opened")
    }

     
     
     
    static func lastProblemWhen(_ problem: HakoTVProductState.Problem?) -> String? {
        guard let problem else { return nil }
        return HakoTVSubscriptionUpdatedWords.text(updatedAt: problem.at)
    }

    static var lastProblemAdvice: String {
        String(localized: "Check that the subscription address is still reachable, then update it once from its own screen.")
    }

     
    static func memoryValue(_ bytes: Int64) -> String {
        HakoTVBytes.text(bytes)
    }
}
