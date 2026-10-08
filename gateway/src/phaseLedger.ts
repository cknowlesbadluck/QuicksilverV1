/**
 * Quicksilver side of the portfolio phase ledger.
 * Simulator CI is not device acceptance.
 */

export type PhaseState = "met" | "owner_blocked" | "open" | "refused";

export type Phase = { id: number; name: string; state: PhaseState };

export function evaluateDevicePhases(input: {
  conduitReady: boolean;
  resonanceOwnerGate: boolean;
  aliasAbsent: boolean;
  hardwareRunRecorded: boolean;
  witnessBudgetSpent: boolean;
}): Phase[] {
  return [
    { id: 1, name: "Owner gate", state: input.resonanceOwnerGate ? "owner_blocked" : "open" },
    { id: 2, name: "Alias absence", state: input.aliasAbsent ? "open" : "met" },
    { id: 3, name: "Entropy governor", state: input.witnessBudgetSpent ? "met" : "open" },
    { id: 4, name: "Collapse planners", state: "open" },
    { id: 5, name: "Device fence", state: input.hardwareRunRecorded ? "met" : "owner_blocked" },
    { id: 6, name: "Gateway fail-closed", state: "open" },
    { id: 7, name: "Hygiene prune", state: "open" },
    { id: 8, name: "Single iOS target", state: "open" },
    { id: 9, name: "No secret in gateway config", state: "refused" },
    { id: 10, name: "Cross-plane acceptance", state: input.conduitReady && input.hardwareRunRecorded && !input.resonanceOwnerGate ? "met" : "open" },
  ];
}

export function bindingPhase(phases: Phase[]): number {
  return phases.find((phase) => phase.state === "owner_blocked")?.id ?? 0;
}
