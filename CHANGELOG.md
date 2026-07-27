# Changelog

All notable changes to GAMAIdentityKit are documented in this file.

## 1.0.3

### Changed

- Separated registration and login transport envelopes from the internal
  authenticated-session model.
- Centralized validated authentication mapping and `StoredSession` construction.

### Fixed

- Added compatibility with the production login response contract.
- Added exact login contract and invalid-response tests while preserving
  registration behavior and the public API.

## 1.0.2

### Fixed

- Added compatibility with the production registration response.
- Added exact registration contract tests and defensive validation for required
  identity and session fields.
- Improved registration response decoding while leaving login decoding unchanged.

## 1.0.1

### Added

- Added `GAMAIdentityError.invalidRegistrationDetails` for registration input
  rejected by GAMA Identity.
- Added `GAMAIdentityError.registrationUnavailable` for registration attempts the
  service cannot complete without disclosing whether a particular account exists.

### Fixed

- Mapped the stable `INVALID_REGISTRATION_DETAILS` service response to
  `.invalidRegistrationDetails`.
- Mapped `REGISTRATION_UNAVAILABLE` to `.registrationUnavailable`.
- Mapped `INVALID_REQUEST` to `.invalidResponse`, because the SDK constructs the
  request and a rejection indicates a client/service contract mismatch rather than
  ordinary user validation.

This release changes only SDK error translation. It does not change the GAMA
Identity backend contract.
