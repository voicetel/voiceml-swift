import Foundation

// Twilio Pricing v1/v2 (pricing.twilio.com) — read-only rate cards (#18).
//
// VoiceML has no dedicated pricing subdomain, so these live on the default
// host (voiceml.voicetel.com) under /v1 and /v2. Every field is optional /
// permissive: rate cards vary by product and tenant, and a partial payload
// must decode rather than throw. Snake_case wire keys map to camelCase via the
// transport's `.convertFromSnakeCase` strategy.

// MARK: - Price leaves

public struct PricingInboundCallPrice: Codable, Sendable {
    public var basePrice: String?
    public var currentPrice: String?
    public var numberType: String?
}

public struct PricingOutboundCallPrice: Codable, Sendable {
    public var basePrice: String?
    public var currentPrice: String?
}

public struct PricingOutboundCallPriceWithOrigin: Codable, Sendable {
    public var originationPrefixes: [String]?
    public var basePrice: String?
    public var currentPrice: String?
}

public struct PricingOutboundPrefixPrice: Codable, Sendable {
    public var prefixes: [String]?
    public var basePrice: String?
    public var currentPrice: String?
    public var friendlyName: String?
}

public struct PricingOutboundPrefixPriceWithOrigin: Codable, Sendable {
    public var originationPrefixes: [String]?
    public var destinationPrefixes: [String]?
    public var basePrice: String?
    public var currentPrice: String?
    public var friendlyName: String?
}

public struct PricingOutboundSMSPrice: Codable, Sendable {
    public var carrier: String?
    public var mcc: String?
    public var mnc: String?
    public var prices: [PricingInboundCallPrice]?
}

public struct PricingPhoneNumberPrice: Codable, Sendable {
    public var numberType: String?
    public var basePrice: String?
    public var currentPrice: String?
}

// MARK: - Countries list envelope

public struct PricingCountryRef: Codable, Sendable {
    public var country: String?
    public var isoCountry: String?
    public var url: String?
}

public struct PricingCountriesList: Codable, Sendable {
    public var countries: [PricingCountryRef]?
    public var meta: V1Meta?
}

// MARK: - Pricing v1 country / number bodies

public struct PricingVoiceCountry: Codable, Sendable {
    public var country: String?
    public var isoCountry: String?
    public var outboundPrefixPrices: [PricingOutboundPrefixPrice]?
    public var inboundCallPrices: [PricingInboundCallPrice]?
    public var priceUnit: String?
    public var url: String?
}

public struct PricingVoiceNumber: Codable, Sendable {
    public var number: String?
    public var country: String?
    public var isoCountry: String?
    public var outboundCallPrice: PricingOutboundCallPrice?
    public var inboundCallPrice: PricingInboundCallPrice?
    public var priceUnit: String?
    public var url: String?
}

public struct PricingMessagingCountry: Codable, Sendable {
    public var country: String?
    public var isoCountry: String?
    public var outboundSmsPrices: [PricingOutboundSMSPrice]?
    public var inboundSmsPrices: [PricingInboundCallPrice]?
    public var priceUnit: String?
    public var url: String?
}

public struct PricingPhoneNumberCountry: Codable, Sendable {
    public var country: String?
    public var isoCountry: String?
    public var phoneNumberPrices: [PricingPhoneNumberPrice]?
    public var priceUnit: String?
    public var url: String?
}

// MARK: - Pricing v2 country / number bodies

public struct PricingVoiceCountryV2: Codable, Sendable {
    public var country: String?
    public var isoCountry: String?
    public var outboundPrefixPrices: [PricingOutboundPrefixPriceWithOrigin]?
    public var inboundCallPrices: [PricingInboundCallPrice]?
    public var priceUnit: String?
    public var url: String?
}

public struct PricingVoiceNumberV2: Codable, Sendable {
    public var destinationNumber: String?
    public var originationNumber: String?
    public var country: String?
    public var isoCountry: String?
    public var outboundCallPrices: [PricingOutboundCallPriceWithOrigin]?
    public var inboundCallPrice: PricingInboundCallPrice?
    public var priceUnit: String?
    public var url: String?
}

public struct PricingTrunkingCountry: Codable, Sendable {
    public var country: String?
    public var isoCountry: String?
    public var terminatingPrefixPrices: [PricingOutboundPrefixPriceWithOrigin]?
    public var originatingCallPrices: [PricingInboundCallPrice]?
    public var priceUnit: String?
    public var url: String?
}

public struct PricingTrunkingNumber: Codable, Sendable {
    public var destinationNumber: String?
    public var originationNumber: String?
    public var country: String?
    public var isoCountry: String?
    public var terminatingPrefixPrices: [PricingOutboundPrefixPriceWithOrigin]?
    public var originatingCallPrice: PricingInboundCallPrice?
    public var priceUnit: String?
    public var url: String?
}
