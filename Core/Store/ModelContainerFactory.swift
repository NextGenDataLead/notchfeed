import Foundation
import SwiftData

public enum ModelContainerFactory {
    public static let schema = Schema([Feed.self, Item.self])

    /// The on-disk store in `~/Library/Application Support/NotchFeed/`.
    public static func makePersistent() throws -> ModelContainer {
        let directory = URL.applicationSupportDirectory.appending(path: "NotchFeed", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(schema: schema, url: directory.appending(path: "NotchFeed.store"))
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// A private in-memory store; each call gets its own, so tests stay isolated.
    public static func makeInMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(UUID().uuidString, schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
