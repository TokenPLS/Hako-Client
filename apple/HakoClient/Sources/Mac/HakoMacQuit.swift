import AppKit
import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
final class HakoMacQuit {
     
    enum Occasion: Equatable {
         
        case readerQuit
         
         
         
         
        case readerQuitLeavingTunnelRunning
         
         
         
        case relaunchForLanguageChange
    }

     
     
     
     
     
     
     
     
     
     
    static func tunnelIsUp(status: String) -> Bool {
        ["connected", "connecting", "disconnecting"]
            .contains(status.lowercased())
    }

     
     
     
     
     
    static var nextTermination: Occasion = .readerQuit

    private let isTunnelUp: () -> Bool
    private let stop: () async -> Void
    private let allowTermination: () -> Void
    private let settle: () async -> Void
    private let settleAttempts: Int

     
     
    private(set) var teardown: Task<Void, Never>?

    init(
        isTunnelUp: @escaping () -> Bool,
        stop: @escaping () async -> Void,
        allowTermination: @escaping () -> Void,
         
         
         
         
         
         
         
         
        settle: @escaping () async -> Void = {
            try? await Task.sleep(nanoseconds: 25_000_000)
        },
        settleAttempts: Int = 160
    ) {
        self.isTunnelUp = isTunnelUp
        self.stop = stop
        self.allowTermination = allowTermination
        self.settle = settle
        self.settleAttempts = settleAttempts
    }

    func reply(for occasion: Occasion) -> NSApplication.TerminateReply {
        guard case .readerQuit = occasion else { return .terminateNow }
        guard isTunnelUp() else { return .terminateNow }
        teardown = Task { @MainActor [self] in
            await stop()
             
             
             
             
            var attempts = 0
            while isTunnelUp(), attempts < settleAttempts {
                attempts += 1
                await settle()
            }
             
             
            allowTermination()
        }
        return .terminateLater
    }
}


 
 
