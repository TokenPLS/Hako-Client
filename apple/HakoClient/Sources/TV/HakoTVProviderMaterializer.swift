import Foundation
import Hako

 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
 
enum HakoTVProviderMaterializer {
    struct Outcome: Equatable {
         
         
         
         
         
         
         
         
         
        let paths: [String: String]
         
         
         
        let readPaths: [String: String]
        let warnings: [String]
         
         
         
         
        let catalog: HakoTVProviderCatalog
    }

     
     
     
     
    static func resourceKey(for provider: RemoteResourcePlan.Provider) -> String {
        provider.resourceKey ?? "\(provider.kind):\(provider.name)"
    }

    enum MaterializeError: LocalizedError {
        case proxyProviderUnavailable(name: String, reason: String)
        case tooLarge(name: String)

        var errorDescription: String? {
            switch self {
            case .proxyProviderUnavailable(let name, let reason):
                String(localized: "The proxy provider “\(name)” could not be downloaded: \(reason)")
            case .tooLarge(let name):
                String(localized: "The provider “\(name)” is larger than this Apple TV accepts.")
            }
        }
    }

     
    static let maximumBytes = 8 * 1024 * 1024

     
     
    typealias Inspector = (_ kind: String, _ behavior: String, _ format: String, _ payload: Data) throws -> Void

    static let coreInspector: Inspector = { kind, behavior, format, payload in
        var count = 0
        var error: NSError?
        let readable = HakoInspectProviderForIOS(kind, behavior, format, payload, &count, &error)
        if !readable {
            throw error ?? NSError(
                domain: "HakoTV.Provider", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "the core could not read the payload"]
            )
        }
    }

    static func materialize(
        plan: RemoteResourcePlan,
        candidate: ConfigurationCandidate,
        session: URLSession,
        userAgent: String,
        maximumBytes: Int = maximumBytes,
        inspect: Inspector = coreInspector,
        now: @escaping () -> Date = Date.init
    ) async throws -> Outcome {
        var paths: [String: String] = [:]
        var readPaths: [String: String] = [:]
        var warnings: [String] = []
        var entries: [HakoTVProviderCatalog.Entry] = []
        for provider in plan.providers {
            let key = Self.resourceKey(for: provider)
            let target = candidate.stagingProvidersDirectory.appendingPathComponent(provider.path)
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let published = candidate.publishedProvidersDirectory.appendingPathComponent(provider.path).path
             
             
             
             
             
             
            let payload: Data
            var failure: String?
            do {
                let rawPayload = try await download(provider, session: session, userAgent: userAgent, maximumBytes: maximumBytes)
                payload = Self.slimmedForRuntime(kind: provider.kind, payload: rawPayload)
                do {
                    try inspect(provider.kind, provider.behavior, provider.format, payload)
                } catch {
                     
                     
                     
                     
                    warnings.append("\(provider.name): \(error.localizedDescription)")
                    failure = error.localizedDescription
                }
            } catch {
                 
                 
                if Task.isCancelled { throw CancellationError() }
                guard provider.kind == "rule" else {
                    throw MaterializeError.proxyProviderUnavailable(
                        name: provider.name,
                        reason: error.localizedDescription
                    )
                }
                warnings.append("\(provider.name): download failed: \(error.localizedDescription)")
                failure = String(localized: "download failed: \(error.localizedDescription)")
                payload = Data()
            }
            try payload.write(to: target, options: .atomic)
            paths[key] = published
            readPaths[key] = target.path
             
             
             
             
            entries.append(HakoTVProviderCatalog.Entry(
                kind: provider.kind,
                name: provider.name,
                updatedAt: now(),
                failure: failure
            ))
        }
        let catalog = HakoTVProviderCatalog(entries: entries)
         
         
         
        try catalog.write(to: candidate.stagingProvidersDirectory)
        return Outcome(paths: paths, readPaths: readPaths, warnings: warnings, catalog: catalog)
    }

     
     
     
     
     
     
     
     
     
     
    static func slimmedForRuntime(kind: String, payload: Data) -> Data {
        guard kind == "proxy" else { return payload }
        if payload.starts(with: Data(#"{"proxies":"#.utf8)) {
            guard let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                  let proxies = object["proxies"] as? [Any], !proxies.isEmpty,
                  let slim = try? JSONSerialization.data(
                      withJSONObject: ["proxies": proxies],
                      options: [.withoutEscapingSlashes, .sortedKeys]
                  )
            else { return payload }
            return slim
        }
        guard let text = String(data: payload, encoding: .utf8),
              let json = try? ConfigTransforms.yamlToJSON(text),
              let object = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let proxies = object["proxies"] as? [Any], !proxies.isEmpty,
              let slim = try? JSONSerialization.data(
                  withJSONObject: ["proxies": proxies],
                  options: [.withoutEscapingSlashes, .sortedKeys]
              )
        else { return payload }
        return slim
    }

    private static func download(
        _ provider: RemoteResourcePlan.Provider,
        session: URLSession,
        userAgent: String,
        maximumBytes: Int
    ) async throws -> Data {
        guard let url = URL(string: provider.url) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        for (field, values) in provider.headers {
            for value in values {
                request.addValue(value, forHTTPHeaderField: field)
            }
        }
        do {
            return try await HakoTVBoundedDownload.data(for: request, session: session, maximumBytes: maximumBytes)
        } catch HakoTVBoundedDownload.Failure.tooLarge {
            throw MaterializeError.tooLarge(name: provider.name)
        }
    }
}
