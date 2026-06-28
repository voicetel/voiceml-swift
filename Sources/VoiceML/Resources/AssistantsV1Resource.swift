import Foundation

/// `client.assistantsV1` — Twilio Assistants v1
/// (assistants.twilio.com/v1) namespace. 7 families, 30 operations.
///
/// Unlike Voice v1 / Conversations v1 (form-encoded), the Assistants v1
/// surface uses **JSON request bodies** (snake_case) and **PUT** for
/// updates. Account is resolved from HTTP Basic auth — no
/// `/2010-04-01/Accounts/{Sid}/` prefix.
///
/// Scope factories on the top resource:
/// - ``assistants(assistantId:)`` → per-assistant tools, knowledge,
///   feedbacks, messages.
/// - ``knowledge(knowledgeId:)`` → per-knowledge status, chunks.
/// - ``sessions(sessionId:)`` → per-session messages.
public final class AssistantsV1Resource: Sendable {
    public let assistants: AssistantsV1AssistantsResource
    public let tools: AssistantsV1ToolsResource
    public let knowledge: AssistantsV1KnowledgeResource
    public let sessions: AssistantsV1SessionsResource
    public let policies: AssistantsV1PoliciesResource

    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
        self.assistants = AssistantsV1AssistantsResource(transport: transport)
        self.tools = AssistantsV1ToolsResource(transport: transport)
        self.knowledge = AssistantsV1KnowledgeResource(transport: transport)
        self.sessions = AssistantsV1SessionsResource(transport: transport)
        self.policies = AssistantsV1PoliciesResource(transport: transport)
    }

    /// Per-assistant scope factory — convenience that mirrors the
    /// TS/Python `client.assistantsV1.assistants(id)` callable shape.
    /// Equivalent to `client.assistantsV1.assistants.scope(assistantId:)`.
    public func assistants(assistantId: String) -> AssistantsV1AssistantScope {
        assistants.scope(assistantId: assistantId)
    }

    /// Per-knowledge scope factory — equivalent to
    /// `client.assistantsV1.knowledge.scope(knowledgeId:)`.
    public func knowledge(knowledgeId: String) -> AssistantsV1KnowledgeScope {
        knowledge.scope(knowledgeId: knowledgeId)
    }

    /// Per-session scope factory — equivalent to
    /// `client.assistantsV1.sessions.scope(sessionId:)`.
    public func sessions(sessionId: String) -> AssistantsV1SessionScope {
        sessions.scope(sessionId: sessionId)
    }
}

// MARK: - Assistants (top-level CRUD + per-assistant scope)

public final class AssistantsV1AssistantsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func list(_ params: ListAssistantsV1PageParams = .init()) async throws -> AssistantsV1AssistantList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Assistants",
            query: params.queryItems()
        ))
    }

    public func create(_ body: CreateAssistantRequest) async throws -> AssistantsV1Assistant {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: "/v1/Assistants",
            jsonBody: try body.jsonBody()
        ))
    }

    /// `GET /v1/Assistants/{id}` — returns the expanded variant carrying
    /// nested tools and knowledge.
    public func fetch(assistantId: String) async throws -> AssistantsV1AssistantWithToolsAndKnowledge {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Assistants/\(assistantId)"
        ))
    }

    public func update(assistantId: String, _ body: UpdateAssistantRequest) async throws -> AssistantsV1Assistant {
        try await transport.request(VoiceMLRequest(
            method: .put,
            path: "/v1/Assistants/\(assistantId)",
            jsonBody: try body.jsonBody()
        ))
    }

    public func delete(assistantId: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: "/v1/Assistants/\(assistantId)"
        ))
    }

    /// `client.assistantsV1.assistants.scope(assistantId:)` — accessor
    /// for the per-assistant nested sub-resources (tools, knowledge,
    /// feedbacks, messages).
    public func scope(assistantId: String) -> AssistantsV1AssistantScope {
        AssistantsV1AssistantScope(transport: transport, assistantId: assistantId)
    }
}

/// Per-assistant facade returned by `assistants(assistantId:)` /
/// `assistants.scope(assistantId:)`. Carries the four nested
/// sub-resources under `/v1/Assistants/{id}/...`.
public final class AssistantsV1AssistantScope: Sendable {
    public let assistantId: String
    public let tools: AssistantsV1AssistantToolsResource
    public let knowledge: AssistantsV1AssistantKnowledgeResource
    public let feedbacks: AssistantsV1AssistantFeedbacksResource
    public let messages: AssistantsV1AssistantMessagesResource

    init(transport: Transport, assistantId: String) {
        self.assistantId = assistantId
        self.tools = AssistantsV1AssistantToolsResource(transport: transport, assistantId: assistantId)
        self.knowledge = AssistantsV1AssistantKnowledgeResource(transport: transport, assistantId: assistantId)
        self.feedbacks = AssistantsV1AssistantFeedbacksResource(transport: transport, assistantId: assistantId)
        self.messages = AssistantsV1AssistantMessagesResource(transport: transport, assistantId: assistantId)
    }
}

// MARK: - Tools (top-level)

public final class AssistantsV1ToolsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func list(_ params: ListAssistantsV1ToolParams = .init()) async throws -> AssistantsV1ToolList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Tools",
            query: params.queryItems()
        ))
    }

    public func create(_ body: CreateToolRequest) async throws -> AssistantsV1Tool {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: "/v1/Tools",
            jsonBody: try body.jsonBody()
        ))
    }

    /// `GET /v1/Tools/{id}` — returns the expanded variant carrying
    /// materialised policies.
    public func fetch(toolId: String) async throws -> AssistantsV1ToolWithPolicies {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Tools/\(toolId)"
        ))
    }

    public func update(toolId: String, _ body: UpdateToolRequest) async throws -> AssistantsV1Tool {
        try await transport.request(VoiceMLRequest(
            method: .put,
            path: "/v1/Tools/\(toolId)",
            jsonBody: try body.jsonBody()
        ))
    }

    public func delete(toolId: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: "/v1/Tools/\(toolId)"
        ))
    }
}

// MARK: - Tools (assistant-scoped: list + attach + detach)

public final class AssistantsV1AssistantToolsResource: Sendable {
    private let transport: Transport
    private let assistantId: String
    init(transport: Transport, assistantId: String) {
        self.transport = transport
        self.assistantId = assistantId
    }

    public func list(_ params: ListAssistantsV1PageParams = .init()) async throws -> AssistantsV1ToolList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Assistants/\(assistantId)/Tools",
            query: params.queryItems()
        ))
    }

    public func attach(toolId: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .post,
            path: "/v1/Assistants/\(assistantId)/Tools/\(toolId)"
        ))
    }

    public func detach(toolId: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: "/v1/Assistants/\(assistantId)/Tools/\(toolId)"
        ))
    }
}

// MARK: - Knowledge (top-level + per-knowledge scope)

public final class AssistantsV1KnowledgeResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func list(_ params: ListAssistantsV1KnowledgeParams = .init()) async throws -> AssistantsV1KnowledgeList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Knowledge",
            query: params.queryItems()
        ))
    }

    public func create(_ body: CreateKnowledgeRequest) async throws -> AssistantsV1Knowledge {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: "/v1/Knowledge",
            jsonBody: try body.jsonBody()
        ))
    }

    public func fetch(knowledgeId: String) async throws -> AssistantsV1Knowledge {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Knowledge/\(knowledgeId)"
        ))
    }

    public func update(knowledgeId: String, _ body: UpdateKnowledgeRequest) async throws -> AssistantsV1Knowledge {
        try await transport.request(VoiceMLRequest(
            method: .put,
            path: "/v1/Knowledge/\(knowledgeId)",
            jsonBody: try body.jsonBody()
        ))
    }

    public func delete(knowledgeId: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: "/v1/Knowledge/\(knowledgeId)"
        ))
    }

    /// `client.assistantsV1.knowledge.scope(knowledgeId:)` — accessor
    /// for the per-knowledge sub-resources (status, chunks).
    public func scope(knowledgeId: String) -> AssistantsV1KnowledgeScope {
        AssistantsV1KnowledgeScope(transport: transport, knowledgeId: knowledgeId)
    }
}

/// Per-knowledge facade returned by `knowledge(knowledgeId:)` /
/// `knowledge.scope(knowledgeId:)`.
public final class AssistantsV1KnowledgeScope: Sendable {
    public let knowledgeId: String
    public let status: AssistantsV1KnowledgeStatusResource
    public let chunks: AssistantsV1KnowledgeChunksResource

    init(transport: Transport, knowledgeId: String) {
        self.knowledgeId = knowledgeId
        self.status = AssistantsV1KnowledgeStatusResource(transport: transport, knowledgeId: knowledgeId)
        self.chunks = AssistantsV1KnowledgeChunksResource(transport: transport, knowledgeId: knowledgeId)
    }
}

public final class AssistantsV1KnowledgeStatusResource: Sendable {
    private let transport: Transport
    private let knowledgeId: String
    init(transport: Transport, knowledgeId: String) {
        self.transport = transport
        self.knowledgeId = knowledgeId
    }

    public func fetch() async throws -> AssistantsV1KnowledgeStatus {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Knowledge/\(knowledgeId)/Status"
        ))
    }
}

public final class AssistantsV1KnowledgeChunksResource: Sendable {
    private let transport: Transport
    private let knowledgeId: String
    init(transport: Transport, knowledgeId: String) {
        self.transport = transport
        self.knowledgeId = knowledgeId
    }

    public func list(_ params: ListAssistantsV1PageParams = .init()) async throws -> AssistantsV1KnowledgeChunkList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Knowledge/\(knowledgeId)/Chunks",
            query: params.queryItems()
        ))
    }
}

// MARK: - Knowledge (assistant-scoped: list + attach + detach)

public final class AssistantsV1AssistantKnowledgeResource: Sendable {
    private let transport: Transport
    private let assistantId: String
    init(transport: Transport, assistantId: String) {
        self.transport = transport
        self.assistantId = assistantId
    }

    public func list(_ params: ListAssistantsV1PageParams = .init()) async throws -> AssistantsV1KnowledgeList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Assistants/\(assistantId)/Knowledge",
            query: params.queryItems()
        ))
    }

    public func attach(knowledgeId: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .post,
            path: "/v1/Assistants/\(assistantId)/Knowledge/\(knowledgeId)"
        ))
    }

    public func detach(knowledgeId: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: "/v1/Assistants/\(assistantId)/Knowledge/\(knowledgeId)"
        ))
    }
}

// MARK: - Sessions (top-level + per-session scope)

public final class AssistantsV1SessionsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func list(_ params: ListAssistantsV1PageParams = .init()) async throws -> AssistantsV1SessionList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Sessions",
            query: params.queryItems()
        ))
    }

    public func fetch(sessionId: String) async throws -> AssistantsV1Session {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Sessions/\(sessionId)"
        ))
    }

    /// `client.assistantsV1.sessions.scope(sessionId:)` — accessor for
    /// the per-session Messages sub-resource (list-only).
    public func scope(sessionId: String) -> AssistantsV1SessionScope {
        AssistantsV1SessionScope(transport: transport, sessionId: sessionId)
    }
}

/// Per-session facade returned by `sessions(sessionId:)` /
/// `sessions.scope(sessionId:)`.
public final class AssistantsV1SessionScope: Sendable {
    public let sessionId: String
    public let messages: AssistantsV1SessionMessagesResource

    init(transport: Transport, sessionId: String) {
        self.sessionId = sessionId
        self.messages = AssistantsV1SessionMessagesResource(transport: transport, sessionId: sessionId)
    }
}

public final class AssistantsV1SessionMessagesResource: Sendable {
    private let transport: Transport
    private let sessionId: String
    init(transport: Transport, sessionId: String) {
        self.transport = transport
        self.sessionId = sessionId
    }

    public func list(_ params: ListAssistantsV1PageParams = .init()) async throws -> AssistantsV1MessageList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Sessions/\(sessionId)/Messages",
            query: params.queryItems()
        ))
    }
}

// MARK: - Assistant Messages (send-message, JSON body)

public final class AssistantsV1AssistantMessagesResource: Sendable {
    private let transport: Transport
    private let assistantId: String
    init(transport: Transport, assistantId: String) {
        self.transport = transport
        self.assistantId = assistantId
    }

    /// `POST /v1/Assistants/{id}/Messages` — synchronous send-message
    /// call. Returns the send result, not a Message resource.
    public func create(_ body: CreateAssistantSendMessageRequest) async throws -> AssistantsV1SendMessageResponse {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: "/v1/Assistants/\(assistantId)/Messages",
            jsonBody: try body.jsonBody()
        ))
    }
}

// MARK: - Feedbacks (assistant-scoped: list + create)

public final class AssistantsV1AssistantFeedbacksResource: Sendable {
    private let transport: Transport
    private let assistantId: String
    init(transport: Transport, assistantId: String) {
        self.transport = transport
        self.assistantId = assistantId
    }

    public func list(_ params: ListAssistantsV1PageParams = .init()) async throws -> AssistantsV1FeedbackList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Assistants/\(assistantId)/Feedbacks",
            query: params.queryItems()
        ))
    }

    public func create(_ body: CreateFeedbackRequest) async throws -> AssistantsV1Feedback {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: "/v1/Assistants/\(assistantId)/Feedbacks",
            jsonBody: try body.jsonBody()
        ))
    }
}

// MARK: - Policies (top-level, list-only)

public final class AssistantsV1PoliciesResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func list(_ params: ListAssistantsV1PolicyParams = .init()) async throws -> AssistantsV1PolicyList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Policies",
            query: params.queryItems()
        ))
    }
}
