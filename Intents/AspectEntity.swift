import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public struct AspectEntity: AppEntity {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Aspect")
    public static let defaultQuery = AspectEntityQuery()

    public var id: String
    public var displayName: String

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct AspectEntityQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [AspectEntity] {
        identifiers.compactMap { id in
            switch id.lowercased() {
            case "forge": return AspectEntity(id: "forge", displayName: "Forge")
            case "quicksilver": return AspectEntity(id: "quicksilver", displayName: "Quicksilver")
            case "eternal": return AspectEntity(id: "eternal", displayName: "Eternal")
            default: return nil
            }
        }
    }

    public func suggestedEntities() async throws -> [AspectEntity] {
        [
            AspectEntity(id: "quicksilver", displayName: "Quicksilver"),
            AspectEntity(id: "forge", displayName: "Forge"),
            AspectEntity(id: "eternal", displayName: "Eternal")
        ]
    }
}
