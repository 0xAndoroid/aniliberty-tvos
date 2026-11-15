import Foundation

struct PlayItem {
    let index: Int
    let value: PlaylistItem
    private(set) var startTime: Double = 0
    private(set) var quality: VideoQuality?
    private(set) var url: URL?

    let isLast: Bool
    let isFirst: Bool

    var name: String {
        if let ordinal = value.ordinal  {
            return "\(NSNumber(value: ordinal))"
        }
        return value.title ?? "1"
    }

    init(index: Int,
         value: PlaylistItem,
         startTime: Double,
         quality: VideoQuality,
         itemsCount: Int) {
        self.index = index
        self.value = value
        self.isLast = index == itemsCount - 1
        self.isFirst = index == 0
        set(quality: quality, startTime: startTime)
    }

    mutating func set(quality: VideoQuality, startTime: Double) {
        let videoUrl = value.video[quality]
        if videoUrl == nil, let bestQuality = value.supportedQualities().first {
            self.quality = bestQuality
            self.url = value.video[bestQuality]
        } else {
            self.quality = quality
            self.url = videoUrl
        }
        set(time: startTime)
    }

    private mutating func set(time: Double) {
        self.startTime = time
    }
}
