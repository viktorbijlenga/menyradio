import XCTest
@testable import Menyradio

final class PlaybackSupportTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)

    func testStablePlaybackRestoresRetryBudget() {
        var recovery = PlaybackRecovery()
        XCTAssertEqual(recovery.nextDelay(), 2)
        XCTAssertEqual(recovery.nextDelay(), 4)
        XCTAssertEqual(recovery.nextDelay(), 6)
        XCTAssertNil(recovery.nextDelay())
        recovery.playing(at: start)
        recovery.playing(at: start.addingTimeInterval(30))
        recovery.interrupted()
        XCTAssertEqual(recovery.nextDelay(), 2)
    }

    func testBriefRecoveriesDoNotAllowEndlessRetries() {
        var recovery = PlaybackRecovery()
        for attempt in 1...3 {
            XCTAssertEqual(recovery.nextDelay(), attempt * 2)
            recovery.playing(at: start)
            recovery.playing(at: start.addingTimeInterval(29))
            recovery.interrupted()
        }
        XCTAssertNil(recovery.nextDelay())
    }

    func testMetadataSurvivesFailedFetchUntilItsExpiry() {
        var cache = RadioMetadataCache()
        cache.update(programme: Episode(title: "Programmet", starttimeutc: "/Date(1000000)/", endtimeutc: "/Date(1120000)/"),
                     song: Song(title: "Låten", artist: "Artisten", starttimeutc: "/Date(1000000)/", stoptimeutc: "/Date(1030000)/"))
        cache.update(programme: nil, song: nil)
        XCTAssertEqual(cache.display(at: start), .init(text: "Artisten – Låten", isSong: true))
        XCTAssertEqual(cache.nextBoundary(after: start), start.addingTimeInterval(30))
        XCTAssertEqual(cache.display(at: start.addingTimeInterval(30)), .init(text: "Programmet", isSong: false))
        XCTAssertEqual(cache.nextBoundary(after: start.addingTimeInterval(30)), start.addingTimeInterval(120))
        XCTAssertNil(cache.display(at: start.addingTimeInterval(120)))
        XCTAssertNil(cache.nextBoundary(after: start.addingTimeInterval(120)))
    }

    func testMetadataRejectsFutureMalformedAndEmptyValues() {
        var cache = RadioMetadataCache()
        cache.update(programme: Episode(title: "Senare", starttimeutc: "/Date(1030000)/", endtimeutc: "/Date(1120000)/"),
                     song: Song(title: "Fel", artist: nil, starttimeutc: "bad", stoptimeutc: "bad"))
        XCTAssertNil(cache.display(at: start))
        XCTAssertEqual(cache.display(at: start.addingTimeInterval(30))?.text, "Senare")
        cache.update(programme: Episode(title: "  ", starttimeutc: "/Date(1000000)/", endtimeutc: "/Date(1120000)/"), song: nil)
        XCTAssertNil(cache.display(at: start))
    }
}
