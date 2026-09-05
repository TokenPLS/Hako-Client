import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxyEditorNumericFields {
     
     
     
     
     
     
    static func firstNonNumeric(
        typeID: String,
        mapping: [String: Any]
    ) -> String? {
        walk(ProxyProtocolEditorSchema.fields(for: typeID), in: mapping)
    }

    private static func walk(
        _ fields: [ProxyEditorSchemaField],
        in object: [String: Any]
    ) -> String? {
        for field in fields {
            guard let value = object[field.key] else { continue }
            if !field.children.isEmpty {
                if let found = descend(field, into: value) { return found }
                continue
            }
            guard field.editorControlKind == .number else { continue }
            if !accepts(value, goType: field.goType) { return field.key }
        }
        return nil
    }

     
     
    private static func descend(
        _ field: ProxyEditorSchemaField,
        into value: Any
    ) -> String? {
        if let child = value as? [String: Any] {
            return walk(field.children, in: child)
        }
        if let elements = value as? [Any] {
            for element in elements {
                guard let child = element as? [String: Any] else { continue }
                if let found = walk(field.children, in: child) { return found }
            }
        }
        return nil
    }

    private static func accepts(_ value: Any, goType: String) -> Bool {
        let type = goType.hasPrefix("*") ? String(goType.dropFirst()) : goType
        let wantsWholeNumber = type.hasPrefix("int") || type.hasPrefix("uint")
         
         
         
         
         
         
         
         
         
         
         
         
         
        let wantsUnsigned = type.hasPrefix("uint")

        if let number = value as? NSNumber {
             
             
             
            guard wantsWholeNumber else { return true }
            if wantsUnsigned && number.doubleValue < 0 { return false }
            return number.doubleValue == number.doubleValue.rounded()
        }
        guard let text = value as? String else {
             
             
            return true
        }
         
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return true
        }
         
         
         
         
         
         
         
         
        if wantsWholeNumber {
            return wantsUnsigned ? UInt64(text) != nil : Int(text) != nil
        }
        return Double(text) != nil
    }
}
