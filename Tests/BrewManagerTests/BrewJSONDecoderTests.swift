#if canImport(XCTest)
import XCTest
@testable import BrewManager

final class BrewJSONDecoderTests: XCTestCase {
    func testDecodeOutdatedPackages() throws {
        let fixture = """
        {
          "formulae": [
            {
              "name": "node",
              "installed_versions": ["22.17.0"],
              "current_version": "22.18.0",
              "pinned": false
            }
          ],
          "casks": [
            {
              "name": "iina",
              "installed_versions": ["1.4.0"],
              "current_version": "1.4.1"
            }
          ]
        }
        """

        let decoded = try BrewJSONDecoder.decodeOutdated(from: Data(fixture.utf8))

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded.first(where: { $0.name == "node" })?.installedVersion, "22.17.0")
        XCTAssertEqual(decoded.first(where: { $0.name == "node" })?.latestVersion, "22.18.0")
        XCTAssertEqual(decoded.first(where: { $0.name == "iina" })?.type, .cask)
    }

    func testDecodeFormulaPackageInfo() throws {
        let fixture = """
        {
          "formulae": [
            {
              "name": "node",
              "desc": "JavaScript runtime",
              "homepage": "https://nodejs.org/",
              "tap": "homebrew/core",
              "pinned": true,
              "dependencies": ["icu4c", "libuv"],
              "versions": { "stable": "22.18.0" },
              "installed": [{ "version": "22.17.0" }]
            }
          ],
          "casks": []
        }
        """

        let package = try BrewJSONDecoder.decodePackageInfo(
            from: Data(fixture.utf8),
            fallbackName: "node"
        )

        XCTAssertEqual(package.name, "node")
        XCTAssertEqual(package.type, .formula)
        XCTAssertEqual(package.currentVersion, "22.17.0")
        XCTAssertEqual(package.latestVersion, "22.18.0")
        XCTAssertEqual(package.packageDescription, "JavaScript runtime")
        XCTAssertEqual(package.tap, "homebrew/core")
        XCTAssertEqual(package.dependencies, ["icu4c", "libuv"])
    }

    func testDecodeServices() throws {
        let fixture = """
        [
          {
            "name": "redis",
            "status": "started",
            "user": "uma",
            "plist": "/Users/uma/Library/LaunchAgents/homebrew.mxcl.redis.plist",
            "exit_code": 0
          }
        ]
        """

        let services = try BrewJSONDecoder.decodeServices(from: Data(fixture.utf8))

        XCTAssertEqual(services.count, 1)
        XCTAssertEqual(services[0].name, "redis")
        XCTAssertEqual(services[0].status, .running)
        XCTAssertEqual(services[0].launchesAtLogin, true)
    }
}
#endif
