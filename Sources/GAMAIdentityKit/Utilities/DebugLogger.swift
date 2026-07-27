import Foundation

struct DebugLogger: Sendable {
    let isEnabled: Bool

    func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[GAMAIdentityKit] \(message())")
    }
}
