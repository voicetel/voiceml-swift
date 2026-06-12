import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HTTP method names used by the SDK. Twilio's REST surface only ever needs these four.
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

    /// Convenience for booleans → Twilio's literal "true"/"false" strings.
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
/// to ``Transport/request(_:)``.
struct VoiceMLRequest {
    var method: HTTPVerb
    var path: String
    var query: [QueryItem] = []
    var form: [FormField]? = nil
    var jsonBody: Data? = nil
}

/// Status codes that trigger automatic retry (transient server / rate-limit).
private let retryableStatuses: Set<Int> = [429, 500, 502, 503, 504]

/// Thin wrapper over `URLSession` that handles auth, encoding, retries, and error mapping.
///
/// The transport is intentionally a plain `final class` rather than an `actor`: `URLSession`
/// is already thread-safe, and the transport carries only immutable configuration after
/// construction. Mark `Sendable` so it can cross actor boundaries freely.
public final class Transport: @unchecked Sendable {
    public let accountSid: String
    public let baseURL: URL
    public let userAgent: String

    private let apiKey: String
    private let timeout: TimeInterval
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

        self.accountSid = options.accountSid
        self.apiKey = options.apiKey
        self.baseURL = try Self.normalizeBase(options.baseURL)
        self.timeout = options.timeout
        self.maxRetries = options.maxRetries
        self.userAgent = options.userAgent

        if let injected = options.session {
            self.session = injected
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = options.timeout
            cfg.timeoutIntervalForResource = options.timeout
            self.session = URLSession(configuration: cfg)
        }
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
            throw ApiError(
                message: "failed to decode response (status \(status)): \(error)",
                statusCode: status,
                body: data
            )
        }
    }

    /// Send a request with no expected response body.
    func requestVoid(_ req: VoiceMLRequest) async throws {
        _ = try await sendWithRetry(req)
    }

    /// Binary fetch — used by recordings.getAudio. Follows redirects (302 → S3).
    func fetchBytes(path: String) async throws -> (Data, HTTPURLResponse) {
        let url = buildURL(path: path, query: [])
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = "GET"
        urlReq.timeoutInterval = timeout
        applyHeaders(&urlReq, sendingJSON: false, sendingForm: false)

        let (data, response) = try await sessionData(for: urlReq)
        guard let http = response as? HTTPURLResponse else {
            throw ApiError(message: "non-HTTP response", statusCode: 0)
        }
        if !(200..<300).contains(http.statusCode) {
            throw decodeError(status: http.statusCode, data: data)
        }
        return (data, http)
    }

    // MARK: - Core send + retry loop

    private func sendWithRetry(_ req: VoiceMLRequest) async throws -> (Data, Int, HTTPURLResponse) {
        let urlReq = try buildURLRequest(req)

        var attempt = 0
        var lastError: Error?
        while attempt <= maxRetries {
            do {
                let (data, response) = try await sessionData(for: urlReq)
                guard let http = response as? HTTPURLResponse else {
                    throw ApiError(message: "non-HTTP response", statusCode: 0)
                }
                let status = http.statusCode
                if retryableStatuses.contains(status), attempt < maxRetries {
                    try await sleepForBackoff(attempt: attempt, response: http)
                    attempt += 1
                    continue
                }
                if !(200..<300).contains(status) {
                    throw decodeError(status: status, data: data)
                }
                return (data, status, http)
            } catch let err as ApiError {
                // Non-retryable API error — propagate immediately.
                throw err
            } catch {
                lastError = error
                if attempt >= maxRetries {
                    throw ApiError(
                        message: "transport error after \(attempt + 1) attempts: \(error)",
                        statusCode: 0
                    )
                }
                try await sleepForBackoff(attempt: attempt, response: nil)
                attempt += 1
            }
        }
        throw lastError ?? ApiError(message: "unreachable retry exhaustion", statusCode: 0)
    }

    // MARK: - Request construction

    private func buildURLRequest(_ req: VoiceMLRequest) throws -> URLRequest {
        let url = buildURL(path: req.path, query: req.query)
        var urlReq = URLRequest(url: url)
        urlReq.httpMethod = req.method.rawValue
        urlReq.timeoutInterval = timeout

        let sendingJSON = req.jsonBody != nil
        let sendingForm = req.form != nil && !sendingJSON

        applyHeaders(&urlReq, sendingJSON: sendingJSON, sendingForm: sendingForm)

        if let json = req.jsonBody {
            urlReq.httpBody = json
        } else if let form = req.form {
            urlReq.httpBody = Self.encodeForm(form)
        }
        return urlReq
    }

    private func applyHeaders(_ urlReq: inout URLRequest, sendingJSON: Bool, sendingForm: Bool) {
        urlReq.setValue("application/json", forHTTPHeaderField: "Accept")
        urlReq.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let credentials = "\(accountSid):\(apiKey)"
        if let encoded = credentials.data(using: .utf8)?.base64EncodedString() {
            urlReq.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
        }
        if sendingJSON {
            urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if sendingForm {
            urlReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
    }

    func buildURL(path: String, query: [QueryItem]) -> URL {
        // Append `.json` suffix to REST paths to match Twilio's canonical URL shape
        // (the v0.5.x server accepts both forms; this future-proofs us against the
        // bare-path form being deprecated). Skip if the path already carries a known
        // suffix (`.json`, `.yaml`, `.yml`, `.wav`) or is `/health`.
        let effectivePath = Self.applyJSONSuffix(path)

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
        let trimmedBasePath = baseURL.path.hasSuffix("/")
            ? String(baseURL.path.dropLast())
            : baseURL.path
        components.path = trimmedBasePath + effectivePath

        // Filter out items whose value is nil, then construct the query string manually.
        // We do this by hand (rather than via URLComponents.queryItems) because Twilio uses
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

    private func decodeError(status: Int, data: Data) -> ApiError {
        var code: String?
        var message = "HTTP \(status)"
        var moreInfo: String?
        if !data.isEmpty,
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let c = obj["code"] {
                code = String(describing: c)
            }
            if let m = obj["message"] as? String, !m.isEmpty {
                message = m
            }
            if let mi = obj["more_info"] as? String, !mi.isEmpty {
                moreInfo = mi
            }
        }
        return errorFromResponse(
            statusCode: status,
            code: code,
            body: data,
            message: message,
            moreInfo: moreInfo
        )
    }

    // MARK: - Backoff

    private func sleepForBackoff(attempt: Int, response: HTTPURLResponse?) async throws {
        let ms: Int
        if let r = response,
           let retryAfter = r.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryAfter) {
            ms = max(0, Int(seconds * 1000))
        } else {
            ms = min(8000, 500 * (1 << min(attempt, 5)))
        }
        // Tests cap this via `TransportBackoffOverride.maxMillis` to keep runs fast.
        let effective = TransportBackoffOverride.maxMillis.map { min($0, ms) } ?? ms
        try await Task.sleep(nanoseconds: UInt64(effective) * 1_000_000)
    }

    // MARK: - URLSession compat shim

    /// `URLSession.data(for:)` is only available on Apple platforms ≥ iOS 15/macOS 12 and
    /// not at all on the Linux/swift-corelibs `FoundationNetworking` build. This shim wraps
    /// the closure-based API in a continuation everywhere else.
    private func sessionData(for request: URLRequest) async throws -> (Data, URLResponse) {
        #if canImport(FoundationNetworking)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(Data, URLResponse), Error>) in
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    cont.resume(throwing: error)
                    return
                }
                guard let data = data, let response = response else {
                    cont.resume(throwing: ApiError(message: "empty response", statusCode: 0))
                    return
                }
                cont.resume(returning: (data, response))
            }
            task.resume()
        }
        #else
        return try await session.data(for: request)
        #endif
    }

    // MARK: - Helpers

    private static func normalizeBase(_ url: URL) throws -> URL {
        // HTTPS-only by construction. The SDK sends AccountSid + API key as HTTP
        // Basic auth on every request; cleartext over http:// would leak both.
        // Refusing the URL up-front is what proves to CodeQL's taint analysis
        // (`swift/cleartext-transmission`) that AccountSid never reaches an
        // unencrypted channel.
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
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
        let known = [".json", ".yaml", ".yml", ".wav"]
        for ext in known where basePath.hasSuffix(ext) {
            return path
        }
        return basePath + ".json" + suffix
    }
}

/// Sentinel for DELETE-style endpoints that legitimately return no body but still need
/// to participate in the generic `request<T>` machinery.
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}

/// Test-only knob. Setting `maxMillis` to a small value (e.g. `1`) caps the retry
/// backoff so test suites don't spend real seconds sleeping. Not part of the supported
/// public API; subject to change without notice.
public final class TransportBackoffOverride: @unchecked Sendable {
    private static let lock = NSLock()
    private static var _maxMillis: Int? = nil

    public static var maxMillis: Int? {
        get { lock.lock(); defer { lock.unlock() }; return _maxMillis }
        set { lock.lock(); defer { lock.unlock() }; _maxMillis = newValue }
    }

    private init() {}
}

// MARK: - Percent encoding helpers

/// Allowed unreserved characters per RFC 3986. We explicitly disallow `=`, `&`, `?`, `#`,
/// `+` (space ambiguity), `>`, `<` so Twilio's `StartTime>=` round-trips.
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
/// `%20` instead — both are accepted by every standards-compliant server (and by Twilio's
/// implementation).
func percentEncodeFormComponent(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: queryAllowed) ?? s
}
