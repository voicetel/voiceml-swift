import Foundation

/// `/Messages` REST resource — VoiceTel's Twilio-compatible SMS surface, backed by
/// the SDK 2.2 gateway. Outbound-only today (no MMS, no inbound webhook delivery).
public final class MessagesResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.filter { !$0.isEmpty }.joined(separator: "/")
    }

    /// Dispatch an outbound SMS.
    public func create(_ body: CreateMessageRequest) async throws -> Message {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Messages"),
            form: body.formFields()
        ))
    }

    /// Fetch a previously-sent Message by sid.
    public func fetch(sid: String) async throws -> Message {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Messages", sid)
        ))
    }

    /// Return a single page of `/Messages` matching the supplied filters.
    public func list(_ params: ListMessagesParams = .init()) async throws -> MessageList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Messages"),
            query: params.queryItems()
        ))
    }

    /// Mutate an existing Message — redact `body` or attempt cancel.
    public func update(sid: String, _ body: UpdateMessageRequest) async throws -> Message {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Messages", sid),
            form: body.formFields()
        ))
    }

    /// Remove a Message resource from the account's store.
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path("Messages", sid)
        ))
    }

    /// Walk every page of `/Messages` matching the supplied filters and yield each ``Message``.
    public func iterate(_ params: ListMessagesParams = .init()) -> AsyncThrowingStream<Message, Error> {
        var current = params
        if current.page == nil { current.page = 0 }
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    while true {
                        let chunk = try await self.list(current)
                        for msg in chunk.messages { continuation.yield(msg) }
                        if chunk.nextPageUri == nil || chunk.nextPageUri?.isEmpty == true || chunk.messages.isEmpty {
                            continuation.finish()
                            return
                        }
                        current.page = (current.page ?? 0) + 1
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
