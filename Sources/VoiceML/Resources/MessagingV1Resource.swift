import Foundation

/// `client.messagingV1` — Twilio Messaging v1 (messaging.twilio.com/v1).
///
/// The whole group is routed at the messaging host (messaging.voicetel.com) by
/// the client, which is what disambiguates a Messaging Service (`MG…`) from a
/// Conversation Service (`IS…`) — they share the `/v1/Services` path shape.
public final class MessagingV1Resource: Sendable {
    public let pages: PageClient
    public let services: MessagingV1ServicesResource

    init(transport: Transport) {
        self.pages = PageClient(transport: transport)
        self.services = MessagingV1ServicesResource(transport: transport)
    }
}

/// `client.messagingV1.services.phoneNumbers(chatServiceSid:)` — the Messaging
/// Service's sender pool on the messaging host.
public final class MessagingServicePhoneNumbersResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String

    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport
        self.chatServiceSid = chatServiceSid
    }

    private func path(_ parts: String...) throws -> String {
        try transport.rootPath(["v1", "Services", chatServiceSid, "PhoneNumbers"] + parts)
    }

    public func list(_ params: ListMessagingPhoneNumbersParams = .init()) async throws -> MessagingServicePhoneNumberList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path(),
            query: params.queryItems()
        ))
    }

    public func create(_ body: AddMessagingServicePhoneNumberRequest) async throws -> MessagingServicePhoneNumber {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try path(),
            form: body.formFields()
        ))
    }

    public func fetch(sid: String) async throws -> MessagingServicePhoneNumber {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path(sid)
        ))
    }

    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: try path(sid)
        ))
    }
}

/// Operations on `/v1/Services` at the messaging host. `create` / `list` /
/// `fetch` / `delete` reuse the shared path; `update` (`POST /v1/Services/{sid}`)
/// is unique to the Messaging Service.
public final class MessagingV1ServicesResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    /// Sender-pool scope: `client.messagingV1.services.phoneNumbers(chatServiceSid:)`.
    public func phoneNumbers(chatServiceSid: String) -> MessagingServicePhoneNumbersResource {
        MessagingServicePhoneNumbersResource(transport: transport, chatServiceSid: chatServiceSid)
    }

    public func create(_ body: CreateMessagingServiceRequest) async throws -> MessagingService {
        try await transport.request(VoiceMLRequest(method: .post, path: try transport.rootPath(["v1", "Services"]), form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> MessagingServiceList {
        try await transport.request(VoiceMLRequest(method: .get, path: try transport.rootPath(["v1", "Services"]), query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> MessagingService {
        try await transport.request(VoiceMLRequest(method: .get, path: try transport.rootPath(["v1", "Services", sid])))
    }
    public func update(sid: String, _ body: UpdateMessagingServiceRequest) async throws -> MessagingService {
        try await transport.request(VoiceMLRequest(method: .post, path: try transport.rootPath(["v1", "Services", sid]), form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: try transport.rootPath(["v1", "Services", sid])))
    }
}
