import Foundation

// Twilio Conversations v1 — Phase 4: service-scoped resources under
// /v1/Services/{ChatServiceSid}/... (v0.9.0 spec). 14 resource families,
// 44 operations.
//
// Field shapes mirror the account-level schemas (most carry an extra
// `chat_service_sid` SID). Decode-only response structs; request bodies
// emit `formFields()`. Closed enum domains (`state`, `notification_level`,
// `target`, `binding_type`, `method`, `type`) stay typed as `String` so a
// forward-rev'd server value cannot blow up decoding — same posture as
// the account-level models.

// MARK: - Service-scoped Conversation

/// Service-scoped conversation under `/v1/Services/{ChatServiceSid}/Conversations`.
/// Field-identical to ``ConversationsV1Conversation`` (mirrors Twilio's
/// service_conversation = conversation shape).
public struct ConversationsV1ServiceConversation: Decodable, Sendable {
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

public struct ConversationsV1ServiceConversationList: Decodable, Sendable {
    public var conversations: [ConversationsV1ServiceConversation]
    public var meta: V1Meta
}

// MARK: - Service-scoped Conversation Message

public struct ConversationsV1ServiceConversationMessage: Decodable, Sendable {
    public var accountSid: String?
    public var chatServiceSid: String?
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

public struct ConversationsV1ServiceConversationMessageList: Decodable, Sendable {
    public var messages: [ConversationsV1ServiceConversationMessage]
    public var meta: V1Meta
}

// MARK: - Service-scoped Conversation Participant

public struct ConversationsV1ServiceConversationParticipant: Decodable, Sendable {
    public var accountSid: String?
    public var chatServiceSid: String?
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

public struct ConversationsV1ServiceConversationParticipantList: Decodable, Sendable {
    public var participants: [ConversationsV1ServiceConversationParticipant]
    public var meta: V1Meta
}

// MARK: - Service-scoped Conversation Message Receipt

/// `status`: one of `read`, `failed`, `delivered`, `undelivered`, `sent`.
public struct ConversationsV1ServiceConversationMessageReceipt: Decodable, Sendable {
    public var accountSid: String?
    public var chatServiceSid: String?
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

public struct ConversationsV1ServiceConversationMessageReceiptList: Decodable, Sendable {
    public var deliveryReceipts: [ConversationsV1ServiceConversationMessageReceipt]
    public var meta: V1Meta
}

// MARK: - Service-scoped Conversation Scoped Webhook

public struct ConversationsV1ServiceConversationScopedWebhook: Decodable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var chatServiceSid: String?
    public var conversationSid: String?
    public var target: String?
    public var url: String?
    public var configuration: FreeformJSONObject?
    public var dateCreated: String?
    public var dateUpdated: String?
}

public struct ConversationsV1ServiceConversationScopedWebhookList: Decodable, Sendable {
    public var webhooks: [ConversationsV1ServiceConversationScopedWebhook]
    public var meta: V1Meta
}

// MARK: - Service-scoped Role

/// `type`: one of `conversation`, `service`.
public struct ConversationsV1ServiceRole: Decodable, Sendable {
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

public struct ConversationsV1ServiceRoleList: Decodable, Sendable {
    public var roles: [ConversationsV1ServiceRole]
    public var meta: V1Meta
}

// MARK: - Service-scoped User

public struct ConversationsV1ServiceUser: Decodable, Sendable {
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

public struct ConversationsV1ServiceUserList: Decodable, Sendable {
    public var users: [ConversationsV1ServiceUser]
    public var meta: V1Meta
}

// MARK: - Service-scoped ConversationWithParticipants

public struct ConversationsV1ServiceConversationWithParticipants: Decodable, Sendable {
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

// MARK: - Service-scoped ParticipantConversation

/// `conversation_state`: one of `inactive`, `active`, `closed`.
public struct ConversationsV1ServiceParticipantConversation: Decodable, Sendable {
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

public struct ConversationsV1ServiceParticipantConversationList: Decodable, Sendable {
    public var conversations: [ConversationsV1ServiceParticipantConversation]
    public var meta: V1Meta
}

// MARK: - Service-scoped UserConversation

/// `conversation_state`: one of `inactive`, `active`, `closed`.
/// `notification_level`: one of `default`, `muted`.
public struct ConversationsV1ServiceUserConversation: Decodable, Sendable {
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

public struct ConversationsV1ServiceUserConversationList: Decodable, Sendable {
    public var conversations: [ConversationsV1ServiceUserConversation]
    public var meta: V1Meta
}

// MARK: - Service-scoped Binding (read/delete only)

/// `binding_type`: one of `apn`, `gcm`, `fcm`, `twilsock`.
public struct ConversationsV1ServiceBinding: Decodable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var chatServiceSid: String?
    public var credentialSid: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var endpoint: String?
    public var identity: String?
    public var bindingType: String?
    public var messageTypes: [String]?
    public var url: String?
}

public struct ConversationsV1ServiceBindingList: Decodable, Sendable {
    public var bindings: [ConversationsV1ServiceBinding]
    public var meta: V1Meta
}

// MARK: - Per-service Configuration (singleton, fetch + update)

public struct ConversationsV1ServiceConfiguration: Decodable, Sendable {
    public var chatServiceSid: String?
    public var defaultConversationCreatorRoleSid: String?
    public var defaultConversationRoleSid: String?
    public var defaultChatServiceRoleSid: String?
    public var url: String?
    public var links: FreeformJSONObject?
    public var reachabilityEnabled: Bool?
}

// MARK: - Per-service Notification (singleton, fetch + update)

public struct ConversationsV1ServiceNotification: Decodable, Sendable {
    public var accountSid: String?
    public var chatServiceSid: String?
    public var newMessage: FreeformJSONObject?
    public var addedToConversation: FreeformJSONObject?
    public var removedFromConversation: FreeformJSONObject?
    public var logEnabled: Bool?
    public var url: String?
}

// MARK: - Per-service Webhook Configuration (singleton, fetch + update)

/// `method`: one of `GET`, `POST`.
public struct ConversationsV1ServiceWebhookConfiguration: Decodable, Sendable {
    public var accountSid: String?
    public var chatServiceSid: String?
    public var preWebhookUrl: String?
    public var postWebhookUrl: String?
    public var filters: [String]?
    public var method: String?
    public var url: String?
}

// MARK: - Request bodies — ServiceConversation

public struct CreateServiceConversationRequest: Sendable {
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

public struct UpdateServiceConversationRequest: Sendable {
    public var friendlyName: String?
    public var uniqueName: String?
    public var attributes: String?
    public var state: String?
    public var timersInactive: String?
    public var timersClosed: String?
    public init(friendlyName: String? = nil, uniqueName: String? = nil,
                attributes: String? = nil, state: String? = nil,
                timersInactive: String? = nil, timersClosed: String? = nil) {
        self.friendlyName = friendlyName
        self.uniqueName = uniqueName
        self.attributes = attributes
        self.state = state
        self.timersInactive = timersInactive
        self.timersClosed = timersClosed
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = friendlyName { f.append(FormField("FriendlyName", v)) }
        if let v = uniqueName { f.append(FormField("UniqueName", v)) }
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = state { f.append(FormField("State", v)) }
        if let v = timersInactive { f.append(FormField("Timers.Inactive", v)) }
        if let v = timersClosed { f.append(FormField("Timers.Closed", v)) }
        return f
    }
}

// MARK: - Request bodies — ServiceConversationMessage

public struct CreateServiceConversationMessageRequest: Sendable {
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

public struct UpdateServiceConversationMessageRequest: Sendable {
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

// MARK: - Request bodies — ServiceConversationParticipant

public struct CreateServiceConversationParticipantRequest: Sendable {
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

public struct UpdateServiceConversationParticipantRequest: Sendable {
    public var attributes: String?
    public var roleSid: String?
    public init(attributes: String? = nil, roleSid: String? = nil) {
        self.attributes = attributes
        self.roleSid = roleSid
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = attributes { f.append(FormField("Attributes", v)) }
        if let v = roleSid { f.append(FormField("RoleSid", v)) }
        return f
    }
}

// MARK: - Request bodies — ServiceConversationScopedWebhook

public struct CreateServiceConversationScopedWebhookRequest: Sendable {
    public var target: String
    public var configurationUrl: String?
    public var configurationMethod: String?
    public var configurationFlowSid: String?
    public init(target: String, configurationUrl: String? = nil,
                configurationMethod: String? = nil, configurationFlowSid: String? = nil) {
        self.target = target
        self.configurationUrl = configurationUrl
        self.configurationMethod = configurationMethod
        self.configurationFlowSid = configurationFlowSid
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = [FormField("Target", target)]
        if let v = configurationUrl { f.append(FormField("Configuration.Url", v)) }
        if let v = configurationMethod { f.append(FormField("Configuration.Method", v)) }
        if let v = configurationFlowSid { f.append(FormField("Configuration.FlowSid", v)) }
        return f
    }
}

public struct UpdateServiceConversationScopedWebhookRequest: Sendable {
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

// MARK: - Request bodies — ServiceRole

public struct CreateServiceRoleRequest: Sendable {
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

public struct UpdateServiceRoleRequest: Sendable {
    public var permission: [String]
    public init(permission: [String]) { self.permission = permission }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        for p in permission { f.append(FormField("Permission", p)) }
        return f
    }
}

// MARK: - Request bodies — ServiceUser

public struct CreateServiceUserRequest: Sendable {
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

public struct UpdateServiceUserRequest: Sendable {
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

// MARK: - Request bodies — ServiceConversationWithParticipants

public struct CreateServiceConversationWithParticipantsRequest: Sendable {
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

// MARK: - List query params — ServiceParticipantConversation (Identity/Address + PageSize)

public struct ListServiceParticipantConversationParams: Sendable {
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

// MARK: - List query params — ServiceBinding (BindingType/Identity + PageSize)

public struct ListServiceBindingParams: Sendable {
    /// One of `apn`, `gcm`, `fcm`, `twilsock`.
    public var bindingType: String?
    public var identity: String?
    public var pageSize: Int?
    public init(bindingType: String? = nil, identity: String? = nil, pageSize: Int? = nil) {
        self.bindingType = bindingType; self.identity = identity; self.pageSize = pageSize
    }
    public func queryItems() -> [QueryItem] {
        var q: [QueryItem] = []
        if let v = bindingType { q.append(QueryItem("BindingType", v)) }
        if let v = identity { q.append(QueryItem("Identity", v)) }
        if let v = pageSize { q.append(QueryItem("PageSize", String(v))) }
        return q
    }
}

// MARK: - Request bodies — ServiceConfiguration (per-service singleton)

public struct UpdateServiceConfigurationRequest: Sendable {
    public var defaultChatServiceRoleSid: String?
    public var defaultConversationCreatorRoleSid: String?
    public var defaultConversationRoleSid: String?
    public var reachabilityEnabled: Bool?
    public init(defaultChatServiceRoleSid: String? = nil,
                defaultConversationCreatorRoleSid: String? = nil,
                defaultConversationRoleSid: String? = nil,
                reachabilityEnabled: Bool? = nil) {
        self.defaultChatServiceRoleSid = defaultChatServiceRoleSid
        self.defaultConversationCreatorRoleSid = defaultConversationCreatorRoleSid
        self.defaultConversationRoleSid = defaultConversationRoleSid
        self.reachabilityEnabled = reachabilityEnabled
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = defaultChatServiceRoleSid { f.append(FormField("DefaultChatServiceRoleSid", v)) }
        if let v = defaultConversationCreatorRoleSid { f.append(FormField("DefaultConversationCreatorRoleSid", v)) }
        if let v = defaultConversationRoleSid { f.append(FormField("DefaultConversationRoleSid", v)) }
        if let v = reachabilityEnabled { f.append(FormField("ReachabilityEnabled", v)) }
        return f
    }
}

// MARK: - Request bodies — ServiceNotification (per-service singleton)

public struct UpdateServiceNotificationRequest: Sendable {
    public var logEnabled: Bool?
    public var newMessageEnabled: Bool?
    public var newMessageTemplate: String?
    public var newMessageSound: String?
    public var newMessageBadgeCountEnabled: Bool?
    public var newMessageWithMediaEnabled: Bool?
    public var newMessageWithMediaTemplate: String?
    public var addedToConversationEnabled: Bool?
    public var addedToConversationTemplate: String?
    public var addedToConversationSound: String?
    public var removedFromConversationEnabled: Bool?
    public var removedFromConversationTemplate: String?
    public var removedFromConversationSound: String?
    public init(logEnabled: Bool? = nil,
                newMessageEnabled: Bool? = nil,
                newMessageTemplate: String? = nil,
                newMessageSound: String? = nil,
                newMessageBadgeCountEnabled: Bool? = nil,
                newMessageWithMediaEnabled: Bool? = nil,
                newMessageWithMediaTemplate: String? = nil,
                addedToConversationEnabled: Bool? = nil,
                addedToConversationTemplate: String? = nil,
                addedToConversationSound: String? = nil,
                removedFromConversationEnabled: Bool? = nil,
                removedFromConversationTemplate: String? = nil,
                removedFromConversationSound: String? = nil) {
        self.logEnabled = logEnabled
        self.newMessageEnabled = newMessageEnabled
        self.newMessageTemplate = newMessageTemplate
        self.newMessageSound = newMessageSound
        self.newMessageBadgeCountEnabled = newMessageBadgeCountEnabled
        self.newMessageWithMediaEnabled = newMessageWithMediaEnabled
        self.newMessageWithMediaTemplate = newMessageWithMediaTemplate
        self.addedToConversationEnabled = addedToConversationEnabled
        self.addedToConversationTemplate = addedToConversationTemplate
        self.addedToConversationSound = addedToConversationSound
        self.removedFromConversationEnabled = removedFromConversationEnabled
        self.removedFromConversationTemplate = removedFromConversationTemplate
        self.removedFromConversationSound = removedFromConversationSound
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = logEnabled { f.append(FormField("LogEnabled", v)) }
        if let v = newMessageEnabled { f.append(FormField("NewMessage.Enabled", v)) }
        if let v = newMessageTemplate { f.append(FormField("NewMessage.Template", v)) }
        if let v = newMessageSound { f.append(FormField("NewMessage.Sound", v)) }
        if let v = newMessageBadgeCountEnabled { f.append(FormField("NewMessage.BadgeCountEnabled", v)) }
        if let v = newMessageWithMediaEnabled { f.append(FormField("NewMessage.WithMedia.Enabled", v)) }
        if let v = newMessageWithMediaTemplate { f.append(FormField("NewMessage.WithMedia.Template", v)) }
        if let v = addedToConversationEnabled { f.append(FormField("AddedToConversation.Enabled", v)) }
        if let v = addedToConversationTemplate { f.append(FormField("AddedToConversation.Template", v)) }
        if let v = addedToConversationSound { f.append(FormField("AddedToConversation.Sound", v)) }
        if let v = removedFromConversationEnabled { f.append(FormField("RemovedFromConversation.Enabled", v)) }
        if let v = removedFromConversationTemplate { f.append(FormField("RemovedFromConversation.Template", v)) }
        if let v = removedFromConversationSound { f.append(FormField("RemovedFromConversation.Sound", v)) }
        return f
    }
}

// MARK: - Request bodies — ServiceWebhookConfiguration (per-service singleton)

public struct UpdateServiceWebhookConfigurationRequest: Sendable {
    public var preWebhookUrl: String?
    public var postWebhookUrl: String?
    /// One of `GET`, `POST`.
    public var method: String?
    public var filters: [String]?
    public init(preWebhookUrl: String? = nil, postWebhookUrl: String? = nil,
                method: String? = nil, filters: [String]? = nil) {
        self.preWebhookUrl = preWebhookUrl
        self.postWebhookUrl = postWebhookUrl
        self.method = method
        self.filters = filters
    }
    public func formFields() -> [FormField] {
        var f: [FormField] = []
        if let v = preWebhookUrl { f.append(FormField("PreWebhookUrl", v)) }
        if let v = postWebhookUrl { f.append(FormField("PostWebhookUrl", v)) }
        if let v = method { f.append(FormField("Method", v)) }
        if let arr = filters {
            for v in arr { f.append(FormField("Filters", v)) }
        }
        return f
    }
}
