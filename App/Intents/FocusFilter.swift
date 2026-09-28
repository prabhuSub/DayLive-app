import AppIntents
import Foundation

/// What Hyperday shows while a Focus is on. Set per Focus in
/// iOS Settings › Focus › (Work) › Add Filter › Hyperday.
enum FocusShow: String, AppEnum, CaseIterable {
    case everything, work, personal, nothing

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Show"
    static var caseDisplayRepresentations: [FocusShow: DisplayRepresentation] = [
        .everything: "Everything",
        .work: "Work only",
        .personal: "Personal only",
        .nothing: "Nothing",
    ]

    /// Category ids kept on screen; nil = no filtering.
    var categoryIDs: Set<String>? {
        switch self {
        case .everything: return nil
        case .work: return ["work", "meetings", "deepwork"]
        case .personal: return ["family", "fitness", "personal"]
        case .nothing: return []
        }
    }
}

struct HyperdayFocusFilter: SetFocusFilterIntent {
    static var title: LocalizedStringResource = "Hyperday"
    static var description: IntentDescription? = IntentDescription("Show only work or personal blocks while this Focus is on.")

    /// Default is Everything, so turning the Focus off clears the filter.
    @Parameter(title: "Show", default: .everything)
    var show: FocusShow

    var displayRepresentation: DisplayRepresentation {
        switch show {
        case .everything: return "Hyperday: everything"
        case .work: return "Hyperday: work only"
        case .personal: return "Hyperday: personal only"
        case .nothing: return "Hyperday: nothing"
        }
    }

    func perform() async throws -> some IntentResult {
        FocusFilterState.current = show
        await LiveActivityManager.shared.refresh()
        return .result()
    }
}

enum FocusFilterState {
    private static let key = "focusFilterShow"

    static var current: FocusShow {
        get { FocusShow(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .everything }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    /// Keep a block if the active Focus filter allows its category.
    @MainActor
    static func allows(_ block: Block) -> Bool {
        guard let ids = current.categoryIDs else { return true }
        return ids.contains(CategoryStore.shared.category(for: block).id)
    }
}
