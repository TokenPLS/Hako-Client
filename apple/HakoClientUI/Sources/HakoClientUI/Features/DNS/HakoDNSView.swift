import Foundation
import SwiftUI

public struct HakoDNSCapabilities: Sendable {
    public typealias Probe = @Sendable (
        String
    ) async -> HakoDNSResolverOutcome
    public typealias SelfCheck = @Sendable (
    ) async -> HakoDNSSelfCheckOutcome
    public typealias GeoValues = @Sendable (
        HakoDNSGeoResource
    ) async -> [String]

    public let probe: Probe
    public let resolverSummary:
        @Sendable (String) -> String?
    public let resolverRejectionReason:
        @Sendable (String) -> String?
    public let bootstrapRejectionReason:
        @Sendable ([String]) -> String?
    public let isResolverTestable:
        @Sendable (String) -> Bool
    public let loadGeoValues: GeoValues
    public let selfCheck: SelfCheck?
     
     
     
    public let inherited: HakoDNSOverrideDraft.Inherited
     
     
    public let ruleProviders: HakoDNSRuleProviders

    public init(
        probe: @escaping Probe,
        resolverSummary:
            @escaping @Sendable (String) -> String? = {
            HakoDNSResolverAddress.summary(for: $0)
        },
        resolverRejectionReason:
            @escaping @Sendable (String) -> String? = {
            HakoDNSResolverAddress.rejectionReason(for: $0)
        },
        bootstrapRejectionReason:
            @escaping @Sendable ([String]) -> String? = {
            values in
            for value in values {
                if let reason =
                    HakoDNSResolverAddress.rejectionReason(for: value)
                {
                    return reason
                }
            }
            return nil
        },
        isResolverTestable:
            @escaping @Sendable (String) -> Bool = {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty
        },
        loadGeoValues: @escaping GeoValues = { _ in [] },
        selfCheck: SelfCheck? = nil,
        inherited: HakoDNSOverrideDraft.Inherited = .none,
        ruleProviders: HakoDNSRuleProviders = .unknown
    ) {
        self.probe = probe
        self.resolverSummary = resolverSummary
        self.resolverRejectionReason = resolverRejectionReason
        self.bootstrapRejectionReason = bootstrapRejectionReason
        self.inherited = inherited
        self.ruleProviders = ruleProviders
        self.isResolverTestable = isResolverTestable
        self.loadGeoValues = loadGeoValues
        self.selfCheck = selfCheck
    }
}

 
 
 
 
public struct HakoDNSSettingsView<
    Icon: View,
    DNSQuery: View
>: View {
    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let capabilities: HakoDNSCapabilities
    private let icon: (HakoSymbol) -> Icon
     
     
     
     
     
    private let dnsQueryDestination: () -> DNSQuery

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @State private var draft: HakoDNSOverrideDraft
     
     
     
     
     
    @State private var openedWith: HakoDNSOverrideDraft
    @State private var error = ""
    @Environment(\.locale) private var locale
    @Environment(\.hakoRootDepartureGuard) private var rootDepartureGuard
    @State private var saveRefusal: String?
    @State private var asksAboutUnsaved = false
     
     
    @State private var departureRegistrationID = UUID()
    @State private var selfCheckState = HakoDNSSelfCheckState.idle
    @StateObject private var saveCoordinator = HakoDNSSaveCoordinator()

     
     
     
     
    private var hasUnsavedEdits: Bool { draft != openedWith }

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        capabilities: HakoDNSCapabilities,

        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        @ViewBuilder dnsQueryDestination: @escaping () -> DNSQuery
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.capabilities = capabilities
        self.icon = icon
        self.dnsQueryDestination = dnsQueryDestination
        _draft = State(initialValue: snapshot.dns.draft)
        _openedWith = State(initialValue: snapshot.dns.draft)
    }

    public var body: some View {
         
         
         
         
        HakoMacSettingsFormContainer(
            scopeFooter: snapshot.dns.profileName == nil
                ? .copy("These settings apply to every profile.")
                : nil
        ) {
            if let profileName = snapshot.dns.profileName {
                Section {
                    HakoProfileContextHeader(
                        profileName: profileName,
                        message:
                            "These settings apply to every profile. Imported sources stay unchanged."
                    ) {
                        icon(.profileClipboard)
                    }
                }
            }

            Section {
                if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                    HakoMacToggleRow(
                        snapshot.dns.profileName == nil
                            ? "Override DNS"
                            : "Customize DNS for all profiles",
                        isOn: $draft.overrideDNS
                    )
                    .accessibilityIdentifier("profile-dns.customize")
                } else {
                    Toggle(
                        snapshot.dns.profileName == nil
                            ? "Override DNS"
                            : "Customize DNS for all profiles",
                        isOn: $draft.overrideDNS
                    )
                    .accessibilityIdentifier("profile-dns.customize")
                }
            } footer: {
                 
                 
                 
                 
                Text(
                    "Off: a profile with its own DNS keeps it; the settings below still apply to profiles without one. Turn it on to change them for every profile."
                )
                .hakoMacSettingsFootnote()
            }

             
             
             
             
             
             
            let shownDraft: Binding<HakoDNSOverrideDraft> =
                draft.overrideDNS || snapshot.dns.inherited.overridesApplyWhileToggleOff
                    ? $draft
                    : .constant(HakoDNSOverrideDraft())
            Group {
                InheritedEntriesSection(
                    title: "Nameserver",
                    state: listState(
                        override: shownDraft.wrappedValue.nameserver.isEmpty ? nil : shownDraft.wrappedValue.nameserver,
                        inherited: snapshot.dns.inherited.list("dns.nameserver"),
                        upstreamDefault: UpstreamListDefault.pinned(for: "dns.nameserver")
                    ),
                    identifier: "profile-dns.nameserver.inherited",
                    follow: { draft.nameserver = [] }
                )
                HakoDNSResolverListView(
                    items: shownDraft.nameserver,
                    identifier: "profile-dns.nameserver",
                    title: "Nameserver",
                    footnote: nil,
                    showsProbeNote: false,
                    emptyState:
                        "Empty means each profile's own nameservers are used.",
                    capabilities: capabilities,
                    icon: icon
                )

                Section {
                    if snapshot.dns.localMappingsAvailable {
                        HakoRoutedViewLink {
                            HakoDNSLocalMappingsView(
                                snapshot: snapshot,
                                actions: actions,
                                icon: icon
                            )
                            .hakoPushedDetailPage()
                        } label: {
                            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                                HakoMacNavigationRowLabel(
                                    "Local Mapping",
                                    value: countLabel(
                                        snapshot.dns.localMappings.count,
                                        singular: "entry",
                                        plural: "entries"
                                    ).map { .copy($0) }
                                )
                            } else {
                                HakoDNSHubRow(
                                    title: "Local Mapping",
                                    detail: "Pin a domain to an address",
                                    value: countLabel(
                                        snapshot.dns.localMappings.count,
                                        singular: "entry",
                                        plural: "entries"
                                    )
                                )
                            }
                        }
                        .accessibilityIdentifier(
                            "profile-dns.hub.local-mapping"
                        )
                    }

                    HakoDNSFieldRows.triStatePicker(
                        "Use Local Mapping",
                        selection: shownDraft.useHosts,
                        inherited: snapshot.dns.inherited.bool("dns.use-hosts"),
                        upstreamDefault: UpstreamBoolDefault.value(for: "dns.use-hosts"),
                        identifier: "profile-dns.use-hosts"
                    )
                    HakoDNSFieldRows.triStatePicker(
                        "Use system hosts",
                        selection: shownDraft.useSystemHosts,
                        inherited: snapshot.dns.inherited.bool("dns.use-system-hosts"),
                        upstreamDefault: UpstreamBoolDefault.value(for: "dns.use-system-hosts"),
                        identifier: "profile-dns.use-system-hosts"
                    )

                    HakoRoutedViewLink {
                        HakoDeferredDraftHost(source: shownDraft) { local in
                            HakoDNSAdvancedView(
                                draft: local,
                                snapshot: snapshot.dns,
                                capabilities: capabilities,
                                icon: icon
                            )
                        }
                        .hakoPushedDetailPage()
                    } label: {
                        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                            HakoMacNavigationRowLabel("Advanced")
                        } else {
                            HakoDNSHubRow(
                                title: "Advanced",
                                detail:
                                    "Nameserver policy · Fallback · Fake-IP · Cache",
                                value: nil
                            )
                        }
                    }
                    .accessibilityIdentifier(
                        "profile-dns.hub.advanced"
                    )
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            "Use Local Mapping consults the entries above; Use system hosts also reads the device's own hosts file."
                        )
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                        Text(
                            "Local Mapping is a top-level `hosts:` setting rather than part of `dns:`, so it applies even to a profile that brings its own DNS, and it keeps applying while this switch is off."
                        )
                    }
                    .hakoMacSettingsFootnote()
                }
            }
            .disabled(!draft.overrideDNS)

            if snapshot.dns.selfCheckAvailable,
               capabilities.selfCheck != nil
            {
                selfCheckSection
            }

            if !error.isEmpty {
                Section {
                    Label {
                        Text(error)
                            .foregroundStyle(.secondary)
                    } icon: {
                        icon(.exclamationmarkTriangleFill)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                HakoRoutedViewLink {
                    dnsQueryDestination()
                    .hakoPushedDetailPage()
                } label: {
                    if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                        HakoMacNavigationRowLabel(
                            "DNS Query",
                             
                             
                             
                             
                             
                            value: snapshot.dns.canQueryRuntime
                                ? nil
                                : "Connect Clash first"
                        )
                    } else {
                        HStack(spacing: HakoTheme.Spacing.row) {
                            icon(.globeAsiaAustralia)
                                .foregroundStyle(.primary)
                                .frame(width: 28, height: 28)

                            VStack(
                                alignment: .leading,
                                spacing: HakoTheme.Spacing.tight
                            ) {
                                Text("DNS Query")
                                    .foregroundStyle(.primary)
                                Text(
                                    snapshot.dns.canQueryRuntime
                                        ? "Resolve a name through the DNS service currently running in the tunnel."
                                        : "Connect Clash to query the DNS service running in the tunnel."
                                )
                                .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.footnote : .footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                            }

                            Spacer(minLength: HakoTheme.Spacing.compact)
                             
                             
                             
                             
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(!snapshot.dns.canQueryRuntime)
                .accessibilityIdentifier("profile-dns.open-query")
            } header: {
                Text("Runtime")
            } footer: {
                Text(
                    "DNS cache maintenance is available from the query screen."
                )
                .hakoMacSettingsFootnote()
            }
        }
        
        .disabled(saveCoordinator.isBusy)
         
         
        .hakoRootHeading(
            snapshot.dns.profileName == nil ? "DNS" : "DNS Settings"
        )
        .alert(
            "No resolver answered",
            isPresented: Binding(
                get: { saveCoordinator.warning != nil },
                 
                 
                 
                 
                set: { _ in }
            )
        ) {
            Button("Save Anyway") {
                saveCoordinator.saveAnyway()
            }
            Button("Keep Editing", role: .cancel) {
                saveCoordinator.keepEditing()
            }
        } message: {
            Text(saveCoordinator.warning ?? "")
        }
        .alert(
            "Cannot Save",
            isPresented: Binding(
                get: { saveRefusal != nil },
                set: { if !$0 { saveRefusal = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveRefusal = nil }
        } message: {
            Text(hako: .verbatim(saveRefusal ?? ""))
        }
        .alert("Save your changes?", isPresented: $asksAboutUnsaved) {
             
             
             
             
            Button("Save") { persist() }
                .disabled(saveCoordinator.isBusy)
            Button("Discard", role: .destructive) {
                discardChangesAndDismiss()
            }
            .disabled(saveCoordinator.isBusy)
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("These DNS settings have changes that have not been saved.")
        }
         
         
         
         
        .hakoBackButtonHidden(hasUnsavedEdits)
         
         
         
        .hakoToolbarUnlessInPanel { toolbarItems }
        .accessibilityIdentifier("profile-dns.screen")
        .onChange(of: snapshot.dns.draft) { updated in
             
             
             
             
             
            guard draft == openedWith else {
                openedWith = updated
                return
            }
            draft = updated
            openedWith = updated
        }
        .onAppear { refreshRootDepartureRegistration() }
        .onChange(of: hasUnsavedEdits) { _ in
            refreshRootDepartureRegistration()
        }
        .onChange(of: saveCoordinator.phase) { _ in
            refreshRootDepartureRegistration()
        }
        .hakoCapturesDismiss(dismiss)
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
             
             
             
             
             
             
             
             
             
            if hasUnsavedEdits {
                Button("Cancel") {
                    asksAboutUnsaved = true
                }
                .disabled(saveCoordinator.isBusy)
                .accessibilityIdentifier("profile-dns.cancel")
            }
        }
        ToolbarItem(placement: .confirmationAction) {
             
             
             
             
             
            Button {
                persist()
            } label: {
                Text(hako: .copy(saveButtonTitle))
            }
             
             
             
             
             
             
            .disabled(saveCoordinator.phase != .idle || !hasUnsavedEdits)
            .accessibilityIdentifier("profile-dns.save")
        }
    }

    private var saveButtonTitle: String {
        switch saveCoordinator.phase {
        case .checking: "Checking…"
        case .committing: "Saving…"
        case .idle, .awaitingWarning: "Save"
        }
    }

    private var selfCheckSection: some View {
        Section {
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                HakoMacActionRow(
                    "Is DNS working",
                     
                     
                     
                    actionTitle: "Check DNS now",
                    action: { runSelfCheck() }
                ) {
                    if selfCheckState.isRunning {
                        ProgressView().controlSize(.small)
                    }
                }
                .accessibilityIdentifier("profile-dns.self-check")
            } else {
                Button {
                    runSelfCheck()
                } label: {
                    HStack {
                        Text("Check DNS now")
                        Spacer(minLength: HakoTheme.Spacing.compact)
                        if selfCheckState.isRunning {
                            ProgressView()
                        } else {
                            icon(.arrowClockwise)
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .accessibilityIdentifier("profile-dns.self-check")
            }

            if let verdict = selfCheckState.verdict {
                Text(hako: verdict)
                    .font(.callout)
                    .foregroundStyle(
                        selfCheckState.isFailure
                            ? Color.orange
                            : Color.secondary
                    )
                    .accessibilityIdentifier(
                        "profile-dns.self-check.verdict"
                    )
            }

            if selfCheckState.isFailure, draft.overrideDNS {
                Button(
                    "Use each profile's own DNS again",
                    role: .destructive
                ) {
                    draft.overrideDNS = false
                }
                .accessibilityIdentifier(
                    "profile-dns.self-check.recover"
                )
            }
        } header: {
            if !HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                Text("Is DNS working")
            }
        } footer: {
            Text(
                "A and AAAA are resolved the way every app on this device resolves, so Local Mappings and Fake-IP show up here exactly as they affect your traffic. Other record types are asked of the core's configured resolvers."
            )
            .hakoMacSettingsFootnote()
        }
    }

    private func persist(completion: ((Bool) -> Void)? = nil) {
        if let validationError {
            error = validationError
             
             
             
            saveRefusal = validationError
            completion?(false)
            return
        }
        let candidate = draft
        let accepted = saveCoordinator.save(
            draft: candidate,
            preflight: { candidate in
                guard candidate.overrideDNS else { return nil }
                let verdict = await HakoDNSPreSaveCheck.run(
                    nameserver: candidate.nameserver,
                    policyResolvers:
                        candidate.nameserverPolicy.flatMap(\.resolvers),
                    isTestable: capabilities.isResolverTestable,
                    probe: capabilities.probe
                )
                return HakoDNSPreSaveCheck.warning(for: verdict)
            },
            commit: { candidate in
                try await actions.perform(
                    .dns(.saveSettings(candidate)),
                    allowedBy: snapshot
                )
            },
            completion: { outcome in
                switch outcome {
                case .saved(let saved):
                    openedWith = saved
                    completion?(true)
                    dismiss()
                case .failed(let message):
                    error = message
                    completion?(false)
                case .cancelled:
                    completion?(false)
                }
            }
        )
        if !accepted {
            completion?(false)
        }
    }

    private var validationError: String? {
        if let reason = draft.scalarValidationError {
            return HakoCopy.string(reason, locale: locale)
        }
        if let reason = draft.crossFieldValidationError(
            inherited: capabilities.inherited
        ) {
            return HakoCopy.string(reason, locale: locale)
        }
        if let reason = capabilities.bootstrapRejectionReason(
            draft.defaultNameserver
        ) {
            return HakoCopy.format(
                "Default nameserver: %@.",
                locale: locale,
                HakoCopy.string(reason, locale: locale)
            )
        }
        for (label, values) in [
            ("Nameserver", draft.nameserver),
            ("Fallback", draft.fallback),
            ("Proxy-server nameserver", draft.proxyServerNameserver),
            ("Direct nameserver", draft.directNameserver),
        ] {
            if let reason = values.compactMap(
                capabilities.resolverRejectionReason
            ).first {
                return "\(HakoCopy.string(label, locale: locale)): "
                    + HakoCopy.string(reason, locale: locale)
            }
        }
        for (label, entries) in [
            ("Nameserver policy", draft.nameserverPolicy),
            (
                "Proxy-server policy",
                draft.proxyServerNameserverPolicy
            ),
        ] {
            if let reason = entries.flatMap(\.resolvers).compactMap(
                capabilities.resolverRejectionReason
            ).first {
                return "\(HakoCopy.string(label, locale: locale)): "
                    + HakoCopy.string(reason, locale: locale)
            }
            for entry in entries {
                if let reason = HakoDNSPolicyKey.rejectionReason(
                    entry.key,
                    ruleProviders: capabilities.ruleProviders
                ) {
                     
                     
                     
                    return "\(HakoCopy.string(label, locale: locale)): "
                        + reason.resolved(locale: locale)
                }
            }
        }
        return nil
    }

    private func discardChangesAndDismiss() {
        saveCoordinator.cancel()
        draft = openedWith
        dismiss()
    }

    private func refreshRootDepartureRegistration() {
        rootDepartureGuard?.register(
            id: departureRegistrationID,
            isDirty: hasUnsavedEdits,
            isBusy: saveCoordinator.isBusy,
            save: { completion in persist(completion: completion) },
            discard: {
                saveCoordinator.cancel()
                draft = openedWith
            }
        )
    }

    private func runSelfCheck() {
        guard let check = capabilities.selfCheck else {
            return
        }
        selfCheckState = .running
        Task {
            selfCheckState = .finished(await check())
        }
    }

    private func openDNSQuery() {
        Task {
            try? await actions.perform(
                .dns(.openDNSQuery),
                allowedBy: snapshot
            )
        }
    }

    private func countLabel(
        _ count: Int,
        singular: String,
        plural: String
    ) -> String? {
        guard count > 0 else {
            return nil
        }
        return "\(count) \(count == 1 ? singular : plural)"
    }
}

public struct HakoDNSLocalMappingsView<Icon: View>: View {
    private let snapshot: AppleClientSnapshot
    private let actions: AppleClientActions
    private let icon: (HakoSymbol) -> Icon

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @State private var mappings: [HakoDNSLocalMapping]
    @State private var editing: HakoDNSMappingEdit?
    @State private var error = ""
    @State private var isSaving = false

    public init(
        snapshot: AppleClientSnapshot,
        actions: AppleClientActions,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.snapshot = snapshot
        self.actions = actions
        self.icon = icon
        _mappings = State(
            initialValue: snapshot.dns.localMappings
        )
    }

     
     
     
     
    @State private var rows = HakoIdentifiedRows()

    public var body: some View {
        HakoMacSettingsContainer {
            Section {
                ForEach(rows.current(for: mappings)) { row in
                    let mapping = rows.index(of: row.id).map { mappings[$0] }
                        ?? HakoDNSLocalMapping(domain: "", addresses: [])
                    HakoMacDeletableRow(onDelete: {
                        rows.remove(row.id, from: &mappings)
                    }) {
                    Button {
                        editing = HakoDNSMappingEdit(
                            rowID: row.id,
                            mapping: mapping
                        )
                    } label: {
                        HStack {
                            Text(mapping.domain)
                                .font(.body.monospaced())
                                .foregroundStyle(.primary)
                            Spacer(
                                minLength: HakoTheme.Spacing.compact
                            )
                            Text(
                                mapping.addresses.joined(
                                    separator: " | "
                                )
                            )
                            .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .callout.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            effectMark(mapping.effect)
                        }
                         
                         
                         
                         
                         
                         
                        .contentShape(Rectangle())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(
                        "profile-hosts.entry.\(mapping.domain)"
                    )
                    .accessibilityValue(effectSpeech(mapping.effect))
                    .buttonStyle(.borderless)
                    .tint(.primary)
                    }
                    if let note = effectNote(mapping.effect) {
                        Text(hako: note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(
                                "profile-hosts.effect.\(mapping.domain)"
                            )
                    }
                }
                .onDelete {
                    rows.removeOffsets($0, from: &mappings)
                }
                .onAppear { rows.resync(count: mappings.count) }
                .onChange(of: mappings.count) { rows.resync(count: $0) }

                Button {
                    editing = HakoDNSMappingEdit(
                        rowID: nil,
                        mapping: HakoDNSLocalMapping(
                            domain: "",
                            addresses: []
                        )
                    )
                } label: {
                        Label {
                            Text("Add Mapping")
                        } icon: {
                            icon(.plus)
                        }
                    }
                .hakoMacListAddChrome()
                .accessibilityIdentifier("profile-hosts.add")
            } header: {
                Text("Local Mappings")
            } footer: {
                Text(
                    "A domain listed here resolves to the address you give it, before any resolver is asked."
                )
                .hakoMacSettingsFootnote()
            }

            if !error.isEmpty {
                Section {
                    Text(error)
                        .foregroundStyle(.orange)
                }
            }
        }
        .hakoPageTitle("Local Mapping")
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Save") {
                    persist()
                }
                .disabled(isSaving)
                .accessibilityIdentifier("profile-hosts.save")
            }
        }
        .sheet(item: $editing) { request in
            HakoDNSMappingEditor(
                mapping: request.mapping
            ) { updated in
                if let id = request.rowID {
                    rows.update(id, in: &mappings, to: updated)
                } else {
                    rows.append(updated, to: &mappings)
                }
                editing = nil
            } cancel: {
                editing = nil
            }
            .hakoModalPresentation(.form)
        }
        .accessibilityIdentifier("profile-hosts.screen")
        .hakoCapturesDismiss(dismiss)
    }

     
     
     
    @ViewBuilder
    private func effectMark(_ effect: HakoDNSLocalMappingEffect?) -> some View {
        switch effect {
        case .inEffect:
            icon(.checkmark)
                .font(.callout)
                .foregroundStyle(.green)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        default:
            icon(.exclamationmarkTriangle)
                .font(.callout)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
        }
    }

     
     
    private func effectNote(
        _ effect: HakoDNSLocalMappingEffect?
    ) -> HakoDisplayText? {
        switch effect {
        case .none, .inEffect:
            return nil
        case .resolvesElsewhere(let actual):
            return .format(
                "Not in effect — this name currently resolves to %@.",
                [actual.joined(separator: ", ")]
            )
        case .tunnelNotRunning:
            return .copy("Not in effect — Clash is not connected.")
        case .notYetApplied:
            return .copy("Saved. It applies the next time Clash connects.")
        case .nameNotResolved:
            return .copy("This name could not be resolved just now.")
        }
    }

    private func effectSpeech(_ effect: HakoDNSLocalMappingEffect?) -> Text {
        switch effect {
        case .inEffect: return Text("In effect")
        case .none: return Text("")
        default: return Text("Not in effect")
        }
    }


    private func persist() {
        let normalized = mappings.map {
            HakoDNSLocalMapping(
                domain: $0.domain.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                addresses: $0.addresses.map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }.filter { !$0.isEmpty }
            )
        }
        var seen = Set<String>()
        guard normalized.allSatisfy({
            !$0.domain.isEmpty
                && !$0.addresses.isEmpty
                && seen.insert($0.domain).inserted
        }) else {
            error =
                "Every local mapping needs a unique domain and at least one address."
            return
        }
        isSaving = true
        Task {
            do {
                try await actions.perform(
                    .dns(.saveLocalMappings(normalized)),
                    allowedBy: snapshot
                )
                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                 
                self.error = [
                    error.localizedDescription,
                    String(
                        localized:
                            "A mapping points a domain at an address: an IPv4 or IPv6 address, or another domain name."
                    ),
                ].joined(separator: "\n\n")
            }
        }
    }
}

 
 
public struct HakoDNSResolverCatalogPicker<Icon: View>: View {
    private let existing: [String]
    private let presets: [HakoDNSResolverPreset]
    private let allowsCustomAddress: Bool
    private let capabilities: HakoDNSCapabilities
    private let icon: (HakoSymbol) -> Icon
    private let add: (String) -> Void

    public init(
        existing: [String],
        presets: [HakoDNSResolverPreset] =
            HakoDNSResolverCatalog.presets,
        allowsCustomAddress: Bool = true,
        capabilities: HakoDNSCapabilities,
        @ViewBuilder icon: @escaping (HakoSymbol) -> Icon,
        add: @escaping (String) -> Void
    ) {
        self.existing = existing
        self.presets = presets
        self.allowsCustomAddress = allowsCustomAddress
        self.capabilities = capabilities
        self.icon = icon
        self.add = add
    }

    public var body: some View {
        HakoDNSResolverCatalogView(
            existing: existing,
            presets: presets,
            allowsCustomAddress: allowsCustomAddress,
            capabilities: capabilities,
            icon: icon,
            add: add
        )
    }
}

private enum HakoDNSSelfCheckState {
    case idle
    case running
    case finished(HakoDNSSelfCheckOutcome)

    var isRunning: Bool {
        if case .running = self {
            true
        } else {
            false
        }
    }

    var isFailure: Bool {
        if case .finished(let outcome) = self {
            outcome.isFailure
        } else {
            false
        }
    }

     
     
     
    var verdict: HakoDisplayText? {
        switch self {
        case .idle, .running:
            nil
        case .finished(.answered(let name, let milliseconds)):
            .format("Resolved %@ in %@ ms.", [name, "\(milliseconds)"])
        case .finished(.noAnswer(let detail)):
            .copy(
                "\(detail) Names cannot be resolved with these settings on this network."
            )
        case .finished(.notConnected):
            .copy(
                "Connect first: while the VPN is off, the system resolver is in use, not this profile's."
            )
        }
    }
}

 
 
 
 
 
 
private enum DNSDoorRoute: String, Identifiable {
    case policy, fallback, filter, direct, proxyServer, defaultNS, fakeIP
    var id: String { rawValue }
}

private struct HakoDNSAdvancedView<Icon: View>: View {
    @State private var advancedDoor: DNSDoorRoute?
    @Binding var draft: HakoDNSOverrideDraft
    let snapshot: HakoDNSSnapshot
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon

    @ViewBuilder
    private func doorDestination(_ route: DNSDoorRoute) -> some View {
        switch route {
        case .policy:
                    HakoDeferredDraftHost(source: $draft.nameserverPolicy) { entries in
                     
                     
                     
                    let _ = HakoPageProbe.sink?(
                        "dns.door.policy entries=\(entries.wrappedValue.count)"
                            + " arm=\(entries.wrappedValue.isEmpty ? "editor" : "list")"
                    )
                     
                     
                     
                     
                     
                     
                     
                    if entries.wrappedValue.isEmpty {
                        HakoDNSPolicyEntrySheet(
                            title: "Nameserver policy",
                            entry: HakoDNSPolicyEntry(key: "", resolvers: []),
                            identifier: "profile-dns.nameserver-policy.new",
                            ruleSets: snapshot.ruleSets,
                            capabilities: capabilities,
                            icon: icon,
                             
                             
                             
                             
                             
                             
                             
                             
                             
                             
                            save: { updated in
                                entries.wrappedValue.append(updated)
                            },
                            cancel: { advancedDoor = nil },
                             
                             
                             
                             
                            leave: {}
                        )
                    } else {
                    HakoDNSPolicyListPage(
                        entries: entries,
                        identifier: "profile-dns.nameserver-policy",
                        title: "Nameserver policy",
                        footnote:
                            "Checked first: a matching domain is resolved by this policy's own resolvers.",
                        ruleSets: snapshot.ruleSets,
                        capabilities: capabilities,
                        icon: icon
                    )
                    }
                    }
                    .hakoPushedDetailPage()
        case .fallback:
                    HakoDeferredDraftHost(source: $draft.fallback) { items in
                    HakoDNSResolverSlotView(
                        title: "Fallback resolvers",
                        items: items,
                        identifier: "profile-dns.fallback",
                        footnote:
                            "Queried alongside the nameservers; the filter decides which answer is used.",
                        emptyState:
                            "Empty means only the nameservers answer.",
                        toggleTitle:
                            "Query fallback only when needed",
                        toggle: $draft.fallbackLazyQuery,
                        toggleIdentifier:
                            "profile-dns.fallback-lazy-query",
                        toggleInherited: snapshot.inherited.bool("dns.fallback-lazy-query"),
                        toggleUpstreamDefault: UpstreamBoolDefault.value(for: "dns.fallback-lazy-query"),
                        toggleFootnote:
                            "On, fallback resolvers are queried only after the nameservers answer.",
                        inherited: snapshot.inherited.list("dns.fallback"),
                        upstreamDefault: UpstreamListDefault.pinned(for: "dns.fallback"),
                        capabilities: capabilities,
                        icon: icon
                    )
                    }
                    .hakoPushedDetailPage()
        case .filter:
                    HakoDeferredDraftHost(source: $draft) { local in
                        HakoDNSFallbackFilterView(
                            draft: local,
                            inherited: snapshot.inherited,
                            capabilities: capabilities,
                            icon: icon
                        )
                    }
                    .hakoPushedDetailPage()
        case .direct:
                    HakoDeferredDraftHost(source: $draft.directNameserver) { items in
                    HakoDNSResolverSlotView(
                        title: "Direct-connection nameserver",
                        items: items,
                        identifier:
                            "profile-dns.direct-nameserver",
                        footnote:
                            "Re-resolves hostnames for traffic that goes out directly.",
                        emptyState:
                            "Empty means direct traffic follows the nameservers above.",
                        toggleTitle:
                            "Direct traffic follows the policy above",
                        toggle:
                            $draft.directNameserverFollowPolicy,
                        toggleIdentifier:
                            "profile-dns.direct-follow-policy",
                        toggleInherited: snapshot.inherited.bool("dns.direct-nameserver-follow-policy"),
                        toggleUpstreamDefault: UpstreamBoolDefault.value(for: "dns.direct-nameserver-follow-policy"),
                        toggleFootnote: nil,
                        inherited: snapshot.inherited.list("dns.direct-nameserver"),
                        upstreamDefault: UpstreamListDefault.pinned(for: "dns.direct-nameserver"),
                        capabilities: capabilities,
                        icon: icon
                    )
                    }
                    .hakoPushedDetailPage()
        case .proxyServer:
                    HakoDeferredDraftHost(source: $draft) { local in
                        HakoDNSProxyResolverSlotView(
                            draft: local,
                            inherited: snapshot.inherited,
                            ruleSets: snapshot.ruleSets,
                            capabilities: capabilities,
                            icon: icon
                        )
                    }
                    .hakoPushedDetailPage()
        case .defaultNS:
                    HakoDeferredDraftHost(source: $draft.defaultNameserver) { items in
                    HakoDNSResolverSlotView(
                        title: "Default nameserver",
                        items: items,
                        identifier:
                            "profile-dns.default-nameserver",
                        footnote:
                            "Resolves the hostnames of the resolvers above. Must be a plain IP.",
                        emptyState:
                            "Empty means the profile's own bootstrap is used.",
                        bootstrapOnly: true,
                        toggleTitle: nil,
                        toggle: nil,
                        toggleIdentifier: nil,
                        toggleInherited: nil,
                        toggleUpstreamDefault: nil,
                        toggleFootnote: nil,
                        inherited: snapshot.inherited.list("dns.default-nameserver"),
                        upstreamDefault: UpstreamListDefault.pinned(for: "dns.default-nameserver"),
                        capabilities: capabilities,
                        icon: icon
                    )
                    }
                    .hakoPushedDetailPage()
        case .fakeIP:
                    HakoDeferredDraftHost(source: $draft) { local in
                        HakoDNSFakeIPView(draft: local, inherited: snapshot.inherited)
                    }
                    .hakoPushedDetailPage()
        }
    }

    private func doorTitle(_ route: DNSDoorRoute) -> String {
        switch route {
        case .policy: "Nameserver policy"
        case .fallback: "Fallback"
        case .filter: "Fallback filter"
        case .direct: "Direct-connection nameserver"
        case .proxyServer: "Proxy-server nameserver"
        case .defaultNS: "Default nameserver"
        case .fakeIP: "Fake-IP"
        }
    }

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                HakoDNSFieldRows.optionPicker(
                    "DNS mode",
                    selection: $draft.enhancedMode,
                    options: HakoDNSOverrideDraft.dnsModes,
                    inherited: snapshot.inherited.text("dns.enhanced-mode"),
                    upstreamDefault: UpstreamTextDefault.pinned(for: "dns.enhanced-mode"),
                    identifier: "profile-dns.mode"
                )
                HakoDNSFieldRows.triStatePicker(
                    "Return IPv6 results",
                    selection: $draft.ipv6,
                    inherited: snapshot.inherited.bool("dns.ipv6"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "dns.ipv6"),
                    identifier: "profile-dns.ipv6"
                )
                HakoDNSFieldRows.trailingNumberField(
                    "IPv6 wait (ms)",
                    text: $draft.ipv6Timeout,
                    inherited: snapshot.inherited.number("dns.ipv6-timeout"),
                    upstreamDefault: UpstreamNumberDefault.pinned(for: "dns.ipv6-timeout"),
                    identifier: "profile-dns.ipv6-timeout"
                )
            } footer: {
                Text(
                    "Fake-IP answers instantly with a placeholder address and routes by domain; Redir Host returns the real address."
                )
                .hakoMacSettingsFootnote()
            }

            Section {
                HakoDoorLink(DNSDoorRoute.policy, selection: $advancedDoor) {
                    doorDestination(.policy)
                } label: {
                    HakoDNSHubRow(
                        title: "Nameserver policy",
                        detail:
                            "Send some domains to a specific resolver",
                        value: count(
                            draft.nameserverPolicy.count,
                            "rule",
                            "rules"
                        )
                    )
                }
                .accessibilityIdentifier("profile-dns.hub.policy")

                HakoDNSHubRow(
                    title: "Nameserver",
                    detail: "Set on the DNS page",
                    value: count(
                        draft.nameserver.count,
                        "resolver",
                        "resolvers"
                    ),
                    inlineDetail: true
                )

                HakoDoorLink(DNSDoorRoute.fallback, selection: $advancedDoor) {
                    doorDestination(.fallback)
                } label: {
                    HakoDNSHubRow(
                        title: "Fallback",
                        detail:
                            "Queried in parallel with the nameservers",
                        value: count(
                            draft.fallback.count,
                            "resolver",
                            "resolvers"
                        )
                    )
                }
                .accessibilityIdentifier(
                    "profile-dns.hub.fallback"
                )

                HakoDoorLink(DNSDoorRoute.filter, selection: $advancedDoor) {
                    doorDestination(.filter)
                } label: {
                    HakoDNSHubRow(
                        title: "Fallback filter",
                        detail: "Decides which answer to believe",
                        value: filterSummary
                    )
                }
                .accessibilityIdentifier("profile-dns.hub.filter")
            } header: {
                Text("Resolving a domain")
            } footer: {
                Text(
                    "Traffic that goes out directly is resolved once more by the direct-connection nameserver below."
                )
                .hakoMacSettingsFootnote()
            }

            Section {
                HakoDoorLink(DNSDoorRoute.direct, selection: $advancedDoor) {
                    doorDestination(.direct)
                } label: {
                    HakoDNSHubRow(
                        title: "Direct-connection nameserver",
                        detail:
                            "For traffic that bypasses the proxy",
                        value: count(
                            draft.directNameserver.count,
                            "resolver",
                            "resolvers"
                        )
                    )
                }
                .accessibilityIdentifier("profile-dns.hub.direct")

                HakoDoorLink(DNSDoorRoute.proxyServer, selection: $advancedDoor) {
                    doorDestination(.proxyServer)
                } label: {
                    HakoDNSHubRow(
                        title: "Proxy-server nameserver",
                        detail:
                            "Resolves the proxy nodes' own hostnames",
                        value: count(
                            draft.proxyServerNameserver.count,
                            "resolver",
                            "resolvers"
                        )
                    )
                }
                .accessibilityIdentifier(
                    "profile-dns.hub.proxy-server"
                )

                HakoDoorLink(DNSDoorRoute.defaultNS, selection: $advancedDoor) {
                    doorDestination(.defaultNS)
                } label: {
                    HakoDNSHubRow(
                        title: "Default nameserver",
                        detail: "Resolves the resolvers themselves",
                        value: count(
                            draft.defaultNameserver.count,
                            "resolver",
                            "resolvers"
                        )
                    )
                }
                .accessibilityIdentifier(
                    "profile-dns.hub.default"
                )
            } header: {
                Text("Dedicated resolvers")
            }

            Section {
                HakoDoorLink(DNSDoorRoute.fakeIP, selection: $advancedDoor) {
                    doorDestination(.fakeIP)
                } label: {
                    HakoDNSHubRow(
                        title: "Fake-IP",
                        detail: "Address pool and exceptions",
                        value: count(
                            draft.fakeIPFilter.count,
                            "exception",
                            "exceptions"
                        )
                    )
                }
                .accessibilityIdentifier("profile-dns.hub.fake-ip")
            } header: {
                Text("Other")
            }

            Section {
                HakoDNSFieldRows.optionPicker(
                    "Cache algorithm",
                    selection: $draft.cacheAlgorithm,
                    options: HakoDNSOverrideDraft.cacheAlgorithms,
                    inherited: snapshot.inherited.text("dns.cache-algorithm"),
                    upstreamDefault: UpstreamTextDefault.pinned(for: "dns.cache-algorithm"),
                    identifier: "profile-dns.cache-algorithm"
                )
                HakoDNSFieldRows.trailingNumberField(
                    "Maximum entries",
                    text: $draft.cacheMaxSize,
                    inherited: snapshot.inherited.number("dns.cache-max-size"),
                    upstreamDefault: UpstreamNumberDefault.pinned(for: "dns.cache-max-size"),
                    identifier: "profile-dns.cache-max-size"
                )
                HakoDNSFieldRows.triStatePicker(
                    "Follow routing rules",
                    selection: $draft.respectRules,
                    inherited: snapshot.inherited.bool("dns.respect-rules"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "dns.respect-rules"),
                    identifier: "profile-dns.respect-rules"
                )
                HakoDNSFieldRows.triStatePicker(
                    "Prefer HTTP/3",
                    selection: $draft.preferH3,
                    inherited: snapshot.inherited.bool("dns.prefer-h3"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "dns.prefer-h3"),
                    identifier: "profile-dns.prefer-h3"
                )
            } header: {
                Text("Cache")
            }

             
             
             
             
            if !HakoPlatformLayout.pageUsesSystemSettingsIdiom,
               let title = snapshot.managementTitle,
               !snapshot.managementRows.isEmpty
            {
                Section {
                    ForEach(snapshot.managementRows) { row in
                        HakoDNSManagementValueRow(row: row)
                    }
                } header: {
                    Text(hako: .copy(title))
                } footer: {
                    if let footer = snapshot.managementFooter {
                        Text(hako: .copy(footer))
                        .hakoMacSettingsFootnote()
                    }
                }
            }
        }
        .hakoDoorPresenter(
            selection: $advancedDoor,
            title: doorTitle
        ) { route in
            doorDestination(route)
        }
        .hakoPageTitle("Advanced")
        .accessibilityIdentifier("profile-dns.advanced.screen")
    }

    private func count(
        _ value: Int,
        _ singular: String,
        _ plural: String
    ) -> String? {
        guard value > 0 else {
            return nil
        }
        return "\(value) \(value == 1 ? singular : plural)"
    }

    private var filterSummary: String? {
        var values: [String] = []
        if draft.filterGeoIP == .on {
            values.append(
                "GeoIP "
                    + (
                        draft.filterGeoIPCode.isEmpty
                            ? "CN"
                            : draft.filterGeoIPCode.uppercased()
                    )
            )
        }
        let lists = draft.filterGeosite.count
            + draft.filterIPCIDR.count
            + draft.filterDomain.count
        if lists > 0 {
            values.append(
                "\(lists) \(lists == 1 ? "rule" : "rules")"
            )
        }
        return values.isEmpty
            ? nil
            : values.joined(separator: " · ")
    }
}

private struct HakoDNSManagementValueRow: View {
    let row: HakoDNSManagementRow

    @ViewBuilder
    var body: some View {
        if #available(
            iOS 16.0,
            macOS 13.0,
            tvOS 16.0,
            watchOS 9.0,
            *
        ) {
            ViewThatFits(in: .horizontal) {
                horizontalContent
                verticalContent
            }
        } else {
            verticalContent
        }
    }

    private var horizontalContent: some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            Text(hako: .copy(row.title))
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: HakoTheme.Spacing.row)
            Text(hako: .copy(row.value))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var verticalContent: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            Text(hako: .copy(row.title))
            Text(hako: .copy(row.value))
                .foregroundStyle(.secondary)
        }
    }
}

private struct HakoDNSResolverSlotView<Icon: View>: View {
    let title: String
    @Binding var items: [String]
    let identifier: String
    let footnote: String?
    let emptyState: String?
     
     
    var bootstrapOnly = false
    let toggleTitle: String?
    let toggle: Binding<HakoDNSTriState>?
    let toggleIdentifier: String?
     
    let toggleInherited: InheritedBase?
    let toggleUpstreamDefault: Bool?
    let toggleFootnote: String?
     
     
     
    let inherited: InheritedListBase
    let upstreamDefault: PinnedDefault<[String]>
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon

    var body: some View {
        HakoMacSettingsContainer {
            if let toggleTitle,
               let toggle,
               let toggleIdentifier,
               let toggleInherited,
               let toggleUpstreamDefault
            {
                Section {
                    HakoDNSFieldRows.triStatePicker(
                        toggleTitle,
                        selection: toggle,
                        inherited: toggleInherited,
                        upstreamDefault: toggleUpstreamDefault,
                        identifier: toggleIdentifier
                    )
                } footer: {
                    if let toggleFootnote {
                        Text(hako: .copy(toggleFootnote))
                        .hakoMacSettingsFootnote()
                    }
                }
            }
            InheritedEntriesSection(
                title: title,
                state: listState(
                    override: items.isEmpty ? nil : items,
                    inherited: inherited,
                    upstreamDefault: upstreamDefault
                ),
                identifier: identifier + ".inherited"
            )
            HakoDNSResolverListView(
                items: $items,
                bootstrapOnly: bootstrapOnly,
                identifier: identifier,
                title: title,
                footnote: footnote,
                emptyState: emptyState,
                capabilities: capabilities,
                icon: icon
            )
        }
        .hakoPageTitle(.copy(title))
        .accessibilityIdentifier("\(identifier).screen")
    }
}

private struct HakoDNSProxyResolverSlotView<
    Icon: View
>: View {
    @Binding var draft: HakoDNSOverrideDraft
    let inherited: HakoDNSInheritedBases
    let ruleSets: [String]
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon

    var body: some View {
        HakoMacSettingsContainer {
            InheritedEntriesSection(
                title: "Proxy-server nameserver",
                state: listState(
                    override: draft.proxyServerNameserver.isEmpty ? nil : draft.proxyServerNameserver,
                    inherited: inherited.list("dns.proxy-server-nameserver"),
                    upstreamDefault: UpstreamListDefault.pinned(for: "dns.proxy-server-nameserver")
                ),
                identifier: "profile-dns.proxy-server-nameserver.inherited"
            )
            HakoDNSResolverListView(
                items: $draft.proxyServerNameserver,
                identifier:
                    "profile-dns.proxy-server-nameserver",
                title: "Proxy-server nameserver",
                footnote:
                    "Resolves the hostnames of the proxy nodes themselves.",
                emptyState:
                    "Empty means node hostnames follow the nameservers above.",
                capabilities: capabilities,
                icon: icon
            )
            HakoDNSPolicyListSection(
                entries: $draft.proxyServerNameserverPolicy,
                identifier: "profile-dns.proxy-server-policy",
                title: "Proxy-server policy",
                footnote:
                    "Applies only while proxy-server nameservers are configured.",
                ruleSets: ruleSets,
                capabilities: capabilities,
                icon: icon
            )
        }
        .hakoPageTitle("Proxy-server nameserver")
        .accessibilityIdentifier(
            "profile-dns.proxy-server-nameserver.screen"
        )
    }
}

private struct HakoDNSFakeIPView: View {
    @Binding var draft: HakoDNSOverrideDraft
    let inherited: HakoDNSInheritedBases

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                HakoDNSFieldRows.trailingTextField(
                    "IPv4 pool",
                    text: $draft.fakeIPRange,
                    inherited: inherited.text("dns.fake-ip-range"),
                    upstreamDefault: UpstreamTextDefault.pinned(for: "dns.fake-ip-range"),
                    identifier: "profile-dns.fake-ip-range"
                )
                HakoDNSFieldRows.trailingTextField(
                    "IPv6 pool",
                    text: $draft.fakeIPRange6,
                    inherited: inherited.text("dns.fake-ip-range6"),
                    upstreamDefault: UpstreamTextDefault.pinned(for: "dns.fake-ip-range6"),
                    identifier: "profile-dns.fake-ip-range6"
                )
                HakoDNSFieldRows.trailingNumberField(
                    "Answer TTL",
                    text: $draft.fakeIPTTL,
                    inherited: inherited.number("dns.fake-ip-ttl"),
                    upstreamDefault: UpstreamNumberDefault.pinned(for: "dns.fake-ip-ttl"),
                    identifier: "profile-dns.fake-ip-ttl"
                )
            } header: {
                Text("Address pool")
            } footer: {
                Text(
                    "Fake-IP answers instantly with a placeholder address so routing can happen by domain."
                )
                .hakoMacSettingsFootnote()
            }
            Section {
                HakoDNSFieldRows.optionPicker(
                    "Exception behavior",
                    selection: $draft.fakeIPFilterMode,
                    options:
                        HakoDNSOverrideDraft.fakeIPFilterModes,
                    inherited: inherited.text("dns.fake-ip-filter-mode"),
                    upstreamDefault: UpstreamTextDefault.pinned(for: "dns.fake-ip-filter-mode"),
                    identifier:
                        "profile-dns.fake-ip-filter-mode"
                )
                InheritedEntriesSection(
                    title: "Exceptions",
                    state: listState(
                        override: draft.fakeIPFilter.isEmpty ? nil : draft.fakeIPFilter,
                        inherited: inherited.list("dns.fake-ip-filter"),
                        upstreamDefault: UpstreamListDefault.pinned(for: "dns.fake-ip-filter")
                    ),
                    identifier: "profile-dns.fake-ip-filter.inherited"
                )
                HakoDNSStringListEditor(
                    items: $draft.fakeIPFilter,
                    placeholder: "*.lan",
                    identifier: "profile-dns.fake-ip-filter"
                )
            } header: {
                Text("Exceptions")
            } footer: {
                Text(
                    "Domains listed here get a real address instead of a fake one. Rule mode also accepts DOMAIN, DOMAIN-SUFFIX, GEOSITE, RULE-SET and MATCH entries."
                )
                .hakoMacSettingsFootnote()
            }
        }
        .hakoPageTitle("Fake-IP")
        .accessibilityIdentifier("profile-dns.fake-ip.screen")
        
    }
}

private struct HakoDNSFallbackFilterView<
    Icon: View
>: View {
    @Binding var draft: HakoDNSOverrideDraft
    let inherited: HakoDNSInheritedBases
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                HakoDNSFieldRows.triStatePicker(
                    "Use GeoIP",
                    selection: $draft.filterGeoIP,
                    inherited: inherited.bool("dns.fallback-filter.geoip"),
                    upstreamDefault: UpstreamBoolDefault.value(for: "dns.fallback-filter.geoip"),
                    identifier:
                        "profile-dns.fallback.geoip"
                )
                HakoRoutedViewLink {
                    HakoDNSGeoValuePicker(
                        resource: .geoIP,
                        localizeRegions: true,
                        title: "Country / Region",
                        current: draft.filterGeoIPCode,
                        load: capabilities.loadGeoValues,
                        icon: icon
                    ) {
                        draft.filterGeoIPCode = $0.uppercased()
                    }
                    .hakoPushedDetailPage()
                } label: {
                    HStack {
                        Text("Country / Region")
                        Spacer(
                            minLength: HakoTheme.Spacing.compact
                        )
                        Text(
                            draft.filterGeoIPCode.isEmpty
                                ? "CN"
                                : draft.filterGeoIPCode
                                    .uppercased()
                        )
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier(
                    "profile-dns.fallback.geoip-code"
                )
            } footer: {
                Text(
                    "An answer whose address belongs to this country is treated as the local answer."
                )
                .hakoMacSettingsFootnote()
            }

            Section {
                InheritedEntriesSection(
                    title: "Answers to distrust · GeoSite",
                    state: listState(
                        override: draft.filterGeosite.isEmpty ? nil : draft.filterGeosite,
                        inherited: inherited.list("dns.fallback-filter.geosite"),
                        upstreamDefault: UpstreamListDefault.pinned(for: "dns.fallback-filter.geosite")
                    ),
                    identifier: "profile-dns.fallback.geosite.inherited"
                )
                HakoDNSGeoCategoryList(
                    items: $draft.filterGeosite,
                    identifier:
                        "profile-dns.fallback.geosite",
                    capabilities: capabilities,
                    icon: icon
                )
            } header: {
                Text("Answers to distrust · GeoSite")
            }

            Section {
                InheritedEntriesSection(
                    title: "Answers to distrust · IP range",
                    state: listState(
                        override: draft.filterIPCIDR.isEmpty ? nil : draft.filterIPCIDR,
                        inherited: inherited.list("dns.fallback-filter.ipcidr"),
                        upstreamDefault: UpstreamListDefault.pinned(for: "dns.fallback-filter.ipcidr")
                    ),
                    identifier: "profile-dns.fallback.ipcidr.inherited"
                )
                HakoDNSStringListEditor(
                    items: $draft.filterIPCIDR,
                    placeholder: "240.0.0.0/4",
                    identifier:
                        "profile-dns.fallback.ipcidr"
                )
            } header: {
                Text("Answers to distrust · IP range")
            }

            Section {
                InheritedEntriesSection(
                    title: "Answers to distrust · Domain",
                    state: listState(
                        override: draft.filterDomain.isEmpty ? nil : draft.filterDomain,
                        inherited: inherited.list("dns.fallback-filter.domain"),
                        upstreamDefault: UpstreamListDefault.pinned(for: "dns.fallback-filter.domain")
                    ),
                    identifier: "profile-dns.fallback.domain.inherited"
                )
                HakoDNSStringListEditor(
                    items: $draft.filterDomain,
                    placeholder: "+.google.com",
                    identifier:
                        "profile-dns.fallback.domain"
                )
            } header: {
                Text("Answers to distrust · Domain")
            }
        }
        .hakoPageTitle("Fallback filter")
        .accessibilityIdentifier(
            "profile-dns.fallback-filter.screen"
        )
        
    }
}


private struct HakoDNSResolverListView<
    Icon: View
>: View {
    @Binding var items: [String]
    var bootstrapOnly = false
    let identifier: String
    let title: String
    let footnote: String?
    var showsProbeNote = true
    let emptyState: String?
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon

    @State private var outcomes:
        [String: HakoDNSResolverOutcome] = [:]
    @State private var probing: Set<String> = []

     
     
     
     
    @State private var rows = HakoIdentifiedRows()

    var body: some View {
        Section {
            ForEach(rows.current(for: items)) { row in
                let address = rows.index(of: row.id).map { items[$0] } ?? ""
                HakoMacDeletableRow(onDelete: {
                    rows.remove(row.id, from: &items)
                }) {
                HakoDNSResolverRow(
                    address: address,
                    outcome: outcomes[address],
                    isProbing: probing.contains(address),
                    summary:
                        capabilities.resolverSummary(address),
                    canProbe:
                        capabilities.isResolverTestable(address),
                    probe: {
                        await probe(address)
                    }
                )
                .accessibilityIdentifier(
                    "\(identifier).item.\(row.index)"
                )
                }
            }
            .onDelete {
                rows.removeOffsets($0, from: &items)
            }
            .onAppear { rows.resync(count: items.count) }
            .onChange(of: items.count) { rows.resync(count: $0) }

            HakoRoutedViewLink {
                HakoDNSResolverCatalogView(
                    existing: items,
                     
                     
                     
                    presets: bootstrapOnly
                        ? HakoDNSResolverCatalog.bootstrapPresets
                        : HakoDNSResolverCatalog.presets,
                    allowsCustomAddress: true,
                    capabilities: capabilities,
                    icon: icon
                ) { address in
                    guard !items.contains(address) else {
                        return
                    }
                    items.append(address)
                }
                .hakoPushedDetailPage()
            } label: {
                Label {
                    Text("Add Resolver")
                } icon: {
                    icon(.plus)
                }
            }
            .accessibilityIdentifier("\(identifier).add")
        } header: {
            HStack {
                Text(hako: .copy(title))
                Spacer()
                if !items.isEmpty {
                    Button("Test All") {
                        Task {
                            await probeAll()
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .textCase(nil)
                    .accessibilityIdentifier(
                        "\(identifier).test-all"
                    )
                }
            }
        } footer: {
            VStack(
                alignment: .leading,
                spacing: HakoTheme.Spacing.tight
            ) {
                if items.isEmpty, let emptyState {
                    Text(hako: .copy(emptyState))
                    .hakoMacSettingsFootnote()
                        .accessibilityIdentifier(
                            "\(identifier).empty"
                        )
                }
                if let footnote {
                    Text(hako: .copy(footnote))
                    .hakoMacSettingsFootnote()
                }
                if showsProbeNote, !items.isEmpty {
                    Text(
                        "Test results come from this device on the current network."
                    )
                    .hakoMacSettingsFootnote()
                }
            }
        }
    }

    private func probe(_ address: String) async {
        probing.insert(address)
        let result = await capabilities.probe(address)
        probing.remove(address)
        outcomes[address] = result
    }

    private func probeAll() async {
        for address in items {
            await probe(address)
        }
    }
}

private struct HakoDNSResolverRow: View {
    let address: String
    let outcome: HakoDNSResolverOutcome?
    let isProbing: Bool
    let summary: String?
    let canProbe: Bool
    let probe: () async -> Void

    var body: some View {
        HStack(
            alignment: .center,
            spacing: HakoTheme.Spacing.standard
        ) {
            VStack(alignment: .leading, spacing: 3) {
                Text(address)
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .footnote.monospaced())
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                if let summary {
                    Text(hako: .copy(summary))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            if canProbe {
                Button {
                    Task {
                        await probe()
                    }
                } label: {
                    Group {
                        if isProbing {
                            ProgressView()
                        } else {
                            Text(hako: .copy(
                                HakoDNSResolverVerdict.text(
                                    for: outcome
                                ) ?? "Test"
                            ))
                            .fixedSize(
                                horizontal: true,
                                vertical: false
                            )
                            .foregroundStyle(verdictColor)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }

    private var verdictColor: Color {
        switch outcome {
        case .reachable:
            .green
        case .none, .notTestable:
            .secondary
        default:
            .orange
        }
    }
}

private enum HakoDNSResolverVerdict {
    static func text(
        for outcome: HakoDNSResolverOutcome?
    ) -> String? {
        switch outcome {
        case .none:
            nil
        case .reachable(let milliseconds):
            "\(milliseconds) ms"
        case .timedOut:
            "No answer"
        case .refused:
            "Connection refused"
        case .handshakeFailed:
            "TLS failed"
        case .invalidReply:
            "Unexpected reply"
        case .notTestable(let reason):
            reason
        }
    }
}

private struct HakoDNSResolverCatalogView<
    Icon: View
>: View {
    let existing: [String]
    let presets: [HakoDNSResolverPreset]
    let allowsCustomAddress: Bool
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon
    let add: (String) -> Void

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
     
     
     
     
     
    @Environment(\.hakoInsideModalPresentation) private var insideModal
    @State private var progress:
        HakoDNSResolverCatalogProgress
    @State private var probing: Set<String> = []
    @State private var isTestingAll = false
    @State private var customAddress = ""
    @State private var customError = ""

    init(
        existing: [String],
        presets: [HakoDNSResolverPreset],
        allowsCustomAddress: Bool,
        capabilities: HakoDNSCapabilities,
        icon: @escaping (HakoSymbol) -> Icon,
        add: @escaping (String) -> Void
    ) {
        self.existing = existing
        self.presets = presets
        self.allowsCustomAddress = allowsCustomAddress
        self.capabilities = capabilities
        self.icon = icon
        self.add = add
        _progress = State(
            initialValue: HakoDNSResolverCatalogProgress(
                presets: presets
            )
        )
    }

    var body: some View {
        let _ = HakoPushClock.note("catalogue-body")
        HakoSingleColumnNavigationContainer {
            List {
                Section {
                    ForEach(progress.rankedPresets) { preset in
                        row(for: preset)
                    }
                }

                if allowsCustomAddress {
                    Section {
                        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                            HakoMacFieldRow(
                                 
                                "Custom Address",
                                prompt: "udp / tcp / tls / https / quic address",
                                text: $customAddress,
                                monospaced: true
                            )
                            .accessibilityIdentifier("dns-catalog.custom")
                        } else {
                            TextField(
                                "udp / tcp / tls / https / quic address",
                                text: $customAddress
                            )
                            .font(.body.monospaced())
                            .accessibilityIdentifier(
                                "dns-catalog.custom"
                            )
                        }
                        Button("Add") {
                            addCustom()
                        }
                        .hakoMacFormActionChrome()
                        .disabled(
                            customAddress.trimmingCharacters(
                                in: .whitespaces
                            ).isEmpty
                        )
                        .accessibilityIdentifier(
                            "dns-catalog.custom.add"
                        )
                        if !customError.isEmpty {
                            Text(customError)
                                .foregroundStyle(.orange)
                        }
                    } header: {
                        Text("Custom Address")
                    } footer: {
                        Text(
                            "Written the way the active engine expects it."
                        )
                        .hakoMacSettingsFootnote()
                    }
                }
            }
            .hakoMacSettingsList()
            .hakoModalListMargins()
            .hakoPageTitle("Add Resolver")
             
             
             
             
             
            .hakoProductModalChild(
                title: "Add Resolver",
                actionTitle: "Test All",
                actionRole: .utility,
                actionDisabled: isTestingAll
                    || !probing.isEmpty
                    || presets.isEmpty,
                action: { Task { await probeAll() } }
            )
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                     
                     
                     
                    if insideModal {
                        HakoSheetCloseButton {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            await probeAll()
                        }
                    } label: {
                        if isTestingAll {
                            ProgressView()
                        } else {
                            Text("Test All")
                        }
                    }
                    .disabled(
                        isTestingAll
                            || !probing.isEmpty
                            || presets.isEmpty
                    )
                    .accessibilityLabel("Test All")
                    .accessibilityIdentifier(
                        "dns-catalog.test-all"
                    )
                }
            }
        }
        .accessibilityIdentifier("dns-catalog.screen")
        .hakoCapturesDismiss(dismiss)
    }

    private func row(
        for preset: HakoDNSResolverPreset
    ) -> some View {
        HStack(
            alignment: .center,
            spacing: HakoTheme.Spacing.standard
        ) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(preset.name)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Text(
                        capabilities.resolverSummary(
                            preset.address
                        ) ?? ""
                    )
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .caption)
                    .foregroundStyle(.secondary)
                }
                Text(preset.address)
                    .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.mono : .caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            if existing.contains(preset.address) {
                icon(.checkmarkCircleFill)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Added")
            } else {
                Button {
                    Task {
                        await probe(preset.address)
                    }
                } label: {
                    Group {
                        if probing.contains(preset.address) {
                            ProgressView()
                        } else {
                            Text(
                                HakoDNSResolverVerdict.text(
                                    for: progress.outcomes[
                                        preset.address
                                    ]
                                ) ?? "Test"
                            )
                            .fixedSize(
                                horizontal: true,
                                vertical: false
                            )
                            .foregroundStyle(
                                catalogVerdictColor(
                                    progress.outcomes[
                                        preset.address
                                    ]
                                )
                            )
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .disabled(
                    isTestingAll || !probing.isEmpty
                )
                .accessibilityIdentifier(
                    "dns-catalog.test.\(preset.address)"
                )

                Button {
                    add(preset.address)
                    dismiss()
                } label: {
                    icon(.plusCircleFill)
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel("Add")
                .accessibilityIdentifier(
                    "dns-catalog.add.\(preset.address)"
                )
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            "dns-catalog.preset.\(preset.address)"
        )
        .onAppear { HakoPushClock.note("catalogue-row") }
    }

    private func catalogVerdictColor(
        _ outcome: HakoDNSResolverOutcome?
    ) -> Color {
        switch outcome {
        case .none:
            .accentColor
        case .reachable:
            .green
        default:
            .orange
        }
    }

    private func addCustom() {
        let trimmed = customAddress.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let reason =
            capabilities.resolverRejectionReason(trimmed)
        {
            customError = reason
            return
        }
        customError = ""
        add(trimmed)
        dismiss()
    }

    private func probe(_ address: String) async {
        guard probing.isEmpty else {
            return
        }
        probing.insert(address)
        let result = await capabilities.probe(address)
        probing.remove(address)
        progress.record(address: address, outcome: result)
    }

    private func probeAll() async {
        guard !isTestingAll, probing.isEmpty else {
            return
        }
        isTestingAll = true
        defer {
            isTestingAll = false
        }
        for preset in presets {
            probing.insert(preset.address)
            let result =
                await capabilities.probe(preset.address)
            probing.remove(preset.address)
            progress.record(
                address: preset.address,
                outcome: result
            )
        }
    }
}

private struct HakoDNSPolicyListPage<
    Icon: View
>: View {
    @Binding var entries: [HakoDNSPolicyEntry]
    let identifier: String
    let title: String
    let footnote: String
    let ruleSets: [String]
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon

    var body: some View {
        HakoMacSettingsContainer {
            HakoDNSPolicyListSection(
                entries: $entries,
                identifier: identifier,
                title: title,
                footnote: footnote,
                ruleSets: ruleSets,
                capabilities: capabilities,
                icon: icon
            )
        }
        .hakoPageTitle(.copy(title))
        .accessibilityIdentifier("\(identifier).screen")
    }
}

private struct HakoDNSPolicyListSection<
    Icon: View
>: View {
    @Binding var entries: [HakoDNSPolicyEntry]
    let identifier: String
    let title: String
    let footnote: String
    let ruleSets: [String]
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon

    @Environment(\.hakoPopRoute) private var popRoute
     
     
     
     
     
    @State private var rows = HakoIdentifiedRows()

    private func entryBinding(
        _ id: UUID, fallback: HakoDNSPolicyEntry
    ) -> Binding<HakoDNSPolicyEntry> {
        Binding(
            get: { rows.index(of: id).map { entries[$0] } ?? fallback },
            set: { rows.update(id, in: &entries, to: $0) }
        )
    }

    var body: some View {
        Section {
            ForEach(rows.current(for: entries)) { row in
                let entry = rows.index(of: row.id).map { entries[$0] }
                    ?? HakoDNSPolicyEntry(key: "", resolvers: [])
                HakoMacDeletableRow(onDelete: {
                    rows.remove(row.id, from: &entries)
                }) {
                 
                 
                 
                 
                 
                 
                 
                 
                HakoRoutedViewLink {
                    HakoLazyView {
                        HakoDNSPolicyEntryView(
                            title: title,
                            entry: entryBinding(row.id, fallback: entry),
                            identifier: "\(identifier).entry",
                            ruleSets: ruleSets,
                            capabilities: capabilities,
                            icon: icon
                        )
                    }
                    .hakoPushedDetailPage()
                } label: {
                    policyRowLabel(entry)
                }
                .accessibilityIdentifier(
                    "\(identifier).item.\(row.index)"
                )
                }
            }
            .onDelete {
                rows.removeOffsets($0, from: &entries)
            }
            .onAppear { rows.resync(count: entries.count) }
            .onChange(of: entries.count) { rows.resync(count: $0) }

             
             
             
             
             
            HakoRoutedViewLink {
                HakoDNSPolicyEntrySheet(
                    title: title,
                    entry: HakoDNSPolicyEntry(key: "", resolvers: []),
                    identifier: "\(identifier).new",
                    ruleSets: ruleSets,
                    capabilities: capabilities,
                    icon: icon,
                    save: { updated in
                        rows.append(updated, to: &entries)
                    },
                     
                     
                     
                     
                     
                     
                     
                    cancel: {}
                )
                .hakoPushedDetailPage()
            } label: {
                Text("Add Policy")
            }
            .accessibilityIdentifier("\(identifier).add")
        } header: {
             
             
             
             
             
            EmptyView()
        } footer: {
            Text(hako: .copy(footnote))
            .hakoMacSettingsFootnote()
        }
    }

    @ViewBuilder
    private func policyRowLabel(
        _ entry: HakoDNSPolicyEntry
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(
                entry.key.isEmpty
                    ? "No match set"
                    : entry.key
            )
            .font(.body.monospaced())
            .lineLimit(1)
            Text(
                entry.resolvers.isEmpty
                    ? "No resolver set"
                    : entry.resolvers.joined(
                        separator: " · "
                    )
            )
            .font(HakoPlatformLayout.pageUsesSystemSettingsIdiom ? HakoMacSettingsType.value : .caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct HakoDNSPolicyEditRequest: Identifiable {
    let id = UUID()
     
     
    let rowID: UUID?
    let entry: HakoDNSPolicyEntry
}

 
 
 
private struct HakoDNSPolicyEntrySheet<Icon: View>: View {
    @Environment(\.hakoProductChromeApplied) private var chromeApplied
    let title: String
    let identifier: String
    let ruleSets: [String]
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon
    let save: (HakoDNSPolicyEntry) -> Void
    let cancel: () -> Void
     
     
     
     
     
     
     
     
     
     
    var leave: (() -> Void)? = nil

    @State private var draft: HakoDNSPolicyEntry
     
     
     
     
    @State private var openedWith: HakoDNSPolicyEntry?
     
     
     
     
     
     
     
     
     
    @State private var committed = false
     
     
     
    @State private var closeSelf = HakoDismissHandle()
     
     
     
    @Environment(\.hakoPopRoute) private var popRoute
     
     
     
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal

    init(
        title: String,
        entry: HakoDNSPolicyEntry,
        identifier: String,
        ruleSets: [String],
        capabilities: HakoDNSCapabilities,
        icon: @escaping (HakoSymbol) -> Icon,
        save: @escaping (HakoDNSPolicyEntry) -> Void,
        cancel: @escaping () -> Void,
        leave: (() -> Void)? = nil
    ) {
        self.title = title
        self.identifier = identifier
        self.ruleSets = ruleSets
        self.capabilities = capabilities
        self.icon = icon
        self.save = save
        self.cancel = cancel
        self.leave = leave
        _draft = State(initialValue: entry)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var isUsable: Bool {
        let match = HakoDNSPolicyMatchKind.split(draft.key)
        return !match.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

     
     
     
     
     
     
     
    private func leaveWithoutSaving() {
        cancel()
        HakoPushedPageExit.leave(popRoute: popRoute, dismiss: closeSelf)
    }

     
    private func commitOnce() {
        guard !committed, isUsable else { return }
        committed = true
        save(draft)
         
         
         
         
         
         
        committed = false
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        if let leave {
            leave()
        } else {
            closeSelf()
        }
    }

    var body: some View {
        HakoSingleColumnNavigationContainer {
            HakoDNSPolicyEntryView(
                title: title,
                entry: $draft,
                identifier: identifier,
                ruleSets: ruleSets,
                capabilities: capabilities,
                icon: icon
            )
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            .hakoProductModalChild(title: title, backAction: leaveWithoutSaving)
             
             
            .background {
                Color.clear.onAppear {
                    HakoPageProbe.sink?(
                        "dns.policy-sheet insideModal=\(insideProductModal)"
                            + " chromeApplied=\(chromeApplied) title=\(title)"
                    )
                }
            }
             
             
             
             
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                    HakoModalActionBar(
                        primaryTitle: "Add",
                        primaryDisabled: !isUsable,
                        onPrimary: commitOnce
                    )
                }
            }
             
             
             
             
            .toolbar {
                 
                 
                 
                ToolbarItem(placement: .confirmationAction) {
                    if !insideProductModal {
                        HakoSaveButton(.copy("Add"), isEnabled: isUsable) { commitOnce() }
                            .font(.body.weight(.semibold))
                            .accessibilityIdentifier("\(identifier).save")
                    }
                }
            }
             
             
             
             
             
             
             
             
            .onAppear { if openedWith == nil { openedWith = draft } }
             
             
            .hakoRegistersDeparture(
                isDirty: openedWith.map { $0 != draft } ?? false,
                save: { completion in
                    commitOnce()
                    completion(true)
                },
                discard: { if let openedWith { draft = openedWith } }
            )
            .hakoCapturesDismiss(closeSelf)
        }
    }
}

private struct HakoDNSPolicyEntryView<
    Icon: View
>: View {
    let title: String
    @Binding var entry: HakoDNSPolicyEntry
    let identifier: String
    let ruleSets: [String]
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon

    @State private var kind: HakoDNSPolicyMatchKind
    @State private var matchValue: String
    @State private var resolvers: [String]

    init(
        title: String,
        entry: Binding<HakoDNSPolicyEntry>,
        identifier: String,
        ruleSets: [String],
        capabilities: HakoDNSCapabilities,
        icon: @escaping (HakoSymbol) -> Icon
    ) {
        self.title = title
        _entry = entry
        self.identifier = identifier
        self.ruleSets = ruleSets
        self.capabilities = capabilities
        self.icon = icon
        let split = HakoDNSPolicyMatchKind.split(
            entry.wrappedValue.key
        )
        _kind = State(initialValue: split.kind)
        _matchValue = State(initialValue: split.value)
        _resolvers = State(
            initialValue: entry.wrappedValue.resolvers
        )
    }

    var body: some View {
        HakoMacSettingsFormContainer {
            Section {
                HakoRoutedViewLink {
                    HakoDNSPolicyKindPicker(
                        selection: $kind,
                        icon: icon
                    )
                    .hakoPushedDetailPage()
                } label: {
                    HStack {
                        Text("Match")
                        Spacer(
                            minLength: HakoTheme.Spacing.compact
                        )
                        Text(hako: .copy(kind.title))
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier(
                    "\(identifier).kind"
                )
                 
                 
                 
                 
                .onChange(of: kind) { _ in
                    matchValue = ""
                }

                switch kind {
                case .geosite:
                    HakoRoutedViewLink {
                        HakoDNSGeoValuePicker(
                            resource: .geoSite,
                            localizeRegions: false,
                            title: "GeoSite category",
                            current: matchValue,
                            load:
                                capabilities.loadGeoValues,
                            icon: icon
                        ) {
                            matchValue = $0
                        }
                        .hakoPushedDetailPage()
                    } label: {
                        selectionRow(
                            "Category",
                            value: matchValue
                        )
                    }
                    .accessibilityIdentifier(
                        "\(identifier).value.picker"
                    )
                case .ruleSet:
                    HakoDNSValuePickerLink(
                        title: "Rule set",
                        values: ruleSets,
                        current: matchValue,
                        icon: icon
                    ) {
                        matchValue = $0
                    }
                    .accessibilityIdentifier(
                        "\(identifier).value.picker"
                    )
                case .domain:
                    HStack {
                        Text("Value")
                        Spacer(
                            minLength: HakoTheme.Spacing.compact
                        )
                        TextField(
                            kind.placeholder,
                            text: $matchValue
                        )
                        .font(.body.monospaced())
                        .multilineTextAlignment(.trailing)
                        .accessibilityIdentifier(
                            "\(identifier).value"
                        )
                    }
                }
            } header: {
                Text("Which domains")
            } footer: {
                Text(hako: .copy(kind.summary))
                .hakoMacSettingsFootnote()
            }

            HakoDNSResolverListView(
                items: $resolvers,
                identifier: "\(identifier).resolvers",
                title: "Resolvers for these domains",
                footnote: "Matching queries go here first.",
                emptyState:
                    "Without a resolver this policy does nothing.",
                capabilities: capabilities,
                icon: icon
            )
        }
        
        .hakoPageTitle(.copy(title))
        .onChange(of: kind) { _ in
            commit()
        }
        .onChange(of: matchValue) { _ in
            commit()
        }
        .onChange(of: resolvers) { _ in
            commit()
        }
        .accessibilityIdentifier("\(identifier).screen")
    }

    private func selectionRow(
        _ label: String,
        value: String
    ) -> some View {
        HStack {
            Text(hako: .copy(label))
            Spacer(minLength: HakoTheme.Spacing.compact)
            Text(value.isEmpty ? "Required" : value)
                .font(.body.monospaced())
                .foregroundStyle(
                    value.isEmpty
                        ? Color.secondary
                        : Color.primary
                )
        }
    }

    private func commit() {
        entry = HakoDNSPolicyEntry(
            key: HakoDNSPolicyMatchKind.key(
                kind: kind,
                value: matchValue
            ),
            resolvers: resolvers
        )
    }
}

private struct HakoDNSPolicyKindPicker<
    Icon: View
>: View {
    @Binding var selection: HakoDNSPolicyMatchKind
    let icon: (HakoSymbol) -> Icon
     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()

    private var kindSelection: Binding<HakoDNSPolicyMatchKind?> {
        Binding(
             
             
            get: { nil },
            set: { value in
                guard let value else { return }
                selection = value
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        )
    }

    var body: some View {
        Group {
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                List(selection: kindSelection) {
                    ForEach(HakoDNSPolicyMatchKind.allCases) { kind in
                        HStack {
                            VStack(
                                alignment: .leading,
                                spacing: 3
                            ) {
                                Text(hako: .copy(kind.title))
                                    .font(.body.monospaced())
                                    .foregroundStyle(.primary)
                                Text(hako: .copy(kind.summary))
                                    .font(HakoMacSettingsType.value)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(
                                minLength: HakoTheme.Spacing.compact
                            )
                            if kind == selection {
                                icon(.checkmark)
                                    .foregroundStyle(
                                        .tint
                                    )
                            }
                        }
                        .tag(kind)
                        .accessibilityIdentifier(
                            "dns-policy.kind.\(kind.rawValue)"
                        )
                    }
                }
            } else {
                List {
                    ForEach(HakoDNSPolicyMatchKind.allCases) { kind in
                        Button {
                            selection = kind
                            dismiss()
                        } label: {
                            HStack {
                                VStack(
                                    alignment: .leading,
                                    spacing: 3
                                ) {
                                    Text(hako: .copy(kind.title))
                                        .font(.body.monospaced())
                                        .foregroundStyle(.primary)
                                    Text(hako: .copy(kind.summary))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(
                                    minLength: HakoTheme.Spacing.compact
                                )
                                if kind == selection {
                                    icon(.checkmark)
                                        .foregroundStyle(
                                            .tint
                                        )
                                }
                            }
                             
                             
                             
                             
                             
                             
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(
                            "dns-policy.kind.\(kind.rawValue)"
                        )
                    }
                }
            }
        }
        .hakoMacSettingsList()
        .modifier(HakoDNSGeoPickerChrome(
            title: "Match",
            sheetChrome: false
        ))
        .hakoCapturesDismiss(dismiss)
    }
}

private struct HakoDNSGeoValuePicker<
    Icon: View
>: View {
    let resource: HakoDNSGeoResource
    let localizeRegions: Bool
    let title: String
    let current: String
    let load: HakoDNSCapabilities.GeoValues
    let icon: (HakoSymbol) -> Icon
    let pick: (String) -> Void
    var sheetChrome = false
    var sheetDismiss: (() -> Void)? = nil

     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @State private var query = ""
    @State private var values: [String] = []
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded {
                 
                 
                 
                 
                 
                if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                    List(
                        filtered,
                        id: \.self,
                        selection: pickerSelection
                    ) { value in
                        HStack {
                            Text(display(value))
                            if let name = regionName(value) {
                                Text(name)
                                    .font(HakoMacSettingsType.value)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if value == current {
                                icon(.checkmark)
                                    .foregroundStyle(
                                        .tint
                                    )
                            }
                        }
                        .accessibilityIdentifier(
                            "rule-geo.\(value)"
                        )
                    }
                } else {
                List(filtered, id: \.self) { value in
                    Button {
                        pick(value)
                        dismiss()
                    } label: {
                        HStack {
                            Text(display(value))
                            if let name = regionName(value) {
                                Text(name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if value == current {
                                icon(.checkmark)
                                    .foregroundStyle(
                                        .tint
                                    )
                            }
                        }
                         
                         
                         
                         
                         
                         
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "rule-geo.\(value)"
                    )
                }
                }
            } else {
                ProgressView()
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity
                    )
                    .accessibilityIdentifier(
                        "rule-geo.loading"
                    )
            }
        }
        .hakoMacSettingsList(minRowHeight: 30)
         
         
         
         
        .modifier(HakoDNSGeoPickerChrome(
            title: title,
            sheetChrome: sheetChrome,
            searchText: $query,
            sheetDismiss: sheetDismiss
        ))
        .task {
            guard !loaded else {
                return
            }
            values = await load(resource)
            loaded = true
        }
        .hakoCapturesDismiss(dismiss)
    }

    private var pickerSelection: Binding<String?> {
        Binding(
             
             
             
             
            get: { nil },
            set: { value in
                guard let value else { return }
                pick(value)
                 
                 
                 
                 
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        )
    }

    private var filtered: [String] {
        guard !query.isEmpty else {
            return values
        }
        return values.filter {
            $0.localizedCaseInsensitiveContains(query)
                || (
                    regionName($0)?
                        .localizedCaseInsensitiveContains(query)
                        ?? false
                )
        }
    }

    private func display(_ value: String) -> String {
        localizeRegions && value.count == 2
            ? value.uppercased()
            : value
    }

    private func regionName(_ value: String) -> String? {
        guard localizeRegions, value.count == 2 else {
            return nil
        }
        return Locale.current.localizedString(
            forRegionCode: value.uppercased()
        )
    }
}

private struct HakoDNSGeoCategoryList<
    Icon: View
>: View {
    @Binding var items: [String]
    let identifier: String
    let capabilities: HakoDNSCapabilities
    let icon: (HakoSymbol) -> Icon

     
     
     
     
    @State private var rows = HakoIdentifiedRows()

    var body: some View {
        ForEach(rows.current(for: items)) { row in
            HakoMacDeletableRow(onDelete: {
                rows.remove(row.id, from: &items)
            }) {
            Text(rows.index(of: row.id).map { items[$0] } ?? "")
                .font(.body.monospaced())
                .accessibilityIdentifier(
                    "\(identifier).item.\(row.index)"
                )
            }
        }
        .onDelete {
            rows.removeOffsets($0, from: &items)
        }
        .onAppear { rows.resync(count: items.count) }
        .onChange(of: items.count) { rows.resync(count: $0) }
         
         
         
         
         
        HakoRoutedViewLink {
            HakoDNSGeoValuePicker(
                resource: .geoSite,
                localizeRegions: false,
                title: "GeoSite category",
                current: "",
                load: capabilities.loadGeoValues,
                icon: icon
            ) { value in
                guard !items.contains(value) else {
                    return
                }
                items.append(value)
            }
            .hakoPushedDetailPage()
        } label: {
            Text("Add Category")
        }
        .accessibilityIdentifier("\(identifier).add")
    }
}

private struct HakoDNSGeoPickerChrome: ViewModifier {
    let title: String
    let sheetChrome: Bool
    var searchText: Binding<String>? = nil
    var sheetDismiss: (() -> Void)? = nil
     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()
    @Environment(\.hakoNavigationHostContext) private var hostContext

    func body(content: Content) -> some View {
        Group {
             
             
             
             
             
             
            if sheetChrome || hostContext == .modal {
                content
                    .hakoModalListMargins()
                    .hakoNativeSheetChild(
                        title: title,
                        searchText: searchText,
                         
                         
                         
                         
                        backAction: sheetChrome
                            ? (sheetDismiss ?? { dismiss() })
                            : nil
                    )
            } else if let searchText {
                content
                    .hakoPageTitle(.copy(title))
                    .searchable(
                        text: searchText,
                        prompt: "Search code or name"
                    )
            } else {
                content
                    .hakoPageTitle(.copy(title))
            }
        }
        .hakoCapturesDismiss(dismiss)
    }
}

private struct HakoDNSValuePickerLink<
    Icon: View
>: View {
    let title: String
    let values: [String]
    let current: String
    let icon: (HakoSymbol) -> Icon
    let pick: (String) -> Void

    var body: some View {
         
         
         
         
         
         
         
        if values.isEmpty {
            HStack {
                Text(hako: .copy(title))
                Spacer()
                Text(hako: .copy("None in this profile"))
                    .foregroundStyle(.secondary)
            }
        } else {
            HakoRoutedViewLink {
                HakoDNSValuePicker(
                    title: title,
                    values: values,
                    current: current,
                    icon: icon,
                    pick: pick
                )
                .hakoPushedDetailPage()
            } label: {
                HStack {
                    Text(hako: .copy(title))
                    Spacer()
                    Text(current.isEmpty ? "Required" : current)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct HakoDNSValuePicker<
    Icon: View
>: View {
    let title: String
    let values: [String]
    let current: String
    let icon: (HakoSymbol) -> Icon
    let pick: (String) -> Void
     
     
     
     
     
     
    @State private var dismiss = HakoDismissHandle()

    private var pickerSelection: Binding<String?> {
        Binding(
             
             
             
             
            get: { nil },
            set: { value in
                guard let value else { return }
                pick(value)
                 
                 
                 
                 
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        )
    }

    var body: some View {
        Group {
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                List(
                    values,
                    id: \.self,
                    selection: pickerSelection
                ) { value in
                    HStack {
                        Text(value)
                            .foregroundStyle(.primary)
                        Spacer()
                        if value == current {
                            icon(.checkmark)
                                .foregroundStyle(
                                    .tint
                                )
                        }
                    }
                }
            } else {
                List(values, id: \.self) { value in
                    Button {
                        pick(value)
                        dismiss()
                    } label: {
                        HStack {
                            Text(value)
                                .foregroundStyle(.primary)
                            Spacer()
                            if value == current {
                                icon(.checkmark)
                                    .foregroundStyle(
                                        .tint
                                    )
                            }
                        }
                         
                         
                         
                         
                         
                         
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .hakoMacSettingsList(minRowHeight: 30)
        .modifier(HakoDNSGeoPickerChrome(
            title: title,
            sheetChrome: false
        ))
        .hakoCapturesDismiss(dismiss)
    }
}

private struct HakoDNSStringListEditor: View {
    @Binding var items: [String]
    let placeholder: String
    let identifier: String

     
     
     
     
     
     
    @State private var rows: HakoIdentifiedRows

    init(items: Binding<[String]>, placeholder: String, identifier: String) {
        _items = items
        self.placeholder = placeholder
        self.identifier = identifier
        _rows = State(
            initialValue: HakoIdentifiedRows(count: items.wrappedValue.count)
        )
    }

    private func text(for id: UUID) -> Binding<String> {
        Binding(
            get: { rows.index(of: id).map { items[$0] } ?? "" },
            set: { rows.update(id, in: &items, to: $0) }
        )
    }

    var body: some View {
        ForEach(rows.current(for: items)) { row in
            HakoMacDeletableRow(onDelete: {
                rows.remove(row.id, from: &items)
            }) {
            Group {
                if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                     
                     
                     
                    TextField(
                        text: text(for: row.id),
                        prompt: Text(placeholder),
                        label: { EmptyView() }
                    )
                    .labelsHidden()
                } else {
                    TextField(
                        placeholder,
                        text: text(for: row.id)
                    )
                }
            }
            .font(.body.monospaced())
            .accessibilityIdentifier(
                "\(identifier).item.\(row.index)"
            )
            }
        }
        .onDelete {
            rows.removeOffsets($0, from: &items)
        }
        .onChange(of: items.count) { count in
            rows.resync(count: count)
        }
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            HakoMacListAddRow("Add") {
                rows.append("", to: &items)
            }
            .accessibilityIdentifier("\(identifier).add")
        } else {
            Button("Add") {
                rows.append("", to: &items)
            }
            .accessibilityIdentifier("\(identifier).add")
        }
    }
}

private struct HakoDNSMappingEdit: Identifiable {
    let id = UUID()
     
     
    let rowID: UUID?
    let mapping: HakoDNSLocalMapping
}

private struct HakoDNSMappingEditor: View {
    let commit: (HakoDNSLocalMapping) -> Void
    let cancel: () -> Void
     
     
    @Environment(\.hakoInsideProductModalPresentation)
    private var insideProductModal

    @State private var domain: String
    @State private var address: String

    init(
        mapping: HakoDNSLocalMapping,
        commit: @escaping (HakoDNSLocalMapping) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.commit = commit
        self.cancel = cancel
        _domain = State(initialValue: mapping.domain)
        _address = State(
            initialValue: mapping.addresses.joined(
                separator: " | "
            )
        )
    }

     
    private var composedMapping: HakoDNSLocalMapping {
        HakoDNSLocalMapping(
            domain: domain.trimmingCharacters(in: .whitespacesAndNewlines),
            addresses: address
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    var body: some View {
        HakoSingleColumnNavigationContainer {
            HakoMacSettingsFormContainer {
                Section {
                    if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                        HakoMacFieldRow(
                            "Domain",
                            prompt: "example.local",
                            text: $domain,
                            monospaced: true
                        )
                        .accessibilityIdentifier("profile-hosts.new-domain")
                    } else {
                        TextField(
                            "example.local",
                            text: $domain
                        )
                        .font(.body.monospaced())
                        .accessibilityIdentifier(
                            "profile-hosts.new-domain"
                        )
                    }
                } header: {
                    Text("Domain")
                } footer: {
                    Text(
                        "Wildcards work: *.lan covers every name under lan."
                    )
                    .hakoMacSettingsFootnote()
                }
                Section {
                    if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                        HakoMacFieldRow(
                            "Resolves to",
                            prompt: "192.168.1.10",
                            text: $address,
                            monospaced: true
                        )
                        .accessibilityIdentifier("profile-hosts.new-address")
                    } else {
                        TextField(
                            "192.168.1.10",
                            text: $address
                        )
                        .font(.body.monospaced())
                        .accessibilityIdentifier(
                            "profile-hosts.new-address"
                        )
                    }
                } header: {
                    Text("Resolves to")
                } footer: {
                    Text(
                        "An IP address, or another domain. Separate several with |."
                    )
                    .hakoMacSettingsFootnote()
                }
            }
            
            .navigationTitle(
                domain.isEmpty
                    ? "Add Mapping"
                    : "Edit Mapping"
            )
            .hakoToolbarUnlessInPanel {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                         
                         
                         
                         
                         
                        .hakoMacCancelKey()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commit(composedMapping)
                    }
                    .disabled(isIncomplete)
                    .accessibilityIdentifier(
                        "profile-hosts.new.confirm"
                    )
                }
            }
             
             
             
             
             
             
             
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if insideProductModal {
                    HakoDialogActionBar(
                        onCancel: cancel,
                        confirmTitle: "Done",
                        confirmDisabled: isIncomplete
                    ) {
                        commit(composedMapping)
                    }
                }
            }
        }
    }

     
     
    private var isIncomplete: Bool {
        domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}



@MainActor
private enum HakoDNSFieldRows {
     
     
     
     
     
     
    static func triStatePicker(
        _ title: String,
        selection: Binding<HakoDNSTriState>,
        inherited: InheritedBase,
        upstreamDefault: Bool,
        identifier: String
    ) -> some View {
        let state = InheritedBool(
            base: inherited, override: selection.wrappedValue.boolValue, upstreamDefault: upstreamDefault
        )
        return menuRow(
            title: title,
            value: state.primaryTitle,
            subtitle: state.sourceLine,
            adopt: adoptAction(state.adoptProfileValueTitle, disagrees: state.profileDisagrees, identifier: identifier) {
                selection.wrappedValue = .inherited
            },
            identifier: identifier
        ) {
            Picker(title, selection: selection) {
                Text(hako: state.followTitle).tag(HakoDNSTriState.inherited)
                Text(hako: .copy("On")).tag(HakoDNSTriState.on)
                Text(hako: .copy("Off")).tag(HakoDNSTriState.off)
            }
        }
    }

     
     
     
    static func optionPicker(
        _ title: String,
        selection: Binding<String>,
        options: [String],
        inherited: InheritedTextBase,
        upstreamDefault: PinnedDefault<String>,
        identifier: String
    ) -> some View {
        let chosen = selection.wrappedValue
        let state = InheritedText(
            base: inherited,
            override: chosen == HakoDNSOverrideDraft.inheritedMode ? nil : chosen,
            upstreamDefault: upstreamDefault
        )
        return menuRow(
            title: title,
            value: state.resolved.map { .copy(modeTitle($0)) } ?? state.primaryTitle,
            subtitle: state.sourceLine,
            adopt: adoptAction(state.adoptProfileValueTitle, disagrees: state.profileDisagrees, identifier: identifier) {
                selection.wrappedValue = HakoDNSOverrideDraft.inheritedMode
            },
            identifier: identifier
        ) {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { value in
                    if value == HakoDNSOverrideDraft.inheritedMode {
                        Text(hako: state.followTitle).tag(value)
                    } else {
                        Text(hako: .copy(modeTitle(value))).tag(value)
                    }
                }
            }
        }
    }

    private static func menuRow<Content: View>(
        title: String,
        value: HakoDisplayText,
        subtitle: HakoDisplayText?,
        adopt: HakoInlineRowAction? = nil,
        identifier: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        HakoDNSMenuValueRow(
            title: title,
            value: value,
            subtitle: subtitle,
            adopt: adopt,
            identifier: identifier,
            content: content
        )
    }

     
     
     
     
     
    private static func adoptAction(
        _ title: HakoDisplayText, disagrees: Bool, identifier: String, follow: @escaping () -> Void
    ) -> HakoInlineRowAction? {
        guard disagrees else { return nil }
         
         
         
         
        return HakoInlineRowAction(title: title, identifier: "adopt-profile.\(identifier)", perform: follow)
    }

     
     
     
     
    static func trailingTextField(
        _ title: String,
        text: Binding<String>,
        inherited: InheritedTextBase,
        upstreamDefault: PinnedDefault<String>,
        identifier: String
    ) -> some View {
        let typed = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let state = InheritedText(base: inherited, override: typed.isEmpty ? nil : typed, upstreamDefault: upstreamDefault)
        return trailingField(
            title, placeholder: state.emptyHint, subtitle: state.sourceLine,
            adopt: adoptAction(state.adoptProfileValueTitle, disagrees: state.profileDisagrees, identifier: identifier) {
                text.wrappedValue = ""
            },
            text: text, identifier: identifier
        )
    }

     
    static func trailingNumberField(
        _ title: String,
        text: Binding<String>,
        inherited: InheritedNumberBase,
        upstreamDefault: PinnedDefault<Int>,
        identifier: String
    ) -> some View {
        let typed = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let state = InheritedNumber(base: inherited, override: Int(typed), upstreamDefault: upstreamDefault)
        return trailingField(
            title, placeholder: state.emptyHint, subtitle: state.sourceLine,
            adopt: adoptAction(state.adoptProfileValueTitle, disagrees: state.profileDisagrees, identifier: identifier) {
                text.wrappedValue = ""
            },
            text: text, identifier: identifier
        )
    }

    @ViewBuilder
    private static func trailingField(
        _ title: String,
        placeholder: String,
        subtitle: HakoDisplayText,
        adopt: HakoInlineRowAction? = nil,
        text: Binding<String>,
        identifier: String
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(hako: .copy(title))
                HStack(spacing: HakoTheme.Spacing.compact) {
                    Text(hako: subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let adopt {
                        HakoInlineRowActionLink(action: adopt)
                    }
                }
            }
            Spacer(minLength: HakoTheme.Spacing.compact)
            if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
                 
                 
                 
                 
                 
                TextField(
                    text: text,
                    prompt: Text(placeholder),
                    label: { EmptyView() }
                )
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .font(HakoMacSettingsType.mono)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 260)
                .accessibilityIdentifier(identifier)
            } else {
                TextField(placeholder, text: text)
                    .font(.body.monospaced())
                    .multilineTextAlignment(.trailing)
                    .accessibilityIdentifier(identifier)
            }
        }
    }

     
     
     
    private static func modeTitle(_ value: String) -> String {
        switch value {
        case "normal":
            "Standard"
        case "fake-ip":
            "Fake-IP"
        case "redir-host":
            "Redir Host"
        case "lru":
            "LRU"
        case "arc":
            "ARC"
        case "blacklist":
            "Exclude matching domains"
        case "whitelist":
            "Only matching domains"
        case "rule":
            "Evaluate as rules"
        default:
            value
        }
    }
}

private struct HakoDNSMenuValueRow<Content: View>: View {
    let title: String
    let value: HakoDisplayText
    let subtitle: HakoDisplayText?
     
     
     
    var adopt: HakoInlineRowAction? = nil
    let identifier: String
    @ViewBuilder let content: () -> Content

    @ViewBuilder
    var body: some View {
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
             
             
             
             
             
            content()
                .labelsHidden()
                .accessibilityLabel(Text(hako: .copy(title)))
                .accessibilityValue(accessibilityValue)
                .accessibilityIdentifier(identifier)
                .hakoSettingsMenuRow(title, subtitle: subtitle, adopt: adopt)
        } else if #available(
            iOS 16.0,
            macOS 13.0,
            tvOS 16.0,
            watchOS 9.0,
            *
        ) {
            ViewThatFits(in: .horizontal) {
                horizontalContent
                verticalContent
            }
        } else {
            verticalContent
        }
    }

     
     
    private var accessibilityValue: Text {
        subtitle.map { Text(hako: value) + Text(verbatim: ", ") + Text(hako: $0) } ?? Text(hako: value)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(hako: .copy(title))
                .foregroundStyle(.primary)
            if let subtitle {
                HStack(spacing: HakoTheme.Spacing.compact) {
                    Text(hako: subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let adopt {
                        HakoInlineRowActionLink(action: adopt)
                    }
                }
            }
        }
    }

    private var horizontalContent: some View {
        HStack(spacing: HakoTheme.Spacing.row) {
            titleBlock
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: HakoTheme.Spacing.row)
            menu
        }
    }

    private var verticalContent: some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            titleBlock
            menu
        }
    }

    private var menu: some View {
        Menu {
            content()
                .hakoFlattensMenuChoices()
        } label: {
            HStack(spacing: HakoTheme.Spacing.tight) {
                Text(hako: value)
                    .fixedSize(
                        horizontal: true,
                        vertical: false
                    )
                    .lineLimit(1)
                Image(
                    systemName:
                        HakoSymbol.chevronUpChevronDown
                            .rawValue
                )
                .font(.caption2)
            }
        }
         
        .hakoMenuRowChrome()
        .id("\(identifier)-\(value.rawValue)")
        .transaction {
            $0.animation = nil
        }
        .accessibilityLabel(Text(hako: .copy(title)))
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(identifier)
    }
}

public enum HakoDNSResolverAddress {
    public static func summary(for address: String) -> String? {
        let value = address.lowercased()
        if value.hasPrefix("https://") {
            return "DoH"
        }
        if value.hasPrefix("tls://") {
            return "DoT"
        }
        if value.hasPrefix("quic://") {
            return "DoQ"
        }
        if value.hasPrefix("tcp://") {
            return "TCP"
        }
        if value.hasPrefix("udp://") || !value.contains("://") {
            return "UDP"
        }
        return nil
    }

    public static func rejectionReason(for address: String) -> String? {
        let value = address.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !value.isEmpty else {
            return "Add a resolver address."
        }
        let supported = [
            "https://",
            "tls://",
            "quic://",
            "tcp://",
            "udp://",
        ]
        if value.contains("://"),
           !supported.contains(where: value.lowercased().hasPrefix)
        {
            return "Use a supported DNS transport."
        }
        return nil
    }
}
