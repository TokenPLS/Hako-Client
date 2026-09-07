import Foundation

 
 
enum ProxyEnvironmentShell: String, CaseIterable, Identifiable {
    case bash
    case fish
    case nushell
    case cmd
    case powershell

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bash: return "Bash"
        case .fish: return "Fish"
        case .nushell: return "Nushell"
        case .cmd: return "CMD"
        case .powershell: return "PowerShell"
        }
    }

     
     
    static let defaultsKey = "proxyShare.environmentShell"

     
    static func remembered(in defaults: UserDefaults = .standard) -> ProxyEnvironmentShell {
        defaults.string(forKey: defaultsKey).flatMap(ProxyEnvironmentShell.init(rawValue:)) ?? .bash
    }
}

 
 
 
struct ProxyEnvironmentEndpoint: Equatable {
    let host: String
    let httpPort: Int32?
    let socksPort: Int32?
    let username: String
    let password: String
}

 
 
 
 
 
 
 
 
enum ProxyEnvironmentCommand {
    static func text(shell: ProxyEnvironmentShell, endpoint: ProxyEnvironmentEndpoint) -> String {
        var pairs: [(String, String)] = []
        if let port = endpoint.httpPort {
            let http = url(scheme: "http", port: port, endpoint: endpoint)
            pairs += [("https_proxy", http), ("http_proxy", http)]
        }
         
        if let port = endpoint.socksPort {
            pairs.append(("all_proxy", url(scheme: "socks5", port: port, endpoint: endpoint)))
        } else if let port = endpoint.httpPort {
            pairs.append(("all_proxy", url(scheme: "http", port: port, endpoint: endpoint)))
        }
        switch shell {
        case .bash:
            return (["export"] + pairs.map { "\($0)=\($1)" }).joined(separator: " ")
        case .fish:
            return pairs.map { "set -gx \($0) \($1)" }.joined(separator: "; ")
        case .nushell:
            return pairs.map { "$env.\($0) = \"\($1)\"" }.joined(separator: "; ")
        case .cmd:
             
             
             
             
             
             
             
            guard let scratch = pairs.first else { return "" }
            guard pairs.contains(where: { $0.1.contains("%") }) else {
                return pairs.map { "set \($0)=\($1)" }.joined(separator: "\r\n") + "\r\n"
            }
            let ordered = Array(pairs.dropFirst()) + [scratch]
            let lines = ["set \(scratch.0)=%"] + ordered.map { name, value in
                "set \(name)=\(value.replacingOccurrences(of: "%", with: "%\(scratch.0)%"))"
            }
            return lines.joined(separator: "\r\n") + "\r\n"
        case .powershell:
            return pairs.map { "$env:\($0)=\"\($1)\"" }.joined(separator: "; ")
        }
    }

    static func url(scheme: String, port: Int32, endpoint: ProxyEnvironmentEndpoint) -> String {
        let host = endpoint.host.contains(":") ? "[\(endpoint.host)]" : endpoint.host
        var userinfo = ""
        if !endpoint.username.isEmpty {
            userinfo = encode(endpoint.username)
            if !endpoint.password.isEmpty {
                userinfo += ":" + encode(endpoint.password)
            }
            userinfo += "@"
        }
        return "\(scheme)://\(userinfo)\(host):\(port)"
    }

     
    private static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    private static func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? value
    }
}
