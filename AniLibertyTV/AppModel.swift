//
//  AppModel.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import Combine
import DITranquillity
import Observation

/// The services of the iOS app, resolved from the dependency container it builds, and the signed-in user.
@MainActor
@Observable
final class AppModel {
    let main: MainService
    let catalog: CatalogService
    let player: PlayerService
    let session: SessionService
    let favorites: FavoriteService

    private(set) var user: User?

    @ObservationIgnored private var sessionState: AnyCancellable?

    init() {
        // The tvOS screens are written in Russian only, so the shared strings stay in Russian too.
        Language.current = .ru

        let configuration = DependenciesConfigurationBase()
        configuration.setup()
        let container = configuration.configuredContainer()
        main = container.resolve()
        catalog = container.resolve()
        player = container.resolve()
        session = container.resolve()
        favorites = container.resolve()

        sessionState = session.fetchState().sink { [weak self] state in
            if case .user(let user) = state {
                self?.user = user
            } else {
                self?.user = nil
            }
        }
    }
}

extension Publisher {
    /// The first value of a publisher that emits once, such as a service request.
    func firstValue() async throws -> Output {
        for try await value in values {
            return value
        }
        throw CancellationError()
    }
}
