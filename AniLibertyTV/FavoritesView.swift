//
//  FavoritesView.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import SwiftUI

struct FavoritesView: View {
    @Environment(AppModel.self) private var app

    @State private var pages = SeriesPages()

    var body: some View {
        SeriesStack {
            if app.user == nil {
                ContentUnavailableView {
                    Label(L10n.Common.Collections.favorites, systemImage: "star")
                } description: {
                    Text("Войдите в профиль, чтобы видеть избранные релизы")
                }
            } else {
                ScrollView {
                    PagedSeriesGrid(pages: pages, emptyMessage: L10n.Stub.Collection.message)
                }
                .task {
                    if pages.items.isEmpty {
                        await reload()
                    }
                }
                .onReceive(app.favorites.favoritesUpdates()) { _ in
                    Task { await reload() }
                }
            }
        }
        .onChange(of: app.user?.id) {
            Task { await reload() }
        }
    }

    private func reload() async {
        await pages.reload { [favorites = app.favorites] page, limit in
            favorites.fetchSeries(limit: limit, page: page, data: SeriesSearchData())
        }
    }
}
