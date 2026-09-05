import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
struct HakoTVUtilitiesHub: View {
     
    enum Door: Hashable, CaseIterable {
        case nodes
        case rules
        case connections

        var title: String {
            switch self {
            case .nodes: String(localized: "Nodes")
            case .rules: String(localized: "Rules")
            case .connections: String(localized: "Connections")
            }
        }

         
         
         
         
         
         
        var identifier: String {
            switch self {
            case .nodes: "nodes"
            case .rules: "rules"
            case .connections: "connections"
            }
        }

        var explanation: String {
            switch self {
            case .nodes:
                String(localized: "Policy groups and the nodes in each. Press a node to use it; a url-test group picks its own until you do.")
            case .rules:
                String(localized: "Every rule in the profile, in the order the tunnel tries them. Read-only here: see what a connection will do, then edit on your phone.")
            case .connections:
                String(localized: "What is going through the tunnel right now, newest first, and which rule sent each one where it went.")
            }
        }
    }

    @Binding var opened: Door?

    @State private var explained: Door = Door.allCases[0]

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            List {
                Section("Utilities") {
                    ForEach(Door.allCases, id: \.self) { door in
                        Button {
                            opened = door
                        } label: {
                            LabeledContent(door.title, value: "")
                        }
                        .onHakoTVFocus { explained = door }
                        .accessibilityIdentifier("tvos.utilities.\(door.identifier)")
                    }
                }
            }
            .listStyle(.grouped)
            .safeAreaPadding(.horizontal, 44)
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                Text(explained.title)
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.tertiary)
                Text(explained.explanation)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.18), value: explained)
        }
         
         
         
    }
}
