import HakoClientUI
import SwiftUI

 
 
struct ProfilePreviewView: View {
    let title: HakoDisplayText
    private let loader: (() async -> String?)?
     
    @State private var dismiss = HakoDismissHandle()
    @State private var text: String
    @State private var isAvailable: Bool
    @State private var isLoading: Bool

    init(title: HakoDisplayText, text: String?) {
        self.title = title
        loader = nil
        _text = State(initialValue: text ?? "")
        _isAvailable = State(initialValue: text != nil)
        _isLoading = State(initialValue: false)
    }

    init(title: HakoDisplayText, load: @escaping () async -> String?) {
        self.title = title
        loader = load
        _text = State(initialValue: "")
        _isAvailable = State(initialValue: false)
        _isLoading = State(initialValue: true)
    }

    var body: some View {
        HakoFeatureNavigationContainer {
            ZStack {
                HakoTheme.canvas.ignoresSafeArea()
                if isLoading {
                    ProgressView("Preparing local configuration")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile-preview.loading")
                } else if isAvailable {
                    CodeEditorPanel(
                        text: $text,
                        language: .yaml,
                        minHeight: 360,
                        isEditable: false,
                        expandsVertically: true
                    )
                    .padding(HakoTheme.Spacing.standard)
                     
                     
                     
                     
                     
                     
                     
                     
                     
#if os(macOS)
                    .hakoPageProbe("runtime-editor")
#endif
                } else {
                    HakoEmptyState(
                        title: "No Local Configuration",
                        message: "Sync or import this profile to cache its configuration on this device.",
                        symbol: .docTextMagnifyingglass
                    )
                }
            }
            .hakoPageTitle(title, watchAs: "profile-preview")
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    HakoSheetCloseButton { dismiss() }
                }
            }
            .hakoProductModalRoot(title: "Runtime Configuration")
            .task {
                guard let loader, isLoading else { return }
                let loaded = await loader()
                guard !Task.isCancelled else { return }
                text = loaded ?? ""
                isAvailable = loaded != nil
                isLoading = false
            }
        }
        .hakoStackNavigationViewStyle()
        .hakoCapturesDismiss(dismiss)
    }
}

private enum FinalConfigurationPreviewKind: String, CaseIterable, Identifiable {
    case source = "Subscription Source"
     
     
     
    case effective = "preview.kind.runtime"

    var id: String { rawValue }
}

 
 
 
 
struct ProfileFinalConfigurationView: View {
    let title: String
    let snapshot: ProfileFinalConfigurationSnapshot
    private let ownsNavigationContainer: Bool
     
     
    private let command: ClashCommandClient?
     
     
    private let sourceYAML: String?
     
     
     
     
     
     
     
    private let comparisonYAML: String?
    private let baseYAML: String?

     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.locale) private var locale
    @State private var previewKind: FinalConfigurationPreviewKind = .effective
     
     
    @State private var verdict: PreflightOutcome?
     
     
    @State private var deviations: ConfigDeviationReport?
     
     
     
     
    @State private var deviationsAreOffline = false
     
     
     
     
    @State private var blockedRuleSets: [ProviderCompileVerdicts.Blocked] = []
     
     
     
     
     
     
    @State private var planNotices: [String] = []
     
     
    @State private var planNoticesLoaded = false
    private let blockedRuleSetsLoader:
        (@Sendable () async -> [ProviderCompileVerdicts.Blocked])?

     
     
     
#if os(macOS)
     
    @ViewBuilder
    private var previewLabel: some View {
        disclosureLabel(
            title: previewKind == .source
                ? "View Captured Source"
                : "View Runtime Configuration",
            detail: selectedText == nil ? "Not available yet" : "Read-only",
            symbol: .docText,
            tint: .blue
        )
    }

     
     
    @ViewBuilder
    private var previewLink: some View {
        HakoRoutedViewLink {
            HakoLazyView {
                FinalConfigurationTextView(
                    title: .copy(previewKind.rawValue),
                    text: selectedText
                )
            }
        } label: {
            previewLabel
        }
        .disabled(selectedText == nil)
        .accessibilityIdentifier("final-configuration.open-preview")
    }

#endif

#if os(macOS)
    private let footerCopy =
        "The captured source is what you pasted. Runtime is the config macOS actually runs — overrides applied, with your own credentials shown. For a profile that is already running, it is the revision that was activated: later edits appear here once you activate it again."
    private let fixedTitle = "Fixed by macOS"
    private let unsupportedTitle = "Not Used on macOS"
    private let adaptedTitle = "Prepared for macOS"
    private let adaptedEmptyDetail =
        "The stored source and effective comparison does not contain a known macOS rewrite."
    private let unsupportedEmptyTitle = "No Desktop or Inbound Fields"
    private let adaptedEmptyTitle = "No Known macOS Rewrite"
#else
    private let footerCopy =
        "The captured source is what you pasted. Runtime is the config iOS actually runs — overrides applied and desktop-only surfaces removed — with your own credentials shown. For a profile that is already running, it is the revision that was activated: later edits appear here once you activate it again."
    private let fixedTitle = "Fixed by iOS"
    private let unsupportedTitle = "Not Used on iOS"
    private let adaptedTitle = "Prepared for iOS"
    private let adaptedEmptyDetail =
        "The stored source and effective comparison does not contain a known iOS rewrite."
    private let unsupportedEmptyTitle = "No Desktop or Inbound Fields"
    private let adaptedEmptyTitle = "No Known iOS Rewrite"
#endif
#if os(macOS)
     
    @State private var showsPreviewText = false
    @Environment(\.hakoDoorMayPush) private var mayPush
#endif

    init(
        title: String,
        sourceYAML: String?,
        effectiveYAML: String?,
         
         
         
         
         
         
         
         
         
         
         
        baseYAML: String? = nil,
         
         
         
         
        comparisonYAML: String? = nil,
        ownsNavigationContainer: Bool = true,
        command: ClashCommandClient? = nil,
        blockedRuleSets:
            (@Sendable () async -> [ProviderCompileVerdicts.Blocked])? = nil
    ) {
        self.init(
            title: title,
            snapshot: ProfileFinalConfigurationSnapshot.make(
                sourceYAML: sourceYAML,
                effectiveYAML: effectiveYAML
            ),
            sourceYAML: sourceYAML,
            comparisonYAML: comparisonYAML ?? sourceYAML,
            baseYAML: baseYAML,
            ownsNavigationContainer: ownsNavigationContainer,
            command: command,
            blockedRuleSets: blockedRuleSets
        )
    }

    init(
        title: String,
        snapshot: ProfileFinalConfigurationSnapshot,
        sourceYAML: String? = nil,
        comparisonYAML: String? = nil,
        baseYAML: String? = nil,
        ownsNavigationContainer: Bool = true,
        command: ClashCommandClient? = nil,
        blockedRuleSets:
            (@Sendable () async -> [ProviderCompileVerdicts.Blocked])? = nil
    ) {
        self.title = title
        self.ownsNavigationContainer = ownsNavigationContainer
        self.command = command
        blockedRuleSetsLoader = blockedRuleSets
        self.snapshot = snapshot
        self.sourceYAML = sourceYAML
        self.comparisonYAML = comparisonYAML
        self.baseYAML = baseYAML
    }

    var body: some View {
        HakoFeatureNavigationContainer(
            ownsNavigationContainer: ownsNavigationContainer
        ) {
            List {
                Section {
                    Picker("Configuration", selection: $previewKind) {
                        ForEach(FinalConfigurationPreviewKind.allCases) { kind in
                            Text(hako: .copy(kind.rawValue)).tag(kind)
                        }
                    }
                    .hakoIdiomFormPickerStyle()
                    .accessibilityIdentifier("final-configuration.preview-kind")

#if os(macOS)
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    if mayPush {
                        previewLink
                    } else {
                        Button {
                             
                             
                             
                             
                             
                             
                            HakoPageProbe.markNavigation()
                            showsPreviewText = true
                        } label: {
                            HStack(spacing: HakoTheme.Spacing.compact) {
                                previewLabel
                                Spacer(minLength: HakoTheme.Spacing.compact)
                                 
                                 
                                 
                                 
                                Image(
                                    systemName: HakoSymbol.chevronForward.rawValue
                                )
                                .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedText == nil)
                         
                         
                         
                         
                         
                         
                         
                        .listRowSeparator(.visible, edges: .bottom)
                        .accessibilityIdentifier("final-configuration.open-preview")
                    }
#else
                    HakoRoutedViewLink {
                        HakoLazyView {
                            FinalConfigurationTextView(
                                title: .copy(previewKind.rawValue),
                                text: selectedText
                            )
                        }
                    } label: {
                        disclosureLabel(
                            title: previewKind == .source
                                ? "View Captured Source"
                                : "View Runtime Configuration",
                            detail: selectedText == nil
                                ? "Not available yet"
                                : "Read-only",
                            symbol: .docText,
                            tint: .blue
                        )
                    }
                    .disabled(selectedText == nil)
                    .accessibilityIdentifier("final-configuration.open-preview")
#endif

#if os(macOS)
                     
                     
                     
                     
                     
                     
                     
                     
                    VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
                        if previewKind == .effective, let text = selectedText {
                            kernelVerdictRow(for: text)
                        }
                        sectionExplanationRow(footerCopy)
                    }
                    .listRowInsets(
                        EdgeInsets(top: 6, leading: 20, bottom: 8, trailing: 20)
                    )
                    .listRowSeparator(.hidden)
#else
                    if previewKind == .effective, let text = selectedText {
                        kernelVerdictRow(for: text)
                    }
#endif
                } header: {
                    Text("Compare")
                } footer: {
                     
                     
                     
                     
                     
                     
                     
#if !os(macOS)
                    Text(hako: .copy(footerCopy))
#endif
                }

                disclosureSection(
                    title: fixedTitle,
                    items: snapshot.fixedItems,
                    symbol: .checkmarkShieldFill,
                    tint: .blue,
                    identifierFragment: "fixed"
                )

                if Self.saysAllClear(
                    items: snapshot.unsupportedItems,
                    planLoaded: planNoticesLoaded,
                    planNotices: planNotices
                ) {
                    Section {
                        disclosureLabel(
                             
                             
                             
                             
                            title: unsupportedEmptyTitle,
                            detail: "This source does not request a desktop or inbound server surface.",
                            symbol: .checkmarkCircle,
                            tint: .green
                        )
                        .accessibilityIdentifier("final-configuration.unsupported.empty")
                    } header: {
                        Text(hako: .copy(unsupportedTitle))
                            .accessibilityIdentifier(
                                "final-configuration.unsupported.heading"
                            )
                    }
                } else {
                    disclosureSection(
                        title: unsupportedTitle,
                        items: snapshot.unsupportedItems,
                        symbol: .xmarkCircle,
                        tint: .orange,
                        identifierFragment: "unsupported"
                    )
                }

                if Self.saysAllClear(
                    items: snapshot.adaptedItems,
                    planLoaded: planNoticesLoaded,
                    planNotices: planNotices
                ) {
                    Section {
                        disclosureLabel(
                            title: adaptedEmptyTitle,
                            detail: adaptedEmptyDetail,
                            symbol: .checkmarkCircle,
                            tint: .green
                        )
                        .accessibilityIdentifier("final-configuration.adapted.empty")
                    } header: {
                        Text(hako: .copy(adaptedTitle))
                            .accessibilityIdentifier(
                                "final-configuration.adapted.heading"
                            )
                    }
                } else {
                    disclosureSection(
                        title: adaptedTitle,
                        items: snapshot.adaptedItems,
                        symbol: .arrowTriangle2Circlepath,
                        tint: .green,
                        identifierFragment: "adapted"
                    )
                }

                blockedRuleSetsSection
                planNoticesSection

                coreDeviationsSection
            }
            .task(id: snapshot.effectiveText) {
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                deviations = nil
                deviations = await command?.configDeviations()

                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                if deviations == nil {
                    deviations = Self.offlineDeviations(for: snapshot.effectiveText)
                    deviationsAreOffline = deviations != nil
                } else if let live = deviations, live.document != nil,
                          !live.describes(snapshot.effectiveText) {
                     
                     
                     
                     
                     
                     
                     
                    deviations = Self.offlineDeviations(for: snapshot.effectiveText)
                    deviationsAreOffline = deviations != nil
                } else {
                    deviationsAreOffline = false
                }

                 
                 
                 
                 
                if let report = deviations, let written = comparisonYAML, let base = baseYAML {
                    let spoken = Set(report.deviations.map(\.configKey))
                    deviations = report.appending(
                        ClientDocumentDeviations
                            .rows(written: written, running: base, locale: locale)
                            .filter { !spoken.contains($0.configKey) }
                    )
                }
            }
             
             
             
            .task(id: snapshot.effectiveText) {
                 
                 
                 
                guard let text = snapshot.effectiveText else {
                     
                     
                     
                    planNotices = []
                    planNoticesLoaded = false
                    return
                }
                planNoticesLoaded = false
                planNotices = await Task.detached(priority: .utility) {
                     
                     
                     
                     
                     
                     
                     
                     
                    (try? ConfigTransforms.planResources(mergedYAML: text).notices) ?? []
                }.value
                planNoticesLoaded = true
            }
             
             
             
             
             
             
            .task(id: snapshot.effectiveText) {
                guard let loader = blockedRuleSetsLoader else {
                    blockedRuleSets = []
                    return
                }
                 
                 
                blockedRuleSets = await Task.detached(priority: .utility) {
                    await loader()
                }.value
            }
            .hakoInsetGroupedListStyle()
            .hakoPageTitle(.copy(title))
            .hakoFeaturePresentation(
                ownsNavigationContainer: ownsNavigationContainer
            )
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    if ownsNavigationContainer {
                        HakoSheetCloseButton { dismiss() }
                            .accessibilityIdentifier(
                                "final-configuration.done"
                            )
                    }
                }
            }
        }
#if os(macOS)
         
         
         
        .hakoProductModal(
            isPresented: $showsPreviewText,
            role: .form,
            macOSPanelRole: .page
        ) {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            HakoDeferredPageContent {
                FinalConfigurationTextView(
                    title: .copy(previewKind.rawValue),
                    text: selectedText
                )
            } placeholder: {
                HakoPageLoadingPlaceholder(
                    title: .copy("Opening Configuration")
                )
            }
            .hakoProductModalRoot(title: previewKind.rawValue)
        }
#endif
        .hakoCapturesDismiss(dismiss)
    }

    private var selectedText: String? {
        switch previewKind {
        case .source: return snapshot.sourceText
        case .effective: return snapshot.effectiveText
        }
    }

#if os(macOS)
     
     
     
    private func sectionExplanationRow(_ copy: String) -> some View {
        Text(hako: .copy(copy))
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
#endif

    @ViewBuilder
    private func disclosureSection(
        title: String,
        items: [ProfileFinalConfigurationDisclosure],
        symbol: HakoSymbol,
        tint: Color,
         
         
         
         
         
        identifierFragment: String
    ) -> some View {
        Section {
            ForEach(items) { item in
                disclosureLabel(
                    title: item.title,
                    detail: item.detail,
                    strippedKeys: item.strippedKeys,
                    symbol: symbol,
                    tint: tint
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("final-configuration.\(identifierFragment).\(item.id)")
            }
        } header: {
            Text(hako: .copy(title))
                .accessibilityIdentifier(
                    "final-configuration.\(identifierFragment).heading"
                )
        }
    }

     
     
     
     
     
     
     
     
     
    private func kernelVerdictRow(for finalYAML: String) -> some View {
         
         
         
         
        HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.compact) {
            Image(
                systemName: verdict?.ok ?? true
                    ? HakoSymbol.checkmarkCircleFill.rawValue
                    : HakoSymbol.exclamationmarkTriangleFill.rawValue
            )
            .foregroundStyle(verdict?.ok ?? true ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(hako: verdict == nil
                    ? "Checking with the core…"
                    : (verdict?.ok == true
                        ? "The core accepts this configuration"
                        : "The core refuses this configuration"))
                    .font(.subheadline)
                if let message = verdict?.errorMessage, !message.isEmpty {
                     
                     
                    Text(hako: .verbatim(message))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .accessibilityIdentifier("final-configuration.kernel-verdict")
         
         
         
         
         
         
         
        .accessibilityValue(
            verdict == nil ? "checking"
                : (verdict?.ok == true ? "accepted" : "refused")
        )
        .task(id: finalYAML) {
            let yaml = finalYAML
            verdict = await Task.detached(priority: .userInitiated) {
                PreflightService.check(finalYAML: yaml)
            }.value
        }
    }

     
     
     
     
     
    @ViewBuilder
    private var blockedRuleSetsSection: some View {
        if !blockedRuleSets.isEmpty {
            Section {
                ForEach(blockedRuleSets) { set in
                    HStack(alignment: .firstTextBaseline, spacing: HakoTheme.Spacing.compact) {
                        Image(systemName: HakoSymbol.xmarkCircle.rawValue)
                            .foregroundStyle(Color.orange)
                        VStack(alignment: .leading, spacing: 2) {
                             
                             
                             
                            Text(hako: .verbatim(set.name))
                                .font(.subheadline.weight(.medium))
                            Text(hako: .verbatim(set.reason))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(
                        "final-configuration.mrs.\(set.name)"
                    )
                }
            } header: {
                Text(hako: .copy("Rule Sets Not in the Runtime"))
                    .accessibilityIdentifier(
                        "final-configuration.mrs.heading"
                    )
            } footer: {
                Text(hako: .copy("Rule sets run from their compiled MRS form. A set that cannot be compiled is left out of the runtime — its rules never match. Each line is the core's own sentence."))
            }
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func saysAllClear(
        items: [ProfileFinalConfigurationDisclosure],
        planLoaded: Bool,
        planNotices: [String]
    ) -> Bool {
        items.isEmpty && planLoaded && planNotices.isEmpty
    }

     
     
     
     
     
     
     
     
    @ViewBuilder
    private var planNoticesSection: some View {
        if !planNotices.isEmpty {
            Section {
                ForEach(Array(planNotices.enumerated()), id: \.offset) { index, notice in
                    Text(hako: .verbatim(notice))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("final-configuration.plan-notice.\(index)")
                }
            } header: {
                Text(hako: .copy("What the Client Adapted"))
                    .accessibilityIdentifier("final-configuration.plan-notices.heading")
            } footer: {
                Text(hako: .copy("Written while preparing this configuration, before the core started. Each line is the core's own sentence about one field."))
            }
        }
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private var coreDeviationsSection: some View {
        if let report = deviations {
            Section {
                if report.isEmpty, report.describes(snapshot.effectiveText) {
                     
                     
                     
                     
                     
                     
                     
                    disclosureLabel(
                        title: "The core honoured every field",
                        detail: "Nothing in this configuration was removed, replaced or left inert by the core that is running.",
                        symbol: .checkmarkCircle,
                        tint: .green
                    )
                    .accessibilityIdentifier("final-configuration.deviations.empty")
                } else if report.isEmpty {
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    EmptyView()
                } else {
                    ForEach(report.deviations) { deviation in
                        ConfigDeviationRow(
                            deviation: deviation,
                            identifierPrefix: "final-configuration.deviation"
                        )
                    }
                }
#if os(macOS)
                sectionExplanationRow(deviationsAreOffline
                    ? "The core read the configuration above and answered without starting anything. Nothing is running."
                    : "Reported by the core itself for the configuration it is running, not derived from the text above. A profile that is not the running one is not described here.")
#endif
            } header: {
                Text(deviationsAreOffline
                     ? "What the Core Would Do"
                     : "What the Running Core Did")
                    .accessibilityIdentifier(
                        "final-configuration.deviations.heading"
                    )
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                     
                    .accessibilityValue("\(deviations?.deviations.count ?? 0)")
            } footer: {
#if !os(macOS)
                Text(deviationsAreOffline
                     ? "The core read the configuration above and answered without starting anything. Nothing is running."
                     : "Reported by the core itself for the configuration it is running, not derived from the text above. A profile that is not the running one is not described here.")
#endif
            }
        }
    }


     
     
     
     
     
     
     
    static func offlineDeviations(for effectiveText: String?) -> ConfigDeviationReport? {
        guard let effectiveText, !effectiveText.isEmpty else { return nil }
        return try? ConfigTransforms.configDeviations(
            configContent: effectiveText,
            targetProfile: hakoAppleRuntimeProfile.rawValue
        )
    }

    private func disclosureLabel(
        title: String,
        detail: String,
        strippedKeys: [String] = [],
        symbol: HakoSymbol,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: HakoTheme.Spacing.row) {
            HakoIconWell(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: HakoTheme.Spacing.tight) {
                Text(hako: .copy(title))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(hako: .copy(detail))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !strippedKeys.isEmpty {
                     
                     
                     
                    Text("Stripped: \(strippedKeys.joined(separator: ", "))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(
                            "Stripped keys: \(strippedKeys.joined(separator: ", "))"
                        )
                }
            }
        }
        .padding(.vertical, HakoTheme.Spacing.tight)
    }
}

private struct FinalConfigurationTextView: View {
    let title: HakoDisplayText
    private let isAvailable: Bool
    @State private var text: String

    init(title: HakoDisplayText, text: String?) {
        self.title = title
        isAvailable = text != nil
        _text = State(initialValue: text ?? "")
    }

    var body: some View {
        ZStack {
            HakoTheme.canvas.ignoresSafeArea()
            if isAvailable {
                CodeEditorPanel(
                    text: $text,
                    language: .yaml,
                    minHeight: 360,
                    isEditable: false,
                    expandsVertically: true
                )
                .padding(HakoTheme.Spacing.standard)
            } else {
                HakoEmptyState(
                    title: "Configuration Unavailable",
                    message: "Activate or sync this profile first.",
                    symbol: .docTextMagnifyingglass
                )
            }
        }
        .hakoPageTitle(title, watchAs: "profile-preview")
        .hakoDetailPageInsets()
    }
}
