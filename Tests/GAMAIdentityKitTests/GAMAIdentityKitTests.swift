import Foundation
import Testing
@testable import GAMAIdentityKit

@Suite("GAMAIdentityKit")
struct GAMAIdentityKitTests {
    @Test("Configuration accepts a service URL and rejects malformed URLs")
    func configurationValidation() throws {
        let valid = GAMAIdentityConfiguration(baseURL: URL(string: "https://identity.example.com")!)
        #expect(try valid.validatedBaseURL() == URL(string: "https://identity.example.com")!)
        _ = try GAMAIdentityClient(configuration: valid)

        let invalid = GAMAIdentityConfiguration(baseURL: URL(string: "file:///tmp/identity")!)
        #expect(throws: GAMAIdentityError.configurationError) {
            try GAMAIdentityClient(configuration: invalid)
        }
    }

    @Test("Login encodes credentials, persists the private token, and publishes safe session data")
    func loginFlow() async throws {
        let transport = MockTransport(responses: [
            HTTPResponse(
                data: Data(#"{"token":"private-token","user":{"id":"user-1","email":"person@example.com"},"session":{"expiresAt":"2030-01-01T00:00:00Z"}}"#.utf8),
                statusCode: 200
            )
        ])
        let store = MemorySessionStore()
        let client = makeClient(transport: transport, store: store)

        let session = try await client.login(email: " person@example.com ", password: "secret")
        #expect(session.userID == "user-1")
        #expect(session.email == "person@example.com")
        #expect(store.value?.token == "private-token")
        #expect(await client.currentSession == session)

        let request = try #require(await transport.requests.first)
        #expect(request.method == "POST")
        #expect(request.path == "login")
        #expect(request.bearerToken == nil)
        let credentials = try JSONDecoder().decode([String: String].self, from: #require(request.body))
        #expect(credentials == ["email": "person@example.com", "password": "secret"])
    }

    @Test("Register uses the registration endpoint")
    func registerFlow() async throws {
        let transport = MockTransport(responses: [Self.authResponse])
        let client = makeClient(transport: transport)
        _ = try await client.register(email: "new@example.com", password: "secret")
        #expect(await transport.requests.first?.path == "register")
    }

    @Test(arguments: [
        (
            400,
            #"{"error":{"code":"INVALID_REGISTRATION_DETAILS","message":"Registration details are invalid"}}"#,
            GAMAIdentityError.invalidRegistrationDetails
        ),
        (
            400,
            #"{"error":{"code":"INVALID_REQUEST","message":"Invalid request body"}}"#,
            GAMAIdentityError.invalidResponse
        ),
        (
            409,
            #"{"error":{"code":"REGISTRATION_UNAVAILABLE","message":"Registration unavailable"}}"#,
            GAMAIdentityError.registrationUnavailable
        ),
        (
            400,
            #"{"error":{"code":"UNRECOGNIZED_VALIDATION","message":"Unknown validation"}}"#,
            GAMAIdentityError.unknown
        )
    ])
    func registrationErrorMapping(
        status: Int,
        body: String,
        expected: GAMAIdentityError
    ) async {
        let transport = MockTransport(responses: [
            HTTPResponse(data: Data(body.utf8), statusCode: status)
        ])
        let client = makeClient(transport: transport)

        await #expect(throws: expected) {
            try await client.register(email: "new@example.com", password: "invalid")
        }
    }

    @Test("Session restoration does not call the network")
    func restoreSession() async throws {
        let expected = GAMAIdentitySession(userID: "u1", email: "a@example.com")
        let store = MemorySessionStore(value: StoredSession(token: "token", session: expected))
        let transport = MockTransport()
        let client = makeClient(transport: transport, store: store)

        #expect(try await client.restoreSession() == expected)
        #expect(await client.currentSession == expected)
        #expect(await transport.requests.isEmpty)
    }

    @Test("Validation attaches the bearer token and refreshes public session data")
    func validateSession() async throws {
        let old = GAMAIdentitySession(userID: "u1", email: "old@example.com")
        let store = MemorySessionStore(value: StoredSession(token: "private", session: old))
        let transport = MockTransport(responses: [
            HTTPResponse(
                data: Data(#"{"user":{"id":"u1","email":"new@example.com"},"session":{}}"#.utf8),
                statusCode: 200
            )
        ])
        let client = makeClient(transport: transport, store: store)
        _ = try await client.restoreSession()

        let refreshed = try await client.validateSession()
        #expect(refreshed.email == "new@example.com")
        let request = try #require(await transport.requests.first)
        #expect(request.method == "GET")
        #expect(request.path == "session")
        #expect(request.bearerToken == "private")
    }

    @Test("An expired session is cleared")
    func expiredSession() async throws {
        let session = GAMAIdentitySession(userID: "u1", email: "a@example.com")
        let store = MemorySessionStore(value: StoredSession(token: "expired", session: session))
        let transport = MockTransport(responses: [
            HTTPResponse(
                data: Data(#"{"error":{"code":"SESSION_INVALID","message":"A bearer session is required"}}"#.utf8),
                statusCode: 401
            )
        ])
        let client = makeClient(transport: transport, store: store)
        _ = try await client.restoreSession()

        await #expect(throws: GAMAIdentityError.sessionExpired) {
            try await client.validateSession()
        }
        #expect(store.value == nil)
        #expect(await client.currentSession == nil)
    }

    @Test("Logout calls the API before clearing local state")
    func logout() async throws {
        let session = GAMAIdentitySession(userID: "u1", email: "a@example.com")
        let store = MemorySessionStore(value: StoredSession(token: "private", session: session))
        let transport = MockTransport(responses: [
            HTTPResponse(data: Data(#"{"ok":true}"#.utf8), statusCode: 204)
        ])
        let client = makeClient(transport: transport, store: store)
        _ = try await client.restoreSession()
        try await client.logout()

        #expect(store.value == nil)
        #expect(await client.currentSession == nil)
        #expect(await transport.requests.first?.bearerToken == "private")
    }

    @Test(arguments: [
        (401, #"{"error":{"code":"CREDENTIALS_INVALID","message":"Invalid credentials"}}"#, GAMAIdentityError.authenticationFailed),
        (500, #"{"error":{"code":"INTERNAL","message":"Failure"}}"#, GAMAIdentityError.serviceUnavailable)
    ])
    func errorMapping(status: Int, body: String, expected: GAMAIdentityError) async {
        let transport = MockTransport(responses: [
            HTTPResponse(data: Data(body.utf8), statusCode: status)
        ])
        let client = makeClient(transport: transport)
        await #expect(throws: expected) {
            try await client.login(email: "a@example.com", password: "wrong")
        }
    }

    @Test("Malformed success responses are rejected")
    func invalidResponse() async {
        let transport = MockTransport(responses: [
            HTTPResponse(data: Data(#"{"unexpected":true}"#.utf8), statusCode: 200)
        ])
        let client = makeClient(transport: transport)
        await #expect(throws: GAMAIdentityError.invalidResponse) {
            try await client.login(email: "a@example.com", password: "secret")
        }
    }

    private static let authResponse = HTTPResponse(
        data: Data(#"{"sessionToken":"private","user":{"id":"u1","email":"a@example.com"}}"#.utf8),
        statusCode: 200
    )

    private func makeClient(
        transport: MockTransport,
        store: MemorySessionStore = MemorySessionStore()
    ) -> GAMAIdentityClient {
        GAMAIdentityClient(
            configuration: GAMAIdentityConfiguration(baseURL: URL(string: "https://identity.example.com")!),
            transport: transport,
            store: store
        )
    }
}

private actor MockTransport: HTTPTransport {
    private(set) var requests: [HTTPRequest] = []
    private var responses: [HTTPResponse]

    init(responses: [HTTPResponse] = []) {
        self.responses = responses
    }

    func execute(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw GAMAIdentityError.network }
        return responses.removeFirst()
    }
}

private final class MemorySessionStore: SessionStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: StoredSession?

    init(value: StoredSession? = nil) {
        storage = value
    }

    var value: StoredSession? {
        lock.withLock { storage }
    }

    func load() throws -> StoredSession? {
        lock.withLock { storage }
    }

    func save(_ session: StoredSession) throws {
        lock.withLock { storage = session }
    }

    func clear() throws {
        lock.withLock { storage = nil }
    }
}
