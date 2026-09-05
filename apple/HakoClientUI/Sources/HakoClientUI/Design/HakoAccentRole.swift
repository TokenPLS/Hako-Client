import SwiftUI

public enum HakoAccentRole: String, CaseIterable, Sendable {
    case blue
    case cyan
    case green
    case indigo
    case orange
    case pink
    case purple
    case teal

    public var color: Color {
        switch self {
        case .blue: .blue
        case .cyan: .cyan
        case .green: .green
        case .indigo: .indigo
        case .orange: .orange
        case .pink: .pink
        case .purple: .purple
        case .teal: .teal
        }
    }
}
