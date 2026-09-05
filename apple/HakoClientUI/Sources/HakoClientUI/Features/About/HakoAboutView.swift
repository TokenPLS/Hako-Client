import Foundation
import SwiftUI

public enum HakoAboutComponentDetailRole: String, Sendable {
    case version
    case upstream
}

public enum HakoAboutComponent:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case hakoCore

    public var id: Self { self }

    public var title: String {
        switch self {
        case .hakoCore: "Hako Core"
        }
    }

     
     
     
     
     
     
    public var description: String {
        switch self {
        case .hakoCore:
            "The open-source core that carries traffic."
        }
    }

    public var detailRole: HakoAboutComponentDetailRole {
        switch self {
        case .hakoCore: .version
        }
    }

    public var accent: HakoAccentRole {
        switch self {
        case .hakoCore: .indigo
        }
    }

    public var url: URL {
        switch self {
        case .hakoCore:
            URL(string: "https://github.com/TokenPLS/Hako")!
        }
    }
}

 
 
 
 
public enum HakoAboutAcknowledgement:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case mihomo
    case singBox
    case flClash
    case clashForWindows

    public var id: Self { self }

    public var title: String {
        switch self {
        case .mihomo: "mihomo"
        case .singBox: "sing-box"
        case .flClash: "FlClash"
        case .clashForWindows: "Clash for Windows"
        }
    }

     
     
    public var role: String {
        switch self {
        case .mihomo: "A rule-based proxy kernel"
        case .singBox: "The universal proxy platform"
        case .flClash: "A multi-platform proxy client"
        case .clashForWindows: "Genshin"
        }
    }

     
     
     
    public var url: URL? {
        switch self {
        case .mihomo:
            URL(string: "https://github.com/MetaCubeX/mihomo")
        case .singBox:
            URL(string: "https://github.com/SagerNet/sing-box")
        case .flClash:
            URL(string: "https://github.com/chen08209/FlClash")
        case .clashForWindows:
            nil
        }
    }
}

 
 
 
 
 
 
 
 
 
public enum HakoAboutLink:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case sourceRepository

    public var id: Self { self }

    public var title: String {
        switch self {
        case .sourceRepository: "Source Repository"
        }
    }

    public var symbol: HakoSymbol {
        switch self {
        case .sourceRepository: .githubMark
        }
    }

    public var url: URL {
        switch self {
        case .sourceRepository:
            URL(string: "https://github.com/TokenPLS/Hako-Client")!
        }
    }
}

 
public struct HakoAboutView<
    Icon: View,
    ComponentLogo: View,
    Legal: View
>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let snapshot: HakoAboutSnapshot
    private let palette: HakoProductPalette
    private let developerMode: Binding<Bool>?
    private let icon: (HakoSymbol) -> Icon
    private let componentLogo:
        (HakoAboutComponent) -> ComponentLogo

     
     
     
    private let legal: () -> Legal

    public init(
        snapshot: HakoAboutSnapshot,
        palette: HakoProductPalette,
        developerMode: Binding<Bool>? = nil,
        @ViewBuilder legal: @escaping () -> Legal = { EmptyView() },
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        @ViewBuilder componentLogo: @escaping (
            HakoAboutComponent
        ) -> ComponentLogo
    ) {
        self.snapshot = snapshot
        self.palette = palette
        self.developerMode = developerMode
        self.legal = legal
        self.icon = icon
        self.componentLogo = componentLogo
    }

    public var body: some View {
         
         
         
         
        HakoMacSettingsContainer {
            Section {
                appHeader
                    .padding(.vertical, HakoTheme.Spacing.compact)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "Clash, Powered by Hako, Version \(snapshot.appVersion)"
                    )
                    .accessibilityIdentifier("about.appHeader")

                Text(
                    "A rule-based proxy client for Apple platforms, powered by the Hako core."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            componentsSection

            acknowledgementsSection

            if let developerMode {
                developerSection(developerMode)
            }

            Section { legal() }

            openSourceSection
        }
         
         
        .hakoRootHeading("About")
    }

    @ViewBuilder
    private var appHeader: some View {
        if dynamicTypeSize >= .accessibility1 {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.standard
            ) {
                appIcon
                appIdentity
            }
        } else {
            HStack(spacing: HakoTheme.Spacing.standard) {
                appIcon
                appIdentity
            }
        }
    }

    private var appIcon: some View {
        icon(.catCircleFill)
            .font(.system(size: 56, weight: .semibold))
            .foregroundStyle(.tint)
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)
    }

    private var appIdentity: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            Text("Clash")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Powered by Hako")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
             
             
             
            Text("Version \(snapshot.versionLine)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !snapshot.sourceRevision.isEmpty {
                Text(snapshot.sourceRevision)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .hakoTextSelectionEnabled()
                    .accessibilityLabel(
                        Text(hako: .format(
                            "Source revision %@",
                            [snapshot.sourceRevision]
                        ))
                    )
                    .accessibilityIdentifier("about.source-revision")
            }
        }
    }

    private var componentsSection: some View {
        Section {
            ForEach(HakoAboutComponent.allCases) { component in
                Link(destination: component.url) {
                    componentRow(component)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    "about.component.\(component.rawValue)"
                )
            }
        } header: {
            Text("Components")
                .accessibilityIdentifier("about.section.components")
        }
    }

    @ViewBuilder
    private var acknowledgementsSection: some View {
        Section {
            ForEach(HakoAboutAcknowledgement.allCases) { project in
                if let url = project.url {
                    Link(destination: url) {
                        acknowledgementRow(project, linksOut: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "about.acknowledgement.\(project.rawValue)"
                    )
                } else {
                    acknowledgementRow(project, linksOut: false)
                        .accessibilityIdentifier(
                            "about.acknowledgement.\(project.rawValue)"
                        )
                }
            }
        } header: {
            Text("Thanks To")
                .accessibilityIdentifier("about.section.acknowledgements")
        }
    }

    private func acknowledgementRow(
        _ project: HakoAboutAcknowledgement,
        linksOut: Bool
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.row) {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.tight
            ) {
                Text(project.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(hako: .copy(project.role))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            if linksOut {
                componentLinkIcon
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
         
         
        .padding(.vertical, HakoMacSettingsMetrics.rowVerticalInset(touch: 0))
        .contentShape(Rectangle())
    }

    private func developerSection(
        _ developerMode: Binding<Bool>
    ) -> some View {
        Section {
            Toggle("Developer Mode", isOn: developerMode)
                .accessibilityIdentifier("about.developerMode")
        } header: {
            Text("Advanced")
        } footer: {
            Text(
                "Shows on-device diagnostics and local data maintenance in Tools."
            )
        }
    }

    private var openSourceSection: some View {
        Section {
            ForEach(HakoAboutLink.allCases) { link in
                Link(destination: link.url) {
                    Label {
                        Text(LocalizedStringKey(link.title))
                    } icon: {
                        icon(link.symbol)
                    }
                }
            }
        } header: {
            Text("Open Source")
                .accessibilityIdentifier("about.section.openSource")
        }
    }

    private func componentRow(
        _ component: HakoAboutComponent
    ) -> some View {
        Group {
            if dynamicTypeSize >= .accessibility1 {
                VStack(
                    alignment: .leading,
                    spacing: HakoTheme.Spacing.compact
                ) {
                    HStack(
                        alignment: .top,
                        spacing: HakoTheme.Spacing.row
                    ) {
                        componentLogoView(component)
                        componentCopy(component)
                    }

                    HStack(spacing: HakoTheme.Spacing.compact) {
                        componentDetail(component)
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        componentLinkIcon
                    }
                    .padding(
                        .leading,
                        HakoTheme.Layout.resolvedDestinationRowIconSize
                            + HakoTheme.Spacing.row
                    )
                }
            } else {
                HStack(spacing: HakoTheme.Spacing.row) {
                    componentLogoView(component)
                    componentCopy(component)
                    Spacer(minLength: HakoTheme.Spacing.compact)
                    componentDetail(component)
                    componentLinkIcon
                }
            }
        }
         
         
         
         
        .padding(
            .vertical,
            HakoMacSettingsMetrics.rowVerticalInset(
                touch: HakoTheme.Spacing.tight
            )
        )
    }

    private func componentLogoView(
        _ component: HakoAboutComponent
    ) -> some View {
        componentLogo(component)
            .frame(
                width: HakoTheme.Layout.resolvedDestinationRowIconSize,
                height: HakoTheme.Layout.resolvedDestinationRowIconSize
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: HakoTheme.Radius.icon,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    private func componentCopy(
        _ component: HakoAboutComponent
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            Text(LocalizedStringKey(component.title))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Text(LocalizedStringKey(component.description))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func componentDetail(
        _ component: HakoAboutComponent
    ) -> some View {
        if component.detailRole == .version {
            Text(snapshot.coreVersion)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        } else {
            HakoStatusBadge(
                title: "Upstream",
                tint: component.accent.color,
                role: .category,
                categoryFill: palette.raisedFill,
                requirementFill: palette.raisedFill,
                separator: palette.separator
            )
        }
    }

    private var componentLinkIcon: some View {
        icon(.link)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }
}
