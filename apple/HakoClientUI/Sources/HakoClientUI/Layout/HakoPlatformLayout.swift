import SwiftUI
import UniformTypeIdentifiers

 
 
public enum HakoPlatformLayout {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    public static var collectionLeadsWithEmptyState: Bool { true }

     
     
     
     
     
    public static var proxiesSweepLivesInToolbar: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

     
     
     
     
     
    public static var proxiesDisplayOptionsUseListAxes: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

     
     
     
     
     
     
     
     
     
     
     
    public static var installsCompensatingInlineRootTitle: Bool {
#if os(macOS)
        false
#else
        true
#endif
    }

     
     
     
     
    public static var pageUsesSystemSettingsIdiom: Bool {
#if os(macOS)
        true
#else
        false
#endif
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
    public static var regularShellKeepsContainer: Bool {
        pageUsesSystemSettingsIdiom
            || !ProcessInfo.processInfo.arguments.contains("--hako-rekey-container")
    }

     
     
     
     
     
     
     
     
     
     
     
    public static var primaryPageCardUsesLiquidGlass: Bool {
#if os(macOS)
        true
#else
        false
#endif
    }


     
     
     
    public static var modalEditorUsesGroupedForm: Bool {
#if os(macOS)
        true
#else
        false
#endif
    }

     
     
     
    public static var sidebarFooterConsumesOwnLayoutSpace: Bool {
#if os(macOS)
        true
#else
        false
#endif
    }

     
     
     
     
     
     
    public static var sidebarStacksLabelsAtAccessibilitySizes: Bool {
#if os(macOS)
        false
#else
        true
#endif
    }

     
     
     
     
     
    public static var immediateDisplayOptionsUseMenu: Bool {
#if os(macOS)
        true
#else
        false
#endif
    }

     
     
     
     
    public static var profileReorderingUsesDedicatedTask: Bool {
#if os(macOS)
        false
#else
        true
#endif
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    public static var columnStableSliceLength: Int? {
#if os(macOS)
        60
#else
        nil
#endif
    }

     
     
     
     
     
     
    public static var displayChangeSwapsToPlaceholder: Bool {
#if os(macOS)
        false
#else
        true
#endif
    }


    public static var dataPagesDeferContentOneTurn: Bool {
#if os(iOS) || os(macOS)
        true
#else
        false
#endif
    }
}

enum HakoReorderDropEdge: Equatable {
    case before
    case after
}

struct HakoReorderDropTarget: Equatable {
    let id: String
    let edge: HakoReorderDropEdge
}

 
 
 
 
 
public struct HakoModalEditorBody<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @ViewBuilder
    public var body: some View {
#if os(macOS)
        Form {
            content
        }
        .formStyle(.grouped)
#else
        List {
            content
        }
#endif
    }
}

public extension View {
     
     
     
     
    @ViewBuilder
    func hakoExplicitReorderMode() -> some View {
#if os(iOS)
        environment(\.editMode, .constant(.active))
#else
        self
#endif
    }

     
     
     
     
    internal func hakoDirectReorderRow(
        id: String,
        label: String,
        enabled: Bool,
        draggedID: Binding<String?>,
        dropTarget: Binding<HakoReorderDropTarget?>,
        canMoveUp: Bool,
        canMoveDown: Bool,
        onMove: @escaping (
            _ sourceID: String,
            _ destinationID: String,
            _ edge: HakoReorderDropEdge
        ) -> Void,
        onMoveUp: @escaping () -> Void,
        onMoveDown: @escaping () -> Void
    ) -> some View {
        modifier(HakoDirectReorderRowModifier(
            id: id,
            label: label,
            enabled: enabled,
            draggedID: draggedID,
            dropTarget: dropTarget,
            canMoveUp: canMoveUp,
            canMoveDown: canMoveDown,
            onMove: onMove,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown
        ))
    }

     
     
    func hakoModalEditorToolbar(
        confirmTitle: LocalizedStringKey,
        confirmationIdentifier: String,
        confirmationDisabled: Bool = false,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            HakoModalEditorToolbarModifier(
                confirmTitle: confirmTitle,
                confirmationIdentifier: confirmationIdentifier,
                confirmationDisabled: confirmationDisabled,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        )
    }
}

private struct HakoDirectReorderRowModifier: ViewModifier {
    let id: String
    let label: String
    let enabled: Bool
    @Binding var draggedID: String?
    @Binding var dropTarget: HakoReorderDropTarget?
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMove: (String, String, HakoReorderDropEdge) -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        if enabled {
            content
                .onDrag {
                    draggedID = id
                    return NSItemProvider(object: id as NSString)
                } preview: {
                    Text(label)
                        .font(.body)
                        .lineLimit(1)
                        .padding(.horizontal, HakoTheme.Spacing.standard)
                        .padding(.vertical, HakoTheme.Spacing.row)
                        .background(.regularMaterial)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: HakoTheme.Radius.control,
                                style: .continuous
                            )
                        )
                }
                .onDrop(
                    of: [UTType.utf8PlainText.identifier],
                    delegate: HakoDirectReorderDropDelegate(
                        id: id,
                        draggedID: $draggedID,
                        dropTarget: $dropTarget,
                        onMove: onMove
                    )
                )
                .overlay(alignment: .top) {
                    insertionLine(.before)
                }
                .overlay(alignment: .bottom) {
                    insertionLine(.after)
                }
                .contextMenu {
                    Button("Move Up", action: onMoveUp)
                        .disabled(!canMoveUp)
                    Button("Move Down", action: onMoveDown)
                        .disabled(!canMoveDown)
                }
                .accessibilityAction(named: "Move Up", onMoveUp)
                .accessibilityAction(named: "Move Down", onMoveDown)
        } else {
            content
        }
#else
        content
#endif
    }

    @ViewBuilder
    private func insertionLine(_ edge: HakoReorderDropEdge) -> some View {
        if dropTarget == HakoReorderDropTarget(id: id, edge: edge) {
            Capsule()
                .fill(.tint)
                .frame(height: 2)
                .padding(.horizontal, HakoTheme.Spacing.standard)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

#if os(macOS)
private struct HakoDirectReorderDropDelegate: DropDelegate {
    let id: String
    @Binding var draggedID: String?
    @Binding var dropTarget: HakoReorderDropTarget?
    let onMove: (String, String, HakoReorderDropEdge) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedID != nil && draggedID != id
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard draggedID != nil, draggedID != id else {
            return DropProposal(operation: .forbidden)
        }
        let midpoint = HakoTheme.Regular.Detail.destinationRowMinHeight / 2
        let edge: HakoReorderDropEdge = info.location.y < midpoint
            ? .before
            : .after
        let next = HakoReorderDropTarget(id: id, edge: edge)
        if dropTarget != next {
            DispatchQueue.main.async {
                dropTarget = next
            }
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        guard dropTarget?.id == id else { return }
        DispatchQueue.main.async {
            dropTarget = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let sourceID = draggedID,
              sourceID != id else {
            draggedID = nil
            dropTarget = nil
            return false
        }
        let edge = dropTarget?.id == id
            ? dropTarget?.edge ?? .before
            : .before
        onMove(sourceID, id, edge)
        draggedID = nil
        dropTarget = nil
        return true
    }
}
#endif

private struct HakoModalEditorToolbarModifier: ViewModifier {
    let confirmTitle: LocalizedStringKey
    let confirmationIdentifier: String
    let confirmationDisabled: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
#if os(macOS)
        content
#else
        content.hakoToolbarUnlessInPanel {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(confirmTitle, action: onConfirm)
                    .disabled(confirmationDisabled)
                    .accessibilityIdentifier(confirmationIdentifier)
            }
        }
#endif
    }
}
