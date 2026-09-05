import SwiftUI

 
 
 
 
 
 
public struct HakoUtilitiesView<Icon: View, DestinationContent: View>: View {
    private let snapshot: AppleClientSnapshot
    @Binding private var destination: HakoUtilitiesDestination
    private let presentationClass: HakoPresentationClass
    private let palette: HakoProductPalette
    private let icon: (HakoSymbol) -> Icon
    private let destinationContent:
        (HakoUtilitiesDestination) -> DestinationContent
    private let omitting: Set<HakoUtilitiesDestination>

    public init(
        snapshot: AppleClientSnapshot,
        destination: Binding<HakoUtilitiesDestination>,
        presentationClass: HakoPresentationClass,
        palette: HakoProductPalette,
        omitting: Set<HakoUtilitiesDestination> = [],
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        @ViewBuilder destinationContent: @escaping (
            HakoUtilitiesDestination
        ) -> DestinationContent
    ) {
        self.snapshot = snapshot
        _destination = destination
        self.presentationClass = presentationClass
        self.palette = palette
        self.omitting = omitting
        self.icon = icon
        self.destinationContent = destinationContent
    }

     
     
    private var visibleSections: [HakoUtilitiesSectionDescriptor] {
        HakoUtilitiesCatalog.sections.compactMap { section in
            let remaining = section.destinations.filter {
                !omitting.contains($0)
            }
            guard !remaining.isEmpty else {
                return nil
            }
            return HakoUtilitiesSectionDescriptor(
                id: section.id,
                destinations: remaining
            )
        }
    }

    public var body: some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "utilities.root"
        ) {
            ForEach(visibleSections, id: \.id) {
                section in
                HakoProductPageSection(
                    title: section.id.title,
                    palette: palette,
                    presentationClass: presentationClass
                ) {
                    ForEach(section.destinations, id: \.self) {
                        item in
                        destinationLink(item)

                         
                         
                         
                        if item != section.destinations.last,
                           !HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                            Divider()
                                .padding(
                                    .leading,
                                    HakoTheme.Layout
                                        .destinationRowDividerInset
                                )
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(
                    "utilities.section.\(section.id.title)"
                )
            }
        }
        .background(deepLink)
    }

     
     
     
     
     
     
     
    @ViewBuilder
    private var deepLink: some View {
        if presentationClass == .compactTouch {
             
             
             
             
             
             
             
            HakoRoutedViewDestination(isPresented: deepLinkBinding) {
                if let item = HakoUtilitiesDeepLink.presented(for: destination) {
                    destinationContent(item)
                }
            }
            .opacity(0)
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
    private var deepLinkBinding: Binding<Bool> {
        Binding(
            get: { HakoUtilitiesDeepLink.presented(for: destination) != nil },
            set: { presented in
                guard !presented else { return }
                 
                 
                 
                 
                 
                guard HakoUtilitiesDeepLink.presented(for: destination) != nil
                else { return }
                destination = HakoUtilitiesDeepLink.dismissed
            }
        )
    }

    @ViewBuilder
    private func destinationLink(
        _ item: HakoUtilitiesDestination
    ) -> some View {
        if presentationClass == .regularTouch
            || presentationClass == .desktop
        {
            Button {
                destination = item
            } label: {
                destinationRow(item)
            }
             
             
             
             
             
             
             
             
            .buttonStyle(HakoPushRowButtonStyle())
            .accessibilityIdentifier("utilities.\(item.rawValue)")
        } else {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            NavigationLink {
                HakoLazyView {
                    destinationContent(item)
                }
                 
                 
                 
                 
                 
                 
                 
                 
                .hakoNativePushBoundary()
            } label: {
                destinationRow(item)
            }
             
             
             
             
             
             
             
             
            .buttonStyle(HakoPushRowButtonStyle())
            .accessibilityIdentifier("utilities.\(item.rawValue)")
        }
    }

    private func destinationRow(
        _ item: HakoUtilitiesDestination
    ) -> some View {
        HakoProductDestinationRow(
            presentation: snapshot.utilities.presentation(for: item),
            symbol: item.symbol,
            tint: item.accent.color,
            presentationClass: presentationClass,
            palette: palette,
            icon: icon
        )
    }
}
