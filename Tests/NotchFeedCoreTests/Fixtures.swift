import Foundation

/// Loads files from `Tests/Fixtures`, which is copied into the test bundle as a folder.
enum Fixtures {
    private final class BundleToken {}

    static func data(_ name: String) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "Fixtures/\(name)"])
        }
        return try Data(contentsOf: url)
    }
}
