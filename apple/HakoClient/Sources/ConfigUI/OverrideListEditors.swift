import HakoClientUI
import SwiftUI

 
 
 
struct StringListEditor: View {
    @Binding var items: [String]
    let itemTitle: String
    let placeholder: String
    var validate: ((String) -> String?)?
    var identifier: String?

    init(
        items: Binding<[String]>,
        itemTitle: String = "Value",
        placeholder: String,
        validate: ((String) -> String?)? = nil,
        identifier: String? = nil
    ) {
        _items = items
        self.itemTitle = itemTitle
        self.placeholder = placeholder
        self.validate = validate
        self.identifier = identifier
    }

    @State private var newItem = ""
    @State private var error = ""

    var body: some View {
         
         
         
        ForEach(Array(items.indices), id: \.self) { index in
            Text(items[index])
                 
                 
                .font(.body.monospaced())
                .optionalAccessibilityIdentifier(identifier.map { "\($0).item.\(index)" })
        }
        .onDelete { items.remove(atOffsets: $0) }
        .onMove { items.move(fromOffsets: $0, toOffset: $1) }
        #if os(macOS)
        HakoFieldRow(
            itemTitle,
            hint: placeholder,
            text: $newItem,
            monospaced: true,
            identifier: identifier
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        HakoAddRow(Text(HakoCopy.key("Add")), action: add)
            .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
            .optionalAccessibilityIdentifier(identifier.map { "\($0).add" })
        #else
        HStack {
            TextField(placeholder, text: $newItem)
                .font(.body.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .optionalAccessibilityIdentifier(identifier)
            Button("Add", action: add)
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                .optionalAccessibilityIdentifier(identifier.map { "\($0).add" })
        }
        #endif
        if !error.isEmpty {
            HakoStatusMessage(text: .copy(error), kind: .error)
        }
    }

    private func add() {
        let candidate = newItem.trimmingCharacters(in: .whitespaces)
        guard !candidate.isEmpty else { return }
        if let reason = validate?(candidate) {
            error = reason
            return
        }
        error = ""
        if !items.contains(candidate) { items.append(candidate) }
        newItem = ""
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

 
 
struct KeyValueListEditor: View {
    struct Entry: Identifiable {
        let id = UUID()
        var key: String
        var value: String
        var valueWasArray: Bool = false
    }

    @Binding var entries: [Entry]
    let keyPlaceholder: String
    let valuePlaceholder: String
    var validateValue: ((String) -> String?)?
    var identifier: String?

    @State private var newKey = ""
    @State private var newValue = ""
    @State private var error = ""

    var body: some View {
        ForEach(Array(entries.indices), id: \.self) { index in
            HStack {
                Text(entries[index].key)
                    .font(.caption.monospaced())
                    .optionalAccessibilityIdentifier(identifier.map { "\($0).key.\(index)" })
                Spacer()
                TextField(valuePlaceholder, text: $entries[index].value)
                    .accessibilityIdentifier("override.list.value")
                    .font(.caption.monospaced())
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .optionalAccessibilityIdentifier(identifier.map { "\($0).value.\(index)" })
            }
        }
        .onDelete { entries.remove(atOffsets: $0) }
        VStack(alignment: .leading, spacing: HakoTheme.Spacing.compact) {
            TextField(keyPlaceholder, text: $newKey)
                .accessibilityIdentifier("override.list.new-key")
                .font(.caption.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .optionalAccessibilityIdentifier(identifier.map { "\($0).new-key" })
            TextField(valuePlaceholder, text: $newValue)
                .accessibilityIdentifier("override.list.new-value")
                .font(.caption.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .optionalAccessibilityIdentifier(identifier.map { "\($0).new-value" })
            HakoAddRow(Text("Add Entry"), action: add) {
                Label("Add Entry", systemImage: HakoSymbol.plus.name)
            }
                .disabled(newKey.trimmingCharacters(in: .whitespaces).isEmpty
                          || newValue.trimmingCharacters(in: .whitespaces).isEmpty)
                .optionalAccessibilityIdentifier(identifier.map { "\($0).add" })
        }
        if !error.isEmpty {
            HakoStatusMessage(text: .copy(error), kind: .error)
        }
    }

    private func add() {
        let key = newKey.trimmingCharacters(in: .whitespaces)
        let value = newValue.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !value.isEmpty else { return }
        if let reason = validateValue?(value) {
            error = reason
            return
        }
        error = ""
        if let index = entries.firstIndex(where: { $0.key == key }) {
            entries[index].value = value
        } else {
            entries.append(Entry(key: key, value: value))
        }
        newKey = ""
        newValue = ""
    }
}
