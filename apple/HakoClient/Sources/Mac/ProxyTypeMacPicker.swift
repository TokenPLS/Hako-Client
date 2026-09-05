import SwiftUI
import HakoClientUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct ProxyTypeMacRow: View {
    @ObservedObject var draft: ProxyNodeEditorDraft
    let hidesNonServerTypes: Bool

    var body: some View {
        Menu {
            Picker("Common", selection: selection) {
                ForEach(commonSpecifications, id: \.typeID) { item in
                    Text(item.displayName)
                        .tag(item.typeID)
                        .accessibilityIdentifier("proxy-type.\(item.typeID)")
                }
            }
            .pickerStyle(.inline)

            Picker("All Protocols", selection: selection) {
                ForEach(remainingSpecifications, id: \.typeID) { item in
                    Text(item.displayName)
                        .tag(item.typeID)
                        .accessibilityIdentifier("proxy-type.\(item.typeID)")
                }
            }
            .pickerStyle(.inline)
        } label: {
             
             
             
             
            HStack(spacing: HakoTheme.Spacing.compact) {
                Text(displayName)
                    .foregroundStyle(.secondary)
                Image(systemName: HakoSymbol.chevronUpChevronDown.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(hako: .copy("Proxy Type")))
            .accessibilityValue(displayName)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityIdentifier("proxies.nodeEditor.type")
        .id("proxies.nodeEditor.type")
        .hakoSettingsMenuRow("Proxy Type")
    }

    private var selection: Binding<String> {
        Binding(
            get: { draft.typeID },
            set: { draft.changeType(to: $0) }
        )
    }

    private var displayName: String {
        ProxyProtocolCatalog.specification(for: draft.typeID)?.displayName
            ?? draft.typeID
    }

    private var commonSpecifications: [ProxyProtocolSpecification] {
        ProxyTypeGrouping.commonTypeIDs.compactMap { id in
            ProxyProtocolCatalog.specifications.first { $0.typeID == id }
        }
    }

    private var remainingSpecifications: [ProxyProtocolSpecification] {
        ProxyProtocolCatalog.specifications.filter {
            !ProxyTypeGrouping.commonTypeIDs.contains($0.typeID)
                && !(hidesNonServerTypes
                    && ProxyTypeGrouping.nonServerTypeIDs.contains($0.typeID))
        }
    }
}
