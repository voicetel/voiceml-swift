import Foundation

/// Top-level VoiceML client.
///
/// Construct once per `{accountSid, apiKey}` pair and reuse — the client is `Sendable`
/// and the underlying `URLSession` handles concurrent requests safely.
///
/// VoiceML uses HTTP Basic auth: `accountSid` (Twilio-format `"AC"` + 32 hex) is the
/// username and `apiKey` is the password. This matches Twilio's constructor shape — code
/// that already works against Twilio's API translates with only the base URL changed.
///
/// ```swift
/// let client = try VoiceMLClient(accountSid: "AC…", apiKey: "…")
/// let call = try await client.calls.create(.init(
///     to: "+18005551234",
///     from: "+18005550000",
///     url: "https://example.com/twiml"
/// ))
/// ```
public final class VoiceMLClient: Sendable {
    public let calls: CallsResource
    public let conferences: ConferencesResource
    public let queues: QueuesResource
    public let applications: ApplicationsResource
    public let recordings: RecordingsResource
    public let diagnostics: DiagnosticsResource

    public let accountSid: String
    public let baseURL: URL

    // Retained internally for resources; not part of the public surface yet because
    // `VoiceMLRequest` is internal.
    internal let transport: Transport

    public init(options: ClientOptions) throws {
        let transport = try Transport(options: options)
        self.transport = transport
        self.accountSid = transport.accountSid
        self.baseURL = transport.baseURL
        self.calls = CallsResource(transport: transport)
        self.conferences = ConferencesResource(transport: transport)
        self.queues = QueuesResource(transport: transport)
        self.applications = ApplicationsResource(transport: transport)
        self.recordings = RecordingsResource(transport: transport)
        self.diagnostics = DiagnosticsResource(transport: transport)
    }

    /// Convenience initializer matching the Python/TS SDK constructor shape.
    public convenience init(
        accountSid: String,
        apiKey: String,
        baseURL: URL = URL(string: "https://voiceml.voicetel.com")!,
        timeout: TimeInterval = 30,
        maxRetries: Int = 2,
        userAgent: String? = nil,
        session: URLSession? = nil
    ) throws {
        try self.init(options: ClientOptions(
            accountSid: accountSid,
            apiKey: apiKey,
            baseURL: baseURL,
            timeout: timeout,
            maxRetries: maxRetries,
            userAgent: userAgent ?? "voiceml-swift/\(voiceMLVersion)",
            session: session
        ))
    }
}
