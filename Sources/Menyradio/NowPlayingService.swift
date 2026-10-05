import MediaPlayer

@MainActor final class NowPlayingService {
    private var targets: [(MPRemoteCommand, Any)] = []
    func configure(play: @escaping @MainActor () -> Void, pause: @escaping @MainActor () -> Void, stop: @escaping @MainActor () -> Void, toggle: @escaping @MainActor () -> Void) {
        let center = MPRemoteCommandCenter.shared()
        for (command, action) in [(center.playCommand, play), (center.pauseCommand, pause), (center.stopCommand, stop), (center.togglePlayPauseCommand, toggle)] {
            let target = command.addTarget { _ in
                Task { @MainActor in action() }
                return .success
            }
            targets.append((command, target))
        }
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackPositionCommand.isEnabled = false
    }
    func update(channel: String?, detail: String?, playing: Bool, paused: Bool) {
        let center = MPNowPlayingInfoCenter.default()
        guard let channel else { center.nowPlayingInfo = nil; center.playbackState = .stopped; return }
        center.nowPlayingInfo = [MPMediaItemPropertyTitle: detail ?? channel, MPMediaItemPropertyArtist: channel,
                                MPNowPlayingInfoPropertyIsLiveStream: true, MPNowPlayingInfoPropertyPlaybackRate: playing ? 1.0 : 0.0]
        center.playbackState = playing ? .playing : (paused ? .paused : .stopped)
    }
}
