import Foundation

public struct Queue: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var friendlyName: String
    public var currentSize: Int
    public var maxSize: Int
    public var averageWaitTime: Int
    public var dateCreated: String
    public var dateUpdated: String
    public var uri: String
}

public struct QueueList: Codable, Sendable {
    public var queues: [Queue]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var firstPageUri: String?
    public var uri: String?
}

public struct QueueMember: Codable, Sendable {
    public var callSid: String
    public var queueSid: String
    public var accountSid: String?
    public var dateEnqueued: String
    public var waitTime: Int
    public var position: Int
    public var uri: String
}

public struct QueueMemberList: Codable, Sendable {
    public var queueMembers: [QueueMember]
    public var page: Int?
    public var pageSize: Int?
    public var total: Int?
    public var uri: String?
}

public struct CreateQueueRequest: Sendable {
    public var friendlyName: String
    public var maxSize: Int?

    public init(friendlyName: String, maxSize: Int? = nil) {
        self.friendlyName = friendlyName
        self.maxSize = maxSize
    }

    func formFields() -> [FormField] {
        [
            FormField("FriendlyName", friendlyName),
            FormField("MaxSize", maxSize),
        ]
    }
}

public struct UpdateQueueRequest: Sendable {
    public var friendlyName: String?
    public var maxSize: Int?

    public init(friendlyName: String? = nil, maxSize: Int? = nil) {
        self.friendlyName = friendlyName
        self.maxSize = maxSize
    }

    func formFields() -> [FormField] {
        [
            FormField("FriendlyName", friendlyName),
            FormField("MaxSize", maxSize),
        ]
    }
}

/// Body for the dequeue endpoints — `Url` is required.
public struct DequeueRequest: Sendable {
    public var url: String
    public var method: HttpMethod?

    public init(url: String, method: HttpMethod? = nil) {
        self.url = url
        self.method = method
    }

    func formFields() -> [FormField] {
        [
            FormField("Url", url),
            FormField("Method", method?.rawValue),
        ]
    }
}
