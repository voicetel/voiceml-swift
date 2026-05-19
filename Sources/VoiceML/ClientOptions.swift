import Foundation

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

    /// Per-request timeout. Defaults to 30 seconds.
    public let timeout: TimeInterval

    /// Retry attempts for 429/5xx + transport errors. Defaults to 2 (so up to 3 total
    /// attempts per call).
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
        timeout: TimeInterval = 30,
        maxRetries: Int = 2,
        userAgent: String = "voiceml-swift/\(voiceMLVersion)",
        session: URLSession? = nil
    ) {
        self.accountSid = accountSid
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.userAgent = userAgent
        self.session = session
    }
}
