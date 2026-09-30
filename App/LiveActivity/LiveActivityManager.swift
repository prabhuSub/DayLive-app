import Combine
import ActivityKit
import BackgroundTasks
import Foundation
import UIKit
import WidgetKit

/// Starts, updates and restarts the one Hyperday Live Activity.
@MainActor
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    /// When on, opening the app (or any refresh) starts the Live Activity if it isn't running.
    @Published var autoStart: Bool {
        didSet { UserDefaults.standard.set(autoStart, forKey: Keys.autoStart) }
    }

    private enum Keys {
        static let autoStart = "autoStartActivity"
        static let startedAt = "activityStartedAt"
    }

    /// iOS ends a Live Activity after ~8h. Restart a bit before that.
    private let maxAge: TimeInterval = 7.5 * 3600

    private init() {
        autoStart = (UserDefaults.standard.object(forKey: Keys.autoStart) as? Bool) ?? true
        isRunning = !Self.liveActivities().isEmpty
    }

    /// Ended-but-not-dismissed activities still appear in `activities`; ignore them.
    private static func liveActivities() -> [Activity<DayActivityAttributes>] {
        Activity<DayActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    private var isRefreshing = false
    private var forceStart = false

    /// One line for the app header explaining the Live Activity state.
    var statusText: String {
        if !activitiesEnabled { return "Live Activities are off · open Settings" }
        if let lastError { return lastError }
        return isRunning ? "Live on your Lock Screen" : "Not live · tap Go Live"
    }
    private var pendingRefresh = false
    private var lastWidgetDay: WidgetDay?

    var activitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    /// Today's raw blocks: your planned blocks + calendar events (before overrides).
    func todayBlocks(now: Date = .now) -> [Block] {
        allTodayBlocks(now: now).filter(FocusFilterState.allows)
    }

    /// Unfiltered (history/stats must not depend on the current Focus).
    func allTodayBlocks(now: Date = .now) -> [Block] {
        BlockStore.shared.planBlocks(on: now) + CalendarService.shared.events(on: now)
    }

    func snapshot(now: Date = .now) -> DaySnapshot {
        var snap = DayEngine.snapshot(
            of: todayBlocks(now: now),
            overrides: BlockStore.shared.overrides,
            steps: BlockStore.shared.steps,
            now: now
        )
        snap.accentHex = snap.current.map { CategoryStore.shared.displayColorHex(for: $0) }
        return snap
    }

    /// Recompute the day and push it to the Live Activity. Safe to call often.
    func refresh() async {
        // Coalesce overlapping calls (launch + scene change + intent) without dropping the latest one.
        guard !isRefreshing else { pendingRefresh = true; return }
        isRefreshing = true
        repeat {
            pendingRefresh = false
            await performRefresh()
        } while pendingRefresh
        isRefreshing = false
    }

    private func performRefresh() async {
        let now = Date.now
        let snap = snapshot(now: now)
        let content = ActivityContent(state: snap.contentState(), staleDate: snap.nextBoundary)
        let running = Self.liveActivities()
        let inForeground = UIApplication.shared.applicationState == .active

        let dayIsOver = !snap.all.isEmpty && !snap.hasAnythingLeft
        let force = forceStart
        forceStart = false

        if dayIsOver && !force {
            // Day's over: show "Day complete" briefly, then let iOS dismiss it.
            for a in running { await a.end(content, dismissalPolicy: .default) }
        } else if let activity = running.first {
            // Only ever one Hyperday card: clear duplicates and ended cards still sitting on the Lock Screen.
            await Self.endAll(except: activity.id)
            let startedAt = (UserDefaults.standard.object(forKey: Keys.startedAt) as? Date) ?? now
            if now.timeIntervalSince(startedAt) > maxAge && inForeground {
                // Restart only in the foreground: a background request would fail and leave nothing on screen.
                await Self.endAll()
                request(content)
            } else {
                await activity.update(content)
            }
        } else if force || (autoStart && snap.hasAnythingLeft) {
            // Auto-start only when there's something to show; "Go Live" always starts.
            await Self.endAll()
            request(content)
        }

        isRunning = !Self.liveActivities().isEmpty
        HistoryStore.shared.recordToday(raw: allTodayBlocks(now: now), now: now)
        writeWidgetDay(snap, now: now)
        BackgroundRefresh.schedule(at: snap.nextBoundary)
    }

    /// Hand today's blocks to the Home Screen widgets (only when they changed, to save reloads).
    private func writeWidgetDay(_ snap: DaySnapshot, now: Date) {
        let store = BlockStore.shared
        let blocks = snap.all.map { b -> WidgetBlock in
            let steps = store.steps(for: b.id)
            return WidgetBlock(
                id: b.id, title: b.title, start: b.start, end: b.end,
                colorHex: CategoryStore.shared.displayColorHex(for: b),
                stepsDone: steps.filter(\.done).count, stepsTotal: steps.count,
                detail: b.source == .calendar ? (b.calendarName ?? "Calendar") : "My plan",
                nextStep: steps.first { !$0.done }?.title
            )
        }
        let day = WidgetDay(day: now, blocks: blocks)
        guard day != lastWidgetDay else { return }
        lastWidgetDay = day
        if WidgetShared.save(day) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func start() async {
        autoStart = true
        forceStart = true
        await refresh()
    }

    func stop() async {
        autoStart = false
        for a in Self.liveActivities() {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        isRunning = false
    }

    /// Ends every Hyperday Live Activity immediately (including ended ones iOS keeps showing for up to 4 hours).
    private static func endAll(except keep: String? = nil) async {
        for a in Activity<DayActivityAttributes>.activities where a.id != keep {
            await a.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func request(_ content: ActivityContent<DayActivityAttributes.ContentState>) {
        guard activitiesEnabled else {
            lastError = "Live Activities are off. Turn them on in Settings › Hyperday."
            return
        }
        do {
            let attributes = DayActivityAttributes(dayStart: Calendar.current.startOfDay(for: .now))
            _ = try Activity<DayActivityAttributes>.request(attributes: attributes, content: content, pushType: nil)
            UserDefaults.standard.set(Date.now, forKey: Keys.startedAt)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}

/// Best-effort wake-ups at block boundaries. iOS decides the real timing (can be late or skipped).
/// v1.1 replaces this with pushes from the Raspberry Pi for exact switching.
enum BackgroundRefresh {
    static let id = "com.prabhu.daylive.refresh"

    static func schedule(at date: Date?) {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = date ?? Date.now.addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
