import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import VoiceML

// MARK: - URLProtocol-based mock

/// Stores a queue of canned responses for the active URLProtocol mock. Each entry yields
/// a `(status, body, headers)` tuple. We also capture every observed request so tests can
/// assert on URL/body/auth headers.
final class MockResponses: @unchecked Sendable {
    struct CannedResponse {
        var statusCode: Int
        var body: Data
        var headers: [String: String]
    }
    struct CapturedRequest {
        var url: URL
        var method: String
        var headers: [String: String]
        var body: Data
    }

    private let lock = NSLock()
    private var responses: [CannedResponse] = []
    private(set) var captured: [CapturedRequest] = []

    static let shared = MockResponses()

    func reset() {
        lock.lock(); defer { lock.unlock() }
        responses.removeAll()
        captured.removeAll()
    }

    func enqueue(_ r: CannedResponse) {
        lock.lock(); defer { lock.unlock() }
        responses.append(r)
    }

    func dequeue() -> CannedResponse? {
        lock.lock(); defer { lock.unlock() }
        return responses.isEmpty ? nil : responses.removeFirst()
    }

    func record(_ r: CapturedRequest) {
        lock.lock(); defer { lock.unlock() }
        captured.append(r)
    }
}

final class MockURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // Capture request — incl. body. URLSession strips httpBody from URLRequest when it
        // enters the protocol; we read it from httpBodyStream if necessary.
        let bodyData: Data
        if let data = request.httpBody {
            bodyData = data
        } else if let stream = request.httpBodyStream {
            bodyData = Self.readAll(stream)
        } else {
            bodyData = Data()
        }
        MockResponses.shared.record(.init(
            url: request.url!,
            method: request.httpMethod ?? "GET",
            headers: request.allHTTPHeaderFields ?? [:],
            body: bodyData
        ))

        let resp = MockResponses.shared.dequeue() ?? .init(
            statusCode: 500,
            body: Data("no mock response queued".utf8),
            headers: [:]
        )
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: resp.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: resp.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: resp.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readAll(_ stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }
        var data = Data()
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
            let n = stream.read(buf, maxLength: 4096)
            if n <= 0 { break }
            data.append(buf, count: n)
        }
        return data
    }
}

// MARK: - Test helpers

final class VoiceMLSmokeTests: XCTestCase {

    static let accountSid = "AC" + String(repeating: "f", count: 32)
    static let apiKey = "secret-key-1234"
    static let baseURL = URL(string: "https://voiceml.voicetel.com")!

    override func setUp() {
        super.setUp()
        MockResponses.shared.reset()
        // Cap retry backoff to 1ms so the retry test doesn't spend real seconds sleeping.
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

    // MARK: - Module surface

    func testVersion() {
        XCTAssertEqual(voiceMLVersion, "0.7.0")
    }

    func testRequiresAccountSidAndApiKey() {
        XCTAssertThrowsError(try VoiceMLClient(accountSid: "", apiKey: Self.apiKey)) { err in
            XCTAssertTrue(err is ConfigurationError)
        }
        XCTAssertThrowsError(try VoiceMLClient(accountSid: Self.accountSid, apiKey: "")) { err in
            XCTAssertTrue(err is ConfigurationError)
        }
    }

    func testWiresUpAllResourceGroups() throws {
        let c = try makeClient()
        XCTAssertEqual(c.accountSid, Self.accountSid)
        XCTAssertEqual(c.baseURL.absoluteString, Self.baseURL.absoluteString)
        // Reference each — just verifying non-nil; in Swift these are non-optional `let`s
        // so the cast suffices to ensure they wired up.
        _ = c.calls
        _ = c.conferences
        _ = c.queues
        _ = c.applications
        _ = c.recordings
        _ = c.incomingPhoneNumbers
        _ = c.messages
        _ = c.diagnostics
    }

    // MARK: - Calls

    func testCallsCreateSendsFormBodyAndBasicAuth() async throws {
        enqueueJSON(callPayload(), status: 201)
        let c = try makeClient()

        let call = try await c.calls.create(.init(
            to: "+18005551234",
            from: "+18005550000",
            url: "https://example.com/twiml"
        ))
        XCTAssertTrue(call.sid.hasPrefix("CA"))

        let captured = MockResponses.shared.captured
        XCTAssertEqual(captured.count, 1)
        let r = captured[0]
        XCTAssertEqual(r.method, "POST")
        XCTAssertEqual(r.url.absoluteString, "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/Calls.json")

        let expectedAuth = "Basic " + Data("\(Self.accountSid):\(Self.apiKey)".utf8).base64EncodedString()
        XCTAssertEqual(r.headers["Authorization"], expectedAuth)
        XCTAssertEqual(r.headers["Content-Type"], "application/x-www-form-urlencoded")

        let form = parseForm(r.body)
        XCTAssertEqual(form["To"]?.first, "+18005551234")
        XCTAssertEqual(form["From"]?.first, "+18005550000")
        XCTAssertEqual(form["Url"]?.first, "https://example.com/twiml")
    }

    func testCallsListRoundTripsStartTimeOperators() async throws {
        enqueueJSON([
            "calls": [callPayload()],
            "page": 0,
            "page_size": 50,
            "total": 1,
            "next_page_uri": NSNull(),
            "uri": "/Calls",
        ])
        let c = try makeClient()

        let result = try await c.calls.list(.init(
            status: .completed,
            startTimeGte: "2026-01-01",
            startTimeLte: "2026-12-31",
            pageSize: 10
        ))
        XCTAssertEqual(result.calls.count, 1)

        let url = MockResponses.shared.captured[0].url.absoluteString.lowercased()
        // The URL string should contain literal-encoded StartTime>= and StartTime<=.
        // Compare lowercased so we tolerate either uppercase or lowercase percent-encoding.
        XCTAssertTrue(url.contains("status=completed"))
        XCTAssertTrue(url.contains("starttime%3e%3d=2026-01-01"))
        XCTAssertTrue(url.contains("starttime%3c%3d=2026-12-31"))
        XCTAssertTrue(url.contains("pagesize=10"))
        // `.json` suffix sits between path and query string.
        XCTAssertTrue(url.contains("/calls.json?"))
    }

    func testCallsUpdateStatusCompleted() async throws {
        let sid = "CA" + String(repeating: "1", count: 32)
        var payload = callPayload(sid: sid)
        payload["status"] = "completed"
        enqueueJSON(payload)
        let c = try makeClient()

        let result = try await c.calls.update(callSid: sid, body: .init(status: .completed))
        XCTAssertEqual(result.status, .completed)

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["Status"]?.first, "completed")
    }

    // MARK: - Booleans

    func testBooleanEncoding() async throws {
        let cfSid = "CF" + String(repeating: "5", count: 32)
        let callSid = "CA" + String(repeating: "4", count: 32)
        enqueueJSON([
            "call_sid": callSid,
            "conference_sid": cfSid,
            "account_sid": Self.accountSid,
            "muted": true,
            "hold": false,
            "coaching": false,
            "queue_time": "0",
            "start_conference_on_enter": true,
            "end_conference_on_exit": false,
            "status": "connected",
            "api_version": "2010-04-01",
            "uri": "/x",
        ])
        let c = try makeClient()
        _ = try await c.conferences.updateParticipant(
            conferenceSid: cfSid,
            callSid: callSid,
            body: .init(muted: true, hold: false)
        )

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["Muted"]?.first, "true")
        XCTAssertEqual(form["Hold"]?.first, "false")
    }

    // MARK: - Streams

    func testStreamsStart() async throws {
        let callSid = "CA" + String(repeating: "6", count: 32)
        enqueueJSON([
            "sid": "MZ" + String(repeating: "7", count: 32),
            "account_sid": Self.accountSid,
            "call_sid": callSid,
            "status": "in-progress",
            "api_version": "2010-04-01",
            "uri": "/x",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.calls.startStream(callSid: callSid, body: .init(
            url: "wss://example.com/ws",
            track: .bothTracks,
            name: "ws-1"
        ))

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["Url"]?.first, "wss://example.com/ws")
        XCTAssertEqual(form["Track"]?.first, "both_tracks")
        XCTAssertEqual(form["Name"]?.first, "ws-1")
    }

    // MARK: - Error mapping

    func test401ToAuthenticationError() async throws {
        let sid = "CA" + String(repeating: "8", count: 32)
        enqueueJSON(["code": 20003, "message": "Authentication Error", "status": 401], status: 401)
        let c = try makeClient(maxRetries: 0)

        do {
            _ = try await c.calls.get(sid)
            XCTFail("expected throw")
        } catch let err as AuthenticationError {
            XCTAssertEqual(err.statusCode, 401)
            XCTAssertEqual(err.code, "20003")
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func test404ToNotFoundError() async throws {
        let sid = "CA" + String(repeating: "9", count: 32)
        enqueueJSON(["code": 20404, "message": "Not Found", "status": 404], status: 404)
        let c = try makeClient(maxRetries: 0)

        do {
            _ = try await c.calls.get(sid)
            XCTFail("expected throw")
        } catch is NotFoundError {
            // ok
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func test429ToRateLimitErrorWhenNoRetry() async throws {
        let sid = "CA" + String(repeating: "a", count: 32)
        enqueueJSON(["code": 20429, "message": "Too Many", "status": 429], status: 429)
        let c = try makeClient(maxRetries: 0)

        do {
            _ = try await c.calls.get(sid)
            XCTFail("expected throw")
        } catch is RateLimitError {
            // ok
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func test501ToNotImplementedAPIError() async throws {
        let sid = "CA" + String(repeating: "b", count: 32)
        enqueueJSON(["code": 20501, "message": "Not Implemented", "status": 501], status: 501)
        let c = try makeClient(maxRetries: 0)

        do {
            try await c.calls.sendUserDefinedMessage(callSid: sid, payload: ["hello": "world"])
            XCTFail("expected throw")
        } catch is NotImplementedAPIError {
            // ok
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func test409ToConflictErrorAndApiErrorBase() async throws {
        let sid = "QU" + String(repeating: "c", count: 32)
        enqueueJSON(["code": 20409, "message": "Queue still has waiting members", "status": 409], status: 409)
        let c = try makeClient(maxRetries: 0)

        do {
            try await c.queues.delete(sid)
            XCTFail("expected throw")
        } catch let err as ApiError {
            XCTAssertEqual(err.statusCode, 409)
            XCTAssertEqual(err.code, "20409")
            XCTAssertTrue(err is ConflictError)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    // MARK: - Retry policy

    func testRetries503ThenSucceeds() async throws {
        let sid = "CA" + String(repeating: "d", count: 32)
        // First: 503. Second: 200 with the payload.
        enqueueRaw(Data("upstream busy".utf8), status: 503)
        enqueueJSON(callPayload(sid: sid))
        let c = try makeClient(maxRetries: 1)

        let call = try await c.calls.get(sid)
        XCTAssertEqual(call.sid, sid)
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
    }

    // MARK: - Defaults

    func testDefaultBaseURL() throws {
        let c = try VoiceMLClient(accountSid: Self.accountSid, apiKey: Self.apiKey)
        XCTAssertEqual(c.baseURL.absoluteString, "https://voiceml.voicetel.com")
    }

    // MARK: - authToken alias

    func testAuthTokenAliasUsedAsApiKey() async throws {
        enqueueJSON(callPayload(), status: 201)
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: cfg)

        let c = try VoiceMLClient(
            accountSid: Self.accountSid,
            authToken: Self.apiKey,
            session: session
        )
        _ = try await c.calls.create(.init(
            to: "+18005551234",
            from: "+18005550000",
            url: "https://example.com/twiml"
        ))

        let r = MockResponses.shared.captured[0]
        let expectedAuth = "Basic " + Data("\(Self.accountSid):\(Self.apiKey)".utf8).base64EncodedString()
        XCTAssertEqual(r.headers["Authorization"], expectedAuth)
    }

    func testApiKeyAndAuthTokenBothSetThrows() {
        XCTAssertThrowsError(try VoiceMLClient(
            accountSid: Self.accountSid,
            apiKey: "k1",
            authToken: "k2"
        )) { err in
            XCTAssertTrue(err is ConfigurationError)
        }
    }

    func testNeitherApiKeyNorAuthTokenThrows() {
        XCTAssertThrowsError(try VoiceMLClient(accountSid: Self.accountSid)) { err in
            XCTAssertTrue(err is ConfigurationError)
        }
    }

    // MARK: - moreInfo

    func testApiErrorCarriesMoreInfo() async throws {
        let sid = "CA" + String(repeating: "e", count: 32)
        enqueueJSON([
            "code": 20404,
            "message": "Not Found",
            "more_info": "https://voicetel.com/docs/api/v0.5/errors/20404",
            "status": 404,
        ], status: 404)
        let c = try makeClient(maxRetries: 0)

        do {
            _ = try await c.calls.get(sid)
            XCTFail("expected throw")
        } catch let err as NotFoundError {
            XCTAssertEqual(err.moreInfo, "https://voicetel.com/docs/api/v0.5/errors/20404")
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testApiErrorMoreInfoNilWhenAbsent() async throws {
        let sid = "CA" + String(repeating: "f", count: 32)
        enqueueJSON(["code": 20404, "message": "Not Found", "status": 404], status: 404)
        let c = try makeClient(maxRetries: 0)

        do {
            _ = try await c.calls.get(sid)
            XCTFail("expected throw")
        } catch let err as NotFoundError {
            XCTAssertNil(err.moreInfo)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    // MARK: - .json suffix machinery

    func testApplyJSONSuffixAppendsToBarePath() {
        let p = Transport.applyJSONSuffix(
            "/2010-04-01/Accounts/AC0/Calls"
        )
        XCTAssertEqual(p, "/2010-04-01/Accounts/AC0/Calls.json")
    }

    func testApplyJSONSuffixIdempotent() {
        let p = Transport.applyJSONSuffix(
            "/2010-04-01/Accounts/AC0/Calls.json"
        )
        XCTAssertEqual(p, "/2010-04-01/Accounts/AC0/Calls.json")
    }

    func testApplyJSONSuffixSkipsWav() {
        let p = Transport.applyJSONSuffix(
            "/2010-04-01/Accounts/AC0/Recordings/RE0.wav"
        )
        XCTAssertEqual(p, "/2010-04-01/Accounts/AC0/Recordings/RE0.wav")
    }

    func testApplyJSONSuffixSkipsHealthAndDocs() {
        XCTAssertEqual(Transport.applyJSONSuffix("/health"), "/health")
        XCTAssertEqual(Transport.applyJSONSuffix("/openapi.yaml"), "/openapi.yaml")
        XCTAssertEqual(Transport.applyJSONSuffix("/openapi.yml"), "/openapi.yml")
        XCTAssertEqual(Transport.applyJSONSuffix("/openapi.json"), "/openapi.json")
    }

    func testApplyJSONSuffixPreservesQueryString() {
        let p = Transport.applyJSONSuffix(
            "/2010-04-01/Accounts/AC0/Calls?Status=completed"
        )
        XCTAssertEqual(p, "/2010-04-01/Accounts/AC0/Calls.json?Status=completed")
    }

    // MARK: - IncomingPhoneNumbers

    private func ipnPayload(
        sid: String = "PN" + String(repeating: "0", count: 32),
        phoneNumber: String = "+18005551234"
    ) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "phone_number": phoneNumber,
            "friendly_name": "",
            "api_version": "2010-04-01",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/IncomingPhoneNumbers/\(sid).json",
            "capabilities": [
                "voice": true,
                "sms": false,
                "mms": false,
                "fax": false,
            ],
            "voice_url": "https://example.com/twiml",
            "voice_method": "POST",
            "voice_fallback_url": "",
            "voice_fallback_method": "POST",
            "beta": false,
            "origin": "",
            "voice_application_sid": "",
            "voice_caller_id_lookup": false,
            "voice_receive_mode": "voice",
            "sms_url": "",
            "sms_method": "",
            "sms_fallback_url": "",
            "sms_fallback_method": "",
            "sms_application_sid": "",
            "status_callback": "",
            "status_callback_method": "",
            "trunk_sid": "",
            "address_sid": "",
            "address_requirements": "none",
            "identity_sid": "",
            "bundle_sid": "",
            "emergency_status": "",
            "emergency_address_sid": "",
            "emergency_address_status": "",
            "status": "",
            "date_created": "Mon, 19 May 2026 12:00:00 +0000",
            "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
        ]
    }

    func testIncomingPhoneNumbersList() async throws {
        enqueueJSON([
            "incoming_phone_numbers": [ipnPayload()],
            "page": 0,
            "page_size": 50,
            "total": 1,
            "uri": "/IncomingPhoneNumbers.json",
        ])
        let c = try makeClient()

        let result = try await c.incomingPhoneNumbers.list(.init(
            page: 0, pageSize: 50, phoneNumber: "+18005551234"
        ))
        XCTAssertEqual(result.incomingPhoneNumbers.count, 1)
        XCTAssertEqual(result.incomingPhoneNumbers[0].phoneNumber, "+18005551234")
        XCTAssertEqual(result.incomingPhoneNumbers[0].capabilities?.voice, true)
        XCTAssertEqual(result.incomingPhoneNumbers[0].capabilities?.sms, false)

        let captured = MockResponses.shared.captured[0]
        XCTAssertEqual(captured.method, "GET")
        let url = captured.url.absoluteString
        XCTAssertTrue(url.contains("/IncomingPhoneNumbers.json?"))
        XCTAssertTrue(url.contains("Page=0"))
        XCTAssertTrue(url.contains("PageSize=50"))
        XCTAssertTrue(url.contains("PhoneNumber=%2B18005551234"))
    }

    func testIncomingPhoneNumbersCreate() async throws {
        enqueueJSON(ipnPayload(), status: 201)
        let c = try makeClient()

        let result = try await c.incomingPhoneNumbers.create(.init(
            phoneNumber: "+18005551234",
            voiceUrl: "https://example.com/twiml",
            voiceMethod: .post
        ))
        XCTAssertTrue(result.sid.hasPrefix("PN"))

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "POST")
        XCTAssertEqual(r.url.absoluteString, "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/IncomingPhoneNumbers.json")
        let form = parseForm(r.body)
        XCTAssertEqual(form["PhoneNumber"]?.first, "+18005551234")
        XCTAssertEqual(form["VoiceUrl"]?.first, "https://example.com/twiml")
        XCTAssertEqual(form["VoiceMethod"]?.first, "POST")
    }

    func testIncomingPhoneNumbersGet() async throws {
        let sid = "PN" + String(repeating: "1", count: 32)
        enqueueJSON(ipnPayload(sid: sid))
        let c = try makeClient()

        let result = try await c.incomingPhoneNumbers.get(sid)
        XCTAssertEqual(result.sid, sid)

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "GET")
        XCTAssertEqual(r.url.absoluteString, "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/IncomingPhoneNumbers/\(sid).json")
    }

    func testIncomingPhoneNumbersUpdate() async throws {
        let sid = "PN" + String(repeating: "2", count: 32)
        enqueueJSON(ipnPayload(sid: sid))
        let c = try makeClient()

        _ = try await c.incomingPhoneNumbers.update(sid, .init(
            voiceUrl: "https://example.com/new-twiml",
            voiceMethod: .get
        ))

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "POST")
        XCTAssertEqual(r.url.absoluteString, "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/IncomingPhoneNumbers/\(sid).json")
        let form = parseForm(r.body)
        XCTAssertEqual(form["VoiceUrl"]?.first, "https://example.com/new-twiml")
        XCTAssertEqual(form["VoiceMethod"]?.first, "GET")
        // PhoneNumber must NOT appear in update body (update-only fields).
        XCTAssertNil(form["PhoneNumber"])
    }

    func testIncomingPhoneNumbersDelete() async throws {
        enqueueRaw(Data(), status: 204)
        let c = try makeClient()
        let sid = "PN" + String(repeating: "3", count: 32)

        try await c.incomingPhoneNumbers.delete(sid)

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "DELETE")
        XCTAssertEqual(r.url.absoluteString, "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/IncomingPhoneNumbers/\(sid).json")
    }

    func testIncomingPhoneNumbersCreateConflict() async throws {
        enqueueJSON([
            "code": 21452,
            "message": "PhoneNumber already assigned",
            "more_info": "https://voicetel.com/docs/api/v0.5/errors/21452",
            "status": 409,
        ], status: 409)
        let c = try makeClient(maxRetries: 0)

        do {
            _ = try await c.incomingPhoneNumbers.create(.init(phoneNumber: "+18005551234"))
            XCTFail("expected throw")
        } catch let err as ConflictError {
            XCTAssertEqual(err.statusCode, 409)
            XCTAssertEqual(err.code, "21452")
            XCTAssertEqual(err.moreInfo, "https://voicetel.com/docs/api/v0.5/errors/21452")
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    // MARK: - Spec v0.6.2 schema additions (D5/D6)

    /// D5 — `Recording.media_url` (spec v0.6.2). Verifies the new optional field
    /// decodes from a snake_case payload into the camelCase `mediaUrl` property.
    func testRecordingDecodesMediaUrl() throws {
        let json = """
        {
          "sid": "RE\(String(repeating: "0", count: 32))",
          "account_sid": "\(Self.accountSid)",
          "call_sid": "CA\(String(repeating: "0", count: 32))",
          "status": "completed",
          "channels": 1,
          "duration": "12",
          "api_version": "2010-04-01",
          "uri": "/x",
          "date_created": "Mon, 19 May 2026 12:00:00 +0000",
          "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
          "media_url": "https://recordings.voiceml.voicetel.com/RE0.wav?sig=abc"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let r = try decoder.decode(Recording.self, from: json)
        XCTAssertEqual(r.mediaUrl, "https://recordings.voiceml.voicetel.com/RE0.wav?sig=abc")
    }

    /// D5 — backward compatibility: payloads without `media_url` must still decode,
    /// with `mediaUrl == nil`.
    func testRecordingDecodesWithoutMediaUrl() throws {
        let json = """
        {
          "sid": "RE\(String(repeating: "1", count: 32))",
          "account_sid": "\(Self.accountSid)",
          "call_sid": "CA\(String(repeating: "0", count: 32))",
          "status": "in-progress",
          "api_version": "2010-04-01",
          "uri": "/x",
          "date_created": "Mon, 19 May 2026 12:00:00 +0000",
          "date_updated": "Mon, 19 May 2026 12:00:00 +0000"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let r = try decoder.decode(Recording.self, from: json)
        XCTAssertNil(r.mediaUrl)
    }

    /// D6 — `IncomingPhoneNumber.type` (spec v0.6.2). Verifies the new optional
    /// classification field decodes through the existing snake_case strategy.
    func testIncomingPhoneNumberDecodesType() throws {
        var payload = ipnPayload()
        payload["type"] = "toll-free"
        let data = try JSONSerialization.data(withJSONObject: payload)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let ipn = try decoder.decode(IncomingPhoneNumber.self, from: data)
        XCTAssertEqual(ipn.type, "toll-free")
    }

    // MARK: - Spec v0.6.3 schema additions

    func testParticipantDecodesCoachingFields() throws {
        let json = """
        {"call_sid":"CA1","conference_sid":"CF1","account_sid":"AC0","muted":false,"hold":false,\
        "coaching":true,"call_sid_to_coach":"CA2","queue_time":"8","start_conference_on_enter":true,\
        "end_conference_on_exit":false,"status":"complete","api_version":"2010-04-01","uri":"/x"}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let p = try decoder.decode(Participant.self, from: json)
        XCTAssertTrue(p.coaching)
        XCTAssertEqual(p.callSidToCoach, "CA2")
        XCTAssertEqual(p.queueTime, "8")
        XCTAssertEqual(p.status, .complete)
    }

    func testRecordingDecodesErrorCodeAndConferenceSource() throws {
        let json = """
        {"sid":"RE1","account_sid":"AC0","call_sid":"CA1","status":"completed",\
        "source":"StartConferenceRecordingAPI","error_code":13227}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let r = try decoder.decode(Recording.self, from: json)
        XCTAssertEqual(r.source, .startConferenceRecordingAPI)
        XCTAssertEqual(r.errorCode, 13227)
    }

    func testListCallsParamsEmitsStartAndEndTimeWireNames() {
        let items = ListCallsParams(
            startTime: "2025-06-01",
            startTimeLt: "2025-06-15",
            startTimeGt: "2025-05-01",
            endTime: "2025-06-30",
            endTimeLt: "2025-07-01",
            endTimeGt: "2025-06-01"
        ).queryItems()
        let names = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
        XCTAssertEqual(names["StartTime"], "2025-06-01")
        XCTAssertEqual(names["StartTime<"], "2025-06-15")
        XCTAssertEqual(names["StartTime>"], "2025-05-01")
        XCTAssertEqual(names["EndTime"], "2025-06-30")
        XCTAssertEqual(names["EndTime<"], "2025-07-01")
        XCTAssertEqual(names["EndTime>"], "2025-06-01")
    }

    func testListCallsParamsEmitsPageToken() {
        let items = ListCallsParams(pageToken: "cursor-abc123").queryItems()
        let names = Dictionary(uniqueKeysWithValues: items.compactMap { item in
            item.value.map { (item.name, $0) }
        })
        XCTAssertEqual(names["PageToken"], "cursor-abc123")
    }

    // MARK: - Spec v0.6.6 additions

    func testCreateParticipantSendsFromAndTo() async throws {
        let confSid = "CF" + String(repeating: "0", count: 32)
        enqueueJSON([
            "call_sid": "CA" + String(repeating: "1", count: 32),
            "conference_sid": confSid,
            "account_sid": Self.accountSid,
            "muted": false,
            "hold": false,
            "coaching": false,
            "queue_time": "0",
            "start_conference_on_enter": true,
            "end_conference_on_exit": false,
            "status": "queued",
            "api_version": "2010-04-01",
            "uri": "/x",
        ], status: 201)
        let c = try makeClient()

        _ = try await c.conferences.createParticipant(
            conferenceSid: confSid,
            body: .init(from: "+18005550000", to: "+18005551234")
        )

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "POST")
        let form = parseForm(r.body)
        XCTAssertEqual(form["From"]?.first, "+18005550000")
        XCTAssertEqual(form["To"]?.first, "+18005551234")
    }

    // MARK: - Pagination (iterate)

    /// Helper: a minimal conference JSON payload.
    private func conferencePayload(sid: String) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "friendly_name": "Room-\(sid.suffix(4))",
            "status": "in-progress",
            "api_version": "2010-04-01",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Conferences/\(sid).json",
        ]
    }

    /// Helper: a minimal recording JSON payload.
    private func recordingPayload(sid: String) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "call_sid": "CA" + String(repeating: "0", count: 32),
            "status": "completed",
            "api_version": "2010-04-01",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Recordings/\(sid).json",
        ]
    }

    /// Helper: a minimal queue JSON payload.
    private func queuePayload(sid: String) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "friendly_name": "Q-\(sid.suffix(4))",
            "current_size": 0,
            "max_size": 100,
            "average_wait_time": 0,
            "date_created": "Mon, 19 May 2026 12:00:00 +0000",
            "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Queues/\(sid).json",
        ]
    }

    // -- calls.iterate() — two pages (2 + 1 = 3 items)

    func testCallsIterateTwoPages() async throws {
        let sid1 = "CA" + String(repeating: "a", count: 31) + "1"
        let sid2 = "CA" + String(repeating: "a", count: 31) + "2"
        let sid3 = "CA" + String(repeating: "a", count: 31) + "3"

        // Page 0: two calls, nextPageUri present.
        enqueueJSON([
            "calls": [callPayload(sid: sid1), callPayload(sid: sid2)],
            "page": 0,
            "page_size": 2,
            "total": 3,
            "next_page_uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls.json?Page=1&PageSize=2",
            "uri": "/Calls.json?Page=0&PageSize=2",
        ])
        // Page 1: one call, nextPageUri nil.
        enqueueJSON([
            "calls": [callPayload(sid: sid3)],
            "page": 1,
            "page_size": 2,
            "total": 3,
            "next_page_uri": NSNull(),
            "uri": "/Calls.json?Page=1&PageSize=2",
        ])

        let c = try makeClient()
        var collected: [Call] = []
        for try await call in c.calls.iterate(.init(pageSize: 2)) {
            collected.append(call)
        }

        XCTAssertEqual(collected.count, 3)
        XCTAssertEqual(collected[0].sid, sid1)
        XCTAssertEqual(collected[1].sid, sid2)
        XCTAssertEqual(collected[2].sid, sid3)
        // Two HTTP requests expected (page 0, page 1).
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
    }

    // -- conferences.iterate() — two pages (2 + 1 = 3 items)

    func testConferencesIterateTwoPages() async throws {
        let sid1 = "CF" + String(repeating: "b", count: 31) + "1"
        let sid2 = "CF" + String(repeating: "b", count: 31) + "2"
        let sid3 = "CF" + String(repeating: "b", count: 31) + "3"

        enqueueJSON([
            "conferences": [conferencePayload(sid: sid1), conferencePayload(sid: sid2)],
            "page": 0,
            "page_size": 2,
            "total": 3,
            "next_page_uri": "/2010-04-01/Accounts/\(Self.accountSid)/Conferences.json?Page=1&PageSize=2",
            "uri": "/Conferences.json?Page=0&PageSize=2",
        ])
        enqueueJSON([
            "conferences": [conferencePayload(sid: sid3)],
            "page": 1,
            "page_size": 2,
            "total": 3,
            "next_page_uri": NSNull(),
            "uri": "/Conferences.json?Page=1&PageSize=2",
        ])

        let c = try makeClient()
        var collected: [Conference] = []
        for try await conf in c.conferences.iterate(.init(pageSize: 2)) {
            collected.append(conf)
        }

        XCTAssertEqual(collected.count, 3)
        XCTAssertEqual(collected[0].sid, sid1)
        XCTAssertEqual(collected[1].sid, sid2)
        XCTAssertEqual(collected[2].sid, sid3)
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
    }

    // -- recordings.iterate() — two pages (2 + 1 = 3 items)

    func testRecordingsIterateTwoPages() async throws {
        let sid1 = "RE" + String(repeating: "c", count: 31) + "1"
        let sid2 = "RE" + String(repeating: "c", count: 31) + "2"
        let sid3 = "RE" + String(repeating: "c", count: 31) + "3"

        enqueueJSON([
            "recordings": [recordingPayload(sid: sid1), recordingPayload(sid: sid2)],
            "page": 0,
            "page_size": 2,
            "total": 3,
            "next_page_uri": "/2010-04-01/Accounts/\(Self.accountSid)/Recordings.json?Page=1&PageSize=2",
            "uri": "/Recordings.json?Page=0&PageSize=2",
        ])
        enqueueJSON([
            "recordings": [recordingPayload(sid: sid3)],
            "page": 1,
            "page_size": 2,
            "total": 3,
            "next_page_uri": NSNull(),
            "uri": "/Recordings.json?Page=1&PageSize=2",
        ])

        let c = try makeClient()
        var collected: [Recording] = []
        for try await rec in c.recordings.iterate(.init(pageSize: 2)) {
            collected.append(rec)
        }

        XCTAssertEqual(collected.count, 3)
        XCTAssertEqual(collected[0].sid, sid1)
        XCTAssertEqual(collected[1].sid, sid2)
        XCTAssertEqual(collected[2].sid, sid3)
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
    }

    // -- queues.iterate() — two pages (2 + 1 = 3 items)

    func testQueuesIterateTwoPages() async throws {
        let sid1 = "QU" + String(repeating: "d", count: 31) + "1"
        let sid2 = "QU" + String(repeating: "d", count: 31) + "2"
        let sid3 = "QU" + String(repeating: "d", count: 31) + "3"

        enqueueJSON([
            "queues": [queuePayload(sid: sid1), queuePayload(sid: sid2)],
            "page": 0,
            "page_size": 2,
            "total": 3,
            "next_page_uri": "/2010-04-01/Accounts/\(Self.accountSid)/Queues.json?Page=1&PageSize=2",
            "uri": "/Queues.json?Page=0&PageSize=2",
        ])
        enqueueJSON([
            "queues": [queuePayload(sid: sid3)],
            "page": 1,
            "page_size": 2,
            "total": 3,
            "next_page_uri": NSNull(),
            "uri": "/Queues.json?Page=1&PageSize=2",
        ])

        let c = try makeClient()
        var collected: [Queue] = []
        for try await queue in c.queues.iterate(.init(pageSize: 2)) {
            collected.append(queue)
        }

        XCTAssertEqual(collected.count, 3)
        XCTAssertEqual(collected[0].sid, sid1)
        XCTAssertEqual(collected[1].sid, sid2)
        XCTAssertEqual(collected[2].sid, sid3)
        XCTAssertEqual(MockResponses.shared.captured.count, 2)
    }

    // -- single-page edge case (calls — serves as representative for all resources)

    func testCallsIterateSinglePage() async throws {
        let sid1 = "CA" + String(repeating: "e", count: 31) + "1"

        enqueueJSON([
            "calls": [callPayload(sid: sid1)],
            "page": 0,
            "page_size": 50,
            "total": 1,
            "next_page_uri": NSNull(),
            "uri": "/Calls.json?Page=0&PageSize=50",
        ])

        let c = try makeClient()
        var collected: [Call] = []
        for try await call in c.calls.iterate() {
            collected.append(call)
        }

        XCTAssertEqual(collected.count, 1)
        XCTAssertEqual(collected[0].sid, sid1)
        // Only a single HTTP request — no second page fetched.
        XCTAssertEqual(MockResponses.shared.captured.count, 1)
    }

    func testListCallNotificationsSendsLogAndMessageDateFilters() async throws {
        let callSid = "CA" + String(repeating: "2", count: 32)
        enqueueJSON([
            "notifications": [] as [Any],
            "page": 0,
            "page_size": 50,
            "total": 0,
        ])
        let c = try makeClient()

        _ = try await c.calls.listNotifications(
            callSid: callSid,
            params: .init(
                log: 1,
                messageDate: "2026-05-01",
                messageDateLt: "2026-05-02",
                messageDateGt: "2026-04-30"
            )
        )

        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("Log=1"))
        XCTAssertTrue(url.contains("MessageDate=2026-05-01"))
        XCTAssertTrue(url.contains("MessageDate%3C=2026-05-02"))
        XCTAssertTrue(url.contains("MessageDate%3E=2026-04-30"))
    }

    // MARK: - Messages (v0.7.0)

    private func messagePayload(
        sid: String = "SM" + String(repeating: "0", count: 32),
        status: String = "sent"
    ) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "api_version": "2010-04-01",
            "to": "+18005551234",
            "from": "+18005550000",
            "body": "hello",
            "status": status,
            "num_segments": "1",
            "num_media": "0",
            "direction": "outbound-api",
            "price": NSNull(),
            "price_unit": NSNull(),
            "error_code": NSNull(),
            "error_message": NSNull(),
            "messaging_service_sid": NSNull(),
            "date_created": "Mon, 19 May 2026 12:00:00 +0000",
            "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
            "date_sent": NSNull(),
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Messages/\(sid).json",
        ]
    }

    func testMessagesCreateSendsToBodyAndFrom() async throws {
        enqueueJSON(messagePayload(), status: 201)
        let c = try makeClient()

        let msg = try await c.messages.create(.init(
            to: "+18005551234",
            body: "hello",
            from: "+18005550000",
            statusCallback: "https://example.com/cb"
        ))
        XCTAssertTrue(msg.sid.hasPrefix("SM"))
        XCTAssertEqual(msg.numSegments, "1")
        XCTAssertEqual(msg.numMedia, "0")
        XCTAssertEqual(msg.status, "sent")
        XCTAssertNil(msg.errorCode)

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "POST")
        XCTAssertEqual(
            r.url.absoluteString,
            "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/Messages.json"
        )
        XCTAssertEqual(r.headers["Content-Type"], "application/x-www-form-urlencoded")
        let form = parseForm(r.body)
        XCTAssertEqual(form["To"]?.first, "+18005551234")
        XCTAssertEqual(form["Body"]?.first, "hello")
        XCTAssertEqual(form["From"]?.first, "+18005550000")
        XCTAssertEqual(form["StatusCallback"]?.first, "https://example.com/cb")
        // MessagingServiceSid omitted (nil) — must not appear on the wire.
        XCTAssertNil(form["MessagingServiceSid"])
    }

    func testMessagesFetchDecodesErrorCode() async throws {
        let sid = "SM" + String(repeating: "1", count: 32)
        var payload = messagePayload(sid: sid, status: "failed")
        payload["error_code"] = 21609
        payload["error_message"] = "SMS gateway not configured"
        enqueueJSON(payload)
        let c = try makeClient()

        let msg = try await c.messages.fetch(sid: sid)
        XCTAssertEqual(msg.sid, sid)
        XCTAssertEqual(msg.status, "failed")
        XCTAssertEqual(msg.errorCode, 21609)
        XCTAssertEqual(msg.errorMessage, "SMS gateway not configured")

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "GET")
        XCTAssertEqual(
            r.url.absoluteString,
            "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/Messages/\(sid).json"
        )
    }

    func testMessagesListEmitsDateSentOperators() async throws {
        enqueueJSON([
            "messages": [messagePayload()],
            "page": 0,
            "page_size": 50,
            "total": 1,
            "next_page_uri": NSNull(),
            "uri": "/Messages",
        ])
        let c = try makeClient()

        let result = try await c.messages.list(.init(
            to: "+18005551234",
            dateSent: "2026-05-01",
            dateSentLt: "2026-05-15",
            dateSentGt: "2026-04-30",
            pageSize: 10
        ))
        XCTAssertEqual(result.messages.count, 1)

        let url = MockResponses.shared.captured[0].url.absoluteString
        XCTAssertTrue(url.contains("To=%2B18005551234"))
        XCTAssertTrue(url.contains("DateSent=2026-05-01"))
        XCTAssertTrue(url.contains("DateSent%3C=2026-05-15"))
        XCTAssertTrue(url.contains("DateSent%3E=2026-04-30"))
        XCTAssertTrue(url.contains("PageSize=10"))
        XCTAssertTrue(url.lowercased().contains("/messages.json?"))
    }

    func testMessagesUpdateBodyRedaction() async throws {
        let sid = "SM" + String(repeating: "2", count: 32)
        var payload = messagePayload(sid: sid)
        payload["body"] = ""
        enqueueJSON(payload)
        let c = try makeClient()

        let result = try await c.messages.update(sid: sid, .init(body: ""))
        XCTAssertEqual(result.body, "")

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "POST")
        XCTAssertEqual(
            r.url.absoluteString,
            "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/Messages/\(sid).json"
        )
        let form = parseForm(r.body)
        // Empty-string Body must be transmitted (it's the redaction trigger).
        XCTAssertEqual(form["Body"]?.first, "")
        XCTAssertNil(form["Status"])
    }

    func testMessagesDelete() async throws {
        enqueueRaw(Data(), status: 204)
        let c = try makeClient()
        let sid = "SM" + String(repeating: "3", count: 32)

        try await c.messages.delete(sid: sid)

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "DELETE")
        XCTAssertEqual(
            r.url.absoluteString,
            "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/Messages/\(sid).json"
        )
    }

    // MARK: - Payments (v0.7.0)

    private func paymentPayload(
        sid: String = "PY" + String(repeating: "0", count: 32),
        callSid: String = "CA" + String(repeating: "1", count: 32)
    ) -> [String: Any] {
        [
            "sid": sid,
            "account_sid": Self.accountSid,
            "call_sid": callSid,
            "api_version": "2010-04-01",
            "date_created": "Mon, 19 May 2026 12:00:00 +0000",
            "date_updated": "Mon, 19 May 2026 12:00:00 +0000",
            "uri": "/2010-04-01/Accounts/\(Self.accountSid)/Calls/\(callSid)/Payments/\(sid).json",
        ]
    }

    func testCallsStartPaymentEncodesEnumsAndScalars() async throws {
        let callSid = "CA" + String(repeating: "1", count: 32)
        enqueueJSON(paymentPayload(callSid: callSid), status: 201)
        let c = try makeClient()

        let result = try await c.calls.startPayment(callSid: callSid, .init(
            idempotencyKey: "idem-abc",
            statusCallback: "https://example.com/pay-cb",
            bankAccountType: .consumerChecking,
            chargeAmount: "9.99",
            currency: "USD",
            input: .dtmf,
            minPostalCodeLength: 5,
            paymentMethod: .creditCard,
            postalCode: true,
            securityCode: false,
            timeout: 7,
            tokenType: .oneTime,
            validCardTypes: "visa mastercard",
            confirmation: true
        ))
        XCTAssertTrue(result.sid.hasPrefix("PY"))
        XCTAssertEqual(result.callSid, callSid)

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "POST")
        XCTAssertEqual(
            r.url.absoluteString,
            "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/Calls/\(callSid)/Payments.json"
        )
        XCTAssertEqual(r.headers["Content-Type"], "application/x-www-form-urlencoded")

        let form = parseForm(r.body)
        XCTAssertEqual(form["IdempotencyKey"]?.first, "idem-abc")
        XCTAssertEqual(form["StatusCallback"]?.first, "https://example.com/pay-cb")
        XCTAssertEqual(form["BankAccountType"]?.first, "consumer-checking")
        XCTAssertEqual(form["ChargeAmount"]?.first, "9.99")
        XCTAssertEqual(form["Currency"]?.first, "USD")
        XCTAssertEqual(form["Input"]?.first, "dtmf")
        XCTAssertEqual(form["MinPostalCodeLength"]?.first, "5")
        XCTAssertEqual(form["PaymentMethod"]?.first, "credit-card")
        XCTAssertEqual(form["PostalCode"]?.first, "true")
        XCTAssertEqual(form["SecurityCode"]?.first, "false")
        XCTAssertEqual(form["Timeout"]?.first, "7")
        XCTAssertEqual(form["TokenType"]?.first, "one-time")
        XCTAssertEqual(form["ValidCardTypes"]?.first, "visa mastercard")
        XCTAssertEqual(form["Confirmation"]?.first, "true")
        // Omitted optionals must not appear on the wire.
        XCTAssertNil(form["Description"])
        XCTAssertNil(form["Parameter"])
    }

    func testCallsUpdatePaymentStatusComplete() async throws {
        let callSid = "CA" + String(repeating: "2", count: 32)
        let paySid = "PY" + String(repeating: "1", count: 32)
        enqueueJSON(paymentPayload(sid: paySid, callSid: callSid), status: 202)
        let c = try makeClient()

        let result = try await c.calls.updatePayment(
            callSid: callSid,
            paymentSid: paySid,
            .init(idempotencyKey: "idem-complete", status: .complete)
        )
        XCTAssertEqual(result.sid, paySid)

        let r = MockResponses.shared.captured[0]
        XCTAssertEqual(r.method, "POST")
        XCTAssertEqual(
            r.url.absoluteString,
            "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/Calls/\(callSid)/Payments/\(paySid).json"
        )
        let form = parseForm(r.body)
        XCTAssertEqual(form["IdempotencyKey"]?.first, "idem-complete")
        XCTAssertEqual(form["Status"]?.first, "complete")
        XCTAssertNil(form["Capture"])
    }

    func testCallsUpdatePaymentCaptureSecurityCode() async throws {
        let callSid = "CA" + String(repeating: "3", count: 32)
        let paySid = "PY" + String(repeating: "2", count: 32)
        enqueueJSON(paymentPayload(sid: paySid, callSid: callSid), status: 202)
        let c = try makeClient()

        _ = try await c.calls.updatePayment(
            callSid: callSid,
            paymentSid: paySid,
            .init(capture: .securityCode)
        )

        let form = parseForm(MockResponses.shared.captured[0].body)
        XCTAssertEqual(form["Capture"]?.first, "security-code")
        XCTAssertNil(form["Status"])
    }
}
