import SwiftUI
import HakoClientUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

 
 
enum HakoTheme {
    static var canvas: Color { canvas(pureBlack: AppPreferences.pureBlack()) }

    static func canvas(pureBlack: Bool) -> Color {
#if os(macOS)
         
         
         
         
        _ = pureBlack
        return Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? .black
                    : .windowBackgroundColor
            }
        )
#else
        return Color(uiColor: UIColor { traits in
            pureBlack && traits.userInterfaceStyle == .dark
                ? .black
                : .systemGroupedBackground
        })
#endif
    }
#if os(macOS)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let raisedFill = Color(
        nsColor: .unemphasizedSelectedContentBackgroundColor
    )
    static let separator = Color(nsColor: .separatorColor)
     
     
     
     
    static let card = Color(
        nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(
                    red: 0x2E / 255,
                    green: 0x2E / 255,
                    blue: 0x2E / 255,
                    alpha: 1
                )
            }
            return NSColor.alternatingContentBackgroundColors[1]
        }
    )
#else
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let raisedFill = Color(uiColor: .tertiarySystemFill)
    static let separator = Color(uiColor: .separator)
#endif

     
     
     
     
    enum Spacing {
        static let tight = HakoClientUI.HakoTheme.Spacing.tight
        static let compact = HakoClientUI.HakoTheme.Spacing.compact
        static let row = HakoClientUI.HakoTheme.Spacing.row
        static let standard = HakoClientUI.HakoTheme.Spacing.standard
        static let section = HakoClientUI.HakoTheme.Spacing.section
    }

     
     
     
    enum Typography {
        static func rowSubtitle(_ locale: Locale) -> Font {
            HakoClientUI.HakoTheme.Typography.rowSubtitle(locale)
        }

        static func rowSubtitleGap(_ locale: Locale) -> CGFloat {
            HakoClientUI.HakoTheme.Typography.rowSubtitleGap(locale)
        }
    }

    enum Radius {
        static let control = HakoClientUI.HakoTheme.Radius.control
        static let icon = HakoClientUI.HakoTheme.Radius.icon
        static let card = HakoClientUI.HakoTheme.Radius.card
         
         
        static let groupedSection = HakoClientUI.HakoTheme.Radius.groupedSection
        static let liquidGlassCard = HakoClientUI.HakoTheme.Radius.liquidGlassCard
    }

    enum Layout {
         
         
        static let primaryPageGlassBleed = HakoClientUI.HakoTheme.Layout.primaryPageGlassBleed
    }
}

extension HakoClientUI.HakoProductPalette {
     
     
     
     
     
     
     
     
     
    static var hakoProduct: HakoClientUI.HakoProductPalette {
#if os(macOS)
        HakoClientUI.HakoProductPalette(
            canvas: HakoTheme.canvas,
            surface: HakoTheme.surface,
            raisedFill: HakoTheme.raisedFill,
            separator: HakoTheme.separator,
            card: HakoTheme.card
        )
#else
        HakoClientUI.HakoProductPalette(
            canvas: HakoTheme.canvas,
            surface: HakoTheme.surface,
            raisedFill: HakoTheme.raisedFill,
            separator: HakoTheme.separator
        )
#endif
    }
}
