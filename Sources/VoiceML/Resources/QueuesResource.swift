import Foundation

public final class QueuesResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) -> String {
        "/2010-04-01/Accounts/\(transport.accountSid)/" + parts.joined(separator: "/")
    }

    public func create(_ body: CreateQueueRequest) async throws -> Queue {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Queues"),
            form: body.formFields()
        ))
    }

    public func list(_ params: ListPageParams = .init()) async throws -> QueueList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Queues"),
            query: params.queryItems()
        ))
    }

    public func get(_ queueSid: String) async throws -> Queue {
        try await transport.request(VoiceMLRequest(method: .get, path: path("Queues", queueSid)))
    }

    public func update(queueSid: String, body: UpdateQueueRequest) async throws -> Queue {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Queues", queueSid),
            form: body.formFields()
        ))
    }

    public func delete(_ queueSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: path("Queues", queueSid)))
    }

    // MARK: - Members

    public func listMembers(
        queueSid: String,
        params: ListPageParams = .init()
    ) async throws -> QueueMemberList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Queues", queueSid, "Members"),
            query: params.queryItems()
        ))
    }

    public func peekFront(queueSid: String) async throws -> QueueMember {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Queues", queueSid, "Members", "Front")
        ))
    }

    public func dequeueFront(queueSid: String, body: DequeueRequest) async throws -> QueueMember {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Queues", queueSid, "Members", "Front"),
            form: body.formFields()
        ))
    }

    public func getMember(queueSid: String, callSid: String) async throws -> QueueMember {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: path("Queues", queueSid, "Members", callSid)
        ))
    }

    public func dequeueMember(
        queueSid: String,
        callSid: String,
        body: DequeueRequest
    ) async throws -> QueueMember {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: path("Queues", queueSid, "Members", callSid),
            form: body.formFields()
        ))
    }
}
