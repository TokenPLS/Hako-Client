import Foundation
import Security

public struct CredentialReference: Codable, Hashable, Sendable, Identifiable,
    CustomStringConvertible {
    public enum Scope: String, Codable, CaseIterable, Sendable {
        case subscription
        case source
        case runtime
        case provider
        case identity
    }

    public let profileID: Profile.ID
    public let scope: Scope
    public let slot: String

    public init(profileID: Profile.ID, scope: Scope, slot: String) throws {
        guard Revision.isValid(slot) else {
            throw CredentialVaultError.invalidReference
        }
        self.profileID = profileID
        self.scope = scope
        self.slot = slot
    }

    public var id: String {
        "\(profileID.rawValue):\(scope.rawValue):\(slot)"
    }

    public var description: String { id }

    private enum CodingKeys: String, CodingKey {
        case profileID
        case scope
        case slot
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                profileID: container.decode(Profile.ID.self, forKey: .profileID),
                scope: container.decode(Scope.self, forKey: .scope),
                slot: container.decode(String.self, forKey: .slot)
            )
        } catch let error as DecodingError {
            throw error
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .slot,
                in: container,
                debugDescription: "Invalid credential reference"
            )
        }
    }
}

public enum CredentialVaultError: LocalizedError, Equatable, Sendable {
    public enum Operation: String, Sendable {
        case read
        case set
        case remove
    }

    case invalidReference
    case invalidService
    case unexpectedStatus(operation: Operation, status: Int32)

    public var errorDescription: String? {
        switch self {
        case .invalidReference:
            return "Credential reference is invalid."
        case .invalidService:
            return "Credential service is invalid."
        case let .unexpectedStatus(operation, status):
            return "Credential vault \(operation.rawValue) failed with status \(status)."
        }
    }
}

public protocol CredentialReading: Sendable {
    func data(for reference: CredentialReference) async throws -> Data?
}

public protocol CredentialVault: CredentialReading {
    func set(_ value: Data, for reference: CredentialReference) async throws
    func remove(_ reference: CredentialReference) async throws
}

public enum CredentialMutation: Sendable, CustomStringConvertible {
    case set(CredentialReference, Data)
    case remove(CredentialReference)

    public var reference: CredentialReference {
        switch self {
        case .set(let reference, _), .remove(let reference):
            return reference
        }
    }

    public var description: String {
        switch self {
        case .set(let reference, _):
            return "set(\(reference.id), value: <redacted>)"
        case .remove(let reference):
            return "remove(\(reference.id))"
        }
    }
}

public actor InMemoryCredentialVault: CredentialVault {
    private var values: [CredentialReference: Data]

    public init(values: [CredentialReference: Data] = [:]) {
        self.values = values
    }

    public func data(for reference: CredentialReference) -> Data? {
        values[reference]
    }

    public func set(_ value: Data, for reference: CredentialReference) {
        values[reference] = value
    }

    public func remove(_ reference: CredentialReference) {
        values.removeValue(forKey: reference)
    }
}

public actor KeychainCredentialVault: CredentialVault {
    private let service: String
    private let accessGroup: String?

    public init(
        service: String = HakoClientKitIdentifiers.keychainService,
        accessGroup: String? = nil
    ) throws {
        let trimmed = service.trimmingCharacters(in: .whitespacesAndNewlines)
        guard service == trimmed, !trimmed.isEmpty else {
            throw CredentialVaultError.invalidService
        }
        self.service = service
        self.accessGroup = accessGroup
    }

    public func data(for reference: CredentialReference) throws -> Data? {
        var query = baseQuery(reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var output: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &output)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw CredentialVaultError.unexpectedStatus(
                operation: .read,
                status: status
            )
        }
        return output as? Data
    }

    public func set(_ value: Data, for reference: CredentialReference) throws {
        let query = baseQuery(reference)
        let attributes: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw CredentialVaultError.unexpectedStatus(
                operation: .set,
                status: updateStatus
            )
        }
        var insertion = query
        for (key, value) in attributes { insertion[key] = value }
        let addStatus = SecItemAdd(insertion as CFDictionary, nil)
        if addStatus == errSecSuccess { return }
        if addStatus == errSecDuplicateItem {
            let retryStatus = SecItemUpdate(
                query as CFDictionary,
                attributes as CFDictionary
            )
            guard retryStatus == errSecSuccess else {
                throw CredentialVaultError.unexpectedStatus(
                    operation: .set,
                    status: retryStatus
                )
            }
            return
        }
        guard addStatus == errSecSuccess else {
            throw CredentialVaultError.unexpectedStatus(
                operation: .set,
                status: addStatus
            )
        }
    }

    public func remove(_ reference: CredentialReference) throws {
        let status = SecItemDelete(baseQuery(reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialVaultError.unexpectedStatus(
                operation: .remove,
                status: status
            )
        }
    }

    private func baseQuery(_ reference: CredentialReference) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference.id,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }
}
