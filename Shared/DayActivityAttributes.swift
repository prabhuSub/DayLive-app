import ActivityKit
import Foundation

/// Where a block came from. Drives the source icon on the card.
enum BlockSource: String, Codable, Hashable {
    case calendar   // iOS Calendar (incl. the Tesla calendar)
    case plan       // added in DayLive
    case free       // gap between blocks
}

/// What the card's single button does.
enum BlockAction: String, Codable, Hashable {
    case done       // finish the current block early
    case startNext  // in a free gap: start the next block now
}

struct DayActivityAttributes: ActivityAttributes {
    /// Everything the Lock Screen card and Dynamic Island render.
    /// Kept small: ActivityKit caps the payload at 4 KB.
    struct ContentState: Codable, Hashable {
        var label: String            // "Next · Lunch at 12:30 PM"
        var title: String            // "Deep Work — ORBIT AI" / "Free until 12:30 PM"
        var also: String?            // "also: Standup · 10:00 AM–10:15 AM"
        var source: BlockSource
        var segments: [Double]       // 0...1 fill per block in the day bar
        var dayProgress: Double      // 0...1 for the Island ring
        var currentEnd: Date?        // drives the countdown in the expanded Island
        var actionBlockID: String?
        var action: BlockAction?
    }

    var dayStart: Date
}
