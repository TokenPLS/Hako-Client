import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoStableNavigationLink<
    Value: Hashable,
    Destination: View,
    Label: View
>: View {
    private let value: Value
    private let destination: () -> Destination
    private let label: Label

    public init(
        value: Value,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.value = value
        self.destination = destination
        self.label = label()
    }

    @Environment(\.hakoPushRoute) private var pushRoute

    public var body: some View {
#if os(macOS)
         
         
         
         
         
         
         
         
         
        if let pushRoute {
            Button {
                pushRoute(value)
            } label: {
                 
                 
                 
                 
                HStack(spacing: 6) {
                    label
                     
                     
                     
                    Spacer(minLength: HakoTheme.Spacing.row)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
             
             
             
             
             
            .buttonStyle(HakoPushRowButtonStyle())
        } else {
            NavigationLink(value: value) {
                label
            }
        }
#else
         
         
         
         
         
         
         
         
         
         
         
         
         
        if HakoPlatformLayout.regularShellKeepsContainer, let pushRoute {
             
            Button {
                pushRoute(value)
            } label: {
                HStack(spacing: 6) {
                    label
                    Spacer(minLength: HakoTheme.Spacing.row)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(HakoPushRowButtonStyle())
        } else {
            NavigationLink {
                HakoLazyView(destination)
                 
                 
                 
                 
                 
                 
                 
                 
                .hakoNativePushBoundary()
            } label: {
                label
            }
        }
#endif
    }
}

public extension View {
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @ViewBuilder
    func hakoStableNavigationDestination<
        Value: Hashable,
        Destination: View
    >(
        for data: Value.Type,
        @ViewBuilder destination: @escaping (Value) -> Destination
    ) -> some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, *) {
            modifier(HakoStableDestinationModifier(destination: destination))
        } else {
             
             
            self
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private struct HakoStableDestinationModifier<
    Value: Hashable,
    Destination: View
>: ViewModifier {
    let destination: (Value) -> Destination

    @Environment(\.hakoPushRoute) private var pushRoute

    func body(content: Content) -> some View {
        content.navigationDestination(for: Value.self) { value in
            HakoDestinationPopScope {
                HakoLazyView {
                    destination(value)
                }
                    .hakoPushedDetailPage()
                    .environment(\.hakoPushRoute, pushRoute)
                    .modifier(HakoSetterRoutedBack())
                     
                     
                     
                    .environment(\.hakoRegularShellOwnsCanvas, true)
            }
        }
    }
}

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
private struct HakoDestinationPopScope<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss
     
     
     
     
    @State private var token = UUID()

    var body: some View {
        content.environment(
            \.hakoPopRoute,
            HakoRoutePusher(token: token) { _ in dismiss() }
        )
    }
}


 
 
 
 
 
 
 
 
 
 
@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
public struct HakoValueRowLink<Value: Hashable, RowLabel: View>: View {
    private let value: Value
    private let label: RowLabel
    @Environment(\.hakoPushRoute) private var pushRoute

    public init(value: Value, @ViewBuilder label: () -> RowLabel) {
        self.value = value
        self.label = label()
    }

    public var body: some View {
#if os(macOS)
        if let pushRoute {
             
             
             
             
             
            Button {
                pushRoute(value)
            } label: {
                label
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: value) { label }
        }
#else
        NavigationLink(value: value) { label }
#endif
    }
}
