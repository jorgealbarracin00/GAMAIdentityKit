import Foundation

/// The concurrency-safe entry point for GAMA Platform authentication.
///
/// The client owns the complete authentication lifecycle, including network
/// communication, bearer authorization, in-memory state, and Keychain persistence.
/// Access actor-isolated properties and methods with `await` from outside the actor.
public actor GAMAIdentityClient {
    /// The authenticated session currently loaded in memory, or `nil` when the
    /// client has no local authenticated state.
    ///
    /// A newly created client does not read the Keychain automatically. Call
    /// ``restoreSession()`` during application startup to restore local state,
    /// then call ``validateSession()`` when server-confirmed validity is required.
    public private(set) var currentSession: GAMAIdentitySession?

    private let api: IdentityAPI
    private let store: any SessionStore
    private var storedSession: StoredSession?

    /// Creates an identity client after validating its service configuration.
    ///
    /// Initialization does not access the network or restore a saved session.
    ///
    /// - Parameter configuration: The service URL and diagnostic options used by
    ///   the client.
    /// - Throws: ``GAMAIdentityError/configurationError`` when the configured base
    ///   URL is not a valid HTTP or HTTPS service URL.
    public init(configuration: GAMAIdentityConfiguration) throws {
        let logger = DebugLogger(isEnabled: configuration.isDebugLoggingEnabled)
        let baseURL = try configuration.validatedBaseURL()
        api = IdentityAPI(transport: URLSessionTransport(baseURL: baseURL, logger: logger))
        store = KeychainSessionStore()
    }

    init(configuration: GAMAIdentityConfiguration, transport: any HTTPTransport, store: any SessionStore) {
        self.api = IdentityAPI(transport: transport)
        self.store = store
    }

    /// Registers a GAMA Identity account and establishes an authenticated session.
    ///
    /// A successful registration securely persists the new session and updates
    /// ``currentSession``. The operation communicates with the configured service.
    ///
    /// - Parameters:
    ///   - email: The email address for the new account.
    ///   - password: The account password. The SDK never logs or persists it.
    /// - Returns: The newly established authenticated session.
    /// - Throws: ``GAMAIdentityError`` when registration, networking, response
    ///   processing, or secure persistence fails.
    @discardableResult
    public func register(email: String, password: String) async throws -> GAMAIdentitySession {
        try await authenticate(path: "register", email: email, password: password)
    }

    /// Authenticates an existing GAMA Identity account.
    ///
    /// A successful login securely persists the session and updates
    /// ``currentSession``. The operation communicates with the configured service.
    ///
    /// - Parameters:
    ///   - email: The account email address.
    ///   - password: The account password. The SDK never logs or persists it.
    /// - Returns: The authenticated session.
    /// - Throws: ``GAMAIdentityError/authenticationFailed`` for rejected
    ///   credentials, or another ``GAMAIdentityError`` for service, networking,
    ///   response, or secure-persistence failures.
    @discardableResult
    public func login(email: String, password: String) async throws -> GAMAIdentitySession {
        try await authenticate(path: "login", email: email, password: password)
    }

    /// Ends the remote session and then clears its local Keychain and in-memory state.
    ///
    /// The operation communicates with GAMA Identity when a session is loaded. If
    /// no session is loaded, it still clears any local stored state and succeeds.
    /// A session already rejected by the service is treated as logged out. For
    /// other remote failures, the local session is preserved so callers may retry.
    ///
    /// - Throws: ``GAMAIdentityError`` if remote logout or local secure-storage
    ///   removal fails.
    public func logout() async throws {
        guard let token = storedSession?.token else {
            try clearSession()
            return
        }
        do {
            try await api.logout(token: token)
        } catch GAMAIdentityError.sessionExpired {
            // An already-invalid server session still has the desired logged-out state.
        } catch {
            throw error
        }
        try clearSession()
    }

    /// Confirms the loaded session with GAMA Identity and refreshes local session data.
    ///
    /// This operation always requires a loaded session and communicates with the
    /// configured service. Success updates ``currentSession`` and its persisted
    /// representation. If the service rejects the session, the client clears local
    /// state before throwing ``GAMAIdentityError/sessionExpired``.
    ///
    /// - Returns: The server-confirmed session.
    /// - Throws: ``GAMAIdentityError/sessionExpired`` when no usable session exists,
    ///   or another ``GAMAIdentityError`` for networking, response, or secure-storage
    ///   failures.
    @discardableResult
    public func validateSession() async throws -> GAMAIdentitySession {
        guard let storedSession else { throw GAMAIdentityError.sessionExpired }
        do {
            let session = try await api.validate(token: storedSession.token)
            let updated = StoredSession(token: storedSession.token, session: session)
            try store.save(updated)
            self.storedSession = updated
            currentSession = session
            return session
        } catch GAMAIdentityError.sessionExpired {
            try? clearSession()
            throw GAMAIdentityError.sessionExpired
        }
    }

    /// Restores a previously persisted session from the local Keychain.
    ///
    /// Restoration does not communicate with the server and does not prove that the
    /// session remains valid. It updates ``currentSession`` with the restored value.
    /// Call ``validateSession()`` afterward for server-confirmed validity.
    ///
    /// - Returns: The restored session, or `nil` when no session is stored.
    /// - Throws: ``GAMAIdentityError`` if secure storage cannot be read or contains
    ///   an invalid record.
    @discardableResult
    public func restoreSession() throws -> GAMAIdentitySession? {
        let restored = try store.load()
        storedSession = restored
        currentSession = restored?.session
        return restored?.session
    }

    /// Removes local authentication state without contacting GAMA Identity.
    ///
    /// This method clears both the Keychain record and ``currentSession``. It does
    /// not invalidate the corresponding remote session; use ``logout()`` for that.
    ///
    /// - Throws: ``GAMAIdentityError`` if the Keychain record cannot be removed.
    public func clearSession() throws {
        try store.clear()
        storedSession = nil
        currentSession = nil
    }

    private func authenticate(path: String, email: String, password: String) async throws -> GAMAIdentitySession {
        let authenticated = try await api.authenticate(
            path: path,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        try store.save(authenticated)
        storedSession = authenticated
        currentSession = authenticated.session
        return authenticated.session
    }
}
