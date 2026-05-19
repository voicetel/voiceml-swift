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

/// Raised when the client is constructed with conflicting or missing config.
public final class ConfigurationError: VoiceMLError, @unchecked Sendable {}

/// Raised when the API returns a non-2xx response.
///
/// The Twilio-shape error body (`{code, message, more_info, status}`) is parsed into
/// `code` / `message` when present, with the raw payload exposed on `body`.
public class ApiError: VoiceMLError, @unchecked Sendable {
    public let statusCode: Int
    public let code: String?
    public let body: Data?

    public init(message: String, statusCode: Int, code: String? = nil, body: Data? = nil) {
        self.statusCode = statusCode
        self.code = code
        self.body = body
        super.init(message)
    }

    public override var description: String {
        "\(type(of: self))(statusCode=\(statusCode), code=\(code ?? "nil")): \(message)"
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

/// HTTP 409 — request conflicts with current resource state (e.g. deleting a non-empty queue).
public final class ConflictError: ApiError, @unchecked Sendable {}

/// HTTP 410 — recording audio is no longer available (no local file, no S3 key).
public final class GoneError: ApiError, @unchecked Sendable {}

/// HTTP 429 — per-account rate limit exceeded. `Retry-After` header may hint when to retry.
public final class RateLimitError: ApiError, @unchecked Sendable {}

/// HTTP 501 — endpoint is mounted as a stub (e.g. `UserDefinedMessages`).
public final class NotImplementedAPIError: ApiError, @unchecked Sendable {}

/// HTTP 5xx — the server hit an error processing the request.
public final class ServerError: ApiError, @unchecked Sendable {}

/// Map an HTTP status code to the most specific ``ApiError`` subclass.
public func errorFromResponse(
    statusCode: Int,
    code: String?,
    body: Data?,
    message: String
) -> ApiError {
    switch statusCode {
    case 400:
        return BadRequestError(message: message, statusCode: statusCode, code: code, body: body)
    case 401:
        return AuthenticationError(message: message, statusCode: statusCode, code: code, body: body)
    case 403:
        return PermissionDeniedError(message: message, statusCode: statusCode, code: code, body: body)
    case 404:
        return NotFoundError(message: message, statusCode: statusCode, code: code, body: body)
    case 409:
        return ConflictError(message: message, statusCode: statusCode, code: code, body: body)
    case 410:
        return GoneError(message: message, statusCode: statusCode, code: code, body: body)
    case 429:
        return RateLimitError(message: message, statusCode: statusCode, code: code, body: body)
    case 501:
        return NotImplementedAPIError(message: message, statusCode: statusCode, code: code, body: body)
    case 500...599:
        return ServerError(message: message, statusCode: statusCode, code: code, body: body)
    default:
        return ApiError(message: message, statusCode: statusCode, code: code, body: body)
    }
}
