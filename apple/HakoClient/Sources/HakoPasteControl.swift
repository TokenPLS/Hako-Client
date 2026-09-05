import HakoClientUI
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

 
 
 
 
 
 
public enum HakoPasteControlPolicy {
    public enum Mode: Equatable {
        case systemControl
        case directRead
    }

    public static func mode(majorSystemVersion: Int) -> Mode {
        majorSystemVersion >= 16 ? .systemControl : .directRead
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoPasteControl: View {
    private let onPaste: (String) -> Void

    public init(onPaste: @escaping (String) -> Void) {
        self.onPaste = onPaste
    }

    public var body: some View {
#if os(iOS)
        if #available(iOS 16.0, *) {
             
             
            SystemPasteControl(onPaste: onPaste)
                .accessibilityIdentifier("hako.paste")
        } else {
            Button {
                onPaste(UIPasteboard.general.string ?? "")
            } label: {
                Image(systemName: HakoSymbol.docOnClipboard.name)
            }
            .accessibilityLabel("Paste")
            .accessibilityIdentifier("hako.paste")
        }
#elseif os(macOS)
        Button {
            onPaste(NSPasteboard.general.string(forType: .string) ?? "")
        } label: {
            Image(systemName: HakoSymbol.docOnClipboard.name)
        }
         
         
        .buttonStyle(.bordered)
        .tint(.primary)
        .accessibilityLabel("Paste")
        .accessibilityIdentifier("hako.paste")
#else
        EmptyView()
#endif
    }
}

#if os(iOS)
@available(iOS 16.0, *)
private struct SystemPasteControl: UIViewRepresentable {
    let onPaste: (String) -> Void

    func makeUIView(context: Context) -> UIPasteControl {
        let configuration = UIPasteControl.Configuration()
        configuration.displayMode = .iconOnly
        configuration.cornerStyle = .medium
        let control = UIPasteControl(configuration: configuration)
        control.target = context.coordinator
        return control
    }

    func updateUIView(_ uiView: UIPasteControl, context: Context) {
        context.coordinator.onPaste = onPaste
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UIPasteControl,
        context: Context
    ) -> CGSize? {
        uiView.intrinsicContentSize
    }

    func makeCoordinator() -> Coordinator { Coordinator(onPaste: onPaste) }

     
     
    final class Coordinator: UIResponder {
        var onPaste: (String) -> Void

        init(onPaste: @escaping (String) -> Void) {
            self.onPaste = onPaste
            super.init()
            pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)
        }

        override func paste(itemProviders: [NSItemProvider]) {
            for provider in itemProviders
            where provider.canLoadObject(ofClass: NSString.self) {
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    guard let text = object as? NSString else { return }
                    let pasted = text as String
                    Task { @MainActor in self.onPaste(pasted) }
                }
                return
            }
        }
    }
}
#endif
