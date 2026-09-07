import Foundation

 
 
 
 
 
 
 
public struct BackupEnvelope: Equatable, Sendable {
    public static let supportedSchemaVersion = 5
    public static let effectiveStageAfterClientTransforms = "afterClientTransforms"

    public enum Source: Equatable, Sendable {
        case url(String)
        case file(String)
        case clipboard
        case unknown
    }

    public struct ProfileSummary: Equatable, Sendable, Identifiable {
        public let id: String
        public let label: String
        public let source: Source
        public init(id: String, label: String, source: Source) {
            self.id = id
            self.label = label
            self.source = source
        }
    }

    public enum DecodeError: Error, Equatable {
        case unsupportedSchema(Int)
        case malformed
    }

    public let schemaVersion: Int
    public let profiles: [ProfileSummary]
    public let sidecars: [String: String]
    public let effectiveSources: [String: String]
    public let effectiveStage: String?
    public let activeProfileID: String?
     
     
    public let publicResourceProfileIDs: Set<String>
    public let sourceInstallID: String?
    public let sourceDevice: String?
    public let exportedAt: Date?

    public static func decode(_ data: Data) throws -> BackupEnvelope {
        let raw: Raw
        do {
            raw = try JSONDecoder().decode(Raw.self, from: data)
        } catch {
            throw DecodeError.malformed
        }
        let schema = raw.schemaVersion ?? 1
        guard schema <= supportedSchemaVersion else { throw DecodeError.unsupportedSchema(schema) }
        return BackupEnvelope(
            schemaVersion: schema,
            profiles: raw.profiles.map { ProfileSummary(id: $0.id, label: $0.label, source: $0.source.value) },
            sidecars: raw.sidecars,
            effectiveSources: raw.effectiveSources ?? [:],
            effectiveStage: raw.effectiveStage,
            activeProfileID: raw.activeProfileID,
            publicResourceProfileIDs: Set((raw.publicResources ?? [:]).filter { !$0.value.isEmpty }.keys),
            sourceInstallID: raw.sourceInstallID,
            sourceDevice: raw.sourceDevice,
            exportedAt: raw.exportedAt?.date
        )
    }

     
     
     
    public func document(for profileID: String) -> (yaml: String, overridesApplied: Bool)? {
        if effectiveStage == Self.effectiveStageAfterClientTransforms, let cooked = effectiveSources[profileID] {
            return (cooked, true)
        }
        guard let raw = sidecars[profileID] else { return nil }
        return (raw, false)
    }

     

    private struct Raw: Decodable {
        let schemaVersion: Int?
        let profiles: [RawProfile]
        let sidecars: [String: String]
        let effectiveSources: [String: String]?
        let effectiveStage: String?
        let activeProfileID: String?
        let publicResources: [String: [String: Data]]?
        let sourceInstallID: String?
        let sourceDevice: String?
        let exportedAt: FlexibleDate?
    }

     
     
     
    private struct FlexibleDate: Decodable {
        let date: Date
        init(from decoder: Decoder) throws {
            let single = try decoder.singleValueContainer()
            if let seconds = try? single.decode(Double.self) {
                date = Date(timeIntervalSinceReferenceDate: seconds)
                return
            }
            let text = try single.decode(String.self)
            let plain = ISO8601DateFormatter()
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let parsed = plain.date(from: text) ?? fractional.date(from: text) else {
                throw DecodingError.dataCorruptedError(in: single, debugDescription: "not a date: \(text)")
            }
            date = parsed
        }
    }

    private struct RawProfile: Decodable {
        let id: String
        let label: String
        let source: RawSource
    }

     
     
     
    private struct RawSource: Decodable {
        let value: Source

        private struct Payload: Decodable { let _0: String? }

        private struct Keys: CodingKey {
            var stringValue: String
            var intValue: Int? { nil }
            init?(stringValue: String) { self.stringValue = stringValue }
            init?(intValue: Int) { nil }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: Keys.self)
            guard let key = container.allKeys.first else {
                value = .unknown
                return
            }
            switch key.stringValue {
            case "url": value = .url(try container.decode(Payload.self, forKey: key)._0 ?? "")
            case "file": value = .file(try container.decode(Payload.self, forKey: key)._0 ?? "")
            case "clipboard": value = .clipboard
            default: value = .unknown
            }
        }
    }
}
