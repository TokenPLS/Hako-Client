import AppKit
import Combine

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum HakoMacProductVisibility {
    struct Window: Equatable {
        var miniaturized: Bool
        var occluded: Bool

        init(miniaturized: Bool, occluded: Bool) {
            self.miniaturized = miniaturized
            self.occluded = occluded
        }

        @MainActor
        init(_ window: NSWindow) {
            self.init(
                miniaturized: window.isMiniaturized,
                occluded: !window.occlusionState.contains(.visible)
            )
        }
    }

    static func isVisible(
        appHidden: Bool,
        window: Window?,
        everHadWindow: Bool = false
    ) -> Bool {
        if appHidden { return false }
        guard let window else { return !everHadWindow }
        return !window.miniaturized && !window.occluded
    }
}

 
 
 
 
 
@MainActor
final class HakoMacSnapshotGate<Value> {
    private let deliver: (Value) -> Void
    private(set) var isVisible = true
    private(set) var isMenuTracking = false
    private(set) var held: Value?
    private(set) var latest: Value?

    init(deliver: @escaping (Value) -> Void) {
        self.deliver = deliver
    }

    var isOpen: Bool { isVisible && !isMenuTracking }

    func send(_ value: Value) {
        latest = value
        if isOpen {
            deliver(value)
        } else {
            held = value
        }
    }

    func setVisible(_ visible: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        flush()
    }

    func setMenuTracking(_ tracking: Bool) {
        guard tracking != isMenuTracking else { return }
        isMenuTracking = tracking
        flush()
    }

    private func flush() {
        guard isOpen, let value = held else { return }
        held = nil
        deliver(value)
    }
}

 
 
@MainActor
final class HakoMacProductVisibilityObserver {
    private(set) var isVisible = true
    private var everHadWindow = false
    private var cancellables: Set<AnyCancellable> = []
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSApplication.didHideNotification,
            NSApplication.didUnhideNotification,
            NSWindow.didChangeOcclusionStateNotification,
            NSWindow.didMiniaturizeNotification,
            NSWindow.didDeminiaturizeNotification,
            NSWindow.didBecomeKeyNotification,
            NSWindow.willCloseNotification,
        ]
        for name in names {
            center.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] note in
                    let closing = name == NSWindow.willCloseNotification
                        ? note.object as? NSWindow : nil
                    self?.recompute(closing: closing)
                }
                .store(in: &cancellables)
        }
    }

     
     
    static func mainWindow(
        among windows: [NSWindow], closing: NSWindow? = nil
    ) -> NSWindow? {
        windows.first {
            $0 !== closing && $0.level == .normal && $0.canBecomeKey
        }
    }

    func recompute(closing: NSWindow? = nil) {
        let window = Self.mainWindow(
            among: NSApplication.shared.windows, closing: closing
        )
        if window != nil { everHadWindow = true }
        let visible = HakoMacProductVisibility.isVisible(
            appHidden: NSApplication.shared.isHidden,
            window: window.map(HakoMacProductVisibility.Window.init),
            everHadWindow: everHadWindow
        )
        guard visible != isVisible else { return }
        isVisible = visible
        onChange(visible)
    }
}
