//
//  AniLibertyTVApp.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import SwiftUI

@main
struct AniLibertyTVApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Theme.canvas.ignoresSafeArea()
                TabView {
                    HomeView()
                        .tabItem { Text(L10n.Screen.Feed.title) }
                    CatalogView()
                        .tabItem { Text("Каталог") }
                    FavoritesView()
                        .tabItem { Text(L10n.Common.Collections.favorites) }
                    ProfileView()
                        .tabItem { Text("Профиль") }
                    SearchView()
                        .tabItem { Label(L10n.Screen.Catalog.title, systemImage: "magnifyingglass") }
                }
            }
            .environment(app)
        }
    }
}

enum Theme {
    static let canvas = Color(red: 13 / 255, green: 15 / 255, blue: 22 / 255)
    static let surface = Color(red: 20 / 255, green: 22 / 255, blue: 31 / 255)
    static let text = Color(red: 236 / 255, green: 238 / 255, blue: 246 / 255)
    static let muted = Color(red: 160 / 255, green: 164 / 255, blue: 184 / 255)
    static let brand = Color(.Buttons.selected)
}
