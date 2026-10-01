import AppIntents
import Foundation

/// The Done / Start next button on the Live Activity.
/// LiveActivityIntent runs in the APP's process (iOS wakes it in the background),
/// so the widget extension only needs the type to exist; the work is app-only.
struct BlockActionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Done / Next"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Block ID")
    var blockID: String

    @Parameter(title: "Action")
    var actionRaw: String

    init() {}

    init(blockID: String, action: BlockAction) {
        self.blockID = blockID
        self.actionRaw = action.rawValue
    }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let action = BlockAction(rawValue: actionRaw) ?? .done
        let id = blockID
        await MainActor.run {
            switch action {
            case .done:      BlockStore.shared.finish(blockID: id, at: .now)
            case .startNext: BlockStore.shared.start(blockID: id, at: .now)
            case .checkStep: BlockStore.shared.checkNextStep(blockID: id)
            }
        }
        await LiveActivityManager.shared.refresh()
        #endif
        return .result()
    }
}

/// v19: −15 / +15 on the Live Activity. Changes how long YOUR planned block runs, even if it now
/// runs into the next block (that one just shows as "also:"). Calendar events are never touched.
struct AdjustTimeIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Add or cut time"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Block ID")
    var blockID: String

    @Parameter(title: "Minutes")
    var minutes: Int

    init() {}

    init(blockID: String, minutes: Int) {
        self.blockID = blockID
        self.minutes = minutes
    }

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        let id = blockID, m = minutes
        await MainActor.run { BlockStore.shared.adjust(blockID: id, minutes: m, now: .now) }
        await LiveActivityManager.shared.refresh()
        #endif
        return .result()
    }
}
