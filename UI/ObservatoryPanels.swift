import SwiftUI
import Nexus

// MARK: - Observatory panels
// Stateless presentation pieces moved from EternalView.swift. Internal (were
// private methods) so EternalView can compose them across files.

struct ObservatoryHeader: View {
    let isAwake: Bool
    let livingStatus: String
    let accent: Color
    let radius: CGFloat

    var body: some View {
        HStack(spacing: 14) {
            ObservatoryLens(accent: accent, active: isAwake)
            VStack(alignment: .leading, spacing: 4) {
                Text("THE OBSERVATORY")
                    .font(.caption.weight(.bold))
                    .tracking(1.8)
                    .foregroundStyle(PersonaTheme.mercurySilver)
                Text(livingStatus)
                    .font(.subheadline)
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.82))
                    .lineLimit(2)
            }
            Spacer()
            Text(isAwake ? "OBSERVING" : "QUIESCENT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(isAwake ? accent : .secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial.opacity(0.52), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.4), lineWidth: 1)
        )
    }
}

struct ObservatorySignalsRow: View {
    let batteryLevelText: String
    let networkStatus: String
    let thermalState: String
    let overallHealthScore: Int
    let radius: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            signalTile("Battery", batteryLevelText)
            signalTile("Network", networkStatus)
            signalTile("Thermal", thermalState)
            signalTile("Health", "\(overallHealthScore)")
        }
    }

    private func signalTile(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PersonaTheme.mercurySilver)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            .ultraThinMaterial.opacity(0.3),
            in: RoundedRectangle(cornerRadius: max(8, radius - 4), style: .continuous)
        )
    }
}

struct ObservatoryInsightCard: View {
    let insight: Insight
    let accent: Color
    let radius: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LATEST INSIGHT")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text(insight.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PersonaTheme.mercurySilver)
            if !insight.body.isEmpty {
                Text(insight.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.24), lineWidth: 1)
        )
    }
}

struct ObservatoryObservationsList: View {
    let observations: [String]
    let radius: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SESSION OBSERVATIONS")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            ForEach(Array(observations.enumerated()), id: \.offset) { _, note in
                Text(note)
                    .font(.caption)
                    .foregroundStyle(PersonaTheme.mercurySilver.opacity(0.9))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        .ultraThinMaterial.opacity(0.25),
                        in: RoundedRectangle(cornerRadius: radius * 0.5, style: .continuous)
                    )
            }
        }
    }
}

struct ObservatoryAnswerCard: View {
    let answer: String
    let accent: Color
    let radius: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RESPONSE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent)
            Text(answer)
                .font(.subheadline)
                .foregroundStyle(PersonaTheme.mercurySilver)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(accent.opacity(0.32), lineWidth: 1)
        )
    }
}
