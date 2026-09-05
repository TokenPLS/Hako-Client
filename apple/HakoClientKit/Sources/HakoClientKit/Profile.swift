import Foundation

public enum ProfileValidationError: LocalizedError, Equatable, Sendable {
    case invalidIdentifier
    case invalidLabel
    case invalidRemoteURL
    case credentialProfileMismatch
    case invalidFileName
    case invalidRefreshInterval
    case invalidOrder

    public var errorDescription: String? {
        switch self {
        case .invalidIdentifier:
            return "Profile identifier is invalid."
        case .invalidLabel:
            return "Profile label is invalid."
        case .invalidRemoteURL:
            return "Profile remote URL is invalid."
        case .credentialProfileMismatch:
            return "Profile source credential belongs to another profile."
        case .invalidFileName:
            return "Profile file name is invalid."
        case .invalidRefreshInterval:
            return "Profile refresh interval is invalid."
        case .invalidOrder:
            return "Profile order is invalid."
        }
    }
}

public struct Revision: Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) throws {
        guard Self.isValid(rawValue) else {
            throw ProfileValidationError.invalidIdentifier
        }
        self.rawValue = rawValue
    }

    public var description: String { "<revision>" }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid revision identifier"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static func isValid(_ value: String) -> Bool {
        !value.isEmpty
            && value.count <= 256
            && value != "."
            && value != ".."
            && !value.contains("/")
            && !value.contains("\\")
            && value.unicodeScalars.allSatisfy {
                !CharacterSet.controlCharacters.contains($0)
            }
    }
}

public struct Profile: Codable, Identifiable, Equatable, Sendable {
    public struct ID: Codable, Hashable, Sendable, CustomStringConvertible {
        public let rawValue: String

        public init(_ rawValue: String) throws {
            guard Revision.isValid(rawValue) else {
                throw ProfileValidationError.invalidIdentifier
            }
            self.rawValue = rawValue
        }

        public var description: String { rawValue }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            do {
                try self.init(value)
            } catch {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid profile identifier"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    public struct RemoteSource: Codable, Equatable, Sendable, CustomStringConvertible {
        public let displayURL: URL
        public let credential: CredentialReference?

        public init(
            requestURL: URL,
            credential: CredentialReference? = nil
        ) throws {
            guard var components = URLComponents(
                url: requestURL,
                resolvingAgainstBaseURL: false
            ), let scheme = components.scheme?.lowercased(),
               (scheme == "https" || scheme == "http"),
               components.host?.isEmpty == false else {
                throw ProfileValidationError.invalidRemoteURL
            }
            components.scheme = scheme
             
             
             
             
             
            guard let displayURL = components.url else {
                throw ProfileValidationError.invalidRemoteURL
            }
            self.displayURL = displayURL
            self.credential = credential
        }

        public var description: String {
            let host = displayURL.host ?? "remote"
            let credentialID = credential?.id ?? "none"
            return "RemoteSource(host: \(host), credential: \(credentialID))"
        }

        private enum CodingKeys: String, CodingKey {
            case displayURL
            case credential
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let url = try container.decode(URL.self, forKey: .displayURL)
            let credential = try container.decodeIfPresent(
                CredentialReference.self,
                forKey: .credential
            )
            do {
                try self.init(requestURL: url, credential: credential)
            } catch {
                throw DecodingError.dataCorruptedError(
                    forKey: .displayURL,
                    in: container,
                    debugDescription: "Invalid remote profile URL"
                )
            }
        }
    }

    public struct FileSource: Codable, Equatable, Sendable {
        public let displayName: String

        public init(displayName: String) throws {
            let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard displayName == trimmed,
                  !trimmed.isEmpty,
                  trimmed.count <= 256,
                  trimmed != ".",
                  trimmed != "..",
                  !trimmed.contains("/"),
                  !trimmed.contains("\\"),
                  trimmed.unicodeScalars.allSatisfy({
                      !CharacterSet.controlCharacters.contains($0)
                  }) else {
                throw ProfileValidationError.invalidFileName
            }
            self.displayName = displayName
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            do {
                try self.init(displayName: value)
            } catch {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid profile file name"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(displayName)
        }
    }

    public enum Source: Codable, Equatable, Sendable {
        case remote(RemoteSource)
        case file(FileSource)
        case clipboard
    }

    public struct RefreshPolicy: Codable, Equatable, Sendable {
        public static let manual = RefreshPolicy(intervalHours: nil)

        public let intervalHours: Int?

        private init(intervalHours: Int?) {
            self.intervalHours = intervalHours
        }

        public static func automatic(everyHours: Int) throws -> RefreshPolicy {
            guard (1...24 * 30).contains(everyHours) else {
                throw ProfileValidationError.invalidRefreshInterval
            }
            return RefreshPolicy(intervalHours: everyHours)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                self = .manual
                return
            }
            let value = try container.decode(Int.self)
            do {
                self = try .automatic(everyHours: value)
            } catch {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid profile refresh interval"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(intervalHours)
        }
    }

    public let id: ID
    public var label: String
    public var source: Source
    public var refreshPolicy: RefreshPolicy
    public var activeRuntimeRevision: Revision?
    public var order: Int

    public init(
        id: ID,
        label: String,
        source: Source,
        refreshPolicy: RefreshPolicy,
        activeRuntimeRevision: Revision?,
        order: Int
    ) throws {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard label == trimmed,
              !trimmed.isEmpty,
              trimmed.count <= 256,
              trimmed.unicodeScalars.allSatisfy({
                  !CharacterSet.controlCharacters.contains($0)
              }) else {
            throw ProfileValidationError.invalidLabel
        }
        guard order >= 0 else { throw ProfileValidationError.invalidOrder }
        if case .remote(let remote) = source,
           let credential = remote.credential,
           credential.profileID != id {
            throw ProfileValidationError.credentialProfileMismatch
        }
        self.id = id
        self.label = label
        self.source = source
        self.refreshPolicy = refreshPolicy
        self.activeRuntimeRevision = activeRuntimeRevision
        self.order = order
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case label
        case source
        case refreshPolicy
        case activeRuntimeRevision
        case order
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                id: container.decode(ID.self, forKey: .id),
                label: container.decode(String.self, forKey: .label),
                source: container.decode(Source.self, forKey: .source),
                refreshPolicy: container.decode(RefreshPolicy.self, forKey: .refreshPolicy),
                activeRuntimeRevision: container.decodeIfPresent(
                    Revision.self,
                    forKey: .activeRuntimeRevision
                ),
                order: container.decode(Int.self, forKey: .order)
            )
        } catch let error as DecodingError {
            throw error
        } catch {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid profile",
                    underlyingError: error
                )
            )
        }
    }
}
