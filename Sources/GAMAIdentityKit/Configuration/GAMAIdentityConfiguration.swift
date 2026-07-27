import Foundation

/// Configuration used to connect a ``GAMAIdentityClient`` to GAMA Identity.
///
/// Supply the base URL for the desired deployment environment. The SDK does not
/// hardcode production, staging, or development environments.
public struct GAMAIdentityConfiguration: Sendable {
    /// The root URL of the GAMA Identity service.
    ///
    /// The URL must use HTTP or HTTPS, include a host, and contain neither a
    /// query nor a fragment. ``GAMAIdentityClient/init(configuration:)`` validates
    /// the URL before creating a client.
    public let baseURL: URL

    /// A Boolean value that controls sanitized diagnostic logging.
    ///
    /// Logging is disabled by default. When enabled, the SDK logs request paths
    /// and response status information but never credentials, bearer tokens,
    /// session identifiers, or authorization headers.
    public let isDebugLoggingEnabled: Bool

    /// Creates an immutable identity configuration.
    ///
    /// - Parameters:
    ///   - baseURL: The root URL of the GAMA Identity service.
    ///   - isDebugLoggingEnabled: Whether sanitized diagnostic logging is enabled.
    ///     The default is `false`.
    ///
    /// URL validation occurs when the configuration is passed to
    /// ``GAMAIdentityClient/init(configuration:)``.
    public init(baseURL: URL, isDebugLoggingEnabled: Bool = false) {
        self.baseURL = baseURL
        self.isDebugLoggingEnabled = isDebugLoggingEnabled
    }

    func validatedBaseURL() throws -> URL {
        guard let scheme = baseURL.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              baseURL.host != nil,
              baseURL.query == nil,
              baseURL.fragment == nil else {
            throw GAMAIdentityError.configurationError
        }
        return baseURL
    }
}
