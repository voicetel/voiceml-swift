import Foundation

/// `client.pricing` — Twilio Pricing v1/v2 (pricing.twilio.com) (#18).
///
/// Read-only. Served on the default host (VoiceML has no pricing subdomain).
///
/// ```
/// client.pricing.v1.voice.countries.list() / .fetch(_:)
/// client.pricing.v1.voice.numbers.fetch(_:)
/// client.pricing.v1.messaging.countries.list() / .fetch(_:)
/// client.pricing.v1.phoneNumbers.countries.list() / .fetch(_:)
/// client.pricing.v2.voice.countries.list() / .fetch(_:)
/// client.pricing.v2.voice.numbers.fetch(_:originationNumber:)
/// client.pricing.v2.trunking.countries.list() / .fetch(_:)
/// client.pricing.v2.trunking.numbers.fetch(_:originationNumber:)
/// ```
///
/// Every `countries.list` returns the shared ``PricingCountriesList`` envelope;
/// `fetch` returns the product-specific country/number body.
public final class PricingResource: Sendable {
    public let v1: PricingV1Resource
    public let v2: PricingV2Resource

    init(transport: Transport) {
        self.v1 = PricingV1Resource(transport: transport)
        self.v2 = PricingV2Resource(transport: transport)
    }
}

// MARK: - Generic Countries resource

/// `.../Countries` list + per-country fetch. `Body` is the fetch response type.
public final class PricingCountriesResource<Body: Decodable & Sendable>: Sendable {
    private let transport: Transport
    private let basePath: String
    init(transport: Transport, basePath: String) {
        self.transport = transport
        self.basePath = basePath
    }

    public func list(_ params: ListV1PageParams = .init()) async throws -> PricingCountriesList {
        try await transport.request(VoiceMLRequest(method: .get, path: basePath, query: params.queryItems()))
    }
    public func fetch(_ isoCountry: String) async throws -> Body {
        try await transport.request(VoiceMLRequest(method: .get, path: "\(basePath)/\(isoCountry)"))
    }
}

// MARK: - Numbers resources (path segment is URL-encoded — E.164 `+` → `%2B`)

public final class PricingV1VoiceNumbersResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func fetch(_ number: String) async throws -> PricingVoiceNumber {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v1/Voice/Numbers/\(percentEncodePathSegment(number))",
            encodedPath: true
        ))
    }
}

public final class PricingV2VoiceNumbersResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func fetch(_ destinationNumber: String, originationNumber: String? = nil) async throws -> PricingVoiceNumberV2 {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v2/Voice/Numbers/\(percentEncodePathSegment(destinationNumber))",
            query: [QueryItem("OriginationNumber", originationNumber)],
            encodedPath: true
        ))
    }
}

public final class PricingV2TrunkingNumbersResource: Sendable {
    private let transport: Transport
    init(transport: Transport) { self.transport = transport }

    public func fetch(_ destinationNumber: String, originationNumber: String? = nil) async throws -> PricingTrunkingNumber {
        try await transport.request(VoiceMLRequest(
            method: .get,
            path: "/v2/Trunking/Numbers/\(percentEncodePathSegment(destinationNumber))",
            query: [QueryItem("OriginationNumber", originationNumber)],
            encodedPath: true
        ))
    }
}

// MARK: - Product groups

public final class PricingV1VoiceResource: Sendable {
    public let countries: PricingCountriesResource<PricingVoiceCountry>
    public let numbers: PricingV1VoiceNumbersResource
    init(transport: Transport) {
        self.countries = PricingCountriesResource(transport: transport, basePath: "/v1/Voice/Countries")
        self.numbers = PricingV1VoiceNumbersResource(transport: transport)
    }
}

public final class PricingV1MessagingResource: Sendable {
    public let countries: PricingCountriesResource<PricingMessagingCountry>
    init(transport: Transport) {
        self.countries = PricingCountriesResource(transport: transport, basePath: "/v1/Messaging/Countries")
    }
}

public final class PricingV1PhoneNumbersResource: Sendable {
    public let countries: PricingCountriesResource<PricingPhoneNumberCountry>
    init(transport: Transport) {
        self.countries = PricingCountriesResource(transport: transport, basePath: "/v1/PhoneNumbers/Countries")
    }
}

public final class PricingV2VoiceResource: Sendable {
    public let countries: PricingCountriesResource<PricingVoiceCountryV2>
    public let numbers: PricingV2VoiceNumbersResource
    init(transport: Transport) {
        self.countries = PricingCountriesResource(transport: transport, basePath: "/v2/Voice/Countries")
        self.numbers = PricingV2VoiceNumbersResource(transport: transport)
    }
}

public final class PricingV2TrunkingResource: Sendable {
    public let countries: PricingCountriesResource<PricingTrunkingCountry>
    public let numbers: PricingV2TrunkingNumbersResource
    init(transport: Transport) {
        self.countries = PricingCountriesResource(transport: transport, basePath: "/v2/Trunking/Countries")
        self.numbers = PricingV2TrunkingNumbersResource(transport: transport)
    }
}

public final class PricingV1Resource: Sendable {
    public let voice: PricingV1VoiceResource
    public let messaging: PricingV1MessagingResource
    public let phoneNumbers: PricingV1PhoneNumbersResource
    init(transport: Transport) {
        self.voice = PricingV1VoiceResource(transport: transport)
        self.messaging = PricingV1MessagingResource(transport: transport)
        self.phoneNumbers = PricingV1PhoneNumbersResource(transport: transport)
    }
}

public final class PricingV2Resource: Sendable {
    public let voice: PricingV2VoiceResource
    public let trunking: PricingV2TrunkingResource
    init(transport: Transport) {
        self.voice = PricingV2VoiceResource(transport: transport)
        self.trunking = PricingV2TrunkingResource(transport: transport)
    }
}
