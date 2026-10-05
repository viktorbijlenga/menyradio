import Foundation

/// Give separate interruptions a fresh retry budget after 30 seconds of stable audio.
struct PlaybackRecovery {
    private(set) var attempts = 0
    private var stableSince: Date?

    mutating func playing(at date: Date) {
        if stableSince == nil { stableSince = date }
        if let stableSince, date.timeIntervalSince(stableSince) >= 30 { attempts = 0 }
    }

    mutating func interrupted() { stableSince = nil }

    mutating func nextDelay() -> Int? {
        guard attempts < 3 else { return nil }
        attempts += 1
        return attempts * 2
    }
}

struct RadioMetadataCache {
    struct Display: Equatable {
        let text: String
        let isSong: Bool
    }

    private var programme: Episode?
    private var song: Song?

    mutating func update(programme: Episode?, song: Song?) {
        // Keep the last known values through transient API errors. Their timestamps
        // determine whether they can still be shown, independently of requests.
        if let programme { self.programme = programme }
        if let song { self.song = song }
    }

    func display(at date: Date) -> Display? {
        if let song, song.current(at: date), let title = nonempty(song.title) {
            let text = [nonempty(song.artist), title].compactMap { $0 }.joined(separator: " – ")
            return Display(text: text, isSong: true)
        }
        if let programme, let start = srDate(programme.starttimeutc),
           let end = srDate(programme.endtimeutc), start <= date, date < end,
           let title = nonempty(programme.title) {
            return Display(text: title, isSong: false)
        }
        return nil
    }

    func nextBoundary(after date: Date) -> Date? {
        [srDate(programme?.starttimeutc), srDate(programme?.endtimeutc),
         srDate(song?.starttimeutc), srDate(song?.stoptimeutc)]
            .compactMap { $0 }.filter { $0 > date }.min()
    }

    private func nonempty(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
