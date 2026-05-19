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
        XCTAssertEqual(voiceMLVersion, "0.4.0")
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
        XCTAssertEqual(r.url.absoluteString, "https://voiceml.voicetel.com/2010-04-01/Accounts/\(Self.accountSid)/Calls")

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
}
