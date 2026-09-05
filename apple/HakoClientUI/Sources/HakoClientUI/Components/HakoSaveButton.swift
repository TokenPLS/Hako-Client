import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoSaveButton: View {
    private let title: HakoDisplayText
    private let isEnabled: Bool
    private let identifier: String?
    private let action: () async -> Void

    @State private var isSaving = false

    public init(
        _ title: HakoDisplayText = .copy("Save"),
        isEnabled: Bool = true,
        identifier: String? = nil,
        action: @escaping () async -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.identifier = identifier
        self.action = action
    }

    public var body: some View {
        Button {
             
             
             
            guard !isSaving else { return }
            isSaving = true
            Task {
                await action()
                isSaving = false
            }
        } label: {
            ZStack {
                 
                 
                Text(hako: title)
                    .opacity(isSaving ? 0 : 1)
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                }
            }
        }
         
         
        .disabled(isSaving || !isEnabled)
         
         
        .modifier(HakoOptionalIdentifier(identifier: identifier))
         
         
        .accessibilityValue(isSaving ? Text("Saving") : Text(""))
    }
}

 
 
 
 
 
struct HakoOptionalIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
