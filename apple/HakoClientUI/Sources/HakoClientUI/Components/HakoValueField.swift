import SwiftUI

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
public struct HakoValueField: View {
    private let hint: String
    private let label: String?
    private let bordered: Bool
    private let text: Binding<String>
     
     
     
     
     
     
     
    private let identifier: String?

     
     
     
     
     
     
     
     
     
     
     
    public init(
        hint: String,
        label: String? = nil,
        bordered: Bool = false,
        text: Binding<String>,
        identifier: String? = nil
    ) {
        self.hint = hint
        self.label = label
        self.bordered = bordered
        self.text = text
        self.identifier = identifier
    }

    public var body: some View {
        field.hakoFieldIdentifier(identifier)
    }

    @ViewBuilder
    private var field: some View {
#if os(macOS)
        if bordered {
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
            TextField(
                text: text,
                prompt: Text(HakoCopy.key(hint)),
                label: { EmptyView() }
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.leading)
            .hakoValueFieldName(label)
        } else {
            TextField("", text: text, prompt: Text(HakoCopy.key(hint)))
                 
                 
                 
                 
                 
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .hakoValueFieldName(label)
        }
#else
        TextField(hint, text: text)
            .multilineTextAlignment(.trailing)
#endif
    }
}

 
public struct HakoSecureValueField: View {
    private let hint: String
    private let label: String?
    private let bordered: Bool
    private let text: Binding<String>
     
     
     
     
     
     
     
    private let identifier: String?

    public init(
        hint: String,
        label: String? = nil,
        bordered: Bool = false,
        text: Binding<String>,
        identifier: String? = nil
    ) {
        self.hint = hint
        self.label = label
        self.bordered = bordered
        self.text = text
        self.identifier = identifier
    }

    public var body: some View {
        field.hakoFieldIdentifier(identifier)
    }

    @ViewBuilder
    private var field: some View {
#if os(macOS)
        if bordered {
             
             
             
             
            SecureField(
                text: text,
                prompt: Text(HakoCopy.key(hint)),
                label: { EmptyView() }
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.leading)
            .hakoValueFieldName(label)
        } else {
             
             
             
             
             
             
             
             
             
             
             
             
            SecureField("", text: text)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .overlay(alignment: .trailing) {
                    if text.wrappedValue.isEmpty {
                        Text(HakoCopy.key(hint))
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }
                }
                .hakoValueFieldName(label)
        }
#else
        SecureField(hint, text: text)
            .multilineTextAlignment(.trailing)
#endif
    }
}

private extension View {
    @ViewBuilder
    func hakoValueFieldName(_ label: String?) -> some View {
        if let label {
            accessibilityLabel(Text(HakoCopy.key(label)))
        } else {
            self
        }
    }
}
