//
//  DefaultsRepositories.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 15.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import Combine
import Foundation

// tvOS may delete everything an app stores on the device except its UserDefaults, and it terminates an app
// whose UserDefaults reach 1 MB (it warns at 512 kB). The watch positions and the continue row therefore live
// in UserDefaults on tvOS, each with a limit on the number of records.

/// The watch positions of the 2,000 episodes written last, at most about 125 bytes each.
final class EpisodesDefaultsRepository: EpisodesRepository {
    private struct Position: Codable {
        let time: TimeInterval
        let isWatched: Bool
        /// When the position was written here. The player passes a position on with the date of its first
        /// save, so that date cannot tell which positions are the newest.
        let updatedAt: Date
    }

    private static let key = "TV_POSITIONS_KEY"
    private static let limit = 2000

    /// A sync with the account writes from a background queue while the player writes on the main one.
    private let lock = NSLock()

    func set(timeCodeData: [TimeCodeData], for userID: Int?) {
        let now = Date()
        lock.withLock {
            var positions = positions
            for data in timeCodeData {
                positions[Self.key(userID, data.episodeID)] = Position(
                    time: data.time,
                    isWatched: data.isWatched,
                    updatedAt: now
                )
            }
            if positions.count > Self.limit {
                let newest = positions.sorted { $0.value.updatedAt > $1.value.updatedAt }.prefix(Self.limit)
                positions = Dictionary(uniqueKeysWithValues: newest.map { ($0.key, $0.value) })
            }
            UserDefaults.standard[Self.key] = positions
        }
    }

    func getTimeCode(for userID: Int?, episodeID: String) -> TimeCodeData? {
        positions[Self.key(userID, episodeID)].map { Self.timeCode(episodeID, $0) }
    }

    func getTimeCodes(for userID: Int?, episodeIDs: [String]) -> AnyPublisher<[String: TimeCodeData], Never> {
        let positions = positions
        var timeCodes: [String: TimeCodeData] = [:]
        for episodeID in episodeIDs {
            timeCodes[episodeID] = positions[Self.key(userID, episodeID)].map { Self.timeCode(episodeID, $0) }
        }
        return .just(timeCodes)
    }

    private var positions: [String: Position] {
        UserDefaults.standard[Self.key] ?? [:]
    }

    private static func key(_ userID: Int?, _ episodeID: String) -> String {
        "\(userID ?? 0)/\(episodeID)"
    }

    private static func timeCode(_ episodeID: String, _ position: Position) -> TimeCodeData {
        TimeCodeData(
            episodeID: episodeID,
            time: position.time,
            isWatched: position.isWatched,
            updatedAt: position.updatedAt
        )
    }
}

/// The continue row: the newest 100 titles. An entry holds the part of a title's JSON that the row shows, so the
/// stored list also decodes as `[Series]`; the title page loads the rest from the service.
final class HistoryDefaultsRepository: HistoryRepository {
    private struct Entry: Codable {
        struct Name: Codable {
            let main: String
        }

        struct Poster: Codable {
            let src: String?
        }

        let id: Int
        let name: Name
        let poster: Poster
        let episodeID: String
    }

    private static let key = "TV_HISTORY_KEY"
    private static let limit = 100

    func getSeriesHistory() -> AnyPublisher<[Series], Never> {
        // Decoded off the main thread, as in the Core Data repository: decoding a title converts its description
        // from HTML, which takes about 2 ms a title even when the description is empty.
        Deferred { Just(UserDefaults.standard[Self.key] ?? [Series]()) }
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func getActiveEpisode(for seriesID: Int) -> ActiveEpisode? {
        entries.first { $0.id == seriesID }.map { .id($0.episodeID) }
    }

    func add(series: Series, episodeID: String) {
        let entry = Entry(
            id: series.id,
            name: Entry.Name(main: series.name?.main ?? ""),
            poster: Entry.Poster(src: series.poster?.absoluteString),
            episodeID: episodeID
        )
        UserDefaults.standard[Self.key] = Array(([entry] + entries.filter { $0.id != series.id }).prefix(Self.limit))
    }

    func remove(seriesID: Int) {
        UserDefaults.standard[Self.key] = entries.filter { $0.id != seriesID }
    }

    private var entries: [Entry] {
        UserDefaults.standard[Self.key] ?? []
    }
}
