import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import VoiceML

// Regression tests for the 2026-10 fix sweep. Every test runs entirely against the
// URLProtocol mock — none of them may reach the real API host.

final class VoiceMLFixTests: XCTestCase {

    static let accountSid = "AC" + String(repeating: "f", count: 32)
    static let apiKey = "super-secret-key-1234"

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

    private func enqueueJSON(_ obj: [String: Any], status: Int = 200, headers: [String: String] = [:]) {
        let data = try! JSONSerialization.data(withJSONObject: obj)
        var h = headers
        h["Content-Type"] = "application/json"
        MockResponses.shared.enqueue(.init(statusCode: status, body: data, headers: h))
    }

    private func enqueueRaw(_ body: Data, status: Int, headers: [String: String] = [:]) {
        MockResponses.shared.enqueue(.init(statusCode: status, body: body, headers: headers))
    }

    private func callPayload(sid: String = "CA" + String(repeating: "0", count: 32)) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "api_version": "2010-04-01",
            "status": "queued",
            "direction": "outbound-api",
            "date_created": "Mon, 19 May 2026 12:00:00 +0000",
            "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls/\(sid).json",
        ]
    }

    private func authHeader() -> String {
        "Basic " + Data("\(Self.accountSid):\(Self.apiKey)".utf8).base64EncodedString()
    }

    // MARK: - Recording audio redirect (CRITICAL: credentials must never leak to S3)

    func testGetAudioRedirectStripsAuthorization() async throws {
        enqueueRaw(Data(), status: 302, headers: [
            "Location": "https://s3.example.com/archives/RE123.wav?X-Amz-Signature=abc",
        ])
        enqueueRaw(Data("WAVBYTES".utf8), status: 200, headers: ["Content-Type": "audio/wav"])

        let c = try makeClient(maxRetries: 0)
        let audio = try await c.recordings.getAudio(recordingSid: "RE" + String(repeating: "1", count: 32))

        XCTAssertEqual(String(decoding: audio.body, as: UTF8.self), "WAVBYTES")
        let captured = MockResponses.shared.captured
        XCTAssertEqual(captured.count, 2)
        // First leg: authenticated GET on the API host.
        XCTAssertEqual(captured[0].url.host, "voiceml.voicetel.com")
        XCTAssertEqual(captured[0].headers["Authorization"], authHeader())
        // Second leg: fresh unauthenticated GET to the redirect target.
        XCTAssertEqual(captured[1].url.host, "s3.example.com")
        XCTAssertNil(captured[1].headers["Authorization"], "redirect leg must not carry Authorization")
        XCTAssertEqual(captured[1].url.query?.contains("X-Amz-Signature=abc"), true)
    }

    func testGetAudioRefusesNonHttpsRedirect() async throws {
        enqueueRaw(Data(), status: 302, headers: ["Location": "http://s3.example.com/archives/x.wav"])

        let c = try makeClient(maxRetries: 0)
        do {
            _ = try await c.recordings.getAudio(recordingSid: "RE" + String(repeating: "2", count: 32))
            XCTFail("expected throw")
        } catch let err as ApiError {
            XCTAssertTrue(err.message.contains("non-https"), err.message)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
        // Exactly one request — the downgrade leg was never sent.
        XCTAssertEqual(MockResponses.shared.captured.count, 1)
    }

    func testGetAudioDirect200() async throws {
        enqueueRaw(Data("ABC".utf8), status: 200, headers: ["Content-Type": "audio/wav"])
        let c = try makeClient(maxRetries: 0)
        let audio = try await c.recordings.getAudio(recordingSid: "RE" + String(repeating: "3", count: 32))
        XCTAssertEqual(audio.contentType, "audio/wav")
        XCTAssertEqual(MockResponses.shared.captured.count, 1)
        XCTAssertEqual(MockResponses.shared.captured[0].headers["Authorization"], authHeader())
    }

    // MARK: - Retry policy (C2)

    func testPostIsNotRetriedOn503() async throws {
        enqueueRaw(Data("busy".utf8), status: 503)
        enqueueJSON(callPayload(), status: 201) // must never be consumed
        let c = try makeClient()

        do {
            _ = try await c.calls.create(.init(to: "+14155550100", from: "+14155550101", url: "https://example.com/twiml"))
            XCTFail("expected throw")
        } catch is ServerError {
            // ok
        } catch {
            XCTFail("wrong error type: \(error)")
        }
        XCTAssertEqual(MockResponses.shared.captured.count, 1, "POST must be sent exactly once on 503")
    }

    func testPostIsNotRetriedOnReadTimeoutStyleTransportError() {
        // A timedOut URLError is ambiguous (connect vs read) — POST must not retry it.
        let err = URLError(.timedOut)
        XCTAssertFalse(Transport.isRetryableTransportError(err, method: .post))
        XCTAssertFalse(
            Transport.isRetryableTransportError(URLError(.networkConnectionLost), method: .post)
        )
        // Connect-phase failures where the request provably was not sent DO retry.
        XCTAssertTrue(Transport.isRetryableTransportError(URLError(.cannotConnectToHost), method: .post))
        XCTAssertTrue(Transport.isRetryableTransportError(URLError(.dnsLookupFailed), method: .post))
        // Idempotent methods retry on any transport error.
        XCTAssertTrue(Transport.isRetryableTransportError(err, method: .get))
        XCTAssertTrue(Transport.isRetryableTransportError(err, method: .delete))
    }

    func testPostIsRetriedOn429() async throws {
        enqueueJSON(["code": 20429, "message": "Too Many", "status": 429], status: 429, headers: ["Retry-After": "0"])
        enqueueJSON(callPayload(), status: 201)
        let c = try makeClient(maxRetries: 1)

        let call = try await c.calls.create(.init(to: "+14155550100", from: "+14155550101", url: "https://example.com/twiml"))
        XCTAssertEqual(call.sid?.hasPrefix("CA"), true)
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
    }

    func testGetIsRetriedOn503ThenSucceeds() async throws {
        enqueueRaw(Data("upstream busy".utf8), status: 503)
        enqueueJSON(callPayload())
        let c = try makeClient(maxRetries: 1)
        let call = try await c.calls.get("CA" + String(repeating: "4", count: 32))
        XCTAssertEqual(call.sid?.hasPrefix("CA"), true)
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
    }

    // MARK: - Retry-After parsing (seconds + HTTP-date + cap)

    func testRetryAfterSecondsIsHonoured() async throws {
        enqueueJSON(["code": 20429, "message": "Too Many", "status": 429], status: 429, headers: ["Retry-After": "1"])
        enqueueJSON(callPayload())
        let c = try makeClient(maxRetries: 1)
        _ = try await c.calls.get("CA" + String(repeating: "5", count: 32))
        XCTAssertEqual(MockResponses.shared.captured.count, 2, "429 with Retry-After: 1 must be retried")
    }

    func testRetryAfterHTTPDateIsHonoured() async throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        formatter.timeZone = TimeZone(identifier: "GMT")
        let soon = formatter.string(from: Date().addingTimeInterval(10))
        enqueueJSON(["code": 20429, "message": "Too Many", "status": 429], status: 429, headers: ["Retry-After": soon])
        enqueueJSON(callPayload())
        let c = try makeClient(maxRetries: 1)
        _ = try await c.calls.get("CA" + String(repeating: "6", count: 32))
        XCTAssertEqual(MockResponses.shared.captured.count, 2, "HTTP-date Retry-After within the cap must be retried")
    }

    func testRetryAfterOverCapRaisesRateLimitErrorImmediately() async throws {
        enqueueJSON(["code": 20429, "message": "Too Many", "status": 429], status: 429, headers: ["Retry-After": "3600"])
        let c = try makeClient(maxRetries: 2)

        do {
            _ = try await c.calls.get("CA" + String(repeating: "7", count: 32))
            XCTFail("expected throw")
        } catch let err as RateLimitError {
            XCTAssertEqual(err.retryAfter, 3600, "parsed Retry-After must be exposed on the error")
        } catch {
            XCTFail("wrong error type: \(error)")
        }
        XCTAssertEqual(MockResponses.shared.captured.count, 1, "no sleep, no retry beyond the cap")
    }

    func testRetryAfterHeaderParsing() {
        let resp = HTTPURLResponse(
            url: URL(string: "https://voiceml.voicetel.com/x")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "12"]
        )!
        XCTAssertEqual(Transport.parseRetryAfter(resp), 12)

        let respDate = HTTPURLResponse(
            url: URL(string: "https://voiceml.voicetel.com/x")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"]
        )!
        let parsed = Transport.parseRetryAfter(respDate)
        XCTAssertNotNil(parsed)
        XCTAssertFalse(abs((parsed ?? 0) - 0) > 3600 * 24 * 400, "HTTP-date far in the past parses to ~0, not a huge delay")

        let respJunk = HTTPURLResponse(
            url: URL(string: "https://voiceml.voicetel.com/x")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "later"]
        )!
        XCTAssertNil(Transport.parseRetryAfter(respJunk))
    }

    // MARK: - Cancellation

    func testCancellationIsRecognisedAndNeverRetried() {
        XCTAssertTrue(Transport.isCancellation(CancellationError()))
        XCTAssertTrue(Transport.isCancellation(URLError(.cancelled)))
        XCTAssertTrue(Transport.isCancellation(
            NSError(domain: "NSURLErrorDomain", code: URLError.cancelled.rawValue)
        ))
        XCTAssertFalse(Transport.isCancellation(URLError(.timedOut)))
    }

    func testTaskCancellationPropagatesToHTTPRequest() async throws {
        final class HangingProtocol: URLProtocol {
            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
            override func startLoading() {}
            override func stopLoading() {}
        }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [HangingProtocol.self]
        let session = URLSession(configuration: cfg)
        let c = try VoiceMLClient(
            accountSid: Self.accountSid,
            apiKey: Self.apiKey,
            maxRetries: 2,
            session: session
        )

        let worker = Task {
            try await c.calls.get("CA" + String(repeating: "8", count: 32))
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        worker.cancel()

        let start = Date()
        do {
            _ = try await worker.value
            XCTFail("expected cancellation")
        } catch is CancellationError {
            // Task cancellation may surface directly as CancellationError.
        } catch let error as URLError where error.code == .cancelled {
            // URLSession cancellation is propagated unchanged.
        } catch {
            XCTFail("expected unchanged cancellation, got \(error)")
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 15, "cancellation must not wait out the retry budget")
    }

    // MARK: - Pagination (C1)

    func testIterateSendsPageTokenFromNextPageUriAndTerminates() async throws {
        let sid1 = "CA" + String(repeating: "a", count: 31) + "1"
        let sid2 = "CA" + String(repeating: "a", count: 31) + "2"
        let sid3 = "CA" + String(repeating: "a", count: 31) + "3"

        enqueueJSON([
            "calls": [callPayload(sid: sid1), callPayload(sid: sid2)],
            "page": 0,
            "page_size": 2,
            "start": 0,
            "end": 1,
            "first_page_uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?PageSize=2",
            "next_page_uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?Page=1&PageSize=2&PageToken=PTabc99",
            "previous_page_uri": NSNull(),
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?PageSize=2",
        ])
        enqueueJSON([
            "calls": [callPayload(sid: sid3)],
            "page": 1,
            "page_size": 2,
            "start": 2,
            "end": 2,
            "first_page_uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?PageSize=2",
            "next_page_uri": NSNull(),
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?Page=1&PageSize=2&PageToken=PTabc99",
        ])

        let c = try makeClient()
        var collected: [Call] = []
        for try await call in c.calls.iterate(.init(pageSize: 2)) {
            collected.append(call)
        }

        XCTAssertEqual(collected.map(\.sid), [sid1, sid2, sid3])
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
        let second = MockResponses.shared.captured[1].url.absoluteString
        XCTAssertTrue(second.contains("PageToken=PTabc99"), second)
        XCTAssertTrue(second.contains("Page=1"), second)
    }

    func testIterateEarlyStopMakesNoFurtherRequests() async throws {
        // Page 0 is a FULL page with a next link — the server's "always link onward"
        // behaviour. The consumer reads one item and breaks; no page-1 request may fire.
        let sid1 = "CA" + String(repeating: "b", count: 31) + "1"
        let sid2 = "CA" + String(repeating: "b", count: 31) + "2"
        enqueueJSON([
            "calls": [callPayload(sid: sid1), callPayload(sid: sid2)],
            "page": 0,
            "page_size": 2,
            "next_page_uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?Page=1&PageSize=2&PageToken=PTxyz",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?PageSize=2",
        ])
        // If a second request fires, the mock would 500 (queue empty) — but assert the
        // count explicitly instead.
        let c = try makeClient()

        var seen = 0
        for try await _ in c.calls.iterate(.init(pageSize: 2)) {
            seen += 1
            break
        }
        XCTAssertEqual(seen, 1)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(MockResponses.shared.captured.count, 1, "lazy iteration must not pre-fetch page 1")
    }

    func testNextPageHelperFollowsPageToken() async throws {
        enqueueJSON([
            "calls": [],
            "page": 0,
            "page_size": 2,
            "next_page_uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?Page=1&PageSize=2&PageToken=PTnext7",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?PageSize=2",
        ])
        enqueueJSON([
            "calls": [callPayload()],
            "page": 1,
            "page_size": 2,
            "next_page_uri": NSNull(),
            "uri": "/x",
        ])
        let c = try makeClient()

        let first = try await c.calls.list(.init(pageSize: 2))
        let second = try await c.calls.nextPage(of: first)
        XCTAssertNotNil(second)
        XCTAssertEqual(second?.calls.count, 1)
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
        XCTAssertTrue(MockResponses.shared.captured[1].url.absoluteString.contains("PageToken=PTnext7"))
        // Terminal page → nil.
        let third = try await c.calls.nextPage(of: second!)
        XCTAssertNil(third)
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
    }

    func testFetchPageRefusesForeignHost() async throws {
        let c = try makeClient()
        let foreign = URL(string: "https://evil.example.com/2010-04-01/Accounts/\(Self.accountSid)/Calls.json")!
        do {
            let _: CallList = try await c.fetchPage(foreign)
            XCTFail("expected throw")
        } catch is ConfigurationError {
            // ok — refused before anything was sent
        } catch {
            XCTFail("wrong error type: \(error)")
        }
        XCTAssertEqual(MockResponses.shared.captured.count, 0)
    }

    // MARK: - Notifications / Events (HIGH)

    private func notificationPayload(sid: String = "NO" + String(repeating: "1", count: 32)) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "call_sid": "CA" + String(repeating: "2", count: 32),
            "api_version": NSNull(),
            "error_code": "11200",
            "log": "0",
            "message_date": "Mon, 19 May 2026 12:00:00 +0000",
            "message_text": "HTTP retrieval failure",
            "more_info": "https://www.twilio.com/docs/errors/11200",
            "request_method": NSNull(),
            "request_url": NSNull(),
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls/CA2/Notifications/\(sid).json",
            "date_created": "Mon, 19 May 2026 12:00:00 +0000",
            "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
        ]
    }

    func testNotificationsListDecodesSpecEnvelopeWithoutTotal() async throws {
        let payload = notificationPayload()
        enqueueJSON([
            "notifications": [payload],
            "page": 0,
            "page_size": 50,
            "start": 0,
            "end": 0,
            "first_page_uri": "/Notifications.json?PageSize=50",
            "next_page_uri": NSNull(),
            "uri": "/Notifications.json?PageSize=50",
        ])
        let c = try makeClient()

        let list = try await c.notifications.list()
        XCTAssertEqual(list.notifications.count, 1)
        XCTAssertEqual(list.notifications[0].errorCode, "11200")
        XCTAssertEqual(list.notifications[0].log, "0")
        XCTAssertNil(list.notifications[0].apiVersion)
        XCTAssertEqual(list.page, 0)
        XCTAssertNil(list.nextPageUri)
    }

    func testCallsListNotificationsAndEventsDecodeSpecEnvelope() async throws {
        let callSid = "CA" + String(repeating: "3", count: 32)
        enqueueJSON([
            "notifications": [],
            "page": 0,
            "page_size": 50,
            "uri": "/x",
        ])
        enqueueJSON([
            "events": [[
                "request": ["method": "POST", "parameters": ["To": "+14155550100"], "url": "/Calls.json"],
                "response": [
                    "content_type": "application/json",
                    "date_created": "Mon, 19 May 2026 12:00:00 +0000",
                    "request_duration": 12,
                    "response_body": "{\"sid\": \"CA…\"}",
                    "response_code": 201,
                ],
            ]],
            "page": 0,
            "page_size": 50,
            "uri": "/x",
        ])
        let c = try makeClient()

        let notifications = try await c.calls.listNotifications(callSid: callSid)
        XCTAssertEqual(notifications.notifications.count, 0)
        let events = try await c.calls.listEvents(callSid: callSid)
        XCTAssertEqual(events.events.count, 1)
        XCTAssertEqual(events.events[0].request?.method, "POST")
        XCTAssertEqual(events.events[0].request?.parameters?["To"], "+14155550100")
        XCTAssertEqual(events.events[0].response?.responseCode, 201)
        XCTAssertEqual(events.events[0].response?.requestDuration, 12)
    }

    func testGetNotificationReturnsTypedModel() async throws {
        let sid = "NO" + String(repeating: "4", count: 32)
        enqueueJSON(notificationPayload(sid: sid))
        let c = try makeClient()

        let n = try await c.calls.getNotification(callSid: "CA" + String(repeating: "5", count: 32), notificationSid: sid)
        XCTAssertEqual(n.sid, sid)
        XCTAssertEqual(n.moreInfo, "https://www.twilio.com/docs/errors/11200")
    }

    // MARK: - Diagnostics (HIGH)

    func testHealthDecodesOkOnlyPayloadThroughTransport() async throws {
        enqueueJSON(["ok": true], headers: ["Content-Type": "application/json"])
        let c = try makeClient()

        let health = try await c.diagnostics.health()
        XCTAssertEqual(health.ok, true)
        XCTAssertNil(health.warnings)

        let captured = MockResponses.shared.captured
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured[0].url.absoluteString, "https://voiceml.voicetel.com/health")
        XCTAssertNil(captured[0].headers["Authorization"], "health is unauthenticated")
    }

    func testHealth503RaisesServerError() async throws {
        enqueueJSON(["ok": false, "failures": [["check": "memdb", "detail": "down"]]], status: 503)
        let c = try makeClient(maxRetries: 0)

        do {
            _ = try await c.diagnostics.health()
            XCTFail("expected throw")
        } catch is ServerError {
            // ok
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testOpenapiYamlAndYmlRouteThroughTransport() async throws {
        enqueueRaw(Data("openapi: 3.0.0".utf8), status: 200, headers: ["Content-Type": "text/yaml"])
        enqueueRaw(Data("openapi: 3.0.0".utf8), status: 200, headers: ["Content-Type": "text/yaml"])
        let c = try makeClient()

        let yaml = try await c.diagnostics.openapiYaml()
        XCTAssertEqual(String(decoding: yaml, as: UTF8.self), "openapi: 3.0.0")
        let yml = try await c.diagnostics.openapiYml()
        XCTAssertEqual(String(decoding: yml, as: UTF8.self), "openapi: 3.0.0")

        let urls = MockResponses.shared.captured.map(\.url.path)
        XCTAssertEqual(urls, ["/openapi.yaml", "/openapi.yml"])
        for req in MockResponses.shared.captured {
            XCTAssertNil(req.headers["Authorization"], "openapi endpoints are unauthenticated")
        }
    }

    func testDiagnosticsWorkWithoutCredentials() async throws {
        enqueueJSON(["ok": true])
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: cfg)

        let health = try await DiagnosticsResource.health(
            baseURL: URL(string: "https://voiceml.voicetel.com")!,
            session: session
        )
        XCTAssertEqual(health.ok, true)

        let captured = MockResponses.shared.captured
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured[0].url.path, "/health")
        XCTAssertNil(captured[0].headers["Authorization"])
    }

    // MARK: - Nullability / open enums (C9)

    func testUnknownEnumNullAndExtraFieldsDecode() throws {
        let json = """
        {
          "sid": "CA\(String(repeating: "9", count: 32))",
          "account_sid": "\(Self.accountSid)",
          "api_version": null,
          "status": "warp-speed",
          "direction": "",
          "some_future_field": {"nested": [1, 2, 3]},
          "date_created": "Mon, 19 May 2026 12:00:00 +0000",
          "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
          "uri": "/x"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let call = try decoder.decode(Call.self, from: json)
        XCTAssertEqual(call.status?.rawValue, "warp-speed", "unknown enum value must not fail decoding")
        XCTAssertEqual(call.direction?.rawValue, "", "empty direction must not fail decoding")
        XCTAssertNil(call.apiVersion)
    }

    func testConferenceStatusUnknownValueDecodes() throws {
        let json = """
        {"sid": "CF1", "account_sid": "AC0", "status": "paused-forever"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let conf = try decoder.decode(Conference.self, from: json)
        XCTAssertEqual(conf.status?.rawValue, "paused-forever")
    }

    // MARK: - Error envelope

    func testErrorCodeNullBecomesNilAndStatusSurfaced() async throws {
        enqueueJSON([
            "code": NSNull(),
            "message": "Boom",
            "more_info": NSNull(),
            "status": 400,
        ], status: 400)
        let c = try makeClient(maxRetries: 0)

        do {
            _ = try await c.calls.get("CA" + String(repeating: "a", count: 32))
            XCTFail("expected throw")
        } catch let err as BadRequestError {
            XCTAssertNil(err.code, "NSNull code must decode to nil, not \"<null>\"")
            XCTAssertEqual(err.responseStatus, 400)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testDecodeFailureOn2xxRaisesDecodingFailedError() async throws {
        enqueueRaw(Data("this is not json".utf8), status: 200, headers: ["Content-Type": "application/json"])
        let c = try makeClient(maxRetries: 0)

        do {
            _ = try await c.calls.get("CA" + String(repeating: "b", count: 32))
            XCTFail("expected throw")
        } catch let err as DecodingFailedError {
            XCTAssertEqual(err.statusCode, 200)
            XCTAssertTrue(err.message.contains("could not decode"), err.message)
            XCTAssertNotNil(err.cause)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    // MARK: - Path encoding (C3)

    func testPathSegmentsArePercentEncoded() async throws {
        enqueueJSON(callPayload())
        let c = try makeClient()

        _ = try await c.calls.get("a b/c%d?e#f")
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("/Calls/a%20b%2Fc%25d%3Fe%23f.json"), url)
    }

    func testEmptyAndDotPathSegmentsAreRejected() async throws {
        let c = try makeClient()
        do {
            _ = try await c.calls.get("")
            XCTFail("expected throw")
        } catch is ConfigurationError {
            // ok
        } catch {
            XCTFail("wrong error type: \(error)")
        }
        do {
            _ = try await c.calls.get("..")
            XCTFail("expected throw")
        } catch is ConfigurationError {
            // ok
        } catch {
            XCTFail("wrong error type: \(error)")
        }
        XCTAssertEqual(MockResponses.shared.captured.count, 0)
    }

    func testRoutesV2FreeTextSegmentIsEncoded() async throws {
        enqueueJSON(["sid": "QQ" + String(repeating: "1", count: 32), "sip_domain": "a/b?c"])
        let c = try makeClient()
        _ = try await c.routesV2.sipDomains.fetch(domainName: "a/b?c")
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("/v2/SipDomains/a%2Fb%3Fc"), url)
    }

    func testTwilioCurrentPathGainsJSONSuffix() async throws {
        enqueueJSON([
            "sid": "RE" + String(repeating: "1", count: 32),
            "account_sid": Self.accountSid,
            "call_sid": "CA" + String(repeating: "1", count: 32),
            "status": "completed",
        ])
        let c = try makeClient()
        _ = try await c.recordings.get("Twilio.CURRENT")
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.hasSuffix("/Recordings/Twilio.CURRENT.json"), url)
    }

    // MARK: - Form/query wire bytes

    func testCreateCallFormBodyRawWireBytes() async throws {
        enqueueJSON(callPayload(), status: 201)
        let c = try makeClient()

        _ = try await c.calls.create(.init(
            to: "+14155550100 555&x=y",
            from: "+14155550101",
            url: "https://example.com/twiml?a=1&b=2"
        ))
        let raw = String(decoding: MockResponses.shared.captured[0].body, as: UTF8.self)
        XCTAssertTrue(raw.contains("To=%2B14155550100%20555%26x%3Dy"), raw)
        XCTAssertTrue(raw.contains("From=%2B14155550101"), raw)
        XCTAssertTrue(raw.contains("Url=https%3A%2F%2Fexample.com%2Ftwiml%3Fa%3D1%26b%3D2"), raw)
    }

    // MARK: - Messages (C8)

    func testMessagesCreateMMSRepeatedMediaUrlAndNewFields() async throws {
        var payload: [String: Any] = [
            "sid": "MM" + String(repeating: "0", count: 32),
            "account_sid": Self.accountSid,
            "api_version": "2010-04-01",
            "to": "+14155550100",
            "from": "+14155550101",
            "body": NSNull(),
            "status": "sent",
            "num_segments": "1",
            "num_media": "2",
            "direction": "outbound-api",
            "date_created": "Mon, 19 May 2026 12:00:00 +0000",
            "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
            "uri": "/x",
        ]
        payload["price"] = NSNull()
        payload["price_unit"] = NSNull()
        enqueueJSON(payload, status: 201)
        let c = try makeClient()

        _ = try await c.messages.create(.init(
            to: "+14155550100",
            from: "+14155550101",
            mediaUrl: ["https://example.com/a.png", "https://example.com/b.png"],
            validityPeriod: 1440,
            statusCallback: "https://example.com/dlr",
            statusCallbackMethod: .post
        ))

        let raw = String(decoding: MockResponses.shared.captured[0].body, as: UTF8.self)
        XCTAssertTrue(raw.contains("MediaUrl=https%3A%2F%2Fexample.com%2Fa.png&MediaUrl=https%3A%2F%2Fexample.com%2Fb.png"), raw)
        XCTAssertTrue(raw.contains("ValidityPeriod=1440"), raw)
        XCTAssertTrue(raw.contains("StatusCallbackMethod=POST"), raw)
        XCTAssertFalse(raw.contains("Body="), "no Body key when only media is sent")
    }

    func testMessagesCreateRequiresBodyOrMediaUrl() async throws {
        let c = try makeClient()
        do {
            _ = try await c.messages.create(.init(to: "+14155550100"))
            XCTFail("expected throw")
        } catch is ConfigurationError {
            // ok
        } catch {
            XCTFail("wrong error type: \(error)")
        }
        XCTAssertEqual(MockResponses.shared.captured.count, 0, "no request may be sent")
    }

    // MARK: - IncomingPhoneNumbers Sms* fields (C8)

    func testIncomingPhoneNumbersCreateSendsSmsFields() async throws {
        enqueueJSON([
            "sid": "PN" + String(repeating: "6", count: 32),
            "account_sid": Self.accountSid,
            "phone_number": "+14155550100",
            "api_version": "2010-04-01",
            "uri": "/x",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.incomingPhoneNumbers.create(.init(
            phoneNumber: "+14155550100",
            smsUrl: "https://example.com/sms",
            smsMethod: .post,
            smsFallbackUrl: "https://example.com/sms-fb",
            smsFallbackMethod: .get,
            smsApplicationSid: "AP" + String(repeating: "7", count: 32)
        ))

        let raw = String(decoding: MockResponses.shared.captured[0].body, as: UTF8.self)
        XCTAssertTrue(raw.contains("SmsUrl=https%3A%2F%2Fexample.com%2Fsms&"), raw)
        XCTAssertTrue(raw.contains("SmsMethod=POST"), raw)
        XCTAssertTrue(raw.contains("SmsFallbackUrl=https%3A%2F%2Fexample.com%2Fsms-fb"), raw)
        XCTAssertTrue(raw.contains("SmsFallbackMethod=GET"), raw)
        XCTAssertTrue(raw.contains("SmsApplicationSid=AP77777777777777777777777777777777"), raw)
    }

    func testIncomingPhoneNumbersListSendsNewFilters() async throws {
        enqueueJSON(["incoming_phone_numbers": [], "page": 0, "page_size": 50, "uri": "/x"])
        let c = try makeClient()

        _ = try await c.incomingPhoneNumbers.list(.init(
            friendlyName: "main-line", beta: false, origin: "hosted"
        ))

        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("FriendlyName=main-line"), url)
        XCTAssertTrue(url.contains("Beta=false"), url)
        XCTAssertTrue(url.contains("Origin=hosted"), url)
    }

    func testTypedIncomingPhoneNumbersCreateSendsOnlySpecFields() async throws {
        enqueueJSON([
            "sid": "PN" + String(repeating: "8", count: 32),
            "account_sid": Self.accountSid,
            "phone_number": "+14155550100",
            "api_version": "2010-04-01",
            "uri": "/x",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.incomingPhoneNumbers.createTollFree(.init(
            phoneNumber: "+14155550100",
            voiceUrl: "https://example.com/twiml",
            voiceMethod: .post
        ))

        let raw = String(decoding: MockResponses.shared.captured[0].body, as: UTF8.self)
        XCTAssertEqual(
            raw,
            "PhoneNumber=%2B14155550100&VoiceUrl=https%3A%2F%2Fexample.com%2Ftwiml&VoiceMethod=POST",
            "typed creates declare exactly PhoneNumber/VoiceUrl/VoiceMethod"
        )
    }

    // MARK: - Applications callbacks (C8)

    func testApplicationsCreateSendsMessageAndSmsCallbacks() async throws {
        enqueueJSON([
            "sid": "AP" + String(repeating: "9", count: 32),
            "account_sid": Self.accountSid,
            "friendly_name": "ivr",
            "api_version": "2010-04-01",
            "uri": "/x",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.applications.create(.init(
            friendlyName: "ivr",
            messageStatusCallback: "https://example.com/dlr",
            smsStatusCallback: "https://example.com/dlr-legacy",
            smsUrl: "https://example.com/sms",
            smsMethod: .post,
            smsFallbackUrl: "https://example.com/sms-fb",
            smsFallbackMethod: .get,
            publicApplicationConnectEnabled: true
        ))

        let raw = String(decoding: MockResponses.shared.captured[0].body, as: UTF8.self)
        XCTAssertTrue(raw.contains("MessageStatusCallback=https%3A%2F%2Fexample.com%2Fdlr"), raw)
        XCTAssertTrue(raw.contains("SmsStatusCallback=https%3A%2F%2Fexample.com%2Fdlr-legacy"), raw)
        XCTAssertTrue(raw.contains("SmsUrl=https%3A%2F%2Fexample.com%2Fsms"), raw)
        XCTAssertTrue(raw.contains("SmsMethod=POST"), raw)
        XCTAssertTrue(raw.contains("SmsFallbackUrl=https%3A%2F%2Fexample.com%2Fsms-fb"), raw)
        XCTAssertTrue(raw.contains("SmsFallbackMethod=GET"), raw)
        XCTAssertTrue(raw.contains("PublicApplicationConnectEnabled=true"), raw)
    }

    func testApplicationsUpdateSendsSmsAndConnectFields() async throws {
        let sid = "AP" + String(repeating: "c", count: 32)
        enqueueJSON([
            "sid": sid,
            "account_sid": Self.accountSid,
            "friendly_name": "ivr2",
            "api_version": "2010-04-01",
            "uri": "/x",
        ])
        let c = try makeClient()

        _ = try await c.applications.update(applicationSid: sid, body: .init(
            smsUrl: "https://example.com/sms2",
            smsMethod: .get,
            smsFallbackUrl: "https://example.com/sms2-fb",
            smsFallbackMethod: .post,
            publicApplicationConnectEnabled: false
        ))

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.method, "POST")
        XCTAssertEqual(req.url.path, "/2010-04-01/Accounts/\(Self.accountSid)/Applications/\(sid).json")
        let raw = String(decoding: req.body, as: UTF8.self)
        XCTAssertTrue(raw.contains("SmsUrl=https%3A%2F%2Fexample.com%2Fsms2"), raw)
        XCTAssertTrue(raw.contains("SmsMethod=GET"), raw)
        XCTAssertTrue(raw.contains("SmsFallbackUrl=https%3A%2F%2Fexample.com%2Fsms2-fb"), raw)
        XCTAssertTrue(raw.contains("SmsFallbackMethod=POST"), raw)
        XCTAssertTrue(raw.contains("PublicApplicationConnectEnabled=false"), raw)
    }

    // MARK: - Recording request fields (C8)

    func testStartRecordingSendsRecordingTrack() async throws {
        enqueueJSON([
            "sid": "RE" + String(repeating: "a", count: 32),
            "account_sid": Self.accountSid,
            "call_sid": "CA" + String(repeating: "a", count: 32),
            "status": "in-progress",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.calls.startRecording(
            callSid: "CA" + String(repeating: "a", count: 32),
            body: .init(recordingTrack: .inbound)
        )

        let raw = String(decoding: MockResponses.shared.captured[0].body, as: UTF8.self)
        XCTAssertTrue(raw.contains("RecordingTrack=inbound"), raw)
    }

    func testUpdateRecordingSendsPauseBehavior() async throws {
        enqueueJSON([
            "sid": "RE" + String(repeating: "b", count: 32),
            "account_sid": Self.accountSid,
            "call_sid": "CA" + String(repeating: "b", count: 32),
            "status": "paused",
        ])
        let c = try makeClient()

        _ = try await c.calls.updateRecording(
            callSid: "CA" + String(repeating: "b", count: 32),
            recordingSid: "RE" + String(repeating: "b", count: 32),
            body: .init(status: .paused, pauseBehavior: .skip)
        )

        let raw = String(decoding: MockResponses.shared.captured[0].body, as: UTF8.self)
        XCTAssertTrue(raw.contains("Status=paused"), raw)
        XCTAssertTrue(raw.contains("PauseBehavior=skip"), raw)
    }

    func testConferenceUpdateRecordingSendsPauseBehavior() async throws {
        enqueueJSON([
            "sid": "RE" + String(repeating: "e", count: 32),
            "account_sid": Self.accountSid,
            "conference_sid": "CF" + String(repeating: "e", count: 32),
            "status": "paused",
        ])
        let c = try makeClient()

        _ = try await c.conferences.updateRecording(
            conferenceSid: "CF" + String(repeating: "e", count: 32),
            recordingSid: "RE" + String(repeating: "e", count: 32),
            body: .init(status: .paused, pauseBehavior: .skip)
        )

        let raw = String(decoding: MockResponses.shared.captured[0].body, as: UTF8.self)
        XCTAssertTrue(raw.contains("Status=paused"), raw)
        XCTAssertTrue(raw.contains("PauseBehavior=skip"), raw)
    }

    func testStartTranscriptionSendsStatusCallbackUrlAndNewFields() async throws {
        enqueueJSON([
            "sid": "GT" + String(repeating: "a", count: 32),
            "account_sid": Self.accountSid,
            "call_sid": "CA" + String(repeating: "a", count: 32),
            "status": "in-progress",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.calls.startTranscription(
            callSid: "CA" + String(repeating: "a", count: 32),
            body: .init(
                speechModel: "nova-3",
                enableAutomaticPunctuation: true,
                intelligenceService: "voice_intelligence",
                statusCallbackUrl: "https://example.com/tr-events",
                statusCallbackMethod: "POST",
                statusCallbackEvents: "completed"
            )
        )

        let raw = String(decoding: MockResponses.shared.captured[0].body, as: UTF8.self)
        XCTAssertTrue(raw.contains("SpeechModel=nova-3"), raw)
        XCTAssertTrue(raw.contains("EnableAutomaticPunctuation=true"), raw)
        XCTAssertTrue(raw.contains("IntelligenceService=voice_intelligence"), raw)
        XCTAssertTrue(raw.contains("StatusCallbackUrl=https%3A%2F%2Fexample.com%2Ftr-events"), raw)
        XCTAssertTrue(raw.contains("StatusCallbackMethod=POST"), raw)
        XCTAssertTrue(raw.contains("StatusCallbackEvents=completed"), raw)
        // The pre-0.9.4 wire key must not reappear.
        XCTAssertFalse(raw.contains("StatusCallback="), raw)
    }

    func testCallsListRecordingsSendsOnlyScopedFilters() async throws {
        enqueueJSON(["recordings": [], "page": 0, "page_size": 50, "uri": "/x"])
        let c = try makeClient()

        _ = try await c.calls.listRecordings(callSid: "CA" + String(repeating: "c", count: 32))

        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertFalse(url.contains("CallSid="), url)
        XCTAssertFalse(url.contains("ConferenceSid="), url)
        XCTAssertFalse(url.contains("IncludeSoftDeleted="), url)
    }

    func testConferencesStartRecordingPathAndBody() async throws {
        enqueueJSON([
            "sid": "RE" + String(repeating: "d", count: 32),
            "account_sid": Self.accountSid,
            "call_sid": "CA" + String(repeating: "d", count: 32),
            "conference_sid": "CF" + String(repeating: "d", count: 32),
            "status": "in-progress",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.conferences.startRecording(
            conferenceSid: "CF" + String(repeating: "d", count: 32),
            body: .init(recordingStatusCallback: "https://example.com/rc")
        )

        let req = MockResponses.shared.captured[0]
        XCTAssertEqual(req.url.path, "/2010-04-01/Accounts/\(Self.accountSid)/Conferences/CF\(String(repeating: "d", count: 32))/Recordings.json")
        let raw = String(decoding: req.body, as: UTF8.self)
        XCTAssertTrue(raw.contains("RecordingStatusCallback=https%3A%2F%2Fexample.com%2Frc"), raw)
        XCTAssertFalse(raw.contains("RecordingTrack="), raw)
    }

    // MARK: - SIP lists FriendlyName (C8)

    func testSipDomainListSendsFriendlyNameFilter() async throws {
        enqueueJSON(["domains": [], "page": 0, "page_size": 50, "uri": "/x"])
        let c = try makeClient()

        _ = try await c.sip.domains.list(.init(friendlyName: "sip.example.com"))
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("FriendlyName=sip.example.com"), url)
    }

    // MARK: - Assistants list params (C8)

    func testAssistantsListSendsPageSizeOnly() async throws {
        enqueueJSON(["assistants": [], "meta": ["page": 0, "page_size": 50]])
        let c = try makeClient()

        _ = try await c.assistantsV1.assistants.list(.init(pageSize: 50))
        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("PageSize=50"), url)
        XCTAssertFalse(url.contains("Page="), url)
        XCTAssertFalse(url.contains("PageToken="), url)
    }

    // MARK: - Secrets redaction (C11)

    private final class DumpCapture: TextOutputStream {
        var text = ""
        func write(_ string: String) { text += string }
    }

    func testClientOptionsRedactApiKeyInMirrorAndDump() {
        let options = ClientOptions(accountSid: Self.accountSid, apiKey: "topsecret-key-9876")
        let mirrorChildren = Mirror(reflecting: options).children
        let secretValues = mirrorChildren.filter { "\($0.value)".contains("topsecret-key-9876") }
        XCTAssertTrue(secretValues.isEmpty, "Mirror must not expose the api key")
        let apiKeyChild = mirrorChildren.first { $0.label == "apiKey" }
        XCTAssertEqual(apiKeyChild.map { "\($0.value)" }, "<redacted>")

        var capture = DumpCapture()
        dump(options, to: &capture)
        XCTAssertFalse(capture.text.contains("topsecret-key-9876"), "dump() must not expose the api key")
    }

    func testTransportRedactsApiKeyInMirrorAndDump() throws {
        let c = try makeClient()
        let mirrorChildren = Mirror(reflecting: c.transport).children
        XCTAssertTrue(mirrorChildren.allSatisfy { !"\($0.value)".contains(Self.apiKey) })
        let apiKeyChild = mirrorChildren.first { $0.label == "apiKey" }
        XCTAssertEqual(apiKeyChild.map { "\($0.value)" }, "<redacted>")
        XCTAssertFalse(c.transport.debugDescription.contains(Self.apiKey))

        var capture = DumpCapture()
        dump(c.transport, to: &capture)
        XCTAssertFalse(capture.text.contains(Self.apiKey), "dump() must not expose the api key")
    }

    // MARK: - Webhook signature vectors (C10)

    func testSignatureVectors() {
        let key = "test-api-key-0123456789"
        let v1Params: [(String, String)] = [
            ("CallSid", "CA0123456789abcdef0123456789abcdef"),
            ("From", "+14155550100"),
            ("To", "+14155550101"),
            ("Digits", "1234"),
            ("AccountSid", "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"),
        ]

        // V1 (POST)
        XCTAssertTrue(RequestValidator.validate(
            apiKey: key,
            url: "https://example.com/voice/answer?case=1",
            params: v1Params,
            signature: "RweoLyWqNC7H8+MLXPb7EPz18OI="
        ))
        // Port normalisation: the same signature validates against the :443 URL…
        XCTAssertTrue(RequestValidator.validate(
            apiKey: key,
            url: "https://example.com:443/voice/answer?case=1",
            params: v1Params,
            signature: "RweoLyWqNC7H8+MLXPb7EPz18OI="
        ))
        // …and the signature computed over the :443 URL validates against the port-less URL.
        XCTAssertTrue(RequestValidator.validate(
            apiKey: key,
            url: "https://example.com/voice/answer?case=1",
            params: v1Params,
            signature: "xE0r2wPa6d1ktQeCFpPyINmTNYg="
        ))

        // V3 (repeated keys, received order preserved)
        XCTAssertTrue(RequestValidator.validate(
            apiKey: key,
            url: "https://example.com/hook",
            params: [("To", "+14155550101"), ("Event", "answered"), ("Event", "initiated")],
            signature: "jCnpBgyg45aZYwUie5fmq4EYUic="
        ))

        // V4 (GET — URL only)
        XCTAssertTrue(RequestValidator.validate(
            apiKey: key,
            url: "https://example.com/voice/answer?CallSid=CA0123456789abcdef0123456789abcdef&From=%2B14155550100",
            params: [],
            signature: "9I4odWBHhF7TMIkIrNtPEPjD9fU="
        ))

        // Negative: tampered value
        XCTAssertFalse(RequestValidator.validate(
            apiKey: key,
            url: "https://example.com/voice/answer?case=1",
            params: v1Params.map { $0.0 == "Digits" ? ($0.0, "9999") : $0 },
            signature: "RweoLyWqNC7H8+MLXPb7EPz18OI="
        ))
        // Negative: wrong key
        XCTAssertFalse(RequestValidator.validate(
            apiKey: "wrong-key-0000000000000000",
            url: "https://example.com/voice/answer?case=1",
            params: v1Params,
            signature: "RweoLyWqNC7H8+MLXPb7EPz18OI="
        ))
    }

    func testSignatureHelperComputesExpectedBase64() {
        let sig = RequestValidator.signature(
            apiKey: "test-api-key-0123456789",
            url: "https://example.com/voice/answer?case=1",
            params: [
                ("CallSid", "CA0123456789abcdef0123456789abcdef"),
                ("From", "+14155550100"),
                ("To", "+14155550101"),
                ("Digits", "1234"),
                ("AccountSid", "ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"),
            ]
        )
        XCTAssertEqual(sig, "RweoLyWqNC7H8+MLXPb7EPz18OI=")
    }

    // MARK: - New resources (C6)

    func testAccountsFetchUpdateBalance() async throws {
        enqueueJSON([
            "sid": Self.accountSid,
            "owner_account_sid": Self.accountSid,
            "friendly_name": "VoiceML account",
            "status": "active",
            "type": "Full",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid).json",
        ])
        enqueueJSON([
            "sid": Self.accountSid,
            "owner_account_sid": Self.accountSid,
            "friendly_name": "renamed",
            "status": "active",
            "type": "Full",
            "uri": "/x",
        ])
        enqueueJSON([
            "account_sid": Self.accountSid,
            "balance": "0",
            "currency": "USD",
        ])
        let c = try makeClient()

        let account = try await c.accounts.fetch(sid: Self.accountSid)
        XCTAssertEqual(account.friendlyName, "VoiceML account")
        XCTAssertEqual(MockResponses.shared.captured[0].url.path, "/2010-04-01/Accounts/\(Self.accountSid).json")

        let updated = try await c.accounts.update(sid: Self.accountSid, .init(friendlyName: "renamed"))
        XCTAssertEqual(updated.friendlyName, "renamed")
        XCTAssertEqual(MockResponses.shared.captured[1].method, "POST")
        XCTAssertTrue(String(decoding: MockResponses.shared.captured[1].body, as: UTF8.self).contains("FriendlyName=renamed"))

        let balance = try await c.accounts.balance()
        XCTAssertEqual(balance.currency, "USD")
        XCTAssertEqual(MockResponses.shared.captured[2].url.path, "/2010-04-01/Accounts/\(Self.accountSid)/Balance.json")
    }

    func testAccountsUpdateConflictMapsToConflictError() async throws {
        enqueueJSON(["code": 20409, "message": "Account modified concurrently", "status": 409], status: 409)
        let c = try makeClient(maxRetries: 0)
        do {
            _ = try await c.accounts.update(sid: Self.accountSid, .init(friendlyName: "x"))
            XCTFail("expected throw")
        } catch is ConflictError {
            // ok — optimistic-lock conflict
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testOutgoingCallerIdsCRUD() async throws {
        enqueueJSON(["outgoing_caller_ids": [], "page": 0, "page_size": 50, "uri": "/x"])
        enqueueJSON([
            "account_sid": Self.accountSid,
            "call_sid": "CA" + String(repeating: "e", count: 32),
            "phone_number": "+14155550102",
            "validation_code": "123456",
        ])
        enqueueJSON([
            "sid": "PN" + String(repeating: "f", count: 32),
            "account_sid": Self.accountSid,
            "phone_number": "+14155550102",
            "uri": "/x",
        ])
        enqueueRaw(Data(), status: 204)
        let c = try makeClient()

        _ = try await c.outgoingCallerIds.list(.init(phoneNumber: "+14155550102"))
        XCTAssertEqual(MockResponses.shared.captured[0].url.path, "/2010-04-01/Accounts/\(Self.accountSid)/OutgoingCallerIds.json")
        XCTAssertTrue(MockResponses.shared.captured[0].url.absoluteString.contains("PhoneNumber=%2B14155550102"))

        let validation = try await c.outgoingCallerIds.create(.init(
            phoneNumber: "+14155550102",
            friendlyName: "office",
            callDelay: 5,
            extension: "123",
            statusCallback: "https://example.com/validation-status",
            statusCallbackMethod: .post
        ))
        XCTAssertEqual(validation.validationCode, "123456")

        let createRaw = String(decoding: MockResponses.shared.captured[1].body, as: UTF8.self)
        XCTAssertTrue(createRaw.contains("CallDelay=5"), createRaw)
        XCTAssertTrue(createRaw.contains("Extension=123"), createRaw)
        XCTAssertTrue(createRaw.contains("StatusCallback=https%3A%2F%2Fexample.com%2Fvalidation-status"), createRaw)
        XCTAssertTrue(createRaw.contains("StatusCallbackMethod=POST"), createRaw)

        let fetched = try await c.outgoingCallerIds.fetch(sid: "PN" + String(repeating: "f", count: 32))
        XCTAssertEqual(fetched.phoneNumber, "+14155550102")

        try await c.outgoingCallerIds.delete(sid: "PN" + String(repeating: "f", count: 32))
        XCTAssertEqual(MockResponses.shared.captured[3].method, "DELETE")
    }

    func testMediaResourceListFetchDelete() async throws {
        let messageSid = "SM" + String(repeating: "1", count: 32)
        enqueueJSON(["media_list": [], "page": 0, "page_size": 50, "uri": "/x"])
        enqueueJSON([
            "sid": "ME" + String(repeating: "2", count: 32),
            "account_sid": Self.accountSid,
            "parent_sid": messageSid,
            "content_type": "image/png",
            "date_created": "Mon, 19 May 2026 12:00:00 +0000",
            "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
            "uri": "/x",
        ])
        enqueueRaw(Data(), status: 204)
        let c = try makeClient()

        _ = try await c.messages.media(messageSid: messageSid).list()
        XCTAssertEqual(
            MockResponses.shared.captured[0].url.path,
            "/2010-04-01/Accounts/\(Self.accountSid)/Messages/\(messageSid)/Media.json"
        )

        let media = try await c.messages.media(messageSid: messageSid).fetch(sid: "ME" + String(repeating: "2", count: 32))
        XCTAssertEqual(media.contentType, "image/png")

        try await c.messages.media(messageSid: messageSid).delete(sid: "ME" + String(repeating: "2", count: 32))
        XCTAssertEqual(MockResponses.shared.captured[2].method, "DELETE")
    }

    func testExportsListAndDownload() async throws {
        enqueueJSON([
            "account_sid": Self.accountSid,
            "exports": [["date": "2026-10-16", "size": 1024, "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Exports/2026-10-16"]],
            "uri": "/x",
        ])
        enqueueRaw(Data(), status: 302, headers: ["Location": "https://s3.example.com/exports/2026-10-16?sig=1"])
        enqueueRaw(Data("CSV,DATA".utf8), status: 200, headers: ["Content-Type": "text/csv"])
        let c = try makeClient()

        let list = try await c.exports.list()
        XCTAssertEqual(list.exports?.count, 1)
        XCTAssertEqual(MockResponses.shared.captured[0].url.path, "/2010-04-01/Accounts/\(Self.accountSid)/Exports.json")

        let (data, _) = try await c.exports.download(date: "2026-10-16")
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "CSV,DATA")
        // The download path itself must NOT gain a .json suffix.
        XCTAssertEqual(MockResponses.shared.captured[1].url.path, "/2010-04-01/Accounts/\(Self.accountSid)/Exports/2026-10-16")
        XCTAssertEqual(MockResponses.shared.captured[1].headers["Authorization"], authHeader())
        // The redirect leg is unauthenticated.
        XCTAssertEqual(MockResponses.shared.captured[2].url.host, "s3.example.com")
        XCTAssertNil(MockResponses.shared.captured[2].headers["Authorization"])
    }

    func testAccountTranscriptionsAndRecordingTranscriptions() async throws {
        let tr: [String: Any] = [
            "sid": "TR" + String(repeating: "3", count: 32),
            "account_sid": Self.accountSid,
            "status": "completed",
            "recording_sid": "RE" + String(repeating: "3", count: 32),
            "duration": "12",
            "transcription_text": "hello there",
            "type": "fast",
            "price": "-0.05",
            "price_unit": "usd",
            "api_version": "2010-04-01",
            "uri": "/x",
            "date_created": "Mon, 19 May 2026 12:00:00 +0000",
            "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
        ]
        enqueueJSON(["transcriptions": [tr], "page": 0, "page_size": 50, "uri": "/x"])
        enqueueJSON(tr)
        enqueueRaw(Data(), status: 204)
        let c = try makeClient()

        let list = try await c.transcriptions.list()
        XCTAssertEqual(list.transcriptions.count, 1)
        XCTAssertEqual(MockResponses.shared.captured[0].url.path, "/2010-04-01/Accounts/\(Self.accountSid)/Transcriptions.json")

        let fetched = try await c.transcriptions.fetch(sid: "TR" + String(repeating: "3", count: 32))
        XCTAssertEqual(fetched.transcriptionText, "hello there")

        try await c.transcriptions.delete(sid: "TR" + String(repeating: "3", count: 32))
        XCTAssertEqual(MockResponses.shared.captured[2].method, "DELETE")

        MockResponses.shared.reset()
        enqueueJSON(["transcriptions": [tr], "page": 0, "page_size": 50, "uri": "/x"])
        let scoped = try await c.recordings.transcriptions(recordingSid: "RE" + String(repeating: "3", count: 32)).list()
        XCTAssertEqual(scoped.transcriptions.count, 1)
        XCTAssertEqual(
            MockResponses.shared.captured[0].url.path,
            "/2010-04-01/Accounts/\(Self.accountSid)/Recordings/RE\(String(repeating: "3", count: 32))/Transcriptions.json"
        )
    }

    func testUsageRecordsWindows() async throws {
        let record: [String: Any] = [
            "account_sid": Self.accountSid,
            "api_version": "2010-04-01",
            "as_of": "2026-10-17T00:00:00+00:00",
            "category": "calls",
            "count": "3",
            "count_unit": "calls",
            "description": "Total calls",
            "end_date": "2026-10-16",
            "price": "0.0525",
            "price_unit": "usd",
            "start_date": "2026-10-16",
            "subresource_uris": ["today": "/Usage/Records/Today.json"],
            "uri": "/x",
            "usage": "12",
            "usage_unit": "minutes",
        ]
        enqueueJSON(["usage_records": [record], "page": 0, "page_size": 50, "uri": "/x"])
        enqueueJSON(["usage_records": [record], "page": 0, "page_size": 50, "uri": "/x"])
        let c = try makeClient()

        let all = try await c.usageRecords.list(.init(category: "calls", includeSubaccounts: true))
        XCTAssertEqual(all.usageRecords.count, 1)
        XCTAssertEqual(all.usageRecords[0].category, "calls")
        let url0 = MockResponses.shared.captured[0].url
        XCTAssertEqual(url0.path, "/2010-04-01/Accounts/\(Self.accountSid)/Usage/Records.json")
        XCTAssertTrue(url0.absoluteString.contains("Category=calls"))
        XCTAssertTrue(url0.absoluteString.contains("IncludeSubaccounts=true"))

        _ = try await c.usageRecords.listToday(.init(startDate: "2026-10-16", endDate: "2026-10-16"))
        XCTAssertEqual(
            MockResponses.shared.captured[1].url.path,
            "/2010-04-01/Accounts/\(Self.accountSid)/Usage/Records/Today.json"
        )
    }

    func testSipRegistrationsList() async throws {
        enqueueJSON([
            "registrations": [[
                "aor": "sip:alice@sip.example.com",
                "username": "alice",
                "domain": "sip.example.com",
                "domain_sid": "SD" + String(repeating: "1", count: 32),
                "status": "registered",
                "contacts": [["contact": "sip:alice@10.0.0.1:5060", "registered": true]],
                "active_call": ["call_sid": "CA" + String(repeating: "9", count: 32)],
            ]],
            "page": 0,
            "page_size": 50,
            "uri": "/x",
        ])
        let c = try makeClient()

        let list = try await c.sip.registrations.list()
        XCTAssertEqual(list.registrations.count, 1)
        XCTAssertEqual(list.registrations[0].status, "registered")
        XCTAssertEqual(list.registrations[0].activeCall?.callSid, "CA" + String(repeating: "9", count: 32))
        XCTAssertEqual(MockResponses.shared.captured[0].url.path, "/2010-04-01/Accounts/\(Self.accountSid)/SIP/Registrations.json")
    }

    func testMessagingServicePhoneNumbersRideMessagingHost() async throws {
        let mgSid = "MG" + String(repeating: "1", count: 32)
        let pn: [String: Any] = [
            "sid": "PN" + String(repeating: "2", count: 32),
            "account_sid": Self.accountSid,
            "service_sid": mgSid,
            "date_created": "2026-05-01T00:00:00Z",
            "date_updated": "2026-05-01T00:00:00Z",
            "phone_number": "+14155550103",
            "country_code": "US",
            "capabilities": ["Voice", "SMS"],
            "url": "https://messaging.voicetel.com/v1/Services/\(mgSid)/PhoneNumbers/PN2",
        ]
        enqueueJSON(["phone_numbers": [pn], "meta": ["page": 0, "page_size": 50]])
        enqueueJSON(pn, status: 200)
        enqueueRaw(Data(), status: 204)
        let c = try makeClient()

        let list = try await c.messagingV1.services.phoneNumbers(chatServiceSid: mgSid).list()
        XCTAssertEqual(list.phoneNumbers?.count, 1)
        XCTAssertEqual(list.phoneNumbers?[0].phoneNumber, "+14155550103")
        XCTAssertEqual(MockResponses.shared.captured[0].url.host, "messaging.voicetel.com")
        XCTAssertEqual(MockResponses.shared.captured[0].url.path, "/v1/Services/\(mgSid)/PhoneNumbers")

        let added = try await c.messagingV1.services.phoneNumbers(chatServiceSid: mgSid).create(
            .init(phoneNumberSid: "PN" + String(repeating: "2", count: 32))
        )
        XCTAssertEqual(added.sid, "PN" + String(repeating: "2", count: 32))
        XCTAssertTrue(String(decoding: MockResponses.shared.captured[1].body, as: UTF8.self).contains("PhoneNumberSid=PN"))
        XCTAssertEqual(MockResponses.shared.captured[1].url.host, "messaging.voicetel.com")

        try await c.messagingV1.services.phoneNumbers(chatServiceSid: mgSid).delete(sid: "PN" + String(repeating: "2", count: 32))
        XCTAssertEqual(MockResponses.shared.captured[2].method, "DELETE")
        XCTAssertEqual(MockResponses.shared.captured[2].url.host, "messaging.voicetel.com")
    }

    // MARK: - Timeouts (C13)

    func testResourceTimeoutMustExceedRequestTimeout() {
        XCTAssertThrowsError(try VoiceMLClient(
            accountSid: Self.accountSid,
            apiKey: Self.apiKey,
            timeout: 30,
            resourceTimeout: 10
        )) { error in
            XCTAssertTrue(error is ConfigurationError)
        }
    }

    func testGetAudioUsesResourceTimeoutNotIdleTimeout() async throws {
        // Not directly observable through the mock; assert the request-level timeout
        // assigned to the audio request is the resource timeout.
        enqueueRaw(Data("x".utf8), status: 200, headers: ["Content-Type": "audio/wav"])
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: cfg)
        let c = try VoiceMLClient(
            accountSid: Self.accountSid,
            apiKey: Self.apiKey,
            timeout: 30,
            resourceTimeout: 300,
            session: session
        )
        _ = try await c.recordings.getAudio(recordingSid: "RE" + String(repeating: "e", count: 32))
        XCTAssertEqual(MockResponses.shared.captured.count, 1)
    }

    // MARK: - startTime non-spec keys removed (C8)

    func testListCallsParamsNoLongerExposeGteLte() {
        let items = ListCallsParams(startTime: "2026-01-01").queryItems()
        let names = items.compactMap(\.name)
        XCTAssertFalse(names.contains("StartTime>="))
        XCTAssertFalse(names.contains("StartTime<="))
        XCTAssertTrue(names.contains("StartTime"))
        XCTAssertTrue(names.contains("StartTime<"))
        XCTAssertTrue(names.contains("StartTime>"))
    }

    // MARK: - Final-spec additions (Monitor Alerts, feedback, key rotation)

    private func alertBody(sid: String = "NO" + String(repeating: "1", count: 30)) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "alert_text": "HTTP retrieval failed",
            "api_version": NSNull(),
            "error_code": "11200",
            "log_level": "error",
            "more_info": "https://voicetel.com/docs/errors/11200",
            "request_method": "POST",
            "request_url": "https://example.com/hook",
            "resource_sid": "CA" + String(repeating: "2", count: 32),
            "service_sid": NSNull(),
            "date_created": "2026-10-17T12:00:00Z",
            "date_generated": "2026-10-17T12:00:00Z",
            "date_updated": "2026-10-17T12:00:00Z",
            "url": "https://voiceml.voicetel.com/v1/Alerts/\(sid)",
        ]
    }

    func testMonitorAlertsListSendsFiltersOnDefaultHostWithAuth() async throws {
        enqueueJSON([
            "alerts": [alertBody()],
            "meta": [
                "first_page_url": "https://voiceml.voicetel.com/v1/Alerts?PageSize=25",
                "next_page_url": nil,
                "previous_page_url": nil,
                "url": "https://voiceml.voicetel.com/v1/Alerts?PageSize=25",
                "page": 0,
                "page_size": 25,
                "key": "alerts",
            ],
        ])
        let c = try makeClient()

        let listed = try await c.monitorAlerts.list(.init(
            logLevel: .error,
            startDate: "2026-10-01",
            endDate: "2026-10-02",
            pageSize: 25
        ))

        let captured = MockResponses.shared.captured
        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured[0].method, "GET")
        XCTAssertEqual(captured[0].url.host, "voiceml.voicetel.com")
        XCTAssertEqual(captured[0].url.path, "/v1/Alerts")
        XCTAssertEqual(captured[0].headers["Authorization"], authHeader())
        let query = captured[0].url.query ?? ""
        XCTAssertEqual(Set(query.split(separator: "&").map { String($0.split(separator: "=")[0]) }),
                       ["LogLevel", "StartDate", "EndDate", "PageSize"], query)

        XCTAssertEqual(listed.alerts.count, 1)
        let alert = try XCTUnwrap(listed.alerts.first)
        XCTAssertEqual(alert.errorCode, "11200")
        XCTAssertEqual(alert.logLevel, MonitorLogLevel(rawValue: "error"))
        XCTAssertEqual(alert.resourceSid, "CA" + String(repeating: "2", count: 32))
        XCTAssertNil(alert.apiVersion)
        XCTAssertNil(alert.responseBody)
        XCTAssertEqual(listed.meta.pageSize, 25)
    }

    func testMonitorAlertsListOmitsUnsetFiltersAndToleratesUnknownLogLevel() async throws {
        enqueueJSON([
            "alerts": [["sid": "NO" + String(repeating: "3", count: 30), "log_level": "critical"]],
            "meta": ["page": 0],
        ])
        let c = try makeClient()

        let listed = try await c.monitorAlerts.list(.init(logLevel: .warning))

        let query = MockResponses.shared.captured[0].url.query ?? ""
        XCTAssertTrue(query.contains("LogLevel=warning"), query)
        XCTAssertFalse(query.contains("StartDate"), query)
        XCTAssertFalse(query.contains("EndDate"), query)
        XCTAssertFalse(query.contains("PageSize"), query)
        // Unknown enum values decode instead of failing the page.
        XCTAssertEqual(listed.alerts[0].logLevel, MonitorLogLevel(rawValue: "critical"))
    }

    func testMonitorAlertsFetchIncludesRequestResponseDetail() async throws {
        var body = alertBody()
        body["request_headers"] = "Accept: application/json"
        body["request_variables"] = "Digits=1234"
        body["response_body"] = "500 Internal Server Error"
        body["response_headers"] = "Content-Type: text/plain"
        let sid = "NO" + String(repeating: "4", count: 30)
        enqueueJSON(body)
        let c = try makeClient()

        let alert = try await c.monitorAlerts.fetch(sid: sid)

        XCTAssertEqual(alert.responseBody, "500 Internal Server Error")
        XCTAssertEqual(alert.requestVariables, "Digits=1234")
        let captured = MockResponses.shared.captured
        XCTAssertEqual(captured[0].url.path, "/v1/Alerts/\(sid)")
        XCTAssertEqual(captured[0].headers["Authorization"], authHeader())
    }

    func testMonitorAlertsNextPageFollowsMetaVerbatimAndStops() async throws {
        let link = "https://voiceml.voicetel.com/v1/Alerts?PageSize=1&PageToken=PTabc"
        let page1: [String: Any] = [
            "alerts": [alertBody()],
            "meta": [
                "next_page_url": link,
                "page": 0,
                "page_size": 1,
            ],
        ]
        let page2: [String: Any] = [
            "alerts": [alertBody(sid: "NO" + String(repeating: "5", count: 30))],
            "meta": ["page": 1, "page_size": 1],
        ]
        // Two pairs: the manual walk below, then the iterate() walk.
        enqueueJSON(page1)
        enqueueJSON(page2)
        enqueueJSON(page1)
        enqueueJSON(page2)
        let c = try makeClient()

        let first = try await c.monitorAlerts.list(.init(pageSize: 1))
        let second = try await c.monitorAlerts.nextPage(of: first)
        XCTAssertNotNil(second)
        // The last page carries no next link: no third request is sent.
        let third = try await c.monitorAlerts.nextPage(of: XCTUnwrap(second))
        XCTAssertNil(third)

        XCTAssertEqual(MockResponses.shared.captured.count, 2)
        XCTAssertEqual(MockResponses.shared.captured[1].url.absoluteString, link)
        XCTAssertEqual(MockResponses.shared.captured[1].headers["Authorization"], authHeader())

        // The walker terminates after the last page.
        var seen: [String] = []
        for try await alert in c.monitorAlerts.iterate(.init(pageSize: 1)) {
            seen.append(alert.sid ?? "")
        }
        XCTAssertEqual(seen.count, 2)
        XCTAssertEqual(MockResponses.shared.captured.count, 4)
    }

    func testMonitorAlertsNextPageRefusesForeignHost() async throws {
        enqueueJSON([
            "alerts": [],
            "meta": ["next_page_url": "https://evil.example.com/v1/Alerts"],
        ])
        let c = try makeClient()

        let page = try await c.monitorAlerts.list()
        do {
            _ = try await c.monitorAlerts.nextPage(of: page)
            XCTFail("expected a ConfigurationError for the foreign host")
        } catch {
            XCTAssertTrue(error is ConfigurationError, "\(error)")
        }
        XCTAssertEqual(MockResponses.shared.captured.count, 1, "no second request may be sent")
    }

    func testMessagesCreateFeedbackPostsExactOutcomePair() async throws {
        enqueueJSON([
            "account_sid": Self.accountSid,
            "message_sid": "SM" + String(repeating: "5", count: 30),
            "outcome": "confirmed",
            "date_created": "Mon, 17 Oct 2026 12:00:00 +0000",
            "date_updated": "Mon, 17 Oct 2026 12:00:00 +0000",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Messages/SM/Feedback.json",
        ], status: 201)
        let c = try makeClient()
        let sid = "SM" + String(repeating: "6", count: 30)

        let feedback = try await c.messages.createFeedback(sid: sid, .init(outcome: "confirmed"))

        XCTAssertEqual(feedback.outcome, "confirmed")
        XCTAssertEqual(feedback.messageSid, "SM" + String(repeating: "5", count: 30))
        let captured = MockResponses.shared.captured
        XCTAssertEqual(captured[0].method, "POST")
        XCTAssertEqual(captured[0].url.path, "/2010-04-01/Accounts/\(Self.accountSid)/Messages/\(sid)/Feedback.json")
        XCTAssertEqual(String(decoding: captured[0].body, as: UTF8.self), "Outcome=confirmed")
        XCTAssertEqual(captured[0].headers["Authorization"], authHeader())
    }

    func testAccountsRotateKeyPostsNoBodyAndDecodesKey() async throws {
        enqueueJSON([
            "sid": Self.accountSid,
            "api_key": "fresh-rotated-key-9876",
            "sip_username": "sip-acme",
            "phone_regions": ["US"],
            "allow_cidr": [],
            "disabled": false,
            "stt_http_token_set": false,
            "tts_http_token_set": false,
            "stripe_secret_key_set": false,
            "pay_enabled": false,
            "sms_allowed_providers": ["twilio"],
            "stt_allowed_providers": [],
            "aws_secret_access_key_set": false,
            "created_at": "2026-10-17T12:00:00Z",
            "updated_at": "2026-10-17T12:00:00Z",
        ])
        let c = try makeClient()

        let account = try await c.accounts.rotateKey()

        XCTAssertEqual(account.apiKey, "fresh-rotated-key-9876")
        XCTAssertEqual(account.smsAllowedProviders, ["twilio"])
        let captured = MockResponses.shared.captured
        XCTAssertEqual(captured[0].method, "POST")
        XCTAssertEqual(captured[0].url.path, "/2010-04-01/Accounts/\(Self.accountSid)/RotateKey.json")
        XCTAssertTrue(captured[0].body.isEmpty, "rotateKey takes no request body")
        XCTAssertEqual(captured[0].headers["Authorization"], authHeader())
    }

    func testAccountWithKeyRedactsApiKeyInMirrorAndDump() throws {
        let account = AccountWithKey(
            sid: Self.accountSid,
            apiKey: "fresh-rotated-key-9876"
        )

        let mirrorChildren = Mirror(reflecting: account).children
        XCTAssertTrue(mirrorChildren.allSatisfy { !"\($0.value)".contains("fresh-rotated-key-9876") })
        let apiKeyChild = mirrorChildren.first { $0.label == "apiKey" }
        XCTAssertEqual(apiKeyChild.map { "\($0.value)" }, "<redacted>")
        XCTAssertFalse(account.debugDescription.contains("fresh-rotated-key-9876"))
        XCTAssertTrue(account.debugDescription.contains(Self.accountSid))

        var capture = DumpCapture()
        dump(account, to: &capture)
        XCTAssertFalse(capture.text.contains("fresh-rotated-key-9876"), "dump() must not expose the rotated api key")
    }
}
