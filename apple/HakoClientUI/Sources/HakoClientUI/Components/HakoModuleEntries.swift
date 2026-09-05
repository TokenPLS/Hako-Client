import SwiftUI

 
public struct HakoModuleEntry: Identifiable {
    public let id: String
    public let title: String
    public let action: () -> Void

    public init(id: String, title: String, action: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.action = action
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoModuleEntries: View {
    private let entries: [HakoModuleEntry]
    private let palette: HakoProductPalette
    private let identifier: (HakoModuleEntry) -> String
    private let stacked: Bool

    public init(
        entries: [HakoModuleEntry],
        palette: HakoProductPalette,
        stacked: Bool,
        identifier: @escaping (HakoModuleEntry) -> String
    ) {
        self.entries = entries
        self.palette = palette
        self.stacked = stacked
        self.identifier = identifier
    }

    public var body: some View {
        if stacked {
            VStack(alignment: .trailing, spacing: HakoTheme.Spacing.compact) {
                buttons
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            HStack(spacing: HakoTheme.Spacing.compact) {
                Spacer(minLength: 0)
                buttons
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        ForEach(entries) { entry in
            HakoModuleEntryButton(
                title: entry.title,
                palette: palette,
                action: entry.action
            )
            .accessibilityIdentifier(identifier(entry))
        }
    }
}

private struct HakoModuleEntryButton: View {
    let title: String
    let palette: HakoProductPalette
    let action: () -> Void

    @ViewBuilder
    var body: some View {
#if os(macOS)
        quiet
#else
        if #available(iOS 26.0, tvOS 26.0, *) {
            Button(action: action) { label }
                .buttonStyle(.glass)
                .foregroundStyle(.primary)
        } else {
            quiet
        }
#endif
    }

    private var quiet: some View {
        Button(action: action) {
            label
                .padding(.horizontal, HakoTheme.Spacing.row)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(
                        cornerRadius: HakoTheme.Radius.control,
                        style: .continuous
                    )
                    .fill(palette.raisedFill)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var label: some View {
        Text(HakoCopy.key(title))
            .font(.subheadline.weight(.medium))
            .fixedSize(horizontal: false, vertical: true)
    }
}
