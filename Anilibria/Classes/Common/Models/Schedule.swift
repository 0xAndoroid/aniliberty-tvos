import Foundation

public struct Schedule: Hashable {
    let day: WeekDay?
    let items: [ScheduleItem]
    #if os(iOS)
    var title: TitleItem {
        TitleItem({ self.day?.name ?? "" }())
    }
    #endif
}
