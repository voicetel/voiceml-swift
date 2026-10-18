import Foundation

/// Manual paging for a configured product host. Fetches server-provided page URLs
/// unchanged and refuses different schemes, hosts or ports before sending auth.
public struct PageClient: Sendable {
    private let transport: Transport

    init(transport: Transport) { self.transport = transport }

    public func fetch<T: Decodable>(_ url: URL) async throws -> T {
        try await transport.requestPage(url)
    }

    /// Follow a `/v1` envelope's `meta.next_page_url`. Returns nil at the end.
    public func fetchNextPage<T: Decodable>(from meta: V1Meta) async throws -> T? {
        guard let raw = meta.nextPageUrl, !raw.isEmpty else { return nil }
        guard let url = URL(string: raw), url.scheme != nil, url.host != nil else {
            throw ConfigurationError("next_page_url must be an absolute URL")
        }
        return try await fetch(url)
    }
}

/// One page's worth of iteration state: the elements to yield and the absolute URL of
/// the next page (`nil` terminates iteration).
public struct PageResult<Element: Sendable>: Sendable {
    public let items: [Element]
    public let nextURL: URL?

    public init(items: [Element], nextURL: URL?) {
        self.items = items
        self.nextURL = nextURL
    }
}

/// A lazy `AsyncSequence` that walks list pages. Pages are fetched one at a time inside
/// ``PagerIterator/next()``: no element is requested from the network before the
/// consumer asks for it, and abandoning the sequence (breaking out of `for try await`)
/// stops all further requests. The next page URL comes verbatim from the previous
/// page's `next_page_uri` (resolved against the request's scheme and host) — the SDK
/// never synthesises `Page=N` requests.
public struct PagerSequence<Element: Sendable>: AsyncSequence {
    public typealias AsyncIterator = PagerIterator<Element>
    public typealias Element = Element

    let firstPage: @Sendable () async throws -> PageResult<Element>
    let followPage: @Sendable (URL) async throws -> PageResult<Element>

    public func makeAsyncIterator() -> PagerIterator<Element> {
        PagerIterator(firstPage: firstPage, followPage: followPage)
    }
}

/// Iterator behind ``PagerSequence``. `next()` fetches only when its element buffer is
/// exhausted, so a consumer that stops early triggers no further requests.
public final class PagerIterator<Element: Sendable>: AsyncIteratorProtocol {
    private var buffer: [Element] = []
    private var index = 0
    private var nextURL: URL?
    private var started = false
    private let firstPage: @Sendable () async throws -> PageResult<Element>
    private let followPage: @Sendable (URL) async throws -> PageResult<Element>

    init(
        firstPage: @escaping @Sendable () async throws -> PageResult<Element>,
        followPage: @escaping @Sendable (URL) async throws -> PageResult<Element>
    ) {
        self.firstPage = firstPage
        self.followPage = followPage
    }

    public func next() async throws -> Element? {
        try Task.checkCancellation()
        while index == buffer.count {
            let page: PageResult<Element>
            if !started {
                started = true
                page = try await firstPage()
            } else if let url = nextURL {
                page = try await followPage(url)
            } else {
                return nil
            }
            buffer = page.items
            index = 0
            nextURL = page.nextURL
            if buffer.isEmpty && nextURL == nil {
                return nil
            }
        }
        defer { index += 1 }
        return buffer[index]
    }
}
