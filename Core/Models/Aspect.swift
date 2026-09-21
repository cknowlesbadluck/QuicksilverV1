import Foundation

/// Facets of the single Quicksilver entity.
/// Never separate products. Expression voice and visual language change;
/// identity and memory do not.
public enum Aspect: String, Sendable, Equatable, CaseIterable, Identifiable {
    case quicksilver
    case forge
    case eternal

    public var id: String { rawValue }

    /// Short label for diagnostics / Codex only. Not normal UX chrome.
    public var diagnosticLabel: String {
        switch self {
        case .quicksilver: return "Quicksilver"
        case .forge: return "Forge"
        case .eternal: return "Eternal"
        }
    }

    /// Preferred VisualState when this aspect becomes active with no stronger signal.
    public var defaultVisualState: VisualState {
        switch self {
        case .quicksilver: return .idle
        case .forge: return .thinking
        case .eternal: return .listening
        }
    }
}
