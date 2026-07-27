import Foundation
import Security

struct KeychainSessionStore: SessionStore {
    private let service: String
    private let account = "authenticated-session"

    init(service: String = "com.gamadynamics.GAMAIdentityKit") {
        self.service = service
    }

    func load() throws -> StoredSession? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw GAMAIdentityError.unknown
        }
        guard let value = try? JSONDecoder().decode(StoredSession.self, from: data) else {
            try? clear()
            throw GAMAIdentityError.invalidResponse
        }
        return value
    }

    func save(_ session: StoredSession) throws {
        guard let data = try? JSONEncoder().encode(session) else {
            throw GAMAIdentityError.unknown
        }
        let attributes = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var query = baseQuery
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
                throw GAMAIdentityError.unknown
            }
        } else if updateStatus != errSecSuccess {
            throw GAMAIdentityError.unknown
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GAMAIdentityError.unknown
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
