import CryptoKit
import Foundation

 
 
 
 
 
 
 
 
 
 
struct BundledGeodataManifest: Decodable, Equatable {
    struct Resource: Decodable, Equatable {
        let kind: String
        let fileName: String
        let sourceAsset: String
        let downloadURL: String
        let size: Int
        let sha256: String
    }

    let schemaVersion: Int
    let upstreamRepository: String
    let upstreamRevision: String
    let releaseTag: String
    let publishedAt: String
    let licenseFile: String
    let resources: [Resource]
}

enum BundledGeodataProvisioningError: LocalizedError, Equatable {
    case missingManifest
    case invalidManifest(String)
    case missingResource(String)
    case sizeMismatch(file: String, expected: Int, actual: Int)
    case checksumMismatch(file: String)

    var errorDescription: String? {
        switch self {
        case .missingManifest:
            return "The built-in Geo data manifest is missing."
        case let .invalidManifest(reason):
            return "The built-in Geo data manifest is invalid: \(reason)"
        case let .missingResource(file):
            return "The built-in Geo data resource \(file) is missing."
        case let .sizeMismatch(file, expected, actual):
            return "The built-in Geo data resource \(file) has size \(actual), expected \(expected)."
        case let .checksumMismatch(file):
            return "The built-in Geo data resource \(file) failed integrity verification."
        }
    }
}

 
 
 
enum BundledGeodataProvisioner {
    static let manifestName = "BundledGeoDataManifest"

    static func manifest(in bundle: Bundle = .main) throws -> BundledGeodataManifest {
        guard let url = bundle.url(forResource: manifestName, withExtension: "json") else {
            throw BundledGeodataProvisioningError.missingManifest
        }
        let manifest = try JSONDecoder().decode(
            BundledGeodataManifest.self,
            from: Data(contentsOf: url)
        )
        try validate(manifest)
        return manifest
    }

    static func seedAllMissing(
        into homeDirectory: URL,
        bundle: Bundle = .main
    ) throws {
        let manifest = try manifest(in: bundle)
        try seedMissing(
            manifest.resources,
            into: homeDirectory,
            resourceURL: { bundleURL(for: $0.sourceAsset, in: bundle) }
        )
    }

    static func seedMissing(
        fileNames: Set<String>,
        into homeDirectory: URL,
        bundle: Bundle = .main
    ) throws {
        let manifest = try manifest(in: bundle)
        let selected = manifest.resources.filter { fileNames.contains($0.fileName) }
        guard selected.count == fileNames.count else {
            let known = Set(selected.map(\.fileName))
            let missing = fileNames.subtracting(known).sorted().joined(separator: ", ")
            throw BundledGeodataProvisioningError.invalidManifest(
                "no descriptor for \(missing)"
            )
        }
        try seedMissing(
            selected,
            into: homeDirectory,
            resourceURL: { bundleURL(for: $0.sourceAsset, in: bundle) }
        )
    }

     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
     
    @discardableResult
    static func seedIfAvailable(
        fileName: String,
        into homeDirectory: URL,
        bundle: Bundle = .main
    ) throws -> Bool {
        let manifest = try manifest(in: bundle)
        guard let resource = manifest.resources.first(where: {
            $0.fileName == fileName
        }) else {
            return false
        }
        try seedMissing(
            [resource],
            into: homeDirectory,
            resourceURL: { bundleURL(for: $0.sourceAsset, in: bundle) }
        )
        return true
    }

    static func seedMissing(
        _ resources: [BundledGeodataManifest.Resource],
        into homeDirectory: URL,
        resourceURL: (BundledGeodataManifest.Resource) -> URL?
    ) throws {
        try FileManager.default.createDirectory(
            at: homeDirectory,
            withIntermediateDirectories: true
        )

        for resource in resources {
            let destination = homeDirectory.appendingPathComponent(resource.fileName)
            if FileManager.default.fileExists(atPath: destination.path) {
                continue
            }
            guard let source = resourceURL(resource) else {
                throw BundledGeodataProvisioningError.missingResource(resource.fileName)
            }
            try verify(resource, at: source)

            let temporary = homeDirectory.appendingPathComponent(
                ".\(resource.fileName).\(UUID().uuidString).tmp"
            )
            do {
                try FileManager.default.copyItem(at: source, to: temporary)
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: temporary.path
                )
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: temporary)
                } else {
                    try FileManager.default.moveItem(at: temporary, to: destination)
                }
            } catch {
                try? FileManager.default.removeItem(at: temporary)
                throw error
            }
        }
    }

    static func verify(
        _ resource: BundledGeodataManifest.Resource,
        at url: URL
    ) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let actualSize = (attributes[.size] as? NSNumber)?.intValue ?? -1
        guard actualSize == resource.size else {
            throw BundledGeodataProvisioningError.sizeMismatch(
                file: resource.fileName,
                expected: resource.size,
                actual: actualSize
            )
        }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        guard digest == resource.sha256.lowercased() else {
            throw BundledGeodataProvisioningError.checksumMismatch(file: resource.fileName)
        }
    }

    private static func validate(_ manifest: BundledGeodataManifest) throws {
        guard manifest.schemaVersion == 1 else {
            throw BundledGeodataProvisioningError.invalidManifest(
                "unsupported schema \(manifest.schemaVersion)"
            )
        }
        let expected = Set(["GeoIP.dat", "GeoSite.dat", "geoip.metadb", "ASN.mmdb"])
        let actual = Set(manifest.resources.map(\.fileName))
        guard manifest.resources.count == expected.count, actual == expected else {
            throw BundledGeodataProvisioningError.invalidManifest(
                "the four required Core lookup files are not described exactly once"
            )
        }
        guard manifest.resources.allSatisfy({ resource in
            resource.fileName == URL(fileURLWithPath: resource.fileName).lastPathComponent
                && resource.sourceAsset == URL(fileURLWithPath: resource.sourceAsset).lastPathComponent
                && URL(string: resource.downloadURL)?.scheme == "https"
                && resource.size > 0
                && resource.sha256.range(
                    of: "^[0-9a-f]{64}$",
                    options: .regularExpression
                ) != nil
        }) else {
            throw BundledGeodataProvisioningError.invalidManifest(
                "a descriptor has an unsafe name, size, or SHA-256"
            )
        }
    }

    private static func bundleURL(for asset: String, in bundle: Bundle) -> URL? {
        let path = asset as NSString
        return bundle.url(
            forResource: path.deletingPathExtension,
            withExtension: path.pathExtension
        )
    }
}
