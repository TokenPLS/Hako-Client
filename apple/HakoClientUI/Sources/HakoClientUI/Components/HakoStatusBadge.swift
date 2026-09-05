import SwiftUI

 
public enum HakoBadgeRole: Equatable, Sendable {
     
    case status
     
    case category
     
    case requirement
}

 
 
 
 
public struct HakoStatusBadge: View {
    public let title: String
    public let tint: Color
    public let role: HakoBadgeRole
    public let categoryFill: Color
    public let requirementFill: Color
    public let separator: Color
    public let requirementBorderOpacity: Double
    public let font: Font
    public let horizontalPadding: CGFloat
    public let verticalPadding: CGFloat

    public init(
        title: String,
        tint: Color,
        role: HakoBadgeRole = .status,
        categoryFill: Color,
        requirementFill: Color,
        separator: Color,
        requirementBorderOpacity: Double = 0.18,
        font: Font = .caption2.weight(.semibold),
        horizontalPadding: CGFloat = HakoTheme.Spacing.compact,
        verticalPadding: CGFloat = HakoTheme.Spacing.tight
    ) {
        self.title = title
        self.tint = tint
        self.role = role
        self.categoryFill = categoryFill
        self.requirementFill = requirementFill
        self.separator = separator
        self.requirementBorderOpacity = requirementBorderOpacity
        self.font = font
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
    }

    public var body: some View {
        Text(hako: .copy(title))
            .font(font)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: true)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Capsule().fill(background))
            .overlay {
                if role == .requirement, requirementBorderOpacity > 0 {
                    Capsule()
                        .stroke(
                            separator.opacity(requirementBorderOpacity),
                            lineWidth: 0.5
                        )
                }
            }
    }

    private var foreground: Color {
        switch role {
        case .status:
            return tint
        case .category, .requirement:
            return .secondary
        }
    }

    private var background: Color {
        switch role {
        case .status:
            return tint.opacity(0.10)
        case .category:
            return categoryFill
        case .requirement:
            return requirementFill
        }
    }
}
