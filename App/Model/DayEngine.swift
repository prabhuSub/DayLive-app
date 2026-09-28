import Foundation

/// Pure logic: blocks + overrides + "now" -> what the card shows. No iOS APIs, easy to unit-test.
struct DaySnapshot {
    var all: [Block]          // every block today, overrides applied, sorted
    var current: Block?       // main title
    var also: Block?          // overlapping block ("also:" line)
    var next: Block?
    var lanes: [Block]        // non-overlapping blocks = segments in the bar
    var segments: [Double]
    var dayProgress: Double
    var currentSteps: [Step] = []   // checklist of the current block (drives the bar when non-empty)
    var accentHex: String?          // category color of the current block (set by LiveActivityManager)

    /// Next moment the card's content changes. Used as staleDate + background refresh time.
    var nextBoundary: Date? {
        [current?.end, also?.end, next?.start].compactMap { $0 }.min()
    }

    var hasAnythingLeft: Bool { current != nil || next != nil }

    func contentState() -> DayActivityAttributes.ContentState {
        let label = next.map { "Next · \($0.title) at \($0.start.shortTime)" }
            ?? (all.isEmpty ? "Add a block in Hyperday" : "Nothing else today")

        var title = all.isEmpty ? "Nothing planned" : "Day complete"
        var source = BlockSource.free
        var actionID: String?
        var action: BlockAction?

        var bar = segments
        var stepsDone: Int?
        var stepsTotal: Int?
        var nextStepLine: String?

        if let c = current {
            title = c.title
            source = c.source
            actionID = c.id
            action = .done
            if !currentSteps.isEmpty {
                // Steps rule: the bar becomes this block's checklist; the button checks the next step.
                let done = currentSteps.filter(\.done).count
                bar = currentSteps.map { $0.done ? 1 : 0 }
                stepsDone = done
                stepsTotal = currentSteps.count
                if let nextStep = currentSteps.first(where: { !$0.done }) {
                    action = .checkStep
                    nextStepLine = "→ \(nextStep.title)"
                } else {
                    nextStepLine = "All \(currentSteps.count) steps done"
                }
            }
        } else if let n = next {
            title = "Free until \(n.start.shortTime)"
            actionID = n.id
            action = .startNext
        }

        return .init(
            label: label,
            title: title,
            // Overlap wins the second line; otherwise show the next step.
            also: also.map { "also: \($0.title) · \($0.start.shortTime)–\($0.end.shortTime)" } ?? nextStepLine,
            source: source,
            segments: bar,
            dayProgress: dayProgress,
            currentEnd: current?.end,
            actionBlockID: actionID,
            action: action,
            stepsDone: stepsDone,
            stepsTotal: stepsTotal,
            accentHex: current == nil ? nil : accentHex
        )
    }
}

enum DayEngine {
    static func snapshot(
        of raw: [Block],
        overrides: [String: BlockOverride],
        steps: [String: [Step]] = [:],
        now: Date
    ) -> DaySnapshot {
        let blocks = apply(overrides, to: raw).sorted {
            $0.start == $1.start ? $0.duration > $1.duration : $0.start < $1.start
        }

        // Overlap rule ("show both"): the block that started first is the title, the other is "also:".
        let active = blocks.filter { $0.contains(now) }
        let current = active.first
        let also = active.dropFirst().first
        let next = blocks.first { $0.start > now }

        // Bar segments: greedy non-overlapping lanes, so overlaps don't double up.
        var lanes: [Block] = []
        for b in blocks {
            if let last = lanes.last, b.start < last.end { continue }
            lanes.append(b)
        }

        var dayProgress = 0.0
        if let first = blocks.first?.start, let last = blocks.map(\.end).max(), last > first {
            dayProgress = clamp(now.timeIntervalSince(first) / last.timeIntervalSince(first))
        }

        return DaySnapshot(
            all: blocks,
            current: current,
            also: also,
            next: next,
            lanes: lanes,
            segments: lanes.map { progress(of: $0, at: now) },
            dayProgress: dayProgress,
            currentSteps: current.map { steps[$0.id] ?? [] } ?? []
        )
    }

    static func apply(_ overrides: [String: BlockOverride], to blocks: [Block]) -> [Block] {
        blocks.compactMap { original in
            var b = original
            if let o = overrides[b.id] {
                if let s = o.start { b.start = min(b.start, s) }
                if let e = o.end { b.end = min(b.end, e) }
            }
            return b.end > b.start ? b : nil
        }
    }

    static func progress(of b: Block, at now: Date) -> Double {
        if now >= b.end { return 1 }
        if now <= b.start { return 0 }
        return clamp(now.timeIntervalSince(b.start) / b.duration)
    }

    private static func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
}
