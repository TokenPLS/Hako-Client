import HakoClientUI
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
private enum AckModalRoute: Identifiable {
    case license(ThirdPartyLicenseInventory.Module)
    case allModules

    var id: String {
        switch self {
        case .license(let module): "license-\(module.id)"
        case .allModules: "all-modules"
        }
    }
}

struct AcknowledgementsView: View {
    private let inventory = ThirdPartyLicenseInventory.shared
    @State private var modalRoute: AckModalRoute?
#if os(macOS)
    @Environment(\.hakoDoorMayPush) private var mayPush
#endif

     
    @ViewBuilder
    private func door<DoorLabel: View>(
        macOS route: @autoclosure @escaping () -> AckModalRoute,
        @ViewBuilder destination: @escaping () -> some View,
        @ViewBuilder label: () -> DoorLabel
    ) -> some View {
#if os(macOS)
         
         
         
         
         
        if mayPush {
            HakoRoutedViewLink {
                destination()
            } label: {
                label()
            }
        } else {
            Button {
                 
                 
                 
                 
                 
                 
                HakoPageProbe.markNavigation()
                modalRoute = route()
            } label: {
                HStack(spacing: 6) {
                    label()
                    Spacer(minLength: 0)
                    Image(systemName: HakoSymbol.chevronForward.rawValue)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
#else
        HakoRoutedViewLink {
            destination()
        } label: {
            label()
        }
#endif
    }

    var body: some View {
         
         
         
         
        HakoMacSettingsContainer {
            Section {
                if let module = inventory.module(
                    AcknowledgementsCatalog.framework.module
                ) {
                    door(macOS: .license(module)) {
                        LicenseTextView(module: module)
                    } label: {
                        row(module, role: AcknowledgementsCatalog.framework.role)
                    }
                    .accessibilityIdentifier("acknowledgements.framework")
                }
            } header: {
                Text(hako: .verbatim("Framework"))
            } footer: {
                Text(hako: .verbatim(
                    AcknowledgementsCatalog.sourceOfferStatement
                ))
            }

            Section {
                ForEach(AcknowledgementsCatalog.highlights) { highlight in
                    if let module = inventory.module(highlight.module) {
                        door(macOS: .license(module)) {
                            LicenseTextView(module: module)
                        } label: {
                            row(module, role: highlight.role)
                        }
                        .accessibilityIdentifier(
                            "acknowledgements.\(module.shortName)"
                        )
                    }
                }
            } header: {
                Text(hako: .verbatim("Inside Hako"))
            } footer: {
                Text(hako: .verbatim(
                    "This app calls none of these directly. All of them are compiled into the binary it ships."
                ))
            }

            Section {
                door(macOS: .allModules) {
                    LinkedModulesView(inventory: inventory)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hako: .verbatim("All linked modules"))
                        Text(hako: .verbatim(summary))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("acknowledgements.allModules")
            }
             
             
             
             
             
             
             
             

            Section {
                ForEach(AcknowledgementsCatalog.systemFrameworks) { framework in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hako: .verbatim(framework.name))
                            .font(.subheadline.weight(.semibold))
                        Text(hako: .verbatim(framework.usage))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text(hako: .verbatim("System frameworks"))
            } footer: {
                Text(hako: .verbatim(
                    "These ship with the operating system rather than with this app, and are named here to describe what it is built against."
                ))
            }

            Section {
                ForEach(AcknowledgementsCatalog.trademarkNotices, id: \.self) {
                    notice in
                    Text(hako: .verbatim(notice))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text(hako: .verbatim("Trademarks"))
            } footer: {
                Text(hako: .verbatim(
                    AcknowledgementsCatalog.trademarkStatement
                ))
            }
        }
        .hakoGroupedList()
        .hakoDetailPageInsets()
#if os(macOS)
         
         
        .hakoProductModal(item: $modalRoute, role: .form) { route in
            HakoFeatureNavigationContainer {
                 
                 
                 
                 
                 
                Group {
                    switch route {
                    case .license(let module):
                        LicenseTextView(module: module)
                    case .allModules:
                        LinkedModulesView(inventory: inventory)
                    }
                }
                .hakoProductModalRoot(title: {
                    switch route {
                    case .license(let module): module.module
                    case .allModules: "Linked modules"
                    }
                }())
            }
            .hakoPageSizedSheet()
        }
#endif
#if os(macOS)
        .hakoPageTitle(.verbatim("Acknowledgements"), watchAs: "acknowledgements")
#else
        .hakoPageTitle(.verbatim("Acknowledgements"), watchAs: "acknowledgements")
#endif
         
         
         
#if os(macOS)
        .hakoPageProbe("acknowledgements")
#endif
        .accessibilityIdentifier("legal.Acknowledgements")
    }

     
    private var summary: String {
        let families = inventory.licenseSummary
            .prefix(4)
            .map { "\($0.license) \($0.count)" }
            .joined(separator: ", ")
        return "\(inventory.modules.count) modules · \(families)"
    }

    @ViewBuilder
    private func row(
        _ module: ThirdPartyLicenseInventory.Module, role: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(hako: .verbatim(module.shortName))
                .font(.subheadline.weight(.semibold))
            Text(hako: .verbatim(role))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(hako: .verbatim(versionLine(module)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func versionLine(
        _ module: ThirdPartyLicenseInventory.Module
    ) -> String {
        module.version.isEmpty
            ? module.license
            : "\(module.license) · \(module.version)"
    }
}

 
 
 
 
 
struct LinkedModulesView: View {
    let inventory: ThirdPartyLicenseInventory

    @ViewBuilder
    var body: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            List {
                ForEach(inventory.modules) { module in
#if os(macOS)
                    Button {
                        push(module)
                    } label: {
                        HStack(spacing: 6) {
                            moduleLabel(module)
                            Spacer(minLength: 0)
                            Image(
                                systemName: HakoSymbol.chevronForward.rawValue
                            )
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                     
                     
                     
                     
                    .accessibilityIdentifier(
                        "acknowledgements.module.\(module.shortName)"
                    )
#else
                    moduleLabel(module)
#endif
                }
            }
            .hakoMacSettingsList(minRowHeight: 30)
            .hakoDetailPageInsets()
#if os(macOS)
            .hakoPageTitle(.verbatim("Linked modules"), watchAs: "linked-modules")
#else
            .hakoPageTitle(.verbatim("Linked modules"), watchAs: "linked-modules")
#endif
            .accessibilityIdentifier("acknowledgements.modules")
             
             
             
             
            .hakoProductModal(item: $modalModule, role: .form) { module in
                HakoFeatureNavigationContainer {
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    LicenseTextView(module: module)
#if os(macOS)
                        .hakoProductModalRoot(title: module.module)
#endif
                }
                .hakoPageSizedSheet()
            }
        } else {
            List {
                ForEach(inventory.modules) { module in
                    HakoRoutedViewLink {
                        LicenseTextView(module: module)
                    } label: {
                        moduleLabel(module)
                    }
                }
            }
            .hakoGroupedList()
            .hakoDetailPageInsets()
             
             
             
             
             
             
             
             
             
             
             
             
             
            .hakoPageTitle(.verbatim("Linked modules"), watchAs: "linked-modules")
            .accessibilityIdentifier("acknowledgements.modules")
        }
    }


     
     
     
    @State private var modalModule: ThirdPartyLicenseInventory.Module?
#if os(macOS)
    @Environment(\.hakoDoorMayPush) private var mayPush
    @Environment(\.hakoPushRoute) private var pushRoute
    @State private var routeToken = UUID()
#endif

     
     
     
     
     
     
     
     
     
     
     
     
    @MainActor
    private func push(_ module: ThirdPartyLicenseInventory.Module) {
#if os(macOS)
        HakoPushAuthorityProbe.trace(
            "licence-row", mayPush: mayPush, hasPusher: pushRoute != nil
        )
        if mayPush, let pushRoute {
            HakoViewRouteRegistry.set(
                routeToken,
                ownership: .rowOwned,
                onReturn: {}
            ) {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                AnyView(
                    LicenseTextView(module: module)
                        .hakoProductModalChild(title: module.module)
                )
            }
            pushRoute(HakoViewRoute(id: routeToken))
            return
        }
#endif
        modalModule = module
    }

    @ViewBuilder
    private func moduleLabel(
        _ module: ThirdPartyLicenseInventory.Module
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(hako: .verbatim(module.module))
                .font(.subheadline)
            Text(hako: .verbatim(
                module.version.isEmpty
                    ? module.license
                    : "\(module.license) · \(module.version)"
            ))
            .font(.caption2)
            .foregroundStyle(.secondary)
            if let note = module.note {
                Text(hako: .verbatim(note))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

 
struct LicenseTextView: View {
    let module: ThirdPartyLicenseInventory.Module

    var body: some View {
        content
            .hakoDetailPageInsets()
            .hakoPageTitle(
                .verbatim(module.shortName), watchAs: "license-module"
            )
            .accessibilityIdentifier("license.\(module.shortName)")
    }

    @ViewBuilder
    private var content: some View {
#if canImport(AppKit)
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
             
             
             
             
             
            HakoMacLicenseText(
                text: ThirdPartyLicenseInventory.shared.text(for: module)
            )
        } else {
            touchScroll
        }
#else
        touchScroll
#endif
    }

    private var touchScroll: some View {
        ScrollView {
             
             
            Text(hako: .verbatim(
                ThirdPartyLicenseInventory.shared.text(for: module)
            ))
            .font(.caption.monospaced())
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HakoTheme.Spacing.standard)
        }
    }
}

#if canImport(AppKit)
 
private struct HakoMacLicenseText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let textView = scroll.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        scroll.drawsBackground = false
        textView.textColor = .labelColor
        textView.font = .monospacedSystemFont(
            ofSize: NSFont.smallSystemFontSize, weight: .regular
        )
        textView.textContainerInset = NSSize(
            width: HakoTheme.Spacing.standard,
            height: HakoTheme.Spacing.standard
        )
         
         
        textView.layoutManager?.allowsNonContiguousLayout = true
        textView.string = text
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? NSTextView,
              textView.string != text else { return }
        textView.string = text
    }
}
#endif
