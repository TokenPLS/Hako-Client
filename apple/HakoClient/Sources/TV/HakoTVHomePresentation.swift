import Foundation

 
 
 
 
 
 
 
 
 
 
 
struct HakoTVHomePresentation: Equatable {
    enum Tone: Equatable {
         
        case idle
         
        case transitional
         
        case connected
         
        case failed
    }

     
     
     
     
    let buttonTitle: String
    let statusLine: String
    let tone: Tone
     
     
     
     
    let cancels: Bool

    init(buttonTitle: String, statusLine: String, tone: Tone, cancels: Bool = false) {
        self.buttonTitle = buttonTitle
        self.statusLine = statusLine
        self.tone = tone
        self.cancels = cancels
    }

     
    var showsActivity: Bool { tone == .transitional }
     
     
     
     
    var isPressable: Bool { !showsActivity || cancels }

    static func phase(for state: HakoTVProductState) -> HakoHomeConnectionPhase {
        HakoHomeConnectionPresenter.presentation(for: facts(for: state)).phase
    }

    static func facts(for state: HakoTVProductState) -> HakoHomeConnectionFacts {
        let status: String = switch state.stage {
        case .disconnected: "disconnected"
        case .connecting: "connecting"
        case .connected: "connected"
        case .disconnecting: "disconnecting"
        }
        return HakoHomeConnectionFacts(
             
             
             
            activeProfileName: state.profileName.isEmpty ? "Profile" : state.profileName,
            vpnStatus: status,
            errorMessage: state.issue ?? "",
            mode: state.outboundMode.kernelToken
        )
    }

    static func make(state: HakoTVProductState) -> HakoTVHomePresentation {
        if let phase = state.pipelinePhase {
            let line: String = switch phase {
            case .downloading: String(localized: "Downloading configuration…")
            case .preparing: String(localized: "Preparing configuration…")
            case .publishing: String(localized: "Saving configuration…")
            }
             
             
             
            return HakoTVHomePresentation(
                buttonTitle: "STARTING".localizedForTelevision,
                statusLine: line,
                tone: .transitional,
                cancels: true
            )
        }
        let presentation = HakoHomeConnectionPresenter.presentation(for: facts(for: state))
        switch presentation.phase {
        case .connected:
             
             
             
            if let issue = state.issue {
                return HakoTVHomePresentation(
                    buttonTitle: word(presentation),
                    statusLine: issue,
                    tone: .failed
                )
            }
            return HakoTVHomePresentation(
                buttonTitle: word(presentation),
                statusLine: connectedLine(state),
                tone: .connected
            )
        case .connecting:
             
             
             
            return HakoTVHomePresentation(
                buttonTitle: presentation.title.localizedForTelevision,
                statusLine: presentation.subtitle.rawValue.localizedForTelevision,
                tone: .transitional,
                cancels: presentation.primaryAction == .cancel
            )
        case .recoverableError:
            return HakoTVHomePresentation(
                buttonTitle: word(presentation),
                statusLine: presentation.issue?.message ?? presentation.subtitle.rawValue.localizedForTelevision,
                tone: .failed
            )
        default:
            return HakoTVHomePresentation(
                buttonTitle: word(presentation),
                statusLine: String(localized: "Not Connected · \(state.nodeCount) nodes · \(state.groupCount) policy groups · \(state.ruleCount) rules"),
                tone: .idle
            )
        }
    }

     
     
     
     
     
     
     
     
    static func nodeRow(_ state: HakoTVProductState) -> (title: String, value: String) {
        if state.outboundMode == .direct { return (String(localized: "Node"), "DIRECT") }
        if state.nodeName.isEmpty { return (String(localized: "Node"), "—") }
        return (state.nodeName, state.nodeGroup)
    }

     
     
     
    static func nodeExplanation(mode: HakoTVOutboundMode) -> String {
        if mode == .direct {
            return String(localized: "This mode sends all traffic without a proxy, so proxy groups and nodes are not listed.")
        }
        return String(localized: "The node currently carrying proxied traffic. A url-test group may pick a different one for you. Press to see every group and node.")
    }

     
     
     
    private static func word(_ presentation: HakoHomeConnectionPresentation) -> String {
        (presentation.primaryActionTitle ?? presentation.title).localizedForTelevision
    }

     
     
     
    static func connectedLine(_ state: HakoTVProductState) -> String {
        let seconds = state.connectedSince.map { Int(Date().timeIntervalSince($0)) } ?? 0
        return String(localized: "Connected · \(duration(secondsElapsed: seconds)) · \(HakoTVBytes.text(state.sessionBytes)) this session · \(state.connectionCount) connections")
    }

    static func throughput(_ bytesPerSecond: Int64) -> String {
        HakoThroughputFormatter.rate(bytesPerSecond)
    }

    static func duration(secondsElapsed: Int) -> String {
        HakoConnectionDuration.text(secondsElapsed: secondsElapsed)
    }
}

 
 
 
enum HakoTVBytes {
    static func text(_ count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.includesUnit = true
        return formatter.string(fromByteCount: max(0, count))
    }
}
