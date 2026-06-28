import Foundation

// Twilio Assistants v1 (assistants.twilio.com/v1) — Phase 5, 7 families,
// 30 operations:
//   Assistant      (/v1/Assistants[/{id}])                  — 5 ops
//   Tool           (/v1/Tools[/{id}], /v1/Assistants/{id}/Tools[/{toolId}])
//                                                            — 8 ops
//   Knowledge      (/v1/Knowledge[/{id}[/Status|/Chunks]],
//                   /v1/Assistants/{id}/Knowledge[/{kid}])   — 10 ops
//   Session        (/v1/Sessions[/{id}[/Messages]])          — 3 ops
//   Message        (POST /v1/Assistants/{id}/Messages)       — 1 op
//   Feedback       (/v1/Assistants/{id}/Feedbacks)           — 2 ops
//   Policy         (GET /v1/Policies)                        — 1 op
//
// Unlike Voice v1 / Conversations v1 (form-encoded POST), Assistants v1
// uses **JSON request bodies** (snake_case wire keys) and **PUT** for
// updates. Account is resolved from HTTP Basic auth — no
// /2010-04-01/Accounts/{Sid}/ prefix.
//
// Identifiers are prefixed strings (`aia_asst_…`, `aia_tool_…`,
// `aia_know_…`, `aia_msg_…`, `aia_fdbk_…`, `aia_plcy_…`), not the legacy
// 34-char hex Sids used elsewhere. List responses carry the shared
// ``V1Meta`` envelope.
//
// Response structs are `Decodable` (not `Codable`) — they are only
// deserialized off the wire. Freeform JSON sub-objects (`customer_ai`,
// `meta`, `content`, `knowledge_source_details`, `metadata`,
// `policy_details`) decode to ``FreeformJSONObject`` so callers can
// introspect arbitrary shape without bringing in a third-party JSON
// dependency.
//
// String fields with closed enum domains (status, type, role, mode) are
// surfaced as `String` rather than Swift enums — same parity-lint
// stance as the rest of the v1 surface: an unknown enum value from a
// forward-rev'd server must not throw a decoding error.

// MARK: - AnyJSON Encodable extension (Assistants v1 needs JSON request
//         bodies, so we extend the Decodable-only enum from
//         ConversationsV1.swift to also encode. Round-trippable.)

extension AnyJSON: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:           try container.encodeNil()
        case .bool(let v):    try container.encode(v)
        case .int(let v):     try container.encode(v)
        case .double(let v):  try container.encode(v)
        case .string(let v):  try container.encode(v)
        case .array(let v):   try container.encode(v)
        case .object(let v):  try container.encode(v)
        }
    }
}

// MARK: - Assistant

/// A Twilio-compatible AI Assistant. ID is `aia_asst_…`.
public struct AssistantsV1Assistant: Decodable, Sendable {
    public var accountSid: String?
    public var customerAi: FreeformJSONObject?
    public var id: String?
    public var model: String?
    public var name: String?
    public var owner: String?
    public var url: String?
    public var personalityPrompt: String?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct AssistantsV1AssistantList: Decodable, Sendable {
    public var assistants: [AssistantsV1Assistant]
    public var meta: V1Meta
}

/// Expanded variant returned by `GET /v1/Assistants/{id}` — carries
/// nested tools and knowledge.
public struct AssistantsV1AssistantWithToolsAndKnowledge: Decodable, Sendable {
    public var accountSid: String?
    public var customerAi: FreeformJSONObject?
    public var id: String?
    public var model: String?
    public var name: String?
    public var owner: String?
    public var url: String?
    public var personalityPrompt: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var tools: [AssistantsV1Tool]?
    public var knowledge: [AssistantsV1Knowledge]?
}

// MARK: - Tool

/// A Twilio-compatible Tool definition. ID is `aia_tool_…`.
public struct AssistantsV1Tool: Decodable, Sendable {
    public var accountSid: String?
    public var description: String?
    public var enabled: Bool?
    public var id: String?
    public var meta: FreeformJSONObject?
    public var name: String?
    public var requiresAuth: Bool?
    public var type: String?
    public var url: String?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct AssistantsV1ToolList: Decodable, Sendable {
    public var tools: [AssistantsV1Tool]
    public var meta: V1Meta
}

/// Expanded variant returned by `GET /v1/Tools/{id}` — carries
/// materialised policies attached to the tool.
public struct AssistantsV1ToolWithPolicies: Decodable, Sendable {
    public var accountSid: String?
    public var description: String?
    public var enabled: Bool?
    public var id: String?
    public var meta: FreeformJSONObject?
    public var name: String?
    public var requiresAuth: Bool?
    public var type: String?
    public var url: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var policies: [AssistantsV1Policy]?
}

// MARK: - Knowledge

/// A Twilio-compatible Knowledge resource. ID is `aia_know_…`.
public struct AssistantsV1Knowledge: Decodable, Sendable {
    public var description: String?
    public var id: String?
    public var accountSid: String?
    public var knowledgeSourceDetails: FreeformJSONObject?
    public var name: String?
    public var status: String?
    public var type: String?
    public var url: String?
    public var embeddingModel: String?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct AssistantsV1KnowledgeList: Decodable, Sendable {
    public var knowledge: [AssistantsV1Knowledge]
    public var meta: V1Meta
}

/// Read-only ingestion status returned by
/// `GET /v1/Knowledge/{id}/Status`. `status` enum is open by design.
public struct AssistantsV1KnowledgeStatus: Decodable, Sendable {
    public var accountSid: String?
    public var status: String?
    public var lastStatus: String?
    public var dateUpdated: String?
}

/// A single retrieval chunk returned by
/// `GET /v1/Knowledge/{id}/Chunks`.
public struct AssistantsV1KnowledgeChunk: Decodable, Sendable {
    public var accountSid: String?
    public var content: String?
    public var metadata: FreeformJSONObject?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct AssistantsV1KnowledgeChunkList: Decodable, Sendable {
    public var chunks: [AssistantsV1KnowledgeChunk]
    public var meta: V1Meta
}

// MARK: - Session

/// A Twilio-compatible Assistants Session.
public struct AssistantsV1Session: Decodable, Sendable {
    public var id: String?
    public var accountSid: String?
    public var assistantId: String?
    public var verified: Bool?
    public var identity: String?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct AssistantsV1SessionList: Decodable, Sendable {
    public var sessions: [AssistantsV1Session]
    public var meta: V1Meta
}

// MARK: - Message

/// A Twilio-compatible Assistants Message. ID is `aia_msg_…`.
///
/// `role` is one of `system`, `user`, `assistant`, `tool` (open enum
/// surface — forward-rev'd values stay as `String`).
public struct AssistantsV1Message: Decodable, Sendable {
    public var id: String?
    public var accountSid: String?
    public var assistantId: String?
    public var sessionId: String?
    public var identity: String?
    public var role: String?
    public var content: FreeformJSONObject?
    public var meta: FreeformJSONObject?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct AssistantsV1MessageList: Decodable, Sendable {
    public var messages: [AssistantsV1Message]
    public var meta: V1Meta
}

/// Result of `POST /v1/Assistants/{id}/Messages` — synchronous
/// send-message response.
public struct AssistantsV1SendMessageResponse: Decodable, Sendable {
    public var status: String?
    public var flagged: Bool?
    public var aborted: Bool?
    public var sessionId: String?
    public var accountSid: String?
    public var body: String?
    public var error: String?
}

// MARK: - Feedback

/// A Twilio-compatible Assistants Feedback record. ID is `aia_fdbk_…`.
public struct AssistantsV1Feedback: Decodable, Sendable {
    public var assistantId: String?
    public var id: String?
    public var accountSid: String?
    public var userSid: String?
    public var messageId: String?
    public var score: Double?
    public var sessionId: String?
    public var text: String?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct AssistantsV1FeedbackList: Decodable, Sendable {
    public var feedbacks: [AssistantsV1Feedback]
    public var meta: V1Meta
}

// MARK: - Policy

/// A materialised Assistants Policy. ID is `aia_plcy_…`. Read-only.
public struct AssistantsV1Policy: Decodable, Sendable {
    public var id: String?
    public var name: String?
    public var description: String?
    public var accountSid: String?
    public var userSid: String?
    public var type: String?
    public var policyDetails: FreeformJSONObject?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct AssistantsV1PolicyList: Decodable, Sendable {
    public var policies: [AssistantsV1Policy]
    public var meta: V1Meta
}

// MARK: - List query params

/// Standard page params shared by `/v1/Assistants`, `/v1/Sessions`,
/// `/v1/Sessions/{id}/Messages`, `/v1/Assistants/{id}/Tools`,
/// `/v1/Assistants/{id}/Knowledge`, `/v1/Knowledge/{id}/Chunks`, and
/// `/v1/Assistants/{id}/Feedbacks`.
public struct ListAssistantsV1PageParams: Sendable {
    public var pageSize: Int?
    public var page: Int?
    public var pageToken: String?
    public init(pageSize: Int? = nil, page: Int? = nil, pageToken: String? = nil) {
        self.pageSize = pageSize
        self.page = page
        self.pageToken = pageToken
    }
    public func queryItems() -> [QueryItem] {
        var q: [QueryItem] = []
        if let v = pageSize { q.append(QueryItem("PageSize", String(v))) }
        if let v = page { q.append(QueryItem("Page", String(v))) }
        if let v = pageToken { q.append(QueryItem("PageToken", v)) }
        return q
    }
}

/// Filterable list params for `/v1/Tools` (optional `AssistantId`).
public struct ListAssistantsV1ToolParams: Sendable {
    public var assistantId: String?
    public var pageSize: Int?
    public init(assistantId: String? = nil, pageSize: Int? = nil) {
        self.assistantId = assistantId
        self.pageSize = pageSize
    }
    public func queryItems() -> [QueryItem] {
        var q: [QueryItem] = []
        if let v = assistantId { q.append(QueryItem("AssistantId", v)) }
        if let v = pageSize { q.append(QueryItem("PageSize", String(v))) }
        return q
    }
}

/// Filterable list params for `/v1/Knowledge` (optional `AssistantId`).
public struct ListAssistantsV1KnowledgeParams: Sendable {
    public var assistantId: String?
    public var pageSize: Int?
    public init(assistantId: String? = nil, pageSize: Int? = nil) {
        self.assistantId = assistantId
        self.pageSize = pageSize
    }
    public func queryItems() -> [QueryItem] {
        var q: [QueryItem] = []
        if let v = assistantId { q.append(QueryItem("AssistantId", v)) }
        if let v = pageSize { q.append(QueryItem("PageSize", String(v))) }
        return q
    }
}

/// Filterable list params for `/v1/Policies` (optional
/// `ToolId`/`KnowledgeId`).
public struct ListAssistantsV1PolicyParams: Sendable {
    public var toolId: String?
    public var knowledgeId: String?
    public var pageSize: Int?
    public init(toolId: String? = nil, knowledgeId: String? = nil, pageSize: Int? = nil) {
        self.toolId = toolId
        self.knowledgeId = knowledgeId
        self.pageSize = pageSize
    }
    public func queryItems() -> [QueryItem] {
        var q: [QueryItem] = []
        if let v = toolId { q.append(QueryItem("ToolId", v)) }
        if let v = knowledgeId { q.append(QueryItem("KnowledgeId", v)) }
        if let v = pageSize { q.append(QueryItem("PageSize", String(v))) }
        return q
    }
}

// MARK: - Request bodies — Assistant

/// Customer-AI feature toggles for an Assistant. Both keys are
/// optional; only set keys are emitted.
public struct AssistantsV1CustomerAi: Sendable {
    public var perceptionEngineEnabled: Bool?
    public var personalizationEngineEnabled: Bool?
    public init(perceptionEngineEnabled: Bool? = nil,
                personalizationEngineEnabled: Bool? = nil) {
        self.perceptionEngineEnabled = perceptionEngineEnabled
        self.personalizationEngineEnabled = personalizationEngineEnabled
    }
    func toJSONObject() -> FreeformJSONObject {
        var o: FreeformJSONObject = [:]
        if let v = perceptionEngineEnabled { o["perception_engine_enabled"] = .bool(v) }
        if let v = personalizationEngineEnabled { o["personalization_engine_enabled"] = .bool(v) }
        return o
    }
}

public struct CreateAssistantRequest: Sendable {
    public var name: String
    public var owner: String?
    public var personalityPrompt: String?
    /// VoiceML extension: the BYO-LLM model backing the assistant (Phase 6).
    public var model: String?
    public var customerAi: AssistantsV1CustomerAi?
    public var segmentCredential: FreeformJSONObject?
    public init(name: String,
                owner: String? = nil,
                personalityPrompt: String? = nil,
                model: String? = nil,
                customerAi: AssistantsV1CustomerAi? = nil,
                segmentCredential: FreeformJSONObject? = nil) {
        self.name = name
        self.owner = owner
        self.personalityPrompt = personalityPrompt
        self.model = model
        self.customerAi = customerAi
        self.segmentCredential = segmentCredential
    }
    public func jsonBody() throws -> Data {
        var o: FreeformJSONObject = ["name": .string(name)]
        if let v = owner { o["owner"] = .string(v) }
        if let v = personalityPrompt { o["personality_prompt"] = .string(v) }
        if let v = model { o["model"] = .string(v) }
        if let v = customerAi { o["customer_ai"] = .object(v.toJSONObject()) }
        if let v = segmentCredential { o["segment_credential"] = .object(v) }
        return try encodeAssistantsV1JSON(o)
    }
}

public struct UpdateAssistantRequest: Sendable {
    public var name: String?
    public var owner: String?
    public var personalityPrompt: String?
    /// VoiceML extension: the BYO-LLM model backing the assistant (Phase 6).
    public var model: String?
    public var customerAi: FreeformJSONObject?
    public var segmentCredential: FreeformJSONObject?
    public init(name: String? = nil,
                owner: String? = nil,
                personalityPrompt: String? = nil,
                model: String? = nil,
                customerAi: FreeformJSONObject? = nil,
                segmentCredential: FreeformJSONObject? = nil) {
        self.name = name
        self.owner = owner
        self.personalityPrompt = personalityPrompt
        self.model = model
        self.customerAi = customerAi
        self.segmentCredential = segmentCredential
    }
    public func jsonBody() throws -> Data {
        var o: FreeformJSONObject = [:]
        if let v = name { o["name"] = .string(v) }
        if let v = owner { o["owner"] = .string(v) }
        if let v = personalityPrompt { o["personality_prompt"] = .string(v) }
        if let v = model { o["model"] = .string(v) }
        if let v = customerAi { o["customer_ai"] = .object(v) }
        if let v = segmentCredential { o["segment_credential"] = .object(v) }
        return try encodeAssistantsV1JSON(o)
    }
}

// MARK: - Request bodies — Tool

public struct CreateToolRequest: Sendable {
    public var name: String
    public var type: String
    public var enabled: Bool
    public var assistantId: String?
    public var description: String?
    public var meta: FreeformJSONObject?
    public init(name: String,
                type: String,
                enabled: Bool,
                assistantId: String? = nil,
                description: String? = nil,
                meta: FreeformJSONObject? = nil) {
        self.name = name
        self.type = type
        self.enabled = enabled
        self.assistantId = assistantId
        self.description = description
        self.meta = meta
    }
    public func jsonBody() throws -> Data {
        var o: FreeformJSONObject = [
            "name": .string(name),
            "type": .string(type),
            "enabled": .bool(enabled),
        ]
        if let v = assistantId { o["assistant_id"] = .string(v) }
        if let v = description { o["description"] = .string(v) }
        if let v = meta { o["meta"] = .object(v) }
        return try encodeAssistantsV1JSON(o)
    }
}

public struct UpdateToolRequest: Sendable {
    public var name: String?
    public var type: String?
    public var enabled: Bool?
    public var description: String?
    public var meta: FreeformJSONObject?
    public init(name: String? = nil,
                type: String? = nil,
                enabled: Bool? = nil,
                description: String? = nil,
                meta: FreeformJSONObject? = nil) {
        self.name = name
        self.type = type
        self.enabled = enabled
        self.description = description
        self.meta = meta
    }
    public func jsonBody() throws -> Data {
        var o: FreeformJSONObject = [:]
        if let v = name { o["name"] = .string(v) }
        if let v = type { o["type"] = .string(v) }
        if let v = enabled { o["enabled"] = .bool(v) }
        if let v = description { o["description"] = .string(v) }
        if let v = meta { o["meta"] = .object(v) }
        return try encodeAssistantsV1JSON(o)
    }
}

// MARK: - Request bodies — Knowledge

public struct CreateKnowledgeRequest: Sendable {
    public var name: String
    public var type: String
    public var assistantId: String?
    public var description: String?
    public var embeddingModel: String?
    public var knowledgeSourceDetails: FreeformJSONObject?
    public init(name: String,
                type: String,
                assistantId: String? = nil,
                description: String? = nil,
                embeddingModel: String? = nil,
                knowledgeSourceDetails: FreeformJSONObject? = nil) {
        self.name = name
        self.type = type
        self.assistantId = assistantId
        self.description = description
        self.embeddingModel = embeddingModel
        self.knowledgeSourceDetails = knowledgeSourceDetails
    }
    public func jsonBody() throws -> Data {
        var o: FreeformJSONObject = [
            "name": .string(name),
            "type": .string(type),
        ]
        if let v = assistantId { o["assistant_id"] = .string(v) }
        if let v = description { o["description"] = .string(v) }
        if let v = embeddingModel { o["embedding_model"] = .string(v) }
        if let v = knowledgeSourceDetails { o["knowledge_source_details"] = .object(v) }
        return try encodeAssistantsV1JSON(o)
    }
}

public struct UpdateKnowledgeRequest: Sendable {
    public var name: String?
    public var type: String?
    public var description: String?
    public var embeddingModel: String?
    public var knowledgeSourceDetails: FreeformJSONObject?
    public init(name: String? = nil,
                type: String? = nil,
                description: String? = nil,
                embeddingModel: String? = nil,
                knowledgeSourceDetails: FreeformJSONObject? = nil) {
        self.name = name
        self.type = type
        self.description = description
        self.embeddingModel = embeddingModel
        self.knowledgeSourceDetails = knowledgeSourceDetails
    }
    public func jsonBody() throws -> Data {
        var o: FreeformJSONObject = [:]
        if let v = name { o["name"] = .string(v) }
        if let v = type { o["type"] = .string(v) }
        if let v = description { o["description"] = .string(v) }
        if let v = embeddingModel { o["embedding_model"] = .string(v) }
        if let v = knowledgeSourceDetails { o["knowledge_source_details"] = .object(v) }
        return try encodeAssistantsV1JSON(o)
    }
}

// MARK: - Request bodies — Send Message

public struct CreateAssistantSendMessageRequest: Sendable {
    public var identity: String
    public var body: String
    public var sessionId: String?
    public var webhook: String?
    public var mode: String?
    public init(identity: String,
                body: String,
                sessionId: String? = nil,
                webhook: String? = nil,
                mode: String? = nil) {
        self.identity = identity
        self.body = body
        self.sessionId = sessionId
        self.webhook = webhook
        self.mode = mode
    }
    public func jsonBody() throws -> Data {
        var o: FreeformJSONObject = [
            "identity": .string(identity),
            "body": .string(body),
        ]
        if let v = sessionId { o["session_id"] = .string(v) }
        if let v = webhook { o["webhook"] = .string(v) }
        if let v = mode { o["mode"] = .string(v) }
        return try encodeAssistantsV1JSON(o)
    }
}

// MARK: - Request bodies — Feedback

public struct CreateFeedbackRequest: Sendable {
    public var sessionId: String
    public var messageId: String?
    public var score: Double?
    public var text: String?
    public init(sessionId: String,
                messageId: String? = nil,
                score: Double? = nil,
                text: String? = nil) {
        self.sessionId = sessionId
        self.messageId = messageId
        self.score = score
        self.text = text
    }
    public func jsonBody() throws -> Data {
        var o: FreeformJSONObject = ["session_id": .string(sessionId)]
        if let v = messageId { o["message_id"] = .string(v) }
        if let v = score { o["score"] = .double(v) }
        if let v = text { o["text"] = .string(v) }
        return try encodeAssistantsV1JSON(o)
    }
}

// MARK: - JSON encoder (sorted keys for deterministic test wire shape)

/// Single shared JSON encoder for Assistants v1 request bodies. Sorts
/// keys so wire-shape tests can assert deterministic byte ordering
/// without parsing JSON, and so the on-wire output is stable across
/// Foundation versions.
func encodeAssistantsV1JSON(_ object: FreeformJSONObject) throws -> Data {
    let enc = JSONEncoder()
    enc.outputFormatting = [.sortedKeys]
    return try enc.encode(object)
}
