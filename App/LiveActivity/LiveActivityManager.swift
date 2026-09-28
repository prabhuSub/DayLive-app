import Combine
import ActivityKit
import BackgroundTasks
import Foundation
import UIKit

/// Starts, updates and restarts the one DayLive Live Activity.
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
    private var pendingRefresh = false

    var activitiesEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func snapshot(now: Date = .now) -> DaySnapshot {
        let blocks = BlockStore.shared.planBlocks(on: now) + CalendarService.shared.events(on: now)
        return DayEngine.snapshot(of: blocks, overrides: BlockStore.shared.overrides, now: now)
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

        if !snap.hasAnythingLeft {
            // Day's over: show "Day complete" briefly, then let iOS dismiss it.
            for a in running { await a.end(content, dismissalPolicy: .default) }
        } else if let activity = running.first {
            let startedAt = (UserDefaults.standard.object(forKey: Keys.startedAt) as? Date) ?? now
            if now.timeIntervalSince(startedAt) > maxAge && inForeground {
                // Restart only in the foreground: a background request would fail and leave nothing on screen.
                for a in running { await a.end(nil, dismissalPolicy: .immediate) }
                request(content)
            } else {
                await activity.update(content)
            }
        } else if autoStart {
            request(content)
        }

        isRunning = !Self.liveActivities().isEmpty
        BackgroundRefresh.schedule(at: snap.nextBoundary)
    }

    func start() async {
        autoStart = true
        await refresh()
    }

    func stop() async {
        autoStart = false
        for a in Self.liveActivities() {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        isRunning = false
    }

    private func request(_ content: ActivityContent<DayActivityAttributes.ContentState>) {
        guard activitiesEnabled else {
            lastError = "Live Activities are off. Turn them on in Settings › DayLive."
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
