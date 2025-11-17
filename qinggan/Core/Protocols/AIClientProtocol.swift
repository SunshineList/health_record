import Foundation

protocol AIClientProtocol {
    var host: String { get }
    func analyzeImage(data: Data, config: AIConfig) async throws -> AIDishRecognitionResponse
    func sendChat(messages: [AIMessage], summary: HealthSummary?, config: AIConfig) async throws -> AIChatResponse
}