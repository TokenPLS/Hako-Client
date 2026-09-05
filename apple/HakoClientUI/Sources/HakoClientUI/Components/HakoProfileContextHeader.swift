import SwiftUI

 
 
 
 
public struct HakoProfileContextHeader<Icon: View>: View {
    public let profileName: String
    public let message: HakoDisplayText
    public let iconTint: Color

    private let icon: Icon

    public init(
        profileName: String,
        message: HakoDisplayText,
        iconTint: Color = .blue,
        @ViewBuilder icon: () -> Icon
    ) {
        self.profileName = profileName
        self.message = message
        self.iconTint = iconTint
        self.icon = icon()
    }

    public var body: some View {
        HStack(
            alignment: .top,
            spacing: HakoTheme.Spacing.row
        ) {
            icon
                .font(.body.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 24, height: 24)

            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.tight
            ) {
                Text(profileName)
                    .font(.headline)
                    .lineLimit(2)
                Text(hako: message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
