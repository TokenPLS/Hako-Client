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

    enum MaterializeError: LocalizedError, Equatable {
        case proxyProviderUnavailable(name: String, reason: String)
        case tooLarge(name: String)
         
        case ageKeyMissing(name: String)
         
         
        case ageDecryptFailed(name: String, reason: String)

        var errorDescription: String? {
            switch self {
            case .proxyProviderUnavailable(let name, let reason):
                String(localized: "The proxy provider “\(name)” could not be downloaded: \(reason)")
            case .tooLarge(let name):
                String(localized: "The provider “\(name)” is larger than this Apple TV accepts.")
            case .ageKeyMissing(let name):
                String(localized: "The proxy provider “\(name)” is encrypted and the profile carries no key for it.")
            case .ageDecryptFailed(let name, let reason):
                String(localized: "The proxy provider “\(name)” could not be decrypted: \(reason)")
            }
        }

         
         
         
         
        var isAboutTheSeal: Bool {
            switch self {
            case .ageKeyMissing, .ageDecryptFailed: true
            case .proxyProviderUnavailable, .tooLarge: false
            }
        }
    }

     
    static let ageArmorPrefix = "-----BEGIN AGE ENCRYPTED FILE-----"

     
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

     
     
     
    struct DownloadKey: Hashable {
        let url: String
        let headers: [String: [String]]
        let proxy: String

        init(_ provider: RemoteResourcePlan.Provider) {
            url = provider.url
            headers = provider.headers
            proxy = provider.proxy
        }
    }

    static func materialize(
        plan: RemoteResourcePlan,
        candidate: ConfigurationCandidate,
        session: URLSession,
        userAgent: String,
        maximumBytes: Int = maximumBytes,
        inspect: Inspector = coreInspector,
         
         
         
        ageSecretKeys: [String: String] = [:],
        ruleSnapshots: [String: Data] = [:],
        existingProxyDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) async throws -> Outcome {
        var paths: [String: String] = [:]
        var readPaths: [String: String] = [:]
        var warnings: [String] = []
        var entries: [HakoTVProviderCatalog.Entry] = []
         
         
         
         
         
         
         
         
         
        var downloads: [DownloadKey: Result<Data, Error>] = [:]
        for provider in plan.providers {
            let key = Self.resourceKey(for: provider)
             
             
            if provider.kind == "rule" {
                let payload = ruleSnapshots[key]
                if let payload {
                    let target = candidate.stagingProvidersDirectory.appendingPathComponent(provider.path)
                    try payload.write(to: target, options: .atomic)
                    readPaths[key] = target.path
                     
                }
                entries.append(.init(kind: provider.kind, name: provider.name,
                                     updatedAt: now(), failure: nil, pending: payload == nil))
                continue
            }
            let target = candidate.stagingProvidersDirectory.appendingPathComponent(provider.path)
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let published = candidate.publishedProvidersDirectory.appendingPathComponent(provider.path).path
            let payload: Data
            var failure: String?
            do {
                let downloadKey = DownloadKey(provider)
                let rawPayload: Data
                if let existingProxyDirectory {
                    rawPayload = try Data(contentsOf: existingProxyDirectory.appendingPathComponent(provider.path))
                } else if let shared = downloads[downloadKey] {
                    rawPayload = try shared.get()
                } else {
                    do {
                        rawPayload = try await download(provider, session: session, userAgent: userAgent, maximumBytes: maximumBytes)
                        downloads[downloadKey] = .success(rawPayload)
                    } catch {
                         
                         
                         
                        if !Task.isCancelled { downloads[downloadKey] = .failure(error) }
                        throw error
                    }
                }
                let bytes = Self.slimmedForRuntime(
                    kind: provider.kind,
                    payload: try Self.unsealed(rawPayload, provider: provider, ageSecretKeys: ageSecretKeys)
                )
                payload = bytes
                do {
                    try inspect(provider.kind, provider.behavior, provider.format, bytes)
                } catch {
                     
                     
                    warnings.append("\(provider.name): \(error.localizedDescription)")
                    failure = error.localizedDescription
                }
            } catch let refusal as MaterializeError where refusal.isAboutTheSeal {
                throw refusal
            } catch {
                 
                 
                if Task.isCancelled { throw CancellationError() }
                 
                let failureReason: String
                if case HakoTVBoundedDownload.Failure.tooLarge = error {
                    failureReason = MaterializeError.tooLarge(name: provider.name).localizedDescription
                } else {
                    failureReason = error.localizedDescription
                }
                throw MaterializeError.proxyProviderUnavailable(name: provider.name, reason: failureReason)
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

     
     
     
     
     
     
     
    private static func unsealed(
        _ payload: Data,
        provider: RemoteResourcePlan.Provider,
        ageSecretKeys: [String: String]
    ) throws -> Data {
        guard provider.kind == "proxy", payload.starts(with: Data(ageArmorPrefix.utf8)) else { return payload }
        guard let key = ageSecretKeys[resourceKey(for: provider)], !key.isEmpty else {
            throw MaterializeError.ageKeyMissing(name: provider.name)
        }
        var error: NSError?
        guard let plaintext = HakoDecryptAgeForIOS(payload, key, &error) else {
            throw MaterializeError.ageDecryptFailed(
                name: provider.name,
                reason: error?.localizedDescription ?? "the core could not open the payload"
            )
        }
        return plaintext
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
        return try await HakoTVBoundedDownload.data(for: request, session: session, maximumBytes: maximumBytes)
    }
}
