import Foundation

/// An immutable description of the identity associated with an authenticated session.
///
/// Session values are created and managed exclusively by ``GAMAIdentityClient``.
/// They intentionally contain no bearer token or other authentication credential.
public struct GAMAIdentitySession: Equatable, Sendable {
    /// The stable GAMA Identity identifier for the authenticated user.
    public let userID: String

    /// The email address associated with the authenticated user.
    public let email: String

    /// The server-provided expiration time, or `nil` when the service does not
    /// provide one.
    ///
    /// This value is advisory. Use ``GAMAIdentityClient/validateSession()`` when
    /// server-confirmed validity is required.
    public let expiresAt: Date?

    init(userID: String, email: String, expiresAt: Date? = nil) {
        self.userID = userID
        self.email = email
        self.expiresAt = expiresAt
    }
}
