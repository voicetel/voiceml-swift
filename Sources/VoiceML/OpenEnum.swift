import Foundation

/// Behaviour shared by every response-side enum surfaced as an open struct: unknown
/// wire values decode instead of throwing, so a forward-revved server adding an enum
/// value never fails decoding of a whole list page. Synthesised `Codable` reads and
/// writes the single `rawValue` string; equality and `switch` pattern matching work
/// through `Hashable`/`Equatable`.
public protocol OpenStringEnum: RawRepresentable, Codable, Sendable, Hashable {
    init(rawValue: String)
}

extension OpenStringEnum where RawValue == String {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Convenience for call sites that pass a plain string.
    public init(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
}
