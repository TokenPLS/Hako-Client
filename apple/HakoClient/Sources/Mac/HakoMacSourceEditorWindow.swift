import HakoClientUI
import SwiftUI

 
struct HakoMacSourceEditorRequest: Hashable, Codable {
    let profileID: String
}

 
 
 
 
struct HakoMacSourceEditorWindow: View {
    let request: HakoMacSourceEditorRequest
     
    @ObservedObject var profiles: ProfilesViewModel
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @State private var rawYAML: String??

    var body: some View {
        if let profile = profiles.profiles.first(where: { $0.id == request.profileID }) {
            content(for: profile)
                 
                 
                .task(id: request.profileID) {
                    guard rawYAML == nil else { return }
                     
                     
                     
                     
                    rawYAML = .some(await profiles.loadSourceYAML(for: profile))
                }
        } else {
            HakoEmptyState(
                title: "No Profile",
                message: "The profile is no longer available.",
                symbol: .curlybraces
            )
            .frame(minWidth: 480, minHeight: 320)
        }
    }

    @ViewBuilder
    private func content(for profile: Profile) -> some View {
        if let rawYAML {
            HakoWindowDepartureHost {
                ProfileEditView(
                    profile: profile,
                    rawYAML: rawYAML
                ) { updated, rawYAML, resources, disablingAutoUpdate in
                    try await profiles.updateEdited(
                        updated,
                        sourceYAML: rawYAML,
                        resourceFiles: resources,
                        disablingAutoUpdate: disablingAutoUpdate
                    )
                }
            } windowGuard: { controller in
                HakoMacWindowCloseGuard(controller: controller)
            }
            .navigationTitle(Text(verbatim: profile.label))
            .navigationSubtitle("Edit Source")
            .frame(minWidth: 640, minHeight: 480)
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(Text(verbatim: profile.label))
                .navigationSubtitle("Edit Source")
                .frame(minWidth: 640, minHeight: 480)
        }
    }
}
