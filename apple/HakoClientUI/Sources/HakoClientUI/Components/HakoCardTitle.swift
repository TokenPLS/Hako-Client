import SwiftUI

 
 
 
 
public struct HakoCardTitle<Title: View, Icon: View>: View {
    public let titleTint: Color
    public let iconTint: Color

     
     
     
     
     
     
     
     
    public let followsAccent: Bool

    private let title: Title
    private let icon: Icon

    public init(
        tint: Color,
        followsAccent: Bool = false,
        @ViewBuilder title: () -> Title,
        @ViewBuilder icon: () -> Icon
    ) {
        self.titleTint = tint
        self.iconTint = tint
        self.followsAccent = followsAccent
        self.title = title()
        self.icon = icon()
    }

    public init(
        titleTint: Color,
        iconTint: Color,
        followsAccent: Bool = false,
        @ViewBuilder title: () -> Title,
        @ViewBuilder icon: () -> Icon
    ) {
        self.titleTint = titleTint
        self.iconTint = iconTint
        self.followsAccent = followsAccent
        self.title = title()
        self.icon = icon()
    }

    public var body: some View {
        Label {
            title
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                .font(.headline)
                .foregroundStyle(
                    followsAccent
                        ? AnyShapeStyle(.tint)
                        : AnyShapeStyle(titleTint)
                )
        } icon: {
            icon
                 
                 
                 
                .font(.headline)
                .foregroundStyle(
                    followsAccent
                        ? AnyShapeStyle(.tint)
                        : AnyShapeStyle(iconTint)
                )
        }
    }
}
