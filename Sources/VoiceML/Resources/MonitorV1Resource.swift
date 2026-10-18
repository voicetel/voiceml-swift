import Foundation

/// `client.monitorAlerts` — Monitor v1 Alerts (`/v1/Alerts`), on the default
/// host: failure events for calls and messaging delivery.
///
/// The server serves a single page (`meta.next_page_url` is always `null`);
/// `nextPage(of:)` follows the envelope verbatim regardless and returns `nil`
/// when there is no continuation.
public final class MonitorAlertsResource: Sendable {
    /// Generic page client for `meta`-enveloped lists on this host.
    public let pages: PageClient

    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
        self.pages = PageClient(transport: transport)
    }

    /// Return one page of alerts, narrowed by severity (`logLevel`) and
    /// generation window (`startDate` / `endDate`).
    public func list(_ params: ListMonitorAlertsParams = .init()) async throws -> MonitorAlertList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try transport.rootPath(["v1", "Alerts"]),
            query: params.queryItems()
        ))
    }

    /// Fetch one alert by sid, with the stored request/response detail when
    /// the underlying event carries any.
    public func fetch(sid: String) async throws -> MonitorAlert {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try transport.rootPath(["v1", "Alerts", sid])
        ))
    }

    /// Fetch the page after `page`, following its `meta.next_page_url`
    /// verbatim. Returns nil when the envelope has no next page. The URL is
    /// only followed on this resource's configured host — credentials are
    /// never sent to a different origin.
    public func nextPage(of page: MonitorAlertList) async throws -> MonitorAlertList? {
        try await pages.fetchNextPage(from: page.meta)
    }

    /// Walk every page of `/v1/Alerts` matching the supplied filters and yield
    /// each ``MonitorAlert``. Lazily follows each page's `meta.next_page_url`;
    /// breaking out of the `for try await` stops all further requests.
    public func iterate(_ params: ListMonitorAlertsParams = .init()) -> PagerSequence<MonitorAlert> {
        PagerSequence(
            firstPage: { [self] in
                let page = try await list(params)
                return PageResult(items: page.alerts, nextURL: Self.nextURL(from: page.meta))
            },
            followPage: { [self] url in
                let page: MonitorAlertList = try await transport.requestPage(url)
                return PageResult(items: page.alerts, nextURL: Self.nextURL(from: page.meta))
            }
        )
    }

    private static func nextURL(from meta: V1Meta) -> URL? {
        guard let raw = meta.nextPageUrl, !raw.isEmpty,
              let url = URL(string: raw), url.scheme != nil, url.host != nil else { return nil }
        return url
    }
}
