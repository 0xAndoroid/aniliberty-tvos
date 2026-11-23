//
//  HomeView.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var app

    @State private var latest: [Series] = []
    @State private var history: [Series] = []
    @State private var error: String?

    var body: some View {
        SeriesStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    if !history.isEmpty {
                        SectionTitle("Продолжить просмотр")
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: SeriesGrid.spacing) {
                                ForEach(history, id: \.id) { series in
                                    PosterCard(series: series)
                                        .containerRelativeFrame(.horizontal, count: 6, spacing: SeriesGrid.spacing)
                                }
                            }
                        }
                        .scrollClipDisabled()
                        .focusSection()
                    }
                    SectionTitle("Последние релизы")
                    if let error {
                        LoadFailure(message: error) {
                            Task { await loadLatest() }
                        }
                    } else if latest.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 400)
                    } else {
                        SeriesGrid(series: latest)
                    }
                }
            }
            .onAppear {
                Task { await loadHistory() }
            }
        }
        .task {
            if latest.isEmpty {
                await loadLatest()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await loadLatest() }
        }
    }

    private func loadLatest() async {
        var freshFirst = SeriesSearchData()
        freshFirst.filter.sorting = "FRESH_AT_DESC"
        error = nil
        do {
            latest = try await app.catalog.fetchCatalog(page: 1, limit: 30, data: freshFirst).firstValue()
        } catch {
            if latest.isEmpty, !(error is CancellationError) {
                self.error = error.message
            }
        }
    }

    private func loadHistory() async {
        if let series = try? await app.player.fetchSeriesHistory().firstValue() {
            history = series
        }
    }
}

struct SectionTitle: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(Theme.muted)
    }
}
