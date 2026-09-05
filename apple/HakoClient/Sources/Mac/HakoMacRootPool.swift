#if os(macOS)
import AppKit
import HakoClientUI
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
private final class HakoMacAppAppearance: ObservableObject {
    @Published private(set) var colorScheme: ColorScheme
    private var observation: NSKeyValueObservation?

    init() {
        colorScheme = Self.current()
        observation = NSApplication.shared.observe(
            \.effectiveAppearance
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let live = Self.current()
                if live != self.colorScheme {
                    self.colorScheme = live
                }
            }
        }
    }

    private static func current() -> ColorScheme {
        NSApplication.shared.effectiveAppearance
            .bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }
}

 
 
private struct HakoMacPooledAppearance<Content: View>: View {
    @StateObject private var appearance = HakoMacAppAppearance()
    let content: Content

    var body: some View {
        content.environment(\.colorScheme, appearance.colorScheme)
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
final class HakoMacRootPoolStore {
    static let shared = HakoMacRootPoolStore()

    private var hosts: [HakoRootDestination: NSHostingView<AnyView>] = [:]
    private var appearanceObservation: NSKeyValueObservation?

    fileprivate func host(
        for destination: HakoRootDestination,
        seededWith seed: () -> AnyView
    ) -> NSHostingView<AnyView> {
        if let existing = hosts[destination] {
            return existing
        }
        let created = NSHostingView(rootView: seed())
        created.autoresizingMask = [.width, .height]
        if #available(macOS 14.0, *) {
            created.sceneBridgingOptions = []
        }
        hosts[destination] = created
         
         
         
         
         
        adoptCurrentAppearance()
        HakoPerf.mark("pool create root=\(destination.rawValue)")
        return created
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    private func adoptCurrentAppearance() {
        if appearanceObservation == nil {
            appearanceObservation = NSApplication.shared.observe(
                \.effectiveAppearance
            ) { _, _ in
                Task { @MainActor in
                    HakoMacRootPoolStore.shared.adoptCurrentAppearance()
                }
            }
        }
        let wanted = NSApplication.shared.effectiveAppearance
        for host in hosts.values where host.appearance?.name != wanted.name {
             
             
            host.appearance = wanted
        }
    }

     
     
     
    func reset() {
        for host in hosts.values {
            host.removeFromSuperview()
        }
        hosts.removeAll()
    }
}

 
 
 
struct HakoMacPooledRootSlot: NSViewRepresentable {
    let destination: HakoRootDestination
    let visible: Bool
    let channels: HakoRegularRootChannels
    let foldStateSink: HakoBoolSink
    let background: Color
    let content: () -> AnyView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        apply(to: container, context: context)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        apply(to: container, context: context)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSView,
        context: Context
    ) -> CGSize? {
         
         
         
        proposal.replacingUnspecifiedDimensions()
    }

    private func apply(to container: NSView, context: Context) {
         
         
         
        if visible || HakoMacRootPoolStore.shared.hasHost(for: destination) {
            let host = HakoMacRootPoolStore.shared.host(
                for: destination,
                seededWith: {
                    AnyView(
                        HakoMacPooledAppearance(
                            content: HakoPooledRootFeed(
                                channels: channels,
                                foldStateSink: foldStateSink,
                                background: background,
                                build: content
                            )
                        )
                         
                         
                         
                         
                         
                         
                         
                        .environment(\.self, context.environment)
                    )
                }
            )
            if host.superview !== container {
                HakoPerf.mark(
                    "pool attach root=\(destination.rawValue)"
                )
                container.addSubview(host)
            }
             
             
             
             
             
             
             
             
             
             
             
            if visible, host.frame != container.bounds {
                HakoPerf.mark(
                    "pool reframe root=\(destination.rawValue) "
                        + "to=\(Int(container.bounds.width))x"
                        + "\(Int(container.bounds.height))"
                )
                host.frame = container.bounds
            }
        }
        let wasVisible = container.alphaValue > 0
        if wasVisible != visible {
             
             
             
             
            HakoPerf.mark(
                "pool \(visible ? "show" : "hide") root=\(destination.rawValue)"
            )
            channels.uiTransitionSink?()
        }
         
         
         
         
         
         
         
         
         
         
         
         
        container.alphaValue = visible ? 1 : 0
         
         
         
         
         
         
         
        channels.latencyPulseGate.isOpen = visible
    }
}

extension HakoMacRootPoolStore {
    fileprivate func hasHost(for destination: HakoRootDestination) -> Bool {
        hosts[destination] != nil
    }
}
#endif
