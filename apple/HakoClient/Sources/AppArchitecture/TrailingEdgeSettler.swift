import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
final class TrailingEdgeSettler {

     
     
     
    static let modeStreamWindowNanoseconds: UInt64 = 400_000_000

    private let windowNanoseconds: UInt64
    private var pending: Task<Void, Never>?
     
     
     
     
     
    private var ticket: UInt64 = 0

    init(windowNanoseconds: UInt64) {
        self.windowNanoseconds = windowNanoseconds
    }

     
     
    func submit(_ deliver: @escaping @MainActor () -> Void) {
        pending?.cancel()
        ticket &+= 1
        let issued = ticket
        pending = Task { [windowNanoseconds] in
            do {
                try await Task.sleep(nanoseconds: windowNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled, issued == self.ticket else { return }
            deliver()
        }
    }

     
     
    func cancel() {
        pending?.cancel()
        pending = nil
        ticket &+= 1
    }
}
