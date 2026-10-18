import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP method names used by the SDK. The wire surface only ever needs these four.
public enum HTTPVerb: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

/// One query-string parameter. We use a list rather than a dict so callers can preserve
/// ordering and emit repeated keys (e.g. `StatusCallbackEvent=initiated&StatusCallbackEvent=completed`).
public struct QueryItem: Sendable {
    public let name: String
    public let value: String?

    public init(_ name: String, _ value: String?) {
        self.name = name
        self.value = value
    }
}

/// One form-urlencoded body field. Same shape as ``QueryItem`` for symmetry.
public struct FormField: Sendable {
    public let name: String
    public let value: String?

    public init(_ name: String, _ value: String?) {
        self.name = name
        self.value = value
    }

    /// Convenience for booleans → the literal "true"/"false" strings.
    public init(_ name: String, _ value: Bool?) {
        self.name = name
        self.value = value.map { $0 ? "true" : "false" }
    }

    /// Convenience for integers.
    public init(_ name: String, _ value: Int?) {
        self.name = name
        self.value = value.map { String($0) }
    }

    /// Convenience for doubles.
    public init(_ name: String, _ value: Double?) {
        self.name = name
        self.value = value.map { String($0) }
    }
}

/// Internal request descriptor — the resource classes build one of these and hand it
/// to ``Transport/request(_:)``. `path` must already be percent-encoded segment by
/// segment (see ``Transport/encodeSegment(_:)``).
struct VoiceMLRequest {
    var method: HTTPVerb
    var path: String
    var query: [QueryItem] = []
    var form: [FormField]? = nil
    var jsonBody: Data? = nil
    /// When false the request is sent without the `Authorization` header (diagnostics
    /// endpoints are declared `security: []`).
    var authenticated: Bool = true
    /// When false, no `.json` suffix is appended to `path` (e.g. `/Exports/{Date}`).
    var jsonSuffix: Bool = true
}

/// Status codes that trigger automatic retry. POST/PATCH only ever retry on 429 —
/// see ``Transport/isRetryableStatus(_:for:)``.
private let retryableStatuses: Set<Int> = [429, 500, 502, 503, 504]

/// Methods whose re-execution is safe: GET, HEAD, PUT, DELETE.
private let idempotentMethods: Set<HTTPVerb> = [.get, .put, .delete]

/// URLError codes where the request provably never reached the server (connection
/// establishment phase). Only these qualify for retrying a non-idempotent request.
private let connectPhaseURLErrorCodes: Set<URLError.Code> = [
    .cannotFindHost,
    .cannotConnectToHost,
    .dnsLookupFailed,
    .secureConnectionFailed,
    .serverCertificateHasBadDate,
    .serverCertificateHasUnknownRoot,
    .serverCertificateNotYetValid,
    .serverCertificateUntrusted,
]

/// Upper bound honoured for a `Retry-After` delay before the SDK stops sleeping and
/// raises ``RateLimitError`` instead.
public let retryAfterCap: TimeInterval = 60

/// Thin wrapper over `URLSession` that handles auth, encoding, retries, redirects and
/// error mapping.
///
/// The transport is a plain `final class` rather than an actor: `URLSession` is already
/// thread-safe, and the transport carries only immutable configuration after
/// construction. Conformance to `Sendable` is compiler-checked.
public final class Transport: Sendable {
    public let accountSid: String
    public let baseURL: URL
    public let userAgent: String

    private let apiKey: String?
    private let timeout: TimeInterval
    private let resourceTimeout: TimeInterval
    private let maxRetries: Int
    private let session: URLSession

    init(options: ClientOptions) throws {
        guard !options.accountSid.isEmpty else {
            throw ConfigurationError("accountSid is required")
        }
        guard !options.apiKey.isEmpty else {
            throw ConfigurationError("apiKey is required")
        }
        guard options.maxRetries >= 0 else {
            throw ConfigurationError("maxRetries must be >= 0")
        }
        guard options.timeout.isFinite, options.timeout > 0,
              options.resourceTimeout.isFinite else {
            throw ConfigurationError("timeouts must be positive, finite seconds")
        }
        _ = try Self.encodeSegment(options.accountSid)
        guard options.resourceTimeout >= options.timeout else {
            throw ConfigurationError("resourceTimeout must be >= timeout")
        }

        self.accountSid = options.accountSid
        self.apiKey = options.apiKey
        self.baseURL = try Self.normalizeBase(options.baseURL)
        self.timeout = options.timeout
        self.resourceTimeout = options.resourceTimeout
        self.maxRetries = options.maxRetries
        self.userAgent = options.userAgent

        if let injected = options.session {
            self.session = injected
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = options.timeout
            cfg.timeoutIntervalForResource = options.resourceTimeout
            self.session = URLSession(configuration: cfg)
        }
    }

    /// Credential-less constructor for the standalone diagnostics helpers: builds a
    /// transport that sends no `Authorization` header at all.
    init(
        diagnosticsBaseURL: URL,
        timeout: TimeInterval,
        resourceTimeout: TimeInterval,
        maxRetries: Int,
        userAgent: String,
        session: URLSession?
    ) throws {
        guard timeout.isFinite, timeout > 0, resourceTimeout.isFinite,
              resourceTimeout >= timeout, maxRetries >= 0 else {
            throw ConfigurationError("invalid diagnostics timeout or retry configuration")
        }
        self.accountSid = ""
        self.apiKey = nil
        self.baseURL = try Self.normalizeBase(diagnosticsBaseURL)
        self.timeout = timeout
        self.resourceTimeout = max(resourceTimeout, timeout)
        self.maxRetries = maxRetries
        self.userAgent = userAgent
        if let injected = session {
            self.session = injected
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = timeout
            cfg.timeoutIntervalForResource = self.resourceTimeout
            self.session = URLSession(configuration: cfg)
        }
    }

    /// Designated init used by ``scoped(to:)`` to build a sibling transport that
    /// reuses this one's session, auth, and retry policy against a different host.
    private init(
        accountSid: String,
        apiKey: String?,
        baseURL: URL,
        timeout: TimeInterval,
        resourceTimeout: TimeInterval,
        maxRetries: Int,
        userAgent: String,
        session: URLSession
    ) {
        self.accountSid = accountSid
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.timeout = timeout
        self.resourceTimeout = resourceTimeout
        self.maxRetries = maxRetries
        self.userAgent = userAgent
        self.session = session
    }

    /// Return a sibling transport pinned to a product host, sharing this
    /// transport's session, credentials, and retry policy. Used to route the
    /// whole Conversations v1 group at `conversations.voicetel.com` and Messaging
    /// Service at `messaging.voicetel.com` — they share the `/v1/Services` path
    /// shape, so the host is what disambiguates them on the wire.
    func scoped(to productBaseURL: URL) throws -> Transport {
        let normalized = try Self.normalizeBase(productBaseURL)
        return Transport(
            accountSid: accountSid,
            apiKey: apiKey,
            baseURL: normalized,
            timeout: timeout,
            resourceTimeout: resourceTimeout,
            maxRetries: maxRetries,
            userAgent: userAgent,
            session: session
        )
    }

    // MARK: - Public request entry points

    /// Send a request and decode the JSON response into `T`.
    func request<T: Decodable>(_ req: VoiceMLRequest) async throws -> T {
        let (data, status, _) = try await sendWithRetry(req)
        if data.isEmpty {
            // Some endpoints (DELETE) legitimately return no body but a declared return type.
            // Decoding empty data only works for `EmptyResponse`, otherwise fall through.
            if let empty = EmptyResponse() as? T {
                return empty
            }
        }
        do {
            return try Self.makeDecoder().decode(T.self, from: data)
        } catch {
            throw DecodingFailedError(
                message: "could not decode response (status \(status)): \(error)",
                statusCode: status,
                body: data,
                cause: error
            )
        }
    }

    /// Send a request with no expected response body.
    func requestVoid(_ req: VoiceMLRequest) async throws {
        _ = try await sendWithRetry(req)
    }

    /// Unauthenticated document fetch (`/health`, `/openapi.*`) through the configured
    /// session, timeout and retry policy — returns the raw response without status
    /// mapping so callers can treat non-2xx as payload.
    func sendUnauthDoc(_ path: String) async throws -> (Data, Int, HTTPURLResponse) {
        let url = buildURL(path: path, query: [], jsonSuffix: false)
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = "GET"
        urlReq.timeoutInterval = timeout
        applyHeaders(&urlReq, sendingJSON: false, sendingForm: false, authenticated: false)
        return try await sendWithRetry(urlReq, method: .get)
    }

    /// Fetch one page from an absolute page URL (as carried in a list envelope's
    /// `next_page_uri` resolved against the transport host, or a `/v1` `meta.next_page_url`),
    /// authenticated, through the configured session and retry policy. The URL's scheme
    /// and host must match this transport's, otherwise the request is refused before
    /// anything is sent — credentials are never transmitted to a different origin.
    public func requestPage<T: Decodable>(_ url: URL) async throws -> T {
        guard url.scheme?.lowercased() == "https",
              url.host == baseURL.host,
              url.port == baseURL.port,
              url.user == nil, url.password == nil else {
            throw ConfigurationError(
                "refusing to fetch page from \(url.absoluteString) — only \(baseURL.host ?? "") is allowed"
            )
        }
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = "GET"
        urlReq.timeoutInterval = timeout
        applyHeaders(&urlReq, sendingJSON: false, sendingForm: false, authenticated: true)
        let (data, status, _) = try await sendWithRetry(urlReq, method: .get)
        if data.isEmpty, let empty = EmptyResponse() as? T {
            return empty
        }
        do {
            return try Self.makeDecoder().decode(T.self, from: data)
        } catch {
            throw DecodingFailedError(
                message: "could not decode response (status \(status)): \(error)",
                statusCode: status,
                body: data,
                cause: error
            )
        }
    }

    /// Binary fetch used by `recordings.getAudio` and `exports.download`. Redirects
    /// are followed manually: the `Authorization` header is **never** sent on a
    /// redirect leg, and a downgrade from https is refused. The first request is an
    /// authenticated GET on the API host; subsequent legs are unauthenticated.
    func fetchBytes(path: String, jsonSuffix: Bool = true) async throws -> (Data, HTTPURLResponse) {
        let url = buildURL(path: path, query: [], jsonSuffix: jsonSuffix)
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = "GET"
        urlReq.timeoutInterval = resourceTimeout
        applyHeaders(&urlReq, sendingJSON: false, sendingForm: false, authenticated: true)
        urlReq.setValue("*/*", forHTTPHeaderField: "Accept")

        var current = urlReq
        var redirects = 0
        while true {
            let (data, _, http) = try await sendWithRetry(current, method: .get, allowRedirect: true)
            if (300..<400).contains(http.statusCode),
               let location = http.value(forHTTPHeaderField: "Location") {
                redirects += 1
                if redirects > 5 {
                    throw ApiError(message: "too many redirects", statusCode: http.statusCode, body: data)
                }
                guard let next = Self.resolveRedirect(location, relativeTo: current.url) else {
                    throw ApiError(message: "redirect carried no usable Location", statusCode: http.statusCode, body: data)
                }
                guard next.scheme?.lowercased() == "https", next.host != nil,
                      next.user == nil, next.password == nil else {
                    throw ApiError(
                        message: "refusing to follow redirect to non-https URL \(next.absoluteString)",
                        statusCode: http.statusCode,
                        body: data
                    )
                }
                var fresh = URLRequest(url: next)
                fresh.httpMethod = "GET"
                fresh.timeoutInterval = resourceTimeout
                fresh.setValue("*/*", forHTTPHeaderField: "Accept")
                fresh.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                current = fresh
                continue
            }
            if !(200..<300).contains(http.statusCode) {
                throw decodeError(status: http.statusCode, data: data, response: http)
            }
            return (data, http)
        }
    }

    /// Resolve a redirect target against the URL that produced it. Returns nil when the
    /// Location header is empty or unparseable.
    static func resolveRedirect(_ location: String, relativeTo base: URL?) -> URL? {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }

    // MARK: - Core send + retry loop

    private func sendWithRetry(_ req: VoiceMLRequest) async throws -> (Data, Int, HTTPURLResponse) {
        let urlReq = try buildURLRequest(req)
        return try await sendWithRetry(urlReq, method: req.method)
    }

    private func sendWithRetry(_ urlReq: URLRequest, method: HTTPVerb, allowRedirect: Bool = false) async throws -> (Data, Int, HTTPURLResponse) {
        var attempt = 0
        var lastError: Error?
        while attempt <= maxRetries {
            if Task.isCancelled { throw CancellationError() }
            do {
                let (data, response) = try await sessionData(for: urlReq, delegate: NoRedirectDelegate())
                guard let http = response as? HTTPURLResponse else {
                    throw ApiError(message: "non-HTTP response", statusCode: 0)
                }
                let status = http.statusCode
                if retryableStatuses.contains(status) {
                    let retryAfter = Self.parseRetryAfter(http)
                    if status == 429, let delay = retryAfter, delay > retryAfterCap {
                        // Server asked to wait longer than the SDK cap — surface the
                        // rate-limit error immediately instead of sleeping.
                        throw decodeError(status: status, data: data, response: http)
                    }
                    if attempt < maxRetries, isRetryableStatus(status, for: method) {
                        try await sleepForBackoff(attempt: attempt, response: http)
                        attempt += 1
                        continue
                    }
                }
                if !(200..<300).contains(status) && !(allowRedirect && (300..<400).contains(status)) {
                    throw decodeError(status: status, data: data, response: http)
                }
                return (data, status, http)
            } catch let err as ApiError {
                // Non-retryable API error — propagate immediately.
                throw err
            } catch let err as DecodingFailedError {
                throw err
            } catch let err as CancellationError {
                throw err
            } catch let err as URLError where err.code == .cancelled {
                throw err
            } catch {
                if Self.isCancellation(error) { throw error }
                guard Self.isRetryableTransportError(error, method: method) else {
                    throw TransportError(
                        message: "transport error: \(error)",
                        cause: error
                    )
                }
                lastError = error
                if attempt >= maxRetries {
                    throw TransportError(
                        message: "transport error after \(attempt + 1) attempts: \(error)",
                        cause: error
                    )
                }
                try await sleepForBackoff(attempt: attempt, response: nil)
                attempt += 1
            }
        }
        throw lastError ?? ApiError(message: "unreachable retry exhaustion", statusCode: 0)
    }

    private func isRetryableStatus(_ status: Int, for method: HTTPVerb) -> Bool {
        if status == 429 { return true }
        return idempotentMethods.contains(method) && retryableStatuses.contains(status)
    }

    /// Cancellation is recognised across CancellationError, URLError.cancelled and
    /// NSURLErrorDomain -999 from either platform's async bridge.
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let url = error as? URLError, url.code == .cancelled { return true }
        let ns = error as NSError
        return ns.domain == "NSURLErrorDomain" && ns.code == URLError.cancelled.rawValue
    }

    /// Transport-error retryability. Idempotent methods retry on any transport error
    /// (connect or read). POST retries only when the failure proves the request was
    /// never delivered (DNS, refused, connect-phase TLS) — never on 5xx, read timeout
    /// or connection reset.
    static func isRetryableTransportError(_ error: Error, method: HTTPVerb) -> Bool {
        if isCancellation(error) { return false }
        if idempotentMethods.contains(method) { return true }
        guard method == .post else { return false }
        if let url = error as? URLError {
            return connectPhaseURLErrorCodes.contains(url.code)
        }
        let ns = error as NSError
        if ns.domain == "NSURLErrorDomain",
           let mapped = URLError.Code(rawValue: ns.code) {
            return connectPhaseURLErrorCodes.contains(mapped)
        }
        return false
    }

    // MARK: - Request construction

    private func buildURLRequest(_ req: VoiceMLRequest) throws -> URLRequest {
        let url = buildURL(path: req.path, query: req.query, jsonSuffix: req.jsonSuffix)
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = req.method.rawValue
        urlReq.timeoutInterval = timeout

        let sendingJSON = req.jsonBody != nil
        let sendingForm = req.form != nil && !sendingJSON

        applyHeaders(&urlReq, sendingJSON: sendingJSON, sendingForm: sendingForm, authenticated: req.authenticated)

        if let json = req.jsonBody {
            urlReq.httpBody = json
        } else if let form = req.form {
            urlReq.httpBody = Self.encodeForm(form)
        }
        return urlReq
    }

    private func applyHeaders(
        _ urlReq: inout URLRequest,
        sendingJSON: Bool,
        sendingForm: Bool,
        authenticated: Bool
    ) {
        urlReq.setValue("application/json", forHTTPHeaderField: "Accept")
        urlReq.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if authenticated, let key = apiKey {
            let credentials = "\(accountSid):\(key)"
            if let encoded = credentials.data(using: .utf8)?.base64EncodedString() {
                urlReq.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
            }
        }
        if sendingJSON {
            urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if sendingForm {
            urlReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
    }

    func buildURL(path: String, query: [QueryItem], jsonSuffix: Bool = true) -> URL {
        // Append the `.json` suffix REST paths carry unless the caller opted out
        // (e.g. `/Exports/{Date}`) or the path already carries a known suffix.
        let effectivePath = jsonSuffix ? Self.applyJSONSuffix(path) : path

        // Build via URLComponents seeded from baseURL — which `normalizeBase` has
        // already proven to be https://. Setting `.scheme = "https"` here as a
        // literal makes that invariant visible to CodeQL's taint analysis and
        // clears `swift/cleartext-transmission` on the AccountSid → URL flow:
        // the scheme is now a constant at the point of URL construction, not
        // derived from a possibly-tainted absolute-string concatenation.
        var components = URLComponents()
        components.scheme = "https"
        components.host = baseURL.host
        if let port = baseURL.port { components.port = port }
        let basePath = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!.percentEncodedPath
        let trimmedBasePath = basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
        // `path` arrives pre-encoded segment by segment; assign verbatim so
        // URLComponents doesn't re-escape the `%`.
        components.percentEncodedPath = Self.normalizeEncodedPath(trimmedBasePath + effectivePath)

        // Filter out items whose value is nil, then construct the query string manually.
        // We do this by hand (rather than via URLComponents.queryItems) because the API uses
        // literal `>=`/`<=` in parameter names which need explicit encoding and ordering.
        let kept = query.filter { $0.value != nil }
        if !kept.isEmpty {
            let queryString = kept.map { item -> String in
                let n = percentEncodeQueryComponent(item.name)
                let v = percentEncodeQueryComponent(item.value ?? "")
                return "\(n)=\(v)"
            }.joined(separator: "&")
            components.percentEncodedQuery = queryString
        }

        // `URLComponents.url` can return nil only when scheme/host don't form
        // a valid URL — given the validated baseURL.host and the literal scheme
        // this branch is unreachable in practice; the fallback is purely
        // defensive (returns baseURL so a downstream error surfaces cleanly).
        return components.url ?? baseURL
    }

    /// Collapse duplicate slashes and strip `.`/`..` traversals from an encoded path
    /// before it reaches the URL — belt and braces on top of per-segment validation.
    static func normalizeEncodedPath(_ raw: String) -> String {
        let segments = raw.split(separator: "/", omittingEmptySubsequences: false)
        var out: [Substring] = []
        for seg in segments {
            if seg == "." { continue }
            if seg == ".." {
                if out.count > 1 { out.removeLast() }
                continue
            }
            out.append(seg)
        }
        return out.joined(separator: "/")
    }

    // MARK: - Path segment encoding

    /// Percent-encode and validate one caller-supplied path segment. Segments that are
    /// empty, `.` or `..` are rejected — they can only be caller error and would either
    /// 404 or traverse into a sibling resource.
    public static func encodeSegment(_ segment: String) throws -> String {
        guard !segment.isEmpty, segment != ".", segment != ".." else {
            throw ConfigurationError("invalid path segment: \(String(describing: segment))")
        }
        return percentEncodePathSegment(segment)
    }

    /// Build an encoded sub-path under `/2010-04-01/Accounts/{AccountSid}/` from
    /// validated, individually-encoded segments.
    func accountPath(_ segments: [String], suffix: String = ".json") throws -> String {
        try "/2010-04-01/Accounts/\(Self.encodeSegment(accountSid))/" + encodeSubpath(segments) + suffix
    }

    /// Build an encoded sub-path with no account prefix (v1/v2 namespaces, root paths).
    func rootPath(_ segments: [String]) throws -> String {
        let suffix = segments.first == "2010-04-01" ? ".json" : ""
        return try "/" + encodeSubpath(segments) + suffix
    }

    private func encodeSubpath(_ segments: [String]) throws -> String {
        try segments.map { try Self.encodeSegment($0) }.joined(separator: "/")
    }

    // MARK: - Pagination URL resolution

    /// Resolve a page envelope's `next_page_uri` (path + query) against this transport's
    /// scheme and host. Returns nil for nil/empty/unparseable input, which terminates
    /// iteration.
    func resolvePageURI(_ uri: String?) -> URL? {
        guard let uri, !uri.isEmpty else { return nil }
        guard var comps = URLComponents(string: uri) else { return nil }
        if comps.scheme == nil {
            comps.scheme = "https"
            comps.host = baseURL.host
            if let port = baseURL.port { comps.port = port }
            if !comps.percentEncodedPath.hasPrefix("/") {
                comps.percentEncodedPath = "/" + comps.percentEncodedPath
            }
        }
        guard comps.scheme == "https", comps.host == baseURL.host else { return nil }
        return comps.url
    }

    // MARK: - Form encoding

    static func encodeForm(_ fields: [FormField]) -> Data {
        let kept = fields.filter { $0.value != nil }
        let body = kept.map { f -> String in
            let n = percentEncodeFormComponent(f.name)
            let v = percentEncodeFormComponent(f.value ?? "")
            return "\(n)=\(v)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    // MARK: - Error / response parsing

    private func decodeError(status: Int, data: Data, response: HTTPURLResponse?) -> ApiError {
        var code: Int?
        var message = "HTTP \(status)"
        var moreInfo: String?
        var responseStatus: Int?
        if !data.isEmpty,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let c = obj["code"] as? Int {
                code = c
            } else if let c = obj["code"] as? String, let parsed = Int(c) {
                code = parsed
            }
            if let m = obj["message"] as? String, !m.isEmpty {
                message = m
            }
            if let mi = obj["more_info"] as? String, !mi.isEmpty {
                moreInfo = mi
            }
            if let s = obj["status"] as? Int {
                responseStatus = s
            }
        }
        return errorFromResponse(
            statusCode: status,
            code: code,
            body: data,
            message: message,
            moreInfo: moreInfo,
            responseStatus: responseStatus,
            retryAfter: response.flatMap { Self.parseRetryAfter($0) }
        )
    }

    // MARK: - Retry-After parsing

    /// Parse a `Retry-After` header as delta-seconds or as an RFC 7231 HTTP-date.
    /// Returns nil when absent or unparseable.
    static func parseRetryAfter(_ response: HTTPURLResponse, now: Date = Date()) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let seconds = TimeInterval(raw), seconds.isFinite {
            return max(0, seconds)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.timeZone = TimeZone(identifier: "GMT")
        if let date = formatter.date(from: raw) {
            return max(0, date.timeIntervalSince(now))
        }
        return nil
    }

    // MARK: - Backoff

    private func sleepForBackoff(attempt: Int, response: HTTPURLResponse?) async throws {
        let ms: Int
        if let r = response,
           let retryAfter = Self.parseRetryAfter(r),
           retryAfter <= retryAfterCap {
            ms = max(0, Int(retryAfter * 1000))
        } else {
            // Exponential with full jitter: random in [0, min(cap, base * 2^attempt)].
            let ceilingMs = min(8000, 500 * (1 << min(attempt, 5)))
            ms = Int.random(in: 0...max(1, ceilingMs))
        }
        // Tests cap this via `TransportBackoffOverride.maxMillis` to keep runs fast.
        let effective = TransportBackoffOverride.maxMillis.map { min($0, ms) } ?? ms
        try await Task.sleep(nanoseconds: UInt64(effective) * 1_000_000)
    }

    // MARK: - URLSession

    /// `URLSession.data(for:delegate:)` is available on Apple platforms ≥ iOS 15/macOS 12
    /// and on the Linux/swift-corelibs FoundationNetworking build shipping with Swift 6.
    /// Its async bridge propagates task cancellation on both platforms. A per-task
    /// delegate is used to stop redirect auto-following for binary fetches.
    private func sessionData(
        for request: URLRequest,
        delegate: (any URLSessionTaskDelegate)?
    ) async throws -> (Data, URLResponse) {
        try await session.data(for: request, delegate: delegate)
    }

    // MARK: - Helpers

    private static func normalizeBase(_ url: URL) throws -> URL {
        // HTTPS-only by construction. The SDK sends AccountSid + API key as HTTP
        // Basic auth on every request; cleartext over http:// would leak both.
        // Refusing the URL up-front is what proves to CodeQL's taint analysis
        // (`swift/cleartext-transmission`) that AccountSid never reaches an
        // unencrypted channel.
        guard let scheme = url.scheme?.lowercased(), scheme == "https",
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil else {
            throw ConfigurationError(
                "baseURL must use https:// (got \(url.scheme ?? "<no scheme>")://) — VoiceML auth is HTTP Basic and must not be transmitted over cleartext."
            )
        }
        var s = url.absoluteString
        while s.hasSuffix("/") { s.removeLast() }
        return URL(string: s) ?? url
    }

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    /// Append `.json` to a REST path if it doesn't already carry one of the recognized
    /// content-type suffixes. The exclusions are: `.json`, `.yaml`, `.yml` (already-typed
    /// document fetches such as `/openapi.json`), `.wav` (binary recording audio), and
    /// the literal `/health` liveness probe.
    static func applyJSONSuffix(_ path: String) -> String {
        // Strip a query fragment if present so we operate on just the path portion. We'll
        // splice the query back on at the end.
        let queryStart = path.firstIndex(of: "?")
        let basePath = queryStart.map { String(path[..<$0]) } ?? path
        let suffix = queryStart.map { String(path[$0...]) } ?? ""

        if basePath == "/health" { return path }
        // /v2/ namespace (routes/v2) uses raw paths without the .json suffix
        // — the spec defines them verbatim (e.g. /v2/SipDomains/{name}).
        if basePath.hasPrefix("/v2/") { return path }
        // /v1/ namespace (Voice v1, Conversations v1) also uses raw paths
        // without the .json suffix — these sub-domain APIs follow the
        // bare-path convention.
        if basePath.hasPrefix("/v1/") { return path }
        let known = [".json", ".yaml", ".yml", ".wav"]
        for ext in known where basePath.hasSuffix(ext) {
            return path
        }
        return basePath + ".json" + suffix
    }
}

/// Delegate that stops automatic redirect following, so `fetchBytes` can follow the
/// redirect itself without ever attaching credentials to the redirect target.
final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

/// Sentinel for DELETE-style endpoints that legitimately return no body but still need
/// to participate in the generic `request<T>` machinery.
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

/// Test-only knob. Setting `maxMillis` to a small value (e.g. `1`) caps the retry
/// backoff so test suites don't spend real seconds sleeping. Internal — tests access
/// it through `@testable import`.
enum TransportBackoffOverride {
    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Int?

        var maxMillis: Int? {
            get { lock.lock(); defer { lock.unlock() }; return value }
            set { lock.lock(); defer { lock.unlock() }; value = newValue }
        }
    }

    private static let box = Box()

    static var maxMillis: Int? {
        get { box.maxMillis }
        set { box.maxMillis = newValue }
    }
}

// MARK: - Percent encoding helpers

/// Allowed unreserved characters per RFC 3986. We explicitly disallow `=`, `&`, `?`, `#`,
/// `+` (space ambiguity), `>`, `<` so `StartTime>` round-trips.
private let queryAllowed: CharacterSet = {
    var s = CharacterSet()
    s.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    return s
}()

func percentEncodeQueryComponent(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? s
}

/// Form bodies have the same rules as query strings under
/// `application/x-www-form-urlencoded` except spaces traditionally become `+`. We use
/// `%20` instead — both are accepted by every standards-compliant server.
func percentEncodeFormComponent(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? s
}

/// Percent-encode a single path segment, escaping everything outside the RFC
/// 3986 unreserved set (so an E.164 `+` becomes `%2B`).
func percentEncodePathSegment(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? s
}

// MARK: - Secret redaction

extension Transport: CustomReflectable, CustomDebugStringConvertible {
    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "accountSid": accountSid,
                "baseURL": baseURL,
                "userAgent": userAgent,
                "apiKey": "<redacted>",
                "timeout": timeout,
                "resourceTimeout": resourceTimeout,
                "maxRetries": maxRetries,
            ],
            displayStyle: .class
        )
    }

    public var debugDescription: String {
        "Transport(accountSid: \(accountSid), baseURL: \(baseURL), apiKey: <redacted>, maxRetries: \(maxRetries))"
    }
}
