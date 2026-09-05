import SwiftUI

public struct HakoFullWidthSegmentedPlatformOption: Identifiable {
    public let id: AnyHashable
    public let title: String
    public let accessibilityIdentifier: String?

    public init(
        id: AnyHashable,
        title: String,
        accessibilityIdentifier: String?
    ) {
        self.id = id
        self.title = title
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}

 
 
 
public struct HakoFullWidthSegmentedPickerAdapter {
    private let makeContent: @MainActor (
        Binding<AnyHashable>,
        [HakoFullWidthSegmentedPlatformOption]
    ) -> AnyView

    public init(
        _ makeContent: @escaping @MainActor (
            Binding<AnyHashable>,
            [HakoFullWidthSegmentedPlatformOption]
        ) -> AnyView
    ) {
        self.makeContent = makeContent
    }

    @MainActor
    public func callAsFunction(
        selection: Binding<AnyHashable>,
        options: [HakoFullWidthSegmentedPlatformOption]
    ) -> AnyView {
        makeContent(selection, options)
    }
}

public struct HakoFullWidthSegmentedPickerAdapterKey: EnvironmentKey {
    nonisolated(unsafe) public static let defaultValue:
        HakoFullWidthSegmentedPickerAdapter? = nil
}

public extension EnvironmentValues {
    var hakoFullWidthSegmentedPickerAdapter:
        HakoFullWidthSegmentedPickerAdapter?
    {
        get { self[HakoFullWidthSegmentedPickerAdapterKey.self] }
        set { self[HakoFullWidthSegmentedPickerAdapterKey.self] = newValue }
    }
}

struct HakoFullWidthSegmentedOption<Selection: Hashable>: Identifiable {
    let selection: Selection
    let title: String
    let accessibilityIdentifier: String?

    var id: Selection { selection }
}

 
 
 
 
 
 
 
 
 
 
 
enum HakoFullWidthSegmentedRole {
     
     
    case pageStrip
     
    case inlineControl
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoFullWidthSegmentedPicker<Selection: Hashable>: View {
    @Binding var selection: Selection
    let options: [HakoFullWidthSegmentedOption<Selection>]
     
    let role: HakoFullWidthSegmentedRole
     
     
    var underlineSeparator: Color = .secondary
    @Environment(\.hakoFullWidthSegmentedPickerAdapter)
    private var platformAdapter

    @ViewBuilder
    var body: some View {
         
         
         
         
        switch role {
        case .pageStrip:
            underlineTabs
        case .inlineControl:
            if let platformAdapter {
                platformAdapter(
                    selection: erasedSelection,
                    options: options.map {
                        HakoFullWidthSegmentedPlatformOption(
                            id: AnyHashable($0.selection),
                            title: $0.title,
                            accessibilityIdentifier: $0.accessibilityIdentifier
                        )
                    }
                )
            } else {
                segmentedPicker
            }
        }
    }

    private var erasedSelection: Binding<AnyHashable> {
        Binding(
            get: { AnyHashable(selection) },
            set: { candidate in
                guard let typed = candidate.base as? Selection else { return }
                selection = typed
            }
        )
    }

    private var segmentedPicker: some View {
        Picker("", selection: $selection) {
            ForEach(options) { option in
                Text(verbatim: option.title)
                    .tag(option.selection)
                    .accessibilityIdentifier(
                        option.accessibilityIdentifier ?? ""
                    )
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

     
     
     
     
     
    private var underlineTabs: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    selection = option.selection
                } label: {
                    Text(verbatim: option.title)
                        .font(
                            .subheadline.weight(
                                selection == option.selection
                                    ? .semibold : .regular
                            )
                        )
                        .foregroundStyle(
                            selection == option.selection
                                ? AnyShapeStyle(.tint)
                                : AnyShapeStyle(.secondary)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HakoTheme.Spacing.row)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(
                                    selection == option.selection
                                        ? AnyShapeStyle(.tint)
                                        : AnyShapeStyle(Color.clear)
                                )
                                .frame(height: 2)
                        }
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                         
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(
                    selection == option.selection ? "Selected" : ""
                )
                .accessibilityIdentifier(
                    option.accessibilityIdentifier ?? ""
                )
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(underlineSeparator.opacity(0.28))
                .frame(height: 1)
                .zIndex(-1)
        }
    }
}
