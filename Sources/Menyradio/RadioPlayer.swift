import AVFoundation
import Observation

@MainActor @Observable final class RadioPlayer {
    enum State: String { case stopped = "Stoppad", connecting = "Ansluter…", playing = "Spelar", paused = "Pausad", failed = "Kunde inte spela kanalen. Välj den för att försöka igen." }
    private(set) var state: State = .stopped
    private(set) var channel: Channel?
    private(set) var metadata: String?
    private(set) var metadataIsSong = false
    private(set) var volume: Float
    private(set) var isMuted: Bool
    private let defaults: UserDefaults
    private let player = AVPlayer()
    var routingPlayer: AVPlayer { player }
    private let api: SverigesRadioAPI
    private let nowPlaying = NowPlayingService()
    private var monitor: Task<Void, Never>?
    private var metadataTask: Task<Void, Never>?
    private var metadataExpiryTask: Task<Void, Never>?
    private var metadataCache = RadioMetadataCache()
    private var wantsPlayback = false

    init(api: SverigesRadioAPI = .init(), defaults: UserDefaults = .standard) {
        self.api = api
        self.defaults = defaults
        let savedVolume = defaults.object(forKey: "playbackVolume") as? NSNumber
        volume = min(1, max(0, savedVolume?.floatValue ?? 1))
        isMuted = defaults.bool(forKey: "playbackMuted")
        player.volume = volume
        player.isMuted = isMuted
        player.automaticallyWaitsToMinimizeStalling = true
        // Follow system output initially; AVKit can select an app-specific route.
        player.audioOutputDeviceUniqueID = nil
        nowPlaying.configure(play: { [weak self] in self?.resume() }, pause: { [weak self] in self?.pause() }, stop: { [weak self] in self?.stop() }, toggle: { [weak self] in
            guard let self else { return }; self.wantsPlayback ? self.pause() : self.resume()
        })
    }

    func setVolume(_ value: Float) {
        guard value.isFinite else { return }
        volume = min(1, max(0, value))
        player.volume = volume
        defaults.set(volume, forKey: "playbackVolume")
        // Moving the slider deliberately restores sound.
        if volume > 0 { setMuted(false) }
    }

    func setMuted(_ muted: Bool) {
        isMuted = muted
        player.isMuted = muted
        defaults.set(muted, forKey: "playbackMuted")
    }

    func select(_ channel: Channel) {
        stop()
        guard let url = channel.streamURL else { setState(.failed); return }
        self.channel = channel
        wantsPlayback = true
        setState(.connecting)
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
        startMonitor(url: url)
        startMetadataUpdates(channelID: channel.id)
    }

    private func startMonitor(url: URL) {
        monitor?.cancel()
        monitor = Task { [weak self] in
            var waitingSince = Date()
            var recovery = PlaybackRecovery()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard !Task.isCancelled, let self, self.wantsPlayback else { return }
                let now = Date()
                if self.player.timeControlStatus == .playing {
                    recovery.playing(at: now)
                    waitingSince = now
                    self.setState(.playing)
                } else {
                    recovery.interrupted()
                    self.setState(.connecting)
                    let failed = self.player.currentItem?.status == .failed
                    if failed || now.timeIntervalSince(waitingSince) > 20 {
                        guard let delay = recovery.nextDelay() else {
                            self.wantsPlayback = false
                            self.player.pause()
                            self.metadataTask?.cancel()
                            self.metadataTask = nil
                            self.setState(.failed)
                            return
                        }
                        do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                        guard !Task.isCancelled, self.wantsPlayback else { return }
                        self.player.replaceCurrentItem(with: AVPlayerItem(url: url))
                        self.player.play()
                        waitingSince = Date()
                    }
                }
            }
        }
    }

    private func startMetadataUpdates(channelID: Int) {
        metadataTask?.cancel()
        metadataTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.wantsPlayback else { return }
                async let programme = try? self.api.programme(channelID)
                async let song = try? self.api.song(channelID)
                let (episode, track) = await (programme, song)
                guard !Task.isCancelled, self.wantsPlayback, self.channel?.id == channelID else { return }
                self.metadataCache.update(programme: episode, song: track)
                self.refreshMetadataPresentation()
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
            }
        }
    }

    private func refreshMetadataPresentation() {
        metadataExpiryTask?.cancel()
        metadataExpiryTask = nil
        let now = Date()
        let display = metadataCache.display(at: now)
        if metadata != display?.text || metadataIsSong != (display?.isSong ?? false) {
            metadata = display?.text
            metadataIsSong = display?.isSong ?? false
            publish()
        }
        // Expire cached information on time even while paused or the API is offline.
        if let boundary = metadataCache.nextBoundary(after: now) {
            metadataExpiryTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(max(0, boundary.timeIntervalSinceNow))) } catch { return }
                guard !Task.isCancelled else { return }
                self?.refreshMetadataPresentation()
            }
        }
    }

    func pause() {
        guard channel != nil, wantsPlayback else { return }
        wantsPlayback = false
        monitor?.cancel(); monitor = nil
        metadataTask?.cancel(); metadataTask = nil
        player.pause()
        setState(.paused)
    }

    func resume() {
        guard let channel, !wantsPlayback, let url = channel.streamURL else { return }
        wantsPlayback = true
        refreshMetadataPresentation()
        setState(.connecting)
        // Resume at the live edge rather than replaying a paused radio buffer.
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        player.play()
        startMonitor(url: url)
        startMetadataUpdates(channelID: channel.id)
    }

    func stop() {
        monitor?.cancel(); monitor = nil
        metadataTask?.cancel(); metadataTask = nil
        metadataExpiryTask?.cancel(); metadataExpiryTask = nil
        metadataCache = RadioMetadataCache()
        wantsPlayback = false
        player.pause(); player.replaceCurrentItem(with: nil)
        channel = nil; metadata = nil; metadataIsSong = false
        state = .stopped
        publish()
    }

    private func setState(_ newState: State) {
        guard state != newState else { return }
        state = newState
        publish()
    }

    private func publish() {
        nowPlaying.update(channel: channel?.name, detail: metadata, playing: state == .playing, paused: state == .paused)
    }
}
