import Foundation

/// The session object shared by authentication transport responses.
///
/// This type represents JSON only. It does not create persistent or public
/// session models.
struct AuthenticationSessionPayload: Decodable {
    let sessionId: String
    let humanIdentityId: String
    let expiresAt: Date
}

/// The transport envelope returned by the registration endpoint.
///
/// This type is limited to decoding the registration JSON contract.
struct RegistrationEnvelope: Decodable {
    let humanIdentityId: String
    let session: AuthenticationSessionPayload
}

/// The transport envelope returned by the login endpoint.
///
/// This type is limited to decoding the login JSON contract.
struct LoginEnvelope: Decodable {
    let session: AuthenticationSessionPayload
}
