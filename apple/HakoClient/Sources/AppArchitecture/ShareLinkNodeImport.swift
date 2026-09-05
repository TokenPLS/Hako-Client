import Foundation

enum ShareLinkNodeImportError: LocalizedError, Equatable {
    case notNodes
    case bridgeReturnedNil

    var errorDescription: String? {
        switch self {
        case .notNodes:
            return "That text does not contain a node share link."
        case .bridgeReturnedNil:
            return "The share link could not be read."
        }
    }
}

 
 
 
 
 
 
 
enum ShareLinkNodeImport {
     
    static func nodes(from raw: String) throws -> [String] {
        try imported(from: raw).nodes
    }

     
     
     
     
     
     
     
     
    static func imported(
        from raw: String
    ) throws -> (nodes: [String], notHonoured: [ProxyImportIssue]) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ShareLinkNodeImportError.notNodes }

        let report = try ProxyImportBridge.inspect(Data(trimmed.utf8), context: .nodeBundle)
         
         
         
         
         
         
         
         
         
         
         
         
         
         
         
        guard !report.proxies.isEmpty else {
            throw report.issues.isEmpty
                ? ShareLinkNodeImportError.notNodes
                : ProxyImportBridgeError.rejected(report.issues)
        }
        let nodes = try report.proxies.map { proxy in
            let data = try JSONSerialization.data(
                withJSONObject: proxy,
                options: [.sortedKeys]
            )
            return String(decoding: data, as: UTF8.self)
        }
        return (nodes, report.notHonoured)
    }
}
