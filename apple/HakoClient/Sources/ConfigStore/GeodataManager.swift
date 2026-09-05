import CryptoKit
import Foundation
import Hako

 
 
 
 
 
 
 
final class GeodataManager {
    private static let writeOptions: Data.WritingOptions =
        [.atomic, .completeFileProtectionUntilFirstUserAuthentication]

    private let downloader: HTTPFetching

    init(downloader: HTTPFetching) { self.downloader = downloader }

     
     
     
     
     
    func stage(
        plan: RemoteResourcePlan,
        homeDir: URL,
        maxBytesEach: Int,
        preferBundled: Bool = false,
        validatesWithCore: Bool = true
    ) async throws {
        guard !plan.geodata.isEmpty else { return }
        let cacheDir = homeDir.appendingPathComponent("geodata", isDirectory: true)
        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        for geo in plan.geodata {
            guard let url = URL(string: geo.url) else { continue }
            let ext = fileExtension(kind: geo.kind, url: url)
            let expectedName = Self.expectedName(kind: geo.kind, ext: ext)
             
             
             
             
             
            if preferBundled, try BundledGeodataProvisioner.seedIfAvailable(
                fileName: expectedName,
                into: homeDir
            ) {
                continue
            }
             
             
             
             
             
            let result = try await downloader.fetch(
                URLRequest(url: url),
                maxBytes: maxBytesEach,
                redirectPolicy: .followAcrossOrigins(maxHops: 5)
            )
            guard result.data.count <= maxBytesEach else {
                throw DownloadError.tooLarge(result.data.count)
            }
            let sha = SHA256.hash(data: result.data).map { String(format: "%02x", $0) }.joined()
            let blobURL = cacheDir.appendingPathComponent("\(sha).\(ext)")
            if !FileManager.default.fileExists(atPath: blobURL.path) {
                try result.data.write(to: blobURL, options: Self.writeOptions)
            }
             
             
             
             
             
            if let reason = Self.rejectionReason(for: result.data, kind: geo.kind) {
                throw DownloadError.invalidPayload(name: expectedName, reason: reason)
            }
            let namedURL = homeDir.appendingPathComponent(expectedName)
            if validatesWithCore, let reason = Self.coreRejectionReason(
                for: result.data,
                kind: geo.kind,
                extension: ext,
                near: homeDir
            ) {
                throw DownloadError.invalidPayload(name: expectedName, reason: reason)
            }
            try result.data.write(to: namedURL, options: Self.writeOptions)
        }
    }

    private func fileExtension(kind: String, url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty { return ext }
        switch kind {
        case "geosite": return "dat"
        case "asn": return "mmdb"
        default: return "metadb"
        }
    }

     
     
     
     
     
     
     
     
     
     
    static func rejectionReason(for data: Data, kind: String) -> String? {
        guard !data.isEmpty else { return "the download was empty" }
         
        let head = data.prefix(64)
        if let text = String(data: head, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            for marker in ["<!DOCTYPE", "<html", "<?xml", "{", "["]
            where trimmed.lowercased().hasPrefix(marker.lowercased()) {
                return "the server returned a document, not a database"
            }
        }
         
         
         
         
         
        if kind == "asn", data.count > 4096,
           data.range(of: Self.maxMindMetadataMarker) == nil {
            return "the file is not a MaxMind database"
        }
        return nil
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    static func coreRejectionReason(
        for data: Data,
        kind: String,
        extension ext: String,
        near homeDir: URL
    ) -> String? {
         
         
         
        let format = ext == "dat" ? "dat" : "mmdb"
        guard ["geoip", "geosite", "asn"].contains(kind),
              !(kind == "geosite" && format == "mmdb")
        else { return nil }

        let candidate = homeDir.appendingPathComponent(
            ".validate-" + UUID().uuidString + "." + format
        )
        defer { try? FileManager.default.removeItem(at: candidate) }
        do {
            try data.write(to: candidate, options: Self.writeOptions)
        } catch {
             
             
            return nil
        }
        var error: NSError?
        HakoValidateGeodataForIOS(kind, format, candidate.path, &error)
        guard let error else { return nil }
        return error.localizedDescription
    }

     
     
     
     
     
     
     
     
     
     
    private static let maxMindMetadataMarker =
        Data([0xAB, 0xCD, 0xEF]) + Data("MaxMind.com".utf8)

     
    static func expectedName(kind: String, ext: String) -> String {
        switch kind {
        case "geoip": return ext == "dat" ? "GeoIP.dat" : "geoip.metadb"
        case "geosite": return "GeoSite.dat"
        case "asn": return "ASN.mmdb"
        default: return "geoip.metadb"
        }
    }
}
