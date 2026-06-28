import Foundation

// Twilio Conversations v1 (conversations.twilio.com/v1) — 15 resources (#421):
//   Conversation, ConversationMessage, ConversationParticipant,
//   ConversationMessageReceipt, ConversationScopedWebhook, Role, User,
//   Credential, Configuration, ConfigurationWebhook, ConfigAddress,
//   ParticipantConversation, ConversationWithParticipants,
//   UserConversation, Service.
//
// Same /v1 conventions as Voice v1: Basic-auth account resolution,
// ISO-8601 dates, `meta` list envelope (shared V1Meta). Untyped JSON
// sub-objects (timers, links, bindings, attributes, messaging_binding,
// delivery, auto_creation, configuration) are surfaced as
// `FreeformJSONObject` (`[String: AnyJSON]`) so callers can introspect
// arbitrary shape without bringing in a third-party JSON dependency.
//
// Response structs are `Decodable` (not `Codable`) — they are only
// deserialized off the wire. Request bodies use manual `formFields()`
// instead of Encodable, so the asymmetry is intentional.
//
// String fields with closed enum domains (state, status, type,
// notification_level, method, target) are surfaced as `String` rather
// than Swift enums — that matches the parity-lint stance: an unknown
// enum value from a forward-rev'd server must not throw a decoding
// error. The valid-values list is documented inline.

// MARK: - AnyJSON (recursive, for freeform JSON sub-objects)

/// A recursive JSON value that can represent any well-formed JSON
/// payload (scalars, arrays, nested objects). Used for spec fields
/// typed as `object` with no inner schema (timers, links, bindings,
/// auto_creation, configuration, messaging_binding, delivery, media
/// items). Decode-only — these fields are response-side; request
/// bodies use dotted form keys instead.
public indirect enum AnyJSON: Decodable, Sendable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([AnyJSON])
    case object([String: AnyJSON])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let v = try? container.decode(Bool.self)   { self = .bool(v);   return }
        if let v = try? container.decode(Int.self)    { self = .int(v);    return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        if let v = try? container.decode([AnyJSON].self) { self = .array(v); return }
        if let v = try? container.decode([String: AnyJSON].self) { self = .object(v); return }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "unsupported JSON value"
        )
    }
}

/// Freeform JSON object alias — what Twilio fields like `timers`,
/// `links`, `bindings`, `auto_creation`, `messaging_binding`,
/// `configuration`, `delivery` decode into.
public typealias FreeformJSONObject = [String: AnyJSON]

// MARK: - Conversation

/// A stateful messaging thread. SID is `CH…`.
///
/// `state`: one of `initializing`, `inactive`, `active`, `closed`.
public struct ConversationsV1Conversation: Decodable, Sendable {
    public var accountSid: String?
    public var chatServiceSid: String?
    public var messagingServiceSid: String?
    public var sid: String?
    public var friendlyName: String?
    public var uniqueName: String?
    public var attributes: String?
    public var state: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var timers: FreeformJSONObject?
    public var url: String?
    public var links: FreeformJSONObject?
    public var bindings: FreeformJSONObject?
}

public struct ConversationsV1ConversationList: Decodable, Sendable {
    public var conversations: [ConversationsV1Conversation]
    public var meta: V1Meta
}

// MARK: - ConversationMessage

/// One message in a conversation. SID is `IM…`.
public struct ConversationsV1ConversationMessage: Decodable, Sendable {
    public var accountSid: String?
    public var conversationSid: String?
    public var sid: String?
    public var index: Int
    public var author: String?
    public var body: String?
    public var media: [FreeformJSONObject]?
    public var attributes: String?
    public var participantSid: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
    public var delivery: FreeformJSONObject?
    public var links: FreeformJSONObject?
    public var contentSid: String?
}

public struct ConversationsV1ConversationMessageList: Decodable, Sendable {
    public var messages: [ConversationsV1ConversationMessage]
    public var meta: V1Meta
}

// MARK: - ConversationParticipant

/// One participant in a conversation. SID is `MB…`.
public struct ConversationsV1ConversationParticipant: Decodable, Sendable {
    public var accountSid: String?
    public var conversationSid: String?
    public var sid: String?
    public var identity: String?
    public var attributes: String?
    public var messagingBinding: FreeformJSONObject?
    public var roleSid: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
    public var lastReadMessageIndex: Int?
    public var lastReadTimestamp: String?
}

public struct ConversationsV1ConversationParticipantList: Decodable, Sendable {
    public var participants: [ConversationsV1ConversationParticipant]
    public var meta: V1Meta
}

// MARK: - ConversationMessageReceipt

/// Per-channel delivery receipt for a message. SID is `DY…`.
///
/// `status`: one of `read`, `failed`, `delivered`, `undelivered`, `sent`.
public struct ConversationsV1ConversationMessageReceipt: Decodable, Sendable {
    public var accountSid: String?
    public var conversationSid: String?
    public var sid: String?
    public var messageSid: String?
    public var channelMessageSid: String?
    public var participantSid: String?
    public var status: String?
    public var errorCode: Int
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
}

public struct ConversationsV1ConversationMessageReceiptList: Decodable, Sendable {
    public var deliveryReceipts: [ConversationsV1ConversationMessageReceipt]
    public var meta: V1Meta
}

// MARK: - ConversationScopedWebhook

/// Conversation-scoped webhook subscription. SID is `WH…`.
public struct ConversationsV1ConversationScopedWebhook: Decodable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var conversationSid: String?
    public var target: String?
    public var url: String?
    public var configuration: FreeformJSONObject?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct ConversationsV1ConversationScopedWebhookList: Decodable, Sendable {
    public var webhooks: [ConversationsV1ConversationScopedWebhook]
    public var meta: V1Meta
}

// MARK: - Role

/// A Conversation-or-Service permissions role. SID is `RL…`.
///
/// `type`: one of `conversation`, `service`.
public struct ConversationsV1Role: Decodable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var chatServiceSid: String?
    public var friendlyName: String?
    public var type: String?
    public var permissions: [String]?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
}

public struct ConversationsV1RoleList: Decodable, Sendable {
    public var roles: [ConversationsV1Role]
    public var meta: V1Meta
}

// MARK: - User

/// A Conversations user. SID is `US…`.
public struct ConversationsV1User: Decodable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var chatServiceSid: String?
    public var roleSid: String?
    public var identity: String?
    public var friendlyName: String?
    public var attributes: String?
    public var isOnline: Bool?
    public var isNotifiable: Bool?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
    public var links: FreeformJSONObject?
}

public struct ConversationsV1UserList: Decodable, Sendable {
    public var users: [ConversationsV1User]
    public var meta: V1Meta
}

// MARK: - Credential (push)

/// Push-notification credential. SID is `CR…`.
///
/// `type`: one of `apn`, `gcm`, `fcm`.
public struct ConversationsV1Credential: Decodable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var friendlyName: String?
    public var type: String?
    public var sandbox: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
}

public struct ConversationsV1CredentialList: Decodable, Sendable {
    public var credentials: [ConversationsV1Credential]
    public var meta: V1Meta
}

// MARK: - Configuration

/// Account-level Conversations configuration. Singleton (no SID).
public struct ConversationsV1Configuration: Decodable, Sendable {
    public var accountSid: String?
    public var defaultChatServiceSid: String?
    public var defaultMessagingServiceSid: String?
    public var defaultInactiveTimer: String?
    public var defaultClosedTimer: String?
    public var url: String?
    public var links: FreeformJSONObject?
}

// MARK: - ConfigurationWebhook

/// Account-global webhook config. Singleton (no SID).
///
/// `method`: one of `GET`, `POST`. `target`: one of `webhook`, `flex`.
public struct ConversationsV1ConfigurationWebhook: Decodable, Sendable {
    public var accountSid: String?
    public var method: String?
    public var filters: [String]?
    public var preWebhookUrl: String?
    public var postWebhookUrl: String?
    public var target: String?
    public var url: String?
}

// MARK: - ConfigAddress

/// A configured address (sms / whatsapp / email / etc.). SID is `IG…`.
public struct ConversationsV1ConfigAddress: Decodable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var type: String?
    public var address: String?
    public var friendlyName: String?
    public var autoCreation: FreeformJSONObject?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
    public var addressCountry: String?
}

public struct ConversationsV1ConfigAddressList: Decodable, Sendable {
    public var addresses: [ConversationsV1ConfigAddress]
    public var meta: V1Meta
}

// MARK: - ParticipantConversation

/// Read-only join view: a participant and the conversation they're in.
///
/// `conversation_state`: one of `inactive`, `active`, `closed`.
public struct ConversationsV1ParticipantConversation: Decodable, Sendable {
    public var accountSid: String?
    public var chatServiceSid: String?
    public var participantSid: String?
    public var participantUserSid: String?
    public var participantIdentity: String?
    public var participantMessagingBinding: FreeformJSONObject?
    public var conversationSid: String?
    public var conversationUniqueName: String?
    public var conversationFriendlyName: String?
    public var conversationAttributes: String?
    public var conversationDateCreated: String?
    public var conversationDateUpdated: String?
    public var conversationCreatedBy: String?
    public var conversationState: String?
    public var conversationTimers: FreeformJSONObject?
    public var links: FreeformJSONObject?
}

public struct ConversationsV1ParticipantConversationList: Decodable, Sendable {
    public var conversations: [ConversationsV1ParticipantConversation]
    public var meta: V1Meta
}

// MARK: - ConversationWithParticipants

/// A conversation created with initial participants. Shape mirrors
/// ConversationsV1Conversation field-for-field.
public struct ConversationsV1ConversationWithParticipants: Decodable, Sendable {
    public var accountSid: String?
    public var chatServiceSid: String?
    public var messagingServiceSid: String?
    public var sid: String?
    public var friendlyName: String?
    public var uniqueName: String?
    public var attributes: String?
    public var state: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var timers: FreeformJSONObject?
    public var links: FreeformJSONObject?
    public var bindings: FreeformJSONObject?
    public var url: String?
}

// MARK: - UserConversation

/// A per-user view of a conversation (notification level, read state).
///
/// `conversation_state`: one of `inactive`, `active`, `closed`.
/// `notification_level`: one of `default`, `muted`.
public struct ConversationsV1UserConversation: Decodable, Sendable {
    public var accountSid: String?
    public var chatServiceSid: String?
    public var conversationSid: String?
    public var unreadMessagesCount: Int?
    public var lastReadMessageIndex: Int?
    public var participantSid: String?
    public var userSid: String?
    public var friendlyName: String?
    public var conversationState: String?
    public var timers: FreeformJSONObject?
    public var attributes: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var createdBy: String?
    public var notificationLevel: String?
    public var uniqueName: String?
    public var url: String?
    public var links: FreeformJSONObject?
}

public struct ConversationsV1UserConversationList: Decodable, Sendable {
    public var conversations: [ConversationsV1UserConversation]
    public var meta: V1Meta
}

// MARK: - Service

/// A Conversation Service container. SID is `IS…`.
public struct ConversationsV1Service: Decodable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var friendlyName: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var url: String?
    public var links: FreeformJSONObject?
}

public struct ConversationsV1ServiceList: Decodable, Sendable {
    public var services: [ConversationsV1Service]
    public var meta: V1Meta
}

// MARK: - Request bodies — Conversation

public struct CreateConversationRequest: Sendable {
    public var friendlyName: String?
    public var uniqueName: String?
    public var messagingServiceSid: String?
    public var attributes: String?
    public var state: String?
    public var timersInactive: String?
    public var timersClosed: String?
    public var bindingsEmailAddress: String?
    public var bindingsEmailName: String?
    public init(friendlyName: String? = nil, uniqueName: String? = nil,
                messagingServiceSid: String? = nil, attributes: String? = nil,
                state: String? = nil, timersInactive: String? = nil,
                timersClosed: String? = nil, bindingsEmailAddress: String? = nil,
                bindingsEmailName: String? = nil) {
        self.friendlyName = friendlyName
        self.uniqueName = uniqueName
        self.messagingServiceSid = messagingServiceSid
        self.attributes = attributes
        self.state = state
        self.timersInactive = timersInactive
        self.timersClosed = timersClosed
        self.bindingsEmailAddress = bindingsEmailAddress
        self.bindingsEmailName = bindingsEmailName
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = uniqueName { f.append(FormField("UniqueName", v)) }
        if let v = messagingServiceSid { f.append(FormField("MessagingServiceSid", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = state { f.append(FormField("State", v)) }
        if let v = timersInactive { f.append(FormField("Timers.Inactive", v)) }
        if let v = timersClosed { f.append(FormField("Timers.Closed", v)) }
        if let v = bindingsEmailAddress { f.append(FormField("Bindings.Email.Address", v)) }
        if let v = bindingsEmailName { f.append(FormField("Bindings.Email.Name", v)) }
        return f
    }
}

public struct UpdateConversationRequest: Sendable {
    public var friendlyName: String?
    public var uniqueName: String?
    public var messagingServiceSid: String?
    public var attributes: String?
    public var state: String?
    public var timersInactive: String?
    public var timersClosed: String?
    public init(friendlyName: String? = nil, uniqueName: String? = nil,
                messagingServiceSid: String? = nil, attributes: String? = nil,
                state: String? = nil, timersInactive: String? = nil,
                timersClosed: String? = nil) {
        self.friendlyName = friendlyName
        self.uniqueName = uniqueName
        self.messagingServiceSid = messagingServiceSid
        self.attributes = attributes
        self.state = state
        self.timersInactive = timersInactive
        self.timersClosed = timersClosed
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = uniqueName { f.append(FormField("UniqueName", v)) }
        if let v = messagingServiceSid { f.append(FormField("MessagingServiceSid", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = state { f.append(FormField("State", v)) }
        if let v = timersInactive { f.append(FormField("Timers.Inactive", v)) }
        if let v = timersClosed { f.append(FormField("Timers.Closed", v)) }
        return f
    }
}

// MARK: - Request bodies — ConversationMessage

public struct CreateConversationMessageRequest: Sendable {
    public var author: String?
    public var body: String?
    public var attributes: String?
    public var contentSid: String?
    public init(author: String? = nil, body: String? = nil,
                attributes: String? = nil, contentSid: String? = nil) {
        self.author = author
        self.body = body
        self.attributes = attributes
        self.contentSid = contentSid
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = author { f.append(FormField("Author", v)) }
        if let v = body { f.append(FormField("Body", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = contentSid { f.append(FormField("ContentSid", v)) }
        return f
    }
}

public struct UpdateConversationMessageRequest: Sendable {
    public var author: String?
    public var body: String?
    public var attributes: String?
    public init(author: String? = nil, body: String? = nil, attributes: String? = nil) {
        self.author = author; self.body = body; self.attributes = attributes
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = author { f.append(FormField("Author", v)) }
        if let v = body { f.append(FormField("Body", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        return f
    }
}

// MARK: - Request bodies — ConversationParticipant

public struct CreateConversationParticipantRequest: Sendable {
    public var identity: String?
    public var attributes: String?
    public var roleSid: String?
    public var messagingBindingAddress: String?
    public var messagingBindingProxyAddress: String?
    public var messagingBindingProjectedAddress: String?
    public init(identity: String? = nil, attributes: String? = nil, roleSid: String? = nil,
                messagingBindingAddress: String? = nil,
                messagingBindingProxyAddress: String? = nil,
                messagingBindingProjectedAddress: String? = nil) {
        self.identity = identity
        self.attributes = attributes
        self.roleSid = roleSid
        self.messagingBindingAddress = messagingBindingAddress
        self.messagingBindingProxyAddress = messagingBindingProxyAddress
        self.messagingBindingProjectedAddress = messagingBindingProjectedAddress
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = identity { f.append(FormField("Identity", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = roleSid { f.append(FormField("RoleSid", v)) }
        if let v = messagingBindingAddress { f.append(FormField("MessagingBinding.Address", v)) }
        if let v = messagingBindingProxyAddress { f.append(FormField("MessagingBinding.ProxyAddress", v)) }
        if let v = messagingBindingProjectedAddress { f.append(FormField("MessagingBinding.ProjectedAddress", v)) }
        return f
    }
}

public struct UpdateConversationParticipantRequest: Sendable {
    public var identity: String?
    public var attributes: String?
    public var roleSid: String?
    public var lastReadMessageIndex: Int?
    public var lastReadTimestamp: String?
    public init(identity: String? = nil, attributes: String? = nil, roleSid: String? = nil,
                lastReadMessageIndex: Int? = nil, lastReadTimestamp: String? = nil) {
        self.identity = identity
        self.attributes = attributes
        self.roleSid = roleSid
        self.lastReadMessageIndex = lastReadMessageIndex
        self.lastReadTimestamp = lastReadTimestamp
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = identity { f.append(FormField("Identity", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = roleSid { f.append(FormField("RoleSid", v)) }
        if let v = lastReadMessageIndex { f.append(FormField("LastReadMessageIndex", v)) }
        if let v = lastReadTimestamp { f.append(FormField("LastReadTimestamp", v)) }
        return f
    }
}

// MARK: - Request bodies — ConversationScopedWebhook

public struct CreateConversationScopedWebhookRequest: Sendable {
    public var target: String
    public var configurationUrl: String?
    public var configurationMethod: String?
    public var configurationFlowSid: String?
    public var configurationReplayAfter: Int?
    public init(target: String, configurationUrl: String? = nil,
                configurationMethod: String? = nil, configurationFlowSid: String? = nil,
                configurationReplayAfter: Int? = nil) {
        self.target = target
        self.configurationUrl = configurationUrl
        self.configurationMethod = configurationMethod
        self.configurationFlowSid = configurationFlowSid
        self.configurationReplayAfter = configurationReplayAfter
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("Target", target)]
        if let v = configurationUrl { f.append(FormField("Configuration.Url", v)) }
        if let v = configurationMethod { f.append(FormField("Configuration.Method", v)) }
        if let v = configurationFlowSid { f.append(FormField("Configuration.FlowSid", v)) }
        if let v = configurationReplayAfter { f.append(FormField("Configuration.ReplayAfter", v)) }
        return f
    }
}

public struct UpdateConversationScopedWebhookRequest: Sendable {
    public var configurationUrl: String?
    public var configurationMethod: String?
    public var configurationFlowSid: String?
    public init(configurationUrl: String? = nil, configurationMethod: String? = nil,
                configurationFlowSid: String? = nil) {
        self.configurationUrl = configurationUrl
        self.configurationMethod = configurationMethod
        self.configurationFlowSid = configurationFlowSid
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = configurationUrl { f.append(FormField("Configuration.Url", v)) }
        if let v = configurationMethod { f.append(FormField("Configuration.Method", v)) }
        if let v = configurationFlowSid { f.append(FormField("Configuration.FlowSid", v)) }
        return f
    }
}

// MARK: - Request bodies — Role

public struct CreateRoleRequest: Sendable {
    public var friendlyName: String
    public var type: String
    public var permission: [String]
    public init(friendlyName: String, type: String, permission: [String]) {
        self.friendlyName = friendlyName
        self.type = type
        self.permission = permission
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = [
            FormField("FriendlyName", friendlyName),
            FormField("Type", type),
        ]
        for p in permission { f.append(FormField("Permission", p)) }
        return f
    }
}

public struct UpdateRoleRequest: Sendable {
    public var permission: [String]
    public init(permission: [String]) { self.permission = permission }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        for p in permission { f.append(FormField("Permission", p)) }
        return f
    }
}

// MARK: - Request bodies — User

public struct CreateUserRequest: Sendable {
    public var identity: String
    public var friendlyName: String?
    public var attributes: String?
    public var roleSid: String?
    public init(identity: String, friendlyName: String? = nil,
                attributes: String? = nil, roleSid: String? = nil) {
        self.identity = identity
        self.friendlyName = friendlyName
        self.attributes = attributes
        self.roleSid = roleSid
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("Identity", identity)]
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = roleSid { f.append(FormField("RoleSid", v)) }
        return f
    }
}

public struct UpdateUserRequest: Sendable {
    public var friendlyName: String?
    public var attributes: String?
    public var roleSid: String?
    public init(friendlyName: String? = nil, attributes: String? = nil, roleSid: String? = nil) {
        self.friendlyName = friendlyName
        self.attributes = attributes
        self.roleSid = roleSid
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = roleSid { f.append(FormField("RoleSid", v)) }
        return f
    }
}

// MARK: - Request bodies — UserConversation

public struct UpdateUserConversationRequest: Sendable {
    public var notificationLevel: String?
    public var lastReadMessageIndex: Int?
    public var lastReadTimestamp: String?
    public init(notificationLevel: String? = nil, lastReadMessageIndex: Int? = nil,
                lastReadTimestamp: String? = nil) {
        self.notificationLevel = notificationLevel
        self.lastReadMessageIndex = lastReadMessageIndex
        self.lastReadTimestamp = lastReadTimestamp
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = notificationLevel { f.append(FormField("NotificationLevel", v)) }
        if let v = lastReadMessageIndex { f.append(FormField("LastReadMessageIndex", v)) }
        if let v = lastReadTimestamp { f.append(FormField("LastReadTimestamp", v)) }
        return f
    }
}

// MARK: - Request bodies — Credential

public struct CreateConversationsCredentialRequest: Sendable {
    public var type: String
    public var friendlyName: String?
    public var certificate: String?
    public var privateKey: String?
    public var sandbox: Bool?
    public var apiKey: String?
    public var secret: String?
    public init(type: String, friendlyName: String? = nil, certificate: String? = nil,
                privateKey: String? = nil, sandbox: Bool? = nil, apiKey: String? = nil,
                secret: String? = nil) {
        self.type = type
        self.friendlyName = friendlyName
        self.certificate = certificate
        self.privateKey = privateKey
        self.sandbox = sandbox
        self.apiKey = apiKey
        self.secret = secret
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("Type", type)]
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = certificate { f.append(FormField("Certificate", v)) }
        if let v = privateKey { f.append(FormField("PrivateKey", v)) }
        if let v = sandbox { f.append(FormField("Sandbox", v)) }
        if let v = apiKey { f.append(FormField("ApiKey", v)) }
        if let v = secret { f.append(FormField("Secret", v)) }
        return f
    }
}

public struct UpdateConversationsCredentialRequest: Sendable {
    public var type: String?
    public var friendlyName: String?
    public var certificate: String?
    public var privateKey: String?
    public var sandbox: Bool?
    public var apiKey: String?
    public var secret: String?
    public init(type: String? = nil, friendlyName: String? = nil, certificate: String? = nil,
                privateKey: String? = nil, sandbox: Bool? = nil, apiKey: String? = nil,
                secret: String? = nil) {
        self.type = type
        self.friendlyName = friendlyName
        self.certificate = certificate
        self.privateKey = privateKey
        self.sandbox = sandbox
        self.apiKey = apiKey
        self.secret = secret
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = type { f.append(FormField("Type", v)) }
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = certificate { f.append(FormField("Certificate", v)) }
        if let v = privateKey { f.append(FormField("PrivateKey", v)) }
        if let v = sandbox { f.append(FormField("Sandbox", v)) }
        if let v = apiKey { f.append(FormField("ApiKey", v)) }
        if let v = secret { f.append(FormField("Secret", v)) }
        return f
    }
}

// MARK: - Request bodies — Configuration

public struct UpdateConfigurationRequest: Sendable {
    public var defaultChatServiceSid: String?
    public var defaultMessagingServiceSid: String?
    public var defaultInactiveTimer: String?
    public var defaultClosedTimer: String?
    public init(defaultChatServiceSid: String? = nil, defaultMessagingServiceSid: String? = nil,
                defaultInactiveTimer: String? = nil, defaultClosedTimer: String? = nil) {
        self.defaultChatServiceSid = defaultChatServiceSid
        self.defaultMessagingServiceSid = defaultMessagingServiceSid
        self.defaultInactiveTimer = defaultInactiveTimer
        self.defaultClosedTimer = defaultClosedTimer
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = defaultChatServiceSid { f.append(FormField("DefaultChatServiceSid", v)) }
        if let v = defaultMessagingServiceSid { f.append(FormField("DefaultMessagingServiceSid", v)) }
        if let v = defaultInactiveTimer { f.append(FormField("DefaultInactiveTimer", v)) }
        if let v = defaultClosedTimer { f.append(FormField("DefaultClosedTimer", v)) }
        return f
    }
}

// MARK: - Request bodies — ConfigurationWebhook

public struct UpdateConfigurationWebhookRequest: Sendable {
    public var method: String?
    public var filters: [String]?
    public var preWebhookUrl: String?
    public var postWebhookUrl: String?
    public var target: String?
    public init(method: String? = nil, filters: [String]? = nil, preWebhookUrl: String? = nil,
                postWebhookUrl: String? = nil, target: String? = nil) {
        self.method = method
        self.filters = filters
        self.preWebhookUrl = preWebhookUrl
        self.postWebhookUrl = postWebhookUrl
        self.target = target
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = method { f.append(FormField("Method", v)) }
        if let arr = filters {
            for v in arr { f.append(FormField("Filters", v)) }
        }
        if let v = preWebhookUrl { f.append(FormField("PreWebhookUrl", v)) }
        if let v = postWebhookUrl { f.append(FormField("PostWebhookUrl", v)) }
        if let v = target { f.append(FormField("Target", v)) }
        return f
    }
}

// MARK: - Request bodies — ConfigAddress

public struct CreateConfigAddressRequest: Sendable {
    public var type: String
    public var address: String
    public var friendlyName: String?
    public var autoCreationEnabled: Bool?
    public var autoCreationType: String?
    public var autoCreationWebhookUrl: String?
    public var addressCountry: String?
    public init(type: String, address: String, friendlyName: String? = nil,
                autoCreationEnabled: Bool? = nil, autoCreationType: String? = nil,
                autoCreationWebhookUrl: String? = nil, addressCountry: String? = nil) {
        self.type = type
        self.address = address
        self.friendlyName = friendlyName
        self.autoCreationEnabled = autoCreationEnabled
        self.autoCreationType = autoCreationType
        self.autoCreationWebhookUrl = autoCreationWebhookUrl
        self.addressCountry = addressCountry
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("Type", type), FormField("Address", address)]
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = autoCreationEnabled { f.append(FormField("AutoCreation.Enabled", v)) }
        if let v = autoCreationType { f.append(FormField("AutoCreation.Type", v)) }
        if let v = autoCreationWebhookUrl { f.append(FormField("AutoCreation.WebhookUrl", v)) }
        if let v = addressCountry { f.append(FormField("AddressCountry", v)) }
        return f
    }
}

public struct UpdateConfigAddressRequest: Sendable {
    public var friendlyName: String?
    public var autoCreationEnabled: Bool?
    public var autoCreationType: String?
    public var autoCreationWebhookUrl: String?
    public init(friendlyName: String? = nil, autoCreationEnabled: Bool? = nil,
                autoCreationType: String? = nil, autoCreationWebhookUrl: String? = nil) {
        self.friendlyName = friendlyName
        self.autoCreationEnabled = autoCreationEnabled
        self.autoCreationType = autoCreationType
        self.autoCreationWebhookUrl = autoCreationWebhookUrl
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = autoCreationEnabled { f.append(FormField("AutoCreation.Enabled", v)) }
        if let v = autoCreationType { f.append(FormField("AutoCreation.Type", v)) }
        if let v = autoCreationWebhookUrl { f.append(FormField("AutoCreation.WebhookUrl", v)) }
        return f
    }
}

// MARK: - Request bodies — ConversationWithParticipants

public struct CreateConversationWithParticipantsRequest: Sendable {
    public var friendlyName: String?
    public var uniqueName: String?
    public var messagingServiceSid: String?
    public var attributes: String?
    public var state: String?
    public var timersInactive: String?
    public var timersClosed: String?
    public var participant: [String]?
    public init(friendlyName: String? = nil, uniqueName: String? = nil,
                messagingServiceSid: String? = nil, attributes: String? = nil,
                state: String? = nil, timersInactive: String? = nil,
                timersClosed: String? = nil, participant: [String]? = nil) {
        self.friendlyName = friendlyName
        self.uniqueName = uniqueName
        self.messagingServiceSid = messagingServiceSid
        self.attributes = attributes
        self.state = state
        self.timersInactive = timersInactive
        self.timersClosed = timersClosed
        self.participant = participant
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = uniqueName { f.append(FormField("UniqueName", v)) }
        if let v = messagingServiceSid { f.append(FormField("MessagingServiceSid", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = state { f.append(FormField("State", v)) }
        if let v = timersInactive { f.append(FormField("Timers.Inactive", v)) }
        if let v = timersClosed { f.append(FormField("Timers.Closed", v)) }
        if let arr = participant {
            for v in arr { f.append(FormField("Participant", v)) }
        }
        return f
    }
}

// MARK: - Request bodies — Service

public struct CreateConversationServiceRequest: Sendable {
    public var friendlyName: String
    public init(friendlyName: String) { self.friendlyName = friendlyName }
    public func formFields() -> [FormField] {
        [FormField("FriendlyName", friendlyName)]
    }
}

// MARK: - List query params — ParticipantConversation (extends ListV1PageParams)

public struct ListParticipantConversationParams: Sendable {
    public var identity: String?
    public var address: String?
    public var pageSize: Int?
    public init(identity: String? = nil, address: String? = nil, pageSize: Int? = nil) {
        self.identity = identity; self.address = address; self.pageSize = pageSize
    }
    public func queryItems() -> [QueryItem] {
        var q: [QueryItem] = []
        if let v = identity { q.append(QueryItem("Identity", v)) }
        if let v = address { q.append(QueryItem("Address", v)) }
        if let v = pageSize { q.append(QueryItem("PageSize", String(v))) }
        return q
    }
}
