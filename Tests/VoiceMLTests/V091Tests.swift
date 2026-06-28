import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import VoiceML

// Wire-shape tests for the v0.9.1 Phase 5 surface — Twilio Assistants v1
// (`/v1/Assistants`, `/v1/Tools`, `/v1/Knowledge`, `/v1/Sessions`,
// `/v1/Policies`). 7 families, 30 operations. Reuses MockURLProtocol +
// MockResponses from SmokeTests.swift.
//
// Assistants v1 differs from Voice v1 / Conversations v1 in three ways:
//   1. Request bodies are JSON (snake_case) not form-encoded.
//   2. Updates are PUT, not POST.
//   3. IDs are prefixed strings (aia_asst_…) not 34-char hex Sids.
//
// Tests assert: HTTP method, raw path (no `.json` suffix), JSON
// request-body shape (snake_case + nested freeform objects), and
// response-side decoding of `customer_ai`/`meta`/`content` etc.
final class V091Tests: XCTestCase {

    static let accountSid = "AC" + String(repeating: "f", count: 32)
    static let apiKey = "secret-key-1234"
    static let baseURL = "https://voiceml.voicetel.com"

    override func setUp() {
        super.setUp()
        MockResponses.shared.reset()
        TransportBackoffOverride.maxMillis = 1
    }

    private func makeClient(maxRetries: Int = 2) throws -> VoiceMLClient {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: cfg)
        return try VoiceMLClient(
            accountSid: Self.accountSid,
            apiKey: Self.apiKey,
            maxRetries: maxRetries,
            session: session
        )
    }

    private func enqueueJSON(_ obj: [String: Any], status: Int = 200) {
        let data = try! JSONSerialization.data(withJSONObject: obj)
        MockResponses.shared.enqueue(.init(
            statusCode: status,
            body: data,
            headers: ["Content-Type": "application/json"]
        ))
    }

    private func enqueueRaw(_ data: Data = Data(), status: Int) {
        MockResponses.shared.enqueue(.init(statusCode: status, body: data, headers: [:]))
    }

    private func decodeJSON(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func metaPayload(key: String) -> [String: Any] {
        [
            "first_page_url": "\(Self.baseURL)/v1/\(key)?PageSize=50",
            "next_page_url": NSNull(),
            "previous_page_url": NSNull(),
            "url": "\(Self.baseURL)/v1/\(key)?PageSize=50",
            "page": 0,
            "page_size": 50,
            "key": key,
        ]
    }

    // MARK: - Top-level surface wiring

    func testTopResourceExposesAllNamespacesAndScopeFactories() throws {
        let c = try makeClient()
        let av1 = c.assistantsV1
        _ = av1.assistants
        _ = av1.tools
        _ = av1.knowledge
        _ = av1.sessions
        _ = av1.policies

        // Scope factories — both the resource-level `.scope(...)` and the
        // top-level callable shorthand should exist and produce scopes
        // carrying the expected id.
        let aScope = av1.assistants(assistantId: "aia_asst_abc")
        XCTAssertEqual(aScope.assistantId, "aia_asst_abc")
        _ = aScope.tools
        _ = aScope.knowledge
        _ = aScope.feedbacks
        _ = aScope.messages

        let aScope2 = av1.assistants.scope(assistantId: "aia_asst_def")
        XCTAssertEqual(aScope2.assistantId, "aia_asst_def")

        let kScope = av1.knowledge(knowledgeId: "aia_know_xyz")
        XCTAssertEqual(kScope.knowledgeId, "aia_know_xyz")
        _ = kScope.status
        _ = kScope.chunks
        let kScope2 = av1.knowledge.scope(knowledgeId: "aia_know_uvw")
        XCTAssertEqual(kScope2.knowledgeId, "aia_know_uvw")

        let sScope = av1.sessions(sessionId: "sess_1")
        XCTAssertEqual(sScope.sessionId, "sess_1")
        _ = sScope.messages
        let sScope2 = av1.sessions.scope(sessionId: "sess_2")
        XCTAssertEqual(sScope2.sessionId, "sess_2")
    }

    // ===================================================================
    // Assistant (5 ops): list, create, fetch (with tools+knowledge),
    //                    update (PUT, JSON), delete
    // ===================================================================

    func testAssistantsList() async throws {
        enqueueJSON([
            "assistants": [
                [
                    "id": "aia_asst_abc",
                    "account_sid": Self.accountSid,
                    "name": "Help Desk",
                    "owner": "team",
                    "model": "gpt-4o",
                    "personality_prompt": "be helpful",
                    "customer_ai": ["perception_engine_enabled": true],
                    "url": "\(Self.baseURL)/v1/Assistants/aia_asst_abc",
                    "date_created": "2026-06-28T12:00:00Z",
                    "date_updated": "2026-06-28T12:00:00Z",
                ] as [String: Any],
            ],
            "meta": Self.metaPayload(key: "assistants"),
        ])
        let c = try makeClient()
        let page = try await c.assistantsV1.assistants.list(.init(pageSize: 50))
        XCTAssertEqual(page.assistants.count, 1)
        XCTAssertEqual(page.assistants[0].id, "aia_asst_abc")
        XCTAssertEqual(page.assistants[0].name, "Help Desk")
        XCTAssertEqual(page.meta.pageSize, 50)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "GET")
        XCTAssertEqual(
            req.url.absoluteString,
            "\(Self.baseURL)/v1/Assistants?PageSize=50"
        )
        XCTAssertFalse(req.url.absoluteString.contains(".json"))
    }

    func testAssistantsCreateSendsJSONBodyWithNestedCustomerAi() async throws {
        enqueueJSON([
            "id": "aia_asst_new",
            "account_sid": Self.accountSid,
            "name": "Triage",
            "owner": "team-1",
            "model": "gpt-4o",
            "personality_prompt": "be concise",
            "customer_ai": [
                "perception_engine_enabled": true,
                "personalization_engine_enabled": false,
            ],
            "url": "\(Self.baseURL)/v1/Assistants/aia_asst_new",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:00Z",
        ], status: 201)
        let c = try makeClient()
        let asst = try await c.assistantsV1.assistants.create(.init(
            name: "Triage",
            owner: "team-1",
            personalityPrompt: "be concise",
            model: "gpt-4o",
            customerAi: .init(
                perceptionEngineEnabled: true,
                personalizationEngineEnabled: false
            )
        ))
        XCTAssertEqual(asst.id, "aia_asst_new")
        XCTAssertEqual(asst.customerAi?["perception_engine_enabled"].flatMap { v -> Bool? in
            if case .bool(let b) = v { return b }
            return nil
        }, true)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.url.absoluteString, "\(Self.baseURL)/v1/Assistants")
        XCTAssertEqual(req.headers["Content-Type"], "application/json")
        let body = decodeJSON(req.body)
        XCTAssertEqual(body["name"] as? String, "Triage")
        XCTAssertEqual(body["owner"] as? String, "team-1")
        XCTAssertEqual(body["personality_prompt"] as? String, "be concise")
        XCTAssertEqual(body["model"] as? String, "gpt-4o")
        let ai = body["customer_ai"] as? [String: Any]
        XCTAssertEqual(ai?["perception_engine_enabled"] as? Bool, true)
        XCTAssertEqual(ai?["personalization_engine_enabled"] as? Bool, false)
    }

    func testAssistantsFetchReturnsExpandedToolsAndKnowledge() async throws {
        enqueueJSON([
            "id": "aia_asst_abc",
            "account_sid": Self.accountSid,
            "name": "Help Desk",
            "owner": "team",
            "model": "gpt-4o",
            "personality_prompt": "be helpful",
            "customer_ai": [:] as [String: Any],
            "url": "\(Self.baseURL)/v1/Assistants/aia_asst_abc",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:00Z",
            "tools": [
                [
                    "id": "aia_tool_1",
                    "name": "lookup",
                    "type": "webhook",
                    "description": "GET",
                    "enabled": true,
                    "requires_auth": false,
                    "meta": ["http_method": "GET"],
                    "date_created": "2026-06-28T12:00:00Z",
                    "date_updated": "2026-06-28T12:00:00Z",
                ] as [String: Any],
            ],
            "knowledge": [
                [
                    "id": "aia_know_1",
                    "name": "FAQ",
                    "type": "Web",
                    "date_created": "2026-06-28T12:00:00Z",
                    "date_updated": "2026-06-28T12:00:00Z",
                ] as [String: Any],
            ],
        ])
        let c = try makeClient()
        let expanded = try await c.assistantsV1.assistants.fetch(assistantId: "aia_asst_abc")
        XCTAssertEqual(expanded.id, "aia_asst_abc")
        XCTAssertEqual(expanded.tools?.count, 1)
        XCTAssertEqual(expanded.tools?[0].id, "aia_tool_1")
        XCTAssertEqual(expanded.knowledge?.count, 1)
        XCTAssertEqual(expanded.knowledge?[0].id, "aia_know_1")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "GET")
        XCTAssertEqual(
            req.url.absoluteString,
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc"
        )
    }

    func testAssistantsUpdateUsesPUTAndJSON() async throws {
        enqueueJSON([
            "id": "aia_asst_abc",
            "account_sid": Self.accountSid,
            "name": "Renamed",
            "owner": "team",
            "model": "gpt-4o",
            "personality_prompt": "tone v2",
            "customer_ai": [:] as [String: Any],
            "url": "\(Self.baseURL)/v1/Assistants/aia_asst_abc",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:01Z",
        ])
        let c = try makeClient()
        let updated = try await c.assistantsV1.assistants.update(
            assistantId: "aia_asst_abc",
            .init(name: "Renamed", personalityPrompt: "tone v2")
        )
        XCTAssertEqual(updated.name, "Renamed")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "PUT")
        XCTAssertEqual(
            req.url.absoluteString,
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc"
        )
        XCTAssertEqual(req.headers["Content-Type"], "application/json")
        let body = decodeJSON(req.body)
        XCTAssertEqual(body["name"] as? String, "Renamed")
        XCTAssertEqual(body["personality_prompt"] as? String, "tone v2")
        // Update omits fields not set — ensure absent.
        XCTAssertNil(body["owner"])
        XCTAssertNil(body["model"])
    }

    func testAssistantsDelete() async throws {
        enqueueRaw(status: 204)
        let c = try makeClient()
        try await c.assistantsV1.assistants.delete(assistantId: "aia_asst_abc")
        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "DELETE")
        XCTAssertEqual(
            req.url.absoluteString,
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc"
        )
        XCTAssertEqual(req.body.count, 0)
    }

    // ===================================================================
    // Tool (8 ops): top list/create/fetch(with policies)/update/delete +
    //               assistant-scoped list/attach/detach
    // ===================================================================

    func testToolsListAcceptsAssistantIdAndPageSize() async throws {
        enqueueJSON([
            "tools": [] as [Any],
            "meta": Self.metaPayload(key: "tools"),
        ])
        let c = try makeClient()
        _ = try await c.assistantsV1.tools.list(.init(
            assistantId: "aia_asst_abc",
            pageSize: 10
        ))
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.hasPrefix("\(Self.baseURL)/v1/Tools"))
        XCTAssertTrue(url.contains("AssistantId=aia_asst_abc"))
        XCTAssertTrue(url.contains("PageSize=10"))
    }

    func testToolsCreateSendsJSONWithMetaFreeformObject() async throws {
        enqueueJSON([
            "id": "aia_tool_new",
            "account_sid": Self.accountSid,
            "name": "lookup",
            "description": "GET endpoint",
            "type": "webhook",
            "enabled": true,
            "requires_auth": false,
            "meta": ["http_method": "GET", "url": "https://api.example.com"],
            "url": "\(Self.baseURL)/v1/Tools/aia_tool_new",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:00Z",
        ], status: 201)
        let c = try makeClient()
        let tool = try await c.assistantsV1.tools.create(.init(
            name: "lookup",
            type: "webhook",
            enabled: true,
            description: "GET endpoint",
            meta: [
                "http_method": .string("GET"),
                "url": .string("https://api.example.com"),
            ]
        ))
        XCTAssertEqual(tool.id, "aia_tool_new")
        XCTAssertEqual(tool.enabled, true)
        // meta decoded as FreeformJSONObject.
        if case .string(let m) = tool.meta?["http_method"] {
            XCTAssertEqual(m, "GET")
        } else {
            XCTFail("expected tool.meta.http_method to decode as string")
        }

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.url.absoluteString, "\(Self.baseURL)/v1/Tools")
        let body = decodeJSON(req.body)
        XCTAssertEqual(body["name"] as? String, "lookup")
        XCTAssertEqual(body["type"] as? String, "webhook")
        XCTAssertEqual(body["enabled"] as? Bool, true)
        XCTAssertEqual(body["description"] as? String, "GET endpoint")
        let meta = body["meta"] as? [String: Any]
        XCTAssertEqual(meta?["http_method"] as? String, "GET")
    }

    func testToolsFetchReturnsExpandedPolicies() async throws {
        enqueueJSON([
            "id": "aia_tool_1",
            "name": "lookup",
            "description": "x",
            "type": "webhook",
            "enabled": true,
            "requires_auth": true,
            "meta": [:] as [String: Any],
            "url": "\(Self.baseURL)/v1/Tools/aia_tool_1",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:00Z",
            "policies": [
                [
                    "id": "aia_plcy_1",
                    "type": "deny",
                    "policy_details": ["effect": "deny"],
                ] as [String: Any],
            ],
        ])
        let c = try makeClient()
        let expanded = try await c.assistantsV1.tools.fetch(toolId: "aia_tool_1")
        XCTAssertEqual(expanded.id, "aia_tool_1")
        XCTAssertEqual(expanded.policies?.count, 1)
        XCTAssertEqual(expanded.policies?[0].type, "deny")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "GET")
        XCTAssertEqual(
            req.url.absoluteString,
            "\(Self.baseURL)/v1/Tools/aia_tool_1"
        )
    }

    func testToolsUpdateUsesPUT() async throws {
        enqueueJSON([
            "id": "aia_tool_1",
            "name": "renamed",
            "description": "x",
            "type": "webhook",
            "enabled": false,
            "requires_auth": false,
            "meta": [:] as [String: Any],
            "url": "\(Self.baseURL)/v1/Tools/aia_tool_1",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:01Z",
        ])
        let c = try makeClient()
        let t = try await c.assistantsV1.tools.update(
            toolId: "aia_tool_1",
            .init(name: "renamed", enabled: false)
        )
        XCTAssertEqual(t.name, "renamed")
        XCTAssertEqual(t.enabled, false)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "PUT")
        let body = decodeJSON(req.body)
        XCTAssertEqual(body["name"] as? String, "renamed")
        XCTAssertEqual(body["enabled"] as? Bool, false)
        XCTAssertNil(body["type"])
    }

    func testToolsDelete() async throws {
        enqueueRaw(status: 204)
        let c = try makeClient()
        try await c.assistantsV1.tools.delete(toolId: "aia_tool_1")
        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "DELETE")
        XCTAssertEqual(
            req.url.absoluteString,
            "\(Self.baseURL)/v1/Tools/aia_tool_1"
        )
    }

    func testAssistantScopedToolsListAttachDetach() async throws {
        // list
        enqueueJSON([
            "tools": [] as [Any],
            "meta": Self.metaPayload(key: "tools"),
        ])
        let c = try makeClient()
        let scope = c.assistantsV1.assistants(assistantId: "aia_asst_abc")
        _ = try await scope.tools.list(.init(pageSize: 20))
        XCTAssertTrue(MockResponses.shared.captured[0].url.absoluteString.hasPrefix(
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc/Tools"
        ))
        XCTAssertTrue(MockResponses.shared.captured[0].url.absoluteString.contains(
            "PageSize=20"
        ))

        // attach
        enqueueRaw(status: 204)
        try await scope.tools.attach(toolId: "aia_tool_1")
        XCTAssertEqual(MockResponses.shared.captured[1].method, "POST")
        XCTAssertEqual(
            MockResponses.shared.captured[1].url.absoluteString,
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc/Tools/aia_tool_1"
        )

        // detach
        enqueueRaw(status: 204)
        try await scope.tools.detach(toolId: "aia_tool_1")
        XCTAssertEqual(MockResponses.shared.captured[2].method, "DELETE")
        XCTAssertEqual(
            MockResponses.shared.captured[2].url.absoluteString,
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc/Tools/aia_tool_1"
        )
    }

    // ===================================================================
    // Knowledge (10 ops): top list/create/fetch/update(PUT)/delete +
    //                     Status.fetch + Chunks.list +
    //                     assistant-scoped list/attach/detach
    // ===================================================================

    func testKnowledgeListAcceptsAssistantIdAndPageSize() async throws {
        enqueueJSON([
            "knowledge": [] as [Any],
            "meta": Self.metaPayload(key: "knowledge"),
        ])
        let c = try makeClient()
        _ = try await c.assistantsV1.knowledge.list(.init(
            assistantId: "aia_asst_abc",
            pageSize: 25
        ))
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.hasPrefix("\(Self.baseURL)/v1/Knowledge"))
        XCTAssertTrue(url.contains("AssistantId=aia_asst_abc"))
        XCTAssertTrue(url.contains("PageSize=25"))
    }

    func testKnowledgeCreateSendsJSONWithFreeformSourceDetails() async throws {
        enqueueJSON([
            "id": "aia_know_new",
            "account_sid": Self.accountSid,
            "name": "FAQ",
            "type": "Web",
            "description": "company FAQ",
            "embedding_model": "voyage-3",
            "knowledge_source_details": ["url": "https://example.com/faq"],
            "url": "\(Self.baseURL)/v1/Knowledge/aia_know_new",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:00Z",
        ], status: 201)
        let c = try makeClient()
        let k = try await c.assistantsV1.knowledge.create(.init(
            name: "FAQ",
            type: "Web",
            description: "company FAQ",
            embeddingModel: "voyage-3",
            knowledgeSourceDetails: ["url": .string("https://example.com/faq")]
        ))
        XCTAssertEqual(k.id, "aia_know_new")
        XCTAssertEqual(k.type, "Web")
        if case .string(let u) = k.knowledgeSourceDetails?["url"] {
            XCTAssertEqual(u, "https://example.com/faq")
        } else {
            XCTFail("expected knowledge_source_details.url decoded as string")
        }

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.url.absoluteString, "\(Self.baseURL)/v1/Knowledge")
        let body = decodeJSON(req.body)
        XCTAssertEqual(body["name"] as? String, "FAQ")
        XCTAssertEqual(body["type"] as? String, "Web")
        XCTAssertEqual(body["embedding_model"] as? String, "voyage-3")
        let src = body["knowledge_source_details"] as? [String: Any]
        XCTAssertEqual(src?["url"] as? String, "https://example.com/faq")
    }

    func testKnowledgeFetch() async throws {
        enqueueJSON([
            "id": "aia_know_1",
            "name": "FAQ",
            "type": "Web",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:00Z",
        ])
        let c = try makeClient()
        let k = try await c.assistantsV1.knowledge.fetch(knowledgeId: "aia_know_1")
        XCTAssertEqual(k.id, "aia_know_1")
        XCTAssertEqual(
            MockResponses.shared.captured[0].url.absoluteString,
            "\(Self.baseURL)/v1/Knowledge/aia_know_1"
        )
    }

    func testKnowledgeUpdateUsesPUT() async throws {
        enqueueJSON([
            "id": "aia_know_1",
            "name": "FAQ-v2",
            "type": "Web",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:01Z",
        ])
        let c = try makeClient()
        let k = try await c.assistantsV1.knowledge.update(
            knowledgeId: "aia_know_1",
            .init(name: "FAQ-v2")
        )
        XCTAssertEqual(k.name, "FAQ-v2")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "PUT")
        XCTAssertEqual(
            req.url.absoluteString,
            "\(Self.baseURL)/v1/Knowledge/aia_know_1"
        )
        let body = decodeJSON(req.body)
        XCTAssertEqual(body["name"] as? String, "FAQ-v2")
    }

    func testKnowledgeDelete() async throws {
        enqueueRaw(status: 204)
        let c = try makeClient()
        try await c.assistantsV1.knowledge.delete(knowledgeId: "aia_know_1")
        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "DELETE")
        XCTAssertEqual(
            req.url.absoluteString,
            "\(Self.baseURL)/v1/Knowledge/aia_know_1"
        )
    }

    func testKnowledgeStatusFetch() async throws {
        enqueueJSON([
            "account_sid": Self.accountSid,
            "status": "INDEXED",
            "last_status": "QUEUED",
            "date_updated": "2026-06-28T12:00:00Z",
        ])
        let c = try makeClient()
        let k = c.assistantsV1.knowledge(knowledgeId: "aia_know_1")
        let st = try await k.status.fetch()
        XCTAssertEqual(st.status, "INDEXED")
        XCTAssertEqual(st.lastStatus, "QUEUED")
        XCTAssertEqual(
            MockResponses.shared.captured[0].url.absoluteString,
            "\(Self.baseURL)/v1/Knowledge/aia_know_1/Status"
        )
    }

    func testKnowledgeChunksList() async throws {
        enqueueJSON([
            "chunks": [
                [
                    "content": "answer text",
                    "metadata": ["source": "p.1"],
                    "date_created": "2026-06-28T12:00:00Z",
                ] as [String: Any],
            ],
            "meta": Self.metaPayload(key: "chunks"),
        ])
        let c = try makeClient()
        let k = c.assistantsV1.knowledge(knowledgeId: "aia_know_1")
        let page = try await k.chunks.list(.init(pageSize: 5))
        XCTAssertEqual(page.chunks.count, 1)
        XCTAssertEqual(page.chunks[0].content, "answer text")
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.hasPrefix("\(Self.baseURL)/v1/Knowledge/aia_know_1/Chunks"))
        XCTAssertTrue(url.contains("PageSize=5"))
    }

    func testAssistantScopedKnowledgeListAttachDetach() async throws {
        enqueueJSON([
            "knowledge": [] as [Any],
            "meta": Self.metaPayload(key: "knowledge"),
        ])
        let c = try makeClient()
        let scope = c.assistantsV1.assistants(assistantId: "aia_asst_abc")
        _ = try await scope.knowledge.list(.init(pageSize: 20))
        XCTAssertTrue(MockResponses.shared.captured[0].url.absoluteString.hasPrefix(
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc/Knowledge"
        ))

        enqueueRaw(status: 204)
        try await scope.knowledge.attach(knowledgeId: "aia_know_1")
        XCTAssertEqual(MockResponses.shared.captured[1].method, "POST")
        XCTAssertEqual(
            MockResponses.shared.captured[1].url.absoluteString,
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc/Knowledge/aia_know_1"
        )

        enqueueRaw(status: 204)
        try await scope.knowledge.detach(knowledgeId: "aia_know_1")
        XCTAssertEqual(MockResponses.shared.captured[2].method, "DELETE")
        XCTAssertEqual(
            MockResponses.shared.captured[2].url.absoluteString,
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc/Knowledge/aia_know_1"
        )
    }

    // ===================================================================
    // Session (3 ops): list, fetch, per-session messages.list
    // ===================================================================

    func testSessionsList() async throws {
        enqueueJSON([
            "sessions": [
                [
                    "id": "sess_1",
                    "assistant_id": "aia_asst_abc",
                    "identity": "user-1",
                    "verified": true,
                    "date_created": "2026-06-28T12:00:00Z",
                    "date_updated": "2026-06-28T12:00:00Z",
                ] as [String: Any],
            ],
            "meta": Self.metaPayload(key: "sessions"),
        ])
        let c = try makeClient()
        let page = try await c.assistantsV1.sessions.list(.init(pageSize: 30))
        XCTAssertEqual(page.sessions.count, 1)
        XCTAssertEqual(page.sessions[0].id, "sess_1")
        XCTAssertEqual(page.sessions[0].verified, true)

        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.hasPrefix("\(Self.baseURL)/v1/Sessions"))
        XCTAssertTrue(url.contains("PageSize=30"))
    }

    func testSessionsFetch() async throws {
        enqueueJSON([
            "id": "sess_1",
            "assistant_id": "aia_asst_abc",
            "identity": "user-1",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:00Z",
        ])
        let c = try makeClient()
        let s = try await c.assistantsV1.sessions.fetch(sessionId: "sess_1")
        XCTAssertEqual(s.id, "sess_1")
        XCTAssertEqual(
            MockResponses.shared.captured[0].url.absoluteString,
            "\(Self.baseURL)/v1/Sessions/sess_1"
        )
    }

    func testSessionScopedMessagesList() async throws {
        enqueueJSON([
            "messages": [
                [
                    "id": "aia_msg_1",
                    "assistant_id": "aia_asst_abc",
                    "session_id": "sess_1",
                    "identity": "user-1",
                    "role": "user",
                    "content": ["body": "hello"],
                    "meta": [:] as [String: Any],
                    "date_created": "2026-06-28T12:00:00Z",
                    "date_updated": "2026-06-28T12:00:00Z",
                ] as [String: Any],
            ],
            "meta": Self.metaPayload(key: "messages"),
        ])
        let c = try makeClient()
        let scope = c.assistantsV1.sessions(sessionId: "sess_1")
        let page = try await scope.messages.list(.init(pageSize: 50))
        XCTAssertEqual(page.messages.count, 1)
        XCTAssertEqual(page.messages[0].id, "aia_msg_1")
        XCTAssertEqual(page.messages[0].role, "user")
        // content decoded as FreeformJSONObject
        if case .string(let b) = page.messages[0].content?["body"] {
            XCTAssertEqual(b, "hello")
        } else {
            XCTFail("expected message.content.body decoded as string")
        }
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.hasPrefix("\(Self.baseURL)/v1/Sessions/sess_1/Messages"))
        XCTAssertTrue(url.contains("PageSize=50"))
    }

    // ===================================================================
    // Message (1 op): POST /v1/Assistants/{id}/Messages (send message)
    // ===================================================================

    func testAssistantSendMessageReturnsSendResponse() async throws {
        enqueueJSON([
            "status": "ok",
            "flagged": false,
            "aborted": false,
            "session_id": "sess_1",
            "account_sid": Self.accountSid,
            "body": "hi back",
        ])
        let c = try makeClient()
        let scope = c.assistantsV1.assistants(assistantId: "aia_asst_abc")
        let res = try await scope.messages.create(.init(
            identity: "user-1",
            body: "hello",
            sessionId: "sess_1",
            webhook: "https://example.com/cb",
            mode: "sync"
        ))
        XCTAssertEqual(res.status, "ok")
        XCTAssertEqual(res.sessionId, "sess_1")
        XCTAssertEqual(res.body, "hi back")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(
            req.url.absoluteString,
            "\(Self.baseURL)/v1/Assistants/aia_asst_abc/Messages"
        )
        let body = decodeJSON(req.body)
        XCTAssertEqual(body["identity"] as? String, "user-1")
        XCTAssertEqual(body["body"] as? String, "hello")
        XCTAssertEqual(body["session_id"] as? String, "sess_1")
        XCTAssertEqual(body["webhook"] as? String, "https://example.com/cb")
        XCTAssertEqual(body["mode"] as? String, "sync")
    }

    // ===================================================================
    // Feedback (2 ops): assistant-scoped list + create
    // ===================================================================

    func testAssistantFeedbacksList() async throws {
        enqueueJSON([
            "feedbacks": [
                [
                    "id": "aia_fdbk_1",
                    "assistant_id": "aia_asst_abc",
                    "session_id": "sess_1",
                    "message_id": "aia_msg_1",
                    "score": 1.0,
                    "text": "great",
                    "date_created": "2026-06-28T12:00:00Z",
                    "date_updated": "2026-06-28T12:00:00Z",
                ] as [String: Any],
            ],
            "meta": Self.metaPayload(key: "feedbacks"),
        ])
        let c = try makeClient()
        let scope = c.assistantsV1.assistants(assistantId: "aia_asst_abc")
        let page = try await scope.feedbacks.list(.init(pageSize: 5))
        XCTAssertEqual(page.feedbacks.count, 1)
        XCTAssertEqual(page.feedbacks[0].score, 1.0)
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.hasPrefix("\(Self.baseURL)/v1/Assistants/aia_asst_abc/Feedbacks"))
    }

    func testAssistantFeedbacksCreateSendsJSON() async throws {
        enqueueJSON([
            "id": "aia_fdbk_new",
            "assistant_id": "aia_asst_abc",
            "session_id": "sess_1",
            "message_id": "aia_msg_1",
            "score": 0.5,
            "text": "okay",
            "date_created": "2026-06-28T12:00:00Z",
            "date_updated": "2026-06-28T12:00:00Z",
        ], status: 201)
        let c = try makeClient()
        let scope = c.assistantsV1.assistants(assistantId: "aia_asst_abc")
        let fb = try await scope.feedbacks.create(.init(
            sessionId: "sess_1",
            messageId: "aia_msg_1",
            score: 0.5,
            text: "okay"
        ))
        XCTAssertEqual(fb.id, "aia_fdbk_new")
        XCTAssertEqual(fb.score, 0.5)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.headers["Content-Type"], "application/json")
        let body = decodeJSON(req.body)
        XCTAssertEqual(body["session_id"] as? String, "sess_1")
        XCTAssertEqual(body["message_id"] as? String, "aia_msg_1")
        XCTAssertEqual((body["score"] as? Double) ?? -1, 0.5, accuracy: 0.0001)
        XCTAssertEqual(body["text"] as? String, "okay")
    }

    // ===================================================================
    // Policy (1 op): list /v1/Policies, optional ToolId/KnowledgeId
    // ===================================================================

    func testPoliciesListAcceptsToolIdAndKnowledgeId() async throws {
        enqueueJSON([
            "policies": [
                [
                    "id": "aia_plcy_1",
                    "type": "allow",
                    "policy_details": ["effect": "allow"],
                ] as [String: Any],
            ],
            "meta": Self.metaPayload(key: "policies"),
        ])
        let c = try makeClient()
        let page = try await c.assistantsV1.policies.list(.init(
            toolId: "aia_tool_1",
            knowledgeId: "aia_know_1",
            pageSize: 5
        ))
        XCTAssertEqual(page.policies.count, 1)
        XCTAssertEqual(page.policies[0].type, "allow")

        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.hasPrefix("\(Self.baseURL)/v1/Policies"))
        XCTAssertTrue(url.contains("ToolId=aia_tool_1"))
        XCTAssertTrue(url.contains("KnowledgeId=aia_know_1"))
        XCTAssertTrue(url.contains("PageSize=5"))
    }
}
