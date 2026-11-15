//
//  SeriesGrid.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import Combine
import Kingfisher
import SwiftUI

/// A tab's navigation stack: every poster inside it opens the title page.
struct SeriesStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(for: Series.self) { SeriesView(series: $0) }
        }
    }
}

struct PosterCard: View {
    static let aspectRatio: CGFloat = 7 / 10

    let series: Series

    var body: some View {
        NavigationLink(value: series) {
            PosterImage(url: series.poster)
                .hoverEffect(.highlight)
            Text(series.name?.main ?? "")
                .font(.caption)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.borderless)
    }
}

struct PosterImage: View {
    let url: URL?

    var body: some View {
        Theme.surface
            .aspectRatio(PosterCard.aspectRatio, contentMode: .fit)
            .overlay {
                KFImage(url)
                    .fade(duration: 0.2)
                    .resizable()
                    .scaledToFill()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SeriesGrid: View {
    static let spacing: CGFloat = 48

    let series: [Series]
    var onLastAppear: () -> Void = {}

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: 6), spacing: 60) {
            ForEach(series, id: \.id) { item in
                PosterCard(series: item)
                    .onAppear {
                        if item.id == series.last?.id {
                            onLastAppear()
                        }
                    }
            }
        }
    }
}

/// A paged grid with its loading, empty and failure states.
struct PagedSeriesGrid: View {
    let pages: SeriesPages
    var emptyMessage = L10n.Stub.title

    var body: some View {
        if !pages.items.isEmpty {
            SeriesGrid(series: pages.items) {
                Task { await pages.loadMore() }
            }
        } else if let error = pages.error {
            LoadFailure(message: error) {
                Task { await pages.loadMore() }
            }
        } else if pages.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 400)
        } else {
            ContentUnavailableView(emptyMessage, systemImage: "tray")
        }
    }
}

struct LoadFailure: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(L10n.Alert.Title.error, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button(L10n.Buttons.retry, action: retry)
        }
    }
}

/// A list of releases that the service returns page by page.
@MainActor
@Observable
final class SeriesPages {
    typealias Fetch = (_ page: Int, _ limit: Int) -> AnyPublisher<[Series], Error>

    private(set) var items: [Series] = []
    private(set) var error: String?
    private(set) var isLoading = false

    @ObservationIgnored private var fetch: Fetch?
    @ObservationIgnored private var nextPage = 1
    @ObservationIgnored private var isComplete = false
    @ObservationIgnored private var generation = 0

    private let pageSize = 30

    func reload(_ fetch: @escaping Fetch) async {
        self.fetch = fetch
        generation += 1
        items = []
        nextPage = 1
        isComplete = false
        isLoading = false
        await loadMore()
    }

    func loadMore() async {
        guard let fetch, !isLoading, !isComplete else { return }
        let generation = generation
        isLoading = true
        error = nil
        do {
            let page = try await fetch(nextPage, pageSize).firstValue()
            // A reload that started while this page was in flight owns the list now.
            guard generation == self.generation else { return }
            let known = Set(items.map(\.id))
            items += page.filter { !known.contains($0.id) }
            nextPage += 1
            isComplete = page.count < pageSize
        } catch {
            guard generation == self.generation else { return }
            if !(error is CancellationError) {
                self.error = error.message
            }
        }
        isLoading = false
    }
}
