import Foundation

struct Credentials: Encodable, Sendable {
    let email: String
    let password: String
}

struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable {
        let code: String
        let message: String
    }
    let error: Detail
}

struct AuthenticationEnvelope: Decodable {
    struct User: Decodable {
        let id: String
        let email: String
    }
    struct Session: Decodable {
        let token: String?
        let id: String?
        let expiresAt: Date?
    }

    let token: String?
    let sessionToken: String?
    let user: User
    let session: Session?

    var bearerToken: String? { token ?? sessionToken ?? session?.token ?? session?.id }
    var publicSession: GAMAIdentitySession {
        GAMAIdentitySession(userID: user.id, email: user.email, expiresAt: session?.expiresAt)
    }
}

struct SessionEnvelope: Decodable {
    struct User: Decodable {
        let id: String
        let email: String
    }
    struct Session: Decodable {
        let expiresAt: Date?
    }

    let user: User
    let session: Session?

    var publicSession: GAMAIdentitySession {
        GAMAIdentitySession(userID: user.id, email: user.email, expiresAt: session?.expiresAt)
    }
}

struct IdentityAPI: Sendable {
    private let transport: any HTTPTransport
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(transport: any HTTPTransport) {
        self.transport = transport
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func authenticate(path: String, email: String, password: String) async throws -> StoredSession {
        let body: Data
        do {
            body = try encoder.encode(Credentials(email: email, password: password))
        } catch {
            throw GAMAIdentityError.unknown
        }
        let response = try await transport.execute(HTTPRequest(method: "POST", path: path, body: body))
        try validate(response)
        guard let envelope = try? decoder.decode(AuthenticationEnvelope.self, from: response.data),
              let token = envelope.bearerToken, !token.isEmpty else {
            throw GAMAIdentityError.invalidResponse
        }
        return StoredSession(token: token, session: envelope.publicSession)
    }

    func validate(token: String) async throws -> GAMAIdentitySession {
        let response = try await transport.execute(
            HTTPRequest(method: "GET", path: "session", bearerToken: token)
        )
        try validate(response)
        guard let envelope = try? decoder.decode(SessionEnvelope.self, from: response.data) else {
            throw GAMAIdentityError.invalidResponse
        }
        return envelope.publicSession
    }

    func logout(token: String) async throws {
        let response = try await transport.execute(
            HTTPRequest(method: "POST", path: "logout", bearerToken: token)
        )
        try validate(response)
    }

    private func validate(_ response: HTTPResponse) throws {
        guard !(200..<300).contains(response.statusCode) else { return }
        let code = (try? decoder.decode(APIErrorEnvelope.self, from: response.data))?.error.code
        switch response.statusCode {
        case 401 where code == "SESSION_INVALID" || code == "SESSION_EXPIRED":
            throw GAMAIdentityError.sessionExpired
        case 401, 403:
            throw GAMAIdentityError.authenticationFailed
        case 500...599:
            throw GAMAIdentityError.serviceUnavailable
        default:
            throw GAMAIdentityError.unknown
        }
    }
}
