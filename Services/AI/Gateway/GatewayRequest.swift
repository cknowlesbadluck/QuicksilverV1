import Foundation
import Core

/// Encodes an `AIRequest` into a protocol v1 `GatewayChatRequest` / JSON body (M3-T8 / M3-T11).
///
/// Message order: optional non-empty system → history (user/assistant) → current user prompt.
/// Context blocks come from CloudContextPolicy via `AIRequest.context`.
public enum GatewayRequest {
    public static func makeChatBody(_ request: AIRequest) -> GatewayChatRequest {
        var messages: [GatewayMessage] = []
        if let system = request.systemPrompt, !system.isEmpty {
            messages.append(GatewayMessage(role: "system", content: system))
        }
        for turn in request.history {
            messages.append(GatewayMessage(role: turn.role.rawValue, content: turn.content))
        }
        messages.append(GatewayMessage(role: "user", content: request.prompt))
        return GatewayChatRequest(
            taskTier: "standard",
            messages: messages,
            context: request.context,
            privacy: .device,
            maxTokens: request.maxTokens
        )
    }

    public static func encodeChatBody(_ request: AIRequest) throws -> Data {
        try JSONEncoder().encode(makeChatBody(request))
    }
}
