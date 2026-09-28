import EventKit
import SwiftUI

@main
struct DayLiveApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = BlockStore.shared
    @StateObject private var activity = LiveActivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .tint(.white)
                .environmentObject(store)
                .environmentObject(activity)
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
