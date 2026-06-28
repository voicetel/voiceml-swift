import Foundation

/// `client.conversationsV1` — Twilio Conversations v1
/// (conversations.twilio.com/v1) namespace. 15 resources keyed by SID;
/// account resolves from HTTP Basic auth so no /Accounts/{Sid}/ prefix.
public final class ConversationsV1Resource: Sendable {
    public let conversations: ConversationsV1ConversationsResource
    public let roles: ConversationsV1RolesResource
    public let users: ConversationsV1UsersResource
    public let credentials: ConversationsV1CredentialsResource
    public let configuration: ConversationsV1ConfigurationResource
    public let participantConversations: ConversationsV1ParticipantConversationsResource
    public let conversationWithParticipants: ConversationsV1ConversationWithParticipantsResource
    public let services: ConversationsV1ServicesResource

    init(transport: Transport) {
        self.conversations = ConversationsV1ConversationsResource(transport: transport)
        self.roles = ConversationsV1RolesResource(transport: transport)
        self.users = ConversationsV1UsersResource(transport: transport)
        self.credentials = ConversationsV1CredentialsResource(transport: transport)
        self.configuration = ConversationsV1ConfigurationResource(transport: transport)
        self.participantConversations = ConversationsV1ParticipantConversationsResource(transport: transport)
        self.conversationWithParticipants = ConversationsV1ConversationWithParticipantsResource(transport: transport)
        self.services = ConversationsV1ServicesResource(transport: transport)
    }
}

// MARK: - Conversations (+ messages, participants, webhooks)

public final class ConversationsV1ConversationsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    // Conversations
    public func create(_ body: CreateConversationRequest = .init()) async throws -> ConversationsV1Conversation {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Conversations", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ConversationList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations", query: params.queryItems()))
    }
    public func fetch(conversationSid: String) async throws -> ConversationsV1Conversation {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations/\(conversationSid)"))
    }
    public func update(conversationSid: String, _ body: UpdateConversationRequest) async throws -> ConversationsV1Conversation {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Conversations/\(conversationSid)", form: body.formFields()))
    }
    public func delete(conversationSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Conversations/\(conversationSid)"))
    }

    /// `client.conversationsV1.conversations.messages(conversationSid:)` — accessor for the
    /// per-conversation Messages sub-resource.
    public func messages(conversationSid: String) -> ConversationsV1ConversationMessagesResource {
        ConversationsV1ConversationMessagesResource(transport: transport, conversationSid: conversationSid)
    }

    /// Per-conversation Participants accessor.
    public func participants(conversationSid: String) -> ConversationsV1ConversationParticipantsResource {
        ConversationsV1ConversationParticipantsResource(transport: transport, conversationSid: conversationSid)
    }

    /// Per-conversation scoped Webhooks accessor.
    public func webhooks(conversationSid: String) -> ConversationsV1ConversationScopedWebhooksResource {
        ConversationsV1ConversationScopedWebhooksResource(transport: transport, conversationSid: conversationSid)
    }
}

// MARK: - Conversation messages (+ receipts)

public final class ConversationsV1ConversationMessagesResource: Sendable {
    private let transport: Transport
    private let conversationSid: String
    init(transport: Transport, conversationSid: String) {
        self.transport = transport; self.conversationSid = conversationSid
    }

    public func create(_ body: CreateConversationMessageRequest = .init()) async throws -> ConversationsV1ConversationMessage {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Conversations/\(conversationSid)/Messages", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ConversationMessageList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations/\(conversationSid)/Messages", query: params.queryItems()))
    }
    public func fetch(messageSid: String) async throws -> ConversationsV1ConversationMessage {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations/\(conversationSid)/Messages/\(messageSid)"))
    }
    public func update(messageSid: String, _ body: UpdateConversationMessageRequest) async throws -> ConversationsV1ConversationMessage {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Conversations/\(conversationSid)/Messages/\(messageSid)", form: body.formFields()))
    }
    public func delete(messageSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Conversations/\(conversationSid)/Messages/\(messageSid)"))
    }

    /// Per-message Receipts accessor (read-only).
    public func receipts(messageSid: String) -> ConversationsV1ConversationMessageReceiptsResource {
        ConversationsV1ConversationMessageReceiptsResource(
            transport: transport,
            conversationSid: conversationSid,
            messageSid: messageSid
        )
    }
}

public final class ConversationsV1ConversationMessageReceiptsResource: Sendable {
    private let transport: Transport
    private let conversationSid: String
    private let messageSid: String
    init(transport: Transport, conversationSid: String, messageSid: String) {
        self.transport = transport
        self.conversationSid = conversationSid
        self.messageSid = messageSid
    }

    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ConversationMessageReceiptList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations/\(conversationSid)/Messages/\(messageSid)/Receipts", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> ConversationsV1ConversationMessageReceipt {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations/\(conversationSid)/Messages/\(messageSid)/Receipts/\(sid)"))
    }
}

// MARK: - Conversation participants

public final class ConversationsV1ConversationParticipantsResource: Sendable {
    private let transport: Transport
    private let conversationSid: String
    init(transport: Transport, conversationSid: String) {
        self.transport = transport; self.conversationSid = conversationSid
    }

    public func create(_ body: CreateConversationParticipantRequest = .init()) async throws -> ConversationsV1ConversationParticipant {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Conversations/\(conversationSid)/Participants", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ConversationParticipantList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations/\(conversationSid)/Participants", query: params.queryItems()))
    }
    public func fetch(participantSid: String) async throws -> ConversationsV1ConversationParticipant {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations/\(conversationSid)/Participants/\(participantSid)"))
    }
    public func update(participantSid: String, _ body: UpdateConversationParticipantRequest) async throws -> ConversationsV1ConversationParticipant {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Conversations/\(conversationSid)/Participants/\(participantSid)", form: body.formFields()))
    }
    public func delete(participantSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Conversations/\(conversationSid)/Participants/\(participantSid)"))
    }
}

// MARK: - Conversation scoped webhooks

public final class ConversationsV1ConversationScopedWebhooksResource: Sendable {
    private let transport: Transport
    private let conversationSid: String
    init(transport: Transport, conversationSid: String) {
        self.transport = transport; self.conversationSid = conversationSid
    }

    public func create(_ body: CreateConversationScopedWebhookRequest) async throws -> ConversationsV1ConversationScopedWebhook {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Conversations/\(conversationSid)/Webhooks", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ConversationScopedWebhookList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations/\(conversationSid)/Webhooks", query: params.queryItems()))
    }
    public func fetch(webhookSid: String) async throws -> ConversationsV1ConversationScopedWebhook {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Conversations/\(conversationSid)/Webhooks/\(webhookSid)"))
    }
    public func update(webhookSid: String, _ body: UpdateConversationScopedWebhookRequest) async throws -> ConversationsV1ConversationScopedWebhook {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Conversations/\(conversationSid)/Webhooks/\(webhookSid)", form: body.formFields()))
    }
    public func delete(webhookSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Conversations/\(conversationSid)/Webhooks/\(webhookSid)"))
    }
}

// MARK: - Roles

public final class ConversationsV1RolesResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateRoleRequest) async throws -> ConversationsV1Role {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Roles", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1RoleList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Roles", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> ConversationsV1Role {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Roles/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateRoleRequest) async throws -> ConversationsV1Role {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Roles/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Roles/\(sid)"))
    }
}

// MARK: - Users (+ user conversations)

public final class ConversationsV1UsersResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateUserRequest) async throws -> ConversationsV1User {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Users", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1UserList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Users", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> ConversationsV1User {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Users/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateUserRequest) async throws -> ConversationsV1User {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Users/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Users/\(sid)"))
    }

    /// Per-user Conversations accessor.
    public func conversations(userSid: String) -> ConversationsV1UserConversationsResource {
        ConversationsV1UserConversationsResource(transport: transport, userSid: userSid)
    }
}

public final class ConversationsV1UserConversationsResource: Sendable {
    private let transport: Transport
    private let userSid: String
    init(transport: Transport, userSid: String) {
        self.transport = transport; self.userSid = userSid
    }

    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1UserConversationList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Users/\(userSid)/Conversations", query: params.queryItems()))
    }
    public func fetch(conversationSid: String) async throws -> ConversationsV1UserConversation {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Users/\(userSid)/Conversations/\(conversationSid)"))
    }
    public func update(conversationSid: String, _ body: UpdateUserConversationRequest) async throws -> ConversationsV1UserConversation {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Users/\(userSid)/Conversations/\(conversationSid)", form: body.formFields()))
    }
    public func delete(conversationSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Users/\(userSid)/Conversations/\(conversationSid)"))
    }
}

// MARK: - Credentials

public final class ConversationsV1CredentialsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateConversationsCredentialRequest) async throws -> ConversationsV1Credential {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Credentials", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1CredentialList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Credentials", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> ConversationsV1Credential {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Credentials/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateConversationsCredentialRequest) async throws -> ConversationsV1Credential {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Credentials/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Credentials/\(sid)"))
    }
}

// MARK: - Configuration (+ webhooks, addresses)

public final class ConversationsV1ConfigurationResource: Sendable {
    public let webhooks: ConversationsV1ConfigurationWebhooksResource
    public let addresses: ConversationsV1ConfigAddressesResource

    private let transport: Transport
    init(transport: Transport) {
        self.transport = transport
        self.webhooks = ConversationsV1ConfigurationWebhooksResource(transport: transport)
        self.addresses = ConversationsV1ConfigAddressesResource(transport: transport)
    }

    public func fetch() async throws -> ConversationsV1Configuration {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Configuration"))
    }
    public func update(_ body: UpdateConfigurationRequest = .init()) async throws -> ConversationsV1Configuration {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Configuration", form: body.formFields()))
    }
}

public final class ConversationsV1ConfigurationWebhooksResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func fetch() async throws -> ConversationsV1ConfigurationWebhook {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Configuration/Webhooks"))
    }
    public func update(_ body: UpdateConfigurationWebhookRequest = .init()) async throws -> ConversationsV1ConfigurationWebhook {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Configuration/Webhooks", form: body.formFields()))
    }
}

public final class ConversationsV1ConfigAddressesResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateConfigAddressRequest) async throws -> ConversationsV1ConfigAddress {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Configuration/Addresses", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ConfigAddressList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Configuration/Addresses", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> ConversationsV1ConfigAddress {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Configuration/Addresses/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateConfigAddressRequest) async throws -> ConversationsV1ConfigAddress {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Configuration/Addresses/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Configuration/Addresses/\(sid)"))
    }
}

// MARK: - ParticipantConversations (read-only, account-scoped)

public final class ConversationsV1ParticipantConversationsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func list(_ params: ListParticipantConversationParams = .init()) async throws -> ConversationsV1ParticipantConversationList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/ParticipantConversations", query: params.queryItems()))
    }
}

// MARK: - ConversationWithParticipants (single create)

public final class ConversationsV1ConversationWithParticipantsResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateConversationWithParticipantsRequest = .init()) async throws -> ConversationsV1ConversationWithParticipants {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/ConversationWithParticipants", form: body.formFields()))
    }
}

// MARK: - Services

public final class ConversationsV1ServicesResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func create(_ body: CreateConversationServiceRequest) async throws -> ConversationsV1Service {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ServiceList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services", query: params.queryItems()))
    }
    public func fetch(chatServiceSid: String) async throws -> ConversationsV1Service {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)"))
    }
    public func delete(chatServiceSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Services/\(chatServiceSid)"))
    }

    /// `client.conversationsV1.services.scope(chatServiceSid:)` — accessor for
    /// the Phase 4 service-scoped sub-tree under
    /// `/v1/Services/{ChatServiceSid}/...` (conversations, users, roles,
    /// bindings, configuration, etc.).
    public func scope(chatServiceSid: String) -> ConversationsV1ServiceScopeResource {
        ConversationsV1ServiceScopeResource(transport: transport, chatServiceSid: chatServiceSid)
    }
}
