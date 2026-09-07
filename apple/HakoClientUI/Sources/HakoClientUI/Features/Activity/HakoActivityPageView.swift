import SwiftUI

 
 
 
 
 
 
 
 
public enum HakoActivityLens: String, CaseIterable, Hashable, Sendable {
    case connections
    case requests
    case logs

     
     
     
     
     
     
    public var destination: HakoUtilitiesDestination {
        switch self {
        case .connections: .connections
        case .requests: .requests
        case .logs: .logs
        }
    }

    public var title: String { destination.title }

     
     
    var searchPrompt: LocalizedStringKey {
        switch self {
        case .connections, .requests: "Destination, route, or rule"
        case .logs: "Search logs"
        }
    }

     
     
     
     
     
     
     
    public init?(destination: HakoUtilitiesDestination) {
        switch destination {
        case .connections: self = .connections
        case .requests: self = .requests
        case .logs: self = .logs
        default: return nil
        }
    }
}

 
 
 
 
 
 
public enum HakoActivitySearchFieldStyle: Sendable {
     
     
     
     
     
    case phoneBottomBar
     
    case standard
}

 
 
 
 
 
 
 
 
 
 
 
public struct HakoActivityPageView<
    Connections: View,
    Requests: View,
    Logs: View
>: View {
    @Binding private var lens: HakoActivityLens
    private let palette: HakoProductPalette
    private let searchFieldStyle: HakoActivitySearchFieldStyle
    private let connections: (String, Bool) -> Connections
    private let requests: (String, Bool) -> Requests
    private let logs: (String, Bool) -> Logs

     
     
     
     
     
     
     
     
     
     
    @State private var query = ""


    @Environment(\.locale) private var locale

     
     
     
     
     
     
     
     
     
     
     
     
     
    @State private var options:
        [HakoFullWidthSegmentedOption<HakoActivityLens>] = []

    public init(
        lens: Binding<HakoActivityLens>,
        palette: HakoProductPalette,
        searchFieldStyle: HakoActivitySearchFieldStyle = .standard,
        @ViewBuilder connections: @escaping (String, Bool) -> Connections,
        @ViewBuilder requests: @escaping (String, Bool) -> Requests,
        @ViewBuilder logs: @escaping (String, Bool) -> Logs
    ) {
        _lens = lens
        self.palette = palette
        self.searchFieldStyle = searchFieldStyle
        self.connections = connections
        self.requests = requests
        self.logs = logs
    }

    public var body: some View {
        searchField(
            lensContent
                .hakoPinnedTopBar { strip }
        )
            .task(id: locale) { options = Self.options(in: locale) }
             
             
             
             
             
            .hakoRootHeading("Activity", watchAs: "activity.\(lens.rawValue)")
         
         
         
         
         
         
         
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private var lensContent: some View {
        switch lens {
        case .connections: connections(query, true)
        case .requests: requests(query, true)
        case .logs: logs(query, true)
        }
    }

     
     
     
     
     
     
     
    @ViewBuilder
    private func searchField<Content: View>(_ content: Content) -> some View {
        switch searchFieldStyle {
        case .phoneBottomBar:
            #if os(iOS)
            if #available(iOS 26, *) {
                content
                    .searchable(
                        text: $query, placement: .toolbar,
                        prompt: lens.searchPrompt
                    )
                    .searchToolbarBehavior(.minimize)
            } else {
                content.searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: lens.searchPrompt
                )
            }
            #else
            content.searchable(text: $query, prompt: lens.searchPrompt)
            #endif
        case .standard:
            content.searchable(text: $query, prompt: lens.searchPrompt)
        }
    }

     
     
     
     
    private var strip: some View {
        HakoFullWidthSegmentedPicker(
            selection: $lens,
            options: options,
            role: .pageStrip,
            underlineSeparator: palette.separator
        )
         
         
         
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HakoTheme.Spacing.standard)
    }

     
     
     
     
    private static func options(
        in locale: Locale
    ) -> [HakoFullWidthSegmentedOption<HakoActivityLens>] {
        HakoActivityLens.allCases.map { candidate in
            HakoFullWidthSegmentedOption(
                selection: candidate,
                title: HakoCopy.string(candidate.title, locale: locale),
                accessibilityIdentifier:
                    "activity.lens.\(candidate.rawValue)"
            )
        }
    }
}


 
 
 
 
 
 
 
private struct HakoActivityLensToolbar<Items: ToolbarContent>: ViewModifier {
    let active: Bool
    let items: () -> Items

    func body(content: Content) -> some View {
        if #available(iOS 16, macOS 13, tvOS 16, *) {
            content.hakoToolbarUnlessInPanel { if active { items() } }
        } else {
            content.hakoToolbarUnlessInPanel { items() }
        }
    }
}

extension View {
    func hakoActivityLensToolbar<Items: ToolbarContent>(
        active: Bool,
        @ToolbarContentBuilder _ items: @escaping () -> Items
    ) -> some View {
        modifier(HakoActivityLensToolbar(active: active, items: items))
    }
}
