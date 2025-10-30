import Foundation

struct GeminiMessage: Codable {
    struct Part: Codable {
        let text: String
    }

    let role: String
    let parts: [Part]
}

final class GeminiClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchModels(apiKey: String) async throws -> [String] {
        guard apiKey.isEmpty == false else {
            throw ClientError.missingAPIKey
        }

        var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey), URLQueryItem(name: "pageSize", value: "200")]

        guard let url = components?.url else {
            throw ClientError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Status: \(httpResponse.statusCode)"
            throw ClientError.requestFailed(errorString)
        }

        let decoded = try JSONDecoder().decode(GeminiModelList.self, from: data)
        let names = decoded.models
            .map { $0.name }
            .compactMap { $0.split(separator: "/").last }
            .map(String.init)
            .sorted()
        return names
    }

    func generateResponse(messages: [GeminiMessage], prompt: String, settings: AISettings) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(settings.model):generateContent?key=\(settings.apiKey)"
        guard let url = URL(string: urlString) else {
            throw ClientError.invalidURL
        }

        var payloadMessages = messages
        if payloadMessages.last?.role != "user" {
            payloadMessages.append(GeminiMessage(role: "user", parts: [.init(text: prompt)]))
        }

        let requestBody = GeminiRequest(
            contents: payloadMessages,
            generationConfig: .init(temperature: settings.temperature, topP: settings.topP)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorString = String(data: data, encoding: .utf8) ?? "Status: \(httpResponse.statusCode)"
            throw ClientError.requestFailed(errorString)
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let candidate = decoded.candidates.first,
              let part = candidate.content.parts.first else {
            throw ClientError.emptyResponse
        }

        return part.text
    }

    enum ClientError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case requestFailed(String)
        case emptyResponse
        case missingAPIKey

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "URL tidak valid."
            case .invalidResponse:
                return "Respons server tidak valid."
            case .requestFailed(let detail):
                return "Permintaan gagal: \(detail)"
            case .emptyResponse:
                return "Tidak ada teks yang diterima dari model."
            case .missingAPIKey:
                return "API key tidak ditemukan."
            }
        }
    }
}

private struct GeminiRequest: Codable {
    struct GenerationConfig: Codable {
        let temperature: Double
        let topP: Double
    }

    let contents: [GeminiMessage]
    let generationConfig: GenerationConfig
}

private struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            let parts: [GeminiMessage.Part]
        }

        let content: Content
    }

    let candidates: [Candidate]
}

private struct GeminiModelList: Codable {
    struct Model: Codable {
        let name: String
    }

    let models: [Model]
}
