# GAMAIdentityKit

`GAMAIdentityKit` is the official Swift client for GAMA Platform Identity. It gives
GAMA applications a small, concurrency-safe authentication API while encapsulating
HTTP requests, JSON, bearer authorization, error translation, and Keychain storage.

## Requirements

- iOS 18 or later
- Swift 6
- No third-party dependencies

## Installation

In Xcode:

1. Choose **File → Add Package Dependencies**.
2. Enter the repository URL for `GAMAIdentityKit`.
3. Select an approved `1.x` release.
4. Add the `GAMAIdentityKit` library product to the application target.

Then import the module:

```swift
import GAMAIdentityKit
```

## Initialization and configuration

Create one long-lived client for the application:

```swift
let configuration = GAMAIdentityConfiguration(
    baseURL: URL(string: "https://gama-identity-production.up.railway.app")!
)

let identity = try GAMAIdentityClient(configuration: configuration)
```

The base URL determines the deployment environment; the package does not hardcode
production, staging, or development. Client creation fails with
`GAMAIdentityError.configurationError` when the URL is not a valid HTTP or HTTPS
service URL.

Sanitized diagnostic logging is disabled by default. It may be enabled during
development:

```swift
let configuration = GAMAIdentityConfiguration(
    baseURL: identityURL,
    isDebugLoggingEnabled: true
)
```

Logs never include passwords, bearer tokens, session identifiers, or authorization
headers.

## Registration

Registration creates the account **and establishes an authenticated session**:

```swift
let session = try await identity.register(
    email: email,
    password: password
)
```

On success, the SDK securely stores the bearer credential and updates
`currentSession`. Applications receive only safe user and expiry information.

## Login

```swift
let session = try await identity.login(
    email: email,
    password: password
)
```

Successful login securely persists the session and updates `currentSession`.

## Current session

Because the client is an actor, read its state with `await`:

```swift
if let session = await identity.currentSession {
    print(session.email)
}
```

A newly created client starts with `currentSession == nil`. It does not
automatically read the Keychain.

## Authentication lifecycle

The expected application startup flow is:

```text
Application launch
        ↓
restoreSession() — local Keychain only
        ↓
validateSession() — confirms with GAMA Identity
        ↓
Authenticated experience or login screen
```

A complete startup example:

```swift
import GAMAIdentityKit

let identity: GAMAIdentityClient

do {
    let configuration = GAMAIdentityConfiguration(
        baseURL: URL(string: "https://gama-identity-production.up.railway.app")!
    )
    identity = try GAMAIdentityClient(configuration: configuration)
} catch {
    // Treat invalid application configuration as a setup failure.
    fatalError("Unable to configure GAMA Identity: \(error)")
}

do {
    if try await identity.restoreSession() != nil {
        _ = try await identity.validateSession()
        // Present the authenticated experience.
    } else {
        // Present the login screen.
    }
} catch GAMAIdentityError.sessionExpired {
    // The SDK removed the rejected local session.
    // Present the login screen.
} catch {
    // Decide whether to retry or present an offline/service message.
}
```

### `restoreSession()`

Reads a saved session from the local Keychain and updates `currentSession`. It does
not contact the server and does not prove that the session is still valid.

```swift
let restored = try await identity.restoreSession()
```

### `validateSession()`

Contacts GAMA Identity to confirm the loaded session. On success it refreshes the
persisted and in-memory session. If the session is invalid or expired, the SDK
clears local state and throws `GAMAIdentityError.sessionExpired`.

```swift
let validated = try await identity.validateSession()
```

## Logout and local clearing

Use `logout()` for a normal user-initiated sign-out:

```swift
try await identity.logout()
```

`logout()` contacts GAMA Identity to end the remote session and then removes local
Keychain and in-memory state. If a non-session-related remote failure occurs, local
state is preserved so the application can retry.

Use `clearSession()` only when local credentials must be removed without contacting
the service:

```swift
try await identity.clearSession()
```

`clearSession()` does not invalidate the remote session.

## Errors

Public operations expose only semantic `GAMAIdentityError` values:

- `network`
- `authenticationFailed`
- `sessionExpired`
- `invalidResponse`
- `configurationError`
- `serviceUnavailable`
- `unknown`

The SDK never exposes URL-loading errors, HTTP status codes, backend error payloads,
or authentication secrets. `LocalizedError` descriptions, failure reasons, and
recovery suggestions are available for diagnostics and user-experience decisions.

## Troubleshooting

### The client cannot be created

Confirm that `baseURL` uses `http` or `https`, includes a host, and contains no
query or fragment. Production applications should use HTTPS.

### A saved session is immediately rejected

Restored Keychain state is intentionally not assumed to be valid. Call
`validateSession()` after restoration and present login when it throws
`sessionExpired`.

### Logout failed and the user still appears signed in

For connectivity or service failures, `logout()` preserves local state so it can
be retried. If product policy requires immediate local removal despite that
failure, explicitly call `clearSession()`.

### No session is restored

`restoreSession()` returns `nil` when no Keychain session exists, including after
logout or explicit local clearing. Present the login or registration experience.

### Debugging a service problem

Enable `isDebugLoggingEnabled` in a development build. Diagnostic output is
sanitized, but it should normally remain disabled in production.

## Architecture

`GAMAIdentityClient` is an actor that serializes authentication and session state.
An internal API layer handles request encoding, response decoding, and semantic
error mapping. An internal `URLSession` transport owns HTTP execution and bearer
authorization. An internal Keychain store persists the private session record using
device-only protection.

Applications interact only with configuration, the client, immutable session
values, and semantic identity errors. Tests replace networking and storage with
deterministic in-memory implementations and never contact production services.
