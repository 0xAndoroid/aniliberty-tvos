//
//  CatalogView.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import SwiftUI

struct CatalogView: View {
    @Environment(AppModel.self) private var app

    @State private var pages = SeriesPages()
    @State private var options = FilterData()
    @State private var filter = SeriesSearchData.Filter()

    var body: some View {
        SeriesStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    HStack(spacing: 40) {
                        Menu {
                            Picker(L10n.Screen.Filter.sotring, selection: $filter.sorting) {
                                Text(L10n.Common.default).tag(String?.none)
                                ForEach(options.sortings, id: \.id) { sorting in
                                    Text(sorting.name).tag(String?.some(sorting.id))
                                }
                            }
                        } label: {
                            Text("\(L10n.Screen.Filter.sotring): \(sortingName)")
                        }
                        Menu {
                            Picker(L10n.Screen.Filter.genres, selection: genre) {
                                Text("Все жанры").tag(Int?.none)
                                ForEach(options.genres, id: \.id) { genre in
                                    Text(genre.name).tag(Int?.some(genre.id))
                                }
                            }
                        } label: {
                            Text("\(L10n.Screen.Series.genres): \(genreName)")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focusSection()
                    PagedSeriesGrid(pages: pages)
                }
            }
        }
        .task {
            if pages.items.isEmpty {
                await reload()
            }
            if options.sortings.isEmpty, let loaded = try? await app.catalog.fetchFilterData().firstValue() {
                options = loaded
            }
        }
        .onChange(of: filter) {
            Task { await reload() }
        }
    }

    private func reload() async {
        await pages.reload { [catalog = app.catalog, filter] page, limit in
            catalog.fetchCatalog(page: page, limit: limit, data: SeriesSearchData(filter: filter))
        }
    }

    private var genre: Binding<Int?> {
        Binding {
            filter.genres.first
        } set: { id in
            filter.genres = id.map { [$0] } ?? []
        }
    }

    private var sortingName: String {
        options.sortings.first { $0.id == filter.sorting }?.name ?? L10n.Common.default
    }

    private var genreName: String {
        options.genres.first { $0.id == filter.genres.first }?.name ?? "Все жанры"
    }
}
