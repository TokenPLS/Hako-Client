import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoDeferredPageContent<Content: View, Placeholder: View>: View {
    @ViewBuilder private let content: () -> Content
    @ViewBuilder private let placeholder: () -> Placeholder

    @State private var ready = false

    public init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.content = content
        self.placeholder = placeholder
    }

    public var body: some View {
        if HakoPlatformLayout.dataPagesDeferContentOneTurn {
            Group {
                if ready {
                    content()
                } else {
                    placeholder()
                        .accessibilityIdentifier("page.deferred.placeholder")
                }
            }
            .task {
                 
                 
                 
                await Task.yield()
                guard !Task.isCancelled else { return }
                ready = true
            }
        } else {
            content()
        }
    }
}

 
 
 
 
 
 
public struct HakoPageLoadingPlaceholder: View {
    private let title: HakoDisplayText

    public init(title: HakoDisplayText) {
        self.title = title
    }

    public var body: some View {
        VStack(spacing: HakoTheme.Spacing.compact) {
            Spacer()
            Text(hako: title)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
