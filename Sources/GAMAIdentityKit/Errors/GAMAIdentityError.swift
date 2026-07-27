import Foundation

/// A sanitized, application-facing error produced by GAMA Identity operations.
///
/// The error surface describes identity-domain outcomes without exposing
/// `URLSession`, HTTP status codes, backend payloads, or authentication secrets.
public enum GAMAIdentityError: Error, Equatable, Sendable {
    /// The identity service could not be reached because of a connectivity failure.
    case network

    /// The supplied credentials were not accepted.
    case authenticationFailed

    /// The supplied email or password does not meet the service's registration
    /// requirements.
    ///
    /// This case does not expose which individual requirement was rejected.
    case invalidRegistrationDetails

    /// Registration cannot be completed with the supplied account details.
    ///
    /// This case intentionally does not confirm whether a particular account
    /// already exists.
    case registrationUnavailable

    /// No usable authenticated session exists, or the service rejected the
    /// restored session as expired or invalid.
    case sessionExpired

    /// The service returned data that the SDK could not safely interpret.
    case invalidResponse

    /// The client configuration is invalid.
    case configurationError

    /// The identity service is temporarily unable to complete the operation.
    case serviceUnavailable

    /// An unexpected failure occurred that has no more specific public category.
    case unknown
}

extension GAMAIdentityError: LocalizedError {
    /// A concise, user-presentable description of the error.
    public var errorDescription: String? {
        switch self {
        case .network: "The identity service could not be reached."
        case .authenticationFailed: "The email or password was not accepted."
        case .invalidRegistrationDetails: "The registration details are invalid."
        case .registrationUnavailable: "Registration is unavailable for these details."
        case .sessionExpired: "The session is no longer valid."
        case .invalidResponse: "The identity service returned an invalid response."
        case .configurationError: "The identity client configuration is invalid."
        case .serviceUnavailable: "The identity service is temporarily unavailable."
        case .unknown: "An unexpected identity error occurred."
        }
    }

    /// The underlying reason expressed without transport or backend details.
    public var failureReason: String? {
        switch self {
        case .network: "A network connection to GAMA Identity could not be established."
        case .authenticationFailed: "GAMA Identity could not verify the supplied credentials."
        case .invalidRegistrationDetails:
            "The email or password does not meet the registration requirements."
        case .registrationUnavailable:
            "GAMA Identity cannot register an account using the supplied details."
        case .sessionExpired: "The saved session is missing, expired, or no longer accepted."
        case .invalidResponse: "The response did not match the supported identity contract."
        case .configurationError: "The configured service URL is not a valid HTTP or HTTPS base URL."
        case .serviceUnavailable: "GAMA Identity could not complete the request at this time."
        case .unknown: "The SDK encountered an unclassified failure."
        }
    }

    /// A suggested next step for failures that applications can reasonably recover from.
    public var recoverySuggestion: String? {
        switch self {
        case .network:
            "Check the network connection and try again."
        case .authenticationFailed:
            "Verify the email and password, then try again."
        case .invalidRegistrationDetails:
            "Check the supplied email and password, then try again."
        case .registrationUnavailable:
            "Try signing in or use different account details."
        case .sessionExpired:
            "Ask the user to sign in again."
        case .configurationError:
            "Provide the base URL of a GAMA Identity HTTP or HTTPS service."
        case .serviceUnavailable:
            "Try the operation again later."
        case .invalidResponse, .unknown:
            "Try again later. If the problem continues, report it to the application support team."
        }
    }
}
