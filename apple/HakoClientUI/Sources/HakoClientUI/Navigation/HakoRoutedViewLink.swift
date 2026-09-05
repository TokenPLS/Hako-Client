import SwiftUI

 
 
 
 
 
 
 
 
 
 
public struct HakoViewRoute: Hashable {
    public let id: UUID
    public init(id: UUID) { self.id = id }
}

 
public enum HakoRouteOwnership: Sendable {
     
     
     
     
     
     
    case rowOwned
     
     
     
    case oneShot
}

@MainActor
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public extension View {
    func hakoNativePushBoundary() -> some View {
        modifier(HakoNativePushBoundaryModifier())
    }
}

private struct HakoNativePushBoundaryModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(macOS)
        content
#else
        content
            .environment(\.hakoPushRoute, nil)
             
             
             
             
             
             
             
             
             
             
             
             
             
            .environment(\.hakoPopRoute, nil)
             
             
             
             
             
            .environment(\.hakoIsPushedPage, true)
             
             
             
             
             
            .onAppear {
                HakoPushClock.arrived()
            }

#endif
    }
}

public enum HakoViewRouteRegistry {
    private struct Entry {
        let builder: () -> AnyView
        let onReturn: () -> Void
        let ownership: HakoRouteOwnership
         
         
         
         
         
         
         
         
        var built: AnyView?
    }

    nonisolated(unsafe) private static var entries: [UUID: Entry] = [:]

    public static func set(
        _ id: UUID,
        ownership: HakoRouteOwnership = .oneShot,
        onReturn: @escaping () -> Void,
        _ builder: @escaping () -> AnyView
    ) {
         
         
         
         
        var entry = Entry(
            builder: builder, onReturn: onReturn, ownership: ownership
        )
        entry.built = entries[id]?.built
        entries[id] = entry
    }

    public static func view(for route: HakoViewRoute) -> AnyView {
        guard var entry = entries[route.id] else {
            return AnyView(EmptyView())
        }
        if let built = entry.built {
            return built
        }
        let built = entry.builder()
        entry.built = built
        entries[route.id] = entry
        return built
    }

    public static func returnFrom(_ route: HakoViewRoute) {
         
         
         
         
         
         
         
        guard var entry = entries[route.id], entry.built != nil else { return }
        entry.built = nil

        switch entry.ownership {
        case .rowOwned:
             
             
             
             
             
             
             
             
            entries[route.id] = entry
        case .oneShot:
             
             
             
             
            entries.removeValue(forKey: route.id)
        }
        entry.onReturn()
    }

     
    public static func discard(_ route: HakoViewRoute) {
        entries.removeValue(forKey: route.id)
    }

     
     
     
     
     
     
    public static func discardAll() {
        entries.removeAll()
    }
}

private struct HakoListRetainsRowSelectionKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    var hakoListRetainsRowSelection: Bool {
        get { self[HakoListRetainsRowSelectionKey.self] }
        set { self[HakoListRetainsRowSelectionKey.self] = newValue }
    }
}

public extension View {
     
     
     
     
    func hakoListRetainsRowSelection() -> some View {
        environment(\.hakoListRetainsRowSelection, true)
    }
}

public struct HakoRoutedViewLink<Destination: View, Label: View>: View {
    private let onNavigate: () -> Void
    private let onReturn: () -> Void
    private let showsDisclosureIndicator: Bool
    private let destination: () -> Destination
    private let label: Label
     
     
     
     
     
    @State private var token = UUID()
    @Environment(\.hakoPushRoute) private var pushRoute
    @Environment(\.hakoInsideModalPresentation) private var insideModal
    @Environment(\.hakoNavigationHostContext) private var hostContext
    @Environment(\.hakoHostedInRootPool) private var hostedInRootPool
    @Environment(\.hakoListRetainsRowSelection)
    private var listRetainsRowSelection
#if os(macOS)
    @State private var awaitsNativeReturn = false
#endif

    public init(
        onNavigate: @escaping () -> Void = {},
        onReturn: @escaping () -> Void = {},
        showsDisclosureIndicator: Bool = true,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.onNavigate = onNavigate
        self.onReturn = onReturn
        self.showsDisclosureIndicator = showsDisclosureIndicator
        self.destination = destination
        self.label = label()
    }

    private func trace(_ branch: String) {
        guard ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1"
        else { return }
        FileHandle.standardError.write(
"[nav] link branch=\(branch) push=\(pushRoute != nil) insideModal=\(insideModal) host=\(hostContext) pool=\(hostedInRootPool)\n"
                .data(using: .utf8)!
        )
    }

    public var body: some View {
#if os(macOS)
        let _ = trace(
            pushRoute == nil
                ? "none"
                : (hostedInRootPool || insideModal || listRetainsRowSelection
                    ? "programmatic" : "value-link")
        )
         
         
         
         
         
         
         
         
         
         
         
         
         
        if let pushRoute,
           hostedInRootPool || insideModal || listRetainsRowSelection
        {
             
             
             
             
             
            Button {
                let destination = destination
                HakoViewRouteRegistry.set(
                    token,
                    ownership: .rowOwned,
                    onReturn: onReturn
                ) {
                    AnyView(destination())
                }
                HakoNavigationTransaction.resignCurrentField()
                onNavigate()
                pushRoute(HakoViewRoute(id: token))
            } label: {
                HStack(spacing: HakoTheme.Spacing.compact) {
                    label
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 0,
                            alignment: .leading
                        )
                     
                     
                     
                     
                     
                    if showsDisclosureIndicator {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(HakoPushRowButtonStyle())
        } else if let pushRoute,
           !insideModal || hostContext == .modal
        {
             
             
             
             
             
             
             
            let _ = {
                let destination = destination
                HakoViewRouteRegistry.set(
                    token,
                    ownership: .rowOwned,
                    onReturn: onReturn
                ) {
                    AnyView(destination())
                }
            }()
            NavigationLink(value: HakoViewRoute(id: token)) {
                label
                    .frame(
                        maxWidth: .infinity,
                         
                         
                         
                         
                        minHeight: insideModal
                            && !HakoPlatformLayout.pageUsesSystemSettingsIdiom
                            ? HakoTheme.Control.fullWidthRowMinHeight
                            : 0,
                        alignment: .leading
                    )
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    HakoNavigationTransaction.resignCurrentField()
                    onNavigate()
                }
            )
        } else {
            NavigationLink {
                HakoNativeRoutedDestination(
                    awaitsReturn: $awaitsNativeReturn,
                    onReturn: onReturn
                ) {
                    HakoLazyView(destination)
                }
            } label: {
                label
                    .frame(
                        maxWidth: .infinity,
                        minHeight: HakoTheme.Control.fullWidthRowMinHeight,
                        alignment: .leading
                    )
                    .contentShape(Rectangle())
            }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        HakoNavigationTransaction.resignCurrentField()
                        onNavigate()
                        awaitsNativeReturn = true
                    }
                )
                 
                 
                 
                 
                 
                 
                .onAppear {
                    guard awaitsNativeReturn else { return }
                    awaitsNativeReturn = false
                    onReturn()
                }
        }
#else
         
         
         
         
        if HakoPlatformLayout.regularShellKeepsContainer,
           let pushRoute,
            
            
            
            
            
            
            
            
            
            
            
            
            
            
            
           !insideModal
        {
            programmaticRow(pushRoute)
        } else {
            NavigationLink {
                HakoLazyView(destination)
                 
                 
                 
                 
                 
                 
                 
                 
                .hakoNativePushBoundary()
            } label: {
                label
            }
        }
#endif
    }

     
     
    private func programmaticRow(_ pushRoute: HakoRoutePusher) -> some View {
        Button {
             
            HakoPushClock.tap()
            let destination = destination
            HakoViewRouteRegistry.set(
                token,
                ownership: .rowOwned,
                onReturn: onReturn
            ) {
                AnyView(destination())
            }
            HakoNavigationTransaction.resignCurrentField()
            onNavigate()
            pushRoute(HakoViewRoute(id: token))
        } label: {
            HStack(spacing: HakoTheme.Spacing.compact) {
                label
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 0,
                        alignment: .leading
                    )
                if showsDisclosureIndicator {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HakoPushRowButtonStyle())
    }

}

 
 
 
 
 
 
 
public struct HakoRoutedViewDestination<Destination: View>: View {
    @Binding private var isPresented: Bool
    private let destination: () -> Destination
     
     
    @State private var token = UUID()

    @Environment(\.hakoPushRoute) private var pushRoute
    @Environment(\.hakoInsideModalPresentation) private var insideModal
    @Environment(\.hakoNavigationHostContext) private var hostContext
#if os(macOS)
    @State private var routeIsPresented = false
#endif

    public init(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination
    ) {
        _isPresented = isPresented
        self.destination = destination
    }

    @ViewBuilder
    public var body: some View {
#if os(macOS)
        if pushRoute != nil,
           !insideModal || hostContext == .modal
        {
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .onAppear(perform: presentRouteIfNeeded)
                .onChange(of: isPresented) { _ in
                    presentRouteIfNeeded()
                }
        } else {
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .onChange(of: isPresented) { shown in
                    if shown {
                        assertionFailure(
                            "HakoRoutedViewDestination requires a value-route host on macOS"
                        )
                    }
                }
        }
#else
        NavigationLink(isActive: $isPresented) {
            HakoLazyView(destination)
        } label: {
            EmptyView()
        }
#endif
    }

#if os(macOS)
    @MainActor
    private func presentRouteIfNeeded() {
        guard isPresented, !routeIsPresented, let pushRoute else { return }
        HakoNavigationTransaction.resignCurrentField()
        routeIsPresented = true
        let presented = _isPresented
        let routed = _routeIsPresented
        let destination = destination
        HakoViewRouteRegistry.set(
            token,
            onReturn: {
                routed.wrappedValue = false
                presented.wrappedValue = false
            }
        ) {
            AnyView(destination())
        }
        pushRoute(HakoViewRoute(id: token))
    }
#endif
}

#if os(macOS)
 
 
 
 
 
 
 
private struct HakoNativeRoutedDestination<Content: View>: View {
    @Binding var awaitsReturn: Bool
    let onReturn: () -> Void
    let content: Content
    @Environment(\.dismiss) private var dismiss

    init(
        awaitsReturn: Binding<Bool>,
        onReturn: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        _awaitsReturn = awaitsReturn
        self.onReturn = onReturn
        self.content = content()
    }

    var body: some View {
        content.environment(
            \.hakoPopRoute,
            HakoRoutePusher { _ in
                awaitsReturn = false
                dismiss()
                DispatchQueue.main.async {
                    onReturn()
                }
            }
        )
    }
}
#endif

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoPushRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
#if os(macOS)
        let forced: Bool = {

            false

        }()
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        configuration.isPressed || forced
                            ? AnyShapeStyle(Color.primary.opacity(0.05))
                            : AnyShapeStyle(.clear)
                    )
                    .padding(.horizontal, -HakoTheme.Spacing.cardGap)
                    .padding(.vertical, -HakoTheme.Spacing.row)
            )
#else
        configuration.label
#endif
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
@MainActor
public enum HakoPushedPageExit {
     
     
     
     
    public static func leave(
        popRoute: HakoRoutePusher?,
        dismiss: HakoDismissHandle
    ) {
         
         
         
         
         
         
         
         
         
         
        if let popRoute {
            popRoute(HakoPopToken())
        } else {
            dismiss()
        }
    }
}
