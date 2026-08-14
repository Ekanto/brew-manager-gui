#if canImport(XCTest)
import Foundation
import XCTest
@testable import BrewManager

final class BrewLocatorTests: XCTestCase {
    func testLocateFindsExecutableInPreferredPath() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let brewURL = temporaryDirectory.appendingPathComponent("brew")
        FileManager.default.createFile(
            atPath: brewURL.path,
            contents: Data("#!/bin/sh\necho brew\n".utf8)
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: brewURL.path
        )

        let locator = BrewLocator(
            preferredPaths: [brewURL.path],
            controlledPathDirectories: [],
            environmentPath: nil
        )

        let resolved = try locator.locate()
        XCTAssertEqual(resolved.path, brewURL.path)
    }

    func testLocateThrowsWhenNoExecutableExists() {
        let locator = BrewLocator(
            preferredPaths: ["/tmp/does-not-exist/brew"],
            controlledPathDirectories: [],
            environmentPath: nil
        )

        XCTAssertThrowsError(try locator.locate()) { error in
            XCTAssertEqual(error as? BrewError, .homebrewNotFound)
        }
    }
}
#endif
