import Combine
import Foundation

/// Your planned blocks + Done/Start-next overrides, saved as JSON in the app's Documents folder.
/// (No App Group needed: the widget only renders ContentState; intents run in the app process.)
@MainActor
final class BlockStore: ObservableObject {
    static let shared = BlockStore()

    @Published private(set) var planBlocks: [Block] = []
    @Published private(set) var overrides: [String: BlockOverride] = [:]

    private struct Snapshot: Codable {
        var planBlocks: [Block]
        var overrides: [String: BlockOverride]
    }

    private let fileURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("daylive-store.json")
    }()

    private init() {
        load()
        pruneOld()
    }

    // MARK: Plan blocks

    func add(title: String, start: Date, minutes: Int) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, minutes > 0 else { return }
        let block = Block(
            id: "plan-" + UUID().uuidString,
            title: clean,
            start: start,
            end: start.addingTimeInterval(TimeInterval(minutes * 60)),
            source: .plan
        )
        planBlocks.append(block)
        planBlocks.sort { $0.start < $1.start }
        save()
    }

    func delete(id: String) {
        planBlocks.removeAll { $0.id == id }
        overrides[id] = nil
        save()
    }

    func planBlocks(on day: Date) -> [Block] {
        let cal = Calendar.current
        return planBlocks.filter { cal.isDate($0.start, inSameDayAs: day) }
    }

    // MARK: Overrides (Done / Start next)

    func finish(blockID: String, at date: Date) {
        var o = overrides[blockID] ?? BlockOverride()
        o.end = date
        overrides[blockID] = o
        save()
    }

    func startEarly(blockID: String, at date: Date) {
        var o = overrides[blockID] ?? BlockOverride()
        o.start = date
        overrides[blockID] = o
        save()
    }

    // MARK: Persistence

    private func pruneOld() {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) else { return }
        let before = planBlocks.count
        let overridesBefore = overrides.count
        planBlocks.removeAll { $0.end < cutoff }
        // Calendar-event overrides carry the event start in their id; plan ones are cleaned with their block.
        let liveIDs = Set(planBlocks.map(\.id))
        overrides = overrides.filter { key, _ in
            key.hasPrefix("plan-") ? liveIDs.contains(key) : true
        }
        if overrides.count > 300 { overrides = [:] }   // crude cap for v1
        if planBlocks.count != before || overrides.count != overridesBefore { save() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        planBlocks = snap.planBlocks
        overrides = snap.overrides
    }

    private func save() {
        let snap = Snapshot(planBlocks: planBlocks, overrides: overrides)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
