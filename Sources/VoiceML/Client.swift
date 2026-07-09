import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
    public let incomingPhoneNumbers: IncomingPhoneNumbersResource
    public let messages: MessagesResource
    public let messagingV1: MessagingV1Resource
    public let notifications: NotificationsResource
    public let pricing: PricingResource
    public let sip: SipResource
    public let routesV2: RoutesV2Resource
    public let voiceV1: VoiceV1Resource
    public let conversationsV1: ConversationsV1Resource
    public let assistantsV1: AssistantsV1Resource
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

        // Conversations and Messaging Service ride their own product subdomains
        // (they share the /v1/Services path shape — host is what disambiguates
        // them). Each gets a sibling transport pinned to its product host that
        // shares this client's session, auth, and retry policy.
        let hosts = resolveProductBaseURLs(
            baseURL: options.baseURL,
            messagingBaseURL: options.messagingBaseURL,
            conversationsBaseURL: options.conversationsBaseURL
        )
        let messagingTransport = try transport.scoped(to: hosts.messaging)
        let conversationsTransport = try transport.scoped(to: hosts.conversations)

        self.calls = CallsResource(transport: transport)
        self.conferences = ConferencesResource(transport: transport)
        self.queues = QueuesResource(transport: transport)
        self.applications = ApplicationsResource(transport: transport)
        self.recordings = RecordingsResource(transport: transport)
        self.incomingPhoneNumbers = IncomingPhoneNumbersResource(transport: transport)
        self.messages = MessagesResource(transport: transport)
        self.messagingV1 = MessagingV1Resource(transport: messagingTransport)
        self.notifications = NotificationsResource(transport: transport)
        self.pricing = PricingResource(transport: transport)
        self.sip = SipResource(transport: transport)
        self.routesV2 = RoutesV2Resource(transport: transport)
        self.voiceV1 = VoiceV1Resource(transport: transport)
        self.conversationsV1 = ConversationsV1Resource(transport: conversationsTransport)
        self.assistantsV1 = AssistantsV1Resource(transport: transport)
        self.diagnostics = DiagnosticsResource(transport: transport)
    }

    /// Convenience initializer matching the Python/TS SDK constructor shape.
    ///
    /// Pass either `apiKey:` or `authToken:` — they're aliases (Twilio's terminology
    /// for the same Basic-auth password). Supplying both throws ``ConfigurationError``
    /// rather than silently picking one; supplying neither also throws.
    public convenience init(
        accountSid: String,
        apiKey: String? = nil,
        authToken: String? = nil,
        baseURL: URL = URL(string: "https://voiceml.voicetel.com")!,
        messagingBaseURL: URL? = nil,
        conversationsBaseURL: URL? = nil,
        timeout: TimeInterval = 30,
        maxRetries: Int = 2,
        userAgent: String? = nil,
        session: URLSession? = nil
    ) throws {
        if apiKey != nil && authToken != nil {
            throw ConfigurationError("specify either apiKey or authToken, not both")
        }
        guard let secret = apiKey ?? authToken else {
            throw ConfigurationError("apiKey (or authToken) is required")
        }
        try self.init(options: ClientOptions(
            accountSid: accountSid,
            apiKey: secret,
            baseURL: baseURL,
            messagingBaseURL: messagingBaseURL,
            conversationsBaseURL: conversationsBaseURL,
            timeout: timeout,
            maxRetries: maxRetries,
            userAgent: userAgent ?? "voiceml-swift/\(voiceMLVersion)",
            session: session
        ))
    }
}
