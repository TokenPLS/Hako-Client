import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum LocalMappingEffect {
    enum Status: Equatable {
         
        case inEffect
         
         
        case resolvesElsewhere(actual: [String])
         
        case tunnelNotRunning
         
        case notYetApplied
         
        case nameNotResolved
    }

     
     
     
     
    static func systemAddresses(for host: String) -> [String] {
        systemAddresses(for: host, family: AF_UNSPEC)
    }

     
    static func systemAddresses(for host: String, family: Int32) -> [String] {
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: family,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var head: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &head) == 0, let head else { return [] }
        defer { freeaddrinfo(head) }

        var found: [String] = []
        var cursor: UnsafeMutablePointer<addrinfo>? = head
        while let node = cursor {
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                node.pointee.ai_addr,
                node.pointee.ai_addrlen,
                &buffer,
                socklen_t(buffer.count),
                nil,
                0,
                NI_NUMERICHOST
            ) == 0 {
                let text = String(cString: buffer)
                 
                 
                let bare = text.split(separator: "%").first.map(String.init) ?? text
                if !bare.isEmpty, !found.contains(bare) { found.append(bare) }
            }
            cursor = node.pointee.ai_next
        }
        return found
    }

     
     
     
     
     
    static func status(
        expected: [String],
        actual: [String],
        tunnelIsRunning: Bool,
        hasUnappliedChanges: Bool
    ) -> Status {
        guard tunnelIsRunning else { return .tunnelNotRunning }
        guard !expected.isEmpty else { return .notYetApplied }
        if actual.isEmpty {
            return hasUnappliedChanges ? .notYetApplied : .nameNotResolved
        }
        let wanted = Set(expected.map(normalized))
        let got = Set(actual.map(normalized))
        if !wanted.isDisjoint(with: got) { return .inEffect }
        return hasUnappliedChanges ? .notYetApplied : .resolvesElsewhere(actual: actual)
    }

     
     
    private static func normalized(_ address: String) -> String {
        let bare = address.split(separator: "%").first.map(String.init) ?? address
        if let v6 = IPv6Address(bare) { return v6.canonicalText }
        return bare
    }
}

 
private struct IPv6Address {
    let words: [UInt16]

    init?(_ text: String) {
        guard text.contains(":") else { return nil }
        var parsed = [UInt16]()
        var address = in6_addr()
        guard text.withCString({ inet_pton(AF_INET6, $0, &address) }) == 1 else {
            return nil
        }
        withUnsafeBytes(of: &address) { raw in
            for index in stride(from: 0, to: 16, by: 2) {
                parsed.append(UInt16(raw[index]) << 8 | UInt16(raw[index + 1]))
            }
        }
        words = parsed
    }

    var canonicalText: String {
        words.map { String(format: "%x", $0) }.joined(separator: ":")
    }
}
