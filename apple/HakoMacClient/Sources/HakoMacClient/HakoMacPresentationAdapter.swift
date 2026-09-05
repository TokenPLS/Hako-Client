import AppKit
import HakoClientUI
import SwiftUI

public enum HakoMacPlatformPresentation {
    @MainActor
    static func resignCurrentField() {
        NSApplication.shared.keyWindow?.makeFirstResponder(nil)
    }

    @MainActor
    static var fullWidthSegmentedPickerAdapter:
        HakoFullWidthSegmentedPickerAdapter?
    {
        guard #available(macOS 26.0, *) else { return nil }
        return HakoFullWidthSegmentedPickerAdapter { selection, options in
            AnyView(
                HakoMacFullWidthSegmentedPicker(
                    selection: selection,
                    options: options
                )
                .controlSize(.extraLarge)
            )
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @MainActor
    public static let palette: HakoClientUI.HakoProductPalette =
        HakoClientUI.HakoProductPalette(
             
            canvas: Color(
                nsColor: NSColor(name: nil) { appearance in
                    NSColor.windowBackgroundColor.hakoResolved(for: appearance)
                }
            ),
             
             
             
            surface: .clear,
            raisedFill: Color(
                nsColor: .unemphasizedSelectedContentBackgroundColor
            ),
            separator: Color(nsColor: .separatorColor),
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            card: Color(
                nsColor: NSColor(name: nil) { appearance in
                    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        ? NSColor.white.withAlphaComponent(0.037)
                        : NSColor.black.withAlphaComponent(0.03)
                }
            )
        )
}

private extension NSColor {
     
     
    func hakoResolved(for appearance: NSAppearance) -> NSColor {
        var resolved = self
        appearance.performAsCurrentDrawingAppearance {
            resolved = NSColor(cgColor: cgColor) ?? self
        }
        return resolved
    }
}

@available(macOS 26.0, *)
private struct HakoMacFullWidthSegmentedPicker: NSViewRepresentable {
    @Binding var selection: AnyHashable
    let options: [HakoFullWidthSegmentedPlatformOption]

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, options: options)
    }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: options.map(\.title),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:))
        )
        control.segmentStyle = .capsule
        control.segmentDistribution = .fillEqually
        control.controlSize = .extraLarge
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        configure(control)
        return control
    }

    func updateNSView(
        _ control: NSSegmentedControl,
        context: Context
    ) {
        context.coordinator.selection = $selection
        context.coordinator.options = options
        configure(control)
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NSSegmentedControl,
        context: Context
    ) -> CGSize? {
        let fitting = nsView.fittingSize
        return CGSize(
            width: proposal.width ?? fitting.width,
            height: fitting.height
        )
    }

    private func configure(_ control: NSSegmentedControl) {
        if control.segmentCount != options.count {
            control.segmentCount = options.count
        }
        for (index, option) in options.enumerated() {
            control.setLabel(option.title, forSegment: index)
        }
        control.segmentDistribution = .fillEqually
        control.selectedSegmentBezelColor =
            .unemphasizedSelectedContentBackgroundColor
        control.selectedSegment = options.firstIndex {
            $0.id == selection
        } ?? -1

        let accessibilitySegments = control.cell?.accessibilityChildren() ?? []
        for (index, child) in accessibilitySegments.enumerated()
            where options.indices.contains(index)
        {
            (child as? NSAccessibilityElement)?.setAccessibilityIdentifier(
                options[index].accessibilityIdentifier
            )
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<AnyHashable>
        var options: [HakoFullWidthSegmentedPlatformOption]

        init(
            selection: Binding<AnyHashable>,
            options: [HakoFullWidthSegmentedPlatformOption]
        ) {
            self.selection = selection
            self.options = options
        }

        @objc func selectionChanged(_ sender: NSSegmentedControl) {
            guard options.indices.contains(sender.selectedSegment) else {
                return
            }
            selection.wrappedValue = options[sender.selectedSegment].id
        }
    }
}

typealias HakoSymbol = HakoClientUI.HakoSymbol

extension HakoSymbol {
    var macSystemFallbackName: String {
        switch self {
        case .catCircleFill:
            return "cat.circle.fill"
        case .ruleDomain:
            return "arrow.triangle.branch"
        case .dnsDomain:
             
             
             
             
             
            return "network"
        case .githubMark:
             
             
             
             
             
             
            return "chevron.left.forwardslash.chevron.right"
        default:
            return rawValue
        }
    }
}

struct HakoSymbolImage: View {
    let symbol: HakoSymbol
    var resizesToFit = false

    @ViewBuilder
    var body: some View {
        Group {
            if symbol.isCustom {
                 
                 
                if let image = HakoMacSymbolImageCache.image(for: symbol) {
                    rendered(Image(nsImage: image))
                } else {
                    rendered(Image(systemName: symbol.macSystemFallbackName))
                }
            } else {
                rendered(Image(systemName: symbol.rawValue))
            }
        }
        .scaleEffect(symbol.opticalScale)
    }

    @ViewBuilder
    private func rendered(_ image: Image) -> some View {
        if resizesToFit {
            image
                .symbolRenderingMode(.monochrome)
                .resizable()
                .scaledToFit()
        } else {
            image
                .symbolRenderingMode(.monochrome)
        }
    }
}

extension View {
    @ViewBuilder
    func hakoStandaloneWindowFrame(
        enabled: Bool,
        minWidth: CGFloat,
        minHeight: CGFloat
    ) -> some View {
        if enabled {
            frame(minWidth: minWidth, minHeight: minHeight)
        } else {
            self
        }
    }
}

typealias HakoSelectionMark = HakoClientUI.HakoSelectionMark

func hakoByteRate(_ bytesPerSecond: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .decimal
    return formatter.string(fromByteCount: bytesPerSecond) + "/s"
}
