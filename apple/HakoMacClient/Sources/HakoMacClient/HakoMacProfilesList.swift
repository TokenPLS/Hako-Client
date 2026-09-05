import HakoClientKit
import HakoClientUI
import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoMacProfilesList: View {
    let profiles: [HakoProfileSnapshot]
     
     
    let selectingProfileID: Profile.ID?
    let selectionFailure: (Profile.ID) -> HakoDisplayText?
    let select: (Profile.ID) -> Void
    let openDetail: (Profile.ID) -> Void
    let reorder: ([Profile.ID]) -> Void
    let addProfile: () -> Void
     
     
     
     
     
     
     
     
     
    let backupDestination: (() -> AnyView)?
    let sync: (Profile.ID) -> Void
    let duplicate: (Profile.ID) -> Void
    let export: (Profile.ID) -> Void
    let delete: (Profile.ID) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var pendingDeletion: HakoProfileSnapshot?
    @State private var showsBackup = false
     
     
     
     
     
    @State private var utcDay = Date()

    public init(
        profiles: [HakoProfileSnapshot],
        selectingProfileID: Profile.ID?,
        selectionFailure: @escaping (Profile.ID) -> HakoDisplayText?,
        select: @escaping (Profile.ID) -> Void,
        openDetail: @escaping (Profile.ID) -> Void,
        reorder: @escaping ([Profile.ID]) -> Void,
        addProfile: @escaping () -> Void,
        backupDestination: (() -> AnyView)? = nil,
        sync: @escaping (Profile.ID) -> Void,
        duplicate: @escaping (Profile.ID) -> Void,
        export: @escaping (Profile.ID) -> Void,
        delete: @escaping (Profile.ID) -> Void
    ) {
        self.profiles = profiles
        self.selectingProfileID = selectingProfileID
        self.selectionFailure = selectionFailure
        self.select = select
        self.openDetail = openDetail
        self.reorder = reorder
        self.addProfile = addProfile
        self.backupDestination = backupDestination
        self.sync = sync
        self.duplicate = duplicate
        self.export = export
        self.delete = delete
    }

    public var body: some View {
        List {
             
             
             
             
             
             
             
             
             
            Section {
                 
                 
                 
                 
                 
                 
                 
                ForEach(Array(profiles.enumerated()), id: \.element.id) {
                    index, profile in
                    row(profile)
                         
                         
                         
                         
                        .listRowSeparator(
                            index == profiles.count - 1 ? .hidden : .automatic,
                            edges: .bottom
                        )
                }
            }

            Section {
                addRow

                if let backupDestination {
                    backupRow(backupDestination)
                }
            }
        }
        .listStyle(.inset)
         
         
         
         
         
        .hakoProductModal(
            isPresented: $showsBackup,
            role: .form,
            macOSPanelRole: .page
        ) {
            backupDestination?() ?? AnyView(EmptyView())
        }
        .alert(
            Text(hako: .copy("Delete Profile")),
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            presenting: pendingDeletion
        ) { profile in
            Button(role: .destructive) {
                delete(profile.id)
                pendingDeletion = nil
            } label: {
                Text(hako: .copy("Delete"))
            }
            Button(role: .cancel) {
                pendingDeletion = nil
            } label: {
                Text(hako: .copy("Cancel"))
            }
        } message: { profile in
             
             
            Text(verbatim: profile.label)
        }
        .task {
             
             
             
            while !Task.isCancelled {
                let now = Date()
                let next = Self.expiryCalendar.nextDate(
                    after: now,
                    matching: DateComponents(hour: 0, minute: 0, second: 0),
                    matchingPolicy: .nextTime
                ) ?? now.addingTimeInterval(86_400)
                try? await Task.sleep(
                    for: .seconds(next.timeIntervalSince(now) + 1)
                )
                guard !Task.isCancelled else { return }
                utcDay = Date()
            }
        }
         
         
         
         
        .hakoPageProbe("profiles-list")
         
         
         
         
        .hakoFrameWatch("profiles-list")
    }

     
     
     
     
     
     
     
     
    private func row(_ profile: HakoProfileSnapshot) -> some View {
        HStack(spacing: HakoTheme.Spacing.compact) {
            Button {
                select(profile.id)
            } label: {
                HStack(spacing: HakoTheme.Spacing.compact) {
                     
                     
                     
                     
                     
                    statusSlot(profile)

                    VStack(alignment: .leading, spacing: 1) {
                         
                         
                         
                         
                        HStack(
                            alignment: .firstTextBaseline,
                            spacing: HakoTheme.Spacing.compact
                        ) {
                            Text(verbatim: profile.label)
                                .fontWeight(
                                    profile.isCurrent ? .semibold : .regular
                                )
                            if let fraction =
                                profile.subscription?.usageFraction,
                                !dynamicTypeSize.isAccessibilitySize {
                                Spacer(minLength: HakoTheme.Spacing.compact)
                                 
                                 
                                 
                                 
                                 
                                Text(hako: .format(
                                    "%@ used",
                                    ["\(Int(fraction * 100))%"]
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            }
                        }
                        Text(hako: profile.sourceSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let subscription = profile.subscription,
                           let fraction = subscription.usageFraction {
                            usageGauge(fraction: fraction)
                                .padding(.top, 3)
                            if dynamicTypeSize.isAccessibilitySize {
                                 
                                 
                                 
                                 
                                accessibilityUsageSummary(subscription)
                                    .padding(.top, 1)
                            } else if let expiration =
                                subscription.expiration {
                                Text(hako: .format(
                                    "until %@",
                                    [Self.expiryDateString(expiration)]
                                ))
                                .font(.caption)
                                .foregroundColor(
                                    expiryTint(expiration, now: utcDay)
                                )
                                .monospacedDigit()
                                .lineLimit(1)
                                .padding(.top, 1)
                            }
                        }
                         
                         
                        if let failure = selectionFailure(profile.id) {
                            Text(hako: failure)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier(
                                    "profiles.select-failure"
                                )
                        }
                    }

                    Spacer(minLength: HakoTheme.Spacing.row)
                }
                 
                 
                 
                 
                 
                 
                 
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
             
             
             
             
            .disabled(isBlocked(profile))
            .accessibilityIdentifier("profiles.row.\(profile.id.rawValue)")

            if profile.isBusy {
                ProgressView().controlSize(.small)
            }

             
             
             
             
             
             
             
             
             
            Button {
                openDetail(profile.id)
            } label: {
                Image(systemName: "chevron.forward")
                    .foregroundStyle(.secondary)
                    .frame(width: HakoTheme.Control.pointerRowTarget)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text(hako: .copy("Profile")))
            .accessibilityIdentifier("profiles.detail.\(profile.id.rawValue)")
        }
        .padding(.vertical, 2)
        .contextMenu {
             
             
             
            Button {
                move(profile.id, by: -1)
            } label: {
                Text(hako: .copy("Move Up"))
            }
            .disabled(HakoMacProfilesList.reordered(profiles, moving: profile.id, by: -1) == nil)

            Button {
                move(profile.id, by: 1)
            } label: {
                Text(hako: .copy("Move Down"))
            }
            .disabled(HakoMacProfilesList.reordered(profiles, moving: profile.id, by: 1) == nil)

            Divider()

            Button { sync(profile.id) } label: {
                Text(hako: .copy("Sync"))
            }
            Button { duplicate(profile.id) } label: {
                Text(hako: .copy("Duplicate"))
            }
            Button { export(profile.id) } label: {
                Text(hako: .copy("Export"))
            }
            if profile.canDelete {
                Divider()
                Button(role: .destructive) {
                    pendingDeletion = profile
                } label: {
                    Text(hako: .copy("Delete"))
                }
            }
        }
    }

     
     
    @ViewBuilder
    private func statusSlot(_ profile: HakoProfileSnapshot) -> some View {
        ZStack {
            if selectingProfileID == profile.id {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
                    .opacity(profile.isCurrent ? 1 : 0)
            }
        }
        .frame(width: 16)
    }

    private func isBlocked(_ profile: HakoProfileSnapshot) -> Bool {
        selectingProfileID != nil && selectingProfileID != profile.id
    }

     

     
     
     
     
     
     
     
     
     
     
    private func usageGauge(fraction: Double) -> some View {
        let clamped = min(max(fraction, 0), 1)
        let fill: Color = fraction >= 1 ? .red : .accentColor
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(fill.opacity(0.22))
                Capsule()
                    .fill(fill)
                     
                     
                    .frame(width: max(
                        6, proxy.size.width * CGFloat(clamped)
                    ))
            }
        }
        .frame(height: 6)
        .accessibilityLabel(Text(hako: .copy("Subscription usage")))
        .accessibilityValue(Text(hako: .format(
            "%@ percent", ["\(Int(fraction * 100))"]
        )))
    }

     
     
     
     
     
    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
            ?? TimeZone(secondsFromGMT: 0)!
        return formatter
    }()

    private static let expiryCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")
            ?? TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static func expiryDateString(_ date: Date) -> String {
        expiryFormatter.string(from: date)
    }

     
     
     
     
     
     
    private func accessibilityUsageSummary(
        _ subscription: HakoProfileSubscriptionSnapshot
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: HakoTheme.Spacing.tight
        ) {
            Text(
                "Uploaded \(Self.compactBytes(subscription.uploadBytes))"
            )
            Text(
                "Downloaded \(Self.compactBytes(subscription.downloadBytes))"
            )
            if subscription.totalBytes > 0 {
                Text(
                    "Total \(Self.compactBytes(subscription.totalBytes))"
                )
            }
            if let expiration = subscription.expiration {
                Text("Expires \(Self.expiryDateString(expiration))")
                    .foregroundStyle(expiryTint(expiration, now: utcDay))
            }
        }
        .font(.caption2)
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
    }

     
    private static func compactBytes(_ bytes: Int64) -> String {
        let units = ["K", "M", "G", "T"]
        var value = Double(max(0, bytes)) / 1_024
        var unit = 0
        while value >= 1_000, unit < units.count - 1 {
            value /= 1_024
            unit += 1
        }
        let text = value < 100
            ? String(format: "%.1f", value)
            : String(format: "%.0f", value)
        return text.replacingOccurrences(
            of: ".0",
            with: ""
        ) + units[unit]
    }

     
     
     
     
    private func expiryTint(_ expiration: Date, now: Date) -> Color {
        let days =
            Self.expiryCalendar.dateComponents(
                [.day],
                from: Self.expiryCalendar.startOfDay(for: now),
                to: Self.expiryCalendar.startOfDay(for: expiration)
            ).day ?? 0
        if days <= 0 { return .red }
        if days <= 7 { return .orange }
        return .secondary
    }

    private func move(_ id: Profile.ID, by offset: Int) {
        guard let ordered = Self.reordered(profiles, moving: id, by: offset) else {
            return
        }
        reorder(ordered)
    }

     
     
     
     
     
     
     
    static func reordered(
        _ profiles: [HakoProfileSnapshot],
        moving id: Profile.ID,
        by offset: Int
    ) -> [Profile.ID]? {
        guard let from = profiles.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        let to = from + offset
        guard profiles.indices.contains(to) else { return nil }
        var ordered = profiles
        ordered.swapAt(from, to)
        return ordered.map(\.id)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     

     
     
     
     
     
     
    private func actionRow(
        symbol: String,
        title: HakoDisplayText,
        subtitle: HakoDisplayText,
        showsChevron: Bool
    ) -> some View {
        HStack(spacing: HakoTheme.Spacing.compact) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(hako: title)
                Text(hako: subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: HakoTheme.Spacing.row)

             
             
             
            Image(systemName: "chevron.forward")
                .foregroundStyle(.secondary)
                .opacity(showsChevron ? 1 : 0)
                .frame(width: HakoTheme.Control.pointerRowTarget)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
    private var addRow: some View {
        Button(action: addProfile) {
            actionRow(
                symbol: HakoSymbol.plusCircle.rawValue,
                title: .copy("Add Profile"),
                subtitle: .copy("Subscription link · config file · from scratch"),
                showsChevron: false
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profiles.add")
        .padding(.vertical, 2)
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    private func backupRow(_ destination: @escaping () -> AnyView) -> some View {
        Button {
            showsBackup = true
        } label: {
            actionRow(
                symbol: HakoSymbol.arrowClockwiseIcloud.rawValue,
                title: .copy("Backup & Restore"),
                subtitle: .copy("Everything a profile needs to run"),
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profiles.backup")
        .padding(.vertical, 2)
    }
}
