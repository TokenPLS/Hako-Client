import SwiftUI
import os.log
import os

 
 
 
 
 
 
 
 
@MainActor
public final class HakoModalCenter: ObservableObject {
    public static let shared = HakoModalCenter()

    public struct Entry: Identifiable {
        public let id: UUID
        let role: HakoModalPresentationRole
        let content: AnyView
        let onDismiss: (() -> Void)?
        let contentRevision: Int

        init(
            id: UUID = UUID(),
            role: HakoModalPresentationRole,
            content: AnyView,
            onDismiss: (() -> Void)?,
            contentRevision: Int = 0
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.onDismiss = onDismiss
            self.contentRevision = contentRevision
        }
    }

    @Published var stack: [Entry] = []

     
     
     
     
     
     
    public var isPresenting: Bool {
        !stack.isEmpty
    }

    public func present(
        role: HakoModalPresentationRole,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> some View
    ) -> UUID {
        let entry = Entry(
            role: role,
            content: AnyView(content()),
            onDismiss: onDismiss
        )
        stack.append(entry)
        return entry.id
    }

     
     
     
     
    public func update(
        _ id: UUID,
        @ViewBuilder content: () -> some View
    ) {
        guard let index = stack.firstIndex(where: { $0.id == id }) else {
            return
        }
        let entry = stack[index]
        if ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1" {
            FileHandle.standardError.write(
                "[nav] centre update rev=\(entry.contentRevision + 1)\n"
                    .data(using: .utf8)!
            )
        }
        stack[index] = Entry(
            id: entry.id,
            role: entry.role,
            content: AnyView(content()),
            onDismiss: entry.onDismiss,
            contentRevision: entry.contentRevision + 1
        )
    }

    public func dismiss(_ id: UUID) {
        if let index = stack.firstIndex(where: { $0.id == id }) {
             
             
             
            let removed = Array(stack[index...])
            stack.removeSubrange(index...)
            for entry in removed {
                parkedOrphans.removeValue(forKey: entry.id)
            }
            for entry in removed.reversed() {
                entry.onDismiss?()
            }
        }
    }

    func dismissTop() {
        if let entry = stack.popLast() {
            parkedOrphans.removeValue(forKey: entry.id)
            entry.onDismiss?()
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var parkedOrphans: [UUID: String] = [:]

    func parkOrphan(_ id: UUID, claimKey: String) {
        guard stack.contains(where: { $0.id == id }) else { return }
        parkedOrphans[id] = claimKey
        if ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1" {
            FileHandle.standardError.write(
                "[nav] centre park key=\(claimKey)\n".data(using: .utf8)!
            )
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.parkedOrphans.removeValue(forKey: id) != nil else {
                return
            }
            if ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1" {
                FileHandle.standardError.write(
                    "[nav] centre sweep unclaimed key=\(claimKey)\n".data(using: .utf8)!
                )
            }
            self.dismiss(id)
        }
    }

    func claimOrphan(claimKey: String) -> UUID? {
        guard let id = parkedOrphans.first(where: { $0.value == claimKey })?.key else {
            return nil
        }
        parkedOrphans.removeValue(forKey: id)
        if ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1" {
            FileHandle.standardError.write(
                "[nav] centre claim key=\(claimKey)\n".data(using: .utf8)!
            )
        }
        return id
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func requestDismissTop(_ departureGuard: HakoRootDepartureGuard?) {
        HakoDeparture.request(departureGuard) { [weak self] in self?.dismissTop() }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoWindowToolbarHiddenWhilePanelUp: ViewModifier {
    @ObservedObject private var center = HakoModalCenter.shared

    public init() {}

    public func body(content: Content) -> some View {
#if os(macOS)
        content.toolbar(
            center.isPresenting ? .hidden : .automatic,
            for: .windowToolbar
        )
#else
        content
#endif
    }
}

enum HakoProductModalLayerMetrics {
     
     
    static var legacyTopInset: CGFloat {
        if #available(macOS 15.0, *) {
            return 0
        } else {
            return 28
        }
    }
}

 
public struct HakoProductModalLayer: View {
    @ObservedObject private var center = HakoModalCenter.shared

    public init() {}

    public var body: some View {
#if os(macOS)
        ZStack {
            if !center.stack.isEmpty {
                Color.black.opacity(
                    HakoTheme.MacOS.ProductModal.dimmingOpacity
                )
                    .ignoresSafeArea()

                 
                 
                 
                 
                 
                 
                 
                 
                ForEach(
                    Array(center.stack.enumerated()),
                    id: \.element.id
                ) { index, entry in
                    let isTop = index == center.stack.index(before: center.stack.endIndex)
                    HakoProductModalPanel(role: entry.role) {
                        entry.content
                            .id(entry.contentRevision)
                             
                             
                             
                             
                            .hakoPageProbe("panel")
                    }
                     
                     
                     
                     
                     
                     
                     
                    .padding(.top, HakoProductModalLayerMetrics.legacyTopInset)
                     
                     
                     
                     
                     
                     
                    .offset(x: isTop ? 0 : -100_000)
                    .animation(nil, value: isTop)
                    .allowsHitTesting(isTop)
                    .accessibilityHidden(!isTop)
                    .zIndex(Double(index))
                }
            }
        }
         
         
         
         
         
         
         
         
         
#else
        EmptyView()
#endif
    }
}

#if os(macOS)
 
 
 
 
 
 
 
 
 
private enum HakoProductModalSurface {
     
     
     
     
    static var canvas: Color {
        Color(nsColor: .windowBackgroundColor)
    }

     
     
     
     
    static var border: Color {
#if os(macOS)
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(
                        red: 0x4B / 255,
                        green: 0x4B / 255,
                        blue: 0x4B / 255,
                        alpha: 1
                    )
                    : NSColor.black.withAlphaComponent(0.08)
            }
        )
#else
        Color(red: 0x4B / 255, green: 0x4B / 255, blue: 0x4B / 255)
#endif
    }
}

private struct HakoProductModalPanel<Content: View>: View {
    let role: HakoModalPresentationRole
    @ViewBuilder let content: () -> Content

     
     
     
     
     
     
    @Environment(\.hakoRootDepartureGuard) private var departureGuard

     
     
     
     
     
     
    private func requestDismiss() {
        HakoModalCenter.shared.requestDismissTop(departureGuard)
    }

    var body: some View {
        framedContent
             
             
             
             
             
             
             
             
             
             
             
            .background(HakoProductModalSurface.canvas)
             
             
            .overlay(alignment: .topTrailing) {
                Button {
                    requestDismiss()
                } label: {
                     
                     
                     
                    Image(systemName: HakoSymbol.xmark.rawValue)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(
                            width: HakoTheme.MacOS.ProductModal.closeGlyphSize,
                            height: HakoTheme.MacOS.ProductModal.closeGlyphSize
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                 
                 
                 
                 
                 
                .keyboardShortcut(.cancelAction)
                .padding(HakoTheme.MacOS.ProductModal.closePadding)
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                .accessibilityLabel("Close")
            }
            .background(
                RoundedRectangle(
                    cornerRadius: HakoTheme.MacOS.ProductModal.cornerRadius,
                    style: .continuous
                )
                .fill(HakoProductModalSurface.canvas)
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: HakoTheme.MacOS.ProductModal.cornerRadius,
                    style: .continuous
                )
                    .strokeBorder(
                         
                         
                         
                         
                        HakoProductModalSurface.border,
                        lineWidth: HakoTheme.MacOS.ProductModal.borderWidth
                    )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: HakoTheme.MacOS.ProductModal.cornerRadius,
                    style: .continuous
                )
            )
             
             
             
            .compositingGroup()
            .shadow(
                color: .black.opacity(
                    HakoTheme.MacOS.ProductModal.shadowOpacity
                ),
                radius: HakoTheme.MacOS.ProductModal.shadowRadius,
                y: HakoTheme.MacOS.ProductModal.shadowYOffset
            )
            .onExitCommand {
                requestDismiss()
            }
    }

    @ViewBuilder
    private var framedContent: some View {
        switch role {
        case .fitted:
            sizedContent
                 
                 
                 
                .scrollContentBackground(.hidden)
                .frame(width: HakoTheme.MacOS.ProductModal.width)
        case .page, .form:
            sizedContent
                .scrollContentBackground(.hidden)
                .frame(width: HakoTheme.MacOS.ProductModal.width)
                .frame(maxHeight: HakoTheme.MacOS.ProductModal.maximumHeight)
        }
    }

    @ViewBuilder
    private var sizedContent: some View {
        switch role {
        case .fitted:
            content()
                .fixedSize(horizontal: false, vertical: true)
        case .page, .form:
            content()
        }
    }
}
#endif

public extension View {
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoProductModal<Item: Identifiable, C: View>(
        item: Binding<Item?>,
        role: HakoModalPresentationRole,
        macOSPanelRole: HakoModalPresentationRole? = nil,
        immersive: @escaping (Item) -> Bool = { _ in false },
        @ViewBuilder content: @escaping (Item) -> C
    ) -> some View {
#if os(macOS)
        modifier(HakoProductModalItemHost(
            item: item,
            role: macOSPanelRole ?? role,
            builder: { AnyView(content($0)) }
        ))
#else
         
         
         
        sheet(item: HakoModalItemSplit.binding(item, keeping: { !immersive($0) })) { value in
            content(value)
                .hakoModalPresentation(role)
        }
        .fullScreenCover(item: HakoModalItemSplit.binding(item, keeping: immersive)) { value in
            content(value)
                .hakoModalPresentation(role)
        }
#endif
    }

     
    @ViewBuilder
    func hakoProductModal<C: View>(
        isPresented: Binding<Bool>,
        role: HakoModalPresentationRole,
        macOSPanelRole: HakoModalPresentationRole? = nil,
        refreshID: AnyHashable = AnyHashable(false),
        @ViewBuilder content: @escaping () -> C
    ) -> some View {
#if os(macOS)
        modifier(HakoProductModalBoolHost(
            isPresented: isPresented,
            role: macOSPanelRole ?? role,
            refreshID: refreshID,
            builder: { AnyView(content()) }
        ))
#else
        sheet(isPresented: isPresented) {
            content()
                .hakoModalPresentation(role)
        }
#endif
    }
}

#if !os(macOS)
 
 
 
enum HakoModalItemSplit {
    static func binding<Item>(
        _ item: Binding<Item?>,
        keeping: @escaping (Item) -> Bool
    ) -> Binding<Item?> {
        Binding(
            get: {
                guard let value = item.wrappedValue, keeping(value) else { return nil }
                return value
            },
            set: { newValue in
                if let newValue {
                    item.wrappedValue = newValue
                } else if let current = item.wrappedValue, keeping(current) {
                    item.wrappedValue = nil
                }
            }
        )
    }
}
#endif

#if os(macOS)
 
 
 
 
 
 
 
 
enum HakoModalClassAudit {
     
     
     
     
     
     
     
     
    static func presenting() {


    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
private final class HakoModalLatestContent<Input> {
    private(set) var make: (Input) -> AnyView = { _ in AnyView(EmptyView()) }

    func install(_ make: @escaping (Input) -> AnyView) {
        self.make = make
    }
}

private struct HakoProductModalItemHost<Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    let role: HakoModalPresentationRole
    let builder: (Item) -> AnyView
    @State private var token: UUID?
    @State private var latest = HakoModalLatestContent<Item>()

    func body(content: Content) -> some View {
        let _ = latest.install { value in AnyView(presentationContent(value)) }
        content
            .onChange(of: item?.id) { _ in
                sync(item)
            }
            .onAppear {
                sync(item)
            }
             
             
             
             
             
             
             
             
             
             
             
             
             
            .onDisappear {
                if let token {
                    HakoModalCenter.shared.parkOrphan(
                        token,
                        claimKey: item.map { "item:\(Item.self):\($0.id)" }
                            ?? "item:\(Item.self):?"
                    )
                    self.token = nil
                }
            }
    }

    private func sync(_ value: Item?) {
         
         
         
         
        if let value, let token {
            HakoModalCenter.shared.update(token) {
                latest.make(value)
            }
            return
        }
         
         
         
         
         
        if let value, token == nil,
            let adopted = HakoModalCenter.shared.claimOrphan(
                claimKey: "item:\(Item.self):\(value.id)"
            )
        {
            token = adopted
            HakoModalCenter.shared.update(adopted) { latest.make(value) }
            return
        }
        if let token {
            HakoModalCenter.shared.dismiss(token)
            self.token = nil
        }
        guard let value else { return }
        HakoModalClassAudit.presenting()
        token = HakoModalCenter.shared.present(
            role: role,
            onDismiss: { item = nil }
        ) {
            latest.make(value)
        }
    }

    private func presentationContent(_ value: Item) -> some View {
        builder(value)
             
             
             
             
             
             
             
            .environment(\.hakoNavigationHostContext, .standalone)
            .environment(\.hakoProductChromeApplied, false)
            .environment(\.hakoInsideModalPresentation, true)
            .environment(\.hakoInsideProductModalPresentation, true)
             
             
             
             
            .onAppear { HakoProductModalPresence.shared.up() }
            .onDisappear { HakoProductModalPresence.shared.down() }
            .environment(\.hakoProductModalDismiss) {
                item = nil
            }
    }
}

private struct HakoProductModalBoolHost: ViewModifier {
    @Binding var isPresented: Bool
    let role: HakoModalPresentationRole
    let refreshID: AnyHashable
    let builder: () -> AnyView
    @State private var token: UUID?
    @State private var latest = HakoModalLatestContent<Void>()

    func body(content: Content) -> some View {
        let _ = latest.install { _ in AnyView(presentationContent) }
        content
            .onChange(of: isPresented) { shown in
                sync(shown)
            }
            .onAppear {
                sync(isPresented)
            }
            .onChange(of: refreshID) { observed in
                traceRefresh(observed)
                refresh(isPresented)
            }
             
             
             
             
             
             
             
             
             
            .onDisappear {
                if let token {
                    HakoModalCenter.shared.parkOrphan(
                        token,
                        claimKey: "presented:\(role)"
                    )
                    self.token = nil
                }
            }
    }

    private func sync(_ shown: Bool) {
         
         
         
        if shown, let token {
            HakoModalCenter.shared.update(token) { latest.make(()) }
            return
        }
        if shown, token == nil,
            let adopted = HakoModalCenter.shared.claimOrphan(
                claimKey: "presented:\(role)"
            )
        {
            token = adopted
            HakoModalCenter.shared.update(adopted) { latest.make(()) }
            return
        }
        if let token {
            HakoModalCenter.shared.dismiss(token)
            self.token = nil
        }
        guard shown else { return }
        HakoModalClassAudit.presenting()
        token = HakoModalCenter.shared.present(
            role: role,
            onDismiss: { isPresented = false }
        ) {
            latest.make(())
        }
    }

    private func refresh(_ shown: Bool) {
        guard shown, let token else { return }
        HakoModalCenter.shared.update(token) {
            latest.make(())
        }
    }

     
     
     
     
     
    private func traceRefresh(_ observed: AnyHashable) {
        guard ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1" else { return }
        FileHandle.standardError.write(
            "[nav] bool-host refresh selfIsCurrent=\(observed == refreshID)\n"
                .data(using: .utf8)!
        )
    }

    private var presentationContent: some View {
        builder()
             
            .environment(\.hakoNavigationHostContext, .standalone)
            .environment(\.hakoProductChromeApplied, false)
            .environment(\.hakoInsideModalPresentation, true)
            .environment(\.hakoInsideProductModalPresentation, true)
             
             
             
             
            .onAppear { HakoProductModalPresence.shared.up() }
            .onDisappear { HakoProductModalPresence.shared.down() }
            .environment(\.hakoProductModalDismiss) {
                isPresented = false
            }
    }
}
#endif

private struct HakoProductModalDismissKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> Void)? = nil
}

private struct HakoInsideProductModalPresentationKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
     
     
     
    var hakoProductModalDismiss: (@MainActor () -> Void)? {
        get { self[HakoProductModalDismissKey.self] }
        set { self[HakoProductModalDismissKey.self] = newValue }
    }

     
     
     
     
     
     
    var hakoInsideProductModalPresentation: Bool {
        get { self[HakoInsideProductModalPresentationKey.self] }
        set { self[HakoInsideProductModalPresentationKey.self] = newValue }
    }
}

public extension View {
     
     
     
    func hakoProductModalRoot(
        title: String,
        actionTitle: String? = nil,
        actionDisabled: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        modifier(HakoProductModalRootModifier(
            title: title,
            actionTitle: actionTitle,
            actionDisabled: actionDisabled,
            action: action
        ))
    }

     
     
     
     
     
     
     
     
    func hakoProductModalChild(
        title: String,
        searchText: Binding<String>? = nil,
        actionTitle: String? = nil,
        actionRole: HakoModalActionRole = .primary,
        actionDisabled: Bool = false,
        action: (() -> Void)? = nil,
        backAction: (() -> Void)? = nil
    ) -> some View {
        modifier(
            HakoProductModalChildModifier(
                title: title,
                searchText: searchText,
                actionTitle: actionTitle,
                actionRole: actionRole,
                actionDisabled: actionDisabled,
                action: action,
                backAction: backAction
            )
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    func hakoToolbarUnlessInPanel<Items: ToolbarContent>(
        @ToolbarContentBuilder _ items: @escaping () -> Items
    ) -> some View {
        modifier(HakoToolbarUnlessInPanelModifier(items: items))
    }

     
     
     
     
     
     
     
     
    func hakoProductModalSearchable(
        text: Binding<String>,
        prompt: Text? = nil
    ) -> some View {
        modifier(
            HakoProductModalSearchModifier(
                text: text,
                prompt: prompt
            )
        )
    }
}



 
 
 
 
 
 
 
 
 
 
 
@MainActor
public final class HakoProductModalPresence: ObservableObject {
    public static let shared = HakoProductModalPresence()
     
     
     
     
     
    static let signature = "hako.panel.presence.v21"
     
     
     
    static let v22Signature = "hako.panel.residue.v22"
    @Published private(set) var depth = 0
    var isUp: Bool { depth > 0 }
    func up() { depth += 1 }
    func down() { depth = max(0, depth - 1) }
}

private struct HakoToolbarUnlessInPanelModifier<Items: ToolbarContent>: ViewModifier {
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @ObservedObject private var presence = HakoProductModalPresence.shared
    let items: () -> Items

    func body(content: Content) -> some View {
         
         
         
         
         
         
         
         
#if os(macOS)
        content.toolbar {
            if !(insideProductModal || presence.isUp) {
                items()
            }
        }
#else
        content.toolbar { items() }
#endif
    }
}

private struct HakoProductModalSearchModifier: ViewModifier {
    @Binding var text: String
    let prompt: Text?

    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        if insideProductModal {
            content
        } else {
            searchable(content)
        }
#else
        searchable(content)
#endif
    }

    @ViewBuilder
    private func searchable(_ content: Content) -> some View {
        if let prompt {
            content.searchable(text: $text, prompt: prompt)
        } else {
            content.searchable(text: $text)
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
public enum HakoModalActionRole: Sendable {
    case primary
    case utility
}

 
 
 
 
 
 
 
 
 
 
 
 
struct HakoProductChromeAppliedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var hakoProductChromeApplied: Bool {
        get { self[HakoProductChromeAppliedKey.self] }
        set { self[HakoProductChromeAppliedKey.self] = newValue }
    }
}

 
enum HakoChromeAudit {
    static func secondChrome(_ title: String, kind: String) {


    }
}

private struct HakoProductModalRootModifier: ViewModifier {
    let title: String
    let actionTitle: String?
    let actionDisabled: Bool
    let action: (() -> Void)?

    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @Environment(\.hakoProductChromeApplied) private var chromeApplied

    private func trace() {
        guard ProcessInfo.processInfo.environment["HAKO_NAV_TRACE"] == "1" else { return }
        FileHandle.standardError.write(
            "[chrome] root title=\(title) insideProductModal=\(insideProductModal) chromeApplied=\(chromeApplied)\n".data(using: .utf8)!)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        let _ = trace()
        if insideProductModal && chromeApplied {
            let _ = HakoChromeAudit.secondChrome(title, kind: "Root")
            content
        } else if insideProductModal {
            content
                .environment(\.hakoProductChromeApplied, true)
                 
                 
                 
                 
                 
                .environment(\.hakoRegularShellOwnsCanvas, true)
                .toolbar(.hidden, for: .windowToolbar)
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack(spacing: HakoTheme.Spacing.row) {
                        Text(hako: .copy(title))
                            .font(.headline)
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        if let actionTitle, let action {
                             
                             
                             
                            Button(action: action) {
                                Text(HakoCopy.key(actionTitle))
                            }
                                 
                                 
                                 
                                 
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.primary)
                                .disabled(actionDisabled)
                                .accessibilityIdentifier(
                                    "hako.modal.root.action"
                                )
                        }
                        Color.clear
                            .frame(
                                width: HakoTheme.MacOS.ProductModal.closeHitRegion,
                                height: 1
                            )
                            .accessibilityHidden(true)
                    }
                    .frame(
                        minHeight: HakoTheme.MacOS.ProductModal.headerMinHeight
                    )
                    .padding(.horizontal, HakoTheme.Spacing.standard)
                    .background(HakoProductModalSurface.canvas)
                    .overlay(alignment: .bottom) {
                        Divider()
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

private struct HakoProductModalChildModifier: ViewModifier {
     
    @Environment(\.hakoRootDepartureGuard) private var departureGuard
    let title: String
    let searchText: Binding<String>?
    let actionTitle: String?
    let actionRole: HakoModalActionRole
    let actionDisabled: Bool
    let action: (() -> Void)?
    let backAction: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.hakoPopRoute) private var popRoute
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal
    @Environment(\.hakoProductChromeApplied) private var chromeApplied

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        if insideProductModal && chromeApplied {
             
             
             
             
             
             
             
             
             
             
             
             
             
            if actionTitle != nil {
                let _ = HakoChromeAudit.secondChrome(title, kind: "Child")
            }
            content
        } else if insideProductModal {
            content
                .environment(\.hakoProductChromeApplied, true)
                 
                 
                 
                .environment(\.hakoRegularShellOwnsCanvas, true)
                 
                 
                 
                 
                 
                 
                 
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(HakoProductModalSurface.canvas)
                 
                 
                 
                .formStyle(.grouped)
                .listStyle(.inset)
                 
                 
                 
                 
                 
                 
                 
                 
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .windowToolbar)
                 
                 
                 
                 
                 
                .padding(.bottom, HakoTheme.Spacing.standard)
                .safeAreaInset(edge: .top, spacing: 0) {
                    HStack(spacing: HakoTheme.Spacing.row) {
                        Button {
                                HakoNavigationTransaction.resignCurrentField()
                                 
                                 
                                 
                                 
                                 
                                 
                                 
                                let leave: () -> Void = {
                                    if let backAction {
                                        backAction()
                                    } else if let popRoute {
                                        popRoute(HakoPopToken())
                                    } else {
                                        dismiss()
                                    }
                                }
                                HakoDeparture.request(departureGuard, leave: leave)
                            } label: {
                                Image(
                                    systemName:
                                        HakoSymbol.chevronBackward.rawValue
                                )
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle().fill(Color.white.opacity(0.09))
                                )
                            }
                            .frame(
                                width: HakoTheme.Control.minimumHitTarget,
                                height: HakoTheme.Control.minimumHitTarget
                            )
                            .contentShape(Rectangle())
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                        .accessibilityIdentifier("hako.modal.child.back")

                        Text(hako: .copy(title))
                            .font(.headline)
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        if let searchText {
                            HakoModalSearchField(text: searchText)
                        }
                        if let actionTitle, let action {
                            switch actionRole {
                            case .primary:
                                Button(actionTitle, action: action)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(actionDisabled)
                                    .accessibilityIdentifier(
                                        "hako.modal.child.action"
                                    )
                            case .utility:
                                Button(actionTitle, action: action)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .tint(.primary)
                                    .disabled(actionDisabled)
                                    .accessibilityIdentifier(
                                        "hako.modal.child.action"
                                    )
                            }
                        }
                         
                         
                         
                        Color.clear
                            .frame(
                                width: HakoTheme.MacOS.ProductModal.closeHitRegion,
                                height: 1
                            )
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, HakoTheme.Spacing.standard)
                     
                     
                    .padding(.vertical, 4)
                     
                     
                     
                     
                     
                    .background(HakoProductModalSurface.canvas)
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("hako.modal.child.header")
                }
        } else {
            content
        }
#else
        content
#endif
    }
}

public extension View {
     
     
     
     
     
     
     
     
    func hakoNativeSheetChild(
        title: String,
        searchText: Binding<String>? = nil,
        backAction: (() -> Void)? = nil,
        actionTitle: String? = nil,
        actionDisabled: Bool = false,
        action: (() -> Void)? = nil
    ) -> some View {
        modifier(
            HakoNativeSheetChildModifier(
                title: title,
                searchText: searchText,
                backAction: backAction,
                actionTitle: actionTitle,
                actionDisabled: actionDisabled,
                action: action
            )
        )
    }
}

 
 
 
private struct HakoWindowToolbarHiddenInsidePanel: ViewModifier {
    let hidden: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        if hidden {
            content.toolbar(.hidden, for: .windowToolbar)
        } else {
            content
        }
#else
        content
#endif
    }
}

private struct HakoNativeSheetChildModifier: ViewModifier {
     
    @Environment(\.hakoRootDepartureGuard) private var departureGuard
    let title: String
    let searchText: Binding<String>?
    let backAction: (() -> Void)?
    var actionTitle: String? = nil
    var actionDisabled = false
    var action: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.hakoPopRoute) private var popRoute
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
             
             
             
             
             
             
             
             
             
            .modifier(HakoWindowToolbarHiddenInsidePanel(hidden: insideProductModal))
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: HakoTheme.Spacing.row) {
                    Button {
                        HakoNavigationTransaction.resignCurrentField()
                         
                         
                         
                         
                        let leave: () -> Void = {
                            if let backAction {
                                backAction()
                            } else if let popRoute {
                                popRoute(HakoPopToken())
                            } else {
                                dismiss()
                            }
                        }
                        HakoDeparture.request(departureGuard, leave: leave)
                    } label: {
                        Image(
                            systemName:
                                HakoSymbol.chevronBackward.rawValue
                        )
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(Color.primary.opacity(0.09))
                        )
                    }
                    .frame(
                        width: HakoTheme.Control.minimumHitTarget,
                        height: HakoTheme.Control.minimumHitTarget
                    )
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(hako: .copy("Back")))
                    .accessibilityIdentifier("hako.sheet.child.back")

                    Text(hako: .copy(title))
                        .font(.headline)
                    Spacer(minLength: HakoTheme.Spacing.compact)
                    if let searchText {
                        HakoModalSearchField(text: searchText)
                    }
                    if let actionTitle, let action {
                        Button(actionTitle, action: action)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(actionDisabled)
                            .accessibilityIdentifier(
                                "hako.sheet.child.action"
                            )
                    }
                }
                .padding(.horizontal, HakoTheme.Spacing.standard)
                .padding(.vertical, 4)
                .background(.bar)
            }
    }
}
