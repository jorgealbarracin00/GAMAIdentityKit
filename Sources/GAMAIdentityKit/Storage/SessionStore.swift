import Foundation

struct StoredSession: Equatable, Sendable {
    let token: String
    let session: GAMAIdentitySession
}

extension StoredSession: Codable {
    private enum CodingKeys: String, CodingKey {
        case token
        case session
    }

    private struct PersistedSession: Codable {
        let userID: String
        let email: String
        let expiresAt: Date?
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        let persisted = try container.decode(PersistedSession.self, forKey: .session)
        session = GAMAIdentitySession(
            userID: persisted.userID,
            email: persisted.email,
            expiresAt: persisted.expiresAt
        )
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token, forKey: .token)
        try container.encode(
            PersistedSession(
                userID: session.userID,
                email: session.email,
                expiresAt: session.expiresAt
            ),
            forKey: .session
        )
    }
}

protocol SessionStore: Sendable {
    func load() throws -> StoredSession?
    func save(_ session: StoredSession) throws
    func clear() throws
}
