import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import VoiceML

// Wire-shape tests for the v0.9.0 Phase 4 surface — service-scoped
// Conversations v1 under `/v1/Services/{ChatServiceSid}/...`. Reuses
// MockURLProtocol + MockResponses from SmokeTests.swift.
final class V090Phase4Tests: XCTestCase {

    static let accountSid = "AC" + String(repeating: "f", count: 32)
    static let apiKey = "secret-key-1234"
    static let chatServiceSid = "IS" + String(repeating: "8", count: 32)

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

    private func parseForm(_ data: Data) -> [String: [String]] {
        guard let s = String(data: data, encoding: .utf8) else { return [:] }
        var result: [String: [String]] = [:]
        for pair in s.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let k = String(parts[0]).removingPercentEncoding ?? String(parts[0])
            let v = String(parts[1]).removingPercentEncoding ?? String(parts[1])
            result[k, default: []].append(v)
        }
        return result
    }

    private static func metaPayload(key: String) -> [String: Any] {
        [
            "first_page_url": "https://voiceml.voicetel.com/v1/Services/X?PageSize=50",
            "next_page_url": NSNull(),
            "previous_page_url": NSNull(),
            "url": "https://voiceml.voicetel.com/v1/Services/X?PageSize=50",
            "page": 0,
            "page_size": 50,
            "key": key,
        ]
    }

    // MARK: - Scope surface wiring

    func testScopeExposesAllPhase4Namespaces() throws {
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        XCTAssertEqual(svc.chatServiceSid, Self.chatServiceSid)
        _ = svc.conversations
        _ = svc.conversations.messages(conversationSid: "CH0")
        _ = svc.conversations.messages(conversationSid: "CH0").receipts(messageSid: "IM0")
        _ = svc.conversations.participants(conversationSid: "CH0")
        _ = svc.conversations.webhooks(conversationSid: "CH0")
        _ = svc.users
        _ = svc.users.conversations(userSid: "US0")
        _ = svc.roles
        _ = svc.bindings
        _ = svc.configuration
        _ = svc.configuration.notifications
        _ = svc.configuration.webhooks
        _ = svc.conversationWithParticipants
        _ = svc.participantConversations
    }

    // ===================================================================
    // Service-scoped Conversation CRUD
    // ===================================================================

    func testServiceConversationCreateSendsDottedTimerKeys() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "sid": chSid,
            "state": "active",
            "attributes": "{}",
            "friendly_name": "Support",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)",
        ], status: 201)
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)

        let conv = try await svc.conversations.create(.init(
            friendlyName: "Support",
            attributes: "{}",
            state: "active",
            timersInactive: "PT5M",
            timersClosed: "PT1H"
        ))
        XCTAssertEqual(conv.sid, chSid)
        XCTAssertEqual(conv.chatServiceSid, Self.chatServiceSid)
        XCTAssertEqual(conv.state, "active")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations"
        )
        XCTAssertFalse(req.url.absoluteString.contains(".json"))
        let form = parseForm(req.body)
        XCTAssertEqual(form["FriendlyName"]?.first, "Support")
        XCTAssertEqual(form["State"]?.first, "active")
        XCTAssertEqual(form["Timers.Inactive"]?.first, "PT5M")
        XCTAssertEqual(form["Timers.Closed"]?.first, "PT1H")
    }

    func testServiceConversationListFetchUpdateDelete() async throws {
        let chSid = "CH" + String(repeating: "1", count: 32)
        // list
        enqueueJSON([
            "conversations": [
                [
                    "account_sid": Self.accountSid,
                    "chat_service_sid": Self.chatServiceSid,
                    "sid": chSid,
                    "state": "active",
                    "attributes": "{}",
                    "date_created": "2026-06-27T12:00:00Z",
                    "date_updated": "2026-06-27T12:00:00Z",
                    "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)",
                ] as [String: Any],
            ],
            "meta": Self.metaPayload(key: "conversations"),
        ])
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        let page = try await svc.conversations.list(.init(pageSize: 50))
        XCTAssertEqual(page.conversations.count, 1)
        XCTAssertEqual(page.meta.pageSize, 50)
        XCTAssertTrue(
            MockResponses.shared.captured[0].url.absoluteString.contains(
                "/v1/Services/\(Self.chatServiceSid)/Conversations?"
            )
        )

        // fetch
        enqueueJSON([
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "sid": chSid,
            "state": "active",
            "attributes": "{}",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)",
        ])
        let fetched = try await svc.conversations.fetch(conversationSid: chSid)
        XCTAssertEqual(fetched.sid, chSid)

        // update
        enqueueJSON([
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "sid": chSid,
            "state": "closed",
            "attributes": "{}",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:01Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)",
        ])
        let updated = try await svc.conversations.update(conversationSid: chSid, .init(state: "closed"))
        XCTAssertEqual(updated.state, "closed")
        let upForm = parseForm(MockResponses.shared.captured[2].body)
        XCTAssertEqual(upForm["State"]?.first, "closed")

        // delete
        enqueueRaw(status: 204)
        try await svc.conversations.delete(conversationSid: chSid)
        XCTAssertEqual(MockResponses.shared.captured[3].method, "DELETE")
        XCTAssertEqual(
            MockResponses.shared.captured[3].url.absoluteString,
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)"
        )
    }

    // ===================================================================
    // Service-scoped Conversation Message + Receipts
    // ===================================================================

    func testServiceConversationMessagesCreateListAndReceiptsPath() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        let imSid = "IM" + String(repeating: "1", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "conversation_sid": chSid,
            "sid": imSid,
            "index": 11,
            "author": "+15551234567",
            "body": "hi",
            "attributes": "{}",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)/Messages/\(imSid)",
        ], status: 201)
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        let msg = try await svc.conversations.messages(conversationSid: chSid)
            .create(.init(author: "+15551234567", body: "hi"))
        XCTAssertEqual(msg.index, 11)
        XCTAssertEqual(msg.chatServiceSid, Self.chatServiceSid)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)/Messages"
        )

        // receipts list
        enqueueJSON([
            "delivery_receipts": [] as [Any],
            "meta": Self.metaPayload(key: "delivery_receipts"),
        ])
        _ = try await svc.conversations.messages(conversationSid: chSid)
            .receipts(messageSid: imSid).list()
        XCTAssertTrue(
            MockResponses.shared.captured[1].url.absoluteString.hasPrefix(
                "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)/Messages/\(imSid)/Receipts"
            )
        )

        // receipts fetch
        let dySid = "DY" + String(repeating: "2", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "conversation_sid": chSid,
            "sid": dySid,
            "message_sid": imSid,
            "status": "delivered",
            "error_code": 0,
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)/Messages/\(imSid)/Receipts/\(dySid)",
        ])
        let dy = try await svc.conversations.messages(conversationSid: chSid)
            .receipts(messageSid: imSid).fetch(sid: dySid)
        XCTAssertEqual(dy.sid, dySid)
        XCTAssertEqual(dy.status, "delivered")
        XCTAssertEqual(dy.errorCode, 0)
    }

    // ===================================================================
    // Service-scoped Conversation Participant — dotted MessagingBinding keys
    // ===================================================================

    func testServiceConversationParticipantCreateSendsDottedMessagingBinding() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        let mbSid = "MB" + String(repeating: "3", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "conversation_sid": chSid,
            "sid": mbSid,
            "attributes": "{}",
            "messaging_binding": ["address": "+15551234567"],
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)/Participants/\(mbSid)",
        ], status: 201)
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        _ = try await svc.conversations.participants(conversationSid: chSid)
            .create(.init(
                messagingBindingAddress: "+15551234567",
                messagingBindingProxyAddress: "+15550000000",
                messagingBindingProjectedAddress: "+15559999999"
            ))

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["MessagingBinding.Address"]?.first, "+15551234567")
        XCTAssertEqual(form["MessagingBinding.ProxyAddress"]?.first, "+15550000000")
        XCTAssertEqual(form["MessagingBinding.ProjectedAddress"]?.first, "+15559999999")
    }

    // ===================================================================
    // Service-scoped Scoped Webhook — Configuration dotted form
    // ===================================================================

    func testServiceConversationScopedWebhookCreateSendsDottedConfiguration() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        let whSid = "WH" + String(repeating: "4", count: 32)
        enqueueJSON([
            "sid": whSid,
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "conversation_sid": chSid,
            "target": "studio",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)/Webhooks/\(whSid)",
            "configuration": ["flow_sid": "FW0"],
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
        ], status: 201)
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        let wh = try await svc.conversations.webhooks(conversationSid: chSid).create(.init(
            target: "studio",
            configurationFlowSid: "FW0"
        ))
        XCTAssertEqual(wh.sid, whSid)
        XCTAssertEqual(wh.target, "studio")

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["Target"]?.first, "studio")
        XCTAssertEqual(form["Configuration.FlowSid"]?.first, "FW0")
    }

    // ===================================================================
    // Service-scoped Roles — repeated Permission, plus update
    // ===================================================================

    func testServiceRolesCreateSendsRepeatedPermission() async throws {
        let rlSid = "RL" + String(repeating: "5", count: 32)
        enqueueJSON([
            "sid": rlSid,
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "type": "conversation",
            "permissions": ["sendMessage", "leaveConversation"],
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Roles/\(rlSid)",
        ], status: 201)
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        let role = try await svc.roles.create(.init(
            friendlyName: "channel-member",
            type: "conversation",
            permission: ["sendMessage", "leaveConversation"]
        ))
        XCTAssertEqual(role.sid, rlSid)
        XCTAssertEqual(role.permissions?.count, 2)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Roles"
        )
        let form = parseForm(req.body)
        XCTAssertEqual(form["FriendlyName"]?.first, "channel-member")
        XCTAssertEqual(form["Type"]?.first, "conversation")
        XCTAssertEqual(form["Permission"]?.count, 2)
        XCTAssertTrue(form["Permission"]?.contains("sendMessage") == true)

        // update — same repeated-key shape
        enqueueJSON([
            "sid": rlSid,
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "type": "conversation",
            "permissions": ["sendMessage"],
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:01Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Roles/\(rlSid)",
        ])
        _ = try await svc.roles.update(sid: rlSid, .init(permission: ["sendMessage"]))
        let upForm = parseForm(MockResponses.shared.captured[1].body)
        XCTAssertEqual(upForm["Permission"]?.first, "sendMessage")
    }

    // ===================================================================
    // Service-scoped Users + user conversations
    // ===================================================================

    func testServiceUsersCRUDAndUserConversations() async throws {
        let usSid = "US" + String(repeating: "6", count: 32)
        // create
        enqueueJSON([
            "sid": usSid,
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "identity": "alice",
            "friendly_name": "Alice",
            "attributes": "{}",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Users/\(usSid)",
        ], status: 201)
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        let user = try await svc.users.create(.init(identity: "alice", friendlyName: "Alice"))
        XCTAssertEqual(user.sid, usSid)
        XCTAssertEqual(user.identity, "alice")

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["Identity"]?.first, "alice")
        XCTAssertEqual(form["FriendlyName"]?.first, "Alice")

        // per-user conversations list
        enqueueJSON([
            "conversations": [] as [Any],
            "meta": Self.metaPayload(key: "conversations"),
        ])
        _ = try await svc.users.conversations(userSid: usSid).list()
        XCTAssertTrue(
            MockResponses.shared.captured[1].url.absoluteString.hasPrefix(
                "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Users/\(usSid)/Conversations"
            )
        )
    }

    // ===================================================================
    // Service-scoped ConversationWithParticipants — repeated Participant
    // ===================================================================

    func testServiceConversationWithParticipantsRepeatsParticipantKey() async throws {
        let chSid = "CH" + String(repeating: "7", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "sid": chSid,
            "state": "active",
            "attributes": "{}",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Conversations/\(chSid)",
        ], status: 201)
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        _ = try await svc.conversationWithParticipants.create(.init(
            friendlyName: "Triage",
            participant: [
                #"{"identity":"alice"}"#,
                #"{"messaging_binding":{"address":"+15551234567"}}"#,
            ]
        ))

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/ConversationWithParticipants"
        )
        let form = parseForm(req.body)
        XCTAssertEqual(form["FriendlyName"]?.first, "Triage")
        XCTAssertEqual(form["Participant"]?.count, 2)
    }

    // ===================================================================
    // Service-scoped ParticipantConversations — query params Identity/Address
    // ===================================================================

    func testServiceParticipantConversationsListAcceptsIdentityAndAddress() async throws {
        enqueueJSON([
            "conversations": [] as [Any],
            "meta": Self.metaPayload(key: "conversations"),
        ])
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        _ = try await svc.participantConversations.list(.init(
            identity: "alice",
            address: "+15551234567",
            pageSize: 25
        ))
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.hasPrefix(
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/ParticipantConversations"
        ))
        XCTAssertTrue(url.contains("Identity=alice"))
        XCTAssertTrue(url.contains("PageSize=25"))
        XCTAssertTrue(url.contains("Address="))
    }

    // ===================================================================
    // Service-scoped Bindings — list/fetch/delete
    // ===================================================================

    func testServiceBindingsListSendsBindingTypeQuery() async throws {
        enqueueJSON([
            "bindings": [] as [Any],
            "meta": Self.metaPayload(key: "bindings"),
        ])
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        _ = try await svc.bindings.list(.init(bindingType: "apn", identity: "alice"))
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("BindingType=apn"))
        XCTAssertTrue(url.contains("Identity=alice"))
        XCTAssertTrue(url.hasPrefix(
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Bindings"
        ))
    }

    func testServiceBindingsFetchAndDelete() async throws {
        let bsSid = "BS" + String(repeating: "a", count: 32)
        enqueueJSON([
            "sid": bsSid,
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "binding_type": "fcm",
            "endpoint": "device-x",
            "identity": "alice",
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Bindings/\(bsSid)",
        ])
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        let b = try await svc.bindings.fetch(sid: bsSid)
        XCTAssertEqual(b.sid, bsSid)
        XCTAssertEqual(b.bindingType, "fcm")

        enqueueRaw(status: 204)
        try await svc.bindings.delete(sid: bsSid)
        XCTAssertEqual(MockResponses.shared.captured[1].method, "DELETE")
        XCTAssertEqual(
            MockResponses.shared.captured[1].url.absoluteString,
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Bindings/\(bsSid)"
        )
    }

    // ===================================================================
    // Per-service Configuration (singleton) — fetch + update with bool
    // ===================================================================

    func testServiceConfigurationFetchAndUpdate() async throws {
        enqueueJSON([
            "chat_service_sid": Self.chatServiceSid,
            "reachability_enabled": false,
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Configuration",
        ])
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        let cfg = try await svc.configuration.fetch()
        XCTAssertEqual(cfg.chatServiceSid, Self.chatServiceSid)
        XCTAssertEqual(cfg.reachabilityEnabled, false)

        enqueueJSON([
            "chat_service_sid": Self.chatServiceSid,
            "reachability_enabled": true,
            "default_chat_service_role_sid": "RL" + String(repeating: "1", count: 32),
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Configuration",
        ], status: 202)
        _ = try await svc.configuration.update(.init(
            defaultChatServiceRoleSid: "RL" + String(repeating: "1", count: 32),
            reachabilityEnabled: true
        ))
        let form = parseForm(MockResponses.shared.captured[1].body)
        XCTAssertEqual(form["ReachabilityEnabled"]?.first, "true")
        XCTAssertTrue(form["DefaultChatServiceRoleSid"]?.first?.hasPrefix("RL") == true)
    }

    // ===================================================================
    // Per-service Notification (singleton) — dotted form keys + bool
    // ===================================================================

    func testServiceNotificationUpdateSendsDottedKeys() async throws {
        enqueueJSON([
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "log_enabled": true,
            "new_message": ["enabled": true, "template": "hi"],
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Configuration/Notifications",
        ])
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        _ = try await svc.configuration.notifications.update(.init(
            logEnabled: true,
            newMessageEnabled: true,
            newMessageTemplate: "hi",
            newMessageBadgeCountEnabled: false,
            newMessageWithMediaEnabled: true,
            newMessageWithMediaTemplate: "media",
            addedToConversationEnabled: true,
            addedToConversationTemplate: "added",
            removedFromConversationEnabled: false,
            removedFromConversationTemplate: "removed"
        ))
        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Configuration/Notifications"
        )
        let form = parseForm(req.body)
        XCTAssertEqual(form["LogEnabled"]?.first, "true")
        XCTAssertEqual(form["NewMessage.Enabled"]?.first, "true")
        XCTAssertEqual(form["NewMessage.Template"]?.first, "hi")
        XCTAssertEqual(form["NewMessage.BadgeCountEnabled"]?.first, "false")
        XCTAssertEqual(form["NewMessage.WithMedia.Enabled"]?.first, "true")
        XCTAssertEqual(form["NewMessage.WithMedia.Template"]?.first, "media")
        XCTAssertEqual(form["AddedToConversation.Enabled"]?.first, "true")
        XCTAssertEqual(form["AddedToConversation.Template"]?.first, "added")
        XCTAssertEqual(form["RemovedFromConversation.Enabled"]?.first, "false")
        XCTAssertEqual(form["RemovedFromConversation.Template"]?.first, "removed")
    }

    // ===================================================================
    // Per-service WebhookConfiguration (singleton) — repeated Filters + method
    // ===================================================================

    func testServiceWebhookConfigurationUpdateRepeatsFilters() async throws {
        enqueueJSON([
            "account_sid": Self.accountSid,
            "chat_service_sid": Self.chatServiceSid,
            "pre_webhook_url": "https://example.com/pre",
            "post_webhook_url": "https://example.com/post",
            "method": "POST",
            "filters": ["onMessageAdded", "onConversationAdded"],
            "url": "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Configuration/Webhooks",
        ])
        let c = try makeClient()
        let svc = c.conversationsV1.services.scope(chatServiceSid: Self.chatServiceSid)
        let cfg = try await svc.configuration.webhooks.update(.init(
            preWebhookUrl: "https://example.com/pre",
            postWebhookUrl: "https://example.com/post",
            method: "POST",
            filters: ["onMessageAdded", "onConversationAdded"]
        ))
        XCTAssertEqual(cfg.method, "POST")
        XCTAssertEqual(cfg.filters?.count, 2)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/Services/\(Self.chatServiceSid)/Configuration/Webhooks"
        )
        let form = parseForm(req.body)
        XCTAssertEqual(form["Method"]?.first, "POST")
        XCTAssertEqual(form["Filters"]?.count, 2)
        XCTAssertTrue(form["Filters"]?.contains("onMessageAdded") == true)
        XCTAssertTrue(form["Filters"]?.contains("onConversationAdded") == true)
    }
}
