import SwiftUI

 
 
public struct HakoProfilePickerItem: Identifiable, Hashable, Sendable {
    public let id: String
     
     
    public let label: String
    public let isCurrent: Bool
    public let isSwitching: Bool

    public init(
        id: String,
        label: String,
        isCurrent: Bool,
        isSwitching: Bool = false
    ) {
        self.id = id
        self.label = label
        self.isCurrent = isCurrent
        self.isSwitching = isSwitching
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoProfilePickerCard: View {
    private let items: [HakoProfilePickerItem]
    private let onPick: (String) -> Void
    private let onClose: () -> Void

    public init(
        items: [HakoProfilePickerItem],
        onPick: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.items = items
        self.onPick = onPick
        self.onClose = onClose
    }

     
     
     
    private var isBusy: Bool { items.contains(where: \.isSwitching) }

    public var body: some View {
         
         
         
        List {
             
             
             
             
             
             
            Section {
                if items.isEmpty {
                    Text(hako: "No profiles yet")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("profile.picker.empty")
                } else {
                    ForEach(items) { row($0) }
                }
            }
        }
        .hakoGroupedList()
        .navigationTitle(HakoCopy.key("Profiles"))
        .hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .cancellationAction) {
                 
                HakoSheetCloseButton { onClose() }
            }
        }
        .accessibilityIdentifier("profile.picker")
    }

    private func row(_ item: HakoProfilePickerItem) -> some View {
        Button {
            onPick(item.id)
        } label: {
            HStack(spacing: HakoTheme.Spacing.row) {
                Text(verbatim: item.label)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer(minLength: HakoTheme.Spacing.compact)
                if item.isSwitching {
                    ProgressView()
                } else if item.isCurrent {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityAddTraits(item.isCurrent ? [.isSelected] : [])
        .accessibilityIdentifier("profile.picker.row.\(item.id)")
    }
}
