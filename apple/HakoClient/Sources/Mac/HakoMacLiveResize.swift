import AppKit
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
struct HakoMacLiveResizeReporting: ViewModifier {
    @State private var isLiveResizing = false

    func body(content: Content) -> some View {
        content
            .environment(\.hakoLiveResizeFreeze, isLiveResizing)
            .background(
                HakoMacLiveResizeObserver(isLiveResizing: $isLiveResizing)
                    .frame(width: 0, height: 0)
            )
    }
}

 
 
struct HakoMacLiveResizeObserver: NSViewRepresentable {
    @Binding var isLiveResizing: Bool

    func makeNSView(context: Context) -> ObservingView {
        let view = ObservingView()
        view.onChange = { isLiveResizing = $0 }
        return view
    }

    func updateNSView(_ nsView: ObservingView, context: Context) {
        nsView.onChange = { isLiveResizing = $0 }
    }

    final class ObservingView: NSView {
        var onChange: ((Bool) -> Void)?
        private var tokens: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observe(window)
        }

         
         
        func observe(_ window: NSWindow?) {
            let center = NotificationCenter.default
            tokens.forEach(center.removeObserver)
            tokens = []
            guard let window else { return }
            tokens = [
                center.addObserver(
                    forName: NSWindow.willStartLiveResizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.onChange?(true)
                },
                center.addObserver(
                    forName: NSWindow.didEndLiveResizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.onChange?(false)
                },
            ]
        }

        deinit {
            tokens.forEach(NotificationCenter.default.removeObserver)
        }
    }
}
