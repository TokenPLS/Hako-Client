import SwiftUI

#if os(macOS)
 
 
 
 
 
private struct HakoRegularDetailNavigationLayout: Layout {
    let maximumContentWidth: CGFloat
    let horizontalInset: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let subview = subviews.first else {
            return CGSize(
                width: proposal.width ?? 0,
                height: proposal.height ?? 0
            )
        }
         
         
         
         
         
         
         
        if let width = proposal.width, let height = proposal.height {
            return CGSize(width: width, height: height)
        }
        let measured = subview.sizeThatFits(proposal)
        return CGSize(
            width: proposal.width ?? measured.width,
            height: proposal.height ?? measured.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let subview = subviews.first else { return }

        let availableWidth = max(
            0,
            bounds.width - (horizontalInset * 2)
        )
        let contentWidth = min(
            maximumContentWidth,
            availableWidth
        )
        subview.place(
            at: CGPoint(
                x: bounds.midX - (contentWidth / 2),
                y: bounds.minY
            ),
            anchor: .topLeading,
            proposal: ProposedViewSize(
                width: contentWidth,
                height: bounds.height
            )
        )
    }
}
#endif

 
 
 
 
 
 
public extension View {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func hakoRegularContentEnvelope() -> some View {
        accessibilityElement(children: .contain)
            .accessibilityIdentifier(HakoRegularContentEnvelope.identifier)
    }
}

 
 
public enum HakoRegularContentEnvelope {
    public static let identifier = "regular.content.envelope"
}

 
 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoInsideDetailPageLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var hakoInsideDetailPageLayout: Bool {
        get { self[HakoInsideDetailPageLayoutKey.self] }
        set { self[HakoInsideDetailPageLayoutKey.self] = newValue }
    }
}

 
 
 
 
 
 
public struct HakoSetterRoutedBack: ViewModifier {
    @Environment(\.hakoPopRoute) private var popRoute
    @Environment(\.hakoNavigationDepth) private var depth
     
     
     
    @Environment(\.hakoRootDepartureGuard) private var departureGuard

    public init() {}

     
     
     
     
     
    private var canGoBack: Bool {
        guard popRoute != nil || HakoNavigationHooks.pop != nil else {
            return false
        }
         
         
        guard let depth else { return true }
        return depth > 0
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
#if os(macOS)
        if canGoBack {
            content
                .navigationBarBackButtonHidden(true)
                 
                 
                 
                 
                 
                .hakoToolbarUnlessInPanel {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            HakoNavigationTransaction.resignCurrentField()
                            let leave: () -> Void = {
                                if let popRoute {
                                    popRoute(HakoPopToken())
                                } else {
                                    HakoNavigationHooks.pop?()
                                }
                            }
                             
                             
                             
                             
                             
                            HakoDeparture.request(departureGuard, leave: leave)
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                         
                         
                        .accessibilityIdentifier("chevron.backward")
                        .accessibilityLabel(Text(HakoCopy.key("Back")))
                    }
                }
        } else {
            content
        }
#else
        content
#endif
    }
}

 
public struct HakoPopToken: Hashable {
    public init() {}
}

public extension View {
     
     
     
     
     
     
    @ViewBuilder
    func hakoRegularStackCanvas(_ canvas: Color) -> some View {
#if os(macOS)
        environment(\.hakoDetailCanvas, canvas)
#else
        self
#endif
    }
}

 
 
 
 
public enum HakoRegularDetailCanvasFallback {
    nonisolated(unsafe) public static var color: Color?
}

public struct HakoRegularDetailNavigationFrame<Content: View>: View {
    private let background: Color
    private let content: Content

    public init(
        background: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.content = content()
    }

    public var body: some View {
        contentColumn
            .hakoRegularContentEnvelope()
            .environment(\.hakoInsideDetailPageLayout, true)
            .background(background.ignoresSafeArea())
            .environment(
                \.defaultMinListRowHeight,
                HakoTheme.Regular.Detail.destinationRowMinHeight
            )
            .environment(\.hakoDetailCanvas, background)
            .modifier(HakoRegularDetailSurfacePolicy())
            .modifier(HakoRegularDetailTitleScale())
    }

    @ViewBuilder
    private var contentColumn: some View {
#if os(macOS)
        HakoRegularDetailNavigationLayout(
            maximumContentWidth: HakoTheme.Regular.Detail.maximumContentWidth,
            horizontalInset: HakoTheme.Regular.Detail.horizontalInset
        ) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
#else
        content
             
             
             
             
             
             
            .frame(
                maxWidth: HakoTheme.Regular.Detail.maximumContentWidth,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(
                .horizontal,
                HakoTheme.Regular.Detail.horizontalInset
            )
#endif
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoRegularDetailTitleScale: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 17.0, *) {
            content.toolbarTitleDisplayMode(.inline)
        } else {
            content.navigationBarTitleDisplayMode(.inline)
        }
#else
        content
#endif
    }
}

 
 
public struct HakoRegularDetailPageLayout<Content: View>: View {
    @Environment(\.hakoInsideDetailPageLayout) private var alreadyPlaced

    private let background: Color
    private let maximumContentWidth: CGFloat
    private let content: Content

    public init(
        background: Color,
        maximumContentWidth: CGFloat = HakoTheme.Regular.Detail.maximumContentWidth,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.maximumContentWidth = maximumContentWidth
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
        if alreadyPlaced {
             
             
             
            content
        } else {
            pageLayout
                .hakoRegularContentEnvelope()
                .environment(\.hakoInsideDetailPageLayout, true)
        }
    }

     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private var contentColumn: some View {
        content
            .frame(
                maxWidth: maximumContentWidth,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
            .padding(
                .horizontal,
                HakoTheme.Regular.Detail.horizontalInset
            )
    }

    private var pageLayout: some View {
        ZStack {
            background.ignoresSafeArea()

            contentColumn
        }
        .environment(
            \.defaultMinListRowHeight,
            HakoTheme.Regular.Detail.destinationRowMinHeight
        )
        .environment(\.hakoDetailCanvas, background)
        .modifier(HakoRegularDetailSurfacePolicy())
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoRegularDetailSurfacePolicy: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        content
            .formStyle(.grouped)
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
#else
        content
#endif
    }
}

 
 
 
 
 
 
 
private struct HakoDetailCanvasKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

public extension EnvironmentValues {
    var hakoDetailCanvas: Color? {
        get { self[HakoDetailCanvasKey.self] }
        set { self[HakoDetailCanvasKey.self] = newValue }
    }
}

public extension View {
     
     
     
     
     
     
     
     
     
    func hakoPushedDetailPage() -> some View {
        modifier(HakoPushedDetailPageModifier())
    }
}

private struct HakoPushedDetailPageModifier: ViewModifier {
#if os(macOS)
    private var isRegular: Bool { true }
    private var fallbackCanvas: Color {
         
         
         
         
         
         
         
         
         
         
        HakoRegularDetailCanvasFallback.color
            ?? Color(nsColor: .underPageBackgroundColor)
    }
#elseif os(tvOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isRegular: Bool { horizontalSizeClass == .regular }
    private var fallbackCanvas: Color {
        Color(uiColor: .black)
    }
#else
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isRegular: Bool { horizontalSizeClass == .regular }
    private var fallbackCanvas: Color {
        Color(uiColor: .systemGroupedBackground)
    }
#endif
    @Environment(\.hakoDetailCanvas) private var canvas
    @Environment(\.hakoInsideModalPresentation)
    private var insideNativeModal
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
#if os(macOS)
    @Environment(\.hakoNavigationDepth) private var inheritedDepth
#endif

    func body(content: Content) -> some View {
        Group {
#if os(macOS)
        if insideProductModal || insideNativeModal {
             
             
             
             
             
            content
        } else {
            HakoRegularDetailPageLayout(background: canvas ?? fallbackCanvas) {
                content
            }
             
             
             
             
             
            .navigationBarBackButtonHidden(true)
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            .environment(\.hakoNavigationDepth, (inheritedDepth ?? 0) + 1)
        }
#else
        if isRegular {
            HakoRegularDetailPageLayout(background: canvas ?? fallbackCanvas) {
                content
            }
        } else {
            content
        }
#endif
        }
         
         
        .onAppear { HakoPushClock.arrived() }
    }
}
