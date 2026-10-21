import Foundation

// Models for the account-scope resources added to match the current spec:
// Usage Records, SIP Registrations, Messaging Service sender pool, account
// Transcriptions (post-recording), and Exports.

// MARK: - Usage Records

/// One usage record: a usage category accumulated over a window.
public struct UsageRecord: Codable, Sendable {
    public var accountSid: String?
    public var apiVersion: String?
    public var asOf: String?
    /// Usage category (`calls`, `sms`, `totalprice`, …).
    public var category: String?
    /// Number of usage events, as a string.
    public var count: String?
    public var countUnit: String?
    public var description: String?
    /// Last day of the record's window (inclusive), `YYYY-MM-DD`.
    public var endDate: String?
    /// Total price over the window as a minimal-decimal string.
    public var price: String?
    public var priceUnit: String?
    /// First day of the record's window, `YYYY-MM-DD`.
    public var startDate: String?
    public var subresourceUris: [String: String]?
    public var uri: String?
    public var usage: String?
    public var usageUnit: String?
}

/// Page of usage records in the standard envelope.
public struct UsageRecordList: Codable, Sendable {
    public var usageRecords: [UsageRecord]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

/// Filter params shared by every `GET /Usage/Records…` window.
public struct ListUsageRecordsParams: Sendable {
    public var category: String?
    public var startDate: String?
    public var endDate: String?
    public var includeSubaccounts: Bool?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        category: String? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        includeSubaccounts: Bool? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.category = category
        self.startDate = startDate
        self.endDate = endDate
        self.includeSubaccounts = includeSubaccounts
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("Category", category),
            QueryItem("StartDate", startDate),
            QueryItem("EndDate", endDate),
            QueryItem("IncludeSubaccounts", includeSubaccounts.map { $0 ? "true" : "false" }),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

// MARK: - SIP Registrations

/// One live contact registration on a SIP domain.
public struct SipRegistrationContact: Codable, Sendable {
    public var contact: String?
    public var received: String?
    public var socket: String?
    public var userAgent: String?
    public var expiresAt: String?
    public var registered: Bool?
}

/// The live call bound to a registration, when present.
public struct SipRegistrationActiveCall: Codable, Sendable {
    public var callSid: String?
    public var direction: String?
    public var remote: String?
    public var since: String?
}

/// An active registration on a SIP ingress domain (`/SIP/Registrations.json`).
public struct SipRegistration: Codable, Sendable {
    public var aor: String?
    public var username: String?
    public var domain: String?
    public var domainSid: String?
    /// `registered` or `expired`.
    public var status: String?
    public var callerId: String?
    public var userAgent: String?
    public var lastRegistered: String?
    public var contacts: [SipRegistrationContact]?
    public var activeCall: SipRegistrationActiveCall?
}

/// Page of SIP registrations in the standard envelope.
public struct SipRegistrationList: Codable, Sendable {
    public var registrations: [SipRegistration]
    public var page: Int?
    public var pageSize: Int?
    public var start: Int?
    public var end: Int?
    public var firstPageUri: String?
    public var nextPageUri: String?
    public var previousPageUri: String?
    public var uri: String?
}

// MARK: - Messaging Service sender pool

/// One phone number in a Messaging Service's sender pool.
public struct MessagingServicePhoneNumber: Codable, Sendable {
    /// The referenced IncomingPhoneNumber's PN sid.
    public var sid: String?
    public var accountSid: String?
    public var serviceSid: String?
    public var dateCreated: String?
    public var dateUpdated: String?
    /// E.164.
    public var phoneNumber: String?
    public var countryCode: String?
    public var capabilities: [String]?
    public var url: String?
}

/// List of sender-pool numbers (`/v1/Services/{ChatServiceSid}/PhoneNumbers`).
public struct MessagingServicePhoneNumberList: Decodable, Sendable {
    public var phoneNumbers: [MessagingServicePhoneNumber]?
    public var meta: V1Meta?
}

/// Body for `POST /v1/Services/{ChatServiceSid}/PhoneNumbers`.
public struct AddMessagingServicePhoneNumberRequest: Sendable {
    public var phoneNumberSid: String

    public init(phoneNumberSid: String) {
        self.phoneNumberSid = phoneNumberSid
    }

    func formFields() -> [FormField] {
        [FormField("PhoneNumberSid", phoneNumberSid)]
    }
}

/// Query params for the sender-pool list — `Page`/`PageSize` only per spec.
public struct ListMessagingPhoneNumbersParams: Sendable {
    public var page: Int?
    public var pageSize: Int?

    public init(page: Int? = nil, pageSize: Int? = nil) {
        self.page = page
        self.pageSize = pageSize
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
        ]
    }
}

// MARK: - Account Transcriptions (post-recording, TR…)

/// Status of a post-recording transcription. Open enum.
public struct AccountTranscriptionStatus: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let inProgress = AccountTranscriptionStatus(rawValue: "in-progress")
    public static let completed = AccountTranscriptionStatus(rawValue: "completed")
    public static let failed = AccountTranscriptionStatus(rawValue: "failed")
}

/// Async / post-recording transcription (`TR…`), created by `<Record transcribe="true">`.
/// `transcriptionText` is null until `status` reaches `completed`.
public typealias Transcription = RecordingTranscription

/// Page of post-recording transcriptions in the standard envelope.
public typealias TranscriptionPageList = RecordingTranscriptionList

/// Filter params for the account and recording transcription lists.
public struct ListTranscriptionsParams: Sendable {
    public var dateCreated: String?
    public var dateCreatedLt: String?
    public var dateCreatedGt: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        dateCreated: String? = nil,
        dateCreatedLt: String? = nil,
        dateCreatedGt: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.dateCreated = dateCreated
        self.dateCreatedLt = dateCreatedLt
        self.dateCreatedGt = dateCreatedGt
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("DateCreated", dateCreated),
            QueryItem("DateCreated<", dateCreatedLt),
            QueryItem("DateCreated>", dateCreatedGt),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

// MARK: - Exports

/// One downloadable nightly event-log archive.
public struct ExportArchive: Codable, Sendable {
    /// Archive day (`YYYY-MM-DD`).
    public var date: String?
    /// Archive size in bytes.
    public var size: Int?
    public var uri: String?
}

/// `GET /Exports.json` — the account's available archives, newest first.
public struct ExportList: Codable, Sendable {
    public var accountSid: String?
    public var exports: [ExportArchive]?
    public var uri: String?
}

// MARK: - Account self-update

/// Body for `POST /Accounts/{Sid}.json` — only-set-fields-touched. `FriendlyName` is
/// the Twilio Account field; the rest configure VoiceML voice routing, BYO STT/TTS,
/// AWS recording storage, and the IP allow-list.
public struct UpdateAccountRequest: Sendable {
    public var friendlyName: String?
    public var voiceUrl: String?
    public var voiceMethod: HttpMethod?
    public var voiceFallbackUrl: String?
    public var voiceFallbackMethod: HttpMethod?
    public var sttFsVendor: String?
    public var sttHttpUrl: String?
    public var sttHttpToken: String?
    public var ttsHttpUrl: String?
    public var ttsHttpToken: String?
    public var ttsEngineName: String?
    public var ttsDefaultVoice: String?
    public var ttsDefaultLanguage: String?
    public var awsBucket: String?
    public var awsRegion: String?
    public var awsPrefix: String?
    public var awsAccessKeyId: String?
    public var awsSecretAccessKey: String?
    public var awsKmsKeyId: String?
    /// IP allow-list, one CIDR prefix per entry (repeated `AllowCidr` keys).
    public var allowCidr: [String]?

    public init(
        friendlyName: String? = nil,
        voiceUrl: String? = nil,
        voiceMethod: HttpMethod? = nil,
        voiceFallbackUrl: String? = nil,
        voiceFallbackMethod: HttpMethod? = nil,
        sttFsVendor: String? = nil,
        sttHttpUrl: String? = nil,
        sttHttpToken: String? = nil,
        ttsHttpUrl: String? = nil,
        ttsHttpToken: String? = nil,
        ttsEngineName: String? = nil,
        ttsDefaultVoice: String? = nil,
        ttsDefaultLanguage: String? = nil,
        awsBucket: String? = nil,
        awsRegion: String? = nil,
        awsPrefix: String? = nil,
        awsAccessKeyId: String? = nil,
        awsSecretAccessKey: String? = nil,
        awsKmsKeyId: String? = nil,
        allowCidr: [String]? = nil
    ) {
        self.friendlyName = friendlyName
        self.voiceUrl = voiceUrl
        self.voiceMethod = voiceMethod
        self.voiceFallbackUrl = voiceFallbackUrl
        self.voiceFallbackMethod = voiceFallbackMethod
        self.sttFsVendor = sttFsVendor
        self.sttHttpUrl = sttHttpUrl
        self.sttHttpToken = sttHttpToken
        self.ttsHttpUrl = ttsHttpUrl
        self.ttsHttpToken = ttsHttpToken
        self.ttsEngineName = ttsEngineName
        self.ttsDefaultVoice = ttsDefaultVoice
        self.ttsDefaultLanguage = ttsDefaultLanguage
        self.awsBucket = awsBucket
        self.awsRegion = awsRegion
        self.awsPrefix = awsPrefix
        self.awsAccessKeyId = awsAccessKeyId
        self.awsSecretAccessKey = awsSecretAccessKey
        self.awsKmsKeyId = awsKmsKeyId
        self.allowCidr = allowCidr
    }

    func formFields() -> [FormField] {
        var fields: [FormField] = [
            FormField("FriendlyName", friendlyName),
            FormField("VoiceUrl", voiceUrl),
            FormField("VoiceMethod", voiceMethod?.rawValue),
            FormField("VoiceFallbackUrl", voiceFallbackUrl),
            FormField("VoiceFallbackMethod", voiceFallbackMethod?.rawValue),
            FormField("SttFsVendor", sttFsVendor),
            FormField("SttHttpUrl", sttHttpUrl),
            FormField("SttHttpToken", sttHttpToken),
            FormField("TtsHttpUrl", ttsHttpUrl),
            FormField("TtsHttpToken", ttsHttpToken),
            FormField("TtsEngineName", ttsEngineName),
            FormField("TtsDefaultVoice", ttsDefaultVoice),
            FormField("TtsDefaultLanguage", ttsDefaultLanguage),
            FormField("AwsBucket", awsBucket),
            FormField("AwsRegion", awsRegion),
            FormField("AwsPrefix", awsPrefix),
            FormField("AwsAccessKeyId", awsAccessKeyId),
            FormField("AwsSecretAccessKey", awsSecretAccessKey),
            FormField("AwsKmsKeyId", awsKmsKeyId),
        ]
        if let cidrs = allowCidr {
            for c in cidrs {
                fields.append(FormField("AllowCidr", c))
            }
        }
        return fields
    }
}

// MARK: - OutgoingCallerIds requests

/// Query params for `GET /OutgoingCallerIds.json`.
public struct ListOutgoingCallerIdsParams: Sendable {
    public var phoneNumber: String?
    public var friendlyName: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        phoneNumber: String? = nil,
        friendlyName: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.friendlyName = friendlyName
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("PhoneNumber", phoneNumber),
            QueryItem("FriendlyName", friendlyName),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}

/// Body for `POST /OutgoingCallerIds.json` — starts a validation call.
public struct CreateOutgoingCallerIdRequest: Sendable {
    public var phoneNumber: String
    public var friendlyName: String?
    /// Seconds to wait before placing the verification call (0–60).
    public var callDelay: Int?
    /// DTMF extension dialed after the verification call connects.
    public var `extension`: String?
    /// Fires at the end of the verification call with the verification outcome.
    public var statusCallback: String?
    /// HTTP method for the status-callback webhook.
    public var statusCallbackMethod: HttpMethod?

    public init(
        phoneNumber: String,
        friendlyName: String? = nil,
        callDelay: Int? = nil,
        `extension`: String? = nil,
        statusCallback: String? = nil,
        statusCallbackMethod: HttpMethod? = nil
    ) {
        self.phoneNumber = phoneNumber
        self.friendlyName = friendlyName
        self.callDelay = callDelay
        self.`extension` = `extension`
        self.statusCallback = statusCallback
        self.statusCallbackMethod = statusCallbackMethod
    }

    func formFields() -> [FormField] {
        [
            FormField("PhoneNumber", phoneNumber),
            FormField("FriendlyName", friendlyName),
            FormField("CallDelay", callDelay),
            FormField("Extension", `extension`),
            FormField("StatusCallback", statusCallback),
            FormField("StatusCallbackMethod", statusCallbackMethod?.rawValue),
        ]
    }
}

/// Body for `POST /OutgoingCallerIds/{Sid}.json`.
public struct UpdateOutgoingCallerIdRequest: Sendable {
    public var friendlyName: String?

    public init(friendlyName: String? = nil) {
        self.friendlyName = friendlyName
    }

    func formFields() -> [FormField] {
        [FormField("FriendlyName", friendlyName)]
    }
}

// MARK: - Message media

/// Filter params for `GET /Messages/{sid}/Media.json`.
public struct ListMediaParams: Sendable {
    public var dateCreated: String?
    public var dateCreatedLt: String?
    public var dateCreatedGt: String?
    public var page: Int?
    public var pageSize: Int?
    public var pageToken: String?

    public init(
        dateCreated: String? = nil,
        dateCreatedLt: String? = nil,
        dateCreatedGt: String? = nil,
        page: Int? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) {
        self.dateCreated = dateCreated
        self.dateCreatedLt = dateCreatedLt
        self.dateCreatedGt = dateCreatedGt
        self.page = page
        self.pageSize = pageSize
        self.pageToken = pageToken
    }

    func queryItems() -> [QueryItem] {
        [
            QueryItem("DateCreated", dateCreated),
            QueryItem("DateCreated<", dateCreatedLt),
            QueryItem("DateCreated>", dateCreatedGt),
            QueryItem("Page", page.map(String.init)),
            QueryItem("PageSize", pageSize.map(String.init)),
            QueryItem("PageToken", pageToken),
        ]
    }
}
