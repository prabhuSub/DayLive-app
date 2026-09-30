import Foundation

/// One block of the day: a calendar event or something you planned in Hyperday.
struct Block: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var start: Date
    var end: Date
    var source: BlockSource
    var calendarName: String? = nil   // e.g. "Tesla" (calendar events only; used by category rules)
    var declined: Bool = false        // you declined this calendar invite

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
    /// Tapped Start: the block runs from `start` for its planned length (can be later than planned),
    /// and keeps going as overtime until Done.
    var started: Bool? = nil
}

extension Date {
    var shortTime: String { formatted(date: .omitted, time: .shortened) }
}

extension TimeInterval {
    /// 5400 -> "1h 30m"
    var hoursMinutes: String {
        let m = max(0, Int((self / 60).rounded()))
        let h = m / 60, r = m % 60
        if h == 0 { return "\(r)m" }
        return r == 0 ? "\(h)h" : "\(h)h \(r)m"
    }
}
