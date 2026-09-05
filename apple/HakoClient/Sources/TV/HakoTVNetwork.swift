import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum HakoTVNetwork {

     
     
     
     
    static let session: URLSession = {
        URLSession(
            configuration: .default,
            delegate: AnyServerTrust(),
            delegateQueue: nil
        )
    }()

     
     
     
     
     
    static func answer(
        toAuthenticationMethod method: String,
        carryingServerTrust: Bool
    ) -> URLSession.AuthChallengeDisposition {
        guard method == NSURLAuthenticationMethodServerTrust, carryingServerTrust else {
            return .performDefaultHandling
        }
        return .useCredential
    }

    private final class AnyServerTrust: NSObject, URLSessionDelegate {
        func urlSession(
            _ session: URLSession,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            let trust = challenge.protectionSpace.serverTrust
            let disposition = HakoTVNetwork.answer(
                toAuthenticationMethod: challenge.protectionSpace.authenticationMethod,
                carryingServerTrust: trust != nil
            )
            guard disposition == .useCredential, let trust else {
                return completionHandler(.performDefaultHandling, nil)
            }
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
    }
}
