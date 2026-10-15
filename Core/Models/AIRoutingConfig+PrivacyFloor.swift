import Foundation

/// Privacy floor (ROADMAP 4a, innovation 2): a remote `/v1/config` may tighten privacy
/// but can never loosen it below the compiled-in policy.
///
/// - A task the floor keeps on device stays on device. Remote config can't send
///   personal work such as memory, plan, tools or summaries to the cloud.
/// - A tier the floor marks `.minimal` stays `.minimal`.
/// - A tier the floor says trains on prompts keeps `trainsOnPrompts = true` (and so
///   `.minimal`). Remote config can't relabel a training provider as safe.
extension AIRoutingConfig {
    public func clampedToPrivacyFloor(_ floor: AIRoutingConfig = .bundledDefault) -> AIRoutingConfig {
        var clampedTasks = tasks
        for (kind, floorRouting) in floor.tasks where floorRouting.route == .onDevice {
            clampedTasks[kind] = AITaskRouting(route: .onDevice)
        }

        var clampedTiers = tiers
        for (id, tier) in tiers {
            guard let floorTier = floor.tiers[id] else { continue }
            let trains = tier.trainsOnPrompts || floorTier.trainsOnPrompts
            let level: AIContextLevel = (trains || floorTier.contextLevel == .minimal) ? .minimal : tier.contextLevel
            clampedTiers[id] = AITierConfig(displayModel: tier.displayModel, trainsOnPrompts: trains, contextLevel: level)
        }

        return AIRoutingConfig(
            protocolVersion: protocolVersion,
            stream: stream,
            tasks: clampedTasks,
            tiers: clampedTiers,
            timeouts: timeouts,
            retry: retry
        )
    }

    /// True when `clampedToPrivacyFloor` would change nothing.
    public func respectsPrivacyFloor(_ floor: AIRoutingConfig = .bundledDefault) -> Bool {
        clampedToPrivacyFloor(floor) == self
    }
}
