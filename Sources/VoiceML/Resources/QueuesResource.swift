import Foundation

public final class QueuesResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(parts)
    }

    public func create(_ body: CreateQueueRequest) async throws -> Queue {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try path("Queues"),
            form: body.formFields()
        ))
    }

    public func list(_ params: ListPageParams = .init()) async throws -> QueueList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path("Queues"),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: QueueList) async throws -> QueueList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    /// Walk every page of `/Queues` and yield each ``Queue``. Lazily follows each
    /// page's `next_page_uri`.
    public func iterate(_ params: ListPageParams = .init()) -> PagerSequence<Queue> {
        PagerSequence(
            firstPage: { [self] in
                let page = try await list(params)
                return PageResult(items: page.queues, nextURL: transport.resolvePageURI(page.nextPageUri))
            },
            followPage: { [self] url in
                let page: QueueList = try await transport.requestPage(url)
                return PageResult(items: page.queues, nextURL: transport.resolvePageURI(page.nextPageUri))
            }
        )
    }

    public func get(_ queueSid: String) async throws -> Queue {
        try await transport.request(VoiceMLRequest(method: .get, path: try path("Queues", queueSid)))
    }

    public func update(queueSid: String, body: UpdateQueueRequest) async throws -> Queue {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try path("Queues", queueSid),
            form: body.formFields()
        ))
    }

    public func delete(_ queueSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: try path("Queues", queueSid)))
    }

    // MARK: - Members

    public func listMembers(
        queueSid: String,
        params: ListPageParams = .init()
    ) async throws -> QueueMemberList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path("Queues", queueSid, "Members"),
            query: params.queryItems()
        ))
    }

    public func peekFront(queueSid: String) async throws -> QueueMember {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path("Queues", queueSid, "Members", "Front")
        ))
    }

    public func dequeueFront(queueSid: String, body: DequeueRequest) async throws -> QueueMember {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try path("Queues", queueSid, "Members", "Front"),
            form: body.formFields()
        ))
    }

    public func getMember(queueSid: String, callSid: String) async throws -> QueueMember {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path("Queues", queueSid, "Members", callSid)
        ))
    }

    public func dequeueMember(
        queueSid: String,
        callSid: String,
        body: DequeueRequest
    ) async throws -> QueueMember {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try path("Queues", queueSid, "Members", callSid),
            form: body.formFields()
        ))
    }
}
