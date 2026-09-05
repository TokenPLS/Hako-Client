import SwiftUI

 
 
 
 
 
public struct HakoMoreView<Icon: View, DestinationContent: View>: View {
    private let snapshot: AppleClientSnapshot
    @Binding private var destination: HakoMoreDestination
    private let presentationClass: HakoPresentationClass
    private let palette: HakoProductPalette
    private let icon: (HakoSymbol) -> Icon
    private let destinationContent:
        (HakoMoreDestination) -> DestinationContent
    private let omitting: Set<HakoMoreDestination>
     
     
    private let attentionAction: (String) -> Void

    public init(
        snapshot: AppleClientSnapshot,
        destination: Binding<HakoMoreDestination>,
        presentationClass: HakoPresentationClass,
        palette: HakoProductPalette,
        omitting: Set<HakoMoreDestination> = [],
        attentionAction: @escaping (String) -> Void = { _ in },
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        @ViewBuilder destinationContent: @escaping (
            HakoMoreDestination
        ) -> DestinationContent
    ) {
        self.snapshot = snapshot
        _destination = destination
        self.presentationClass = presentationClass
        self.palette = palette
        self.omitting = omitting
        self.attentionAction = attentionAction
        self.icon = icon
        self.destinationContent = destinationContent
    }

     
     
    private var visibleSections: [HakoMoreSectionDescriptor] {
        HakoMoreCatalog.sections.compactMap { section in
            let remaining = section.destinations.filter {
                !omitting.contains($0)
            }
            guard !remaining.isEmpty else {
                return nil
            }
            return HakoMoreSectionDescriptor(
                id: section.id,
                destinations: remaining
            )
        }
    }

    public var body: some View {
        HakoProductRootPage(
            palette: palette,
            accessibilityIdentifier: "more.root"
        ) {
            if let attention = snapshot.more.attention {
                attentionSection(attention)
            }
            ForEach(visibleSections, id: \.id) { section in
                productSection(
                    title: section.id.title,
                    identifier: "more.section.\(section.id.title)",
                    destinations: section.destinations
                )
            }

            if snapshot.more.showsDeveloperDestination {
                productSection(
                    title: "Development",
                    identifier: "more.section.Development",
                    destinations: [.developer]
                )
            }
        }
    }


     
     
     
     
    private func attentionSection(_ attention: HakoMoreAttention) -> some View {
        HakoProductPageSection(
            title: "Needs Attention",
            palette: palette,
            presentationClass: presentationClass
        ) {
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
                HStack(alignment: .top, spacing: HakoTheme.Spacing.compact) {
                    icon(attention.emphasised ? .exclamationmarkTriangle : .infoCircle)
                    Text(hako: attention.message)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: HakoTheme.Spacing.row) {
                    ForEach(attention.actions) { action in
                        Button(role: action.destructive ? .destructive : nil) {
                            attentionAction(action.id)
                        } label: {
                            Text(hako: action.title)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("more.legacy-settings-action.\(action.id)")
                    }
                }
            }
            .padding(.vertical, HakoTheme.Spacing.tight)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("more.legacy-settings")
        }
    }

    private func productSection(
        title: String,
        identifier: String,
        destinations: [HakoMoreDestination]
    ) -> some View {
        HakoProductPageSection(
            title: title,
            palette: palette,
            presentationClass: presentationClass
        ) {
            ForEach(destinations, id: \.self) { item in
                destinationLink(item)

                 
                 
                 
                if item != destinations.last,
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
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private func destinationLink(
        _ item: HakoMoreDestination
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
            .accessibilityIdentifier("more.\(item.rawValue)")
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
            .accessibilityIdentifier("more.\(item.rawValue)")
        }
    }

    private func destinationRow(
        _ item: HakoMoreDestination
    ) -> some View {
        HakoProductDestinationRow(
            presentation: snapshot.more.presentation(for: item),
            symbol: item.symbol,
            tint: item.accent.color,
            presentationClass: presentationClass,
            palette: palette,
            icon: icon
        )
    }
}
