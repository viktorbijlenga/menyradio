import XCTest
@testable import Menyradio

final class ChannelOrderTests: XCTestCase {
    func testMovesVisibleNeighboursPastUnavailableStations() {
        XCTAssertEqual(movingFavourite(164, by: -1, in: [132, 999, 164, 163], visibleIDs: [132, 164, 163]), [164, 999, 132, 163])
        XCTAssertEqual(movingFavourite(132, by: 1, in: [132, 999, 164, 163], visibleIDs: [132, 164, 163]), [164, 999, 132, 163])
    }

    func testBoundaryAndMissingMovesLeaveOrderIntact() {
        let ids = [132, 163, 164]
        XCTAssertEqual(movingFavourite(132, by: -1, in: ids, visibleIDs: ids), ids)
        XCTAssertEqual(movingFavourite(164, by: 1, in: ids, visibleIDs: ids), ids)
        XCTAssertEqual(movingFavourite(999, by: 1, in: ids, visibleIDs: ids), ids)
    }
}
