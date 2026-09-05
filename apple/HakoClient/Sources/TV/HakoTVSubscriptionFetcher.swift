import Foundation

 
 
 
 
 
 
 
 
 
 
 
 
 
 
struct HakoTVFetchedSubscription: Equatable {
    let yaml: String
     
    let userInfo: String?
}

enum HakoTVSubscriptionFetcher {
    enum FetchError: LocalizedError, Equatable {
        case httpStatus(Int)
        case tooLarge
        case notText
        case transport(String)

        var errorDescription: String? {
            switch self {
            case .httpStatus(let status):
                String(localized: "The server answered \(status). Check the address on your phone.")
            case .tooLarge:
                String(localized: "The profile is larger than this Apple TV accepts.")
            case .notText:
                String(localized: "The profile did not come back as text.")
            case .transport(let reason):
                String(localized: "The profile could not be downloaded: \(reason)")
            }
        }
    }

     
     
    static let maximumBytes = 16 * 1024 * 1024

     
     
     
     
     
    static func userAgent(
        defaults: UserDefaults = ClientUserAgent.appGroupDefaults
    ) -> String {
        ClientUserAgent.preset(from: defaults).value
    }

    static func fetch(
        _ url: URL,
        session: URLSession,
        userAgent: String,
        maximumBytes: Int = maximumBytes
    ) async throws -> HakoTVFetchedSubscription {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        let data: Data
        let response: HTTPURLResponse?
        do {
            (data, response) = try await HakoTVBoundedDownload.dataAndResponse(
                for: request, session: session, maximumBytes: maximumBytes
            )
        } catch HakoTVBoundedDownload.Failure.tooLarge {
            throw FetchError.tooLarge
        } catch HakoTVBoundedDownload.Failure.httpStatus(let status) {
            throw FetchError.httpStatus(status)
        } catch {
             
             
             
            if Task.isCancelled { throw CancellationError() }
            throw FetchError.transport(error.localizedDescription)
        }
        guard let yaml = String(data: data, encoding: .utf8) else { throw FetchError.notText }
        return HakoTVFetchedSubscription(yaml: yaml, userInfo: response?.value(forHTTPHeaderField: "subscription-userinfo"))
    }
}

 
 
 
 
enum HakoTVBoundedDownload {
    enum Failure: Error, Equatable {
        case tooLarge
        case httpStatus(Int)
    }

    static func data(for request: URLRequest, session: URLSession, maximumBytes: Int) async throws -> Data {
        try await dataAndResponse(for: request, session: session, maximumBytes: maximumBytes).data
    }

    static func dataAndResponse(
        for request: URLRequest,
        session: URLSession,
        maximumBytes: Int
    ) async throws -> (data: Data, response: HTTPURLResponse?) {
        let (bytes, response) = try await session.bytes(for: request)
        let http = response as? HTTPURLResponse
        if let http, !(200..<300).contains(http.statusCode) {
            throw Failure.httpStatus(http.statusCode)
        }
        if let http, http.expectedContentLength > Int64(maximumBytes) {
            throw Failure.tooLarge
        }
        var data = Data()
        data.reserveCapacity(min(maximumBytes, max(0, Int(http?.expectedContentLength ?? 0))))
        for try await byte in bytes {
            data.append(byte)
            if data.count > maximumBytes { throw Failure.tooLarge }
        }
        return (data, http)
    }
}
