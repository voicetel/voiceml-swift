import Foundation

// Monitor v1 (`/v1/Alerts`) — failure events rendered in the Monitor Alert
// shape: call-scoped errors and messaging delivery failures alike. List rows
// omit the request/response detail; `fetch` includes it when the underlying
// event stored any. Sits outside the /2010-04-01/Accounts/{Sid}/ prefix —
// the account resolves from HTTP Basic auth. Lists use the shared `meta`
// envelope and serve a single page (`next_page_url` is always null); unlike
// the other /v1 collections, `PageSize` does limit the Alerts page
// (default 50, capped at 1000).

/// Severity of a Monitor Alert. Open enum — an unknown wire value decodes
/// as-is instead of failing the whole payload.
public struct MonitorLogLevel: OpenStringEnum {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let error = MonitorLogLevel(rawValue: "error")
    public static let warning = MonitorLogLevel(rawValue: "warning")
}

/// A Monitor v1 Alert. `resourceSid` carries the affected resource (the
/// message sid for messaging failures, the call sid for call-scoped ones);
/// `null` when neither exists. The `request*` / `response*` detail fields
/// are only populated by `fetch`, and only when the event stored them.
public struct MonitorAlert: Codable, Sendable {
    public var sid: String?
    public var accountSid: String?
    public var alertText: String?
    /// Always `null` on this surface.
    public var apiVersion: String?
    /// Numeric error code as a string (e.g. `"11200"`).
    public var errorCode: String?
    public var logLevel: MonitorLogLevel?
    public var moreInfo: String?
    public var requestMethod: String?
    public var requestUrl: String?
    public var requestHeaders: String?
    public var requestVariables: String?
    public var responseBody: String?
    public var responseHeaders: String?
    public var resourceSid: String?
    public var serviceSid: String?
    public var dateCreated: String?
    public var dateGenerated: String?
    public var dateUpdated: String?
    public var url: String?
}

/// One page of `/v1/Alerts` — `alerts` plus the shared `meta` envelope.
public struct MonitorAlertList: Codable, Sendable {
    public var alerts: [MonitorAlert]
    public var meta: V1Meta
}

/// Filter parameters for `GET /v1/Alerts`. `startDate` / `endDate` take a
/// `YYYY-MM-DD` date or a full ISO-8601 timestamp; `pageSize` limits the
/// single served page (default 50, capped at 1000).
public struct ListMonitorAlertsParams: Sendable {
    public var logLevel: MonitorLogLevel?
    public var startDate: String?
    public var endDate: String?
    public var pageSize: Int?

    public init(
        logLevel: MonitorLogLevel? = nil,
        startDate: String? = nil,
        endDate: String? = nil,
        pageSize: Int? = nil
    ) {
        self.logLevel = logLevel
        self.startDate = startDate
        self.endDate = endDate
        self.pageSize = pageSize
    }

    public func queryItems() -> [QueryItem] {
        [
            QueryItem("LogLevel", logLevel?.rawValue),
            QueryItem("StartDate", startDate),
            QueryItem("EndDate", endDate),
            QueryItem("PageSize", pageSize.map(String.init)),
        ]
    }
}
