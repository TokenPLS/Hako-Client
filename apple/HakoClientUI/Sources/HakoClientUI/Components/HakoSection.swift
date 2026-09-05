import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoSection<Content: View, Footer: View>: View {
    private let title: String
    private let content: Content
    private let footer: Footer

    public init(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) where Footer == EmptyView {
        self.title = title
        self.content = content()
        self.footer = EmptyView()
    }

     
     
     
     
     
    public init(
        _ title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }

#if os(macOS)
    @Environment(\.hakoMacSectionCard) private var macSectionCard
#endif

    public var body: some View {
#if os(macOS)
        if let card = macSectionCard {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
                if !title.isEmpty {
                    HakoSectionTitle(title: title)
                }
                HakoCardSurface(
                    fill: card.fill,
                    separator: card.separator,
                    paintsInSettingsIdiom: true
                ) {
                     
                     
                     
                     
                     
                     
                    VStack(spacing: HakoTheme.Spacing.row) {
                        content
                    }
                    .padding(HakoTheme.Spacing.cardGap)
                }
                footer
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Section {
                content
            } header: {
                 
                 
                 
                if !title.isEmpty {
                    HakoSectionTitle(title: title)
                }
            } footer: {
                footer
            }
        }
#else
        Section {
            content
        } header: {
            Text(HakoCopy.key(title))
        } footer: {
            footer
        }
#endif
    }
}

#if os(macOS)
 
 
 
 
 
 
 
 
public struct HakoMacSectionCardStyle: Sendable {
    public let fill: Color
    public let separator: Color

    public init(fill: Color, separator: Color) {
        self.fill = fill
        self.separator = separator
    }
}

private struct HakoMacSectionCardKey: EnvironmentKey {
    static let defaultValue: HakoMacSectionCardStyle? = nil
}

extension EnvironmentValues {
    public var hakoMacSectionCard: HakoMacSectionCardStyle? {
        get { self[HakoMacSectionCardKey.self] }
        set { self[HakoMacSectionCardKey.self] = newValue }
    }
}

 
 
 
 
 
 
 
 
 
private struct HakoSectionTitle: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
             
             
             
             
            Text(HakoCopy.key(title))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                 
                 
                .textCase(nil)
        }
        .padding(.top, HakoTheme.Spacing.compact)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
