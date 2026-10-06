import XCTest
@testable import Menyradio

final class VolumeTests: XCTestCase {
    @MainActor func testVolumeAndMutePersistWithoutChangingPlaybackState() {
        let name = "MenyradioVolumeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let player = RadioPlayer(defaults: defaults)
        XCTAssertEqual(player.volume, 1)
        XCTAssertFalse(player.isMuted)
        player.setVolume(0.35)
        player.setMuted(true)
        player.stop()
        let restored = RadioPlayer(defaults: defaults)
        XCTAssertEqual(restored.volume, 0.35, accuracy: 0.001)
        XCTAssertTrue(restored.isMuted)
        XCTAssertEqual(restored.state, .stopped)
        restored.setVolume(0.5)
        XCTAssertFalse(restored.isMuted)
        XCTAssertEqual(restored.routingPlayer.volume, 0.5)
        XCTAssertFalse(restored.routingPlayer.isMuted)
    }

    @MainActor func testVolumeClampsAndRejectsNonFiniteInput() {
        let name = "MenyradioVolumeTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let player = RadioPlayer(defaults: defaults)
        player.setVolume(-1)
        XCTAssertEqual(player.volume, 0)
        player.setVolume(2)
        XCTAssertEqual(player.volume, 1)
        player.setVolume(.nan)
        XCTAssertEqual(player.volume, 1)
    }
}
