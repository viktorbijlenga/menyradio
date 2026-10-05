import XCTest
@testable import Menyradio

final class APITests: XCTestCase {
    func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")))
    }
    func testLiveChannelResponseIncludesNationalAndRegionalStreams() throws {
        let response = try JSONDecoder().decode(ChannelResponse.self, from: fixture("channels"))
        let channels = response.channels.filter { $0.supported && $0.streamURL != nil }
        for name in ["P1", "P2", "P3", "P4 Värmland"] {
            XCTAssertNotNil(channels.first { $0.name == name })
        }
        XCTAssertGreaterThan(channels.filter { $0.name.hasPrefix("P4 ") }.count, 20)
        XCTAssertTrue(channels.allSatisfy { $0.streamURL?.scheme == "https" })
    }
    func testProgrammeAndSongResponseShapesAndStaleSongRejection() throws {
        let schedule = try JSONDecoder().decode(ScheduleResponse.self, from: fixture("schedule"))
        XCTAssertNotNil(schedule.channel.currentscheduledepisode?.title)
        let song = try XCTUnwrap(JSONDecoder().decode(PlaylistResponse.self, from: fixture("songs")).playlist.song)
        let start = try XCTUnwrap(srDate(song.starttimeutc))
        let stop = try XCTUnwrap(srDate(song.stoptimeutc))
        XCTAssertTrue(song.current(at: start))
        XCTAssertFalse(song.current(at: stop))
        XCTAssertFalse(song.current(at: start.addingTimeInterval(-1)))
    }
    func testMalformedAndMissingMetadata() throws {
        XCTAssertNil(srDate("invalid"))
        let response = try JSONDecoder().decode(PlaylistResponse.self, from: Data(#"{"playlist":{}}"#.utf8))
        XCTAssertNil(response.playlist.song)
        XCTAssertThrowsError(try JSONDecoder().decode(ChannelResponse.self, from: Data(#"{"channels":"bad"}"#.utf8)))
        let channel = Channel(id: 1, name: "P1", liveaudio: .init(url: "http://example.com/radio"))
        XCTAssertNil(channel.streamURL)
    }
}
