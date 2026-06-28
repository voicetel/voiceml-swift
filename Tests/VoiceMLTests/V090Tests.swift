import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import VoiceML

// Wire-shape tests for the v0.9.0 surface (#420 Voice v1, #421
// Conversations v1, RoutesV2 phone numbers). Reuses MockURLProtocol +
// MockResponses from SmokeTests.swift.
final class V090Tests: XCTestCase {

    static let accountSid = "AC" + String(repeating: "f", count: 32)
    static let apiKey = "secret-key-1234"

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

    private static func metaPayload() -> [String: Any] {
        [
            "first_page_url": "https://voiceml.voicetel.com/v1/Conversations?PageSize=50",
            "next_page_url": NSNull(),
            "previous_page_url": NSNull(),
            "url": "https://voiceml.voicetel.com/v1/Conversations?PageSize=50",
            "page": 0,
            "page_size": 50,
            "key": "conversations",
        ]
    }

    // MARK: - Transport `/v1/` skip

    func testApplyJSONSuffixSkipsV1Paths() {
        XCTAssertEqual(
            Transport.applyJSONSuffix("/v1/Conversations"),
            "/v1/Conversations"
        )
        XCTAssertEqual(
            Transport.applyJSONSuffix("/v1/Conversations?PageSize=50"),
            "/v1/Conversations?PageSize=50"
        )
        XCTAssertEqual(
            Transport.applyJSONSuffix("/v1/IpRecords/IL0"),
            "/v1/IpRecords/IL0"
        )
    }

    // MARK: - Client wiring

    func testClientExposesNewNamespaces() throws {
        let c = try makeClient()
        _ = c.voiceV1
        _ = c.voiceV1.ipRecords
        _ = c.voiceV1.sourceIpMappings
        _ = c.voiceV1.byocTrunks
        _ = c.voiceV1.connectionPolicies
        _ = c.voiceV1.settings
        _ = c.conversationsV1
        _ = c.conversationsV1.conversations
        _ = c.conversationsV1.roles
        _ = c.conversationsV1.users
        _ = c.conversationsV1.credentials
        _ = c.conversationsV1.configuration
        _ = c.conversationsV1.configuration.webhooks
        _ = c.conversationsV1.configuration.addresses
        _ = c.conversationsV1.participantConversations
        _ = c.conversationsV1.conversationWithParticipants
        _ = c.conversationsV1.services
        _ = c.routesV2.phoneNumbers
    }

    // ===================================================================
    // Voice v1
    // ===================================================================

    // MARK: - IpRecord

    func testVoiceV1IpRecordCreateAndDecode() async throws {
        enqueueJSON([
            "account_sid": Self.accountSid,
            "sid": "IL" + String(repeating: "0", count: 32),
            "friendly_name": "carrier-a",
            "ip_address": "203.0.113.10",
            "cidr_prefix_length": 24,
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/IpRecords/IL0",
        ], status: 201)
        let c = try makeClient()

        let r = try await c.voiceV1.ipRecords.create(.init(
            ipAddress: "203.0.113.10",
            friendlyName: "carrier-a",
            cidrPrefixLength: 24
        ))
        XCTAssertTrue(r.sid?.hasPrefix("IL") == true)
        XCTAssertEqual(r.ipAddress, "203.0.113.10")
        XCTAssertEqual(r.cidrPrefixLength, 24)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "POST")
        // Critical: no .json suffix on /v1/ paths.
        XCTAssertEqual(req.url.absoluteString, "https://voiceml.voicetel.com/v1/IpRecords")
        XCTAssertEqual(req.headers["Content-Type"], "application/x-www-form-urlencoded")
        let form = parseForm(req.body)
        XCTAssertEqual(form["IpAddress"]?.first, "203.0.113.10")
        XCTAssertEqual(form["FriendlyName"]?.first, "carrier-a")
        XCTAssertEqual(form["CidrPrefixLength"]?.first, "24")
    }

    func testVoiceV1IpRecordListUsesMetaEnvelope() async throws {
        enqueueJSON([
            "ip_records": [
                [
                    "account_sid": Self.accountSid,
                    "sid": "IL" + String(repeating: "0", count: 32),
                    "ip_address": "203.0.113.10",
                    "cidr_prefix_length": 32,
                    "date_created": "2026-06-27T12:00:00Z",
                    "date_updated": "2026-06-27T12:00:00Z",
                    "url": "https://voiceml.voicetel.com/v1/IpRecords/IL0",
                ] as [String: Any],
            ],
            "meta": Self.metaPayload(),
        ])
        let c = try makeClient()

        let result = try await c.voiceV1.ipRecords.list(.init(pageSize: 50))
        XCTAssertEqual(result.ipRecords.count, 1)
        XCTAssertEqual(result.meta.pageSize, 50)

        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("PageSize=50"))
        XCTAssertFalse(url.contains(".json"))
        XCTAssertTrue(url.hasPrefix("https://voiceml.voicetel.com/v1/IpRecords"))
    }

    func testVoiceV1IpRecordUpdateAndDelete() async throws {
        let sid = "IL" + String(repeating: "1", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "sid": sid,
            "friendly_name": "renamed",
            "ip_address": "203.0.113.11",
            "cidr_prefix_length": 32,
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:01Z",
            "url": "https://voiceml.voicetel.com/v1/IpRecords/\(sid)",
        ])
        let c = try makeClient()
        _ = try await c.voiceV1.ipRecords.update(sid: sid, .init(friendlyName: "renamed"))

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.url.absoluteString, "https://voiceml.voicetel.com/v1/IpRecords/\(sid)")
        XCTAssertEqual(parseForm(req.body)["FriendlyName"]?.first, "renamed")

        enqueueRaw(status: 204)
        try await c.voiceV1.ipRecords.delete(sid: sid)
        XCTAssertEqual(MockResponses.shared.captured[1].method, "DELETE")
    }

    // MARK: - SourceIpMapping

    func testVoiceV1SourceIpMappingCreateAndDecode() async throws {
        let sid = "IB" + String(repeating: "2", count: 32)
        enqueueJSON([
            "sid": sid,
            "ip_record_sid": "IL" + String(repeating: "0", count: 32),
            "sip_domain_sid": "SD" + String(repeating: "0", count: 32),
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/SourceIpMappings/\(sid)",
        ], status: 201)
        let c = try makeClient()

        let m = try await c.voiceV1.sourceIpMappings.create(.init(
            ipRecordSid: "IL" + String(repeating: "0", count: 32),
            sipDomainSid: "SD" + String(repeating: "0", count: 32)
        ))
        XCTAssertEqual(m.sid, sid)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.url.absoluteString, "https://voiceml.voicetel.com/v1/SourceIpMappings")
        let form = parseForm(req.body)
        XCTAssertEqual(form["IpRecordSid"]?.first, "IL" + String(repeating: "0", count: 32))
        XCTAssertEqual(form["SipDomainSid"]?.first, "SD" + String(repeating: "0", count: 32))
    }

    // MARK: - ByocTrunk

    func testVoiceV1ByocTrunkCreateAndDecode() async throws {
        let sid = "BY" + String(repeating: "3", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "sid": sid,
            "friendly_name": "carrier-x",
            "voice_url": "https://example.com/twiml",
            "voice_method": "POST",
            "cnam_lookup_enabled": true,
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/ByocTrunks/\(sid)",
        ], status: 201)
        let c = try makeClient()

        let t = try await c.voiceV1.byocTrunks.create(.init(
            friendlyName: "carrier-x",
            voiceUrl: "https://example.com/twiml",
            voiceMethod: "POST",
            cnamLookupEnabled: true
        ))
        XCTAssertEqual(t.sid, sid)
        XCTAssertEqual(t.cnamLookupEnabled, true)

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["FriendlyName"]?.first, "carrier-x")
        XCTAssertEqual(form["VoiceMethod"]?.first, "POST")
        XCTAssertEqual(form["CnamLookupEnabled"]?.first, "true")
    }

    // MARK: - ConnectionPolicy + Target

    func testVoiceV1ConnectionPolicyCreateAndTargets() async throws {
        let cpSid = "NY" + String(repeating: "4", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "sid": cpSid,
            "friendly_name": "p",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/ConnectionPolicies/\(cpSid)",
            "links": ["targets": "https://voiceml.voicetel.com/v1/ConnectionPolicies/\(cpSid)/Targets"],
        ], status: 201)
        let c = try makeClient()

        let cp = try await c.voiceV1.connectionPolicies.create(.init(friendlyName: "p"))
        XCTAssertEqual(cp.sid, cpSid)
        XCTAssertEqual(cp.links?["targets"], "https://voiceml.voicetel.com/v1/ConnectionPolicies/\(cpSid)/Targets")
        XCTAssertEqual(
            MockResponses.shared.captured[0].url.absoluteString,
            "https://voiceml.voicetel.com/v1/ConnectionPolicies"
        )

        let tSid = "NE" + String(repeating: "5", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "connection_policy_sid": cpSid,
            "sid": tSid,
            "target": "sip:edge@example.com",
            "priority": 10,
            "weight": 5,
            "enabled": true,
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/ConnectionPolicies/\(cpSid)/Targets/\(tSid)",
        ], status: 201)

        let t = try await c.voiceV1.connectionPolicies.createTarget(
            connectionPolicySid: cpSid,
            .init(target: "sip:edge@example.com", priority: 10, weight: 5, enabled: true)
        )
        XCTAssertEqual(t.priority, 10)
        XCTAssertEqual(t.weight, 5)
        XCTAssertEqual(t.enabled, true)

        let req = MockResponses.shared.captured[1]
        XCTAssertEqual(req.url.absoluteString, "https://voiceml.voicetel.com/v1/ConnectionPolicies/\(cpSid)/Targets")
        let form = parseForm(req.body)
        XCTAssertEqual(form["Target"]?.first, "sip:edge@example.com")
        XCTAssertEqual(form["Priority"]?.first, "10")
        XCTAssertEqual(form["Weight"]?.first, "5")
        XCTAssertEqual(form["Enabled"]?.first, "true")
    }

    // MARK: - DialingPermissions Settings

    func testVoiceV1SettingsFetchAndUpdate() async throws {
        enqueueJSON([
            "dialing_permissions_inheritance": false,
            "url": "https://voiceml.voicetel.com/v1/Settings",
        ])
        let c = try makeClient()
        let s = try await c.voiceV1.settings.fetch()
        XCTAssertEqual(s.dialingPermissionsInheritance, false)
        XCTAssertEqual(MockResponses.shared.captured[0].url.absoluteString, "https://voiceml.voicetel.com/v1/Settings")

        enqueueJSON([
            "dialing_permissions_inheritance": true,
            "url": "https://voiceml.voicetel.com/v1/Settings",
        ], status: 202)
        _ = try await c.voiceV1.settings.update(.init(dialingPermissionsInheritance: true))
        let form = parseForm(MockResponses.shared.captured[1].body)
        XCTAssertEqual(form["DialingPermissionsInheritance"]?.first, "true")
    }

    // ===================================================================
    // Conversations v1
    // ===================================================================

    // MARK: - Conversation CRUD

    func testConversationCreateSendsDottedTimerKeys() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "sid": chSid,
            "state": "active",
            "attributes": "{}",
            "friendly_name": "Support",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Conversations/\(chSid)",
        ], status: 201)
        let c = try makeClient()

        let conv = try await c.conversationsV1.conversations.create(.init(
            friendlyName: "Support",
            attributes: "{}",
            state: "active",
            timersInactive: "PT5M",
            timersClosed: "PT1H"
        ))
        XCTAssertEqual(conv.sid, chSid)
        XCTAssertEqual(conv.state, "active")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.url.absoluteString, "https://voiceml.voicetel.com/v1/Conversations")
        let form = parseForm(req.body)
        XCTAssertEqual(form["FriendlyName"]?.first, "Support")
        XCTAssertEqual(form["Attributes"]?.first, "{}")
        XCTAssertEqual(form["State"]?.first, "active")
        // Dotted keys must round-trip verbatim — Twilio's wire format requires them.
        XCTAssertEqual(form["Timers.Inactive"]?.first, "PT5M")
        XCTAssertEqual(form["Timers.Closed"]?.first, "PT1H")
    }

    // MARK: - Conversation messages

    func testConversationMessagesPathAndIndexDecode() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        let imSid = "IM" + String(repeating: "1", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "conversation_sid": chSid,
            "sid": imSid,
            "index": 7,
            "author": "+15551234567",
            "body": "Hello",
            "attributes": "{}",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Conversations/\(chSid)/Messages/\(imSid)",
        ], status: 201)
        let c = try makeClient()

        let msg = try await c.conversationsV1.conversations.messages(conversationSid: chSid)
            .create(.init(author: "+15551234567", body: "Hello"))
        XCTAssertEqual(msg.index, 7)
        XCTAssertEqual(msg.body, "Hello")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/Conversations/\(chSid)/Messages"
        )
        let form = parseForm(req.body)
        XCTAssertEqual(form["Author"]?.first, "+15551234567")
        XCTAssertEqual(form["Body"]?.first, "Hello")
    }

    // MARK: - Conversation participants — MessagingBinding dotted form

    func testConversationParticipantCreateSendsMessagingBindingDottedKeys() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        let mbSid = "MB" + String(repeating: "2", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "conversation_sid": chSid,
            "sid": mbSid,
            "attributes": "{}",
            "messaging_binding": ["address": "+15551234567", "proxy_address": "+15550000000"],
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Conversations/\(chSid)/Participants/\(mbSid)",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.conversationsV1.conversations.participants(conversationSid: chSid)
            .create(.init(
                messagingBindingAddress: "+15551234567",
                messagingBindingProxyAddress: "+15550000000"
            ))

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["MessagingBinding.Address"]?.first, "+15551234567")
        XCTAssertEqual(form["MessagingBinding.ProxyAddress"]?.first, "+15550000000")
    }

    // MARK: - Conversation scoped webhooks — Configuration dotted form

    func testConversationScopedWebhookCreateSendsConfigurationDottedKeys() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        let whSid = "WH" + String(repeating: "3", count: 32)
        enqueueJSON([
            "sid": whSid,
            "account_sid": Self.accountSid,
            "conversation_sid": chSid,
            "target": "webhook",
            "url": "https://voiceml.voicetel.com/v1/Conversations/\(chSid)/Webhooks/\(whSid)",
            "configuration": ["url": "https://example.com/cb", "method": "POST"],
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
        ], status: 201)
        let c = try makeClient()

        let wh = try await c.conversationsV1.conversations.webhooks(conversationSid: chSid)
            .create(.init(
                target: "webhook",
                configurationUrl: "https://example.com/cb",
                configurationMethod: "POST",
                configurationReplayAfter: 0
            ))
        XCTAssertEqual(wh.sid, whSid)

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/Conversations/\(chSid)/Webhooks"
        )
        let form = parseForm(req.body)
        XCTAssertEqual(form["Target"]?.first, "webhook")
        XCTAssertEqual(form["Configuration.Url"]?.first, "https://example.com/cb")
        XCTAssertEqual(form["Configuration.Method"]?.first, "POST")
        XCTAssertEqual(form["Configuration.ReplayAfter"]?.first, "0")
    }

    // MARK: - Receipts (read-only)

    func testConversationMessageReceiptsListPath() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        let imSid = "IM" + String(repeating: "1", count: 32)
        enqueueJSON([
            "delivery_receipts": [] as [Any],
            "meta": Self.metaPayload(),
        ])
        let c = try makeClient()
        _ = try await c.conversationsV1.conversations.messages(conversationSid: chSid)
            .receipts(messageSid: imSid).list()

        XCTAssertEqual(
            MockResponses.shared.captured[0].url.absoluteString,
            "https://voiceml.voicetel.com/v1/Conversations/\(chSid)/Messages/\(imSid)/Receipts"
        )
    }

    // MARK: - Roles — repeated Permission

    func testRoleCreateSendsRepeatedPermission() async throws {
        let rlSid = "RL" + String(repeating: "4", count: 32)
        enqueueJSON([
            "sid": rlSid,
            "account_sid": Self.accountSid,
            "type": "conversation",
            "permissions": ["sendMessage", "leaveConversation"],
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Roles/\(rlSid)",
        ], status: 201)
        let c = try makeClient()

        let role = try await c.conversationsV1.roles.create(.init(
            friendlyName: "agent",
            type: "conversation",
            permission: ["sendMessage", "leaveConversation"]
        ))
        XCTAssertEqual(role.sid, rlSid)
        XCTAssertEqual(role.permissions, ["sendMessage", "leaveConversation"])

        let form = parseForm(MockResponses.shared.captured[0].body)
        // Repeated key — order preserved by the FormField array.
        XCTAssertEqual(form["Permission"], ["sendMessage", "leaveConversation"])
        XCTAssertEqual(form["FriendlyName"]?.first, "agent")
        XCTAssertEqual(form["Type"]?.first, "conversation")
    }

    // MARK: - Users + user-conversations

    func testUsersFetchAndUserConversationUpdate() async throws {
        let usSid = "US" + String(repeating: "5", count: 32)
        enqueueJSON([
            "sid": usSid,
            "account_sid": Self.accountSid,
            "identity": "alice",
            "attributes": "{}",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Users/\(usSid)",
        ])
        let c = try makeClient()
        let u = try await c.conversationsV1.users.fetch(sid: usSid)
        XCTAssertEqual(u.identity, "alice")

        // user-conversation update — notification level
        let chSid = "CH" + String(repeating: "0", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "conversation_sid": chSid,
            "user_sid": usSid,
            "conversation_state": "active",
            "notification_level": "muted",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Users/\(usSid)/Conversations/\(chSid)",
        ])
        let uc = try await c.conversationsV1.users.conversations(userSid: usSid)
            .update(conversationSid: chSid, .init(notificationLevel: "muted"))
        XCTAssertEqual(uc.notificationLevel, "muted")

        let req = MockResponses.shared.captured[1]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/Users/\(usSid)/Conversations/\(chSid)"
        )
        XCTAssertEqual(parseForm(req.body)["NotificationLevel"]?.first, "muted")
    }

    // MARK: - Credentials

    func testConversationsCredentialCreate() async throws {
        let crSid = "CR" + String(repeating: "6", count: 32)
        enqueueJSON([
            "sid": crSid,
            "account_sid": Self.accountSid,
            "friendly_name": "ios-push",
            "type": "apn",
            "sandbox": "sandbox",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Credentials/\(crSid)",
        ], status: 201)
        let c = try makeClient()
        let cr = try await c.conversationsV1.credentials.create(.init(
            type: "apn",
            friendlyName: "ios-push",
            sandbox: true
        ))
        XCTAssertEqual(cr.type, "apn")
        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["Type"]?.first, "apn")
        XCTAssertEqual(form["Sandbox"]?.first, "true")
    }

    // MARK: - Configuration (singleton)

    func testConfigurationFetchAndUpdate() async throws {
        enqueueJSON([
            "account_sid": Self.accountSid,
            "default_chat_service_sid": NSNull(),
            "default_messaging_service_sid": NSNull(),
            "url": "https://voiceml.voicetel.com/v1/Configuration",
        ])
        let c = try makeClient()
        let cfg = try await c.conversationsV1.configuration.fetch()
        XCTAssertNil(cfg.defaultChatServiceSid)

        enqueueJSON([
            "account_sid": Self.accountSid,
            "default_inactive_timer": "PT5M",
            "url": "https://voiceml.voicetel.com/v1/Configuration",
        ])
        _ = try await c.conversationsV1.configuration.update(.init(defaultInactiveTimer: "PT5M"))
        let form = parseForm(MockResponses.shared.captured[1].body)
        XCTAssertEqual(form["DefaultInactiveTimer"]?.first, "PT5M")
    }

    // MARK: - ConfigurationWebhook (singleton)

    func testConfigurationWebhookUpdateSendsRepeatedFilters() async throws {
        enqueueJSON([
            "account_sid": Self.accountSid,
            "method": "POST",
            "target": "webhook",
            "filters": ["onMessageAdded", "onConversationAdded"],
            "url": "https://voiceml.voicetel.com/v1/Configuration/Webhooks",
        ])
        let c = try makeClient()
        let wh = try await c.conversationsV1.configuration.webhooks.update(.init(
            method: "POST",
            filters: ["onMessageAdded", "onConversationAdded"],
            target: "webhook"
        ))
        XCTAssertEqual(wh.method, "POST")
        XCTAssertEqual(wh.target, "webhook")

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["Method"]?.first, "POST")
        XCTAssertEqual(form["Filters"], ["onMessageAdded", "onConversationAdded"])
        XCTAssertEqual(form["Target"]?.first, "webhook")
    }

    // MARK: - ConfigAddress — AutoCreation dotted form

    func testConfigAddressCreateSendsAutoCreationDottedKeys() async throws {
        let igSid = "IG" + String(repeating: "7", count: 32)
        enqueueJSON([
            "sid": igSid,
            "account_sid": Self.accountSid,
            "type": "sms",
            "address": "+15551234567",
            "auto_creation": ["enabled": true, "type": "webhook", "webhook_url": "https://example.com/auto"],
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Configuration/Addresses/\(igSid)",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.conversationsV1.configuration.addresses.create(.init(
            type: "sms",
            address: "+15551234567",
            autoCreationEnabled: true,
            autoCreationType: "webhook",
            autoCreationWebhookUrl: "https://example.com/auto"
        ))

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["Type"]?.first, "sms")
        XCTAssertEqual(form["Address"]?.first, "+15551234567")
        XCTAssertEqual(form["AutoCreation.Enabled"]?.first, "true")
        XCTAssertEqual(form["AutoCreation.Type"]?.first, "webhook")
        XCTAssertEqual(form["AutoCreation.WebhookUrl"]?.first, "https://example.com/auto")
    }

    // MARK: - ParticipantConversations (filtered list)

    func testParticipantConversationsListWithIdentityFilter() async throws {
        enqueueJSON([
            "conversations": [] as [Any],
            "meta": Self.metaPayload(),
        ])
        let c = try makeClient()
        _ = try await c.conversationsV1.participantConversations.list(.init(identity: "alice", pageSize: 10))

        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("/v1/ParticipantConversations"))
        XCTAssertTrue(url.contains("Identity=alice"))
        XCTAssertTrue(url.contains("PageSize=10"))
        XCTAssertFalse(url.contains(".json"))
    }

    // MARK: - ConversationWithParticipants — repeated Participant

    func testConversationWithParticipantsCreateSendsRepeatedParticipant() async throws {
        let chSid = "CH" + String(repeating: "0", count: 32)
        enqueueJSON([
            "account_sid": Self.accountSid,
            "sid": chSid,
            "state": "active",
            "attributes": "{}",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Conversations/\(chSid)",
        ], status: 201)
        let c = try makeClient()
        _ = try await c.conversationsV1.conversationWithParticipants.create(.init(
            friendlyName: "Triage",
            participant: [
                #"{"identity":"alice"}"#,
                #"{"messaging_binding":{"address":"+15551234567"}}"#,
            ]
        ))

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(
            req.url.absoluteString,
            "https://voiceml.voicetel.com/v1/ConversationWithParticipants"
        )
        let form = parseForm(req.body)
        XCTAssertEqual(form["FriendlyName"]?.first, "Triage")
        XCTAssertEqual(form["Participant"]?.count, 2)
        XCTAssertEqual(form["Participant"]?[0], #"{"identity":"alice"}"#)
    }

    // MARK: - Services

    func testServiceCreateAndDelete() async throws {
        let isSid = "IS" + String(repeating: "8", count: 32)
        enqueueJSON([
            "sid": isSid,
            "account_sid": Self.accountSid,
            "friendly_name": "Triage",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Services/\(isSid)",
        ], status: 201)
        let c = try makeClient()
        let svc = try await c.conversationsV1.services.create(.init(friendlyName: "Triage"))
        XCTAssertEqual(svc.sid, isSid)
        XCTAssertEqual(svc.friendlyName, "Triage")

        enqueueRaw(status: 204)
        try await c.conversationsV1.services.delete(chatServiceSid: isSid)
        XCTAssertEqual(MockResponses.shared.captured[1].method, "DELETE")
        XCTAssertEqual(
            MockResponses.shared.captured[1].url.absoluteString,
            "https://voiceml.voicetel.com/v1/Services/\(isSid)"
        )
    }

    // ===================================================================
    // RoutesV2 — PhoneNumber
    // ===================================================================

    func testRoutesV2PhoneNumberFetchAndUpdate() async throws {
        let sid = "QQ" + String(repeating: "9", count: 32)
        let pn = "+18005551234"
        enqueueJSON([
            "phone_number": pn,
            "sid": sid,
            "account_sid": Self.accountSid,
            "friendly_name": "Main",
            "voice_region": "us1",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v2/PhoneNumbers/\(pn)",
        ])
        let c = try makeClient()
        let r = try await c.routesV2.phoneNumbers.fetch(phoneNumber: pn)
        XCTAssertEqual(r.sid, sid)
        XCTAssertEqual(r.phoneNumber, pn)
        XCTAssertEqual(r.voiceRegion, "us1")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "GET")
        // /v2/ paths must not pick up the .json suffix.
        XCTAssertFalse(req.url.absoluteString.contains(".json"))
        XCTAssertTrue(req.url.absoluteString.contains("/v2/PhoneNumbers/"))

        // update
        enqueueJSON([
            "phone_number": pn,
            "sid": sid,
            "account_sid": Self.accountSid,
            "voice_region": "us2",
            "date_created": "2026-06-27T12:00:00Z",
            "date_updated": "2026-06-27T12:00:01Z",
            "url": "https://voiceml.voicetel.com/v2/PhoneNumbers/\(pn)",
        ])
        let r2 = try await c.routesV2.phoneNumbers.update(phoneNumber: pn, .init(voiceRegion: "us2"))
        XCTAssertEqual(r2.voiceRegion, "us2")

        let form = parseForm(MockResponses.shared.captured[1].body)
        XCTAssertEqual(form["VoiceRegion"]?.first, "us2")
    }
}
