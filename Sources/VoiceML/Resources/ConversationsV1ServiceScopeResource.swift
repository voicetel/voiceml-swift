import Foundation

// Phase 4 — service-scoped Conversations v1 surface, rooted at
// `/v1/Services/{ChatServiceSid}/...`.
//
// Entry point: `client.conversationsV1.services.scope(chatServiceSid:)`
// returns a `ConversationsV1ServiceScopeResource` that mirrors the
// account-level nested layout (conversations, conversations.messages,
// conversations.messages.receipts, conversations.participants,
// conversations.webhooks, conversationWithParticipants, participantConversations,
// users, users.conversations, roles, bindings, configuration,
// configuration.notifications, configuration.webhooks).

// MARK: - Scope root

/// Service-scoped sub-tree of `client.conversationsV1.services`.
///
/// ```
/// let svc = client.conversationsV1.services.scope(chatServiceSid: "IS…")
/// try await svc.conversations.list()
/// try await svc.users.create(.init(identity: "alice"))
/// ```
public final class ConversationsV1ServiceScopeResource: Sendable {
    public let conversations: ConversationsV1ServiceConversationsResource
    public let roles: ConversationsV1ServiceRolesResource
    public let users: ConversationsV1ServiceUsersResource
    public let bindings: ConversationsV1ServiceBindingsResource
    public let configuration: ConversationsV1ServiceConfigurationResource
    public let conversationWithParticipants: ConversationsV1ServiceConversationWithParticipantsResource
    public let participantConversations: ConversationsV1ServiceParticipantConversationsResource

    public let chatServiceSid: String

    init(transport: Transport, chatServiceSid: String) {
        self.chatServiceSid = chatServiceSid
        self.conversations = ConversationsV1ServiceConversationsResource(transport: transport, chatServiceSid: chatServiceSid)
        self.roles = ConversationsV1ServiceRolesResource(transport: transport, chatServiceSid: chatServiceSid)
        self.users = ConversationsV1ServiceUsersResource(transport: transport, chatServiceSid: chatServiceSid)
        self.bindings = ConversationsV1ServiceBindingsResource(transport: transport, chatServiceSid: chatServiceSid)
        self.configuration = ConversationsV1ServiceConfigurationResource(transport: transport, chatServiceSid: chatServiceSid)
        self.conversationWithParticipants = ConversationsV1ServiceConversationWithParticipantsResource(transport: transport, chatServiceSid: chatServiceSid)
        self.participantConversations = ConversationsV1ServiceParticipantConversationsResource(transport: transport, chatServiceSid: chatServiceSid)
    }
}

// MARK: - Service-scoped Conversations (+ messages, participants, webhooks)

public final class ConversationsV1ServiceConversationsResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport; self.chatServiceSid = chatServiceSid
    }

    public func create(_ body: CreateServiceConversationRequest = .init()) async throws -> ConversationsV1ServiceConversation {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Conversations", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ServiceConversationList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations", query: params.queryItems()))
    }
    public func fetch(conversationSid: String) async throws -> ConversationsV1ServiceConversation {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)"))
    }
    public func update(conversationSid: String, _ body: UpdateServiceConversationRequest) async throws -> ConversationsV1ServiceConversation {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)", form: body.formFields()))
    }
    public func delete(conversationSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)"))
    }

    /// Per-conversation Messages sub-resource accessor.
    public func messages(conversationSid: String) -> ConversationsV1ServiceConversationMessagesResource {
        ConversationsV1ServiceConversationMessagesResource(transport: transport, chatServiceSid: chatServiceSid, conversationSid: conversationSid)
    }

    /// Per-conversation Participants sub-resource accessor.
    public func participants(conversationSid: String) -> ConversationsV1ServiceConversationParticipantsResource {
        ConversationsV1ServiceConversationParticipantsResource(transport: transport, chatServiceSid: chatServiceSid, conversationSid: conversationSid)
    }

    /// Per-conversation scoped Webhooks sub-resource accessor.
    public func webhooks(conversationSid: String) -> ConversationsV1ServiceConversationScopedWebhooksResource {
        ConversationsV1ServiceConversationScopedWebhooksResource(transport: transport, chatServiceSid: chatServiceSid, conversationSid: conversationSid)
    }
}

// MARK: - Service-scoped Conversation Messages (+ receipts)

public final class ConversationsV1ServiceConversationMessagesResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    private let conversationSid: String
    init(transport: Transport, chatServiceSid: String, conversationSid: String) {
        self.transport = transport
        self.chatServiceSid = chatServiceSid
        self.conversationSid = conversationSid
    }

    public func create(_ body: CreateServiceConversationMessageRequest = .init()) async throws -> ConversationsV1ServiceConversationMessage {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Messages", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ServiceConversationMessageList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Messages", query: params.queryItems()))
    }
    public func fetch(messageSid: String) async throws -> ConversationsV1ServiceConversationMessage {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Messages/\(messageSid)"))
    }
    public func update(messageSid: String, _ body: UpdateServiceConversationMessageRequest) async throws -> ConversationsV1ServiceConversationMessage {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Messages/\(messageSid)", form: body.formFields()))
    }
    public func delete(messageSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Messages/\(messageSid)"))
    }

    /// Per-message Receipts sub-resource (read-only).
    public func receipts(messageSid: String) -> ConversationsV1ServiceConversationMessageReceiptsResource {
        ConversationsV1ServiceConversationMessageReceiptsResource(
            transport: transport,
            chatServiceSid: chatServiceSid,
            conversationSid: conversationSid,
            messageSid: messageSid
        )
    }
}

public final class ConversationsV1ServiceConversationMessageReceiptsResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    private let conversationSid: String
    private let messageSid: String
    init(transport: Transport, chatServiceSid: String, conversationSid: String, messageSid: String) {
        self.transport = transport
        self.chatServiceSid = chatServiceSid
        self.conversationSid = conversationSid
        self.messageSid = messageSid
    }

    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ServiceConversationMessageReceiptList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Messages/\(messageSid)/Receipts", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> ConversationsV1ServiceConversationMessageReceipt {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Messages/\(messageSid)/Receipts/\(sid)"))
    }
}

// MARK: - Service-scoped Conversation Participants

public final class ConversationsV1ServiceConversationParticipantsResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    private let conversationSid: String
    init(transport: Transport, chatServiceSid: String, conversationSid: String) {
        self.transport = transport
        self.chatServiceSid = chatServiceSid
        self.conversationSid = conversationSid
    }

    public func create(_ body: CreateServiceConversationParticipantRequest = .init()) async throws -> ConversationsV1ServiceConversationParticipant {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Participants", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ServiceConversationParticipantList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Participants", query: params.queryItems()))
    }
    public func fetch(participantSid: String) async throws -> ConversationsV1ServiceConversationParticipant {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Participants/\(participantSid)"))
    }
    public func update(participantSid: String, _ body: UpdateServiceConversationParticipantRequest) async throws -> ConversationsV1ServiceConversationParticipant {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Participants/\(participantSid)", form: body.formFields()))
    }
    public func delete(participantSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Participants/\(participantSid)"))
    }
}

// MARK: - Service-scoped Conversation Scoped Webhooks

public final class ConversationsV1ServiceConversationScopedWebhooksResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    private let conversationSid: String
    init(transport: Transport, chatServiceSid: String, conversationSid: String) {
        self.transport = transport
        self.chatServiceSid = chatServiceSid
        self.conversationSid = conversationSid
    }

    public func create(_ body: CreateServiceConversationScopedWebhookRequest) async throws -> ConversationsV1ServiceConversationScopedWebhook {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Webhooks", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ServiceConversationScopedWebhookList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Webhooks", query: params.queryItems()))
    }
    public func fetch(webhookSid: String) async throws -> ConversationsV1ServiceConversationScopedWebhook {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Webhooks/\(webhookSid)"))
    }
    public func update(webhookSid: String, _ body: UpdateServiceConversationScopedWebhookRequest) async throws -> ConversationsV1ServiceConversationScopedWebhook {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Webhooks/\(webhookSid)", form: body.formFields()))
    }
    public func delete(webhookSid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Services/\(chatServiceSid)/Conversations/\(conversationSid)/Webhooks/\(webhookSid)"))
    }
}

// MARK: - Service-scoped Roles

public final class ConversationsV1ServiceRolesResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport; self.chatServiceSid = chatServiceSid
    }

    public func create(_ body: CreateServiceRoleRequest) async throws -> ConversationsV1ServiceRole {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Roles", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ServiceRoleList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Roles", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> ConversationsV1ServiceRole {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Roles/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateServiceRoleRequest) async throws -> ConversationsV1ServiceRole {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Roles/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Services/\(chatServiceSid)/Roles/\(sid)"))
    }
}

// MARK: - Service-scoped Users (+ user conversations)

public final class ConversationsV1ServiceUsersResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport; self.chatServiceSid = chatServiceSid
    }

    public func create(_ body: CreateServiceUserRequest) async throws -> ConversationsV1ServiceUser {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Users", form: body.formFields()))
    }
    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ServiceUserList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Users", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> ConversationsV1ServiceUser {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Users/\(sid)"))
    }
    public func update(sid: String, _ body: UpdateServiceUserRequest) async throws -> ConversationsV1ServiceUser {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Users/\(sid)", form: body.formFields()))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Services/\(chatServiceSid)/Users/\(sid)"))
    }

    /// Per-user Conversations accessor (read-only join view).
    public func conversations(userSid: String) -> ConversationsV1ServiceUserConversationsResource {
        ConversationsV1ServiceUserConversationsResource(transport: transport, chatServiceSid: chatServiceSid, userSid: userSid)
    }
}

public final class ConversationsV1ServiceUserConversationsResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    private let userSid: String
    init(transport: Transport, chatServiceSid: String, userSid: String) {
        self.transport = transport
        self.chatServiceSid = chatServiceSid
        self.userSid = userSid
    }

    public func list(_ params: ListV1PageParams = .init()) async throws -> ConversationsV1ServiceUserConversationList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Users/\(userSid)/Conversations", query: params.queryItems()))
    }
}

// MARK: - Service-scoped ConversationWithParticipants (single create)

public final class ConversationsV1ServiceConversationWithParticipantsResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport; self.chatServiceSid = chatServiceSid
    }

    public func create(_ body: CreateServiceConversationWithParticipantsRequest = .init()) async throws -> ConversationsV1ServiceConversationWithParticipants {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/ConversationWithParticipants", form: body.formFields()))
    }
}

// MARK: - Service-scoped ParticipantConversations (read-only)

public final class ConversationsV1ServiceParticipantConversationsResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport; self.chatServiceSid = chatServiceSid
    }

    public func list(_ params: ListServiceParticipantConversationParams = .init()) async throws -> ConversationsV1ServiceParticipantConversationList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/ParticipantConversations", query: params.queryItems()))
    }
}

// MARK: - Service-scoped Bindings (list/fetch/delete)

public final class ConversationsV1ServiceBindingsResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport; self.chatServiceSid = chatServiceSid
    }

    public func list(_ params: ListServiceBindingParams = .init()) async throws -> ConversationsV1ServiceBindingList {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Bindings", query: params.queryItems()))
    }
    public func fetch(sid: String) async throws -> ConversationsV1ServiceBinding {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Bindings/\(sid)"))
    }
    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(method: .delete, path: "/v1/Services/\(chatServiceSid)/Bindings/\(sid)"))
    }
}

// MARK: - Service-scoped Configuration (+ notifications, webhooks)

public final class ConversationsV1ServiceConfigurationResource: Sendable {
    public let notifications: ConversationsV1ServiceNotificationsResource
    public let webhooks: ConversationsV1ServiceWebhookConfigurationResource

    private let transport: Transport
    private let chatServiceSid: String

    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport
        self.chatServiceSid = chatServiceSid
        self.notifications = ConversationsV1ServiceNotificationsResource(transport: transport, chatServiceSid: chatServiceSid)
        self.webhooks = ConversationsV1ServiceWebhookConfigurationResource(transport: transport, chatServiceSid: chatServiceSid)
    }

    public func fetch() async throws -> ConversationsV1ServiceConfiguration {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Configuration"))
    }
    public func update(_ body: UpdateServiceConfigurationRequest = .init()) async throws -> ConversationsV1ServiceConfiguration {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Configuration", form: body.formFields()))
    }
}

public final class ConversationsV1ServiceNotificationsResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport; self.chatServiceSid = chatServiceSid
    }

    public func fetch() async throws -> ConversationsV1ServiceNotification {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Configuration/Notifications"))
    }
    public func update(_ body: UpdateServiceNotificationRequest = .init()) async throws -> ConversationsV1ServiceNotification {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Configuration/Notifications", form: body.formFields()))
    }
}

public final class ConversationsV1ServiceWebhookConfigurationResource: Sendable {
    private let transport: Transport
    private let chatServiceSid: String
    init(transport: Transport, chatServiceSid: String) {
        self.transport = transport; self.chatServiceSid = chatServiceSid
    }

    public func fetch() async throws -> ConversationsV1ServiceWebhookConfiguration {
        try await transport.request(VoiceMLRequest(method: .get, path: "/v1/Services/\(chatServiceSid)/Configuration/Webhooks"))
    }
    public func update(_ body: UpdateServiceWebhookConfigurationRequest = .init()) async throws -> ConversationsV1ServiceWebhookConfiguration {
        try await transport.request(VoiceMLRequest(method: .post, path: "/v1/Services/\(chatServiceSid)/Configuration/Webhooks", form: body.formFields()))
    }
}
