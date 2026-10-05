import XCTest
@testable import Menyradio

final class PreferenceMigrationTests: XCTestCase {
    func testRenameCopiesOrderedFavouritesWithoutOverwritingNewSelection() throws {
        let suite = "MenyradioTests.\(UUID().uuidString)"
        let legacy = "MenyradioLegacyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            defaults.removePersistentDomain(forName: legacy)
        }
        defaults.setPersistentDomain(["favourites": [164, 203, 132]], forName: legacy)
        XCTAssertEqual(loadFavouriteIDs(defaults: defaults, legacyDomain: legacy), [164, 203, 132])
        XCTAssertEqual(defaults.array(forKey: "favourites") as? [Int], [164, 203, 132])
        defaults.set([], forKey: "favourites")
        XCTAssertEqual(loadFavouriteIDs(defaults: defaults, legacyDomain: legacy), [])
    }
}
