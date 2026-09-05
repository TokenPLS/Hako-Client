import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoEntryRow: View {
    private let title: String
    private let value: String?
    private let action: () -> Void

    public init(
        _ title: String,
        value: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(HakoCopy.key(title))
                    .foregroundStyle(.primary)
                Spacer(minLength: HakoTheme.Spacing.standard)
                if let value, !value.isEmpty {
                    Text(HakoCopy.key(value))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: HakoTheme.Control.fullWidthRowMinHeightOnItsOwnPlatform)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
