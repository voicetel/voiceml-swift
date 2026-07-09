import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import VoiceML

// Wire-shape tests for the v0.9.2 surface: per-product host routing, Messaging
// Service (#16), and Pricing v1/v2 (#18). Reuses MockURLProtocol +
// MockResponses from SmokeTests.swift.
//
// Messaging Service must ride messaging.voicetel.com (that host is what
// disambiguates it from a Conversation Service on the shared /v1/Services
// path). Pricing rides the default host. Host derivation is unit-tested
// directly against `resolveProductBaseURLs`.
final class V092Tests: XCTestCase {

    static let accountSid = "AC" + String(repeating: "f", count: 32)
    static let apiKey = "secret-key-1234"
    static let base = "https://voiceml.voicetel.com"
    static let msg = "https://messaging.voicetel.com"
    static let conv = "https://conversations.voicetel.com"

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

    private static func meta() -> [String: Any] {
        [
            "first_page_url": "\(Self.msg)/v1/Services?Page=0",
            "next_page_url": NSNull(),
            "previous_page_url": NSNull(),
            "url": "\(Self.msg)/v1/Services",
            "page": 0,
            "page_size": 50,
            "key": "services",
        ]
    }

    private func messagingServicePayload(sid: String = "MG" + String(repeating: "0", count: 32)) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "friendly_name": "alerts",
            "inbound_request_url": "https://example.com/in",
            "sticky_sender": true,
            "date_created": "2026-07-08T00:00:00Z",
            "date_updated": "2026-07-08T00:00:00Z",
            "url": "\(Self.msg)/v1/Services/\(sid)",
        ]
    }

    // ===================================================================
    // Host resolution
    // ===================================================================

    func testHostDerivationFromDefault() {
        let r = resolveProductBaseURLs(baseURL: URL(string: Self.base)!)
        XCTAssertEqual(r.defaultURL.absoluteString, Self.base)
        XCTAssertEqual(r.messaging.absoluteString, Self.msg)
        XCTAssertEqual(r.conversations.absoluteString, Self.conv)
    }

    func testHostDerivationRegional() {
        let r = resolveProductBaseURLs(baseURL: URL(string: "https://east-1.us.voiceml.voicetel.com")!)
        XCTAssertEqual(r.defaultURL.absoluteString, "https://east-1.us.voiceml.voicetel.com")
        XCTAssertEqual(r.messaging.absoluteString, "https://east-1.us.messaging.voicetel.com")
        XCTAssertEqual(r.conversations.absoluteString, "https://east-1.us.conversations.voicetel.com")
    }

    func testHostDerivationSelfHostedFallsBackToSingleHost() {
        // A custom host has no `voiceml` label to swap — every product stays on
        // it, so a single-host deployment keeps working.
        let r = resolveProductBaseURLs(baseURL: URL(string: "https://pbx.acme.com")!)
        XCTAssertEqual(r.defaultURL.absoluteString, "https://pbx.acme.com")
        XCTAssertEqual(r.messaging.absoluteString, "https://pbx.acme.com")
        XCTAssertEqual(r.conversations.absoluteString, "https://pbx.acme.com")
    }

    func testHostDerivationExplicitOverridesWin() {
        let r = resolveProductBaseURLs(
            baseURL: URL(string: "https://pbx.acme.com")!,
            messagingBaseURL: URL(string: "https://msg.acme.com")!,
            conversationsBaseURL: URL(string: "https://conv.acme.com/")!
        )
        XCTAssertEqual(r.defaultURL.absoluteString, "https://pbx.acme.com")
        XCTAssertEqual(r.messaging.absoluteString, "https://msg.acme.com")
        XCTAssertEqual(r.conversations.absoluteString, "https://conv.acme.com")
    }

    func testV092ResourcesWired() throws {
        let c = try makeClient()
        _ = c.messagingV1.services
        _ = c.pricing.v1.voice.countries
        _ = c.pricing.v1.voice.numbers
        _ = c.pricing.v1.messaging.countries
        _ = c.pricing.v1.phoneNumbers.countries
        _ = c.pricing.v2.voice.countries
        _ = c.pricing.v2.voice.numbers
        _ = c.pricing.v2.trunking.countries
        _ = c.pricing.v2.trunking.numbers
    }

    // ===================================================================
    // Messaging Service — CRUD on the messaging host
    // ===================================================================

    func testMessagingServiceCrudOnMessagingHost() async throws {
        let sid = "MG" + String(repeating: "1", count: 32)
        enqueueJSON(messagingServicePayload(sid: sid), status: 201)                      // create
        enqueueJSON(["services": [messagingServicePayload(sid: sid)], "meta": Self.meta()]) // list
        enqueueJSON(messagingServicePayload(sid: sid))                                    // fetch
        enqueueJSON(messagingServicePayload(sid: sid))                                    // update
        enqueueRaw(status: 204)                                                           // delete

        let c = try makeClient()
        let created = try await c.messagingV1.services.create(.init(
            friendlyName: "alerts",
            inboundRequestUrl: "https://example.com/in",
            stickySender: true
        ))
        let listed = try await c.messagingV1.services.list(.init(pageSize: 25))
        let fetched = try await c.messagingV1.services.fetch(sid: sid)
        let updated = try await c.messagingV1.services.update(sid: sid, .init(friendlyName: "renamed"))
        try await c.messagingV1.services.delete(sid: sid)

        XCTAssertEqual(created.sid, sid)
        XCTAssertTrue(created.sid?.hasPrefix("MG") == true)
        XCTAssertEqual(listed.services?.count, 1)
        XCTAssertEqual(fetched.sid, sid)
        XCTAssertEqual(updated.sid, sid)

        let reqs = MockResponses.shared.captured
        // Every request must have hit the messaging host, not the default one.
        for r in reqs {
            XCTAssertEqual(r.url.host, "messaging.voicetel.com")
        }
        let createBody = parseForm(reqs[0].body)
        XCTAssertEqual(createBody["FriendlyName"]?.first, "alerts")
        XCTAssertEqual(createBody["InboundRequestUrl"]?.first, "https://example.com/in")
        XCTAssertEqual(createBody["StickySender"]?.first, "true")
        XCTAssertTrue(reqs[1].url.absoluteString.contains("PageSize=25"))
        let updateBody = parseForm(reqs[3].body)
        XCTAssertEqual(updateBody["FriendlyName"], ["renamed"])
        XCTAssertNil(updateBody["StickySender"])
    }

    func testMessagingServiceHostOverride() async throws {
        enqueueJSON(["services": [] as [Any], "meta": Self.meta()])
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: cfg)
        let c = try VoiceMLClient(
            accountSid: Self.accountSid,
            apiKey: Self.apiKey,
            baseURL: URL(string: "https://pbx.acme.com")!,
            messagingBaseURL: URL(string: "https://msg.acme.com")!,
            session: session
        )
        _ = try await c.messagingV1.services.list()
        XCTAssertEqual(MockResponses.shared.captured[0].url.host, "msg.acme.com")
    }

    // ===================================================================
    // Pricing v1/v2 — read-only on the default host
    // ===================================================================

    func testPricingV1VoiceCountriesAndNumber() async throws {
        enqueueJSON([
            "countries": [
                [
                    "country": "United States",
                    "iso_country": "US",
                    "url": "\(Self.base)/v1/Voice/Countries/US",
                ] as [String: Any],
            ],
            "meta": ["page": 0, "page_size": 50],
        ])
        enqueueJSON([
            "country": "United States",
            "iso_country": "US",
            "outbound_prefix_prices": [
                [
                    "prefixes": ["1"],
                    "base_price": "0.013",
                    "current_price": "0.013",
                    "friendly_name": "United States & Canada",
                ] as [String: Any],
            ],
            "inbound_call_prices": [
                ["base_price": "0.0085", "current_price": "0.0085", "number_type": "local"] as [String: Any],
            ],
            "price_unit": "USD",
            "url": "\(Self.base)/v1/Voice/Countries/US",
        ])
        enqueueJSON([
            "number": "+18005551234",
            "country": "United States",
            "iso_country": "US",
            "outbound_call_price": ["base_price": "0.013", "current_price": "0.013"],
            "inbound_call_price": [
                "base_price": "0.0085",
                "current_price": "0.0085",
                "number_type": "toll free",
            ],
            "price_unit": "USD",
            "url": "\(Self.base)/v1/Voice/Numbers/+18005551234",
        ])

        let c = try makeClient()
        let listed = try await c.pricing.v1.voice.countries.list()
        let fetched = try await c.pricing.v1.voice.countries.fetch("US")
        let num = try await c.pricing.v1.voice.numbers.fetch("+18005551234")

        XCTAssertEqual(listed.countries?.first?.isoCountry, "US")
        XCTAssertEqual(fetched.outboundPrefixPrices?.first?.prefixes, ["1"])
        XCTAssertEqual(num.inboundCallPrice?.numberType, "toll free")

        let reqs = MockResponses.shared.captured
        for r in reqs {
            XCTAssertEqual(r.url.host, "voiceml.voicetel.com")
        }
        // The E.164 number path segment is URL-encoded (`+` → `%2B`).
        XCTAssertTrue(reqs[2].url.absoluteString.contains("/v1/Voice/Numbers/%2B18005551234"))
        XCTAssertFalse(reqs[0].url.absoluteString.contains(".json"))
    }

    func testPricingV2VoiceNumberWithOrigination() async throws {
        enqueueJSON([
            "destination_number": "+18005551234",
            "origination_number": "+15551112222",
            "country": "United States",
            "iso_country": "US",
            "outbound_call_prices": [
                [
                    "origination_prefixes": ["1"],
                    "base_price": "0.013",
                    "current_price": "0.013",
                ] as [String: Any],
            ],
            "inbound_call_price": [
                "base_price": "0.0085",
                "current_price": "0.0085",
                "number_type": "local",
            ],
            "price_unit": "USD",
            "url": "\(Self.base)/v2/Voice/Numbers/+18005551234",
        ])
        let c = try makeClient()
        let got = try await c.pricing.v2.voice.numbers.fetch(
            "+18005551234",
            originationNumber: "+15551112222"
        )
        XCTAssertEqual(got.originationNumber, "+15551112222")

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.url.host, "voiceml.voicetel.com")
        XCTAssertTrue(req.url.absoluteString.contains("/v2/Voice/Numbers/%2B18005551234"))
        XCTAssertTrue(req.url.absoluteString.contains("OriginationNumber=%2B15551112222"))
    }

    func testPricingV2TrunkingCountry() async throws {
        enqueueJSON([
            "country": "United States",
            "iso_country": "US",
            "terminating_prefix_prices": [
                [
                    "origination_prefixes": ["1"],
                    "destination_prefixes": ["1"],
                    "base_price": "0.013",
                    "current_price": "0.013",
                    "friendly_name": "US",
                ] as [String: Any],
            ],
            "originating_call_prices": [
                ["base_price": "0.0085", "current_price": "0.0085", "number_type": "local"] as [String: Any],
            ],
            "price_unit": "USD",
            "url": "\(Self.base)/v2/Trunking/Countries/US",
        ])
        let c = try makeClient()
        let got = try await c.pricing.v2.trunking.countries.fetch("US")
        XCTAssertEqual(got.terminatingPrefixPrices?.first?.friendlyName, "US")
        XCTAssertEqual(MockResponses.shared.captured[0].url.host, "voiceml.voicetel.com")
    }

    // ===================================================================
    // Async smoke
    // ===================================================================

    func testAsyncMessagingServiceCreate() async throws {
        enqueueJSON(messagingServicePayload(), status: 201)
        let c = try makeClient()
        let created = try await c.messagingV1.services.create(.init(friendlyName: "alerts"))
        XCTAssertTrue(created.sid?.hasPrefix("MG") == true)
        XCTAssertEqual(MockResponses.shared.captured[0].url.host, "messaging.voicetel.com")
    }

    func testAsyncPricingV1MessagingCountriesList() async throws {
        enqueueJSON(["countries": [] as [Any], "meta": ["page": 0]])
        let c = try makeClient()
        let listed = try await c.pricing.v1.messaging.countries.list()
        XCTAssertEqual(listed.countries?.count, 0)
        XCTAssertEqual(MockResponses.shared.captured[0].url.host, "voiceml.voicetel.com")
    }
}
