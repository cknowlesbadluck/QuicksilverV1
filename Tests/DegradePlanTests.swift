import Foundation
import Testing
@testable import Core

@Suite("Degrade planner")
struct DegradePlanTests {
    @Test func ownerGateKeepsSettingNamesAndDropsValues() {
        let plan = DegradePlanner.plan(HostProbe(
            status: 503,
            missingRequired: ["SUPABASE_SERVICE_ROLE_KEY", "postgres://user:secret@db/app"],
            bodyText: "eyJhbGciOiJIUzI1NiJ9.payload"
        ))
        #expect(plan == DegradePlan(
            host: .ownerGate,
            action: .askOwner,
            retryable: false,
            missingNames: ["SUPABASE_SERVICE_ROLE_KEY"]
        ))
    }

    @Test func absentAliasIsNotAnOwnerGate() {
        let plan = DegradePlanner.plan(HostProbe(
            status: 404,
            bodyText: "DEPLOYMENT_NOT_FOUND",
            missingRequired: ["SUPABASE_SERVICE_ROLE_KEY"]
        ))
        #expect(plan.action == .ignoreAlias)
        #expect(plan.host == .aliasAbsent)
        #expect(plan.missingNames.isEmpty)
    }

    @Test func budgetStaysLocalAndRateLimitBacksOff() {
        #expect(DegradePlanner.plan(HostProbe(status: 200, code: "budget_exhausted")).action == .stayLocal)
        let limited = DegradePlanner.plan(HostProbe(status: 429))
        #expect(limited.action == .backoff)
        #expect(limited.retryable)
    }

    @Test func authAndUnknownFailClosed() {
        #expect(DegradePlanner.plan(HostProbe(status: 401)).action == .reauth)
        #expect(DegradePlanner.plan(HostProbe(status: 200, code: "ready")).action == .proceed)
        #expect(DegradePlanner.plan(HostProbe(status: 500, bodyText: "boom")).action == .stayLocal)
    }
}
