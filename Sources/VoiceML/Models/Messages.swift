import Foundation

/// One SMS/MMS resource. Decoded from `GET /Messages/{sid}` and embedded in `MessageList`.
///
/// `status` pins to "sent" on a successful dispatch and "failed" otherwise when the
/// gateway is fire-and-forget. `numSegments`/`numMedia` are string-typed on the wire to
/// match the compatible response shape; SDK consumers can `Int($0)` if they need a count.
public struct Message: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var apiVersion: String?
    public var to: String?
    public var from: String?
    public var body: String?
    public var status: String?
    public var numSegments: String?
    public var numMedia: String?
    public var direction: String?
    public var price: String?
    public var priceUnit: String?
    public var errorCode: Int?
    public var errorMessage: String?
    public var messagingServiceSid: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var dateSent: String?
    public var uri: String?
    public var subresourceUris: [String: String]?
}

/// Paginated `/Messages` list response in the standard envelope.
public struct MessageList: Codable, Sendable {
    public var messages: [Message]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// Delivery-quality feedback echoed on `POST /Messages/{sid}/Feedback.json`.
/// VoiceML records the outcome on the response only; any submitted `Outcome`
/// other than `"confirmed"` echoes back as `unconfirmed`.
public struct MessageFeedback: Codable, Sendable {
    public var accountSid: String?
    public var messageSid: String?
    public var outcome: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    public var uri: String?
}

/// Body for `POST /Messages/{sid}/Feedback.json`. `outcome` is `"confirmed"`
/// or `"unconfirmed"`.
public struct CreateMessageFeedbackRequest: Sendable {
    public var outcome: String

    public init(outcome: String) {
        self.outcome = outcome
    }

    func formFields() -> [FormField] {
        [FormField("Outcome", outcome)]
    }
}

/// Body for `POST /Messages`. `to` is required; `from` falls back to the tenant's
/// configured default sender when omitted. Supply `body` and/or one or more `mediaUrl`
/// entries — sending neither throws ``ConfigurationError`` before any request is made
/// (the server requires Body unless MediaUrl is present).
public struct CreateMessageRequest: Sendable {
    public var to: String
    public var body: String?
    public var from: String?
    /// One or more media URLs (MMS); each entry is sent as a repeated `MediaUrl` key.
    public var mediaUrl: [String]?
    public var messagingServiceSid: String?
    /// Seconds the message may stay queued before failing (1–36000).
    public var validityPeriod: Int?
    public var statusCallback: String?
    public var statusCallbackMethod: HttpMethod?
    /// Wire name `SendAt`. Schedule the message for a future UTC time, as an
    /// RFC 3339 date-time string. Requires `scheduleType` and `messagingServiceSid`.
    public var sendAt: String?
    /// `"fixed"` is the only supported value; anything else is a 400 (error 35126).
    /// Requires `sendAt` and `messagingServiceSid`.
    public var scheduleType: String?

    public init(
        to: String,
        body: String? = nil,
        from: String? = nil,
        mediaUrl: [String]? = nil,
        messagingServiceSid: String? = nil,
        validityPeriod: Int? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: HttpMethod? = nil,
        sendAt: String? = nil,
        scheduleType: String? = nil
    ) {
        self.to = to
        self.body = body
        self.from = from
        self.mediaUrl = mediaUrl
        self.messagingServiceSid = messagingServiceSid
        self.validityPeriod = validityPeriod
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
        self.sendAt = sendAt
        self.scheduleType = scheduleType
    }

    func formFields() -> [FormField] {
        var fields: [FormField] = [
            FormField("To", to),
            FormField("Body", body),
            FormField("From", from),
        ]
        if let media = mediaUrl {
            for m in media {
                fields.append(FormField("MediaUrl", m))
            }
        }
        fields.append(contentsOf: [
            FormField("MessagingServiceSid", messagingServiceSid),
            FormField("ValidityPeriod", validityPeriod),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod?.rawValue),
            FormField("SendAt", sendAt),
            FormField("ScheduleType", scheduleType),
        ])
        return fields
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
    /// Wire name `DateSent`. Messages sent on this UTC date.
    public var dateSent: String?
    /// Wire name `DateSent<`.
    public var dateSentLt: String?
    /// Wire name `DateSent>`.
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
