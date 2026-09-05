import Foundation

 
 
 
 
 
 
 
 
enum DNSServerValidator {
     
     
     
     
     
     
     
    static func isStrippedOnIOS(_ server: String) -> Bool {
        let lowered = server.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lowered == "system" || lowered.hasPrefix("system:")
            || lowered.hasPrefix("dhcp:")
    }

     
     
     
     
     
     
     
    static func isUsableIPBootstrap(_ server: String) -> Bool {
        let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStrippedOnIOS(trimmed) else { return false }

         
        var rest = trimmed
        if let range = rest.range(of: "://") {
            rest = String(rest[range.upperBound...])
        }
        if let cut = rest.firstIndex(where: { $0 == "/" || $0 == "#" || $0 == "?" }) {
            rest = String(rest[..<cut])
        }
        guard !rest.isEmpty else { return false }

         
        if rest.hasPrefix("[") {
            guard let close = rest.firstIndex(of: "]") else { return false }
            let host = String(rest[rest.index(after: rest.startIndex)..<close])
            return isIPLiteral(host)
        }
         
        if rest.filter({ $0 == ":" }).count >= 2 {
            return isIPLiteral(rest)
        }
         
        let host = rest.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)[0]
        guard !host.isEmpty else { return false }  
        return isIPLiteral(String(host))
    }

    private static func isIPLiteral(_ value: String) -> Bool {
        var v4 = in_addr(), v6 = in6_addr()
        return value.withCString {
            inet_pton(AF_INET, $0, &v4) == 1 || inet_pton(AF_INET6, $0, &v6) == 1
        }
    }

     
     
     
     
     
    static func rejectionReason(_ server: String) -> String? {
        let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "empty server" }
        return nil
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func defaultNameserverRejectionReason(_ servers: [String]) -> String? {
        nil
    }
}
