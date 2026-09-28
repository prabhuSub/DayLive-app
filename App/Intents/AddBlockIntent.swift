import AppIntents
import Foundation

/// "Hey Siri, add a block in Hyperday" -> Siri asks what + how long.
/// Also usable from Shortcuts and the Action Button.
/// LiveActivityIntent (not plain AppIntent) so it may start the Live Activity from the background.
struct AddBlockIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Add Block"
    static var description = IntentDescription("Plan a block of time in your day.")

    @Parameter(title: "What", requestValueDialog: "What are you going to do?")
    var what: String

    @Parameter(title: "Minutes", default: 60, requestValueDialog: "For how many minutes?")
    var minutes: Int

    @Parameter(title: "Start", description: "Leave empty to start now.")
    var start: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$what) for \(\.$minutes) minutes") {
            \.$start
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let begin = start ?? .now
        BlockStore.shared.add(title: what, start: begin, minutes: minutes)
        await LiveActivityManager.shared.refresh()
        return .result(dialog: "Added \(what) at \(begin.shortTime).")
    }
}

struct DayLiveShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddBlockIntent(),
            phrases: [
                "Add a block in \(.applicationName)",
                "Plan something in \(.applicationName)"
            ],
            shortTitle: "Add Block",
            systemImageName: "plus.circle"
        )
    }
}
