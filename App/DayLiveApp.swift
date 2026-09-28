import EventKit
import SwiftUI

@main
struct DayLiveApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = Appearance.system.rawValue
    @StateObject private var store = BlockStore.shared
    @StateObject private var activity = LiveActivityManager.shared
    @StateObject private var categories = CategoryStore.shared
    @StateObject private var history = HistoryStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme((Appearance(rawValue: appearance) ?? .system).scheme)
                .tint(Theme.blue)
                .environmentObject(store)
                .environmentObject(activity)
                .environmentObject(categories)
                .environmentObject(history)
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                    Task { await LiveActivityManager.shared.refresh() }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await LiveActivityManager.shared.refresh() }
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.id)) {
            await LiveActivityManager.shared.refresh()
        }
    }
}
