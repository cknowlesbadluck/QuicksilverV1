import Foundation
import Core

/// Encodes an `AIRequest` into a protocol v1 `GatewayChatRequest` / JSON body (M3-T8).
///
/// Message order: optional non-empty system → history (user/assistant) → current user prompt.
/// Context blocks are empty here; CloudContextPolicy fills them in M3-T11.
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
            context: [],
            privacy: .device,
            maxTokens: request.maxTokens
        )
    }

    public static func encodeChatBody(_ request: AIRequest) throws -> Data {
        try JSONEncoder().encode(makeChatBody(request))
    }
}
