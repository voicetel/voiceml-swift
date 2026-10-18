import Foundation

/// Account-scoped `/Notifications` — Twilio-compatible alert log.
public final class NotificationsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(parts)
    }

    public func list(_ params: ListNotificationsParams = .init()) async throws -> NotificationsList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path("Notifications"),
            query: params.queryItems()
        ))
    }

    /// Fetch an account-scoped notification by sid.
    public func get(_ notificationSid: String) async throws -> Notification {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path("Notifications", notificationSid)
        ))
    }
}
