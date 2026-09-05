import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum CertificateStorePolicy {
    static let defaultsKey = "core.certificate-store"

     
     
    static let platform = ""

     
    static let selectable = ["system", "mozilla", "chrome", "none"]

     
     
     
     
    static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isSelectable(_ value: String) -> Bool {
        selectable.contains(normalized(value))
    }

     
     
     
     
    static func setupValue(forStored stored: String?) -> String? {
        guard let stored, !normalized(stored).isEmpty else { return nil }
        return normalized(stored)
    }

     
     
     
     
     
     
     
     
    static func title(for value: String) -> String {
        switch normalized(value) {
        case "system": "System (explicit)"
        case "mozilla": "Mozilla bundle"
        case "chrome": "Chrome bundle"
        case "none": "None"
        case platform: "Platform default"
        default: "Unsupported"
        }
    }

     
    static func detail(for value: String) -> String {
        switch normalized(value) {
        case "mozilla", "chrome":
            "Skips the system trust service on every verification. Enterprise and self-signed roots installed on this device stop being trusted."
        case "none":
            "Trusts nothing by default. Only for configurations that pin their own certificates."
        case "system":
            "The platform's own trust, selected explicitly."
        case platform:
            "The platform's own trust. Nothing is changed."
        default:
            "Not a store the core recognises. Clash will refuse to start until this is changed."
        }
    }
}
