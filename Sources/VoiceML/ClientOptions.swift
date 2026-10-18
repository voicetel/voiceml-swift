import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Configuration for ``VoiceMLClient``.
///
/// At minimum, supply `accountSid` and `apiKey`. The rest carry sensible defaults that
/// match the TypeScript and Python SDKs.
public struct ClientOptions: Sendable {
    /// Twilio-format AccountSid: literal `"AC"` + 32 hex characters.
    public let accountSid: String

    /// Per-tenant API key. Sent as the Basic-auth password.
    public let apiKey: String

    /// Server base URL. Defaults to `https://voiceml.voicetel.com`.
    public let baseURL: URL

    /// Override the Messaging Service host. When nil it's derived from `baseURL`
    /// (swap the `voiceml` label → `messaging` for `*.voicetel.com` hosts).
    public let messagingBaseURL: URL?

    /// Override the Conversations host. When nil it's derived from `baseURL`
    /// (swap the `voiceml` label → `conversations` for `*.voicetel.com` hosts).
    public let conversationsBaseURL: URL?

    /// Per-request (idle) timeout in seconds. Defaults to 30.
    public let timeout: TimeInterval

    /// Whole-resource transfer timeout in seconds — caps the entire request including
    /// body transfer, so large downloads (recording audio, exports) get room beyond the
    /// idle timeout. Defaults to 300. Must be >= `timeout`.
    public let resourceTimeout: TimeInterval

    /// Retry attempts for transient failures. Defaults to 2 (so up to 3 total attempts
    /// per call). GET/PUT/DELETE retry on 429/500/502/503/504 and transport errors;
    /// POST retries only on 429 and connection-establishment failures.
    public let maxRetries: Int

    /// Override the User-Agent header. Mainly for tests.
    public let userAgent: String

    /// Inject a custom `URLSession`. Tests use this to swap in a session configured with
    /// a `URLProtocol` mock; in production leave it nil and the SDK builds its own.
    public let session: URLSession?

    public init(
        accountSid: String,
        apiKey: String,
        baseURL: URL = URL(string: "https://voiceml.voicetel.com")!,
        messagingBaseURL: URL? = nil,
        conversationsBaseURL: URL? = nil,
        timeout: TimeInterval = 30,
        resourceTimeout: TimeInterval = 300,
        maxRetries: Int = 2,
        userAgent: String = "voiceml-swift/\(voiceMLVersion)",
        session: URLSession? = nil
    ) {
        self.accountSid = accountSid
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.messagingBaseURL = messagingBaseURL
        self.conversationsBaseURL = conversationsBaseURL
        self.timeout = timeout
        self.resourceTimeout = resourceTimeout
        self.maxRetries = maxRetries
        self.userAgent = userAgent
        self.session = session
    }
}

// MARK: - Secret redaction

extension ClientOptions: CustomReflectable, CustomDebugStringConvertible {
    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "accountSid": accountSid,
                "apiKey": "<redacted>",
                "baseURL": baseURL,
                "messagingBaseURL": messagingBaseURL as Any,
                "conversationsBaseURL": conversationsBaseURL as Any,
                "timeout": timeout,
                "resourceTimeout": resourceTimeout,
                "maxRetries": maxRetries,
                "userAgent": userAgent,
            ],
            displayStyle: .struct
        )
    }

    public var debugDescription: String {
        "ClientOptions(accountSid: \(accountSid), apiKey: <redacted>, baseURL: \(baseURL), maxRetries: \(maxRetries))"
    }
}
