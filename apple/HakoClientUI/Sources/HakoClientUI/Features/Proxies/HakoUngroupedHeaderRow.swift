import SwiftUI

 
 
 
 
 
 
public struct HakoUngroupedHeaderRow<Icon: View>: View {
    let count: Int
    let isOpen: Bool
     
     
     
     
     
    let verticalPadding: CGFloat
    let icon: (HakoSymbol) -> Icon
    let toggle: () -> Void

    public init(
        count: Int,
        isOpen: Bool,
        verticalPadding: CGFloat = 0,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        toggle: @escaping () -> Void
    ) {
        self.count = count
        self.isOpen = isOpen
        self.verticalPadding = verticalPadding
        self.icon = icon
        self.toggle = toggle
    }

    public var body: some View {
        Button(action: toggle) {
            HStack(spacing: HakoTheme.Spacing.row) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ungrouped")
                        .font(.body.weight(.semibold))
                    Text("Not referenced by any group")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                icon(.chevronDown)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.vertical, verticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("proxies.group.ungrouped")
    }
}
