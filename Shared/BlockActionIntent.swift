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
