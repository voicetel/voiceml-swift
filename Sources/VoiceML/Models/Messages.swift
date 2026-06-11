import Foundation

/// One SMS resource. Decoded from `GET /Messages/{sid}` and embedded in `MessageList`.
///
/// Outbound-only today (no MMS, no inbound webhook delivery). `status` pins to "sent"
/// on a successful SDK 2.2 dispatch and "failed" otherwise — there is no in-flight
/// "queued"/"sending"/"delivered" lifecycle because the gateway is fire-and-forget.
///
/// `numSegments`/`numMedia` are deliberately string-typed on the wire to match the
/// Twilio-compatible response shape; SDK consumers can `Int($0)` if they need a count.
public struct Message: Codable, Sendable {
    public var sid: String
    public var accountSid: String
    public var apiVersion: String
    public var to: String
    public var from: String
    public var body: String
    public var status: String
    public var numSegments: String
    public var numMedia: String
    public var direction: String
    public var price: String?
    public var priceUnit: String?
    public var errorCode: Int?
    public var errorMessage: String?
    public var messagingServiceSid: String?
    public var dateCreated: String
    public var dateUpdated: String
    public var dateSent: String?
    public var uri: String
    public var subresourceUris: [String: String]?
}

/// Paginated `/Messages` list response.
public struct MessageList: Codable, Sendable {
    public var messages: [Message]
    public var page: Int?
    public var pageSize: Int?
    public var numPages: Int?
    public var total: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// Body for `POST /Messages`. `to` and `body` are required; `from` falls back to the
/// tenant's configured default sender when omitted.
public struct CreateMessageRequest: Sendable {
    public var to: String
    public var body: String
    public var from: String?
    public var messagingServiceSid: String?
    public var statusCallback: String?

    public init(
        to: String,
        body: String,
        from: String? = nil,
        messagingServiceSid: String? = nil,
        statusCallback: String? = nil
    ) {
        self.to = to
        self.body = body
        self.from = from
        self.messagingServiceSid = messagingServiceSid
        self.statusCallback = statusCallback
    }

    func formFields() -> [FormField] {
        [
            FormField("To", to),
            FormField("Body", body),
            FormField("From", from),
            FormField("MessagingServiceSid", messagingServiceSid),
            FormField("StatusCallback", statusCallback),
        ]
    }
}

/// Body for `POST /Messages/{sid}` — only `body=""` (redaction) is honoured by the
/// server today; `status=canceled` returns 21610 because outbound SMS is fire-and-forget.
public struct UpdateMessageRequest: Sendable {
    public var body: String?
    public var status: String?

    public init(body: String? = nil, status: String? = nil) {
        self.body = body
        self.status = status
    }

    func formFields() -> [FormField] {
        [
            FormField("Body", body),
            FormField("Status", status),
        ]
    }
}

/// Filter parameters for `GET /Messages`.
public struct ListMessagesParams: Sendable {
    public var to: String?
    public var from: String?
    /// Twilio wire name `DateSent`. Messages sent on this UTC date.
    public var dateSent: String?
    /// Twilio wire name `DateSent<`.
    public var dateSentLt: String?
    /// Twilio wire name `DateSent>`.
    public var dateSentGt: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        to: String? = nil,
        from: String? = nil,
        dateSent: String? = nil,
        dateSentLt: String? = nil,
        dateSentGt: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.to = to
        self.from = from
        self.dateSent = dateSent
        self.dateSentLt = dateSentLt
        self.dateSentGt = dateSentGt
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("To", to),
            QueryItem("From", from),
            QueryItem("DateSent", dateSent),
            QueryItem("DateSent<", dateSentLt),
            QueryItem("DateSent>", dateSentGt),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}
