import AppKit
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
extension View {
    @ViewBuilder
    public func hakoMacWindowChrome() -> some View {
        if #available(macOS 15.0, *) {
            self.modifier(HakoMacFullScreenAwareToolbar())
        } else {
            self
                .ignoresSafeArea(.container, edges: .top)
                .background(HakoMacLegacyWindowChrome())
        }
    }
}

 
 
 
 
 
 
public enum HakoMacToolbarBackgroundPolicy {
    public static func hidesBackground(isFullScreen: Bool) -> Bool {
        !isFullScreen
    }
}

@available(macOS 15.0, *)
private struct HakoMacFullScreenAwareToolbar: ViewModifier {
    @State private var isFullScreen = false

    func body(content: Content) -> some View {
        content
            .toolbarBackgroundVisibility(
                HakoMacToolbarBackgroundPolicy.hidesBackground(
                    isFullScreen: isFullScreen
                ) ? .hidden : .automatic,
                for: .windowToolbar
            )
            .background(
                HakoMacFullScreenObserver(isFullScreen: $isFullScreen)
                    .frame(width: 0, height: 0)
            )
    }
}

 
 
struct HakoMacFullScreenObserver: NSViewRepresentable {
    @Binding var isFullScreen: Bool

    func makeNSView(context: Context) -> ObservingView {
        let view = ObservingView()
        view.onChange = { isFullScreen = $0 }
        return view
    }

    func updateNSView(_ nsView: ObservingView, context: Context) {
        nsView.onChange = { isFullScreen = $0 }
    }

     
     
     
    private final class TokenBox: @unchecked Sendable {
        var tokens: [NSObjectProtocol] = []

        func drain() {
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens = []
        }

        deinit {
            drain()
        }
    }

    final class ObservingView: NSView {
        var onChange: ((Bool) -> Void)?
        private let box = TokenBox()

         
         
        static func dropSeparator(of window: NSWindow?) {
            window?.titlebarSeparatorStyle = .none
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak window] in
                window?.titlebarSeparatorStyle = .none
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observe(window)
            if let window {
                onChange?(window.styleMask.contains(.fullScreen))
            }
        }

         
        func observe(_ window: NSWindow?) {
            box.drain()
            guard let window else { return }
             
             
             
             
             
            window.titlebarSeparatorStyle = .none
            let center = NotificationCenter.default
            box.tokens = [
                center.addObserver(
                    forName: NSWindow.willEnterFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    self?.onChange?(true)
                     
                     
                     
                     
                    Self.dropSeparator(of: window)
                },
                center.addObserver(
                    forName: NSWindow.didExitFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self, weak window] _ in
                    self?.onChange?(false)
                    Self.dropSeparator(of: window)
                },
            ]
        }
    }
}

 
private struct HakoMacLegacyWindowChrome: NSViewRepresentable {
    final class WindowProbeView: NSView {
        private weak var configuredWindow: NSWindow?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, configuredWindow !== window else { return }
            configuredWindow = window
            DispatchQueue.main.async { [weak window] in
                guard let window else { return }
                Self.configure(window)
            }
        }

        private static func configure(_ window: NSWindow) {
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
        }
    }

    func makeNSView(context: Context) -> NSView {
        WindowProbeView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
