import Foundation
import Security
import CryptoKit

protocol CredentialStoreBacking: AnyObject {
    func set(_ value: Data, service: String, key: String) throws
    func get(service: String, key: String) -> Data?
    func remove(service: String, key: String) throws
    func removeAll(service: String) throws
}

final class SecurityCredentialStoreBacking: CredentialStoreBacking {
     
     
     
     
     
     
     
     
     
     
     
     
     
    private func baseQuery(service: String, key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key,
          
          
          
         kSecAttrSynchronizable as String: kSecAttrSynchronizableAny]
    }

    func set(_ value: Data, service: String, key: String) throws {
        SecItemDelete(baseQuery(service: service, key: key) as CFDictionary)
        var add = baseQuery(service: service, key: key)
        add[kSecValueData as String] = value
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        add[kSecAttrSynchronizable as String] = true
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStore.CredentialError.unexpectedStatus(status)
        }
    }

    func get(service: String, key: String) -> Data? {
        var query = baseQuery(service: service, key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var output: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &output) == errSecSuccess else {
            return nil
        }
        return output as? Data
    }

    func remove(service: String, key: String) throws {
        let status = SecItemDelete(baseQuery(service: service, key: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStore.CredentialError.unexpectedStatus(status)
        }
    }

    func removeAll(service: String) throws {
         
         
         
        let status = SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStore.CredentialError.unexpectedStatus(status)
        }
    }
}

 
 
final class InMemoryCredentialStoreBacking: CredentialStoreBacking {
    private var values: [String: Data] = [:]
    private let lock = NSLock()

    func set(_ value: Data, service: String, key: String) throws {
        lock.lock()
        values[identity(service: service, key: key)] = value
        lock.unlock()
    }

    func get(service: String, key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[identity(service: service, key: key)]
    }

    func remove(service: String, key: String) throws {
        lock.lock()
        values.removeValue(forKey: identity(service: service, key: key))
        lock.unlock()
    }

    func removeAll(service: String) throws {
        lock.lock()
        let prefix = service + "\u{0}"
        values = values.filter { !$0.key.hasPrefix(prefix) }
        lock.unlock()
    }

    private func identity(service: String, key: String) -> String {
        service + "\u{0}" + key
    }
}

 
 
 
 
 
final class CredentialStore {
    enum CredentialError: Error, Equatable { case unexpectedStatus(OSStatus) }

    private let service: String
    private let backing: CredentialStoreBacking
    init(
        service: String = HakoAppIdentifiers.keychainService,
        backing: CredentialStoreBacking = SecurityCredentialStoreBacking()
    ) {
        self.service = service
        self.backing = backing
    }

    func set(_ value: Data, for key: String) throws {
        try backing.set(value, service: service, key: key)
    }

    func get(_ key: String) -> Data? {
        backing.get(service: service, key: key)
    }

    func remove(_ key: String) throws {
        try backing.remove(service: service, key: key)
    }

    func removeAll() throws {
        try backing.removeAll(service: service)
    }
}
