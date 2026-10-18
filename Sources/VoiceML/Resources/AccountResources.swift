import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// `/2010-04-01/Accounts/{Sid}.json` — self-serve account fetch/update and balance.
/// An account may only read and update its own record.
public final class AccountsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    /// `GET /Accounts/{Sid}.json` — the authenticated account in the Account shape.
    public func fetch(sid: String) async throws -> Account {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try transport.rootPath(["2010-04-01", "Accounts", sid])
        ))
    }

    /// `POST /Accounts/{Sid}.json` — only-set-fields-touched update. Returns the
    /// post-update Account. A concurrent modification surfaces as ``ConflictError``
    /// (409 / error 20409 optimistic-locking).
    public func update(sid: String, _ body: UpdateAccountRequest) async throws -> Account {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try transport.rootPath(["2010-04-01", "Accounts", sid]),
            form: body.formFields()
        ))
    }

    /// `GET /Accounts/{AccountSid}/Balance.json` — the account balance.
    public func balance() async throws -> Balance {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try transport.accountPath(["Balance"])
        ))
    }

    /// `POST /Accounts/{AccountSid}/RotateKey.json` — rotate the account's API
    /// key (no request body). The previous key stops working immediately. The
    /// new key rides the returned ``AccountWithKey`` as `apiKey` — no read
    /// endpoint exposes it, so store it right away. It never appears in
    /// `Mirror` / `dump()` / `debugDescription` output.
    public func rotateKey() async throws -> AccountWithKey {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try transport.accountPath(["RotateKey"])
        ))
    }
}

/// `/OutgoingCallerIds.json` — verified outgoing caller IDs.
public final class OutgoingCallerIdsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(["OutgoingCallerIds"] + parts)
    }

    public func list(_ params: ListOutgoingCallerIdsParams = .init()) async throws -> OutgoingCallerIdList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path(),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: OutgoingCallerIdList) async throws -> OutgoingCallerIdList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    /// `POST /OutgoingCallerIds.json` — start a validation call; the response carries
    /// the validation code rather than a caller-id sid.
    public func create(_ body: CreateOutgoingCallerIdRequest) async throws -> ValidationRequest {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try path(),
            form: body.formFields()
        ))
    }

    public func fetch(sid: String) async throws -> OutgoingCallerId {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path(sid)
        ))
    }

    public func update(sid: String, _ body: UpdateOutgoingCallerIdRequest) async throws -> OutgoingCallerId {
        try await transport.request(VoiceMLRequest(
            method: .post,
            path: try path(sid),
            form: body.formFields()
        ))
    }

    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: try path(sid)
        ))
    }
}

/// `/Transcriptions.json` — the account's post-recording transcriptions (`TR…`).
public final class TranscriptionsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(["Transcriptions"] + parts)
    }

    public func list(_ params: ListTranscriptionsParams = .init()) async throws -> TranscriptionPageList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path(),
            query: params.queryItems()
        ))
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: TranscriptionPageList) async throws -> TranscriptionPageList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    public func fetch(sid: String) async throws -> Transcription {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path(sid)
        ))
    }

    public func delete(sid: String) async throws {
        try await transport.requestVoid(VoiceMLRequest(
            method: .delete,
            path: try path(sid)
        ))
    }
}

/// `/Exports.json` — the account's nightly event-log archives.
public final class ExportsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: String...) throws -> String {
        try transport.accountPath(["Exports"] + parts)
    }

    /// List the available daily archives, newest first.
    public func list() async throws -> ExportList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path()
        ))
    }

    /// Download one day's archive. The server answers 302 with a presigned URL; the
    /// redirect is followed manually and never carries credentials (same machinery as
    /// `recordings.getAudio`).
    public func download(date: String) async throws -> (Data, HTTPURLResponse) {
        try await transport.fetchBytes(path: try transport.accountPath(["Exports", date], suffix: ""), jsonSuffix: false)
    }
}

/// `/Usage/Records…` — usage summaries per category over a window.
public final class UsageRecordsResource: Sendable {
    private let transport: Transport

    init(transport: Transport) {
        self.transport = transport
    }

    private func path(_ parts: [String]) throws -> String {
        try transport.accountPath(["Usage", "Records"] + parts)
    }

    /// All categories over the requested window.
    public func list(_ params: ListUsageRecordsParams = .init()) async throws -> UsageRecordList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path([]),
            query: params.queryItems()
        ))
    }

    public func listAllTime(_ params: ListUsageRecordsParams = .init()) async throws -> UsageRecordList {
        try await windowed("AllTime", params)
    }

    public func listDaily(_ params: ListUsageRecordsParams = .init()) async throws -> UsageRecordList {
        try await windowed("Daily", params)
    }

    public func listLastMonth(_ params: ListUsageRecordsParams = .init()) async throws -> UsageRecordList {
        try await windowed("LastMonth", params)
    }

    public func listMonthly(_ params: ListUsageRecordsParams = .init()) async throws -> UsageRecordList {
        try await windowed("Monthly", params)
    }

    public func listThisMonth(_ params: ListUsageRecordsParams = .init()) async throws -> UsageRecordList {
        try await windowed("ThisMonth", params)
    }

    public func listToday(_ params: ListUsageRecordsParams = .init()) async throws -> UsageRecordList {
        try await windowed("Today", params)
    }

    public func listYearly(_ params: ListUsageRecordsParams = .init()) async throws -> UsageRecordList {
        try await windowed("Yearly", params)
    }

    public func listYesterday(_ params: ListUsageRecordsParams = .init()) async throws -> UsageRecordList {
        try await windowed("Yesterday", params)
    }

    /// Fetch the page after `page`, following its `next_page_uri` verbatim.
    public func nextPage(of page: UsageRecordList) async throws -> UsageRecordList? {
        guard let url = transport.resolvePageURI(page.nextPageUri) else { return nil }
        return try await transport.requestPage(url)
    }

    private func windowed(_ window: String, _ params: ListUsageRecordsParams) async throws -> UsageRecordList {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: try path([window]),
            query: params.queryItems()
        ))
    }
}
