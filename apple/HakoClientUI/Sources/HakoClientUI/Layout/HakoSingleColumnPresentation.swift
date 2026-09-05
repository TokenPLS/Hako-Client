import SwiftUI

 
 
 
 
 
 
 
 
public enum HakoModalPresentationRole: Sendable {
    case page
    case form
    case fitted
}

 
 
 
 
 
 
enum HakoNavigationHostContext: Sendable {
    case standalone
    case regularDetail
    case modal
}

private struct HakoNavigationHostContextKey: EnvironmentKey {
    static let defaultValue = HakoNavigationHostContext.standalone
}

extension EnvironmentValues {
    var hakoNavigationHostContext: HakoNavigationHostContext {
        get { self[HakoNavigationHostContextKey.self] }
        set { self[HakoNavigationHostContextKey.self] = newValue }
    }
}

 
 
 
 
 
 
enum HakoSingleColumnNavigationPolicy {
    static func buildsHost(
        ownsNavigationContainer: Bool,
        hostContext: HakoNavigationHostContext,
        isPushedPage: Bool = false
    ) -> Bool {
        guard ownsNavigationContainer else { return false }
         
         
         
         
         
         
         
         
         
        if isPushedPage { return false }
        switch hostContext {
        case .standalone:
            return true
        case .regularDetail, .modal:
            return false
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoIsPushedPageKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var hakoIsPushedPage: Bool {
        get { self[HakoIsPushedPageKey.self] }
        set { self[HakoIsPushedPageKey.self] = newValue }
    }
}

struct HakoNavigationDepthKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var hakoNavigationDepth: Int? {
        get { self[HakoNavigationDepthKey.self] }
        set { self[HakoNavigationDepthKey.self] = newValue }
    }
}

 
 
 
 
 
 
 
public struct HakoSingleColumnNavigationContainer<Content: View>: View {
    private let ownsNavigationContainer: Bool
    private let content: Content
    @Environment(\.hakoNavigationHostContext) private var hostContext
    @Environment(\.hakoIsPushedPage) private var isPushedPage
    @Environment(\.hakoInsideModalPresentation) private var insideModal

    public init(
        ownsNavigationContainer: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.ownsNavigationContainer = ownsNavigationContainer
        self.content = content()
    }

     
     
    private func trace(_ builds: Bool) {
        guard ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1"
        else { return }
        FileHandle.standardError.write(
            "[nav] container owns=\(ownsNavigationContainer) host=\(hostContext) insideModal=\(insideModal) builds=\(builds)\n"
                .data(using: .utf8)!
        )
    }

    @ViewBuilder
    public var body: some View {
        let buildsHost = HakoSingleColumnNavigationPolicy.buildsHost(
            ownsNavigationContainer: ownsNavigationContainer,
            hostContext: hostContext,
             
             
            isPushedPage: isPushedPage
        )
        let _ = trace(buildsHost)
        if buildsHost {
            if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
                HakoModernSingleColumnNavigationHost(
                    insideModal: insideModal
                ) {
                    content
                }
            } else {
#if os(macOS)
                 
                 
                 
                NavigationView {
                    content
                }
#else
                NavigationView {
                    content
                }
                .navigationViewStyle(.stack)
#endif
            }
        } else {
            content
        }
    }
}

 
 
 
@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private struct HakoModernSingleColumnNavigationHost<Content: View>: View {
    private let insideModal: Bool
    private let content: Content
    @State private var path = NavigationPath()
    @State private var managedRoutes: [HakoViewRoute?] = []
     
     
     
     
     
     
     
    @State private var hostedRoutes: [HakoViewRoute] = []

     
    @State private var pushTokens = HakoRoutePusherTokens()
     
     
    @State private var instanceID = UUID()

#if os(macOS)
     
     
     
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
#endif

    init(
        insideModal: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.insideModal = insideModal
        self.content = content()
    }

    var body: some View {
        let _ = navTrace("body")
        return NavigationStack(path: pathBinding) {
            content.navigationDestination(
                for: HakoViewRoute.self
            ) { route in
                routedDestination(route)
            }
        }
        .environment(
            \.hakoPushRoute,
            HakoRoutePusher(token: pushTokens.push) { value in
                push(value)
            }
        )
        .environment(
            \.hakoPopRoute,
            HakoRoutePusher(token: pushTokens.pop) { _ in pop() }
        )
        .environment(
            \.hakoNavigationHostContext,
            insideModal ? .modal : .standalone
        )
         
        .environment(\.hakoNavigationDepth, 0)
        .onDisappear(perform: discardRoutes)
    }

    private var pathBinding: Binding<NavigationPath> {
        Binding(
            get: { path },
            set: { updated in
                let removedCount = max(0, path.count - updated.count)
                let removed = managedRoutes.suffix(removedCount)
                    .compactMap { $0 }
                if removedCount > 0 {
                    managedRoutes.removeLast(
                        min(removedCount, managedRoutes.count)
                    )
                } else if updated.count > managedRoutes.count {
                    managedRoutes.append(
                        contentsOf: repeatElement(
                            nil,
                            count: updated.count - managedRoutes.count
                        )
                    )
                }
                path = updated
                for route in removed.reversed() {
                    DispatchQueue.main.async {
                        HakoViewRouteRegistry.returnFrom(route)
                    }
                }
            }
        )
    }

    private func navTrace(_ what: String) {
        guard ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1"
        else { return }
        FileHandle.standardError.write(
            "[nav] host \(what) path=\(path.count) inst=\(instanceID.uuidString.prefix(6))\n"
                .data(using: .utf8)!
        )
    }

    private func push(_ value: any Hashable) {
        navTrace("push")
         
         
         
         
         
         
         
        HakoNavigationTransaction.applyPathChange {
            path.append(value)
            managedRoutes.append(value as? HakoViewRoute)
            if let route = value as? HakoViewRoute {
                hostedRoutes.append(route)
            }
        }
    }

    private func pop() {
        var updated = path
        guard !updated.isEmpty else { return }
        updated.removeLast()
        let binding = pathBinding
        HakoNavigationTransaction.applyPathChange {
            binding.wrappedValue = updated
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func adoptSystemPushedRoute(_ route: HakoViewRoute) {
        guard let last = managedRoutes.indices.last else { return }
        guard managedRoutes[last] == nil else { return }
        managedRoutes[last] = route
    }

    private func routedDestination(_ route: HakoViewRoute) -> some View {
        let _ = navTrace("destination")
        return HakoLazyView {
            HakoViewRouteRegistry.view(for: route)
        }
            .onAppear { adoptSystemPushedRoute(route) }
            .hakoPushedDetailPage()
             
             
             
             
             
             
             
            .environment(\.hakoIsPushedPage, true)
            .onAppear { HakoPushClock.arrived() }
            .environment(
                \.hakoPushRoute,
                HakoRoutePusher(token: pushTokens.push) { nested in
                    push(nested)
                }
            )
            .environment(
                \.hakoPopRoute,
                HakoRoutePusher(token: pushTokens.pop) { _ in pop() }
            )
            .environment(
                \.hakoNavigationHostContext,
                insideModal ? .modal : .standalone
            )
            .environment(\.hakoNavigationDepth, path.count)
             
             
            .environment(\.hakoProductChromeApplied, false)
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
#if os(macOS)
            .environment(\.hakoInsideProductModalPresentation, insideProductModal)
#endif
    }

    private func discardRoutes() {
         
         
        for route in hostedRoutes {
            HakoViewRouteRegistry.discard(route)
        }
        for route in managedRoutes.compactMap({ $0 }) {
            HakoViewRouteRegistry.discard(route)
        }
        hostedRoutes.removeAll()
    }
}

public extension View {
     
     
     
     
     
    func hakoModalPresentation(
        _ role: HakoModalPresentationRole
    ) -> some View {
        modifier(HakoModalSizingPolicy(role: role))
            .modifier(HakoModalSurfacePolicy())
             
             
             
             
            .environment(\.hakoNavigationHostContext, .standalone)
             
             
            .environment(\.hakoIsPushedPage, false)
             
             
             
             
             
            .environment(\.hakoInsideModalPresentation, true)
             
             
             
             
            .environment(\.hakoProductChromeApplied, false)
    }
}

private struct HakoInsideModalPresentationKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
     
    var hakoInsideModalPresentation: Bool {
        get { self[HakoInsideModalPresentationKey.self] }
        set { self[HakoInsideModalPresentationKey.self] = newValue }
    }
}

private struct HakoModalSizingPolicy: ViewModifier {
    let role: HakoModalPresentationRole

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
            switch role {
            case .page:
                content.presentationSizing(.page)
            case .form:
                content.presentationSizing(.form)
            case .fitted:
                content.presentationSizing(.fitted)
            }
        } else {
            content
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
private struct HakoModalSurfacePolicy: ViewModifier {
    @Environment(\.hakoDetailCanvas) private var inheritedCanvas

    private var canvas: Color {
        inheritedCanvas ?? fallbackCanvas
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
         
         
         
         
         
         
         
         
         
         
         
        content
            .formStyle(.grouped)
            .listStyle(.inset)
#else
        if #available(iOS 18.0, tvOS 18.0, *) {
            content
                .environment(\.hakoDetailCanvas, canvas)
                .presentationBackground(canvas)
        } else {
            content
                .environment(\.hakoDetailCanvas, canvas)
        }
#endif
    }

    private var fallbackCanvas: Color {
#if os(macOS)
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? .black
                    : .windowBackgroundColor
            }
        )
#elseif os(tvOS)
        Color(uiColor: .black)
#else
        Color(uiColor: .systemGroupedBackground)
#endif
    }
}

public extension View {
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoWindowContainerBackground(_ color: Color) -> some View {
#if os(macOS)
        if #available(macOS 15.0, *) {
            self.containerBackground(color, for: .window)
        } else {
            background(color.ignoresSafeArea())
        }
#else
        self
#endif
    }
}
