import Foundation
import Observation

@MainActor @Observable final class RadioLibrary {
    private(set) var channels: [Channel] = []
    var error: String?
    private(set) var loading = false
    var favouriteIDs: [Int] { didSet { UserDefaults.standard.set(favouriteIDs, forKey: "favourites") } }
    let api: SverigesRadioAPI
    private let cacheURL: URL
    private struct Cache: Codable { let date: Date; let channels: [Channel] }
    private var cacheDate: Date?
    private var programmes: [Int: Episode] = [:]
    private var programmeFetchDates: [Int: Date] = [:]
    private var fetchingProgrammes = false

    func programmeTitle(for id: Int, at date: Date = Date()) -> String? {
        guard let episode = programmes[id],
              let start = srDate(episode.starttimeutc), let end = srDate(episode.endtimeutc),
              start <= date, date < end,
              let title = episode.title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }
        return title
    }

    func refreshProgrammes() async {
        guard !fetchingProgrammes else { return }
        let ids = favourites.map(\.id).filter {
            Date().timeIntervalSince(programmeFetchDates[$0] ?? .distantPast) >= 60
        }
        guard !ids.isEmpty else { return }
        fetchingProgrammes = true
        defer { fetchingProgrammes = false }
        let api = api
        await withTaskGroup(of: (Int, Episode?).self) { group in
            for id in ids {
                group.addTask { (id, try? await api.programme(id)) }
            }
            for await (id, episode) in group {
                guard !Task.isCancelled else { continue }
                programmeFetchDates[id] = Date()
                // A metadata outage must not affect playback or erase a still-current title.
                if let episode { programmes[id] = episode }
            }
        }
    }
    init(api: SverigesRadioAPI = .init()) {
        self.api = api
        favouriteIDs = loadFavouriteIDs()
        cacheURL = URL.applicationSupportDirectory.appending(path: "Menyradio/channels.json")
        let legacyCache = URL.applicationSupportDirectory.appending(path: "SRMenu/channels.json")
        for candidate in [cacheURL, legacyCache] {
            guard let data = try? Data(contentsOf: candidate),
                  let cache = try? JSONDecoder().decode(Cache.self, from: data) else { continue }
            channels = cache.channels.filter { $0.supported && $0.streamURL != nil }
            cacheDate = cache.date
            if candidate != cacheURL {
                try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? data.write(to: cacheURL, options: .atomic)
            }
            break
        }
        Task { await refresh() }
    }
    var favourites: [Channel] { favouriteIDs.compactMap { id in channels.first { $0.id == id } } }
    func refresh(force: Bool = false) async {
        guard !loading else { return }
        guard force || cacheDate == nil || Date().timeIntervalSince(cacheDate!) > 86400 else { return }
        loading = true
        defer { loading = false }
        do {
            channels = try await api.channels()
            cacheDate = Date(); error = nil
            try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(Cache(date: Date(), channels: channels)) { try? data.write(to: cacheURL, options: .atomic) }
        } catch { self.error = "Kunde inte hämta kanaler. Försök igen." }
    }
    func setFavourite(_ channel: Channel, selected: Bool) {
        if selected && !favouriteIDs.contains(channel.id) { favouriteIDs.append(channel.id) }
        if !selected { favouriteIDs.removeAll { $0 == channel.id } }
    }
    func move(_ id: Int, by offset: Int) {
        guard let index = favouriteIDs.firstIndex(of: id), favouriteIDs.indices.contains(index + offset) else { return }
        favouriteIDs.swapAt(index, index + offset)
    }
}

/// Copy existing favourites once when upgrading from the original bundle ID.
func loadFavouriteIDs(defaults: UserDefaults = .standard,
                      legacyDomain: String = "se.publicradio.SRMenu") -> [Int] {
    if let current = defaults.array(forKey: "favourites") as? [Int] { return current }
    if let previous = defaults.persistentDomain(forName: legacyDomain)?["favourites"] as? [Int] {
        defaults.set(previous, forKey: "favourites")
        return previous
    }
    return [132, 163, 164]
}
