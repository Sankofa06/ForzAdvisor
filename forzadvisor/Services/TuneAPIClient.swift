//
//  TuneAPIClient.swift
//  forzadvisor
//
//  URLSession-backed remote tune provider. It is optional: callers can fall
//  back to LocalSampleTuneProvider when no API key is configured or a call fails.
//

import Foundation

struct TuneAPIClient: TuneProvider {
    var keychainStore: any APIKeyStoring = KeychainStore()
    var session: any URLSessionProtocol = URLSession.shared
    var endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    var modelName = "claude-sonnet-4-6"
    var timeout: TimeInterval = 10

    func generateTune(for request: TuneRequest) async throws -> TuneResult {
        let payload = TuneAPIRequestPayload(request: request)
        let response: TuneAPIResponse = try await performJSONRequest(
            payload: payload,
            game: request.car.game
        )
        return response.tuneResult(for: request)
            .withProviderInfo(.direct(.anthropicAPI))
    }

    func adjustTune(previous tune: TuneResult, adjustment: TuneAdjustment) async throws -> TuneAdjustmentResult {
        let payload = TuneAPIAdjustmentPayload(
            previousTune: TuneAPIResponse(result: tune),
            adjustment: adjustment.apiValue
        )
        let response: TuneAPIResponse = try await performJSONRequest(
            payload: payload,
            game: tune.request.car.game
        )
        let adjustedTune = response.mergedTuneResult(updating: tune)
        return TuneAdjustmentResult(
            tune: adjustedTune.withProviderInfo(.direct(.anthropicAPI)),
            changes: adjustedTune.changes(comparedWith: tune)
        )
    }

    func hasConfiguredAPIKey() -> Bool {
        apiKeyStatus().hasConfiguredKey
    }

    func apiKeyStatus() -> APIKeyStatus {
        keychainStore.apiKeyStatus()
    }

    private func performJSONRequest<Response: Decodable, Payload: Encodable>(
        payload: Payload,
        game: ForzaGame
    ) async throws -> Response {
        let apiKey = try readConfiguredAPIKey()

        var request = URLRequest(url: endpoint, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder.apiEncoder.encode(AnthropicRequest(
            model: modelName,
            system: Self.systemPrompt(for: game),
            payload: payload
        ))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TuneAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw TuneAPIError.httpStatus(httpResponse.statusCode)
        }

        let envelope = try JSONDecoder.apiDecoder.decode(AnthropicResponse.self, from: data)
        guard let jsonText = envelope.firstTextBlock else {
            throw TuneAPIError.malformedJSON
        }
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw TuneAPIError.malformedJSON
        }

        do {
            return try JSONDecoder.apiDecoder.decode(Response.self, from: jsonData)
        } catch {
            throw TuneAPIError.decodingFailed(error.localizedDescription)
        }
    }
}

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

enum TuneAPIError: LocalizedError, Equatable {
    case missingAPIKey
    case apiKeyReadFailed(String)
    case invalidResponse
    case httpStatus(Int)
    case malformedJSON
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No API key is saved."
        case .apiKeyReadFailed(let detail):
            "Could not read API key: \(detail)"
        case .invalidResponse:
            "The tune service returned an invalid response."
        case .httpStatus(let status):
            "The tune service returned HTTP \(status)."
        case .malformedJSON:
            "The tune service did not return valid tune JSON."
        case .decodingFailed(let detail):
            "Could not decode tune JSON: \(detail)"
        }
    }
}

private struct AnthropicRequest<Payload: Encodable>: Encodable {
    var model: String
    var maxTokens = 2_000
    var system: String
    var messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }

    init(model: String, system: String, payload: Payload) throws {
        self.model = model
        self.system = system
        let data = try JSONEncoder.apiEncoder.encode(payload)
        let json = String(decoding: data, as: UTF8.self)
        self.messages = [
            AnthropicMessage(role: "user", content: json)
        ]
    }
}

private struct AnthropicMessage: Codable {
    var role: String
    var content: String
}

private struct AnthropicResponse: Decodable {
    var content: [AnthropicContentBlock]

    var firstTextBlock: String? {
        content.first { $0.type == "text" }?.text
    }
}

private struct AnthropicContentBlock: Decodable {
    var type: String
    var text: String?
}

extension TuneAPIClient {
    static func systemPrompt(for game: ForzaGame) -> String {
        """
    You are the ForzAdvisor \(game.title) tuning service. Return only JSON matching the provided schema.
    Do not include Markdown, prose, code fences, or fields outside the requested tune schema.
    Use complete tune-menu order for generate_tune responses. For adjust_tune, return changed numeric fields and notes.
    """
    }
}

private extension TuneAPIClient {
    func readConfiguredAPIKey() throws -> String {
        do {
            guard let apiKey = try keychainStore.readAPIKey(), !apiKey.isEmpty else {
                throw TuneAPIError.missingAPIKey
            }

            return apiKey
        } catch let error as TuneAPIError {
            throw error
        } catch {
            throw TuneAPIError.apiKeyReadFailed(error.localizedDescription)
        }
    }
}

private extension TuneAdjustment {
    var apiValue: String {
        switch self {
        case .moreRotation: "more_rotation"
        case .moreStability: "more_stability"
        case .softer: "softer"
        case .stiffer: "stiffer"
        case .moreTopSpeed: "more_top_speed"
        case .moreAcceleration: "more_acceleration"
        }
    }
}

private extension JSONEncoder {
    static var apiEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var apiDecoder: JSONDecoder {
        JSONDecoder()
    }
}

private extension TuneResult {
    func changes(comparedWith previous: TuneResult) -> [TuneAdjustmentChange] {
        sections.flatMap { section in
            section.lines.compactMap { line in
                guard let oldLine = previous.sections
                    .first(where: { $0.title == section.title })?
                    .lines
                    .first(where: { $0.label == line.label }),
                    oldLine.value != line.value
                else { return nil }

                return TuneAdjustmentChange(
                    sectionTitle: section.title,
                    lineLabel: line.label,
                    oldValue: oldLine.value,
                    newValue: line.value,
                    unit: line.unit
                )
            }
        }
    }
}
