import Foundation

/// Where one assistant reply was produced. Shown per reply in Ask so the user can
/// see, turn by turn, whether anything left the device.
public struct AnswerProvenance: Sendable, Equatable {
    public enum Origin: String, Sendable, Equatable {
        case onDevice
        case cloud
        /// Answered from saved notes on device, with no model call.
        case memory
    }

    public let origin: Origin
    /// Display name of the provider that answered (e.g. "Gemini").
    public let providerName: String

    public init(origin: Origin, providerName: String) {
        self.origin = origin
        self.providerName = providerName
    }

    public static let onDevice = AnswerProvenance(origin: .onDevice, providerName: OnDeviceAIProvider.routeName)
    public static let memory = AnswerProvenance(origin: .memory, providerName: "Memory")

    /// Short badge text for the reply bubble.
    public var badge: String {
        switch origin {
        case .onDevice: "On device"
        case .cloud: "Cloud · \(providerName)"
        case .memory: "From memory"
        }
    }

    /// VoiceOver text: states plainly whether the reply left the phone.
    public var accessibilityLabel: String {
        switch origin {
        case .onDevice: "Answered on this device. Nothing was sent."
        case .cloud: "Answered in the cloud by \(providerName)."
        case .memory: "Answered from your saved notes on this device. Nothing was sent."
        }
    }
}
