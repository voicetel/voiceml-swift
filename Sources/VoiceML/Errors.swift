import Foundation

/// Base class for every error raised by the VoiceML SDK.
///
/// Concrete error types are reference types so callers can `catch let err as NotFoundError`
/// (Swift's type-pattern catch requires a class for cross-target inheritance to work cleanly).
/// Wrap them in `do/catch` blocks and switch on the concrete subtype to branch on HTTP
/// status family.
public class VoiceMLError: Error, @unchecked Sendable, CustomStringConvertible {
    /// Human-readable description of the failure. Mirrors `Error.localizedDescription`.
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String {
        "\(type(of: self)): \(message)"
    }

    public var localizedDescription: String { description }
}

/// Raised when the client is constructed with conflicting or missing config, or when a
/// caller-supplied identifier is malformed before any request is sent.
public final class ConfigurationError: VoiceMLError, @unchecked Sendable {}

/// Raised when the API returns a non-2xx response.
///
/// The Twilio-compatible error body (`{code, message, more_info, status}`) is parsed into
/// `code` / `message` / `status` when present, with the raw payload exposed on `body`.
public class ApiError: VoiceMLError, @unchecked Sendable {
    public let statusCode: Int
    /// Numeric error code from the response body, when the server included one.
    public let code: Int?
    public let body: Data?
    /// Twilio-compatible `more_info` URL pointing to human docs for this error code, when the
    /// server included one in the response body. `nil` for transport errors, decoding
    /// failures, or 5xx responses without a structured body.
    public let moreInfo: String?
    /// `status` field from the response body when present (mirrors `statusCode`).
    public let responseStatus: Int?
    public var status: Int? { responseStatus }
    /// Parsed `Retry-After` delay in seconds, when the response carried one (429 responses).
    public let retryAfter: TimeInterval?

    public init(
        message: String,
        statusCode: Int,
        code: Int? = nil,
        body: Data? = nil,
        moreInfo: String? = nil,
        responseStatus: Int? = nil,
        retryAfter: TimeInterval? = nil
    ) {
        self.statusCode = statusCode
        self.code = code
        self.body = body
        self.moreInfo = moreInfo
        self.responseStatus = responseStatus
        self.retryAfter = retryAfter
        super.init(message)
    }

    public override var description: String {
        "\(type(of: self))(statusCode=\(statusCode), code=\(code.map(String.init) ?? "nil")): \(message)"
    }
}

/// A connection, TLS, timeout or response-transfer failure. The original error is
/// retained on `cause`; cancellation errors are propagated directly instead.
public final class TransportError: VoiceMLError, @unchecked Sendable {
    public let cause: Error

    public init(message: String, cause: Error) {
        self.cause = cause
        super.init(message)
    }
}

/// Raised when a 2xx response body could not be decoded into the expected model.
/// Carries the underlying `DecodingError` on ``cause``.
public final class DecodingFailedError: VoiceMLError, @unchecked Sendable {
    public let statusCode: Int
    public let body: Data?
    public let cause: Error

    public init(message: String, statusCode: Int, body: Data?, cause: Error) {
        self.statusCode = statusCode
        self.body = body
        self.cause = cause
        super.init(message)
    }

    public override var description: String {
        "\(type(of: self))(statusCode=\(statusCode)): \(message) (cause: \(cause))"
    }
}

/// HTTP 400 — the request was malformed or failed server-side validation.
public final class BadRequestError: ApiError, @unchecked Sendable {}

/// HTTP 401 — Basic auth missing, account unknown, key wrong, or source IP not allowed.
///
/// The server intentionally returns an identical 401 for all four failure modes.
public final class AuthenticationError: ApiError, @unchecked Sendable {}

/// HTTP 403 — authenticated, but not allowed to perform this action.
public final class PermissionDeniedError: ApiError, @unchecked Sendable {}

/// HTTP 404 — the resource does not exist (or belongs to a different tenant).
public final class NotFoundError: ApiError, @unchecked Sendable {}

/// HTTP 409 — request conflicts with current resource state (e.g. deleting a non-empty
/// queue, or an optimistic-locking conflict on account update).
public final class ConflictError: ApiError, @unchecked Sendable {}

/// HTTP 410 — recording audio is no longer available (no local file, no S3 key).
public final class GoneError: ApiError, @unchecked Sendable {}

/// HTTP 429 — per-account rate limit exceeded. The parsed `Retry-After` delay (seconds or
/// HTTP-date), when the server sent one, is exposed on `retryAfter`.
public final class RateLimitError: ApiError, @unchecked Sendable {}

/// HTTP 501 — endpoint is mounted as a stub (e.g. `UserDefinedMessages`).
public final class NotImplementedAPIError: ApiError, @unchecked Sendable {}

/// HTTP 5xx — the server hit an error processing the request.
public final class ServerError: ApiError, @unchecked Sendable {}

/// Map an HTTP status code to the most specific ``ApiError`` subclass.
public func errorFromResponse(
    statusCode: Int,
    code: Int?,
    body: Data?,
    message: String,
    moreInfo: String? = nil,
    responseStatus: Int? = nil,
    retryAfter: TimeInterval? = nil
) -> ApiError {
    switch statusCode {
    case 400:
        return BadRequestError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    case 401:
        return AuthenticationError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    case 403:
        return PermissionDeniedError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    case 404:
        return NotFoundError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    case 409:
        return ConflictError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    case 410:
        return GoneError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    case 429:
        return RateLimitError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    case 501:
        return NotImplementedAPIError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    case 500...599:
        return ServerError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    default:
        return ApiError(message: message, statusCode: statusCode, code: code, body: body, moreInfo: moreInfo, responseStatus: responseStatus, retryAfter: retryAfter)
    }
}
