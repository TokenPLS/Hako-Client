import SwiftUI

 
 
 
 
 
public struct HakoRootSidebarRow<Icon: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public let destination: HakoRootDestination
    public let isSelected: Bool
    public let minimumHeight: CGFloat
    public let horizontalPadding: CGFloat

    private let icon: Icon

    public init(
        destination: HakoRootDestination,
        isSelected: Bool,
        minimumHeight: CGFloat = HakoTheme.Control.minimumHitTarget,
        horizontalPadding: CGFloat = HakoTheme.Spacing.compact,
        @ViewBuilder icon: () -> Icon
    ) {
        self.destination = destination
        self.isSelected = isSelected
        self.minimumHeight = minimumHeight
        self.horizontalPadding = horizontalPadding
        self.icon = icon()
    }

    public var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize
                && HakoPlatformLayout.sidebarStacksLabelsAtAccessibilitySizes
            {
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.compact
                ) {
                    sidebarIcon
                    title
                }
            } else {
                HStack(spacing: HakoTheme.Spacing.row) {
                    sidebarIcon
                    title
                    Spacer(minLength: HakoTheme.Spacing.compact)
                }
            }
        }
        .frame(minHeight: minimumHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .foregroundStyle(contentStyle)
        .background {
            Capsule()
                .fill(
                    isSelected
                        ? Color.primary.opacity(
                            HakoTheme.Opacity.regularSidebarSelection
                        )
                        : Color.clear
                )
        }
        .contentShape(Rectangle())
    }

    private var sidebarIcon: some View {
        icon
            .font(.system(
                size: HakoTheme.Regular.Sidebar.iconSize,
                weight: .semibold
            ))
            .frame(
                width: HakoTheme.Regular.Sidebar.iconSize,
                height: HakoTheme.Regular.Sidebar.iconSize
            )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var contentStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary)
    }

    private var title: some View {
         
         
         
         
         
         
         
         
        HStack(spacing: 0) {
            Text(hako: .copy(destination.title))
                .lineLimit(1)
                .foregroundStyle(contentStyle)
#if os(macOS)
             
             
             
             
            Rectangle()
                .fill(Color.primary.opacity(0.02))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
#endif
        }
    }
}
