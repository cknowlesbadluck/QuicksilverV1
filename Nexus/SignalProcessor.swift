import Foundation

public struct SignalProcessor: Sendable {
    public init() {}

    public func networkSignal(isConnected: Bool, isExpensive: Bool, isConstrained: Bool) -> Signal {
        let value: String
        if !isConnected {
            value = "disconnected"
        } else if isConstrained {
            value = "constrained"
        } else if isExpensive {
            value = "expensive"
        } else {
            value = "satisfied"
        }

        return Signal(
            source: .network,
            category: .connectivity,
            value: value,
            numericValue: isConnected ? 1.0 : 0.0,
            confidence: 0.95,
            metadata: [
                "expensive": String(isExpensive),
                "constrained": String(isConstrained)
            ]
        )
    }

    public func batterySignal(level: Double, stateDescription: String) -> Signal {
        Signal(
            source: .battery,
            category: .power,
            value: stateDescription,
            numericValue: level,
            confidence: 0.9,
            metadata: ["level": String(format: "%.2f", level)]
        )
    }

    public func storageSignal(availableGB: Double, totalGB: Double) -> Signal {
        let usedRatio = totalGB > 0 ? (totalGB - availableGB) / totalGB : 0
        return Signal(
            source: .storage,
            category: .capacity,
            value: String(format: "%.1f GB free", availableGB),
            numericValue: availableGB,
            confidence: 0.85,
            metadata: [
                "availableGB": String(format: "%.1f", availableGB),
                "totalGB": String(format: "%.1f", totalGB),
                "usedRatio": String(format: "%.2f", usedRatio)
            ]
        )
    }

    public func deviceSignal(thermal: String, lowPower: Bool) -> Signal {
        // Emit both keys so SignalPipeline autonomy mapping and any
        // coordinator-side merges stay consistent.
        Signal(
            source: .device,
            category: .performance,
            value: thermal,
            confidence: 0.8,
            metadata: [
                "lowPowerMode": String(lowPower),
                "lowPower": String(lowPower)
            ]
        )
    }
}
