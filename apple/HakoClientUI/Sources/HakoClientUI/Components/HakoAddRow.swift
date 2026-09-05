import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoAddRow<TouchLabel: View>: View {
     
     
     
     
     
     
     
     
     
    public enum Context {
        case formRow
        case standaloneCard
    }

    private let title: Text
    private let context: Context
    private let action: () -> Void
    private let touchLabel: () -> TouchLabel

    public init(
        _ title: Text,
        context: Context = .formRow,
        action: @escaping () -> Void,
        @ViewBuilder touchLabel: @escaping () -> TouchLabel
    ) {
        self.title = title
        self.context = context
        self.action = action
        self.touchLabel = touchLabel
    }

    public var body: some View {
#if os(macOS)
         
         
         
         
        if HakoPlatformLayout.pageUsesSystemSettingsIdiom {
            Button(action: action) {
                HStack(spacing: HakoTheme.Spacing.row) {
                    Image(systemName: HakoSymbol.plus.rawValue)
                    title
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.primary)
        } else {
        Button(action: action) {
            HStack(spacing: HakoTheme.Spacing.row) {
                Image(systemName: HakoSymbol.plusCircleFill.rawValue)
                    .font(.title3)
                title
                Spacer(minLength: 0)
            }
            .foregroundStyle(.tint)
            .padding(
                context == .standaloneCard
                    ? EdgeInsets(
                        top: HakoTheme.Spacing.standard,
                        leading: HakoTheme.Spacing.standard,
                        bottom: HakoTheme.Spacing.standard,
                        trailing: HakoTheme.Spacing.standard
                    )
                    : EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
            )
            .frame(
                maxWidth: .infinity,
                minHeight: HakoTheme.Control.fullWidthRowMinHeight,
                alignment: .leading
            )
             
             
             
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        }
#else
        Button(action: action) {
            touchLabel()
        }
#endif
    }
}

public extension HakoAddRow where TouchLabel == EmptyView {
     
     
    init(
        _ title: Text,
        context: Context = .formRow,
        action: @escaping () -> Void
    ) {
        self.init(
            title,
            context: context,
            action: action,
            touchLabel: { EmptyView() }
        )
    }
}

