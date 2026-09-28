import Foundation

/// One block of the day: a calendar event or something you planned in DayLive.
struct Block: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var source: BlockSource

    var duration: TimeInterval { end.timeIntervalSince(start) }

    func contains(_ date: Date) -> Bool { start <= date && date < end }
}

/// A checklist item inside a block. Checked steps fill the green bar on the Live Activity.
struct Step: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var title: String
    var done: Bool = false
}

/// Done / Start next never edits your calendar. It records an override instead.
struct BlockOverride: Codable, Hashable {
    var start: Date?
    var end: Date?
}

extension Date {
    var shortTime: String { formatted(date: .omitted, time: .shortened) }
}
