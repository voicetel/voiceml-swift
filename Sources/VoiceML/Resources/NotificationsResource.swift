import Foundation

/// Account-scoped `/Notifications` compat stubs (always empty list; fetch returns 404).
public final class NotificationsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.joined(separator: "/")
    }

    public func list(_ params: ListNotificationsParams = .init()) async throws -> NotificationsList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Notifications"),
            query: params.queryItems()
        ))
    }

    public func get(_ notificationSid: String) async throws -> JSONObject {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Notifications", notificationSid)
        ))
    }
}
