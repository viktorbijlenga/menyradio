import Foundation

struct Channel: Codable, Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let liveaudio: LiveAudio?
    struct LiveAudio: Codable, Equatable, Sendable { let url: String }
    var streamURL: URL? {
        guard let raw = liveaudio?.url, let url = URL(string: raw), url.scheme == "https" else { return nil }
        return url
    }
    var supported: Bool { ["P1", "P2", "P3"].contains(name) || name.hasPrefix("P4 ") }
}
struct ChannelResponse: Decodable { let channels: [Channel] }
struct Episode: Decodable, Sendable {
    let title: String?
    let starttimeutc: String?
    let endtimeutc: String?
}
struct ScheduleResponse: Decodable {
    let channel: ScheduleChannel
    struct ScheduleChannel: Decodable { let currentscheduledepisode: Episode? }
}
struct Song: Decodable, Sendable {
    let title: String?
    let artist: String?
    let starttimeutc: String?
    let stoptimeutc: String?
    func current(at date: Date) -> Bool {
        guard let start = srDate(starttimeutc), let end = srDate(stoptimeutc) else { return false }
        return start <= date && date < end
    }
}
struct PlaylistResponse: Decodable {
    let playlist: Playlist
    struct Playlist: Decodable { let song: Song? }
}
func srDate(_ raw: String?) -> Date? {
    guard let raw, raw.hasPrefix("/Date("), let end = raw.firstIndex(of: ")"), let value = Double(raw[raw.index(raw.startIndex, offsetBy: 6)..<end]) else { return nil }
    return Date(timeIntervalSince1970: value / 1000)
}
struct SverigesRadioAPI: Sendable {
    let session: URLSession
    init(session: URLSession = .shared) { self.session = session }
    func request<T: Decodable & Sendable>(_ path: String, channelID: Int? = nil) async throws -> T {
        var components = URLComponents(string: "https://api.sr.se/api/v2/\(path)")!
        components.queryItems = [URLQueryItem(name: "format", value: "json"), URLQueryItem(name: "pagination", value: "false")]
        if let channelID { components.queryItems?.append(URLQueryItem(name: "channelid", value: String(channelID))) }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func channels() async throws -> [Channel] {
        let response: ChannelResponse = try await request("channels")
        let channels = response.channels.filter { $0.supported && $0.streamURL != nil }
        guard !channels.isEmpty else { throw URLError(.cannotParseResponse) }
        return channels
    }
    func programme(_ id: Int) async throws -> Episode? {
        let response: ScheduleResponse = try await request("scheduledepisodes/rightnow", channelID: id)
        return response.channel.currentscheduledepisode
    }
    func song(_ id: Int) async throws -> Song? {
        let response: PlaylistResponse = try await request("playlists/rightnow", channelID: id)
        return response.playlist.song
    }
}
extension ChannelResponse: Sendable {}
extension ScheduleResponse: Sendable {}
extension ScheduleResponse.ScheduleChannel: Sendable {}
extension PlaylistResponse: Sendable {}
extension PlaylistResponse.Playlist: Sendable {}
