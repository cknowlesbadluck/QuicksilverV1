import Foundation
import Core

/// Builds Mercury's default free-tier provider stack without forcing API keys into Core.
public enum MercuryAIProviderFactory {
    public static func makeRouter(
        geminiAPIKey: String?,
        groqAPIKey: String?,
        openRouterAPIKey: String?
    ) async -> MercuryProviderRouter {
        let router = MercuryProviderRouter()

        if let key = geminiAPIKey, let provider = try? GeminiAIProvider(apiKey: key) {
            await router.register(provider)
        }

        if let key = groqAPIKey, let provider = try? OpenAICompatibleAIProvider.groq(apiKey: key) {
            await router.register(provider)
        }

        if let key = openRouterAPIKey, let provider = try? OpenAICompatibleAIProvider.openRouterFree(apiKey: key) {
            await router.register(provider)
        }

        return router
    }
}
