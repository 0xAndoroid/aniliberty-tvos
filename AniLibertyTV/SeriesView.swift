//
//  SeriesView.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import SwiftUI

struct SeriesView: View {
    @Environment(AppModel.self) private var app

    @State private var series: Series
    @State private var isLoaded = false
    @State private var timeCodes: [String: TimeCodeData] = [:]
    @State private var activeEpisode: PlaylistItem?
    @State private var isFavorite: Bool?
    @State private var playing: PlaylistItem?
    @State private var loadError: String?
    @State private var favoriteError: String?
    @State private var isDescriptionShown = false

    @FocusState private var isPlayFocused: Bool

    init(series: Series) {
        _series = State(initialValue: series)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 50) {
                header
                episodes
            }
        }
        .scrollClipDisabled()
        .toolbar(.hidden, for: .tabBar)
        .task(id: app.user?.id) {
            await load()
        }
        .fullScreenCover(isPresented: isPlaying) {
            Task { await loadProgress() }
        } content: {
            if let playing {
                PlayerView(series: series, episode: playing, userID: app.user?.id, service: app.player)
                    .ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $isDescriptionShown) {
            VStack(alignment: .leading, spacing: 30) {
                Text(series.name?.main ?? "")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(description)
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: 1400)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas)
        }
        .alert(L10n.Alert.Title.error, isPresented: isFavoriteErrorShown) {
            Button(L10n.Buttons.ok) {}
        } message: {
            Text(favoriteError ?? "")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 60) {
            PosterImage(url: series.poster)
                .frame(width: 400)
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(series.name?.main ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.text)
                    if let english = series.name?.english, !english.isEmpty {
                        Text(english)
                            .font(.headline)
                            .foregroundStyle(Theme.muted)
                    }
                }
                Text(facts.joined(separator: " · "))
                    .foregroundStyle(Theme.muted)
                if !series.notification.isEmpty {
                    Text(series.notification)
                        .foregroundStyle(Theme.brand)
                }
                Button {
                    isDescriptionShown = true
                } label: {
                    Text(description)
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 10)
                HStack(spacing: 30) {
                    if let activeEpisode {
                        Button {
                            playing = activeEpisode
                        } label: {
                            Label(playTitle(for: activeEpisode), systemImage: "play.fill")
                        }
                        .focused($isPlayFocused)
                        .onAppear {
                            isPlayFocused = true
                        }
                    }
                    if let isFavorite {
                        Button {
                            Task { await setFavorite(!isFavorite) }
                        } label: {
                            Label(L10n.Common.Collections.favorites, systemImage: isFavorite ? "star.fill" : "star")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var episodes: some View {
        if let loadError {
            LoadFailure(message: loadError) {
                Task { await load() }
            }
        } else if !isLoaded {
            // Focusable, like the text below: a page with nothing to focus cannot be left, Menu would quit the
            // app. A title opened from the continue row has no description to focus until it has loaded.
            ProgressView()
                .frame(maxWidth: .infinity)
                .focusable()
        } else if series.playlist.isEmpty {
            Text(series.isBlocked ? L10n.Common.contentBlocked : L10n.Stub.noEpisodes)
                .foregroundStyle(Theme.muted)
                .focusable()
        } else {
            SectionTitle(L10n.Screen.Series.episodes)
            LazyVStack(spacing: 16) {
                ForEach(series.playlist, id: \.id) { episode in
                    Button {
                        playing = episode
                    } label: {
                        EpisodeRow(episode: episode, timeCode: timeCodes[episode.id])
                    }
                }
            }
        }
    }

    private var isPlaying: Binding<Bool> {
        Binding {
            playing != nil
        } set: { shown in
            if !shown {
                playing = nil
            }
        }
    }

    private var isFavoriteErrorShown: Binding<Bool> {
        Binding {
            favoriteError != nil
        } set: { shown in
            if !shown {
                favoriteError = nil
            }
        }
    }

    private var description: String {
        series.desc?.string ?? ""
    }

    private var facts: [String] {
        var facts = [
            series.year.map(String.init),
            series.type?.description,
            series.season?.description,
            series.ageRating?.label
        ].compactMap { $0 }
        facts += series.genres.map(\.name)
        return facts
    }

    private func playTitle(for episode: PlaylistItem) -> String {
        let started = episode.id != series.playlist.first?.id || (timeCodes[episode.id]?.time ?? 0) > 0
        let action = started ? L10n.Buttons.continue : L10n.Buttons.watch
        return [action, episode.episode].compactMap { $0 }.joined(separator: " · ")
    }

    private func load() async {
        loadError = nil
        do {
            if let userID = app.user?.id {
                // As on iOS, the positions saved from other devices arrive before the episodes are shown.
                _ = try? await app.player.syncTimeCodes(userID: userID).firstValue()
            }
            series = try await app.main.series(with: series.id).firstValue()
            await loadProgress()
            isLoaded = true
            if app.user == nil {
                isFavorite = nil
            } else {
                isFavorite = try? await app.favorites.getFavoriteState(for: series.id).firstValue()
            }
        } catch {
            if !(error is CancellationError) {
                loadError = error.message
            }
        }
    }

    private func loadProgress() async {
        let playlist = series.playlist
        if let saved = try? await app.player.getTimeCodes(userID: app.user?.id, episodeIDs: playlist.map(\.id)).firstValue() {
            timeCodes = saved
        }
        var index = app.player.getActiveEpisodeID(for: series).flatMap { id in
            playlist.firstIndex { $0.id == id }
        } ?? 0
        while index < playlist.count - 1, timeCodes[playlist[index].id]?.isWatched == true {
            index += 1
        }
        activeEpisode = playlist[safe: index]
    }

    private func setFavorite(_ add: Bool) async {
        do {
            try await app.favorites.favorite(add: add, series: series).firstValue()
            isFavorite = add
        } catch {
            favoriteError = error.message
        }
    }
}

private struct EpisodeRow: View {
    private static let time = FormatterFactory.time.create()

    let episode: PlaylistItem
    let timeCode: TimeCodeData?

    var body: some View {
        HStack(spacing: 30) {
            if let number = episode.episode {
                Text(number)
            }
            if let title = episode.title {
                Text(title)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if timeCode?.isWatched == true {
                Label(L10n.Common.Collections.watched, systemImage: "checkmark")
                    .foregroundStyle(.secondary)
            } else if let position = timeCode?.time, position > 0 {
                Text("\(Self.time.string(from: position) ?? "") / \(Self.time.string(from: episode.duration) ?? "")")
                    .foregroundStyle(Theme.brand)
            } else {
                Text(Self.time.string(from: episode.duration) ?? "")
                    .foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
    }
}
