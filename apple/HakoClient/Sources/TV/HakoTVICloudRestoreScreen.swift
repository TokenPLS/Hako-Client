import HakoClientKit
import SwiftUI

 
 
enum HakoTVICloudRestorePresentation {
     
    static func welcomeLine(_ availability: HakoTVICloudRestore.Availability) -> String? {
        if case .ready = availability { return String(localized: "Restore from iCloud") }
        return nil
    }

    static func itemLine(_ item: HakoTVICloudRestore.Plan.Item) -> String {
        switch item.disposition {
        case .restorable(true):
            String(localized: "Ready to restore")
        case .restorable(false):
            String(localized: "Overrides not applied — back up again on your iPhone")
        case .skippedLocalResources(let count):
            String(localized: "Uses \(count) local resource files — not supported on Apple TV yet")
        }
    }

    static func rowSubtitle(_ restored: HakoTVSubscription.Restored) -> String {
        let when = restored.exportedAt.formatted(.relative(presentation: .named))
        return String(localized: "From iCloud · \(restored.sourceDevice) · \(when)")
    }

    static func sourceChoice(_ summary: BackupRecordSummary) -> String {
        let device = summary.sourceDevice ?? summary.installID
        let when = summary.exportedAt?.formatted(.relative(presentation: .named)) ?? ""
        return "\(device) · \(when)"
    }
}

 
 
 
 
 
 
struct HakoTVICloudRestoreScreen: View {
    @Binding var state: HakoTVProductState
     
    let service: HakoTVICloudRestore?
    @Binding var store: HakoTVSubscriptionStore
     
     
    var onDone: () -> Void = {}

    @State private var availability: HakoTVICloudRestore.Availability?
    @State private var plan: HakoTVICloudRestore.Plan?
    @State private var failure: String?

    var body: some View {
        List {
            switch availability {
            case nil:
                Text("Downloading from iCloud…")
                    .foregroundStyle(.secondary)
            case .unavailable:
                Text("Sign in to iCloud on this Apple TV to restore from your iPhone.")
            case .noBackups:
                Text("No automatic backup yet. Turn on “Keep iCloud backup current” on your iPhone or Mac.")
            case .failed(let sentence):
                 
                Text(verbatim: sentence)
            case .ready(let backups):
                if backups.count > 1, plan == nil {
                    Section("Choose the device to restore from") {
                        ForEach(backups) { summary in
                            Button(HakoTVICloudRestorePresentation.sourceChoice(summary)) { Task { await load(summary) } }
                        }
                    }
                }
                if let plan {
                     
                     
                     
                    Section(HakoTVICloudRestorePresentation.sourceChoice(plan.summary)) {
                        Button("Restore \(plan.restorableCount) profiles") { apply(plan) }
                            .disabled(plan.restorableCount == 0)
                            .accessibilityIdentifier("tvos.icloud.restore")
                    }
                    Section {
                        ForEach(plan.items) { item in
                            LabeledContent(item.label, value: HakoTVICloudRestorePresentation.itemLine(item))
                                .accessibilityIdentifier("tvos.icloud.item.\(item.id)")
                        }
                    }
                }
            }
            if let failure {
                 
                Text(verbatim: failure)
                    .foregroundStyle(.red)
            }
        }
        .listStyle(.grouped)
        .navigationTitle("Restore from iCloud")
        .task { await refreshAvailability() }
    }

    private func refreshAvailability() async {
        guard let service else {
            availability = .unavailable
            return
        }
        var availability = await HakoTVICloudRestore.availability(locator: service.locator())
         
         
        var retries = 2
        while case .noBackups = availability, retries > 0 {
            retries -= 1
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            availability = await HakoTVICloudRestore.availability(locator: service.locator())
        }
        self.availability = availability
        if case .ready(let backups) = availability, backups.count == 1 { await load(backups[0]) }
    }

    private func load(_ summary: BackupRecordSummary) async {
        guard let service, let locator = service.locator() else { return }
        do {
            failure = nil
            plan = HakoTVICloudRestore.plan(summary: summary, envelope: try await locator.read(summary))
        } catch {
            failure = error.localizedDescription
        }
    }

    private func apply(_ plan: HakoTVICloudRestore.Plan) {
        guard let service else { return }
        do {
            _ = try service.apply(plan, to: &store)
            onDone()
        } catch {
            failure = error.localizedDescription
        }
    }
}
