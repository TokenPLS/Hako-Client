import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum UDPEgressDiagnosis {
     
     
    private static let refusal = "UDP is not supported"

     
     
    private static let quicSilence = "no recent network activity"

     
     
     
    static func explain(_ message: String, outbound: String) -> String? {
        let named = outbound.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.contains(refusal) {
            return named.isEmpty
                ? "The line this traffic took does not carry UDP. HTTP and HTTPS proxies have no UDP transport at all, and Shadowsocks or Trojan lines can have it switched off. Pick a UDP-capable outbound and test again."
                : "\(named) does not carry UDP. HTTP and HTTPS proxies have no UDP transport at all, and Shadowsocks or Trojan lines can have it switched off. Pick a UDP-capable outbound and test again."
        }
        if message.contains(quicSilence) {
            return "HTTP/3 needs UDP, and nothing came back. The most likely reason is that the line in use does not carry UDP — HTTP and HTTPS proxies never do. Turn HTTP/3 off to measure over HTTP/1.1 and HTTP/2, or switch to a UDP-capable line."
        }
        return nil
    }

     
     
     
    static func presentable(_ message: String, outbound: String = "") -> String {
        explain(message, outbound: outbound) ?? message
    }
}
