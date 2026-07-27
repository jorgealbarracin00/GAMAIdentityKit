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

        let authenticatedSession: InternalAuthenticatedSession
        switch path {
        case "register":
            guard let envelope = try? decoder.decode(RegistrationEnvelope.self, from: response.data) else {
                throw GAMAIdentityError.invalidResponse
            }
            authenticatedSession = try envelope.authenticatedSession(email: email)
        case "login":
            guard let envelope = try? decoder.decode(LoginEnvelope.self, from: response.data) else {
                throw GAMAIdentityError.invalidResponse
            }
            authenticatedSession = try envelope.authenticatedSession(email: email)
        default:
            throw GAMAIdentityError.invalidResponse
        }

        return authenticatedSession.storedSession
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
        case 400 where code == "INVALID_REGISTRATION_DETAILS":
            throw GAMAIdentityError.invalidRegistrationDetails
        case 400 where code == "INVALID_REQUEST":
            // The SDK creates request bodies, so this indicates a contract mismatch
            // rather than ordinary user-entered registration validation.
            throw GAMAIdentityError.invalidResponse
        case 409 where code == "REGISTRATION_UNAVAILABLE":
            throw GAMAIdentityError.registrationUnavailable
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
