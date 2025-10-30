import Foundation

struct AISettings: Equatable {
    var model: String
    var apiKey: String
    var temperature: Double
    var topP: Double

    static let `default` = AISettings(
        model: "gemini-2.0-flash",
        apiKey: "",
        temperature: 0.4,
        topP: 0.95
    )
}
