//
//  SearchView.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var app

    @State private var query = ""
    @State private var results: [Series]?
    @State private var error: String?

    var body: some View {
        SeriesStack {
            ScrollView {
                if let error {
                    LoadFailure(message: error) {
                        Task { await search() }
                    }
                } else if let results, results.isEmpty {
                    ContentUnavailableView(L10n.Stub.messageNotFound(trimmedQuery), systemImage: "magnifyingglass")
                } else if let results {
                    SeriesGrid(series: results)
                }
            }
            .searchable(text: $query, prompt: L10n.Common.Search.byName)
        }
        .task(id: trimmedQuery) {
            try? await Task.sleep(for: .milliseconds(400))
            if !Task.isCancelled {
                await search()
            }
        }
    }

    private var trimmedQuery: String {
        query.trim()
    }

    private func search() async {
        let query = trimmedQuery
        error = nil
        guard !query.isEmpty else {
            results = nil
            return
        }
        do {
            results = try await app.main.search(query: query).firstValue()
        } catch {
            if !(error is CancellationError) {
                results = nil
                self.error = error.message
            }
        }
    }
}
