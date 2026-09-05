import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum ProxyEditorFieldOwnership {
     
     
     
     
     
    static let dedicatedSections: Set<String> = ["dialer-proxy"]

     
    static let tlsEditorCandidates: Set<String> = [
        "tls", "sni", "servername", "alpn", "ech-opts", "reality-opts",
        "skip-cert-verify", "fingerprint", "client-fingerprint",
        "certificate", "private-key",
    ]

     
     
    static let tlsDetectionKeys: Set<String> = [
        "tls", "sni", "servername", "alpn", "ech-opts", "reality-opts",
        "skip-cert-verify", "fingerprint", "certificate",
    ]

    static func supportsTLS(typeID: String) -> Bool {
        cache[typeID]?.supportsTLS ?? computeSupportsTLS(typeID: typeID)
    }

     
    static func formKeys(typeID: String) -> Set<String> {
        cache[typeID]?.form ?? Set(ProxyEditorDefaultFields.keys(for: typeID))
    }

     
     
     
     
    static func tlsKeys(typeID: String) -> Set<String> {
        cache[typeID]?.tls ?? computeTLSKeys(typeID: typeID)
    }

     
     
     
     
    static func advancedFields(typeID: String) -> [ProxyEditorSchemaField] {
        cache[typeID]?.advanced ?? computeAdvancedFields(typeID: typeID)
    }

     

     
     
     
     
     
     
     
     
     
     
     
    private struct Ownership {
        let supportsTLS: Bool
        let form: Set<String>
        let tls: Set<String>
        let advanced: [ProxyEditorSchemaField]
    }

    private static let cache: [String: Ownership] = {
        var table: [String: Ownership] = [:]
        for typeID in ProxyProtocolCatalog.formalTypeIDs {
            table[typeID] = Ownership(
                supportsTLS: computeSupportsTLS(typeID: typeID),
                form: Set(ProxyEditorDefaultFields.keys(for: typeID)),
                tls: computeTLSKeys(typeID: typeID),
                advanced: computeAdvancedFields(typeID: typeID)
            )
        }
        return table
    }()

    private static func computeSupportsTLS(typeID: String) -> Bool {
        tlsDetectionKeys.contains {
            ProxyProtocolEditorSchema.supports($0, typeID: typeID)
        }
    }

    private static func computeTLSKeys(typeID: String) -> Set<String> {
        guard computeSupportsTLS(typeID: typeID) else { return [] }
        return tlsEditorCandidates
            .filter { ProxyProtocolEditorSchema.supports($0, typeID: typeID) }
            .subtracting(Set(ProxyEditorDefaultFields.keys(for: typeID)))
    }

    private static func computeAdvancedFields(
        typeID: String
    ) -> [ProxyEditorSchemaField] {
        let owned = Set(ProxyEditorDefaultFields.keys(for: typeID))
            .union(computeTLSKeys(typeID: typeID))
            .union(dedicatedSections)
            .union(ProxyEditorHiddenFields.platformUnsupported)
        return ProxyProtocolEditorSchema.fields(for: typeID).filter {
            $0.key != "name" && !owned.contains($0.key)
        }
    }
}

 
 
 
 
enum ProxyEditorHiddenFields {
     
     
     
     
     
     
     
     
     
    static let platformUnsupported: Set<String> = ["interface-name", "routing-mark"]

    static func isHidden(_ key: String) -> Bool {
        platformUnsupported.contains(key.lowercased())
    }
}
