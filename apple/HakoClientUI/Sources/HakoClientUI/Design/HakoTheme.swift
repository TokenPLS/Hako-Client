import SwiftUI

 
 
 
 
 
public enum HakoTheme {
    public enum Spacing {
        public static let tight: CGFloat = 4
        public static let compact: CGFloat = 8
        public static let row: CGFloat = 12
         
         
         
         
        public static let cardGap: CGFloat = 10
        public static let standard: CGFloat = 16
        public static let section: CGFloat = 24
    }

     
     
    public enum Control {
         
         
         
         
         
         
         
         
         
         
         
         
        #if os(macOS)
        public static let pointerRowTarget: CGFloat = 28
        #else
        public static let pointerRowTarget: CGFloat = 44
        #endif

         
        public static let minimumHitTarget: CGFloat = 44

         
         
         
        public static let compactChoiceRowMinHeight: CGFloat = 48

         
         
        public static let fullWidthRowMinHeight: CGFloat = 49

         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        public static let fullWidthRowMinHeightOnItsOwnPlatform: CGFloat? = nil
    }

     
     
     
     
     
     
     
     
     
     
     
     
    public enum Typography {
        public static func usesHanDensity(_ locale: Locale) -> Bool {
            let language = locale.identifier.prefix(2).lowercased()
            return language == "zh" || language == "ja"
        }

         
        public static func rowSubtitle(_ locale: Locale) -> Font {
            usesHanDensity(locale) ? .footnote : .subheadline
        }

         
        public static func rowSubtitleGap(_ locale: Locale) -> CGFloat {
            usesHanDensity(locale) ? 5 : Spacing.tight
        }
    }

    public enum Radius {
        public static let control: CGFloat = 8
        public static let icon: CGFloat = 9

         
         
         
         
         
         
         
        public static var card: CGFloat {
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
                return 26
            }
            return 12
        }

        public static var groupedSection: CGFloat {
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
                return 26
            }
            return 20
        }

        public static let liquidGlassCard: CGFloat = 24
    }

    public enum Opacity {
        public static let regularSidebarSelection: Double = 0.08
    }

     
     
     
     
     
     
     
    public enum Regular {
        public enum Sidebar {
            public static let iconSize: CGFloat = 22
            public static let sectionIndent: CGFloat = Spacing.standard

             
             
             
             
             
             
             
             
             
             
            public static let sectionHeaderLeadingCompensation: CGFloat = {
#if os(macOS)
                return Spacing.compact
#else
                return 0
#endif
            }()
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            public static let pinnedRowSectionIndent: CGFloat = {
#if os(macOS)
                return sectionIndent
#else
                return 0
#endif
            }()
            public static let rowLeadingInset: CGFloat = {
#if os(macOS)
                return HakoTheme.MacOS.Sidebar.rowLeadingInset
#else
                return Spacing.row
#endif
            }()
            public static let minimumWidth: CGFloat = 240
            public static let width: CGFloat = 256
            public static let maximumWidth: CGFloat = 272

             
            public static let topInset: CGFloat = 32
        }

        public enum Detail {
            public static let maximumContentWidth: CGFloat = 1_120
            public static let horizontalInset: CGFloat = 56

             
             
            public static let destinationRowMinHeight: CGFloat = 68
        }
    }

     
    public enum MacOS {
         
         
         
         
         
         
         
         
         
         
         
         
        public static let destinationRowIconSize: CGFloat = 26

        public enum Sidebar {
             
             
             
            public static let rowLeadingInset: CGFloat = 0
        }

        public enum ProductModal {
            public static let width: CGFloat = 720
            public static let maximumHeight: CGFloat = 720
            public static let cornerRadius: CGFloat = 26
             
             
             
             
             
            public static let headerMinHeight: CGFloat =
                closeGlyphSize + (closePadding * 2)
            public static let closeGlyphSize: CGFloat = 32
            public static let closePadding: CGFloat = 12
            public static let closeHitRegion: CGFloat =
                closeGlyphSize + (closePadding * 2)
            public static let contentHorizontalInset: CGFloat = 85
            public static let borderWidth: CGFloat = 1
            public static let dimmingOpacity: Double = 0.45
            public static let shadowOpacity: Double = 0.5
            public static let shadowRadius: CGFloat = 42
            public static let shadowYOffset: CGFloat = 18
             
             
             
             
             
             
             
             
             
             
             
             
             
        }
    }

    public enum Layout {
        public static let primaryPageGlassBleed: CGFloat = 48
         
         
         
         
         
         
         
         
         
         
        public static let destinationRowIconSize: CGFloat = 29

         
         
        public static let destinationRowTargetHeight: CGFloat = 62.7

         
         
         
        public static let cardHorizontalInset: CGFloat = 20

         
         
         
         
         
         
         
         
         
         
        public static let proxyGroupIconSize: CGFloat = 24
        public static let proxyGroupIconCornerRadius: CGFloat = 6
         
         
         
         
         
        public static var resolvedDestinationRowIconSize: CGFloat {
            HakoPlatformLayout.pageUsesSystemSettingsIdiom
                ? MacOS.destinationRowIconSize
                : destinationRowIconSize
        }

        public static var destinationRowDividerInset: CGFloat {
            resolvedDestinationRowIconSize + Spacing.row
        }
    }
}

extension View {
     
     
     
    @ViewBuilder
    func hakoReaderControlGroupStyle() -> some View {
#if os(tvOS)
        self
#else
        controlGroupStyle(.navigation)
#endif
    }
}
