import Foundation

/// A validated authenticated session independent of transport JSON, persistence,
/// and the public SDK model.
struct InternalAuthenticatedSession: Equatable, Sendable {
    let sessionId: String
    let humanIdentityId: String
    let email: String
    let expiresAt: Date

    /// The single conversion point from validated authentication state into the
    /// SDK's persisted private session representation.
    var storedSession: StoredSession {
        StoredSession(
            token: sessionId,
            session: GAMAIdentitySession(
                userID: humanIdentityId,
                email: email,
                expiresAt: expiresAt
            )
        )
    }
}

extension RegistrationEnvelope {
    /// Validates and maps registration transport data into endpoint-independent
    /// authentication state.
    func authenticatedSession(email: String) throws -> InternalAuthenticatedSession {
        guard !session.sessionId.isEmpty,
              !humanIdentityId.isEmpty,
              humanIdentityId == session.humanIdentityId else {
            throw GAMAIdentityError.invalidResponse
        }

        return InternalAuthenticatedSession(
            sessionId: session.sessionId,
            humanIdentityId: humanIdentityId,
            email: email,
            expiresAt: session.expiresAt
        )
    }
}

extension LoginEnvelope {
    /// Validates and maps login transport data into endpoint-independent
    /// authentication state.
    func authenticatedSession(email: String) throws -> InternalAuthenticatedSession {
        guard !session.sessionId.isEmpty,
              !session.humanIdentityId.isEmpty else {
            throw GAMAIdentityError.invalidResponse
        }

        return InternalAuthenticatedSession(
            sessionId: session.sessionId,
            humanIdentityId: session.humanIdentityId,
            email: email,
            expiresAt: session.expiresAt
        )
    }
}
