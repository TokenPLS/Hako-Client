import SwiftUI

 
 
 
 
public struct HakoIconWell<Icon: View>: View {
    public let tint: Color
    public let size: CGFloat
    public let cornerRadius: CGFloat

    private let icon: Icon

    public init(
        tint: Color,
        size: CGFloat = HakoTheme.Layout.resolvedDestinationRowIconSize,
        cornerRadius: CGFloat = HakoTheme.Radius.icon,
        @ViewBuilder icon: () -> Icon
    ) {
        self.tint = tint
        self.size = size
        self.cornerRadius = cornerRadius
        self.icon = icon()
    }

    public var body: some View {
        icon
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            )
            .accessibilityHidden(true)
    }
}
