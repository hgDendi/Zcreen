import XCTest
@testable import Zcreen

final class ConfigManagerTests: XCTestCase {

    func testConfigIssueIncludesFieldPathForMissingVersion() throws {
        let configDirectory = tempDirectory()
        try writeConfig(
            """
            {
                "screens": [{"alias": "main", "nameContains": "Built-in"}]
            }
            """,
            to: configDirectory
        )

        let manager = ConfigManager(loadFromDisk: true, configDirectory: configDirectory)

        XCTAssertEqual(manager.configIssue?.summary, "Missing required field")
        XCTAssertEqual(manager.configIssue?.fieldPath, "version")
        XCTAssertEqual(manager.configIssue?.suggestion, "Add the missing field to config.json.")
    }

    func testConfigIssueIncludesSuggestionForUnknownTargetScreen() throws {
        let configDirectory = tempDirectory()
        try writeConfig(
            """
            {
                "version": 1,
                "screens": [{"alias": "main", "nameContains": "Built-in"}],
                "rules": [{
                    "app": {"bundleId": "com.apple.Safari"},
                    "targetScreen": "external"
                }]
            }
            """,
            to: configDirectory
        )

        let manager = ConfigManager(loadFromDisk: true, configDirectory: configDirectory)

        XCTAssertEqual(manager.configIssue?.summary, "Unknown target screen alias 'external'")
        XCTAssertEqual(manager.configIssue?.fieldPath, "rules[0].targetScreen")
        XCTAssertEqual(manager.configIssue?.suggestion, "Add the alias to screens or change targetScreen to an existing alias.")
    }

    private func writeConfig(_ json: String, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try XCTUnwrap(json.data(using: .utf8))
        try data.write(to: directory.appendingPathComponent("config.json"))
    }

    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
}
