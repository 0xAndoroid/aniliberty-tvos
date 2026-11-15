//
//  PlayerView.swift
//  AniLibertyTV
//
//  Created by Andrew Tretyakov on 14.11.2026.
//  Copyright © 2026 Andrew Tretyakov. All rights reserved.
//

import AVKit
import SwiftUI

/// The system player for one episode. It starts from the saved position and saves the position when it closes.
struct PlayerView: UIViewControllerRepresentable {
    let series: Series
    let episode: PlaylistItem
    let userID: Int?
    let service: PlayerService

    func makeCoordinator() -> Playback {
        Playback(series: series, episode: episode, userID: userID, service: service)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        context.coordinator.start(in: controller)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: Playback) {
        coordinator.stop()
    }
}

final class Playback {
    private let series: Series
    private let userID: Int?
    private let service: PlayerService
    private let player = AVPlayer()

    private var item: PlayItem
    private var timeCode: TimeCodeData
    private var observers: [NSObjectProtocol] = []
    private var readiness: NSKeyValueObservation?
    private weak var controller: AVPlayerViewController?
    /// False while an episode loads. Until it is ready to play, the system controls count a skip by the viewer
    /// from zero instead of the start position, and the player's clock may still read zero, so skipping is off
    /// and the position is not saved.
    private var isReady = false {
        didSet {
            controller?.requiresLinearPlayback = !isReady
        }
    }

    init(series: Series, episode: PlaylistItem, userID: Int?, service: PlayerService) {
        self.series = series
        self.userID = userID
        self.service = service
        timeCode = service.startTimeCode(for: episode, userID: userID)
        item = PlayItem(
            index: series.playlist.firstIndex(of: episode) ?? 0,
            value: episode,
            startTime: timeCode.time,
            quality: service.fetchSettings().quality,
            itemsCount: series.playlist.count
        )
    }

    func start(in controller: AVPlayerViewController) {
        self.controller = controller
        controller.player = player
        load()

        let center = NotificationCenter.default
        observers = [
            UIApplication.willResignActiveNotification,
            AVPlayerItem.didPlayToEndTimeNotification
        ].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.save()
            }
        }
    }

    func stop() {
        save()
        player.pause()
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func load() {
        guard let url = item.url else { return }
        let playerItem = AVPlayerItem(url: url)
        playerItem.externalMetadata = [
            metadata(.commonIdentifierTitle, series.name?.main ?? ""),
            metadata(.iTunesMetadataTrackSubTitle, [item.value.episode, item.value.title].compactMap { $0 }.joined(separator: " · "))
        ]
        isReady = false
        player.replaceCurrentItem(with: playerItem)
        let start = CMTime(seconds: item.startTime, preferredTimescale: 600)
        player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
        readiness = playerItem.observe(\.status) { [weak self] playerItem, _ in
            DispatchQueue.main.async {
                guard let self, playerItem.status == .readyToPlay, self.player.currentItem === playerItem else { return }
                self.isReady = true
            }
        }
        player.play()
        controller?.transportBarCustomMenuItems = [qualityMenu]
    }

    private var qualityMenu: UIMenu {
        let actions = item.value.supportedQualities().map { quality in
            UIAction(title: quality.name, state: quality == item.quality ? .on : .off) { [weak self] _ in
                self?.select(quality)
            }
        }
        return UIMenu(title: L10n.Common.quality, image: UIImage(systemName: "gearshape"), children: actions)
    }

    private func select(_ quality: VideoQuality) {
        guard quality != item.quality else { return }
        var settings = service.fetchSettings()
        settings.quality = quality
        service.update(settings: settings)

        save()
        item.set(quality: quality, startTime: timeCode.time)
        load()
    }

    private func save() {
        let position = player.currentTime().seconds
        guard isReady, position.isFinite, position != timeCode.time else { return }
        timeCode.time = position
        service.save(timeCode: timeCode, of: item.value, in: series, userID: userID)
    }

    private func metadata(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }
}
