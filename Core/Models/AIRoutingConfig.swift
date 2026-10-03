import Foundation

/// Mercury AI routing config (M3-T4).
///
/// Bundled in the app, refreshed from `GET /v1/config`, cached in Application Support.
/// Never carries API keys or device tokens — only route policy, display models, and timeouts.
public struct AIRoutingConfig: Codable, Sendable, Equatable {
    public let protocolVersion: String
    public let stream: [String]
    public let tasks: [String: AITaskRouting]
    public let tiers: [String: AITierConfig]
    public let timeouts: AIRoutingTimeouts
    public let retry: AIRoutingRetry

    public enum CodingKeys: String, CodingKey {
        case protocolVersion = "protocol"
        case stream, tasks, tiers, timeouts, retry
    }

    public init(
        protocolVersion: String,
        stream: [String],
        tasks: [String: AITaskRouting],
        tiers: [String: AITierConfig],
        timeouts: AIRoutingTimeouts,
        retry: AIRoutingRetry
    ) {
        self.protocolVersion = protocolVersion
        self.stream = stream
        self.tasks = tasks
        self.tiers = tiers
        self.timeouts = timeouts
        self.retry = retry
    }

    /// Owner-policy default: answer → Gemini Flash (minimal); plan/tools/memory/summaries on-device.
    public static let bundledDefault: AIRoutingConfig = makeBundledDefault()

    /// Compact JSON matching `Resources/ai-routing.default.json` / gateway `config.json` semantics.
    public static let bundledDefaultJSON =
        #"{"protocol":"v1","stream":["meta","delta","done","error"],"#
        + #""tasks":{"answer":{"route":"cloud","tier":"main"},"plan":{"route":"onDevice"},"#
        + #""tools":{"route":"onDevice"},"memory":{"route":"onDevice"},"summaries":{"route":"onDevice"}},"#
        + #""tiers":{"main":{"displayModel":"Gemini Flash","trainsOnPrompts":true,"contextLevel":"minimal"},"#
        + #""backup":{"displayModel":"Groq gpt-oss-120b","trainsOnPrompts":false,"contextLevel":"standard"},"#
        + #""lastResort":{"displayModel":"Workers AI","trainsOnPrompts":false,"contextLevel":"standard"}},"#
        + #""timeouts":{"connect":10,"firstEvent":20,"idle":15,"total":90},"#
        + #""retry":{"maxAttempts":1,"honorRetryAfter":true}}"#

    public static func decodeAndValidate(_ data: Data) throws -> AIRoutingConfig {
        try rejectSecretKeys(in: data)
        let config = try JSONDecoder().decode(AIRoutingConfig.self, from: data)
        try config.validate()
        return config
    }

    public func validate() throws {
        guard protocolVersion == "v1" else {
            throw AIRoutingConfigError.invalidProtocol(protocolVersion)
        }
        let requiredEvents: Set<String> = ["meta", "delta", "done", "error"]
        guard requiredEvents.isSubset(of: Set(stream)) else {
            throw AIRoutingConfigError.invalidStream(stream)
        }
        guard !tasks.isEmpty else {
            throw AIRoutingConfigError.emptyTasks
        }
        for (kind, routing) in tasks {
            try routing.validate(taskKind: kind, knownTiers: Set(tiers.keys))
        }
        for (id, tier) in tiers {
            try tier.validate(id: id)
        }
        try timeouts.validate()
        try retry.validate()
    }

    /// Read-only Codex summary for the primary `answer` task.
    public func answerDisplay() -> (route: String, model: String) {
        guard let routing = tasks["answer"] else {
            return ("unknown", "—")
        }
        switch routing.route {
        case .onDevice:
            return ("on-device", "Apple Intelligence")
        case .cloud:
            let tierID = routing.tier?.rawValue ?? "main"
            let model = tiers[tierID]?.displayModel ?? tierID
            return ("cloud / \(tierID)", model)
        }
    }

    private static func makeBundledDefault() -> AIRoutingConfig {
        if let decoded = try? decodeAndValidate(Data(bundledDefaultJSON.utf8)) {
            return decoded
        }
        return AIRoutingConfig(
            protocolVersion: "v1",
            stream: ["meta", "delta", "done", "error"],
            tasks: [
                "answer": AITaskRouting(route: .cloud, tier: .main),
                "plan": AITaskRouting(route: .onDevice),
                "tools": AITaskRouting(route: .onDevice),
                "memory": AITaskRouting(route: .onDevice),
                "summaries": AITaskRouting(route: .onDevice)
            ],
            tiers: [
                "main": AITierConfig(
                    displayModel: "Gemini Flash",
                    trainsOnPrompts: true,
                    contextLevel: .minimal
                ),
                "backup": AITierConfig(
                    displayModel: "Groq gpt-oss-120b",
                    trainsOnPrompts: false,
                    contextLevel: .standard
                ),
                "lastResort": AITierConfig(
                    displayModel: "Workers AI",
                    trainsOnPrompts: false,
                    contextLevel: .standard
                )
            ],
            timeouts: AIRoutingTimeouts(connect: 10, firstEvent: 20, idle: 15, total: 90),
            retry: AIRoutingRetry(maxAttempts: 1, honorRetryAfter: true)
        )
    }

    /// Forbidden key names — config must never carry secrets.
    private static let forbiddenKeys: Set<String> = [
        "apikey", "api_key",
        "secret", "password", "token", "accesstoken", "access_token",
        "bearer", "authorization",
        "gemini_api_key", "groq_api_key", "xai_api_key", "device_token",
        "devicetoken"
    ]

    private static func rejectSecretKeys(in data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIRoutingConfigError.malformed
        }
        var stack: [Any] = [root]
        while let current = stack.popLast() {
            if let dict = current as? [String: Any] {
                for (key, value) in dict {
                    let normalized = key
                        .lowercased()
                        .replacingOccurrences(of: "-", with: "_")
                    if Self.forbiddenKeys.contains(normalized) {
                        throw AIRoutingConfigError.containsSecretKey(key)
                    }
                    stack.append(value)
                }
            } else if let array = current as? [Any] {
                stack.append(contentsOf: array)
            }
        }
    }
}

public struct AITaskRouting: Codable, Sendable, Equatable {
    public enum Route: String, Codable, Sendable {
        case onDevice
        case cloud
    }

    public let route: Route
    public let tier: AICloudTier?

    public init(route: Route, tier: AICloudTier? = nil) {
        self.route = route
        self.tier = tier
    }

    func validate(taskKind: String, knownTiers: Set<String>) throws {
        switch route {
        case .onDevice:
            break
        case .cloud:
            guard let tier else {
                throw AIRoutingConfigError.cloudMissingTier(taskKind)
            }
            guard knownTiers.contains(tier.rawValue) else {
                throw AIRoutingConfigError.unknownTier(tier.rawValue)
            }
        }
    }
}

public enum AICloudTier: String, Codable, Sendable, CaseIterable {
    case main
    case backup
    case lastResort
}

public enum AIContextLevel: String, Codable, Sendable, CaseIterable {
    case standard
    case minimal
}

public struct AITierConfig: Codable, Sendable, Equatable {
    public let displayModel: String
    public let trainsOnPrompts: Bool
    public let contextLevel: AIContextLevel

    public init(displayModel: String, trainsOnPrompts: Bool, contextLevel: AIContextLevel) {
        self.displayModel = displayModel
        self.trainsOnPrompts = trainsOnPrompts
        self.contextLevel = contextLevel
    }

    func validate(id: String) throws {
        let trimmed = displayModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AIRoutingConfigError.emptyDisplayModel(id)
        }
        if trainsOnPrompts, contextLevel != .minimal {
            throw AIRoutingConfigError.trainsRequiresMinimal(id)
        }
    }
}

public struct AIRoutingTimeouts: Codable, Sendable, Equatable {
    public let connect: Double
    public let firstEvent: Double
    public let idle: Double
    public let total: Double

    public init(connect: Double, firstEvent: Double, idle: Double, total: Double) {
        self.connect = connect
        self.firstEvent = firstEvent
        self.idle = idle
        self.total = total
    }

    func validate() throws {
        guard connect > 0, firstEvent > 0, idle > 0, total > 0 else {
            throw AIRoutingConfigError.invalidTimeouts
        }
        guard total >= connect, total >= firstEvent else {
            throw AIRoutingConfigError.invalidTimeouts
        }
    }
}

public struct AIRoutingRetry: Codable, Sendable, Equatable {
    public let maxAttempts: Int
    public let honorRetryAfter: Bool

    public init(maxAttempts: Int, honorRetryAfter: Bool) {
        self.maxAttempts = maxAttempts
        self.honorRetryAfter = honorRetryAfter
    }

    func validate() throws {
        // M3-T4 / M3-T5: at most one bounded retry for now.
        guard (0...1).contains(maxAttempts) else {
            throw AIRoutingConfigError.invalidRetry(maxAttempts)
        }
    }
}

public enum AIRoutingConfigError: Error, Equatable, Sendable {
    case malformed
    case invalidProtocol(String)
    case invalidStream([String])
    case emptyTasks
    case cloudMissingTier(String)
    case unknownTier(String)
    case emptyDisplayModel(String)
    case trainsRequiresMinimal(String)
    case invalidTimeouts
    case invalidRetry(Int)
    case containsSecretKey(String)
}
