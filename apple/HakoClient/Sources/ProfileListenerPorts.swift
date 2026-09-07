import Foundation

 
 
 
 
 
 
struct ProfileListenerPorts: Equatable {
    struct Credentials: Equatable {
        let username: String
        let password: String
    }

    let mixedPort: Int32?
    let httpPort: Int32?
    let socksPort: Int32?
    let allowLAN: Bool
     
    let credentials: Credentials?

    static func parse(yaml: String) -> ProfileListenerPorts? {
        var values: [String: String] = [:]
        var authentication: [String] = []
        var inAuthentication = false
        for rawLine in yaml.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inAuthentication {
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                if line.first == " " || line.first == "\t" || line.first == "-" {
                    if trimmed.hasPrefix("- ") {
                        authentication.append(unquote(stripComment(String(trimmed.dropFirst(2)))))
                    }
                    continue
                }
                inAuthentication = false
            }
            guard let first = line.first, first != " ", first != "\t", first != "#", first != "-",
                  let colon = line.firstIndex(of: ":")
            else { continue }
            let rest = String(line[line.index(after: colon)...])
             
            guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let value = unquote(stripComment(rest.trimmingCharacters(in: .whitespaces)))
            if key == "authentication" {
                if value.hasPrefix("[") {
                    authentication = flowList(value)
                } else {
                    inAuthentication = value.isEmpty
                }
                continue
            }
            values[key] = value
        }
        func port(_ key: String) -> Int32? {
            guard let raw = values[key], let number = Int32(raw), (1...65535).contains(number) else { return nil }
            return number
        }
        let mixed = port("mixed-port")
        let http = port("port")
        let socks = port("socks-port")
        guard mixed != nil || http != nil || socks != nil else { return nil }
        let allowLAN = ["true", "yes", "on"].contains((values["allow-lan"] ?? "").lowercased())
        var credentials: Credentials?
        if let entry = authentication.first, let separator = entry.firstIndex(of: ":") {
            credentials = Credentials(
                username: String(entry[..<separator]),
                password: String(entry[entry.index(after: separator)...])
            )
        }
        return ProfileListenerPorts(
            mixedPort: mixed, httpPort: http, socksPort: socks, allowLAN: allowLAN, credentials: credentials
        )
    }

     
    private static func stripComment(_ value: String) -> String {
        if let quote = value.first, quote == "\"" || quote == "'",
           let close = value.dropFirst().firstIndex(of: quote) {
            return String(value[...close])
        }
        if value.hasPrefix("#") { return "" }
        if let range = value.range(of: " #") { return String(value[..<range.lowerBound]).trimmingCharacters(in: .whitespaces) }
        return value
    }

    private static func unquote(_ value: String) -> String {
        guard value.count >= 2, let first = value.first, let last = value.last,
              first == last, first == "\"" || first == "'"
        else { return value }
        return String(value.dropFirst().dropLast())
    }

    private static func flowList(_ value: String) -> [String] {
        var inner = value
        if inner.hasPrefix("[") { inner.removeFirst() }
        if inner.hasSuffix("]") { inner.removeLast() }
        return inner.split(separator: ",").map { unquote($0.trimmingCharacters(in: .whitespaces)) }.filter { !$0.isEmpty }
    }
}

 
 
 
 
struct ProxyTerminalListener: Equatable {
    enum Source: Equatable {
        case share
        case profile
    }

    let source: Source
    let httpPort: Int32?
    let socksPort: Int32?
    let username: String
     
     
    let password: String
    let lanReachable: Bool
}
