import Foundation

/// `/Messages` REST resource — outbound SMS and MMS.
public final class MessagesResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(parts)
    }

    /// Dispatch an outbound SMS or MMS. The request must carry `body` and/or at least
    /// one `mediaUrl` entry — supplying neither throws ``ConfigurationError`` before any
    /// request is made.
    public func create(_ body: CreateMessageRequest) async throws -> Message {
        if (body.body == nil || body.body?.isEmpty == true)
            && (body.mediaUrl == nil || body.mediaUrl?.isEmpty == true) {
            throw ConfigurationError("messages.create requires body or at least one mediaUrl")
        }
        return try await transport.request(VoiceMLRequest(
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

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: MessageList) async throws -> MessageList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    /// Walk every page of `/Messages` matching the supplied filters and yield each
    /// ``Message``. Lazily follows each page's `next_page_uri`.
    public func iterate(_ params: ListMessagesParams = .init()) -> PagerSequence<Message> {
        PagerSequence(
            firstPage: { [self] in
                let page = try await list(params)
                return PageResult(items: page.messages, nextURL: transport.resolvePageURI(page.nextPageUri))
            },
            followPage: { [self] url in
                let page: MessageList = try await transport.requestPage(url)
                return PageResult(items: page.messages, nextURL: transport.resolvePageURI(page.nextPageUri))
            }
        )
    }

    /// Mutate an existing Message — redact `body` or attempt cancel.
    public func update(sid: String, _ body: UpdateMessageRequest) async throws -> Message {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Messages", sid),
            form: body.formFields()
        ))
    }

    /// Submit delivery feedback for a Message. The server echoes the Feedback
    /// resource back; any outcome other than `"confirmed"` records as
    /// `"unconfirmed"`.
    public func createFeedback(sid: String, _ body: CreateMessageFeedbackRequest) async throws -> MessageFeedback {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Messages", sid, "Feedback"),
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

    /// Media scope for one message: `client.messages.media(messageSid:)`.
    public func media(messageSid: String) -> MessageMediaResource {
        MessageMediaResource(transport: transport, messageSid: messageSid)
    }
}

/// `/Messages/{MessageSid}/Media/…` — MMS attachments on a message.
public final class MessageMediaResource: Sendable {
    private let transport: Transport
    private let messageSid: String

    init(transport: Transport, messageSid: String) {
        self.transport = transport
        self.messageSid = messageSid
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(["Messages", messageSid, "Media"] + parts)
    }

    public func list(_ params: ListMediaParams = .init()) async throws -> MediaList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path(),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: MediaList) async throws -> MediaList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    public func fetch(sid: String) async throws -> Media {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path(sid)
        ))
    }

    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: path(sid)
        ))
    }
}
