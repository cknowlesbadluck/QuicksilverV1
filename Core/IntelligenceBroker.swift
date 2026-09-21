import Foundation

/// Gates a single intelligence turn against a ResourcePlan.
/// Pure policy: no networking, no UI, no storage.
/// Callers (MercuryBrain) supply the plan and enforce the decision.
public struct IntelligenceBroker: Sendable {

    public init() {}

    public struct TurnRequest: Sendable {
        public let intent: Intent
        public let aspect: Aspect
        public let plan: ResourcePlan
        public let estimatedContextTokens: Int

        public init(
            intent: Intent,
            aspect: Aspect,
            plan: ResourcePlan = .interactive,
            estimatedContextTokens: Int = 0
        ) {
            self.intent = intent
            self.aspect = aspect
            self.plan = plan
            self.estimatedContextTokens = max(0, estimatedContextTokens)
        }
    }

    public enum Decision: Sendable, Equatable {
        case allow(ResourcePlan)
        case deny(reason: String)
        case degrade(ResourcePlan, reason: String)
    }

    /// Decide whether a turn may proceed and under what budget.
    public func evaluate(_ request: TurnRequest) -> Decision {
        let plan = request.plan

        if request.estimatedContextTokens > plan.maxContextTokens {
            // Degrade to a tighter plan rather than hard-fail interactive work.
            let tighter = ResourcePlan(
                maxContextTokens: plan.maxContextTokens,
                maxOutputTokens: min(plan.maxOutputTokens, 512),
                maxWallClockSeconds: plan.maxWallClockSeconds,
                allowExternalCalls: plan.allowExternalCalls,
                priority: plan.priority
            )
            return .degrade(tighter, reason: "context exceeds budget; output clamped")
        }

        // Background plans never allow external calls.
        if !plan.allowExternalCalls && request.intent.kind == .inquire {
            return .deny(reason: "external calls disabled for this plan")
        }

        // Elevated aspect prefers elevated budget when caller sent interactive default.
        if request.aspect == .forge && plan.priority == .normal {
            return .allow(.elevated)
        }

        return .allow(plan)
    }

    /// Map Intent → default ResourcePlan.
    public func defaultPlan(for intent: Intent) -> ResourcePlan {
        switch intent.kind {
        case .diagnose, .create:
            return .elevated
        case .observe, .retrieve:
            return .background
        case .remember:
            return ResourcePlan(
                maxContextTokens: 2_048,
                maxOutputTokens: 256,
                maxWallClockSeconds: 20,
                allowExternalCalls: false,
                priority: .low
            )
        case .inquire, .express, .switchAspect, .unknown:
            return .interactive
        }
    }
}
