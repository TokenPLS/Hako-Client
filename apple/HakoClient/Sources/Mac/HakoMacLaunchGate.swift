import AppKit

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
final class HakoMacLaunchGate {
    static let shared = HakoMacLaunchGate()

    private(set) var hasFinishedLaunching = false
    private var waiting: [() -> Void] = []

     
     
    func onceLaunched(_ work: @escaping () -> Void) {
        if hasFinishedLaunching {
            work()
        } else {
            waiting.append(work)
        }
    }

     
     
     
    func applicationDidFinishLaunching() {
        hasFinishedLaunching = true
        let work = waiting
        waiting.removeAll()
        for item in work {
            item()
        }
    }
}
