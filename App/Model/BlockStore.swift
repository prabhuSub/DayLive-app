import Combine
import Foundation

/// Your planned blocks + Done/Start-next overrides, saved as JSON in the app's Documents folder.
/// (No App Group needed: the widget only renders ContentState; intents run in the app process.)
@MainActor
final class BlockStore: ObservableObject {
    static let shared = BlockStore()

    @Published private(set) var planBlocks: [Block] = []
    @Published private(set) var overrides: [String: BlockOverride] = [:]
    /// Steps per block id (plan blocks and calendar events alike).
    @Published private(set) var steps: [String: [Step]] = [:]
    /// Manual category per block id; beats the auto rules.
    @Published private(set) var categoryOverrides: [String: String] = [:]

    private struct Snapshot: Codable {
        var planBlocks: [Block]
        var overrides: [String: BlockOverride]
        var steps: [String: [Step]]?   // optional so files saved before steps existed still load
        var categoryOverrides: [String: String]?
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

    @discardableResult
    func add(title: String, start: Date, minutes: Int, categoryID: String? = nil) -> String? {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, minutes > 0 else { return nil }
        let block = Block(
            id: "plan-" + UUID().uuidString,
            title: clean,
            start: start,
            end: start.addingTimeInterval(TimeInterval(minutes * 60)),
            source: .plan
        )
        planBlocks.append(block)
        planBlocks.sort { $0.start < $1.start }
        if let categoryID { categoryOverrides[block.id] = categoryID }
        save()
        return block.id
    }

    func delete(id: String) {
        planBlocks.removeAll { $0.id == id }
        overrides[id] = nil
        steps[id] = nil
        categoryOverrides[id] = nil
        save()
    }

    /// nil = back to automatic (rules).
    func setCategory(_ categoryID: String?, for blockID: String) {
        categoryOverrides[blockID] = categoryID
        save()
    }

    // MARK: Demo data

    static let demoPrefix = "plan-demo-"

    func addDemo(blocks: [Block], steps demoSteps: [String: [Step]], categories: [String: String], finished: [String: Date]) {
        planBlocks.removeAll { $0.id.hasPrefix(Self.demoPrefix) }
        planBlocks.append(contentsOf: blocks)
        planBlocks.sort { $0.start < $1.start }
        for (k, v) in demoSteps { steps[k] = v }
        for (k, v) in categories { categoryOverrides[k] = v }
        for (k, v) in finished { overrides[k] = BlockOverride(start: nil, end: v) }
        save()
    }

    func removeDemo() {
        planBlocks.removeAll { $0.id.hasPrefix(Self.demoPrefix) }
        steps = steps.filter { !$0.key.hasPrefix(Self.demoPrefix) }
        categoryOverrides = categoryOverrides.filter { !$0.key.hasPrefix(Self.demoPrefix) }
        overrides = overrides.filter { !$0.key.hasPrefix(Self.demoPrefix) }
        save()
    }

    /// Edit a planned block. Clears Done/Start-next overrides so the new times take effect.
    func update(id: String, title: String, start: Date, minutes: Int) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let i = planBlocks.firstIndex(where: { $0.id == id }), !clean.isEmpty, minutes > 0 else { return }
        planBlocks[i].title = clean
        planBlocks[i].start = start
        planBlocks[i].end = start.addingTimeInterval(TimeInterval(minutes * 60))
        planBlocks.sort { $0.start < $1.start }
        overrides[id] = nil
        save()
    }

    // MARK: Steps

    func steps(for blockID: String) -> [Step] { steps[blockID] ?? [] }

    func setSteps(_ list: [Step], for blockID: String) {
        let cleaned = list
            .map { Step(id: $0.id, title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines), done: $0.done) }
            .filter { !$0.title.isEmpty }
        steps[blockID] = cleaned.isEmpty ? nil : cleaned
        save()
    }

    func toggleStep(blockID: String, stepID: String) {
        guard var list = steps[blockID], let i = list.firstIndex(where: { $0.id == stepID }) else { return }
        list[i].done.toggle()
        steps[blockID] = list
        save()
    }

    /// Lock Screen button: check the first unchecked step.
    func checkNextStep(blockID: String) {
        guard var list = steps[blockID], let i = list.firstIndex(where: { !$0.done }) else { return }
        list[i].done = true
        steps[blockID] = list
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
        steps = steps.filter { key, _ in
            key.hasPrefix("plan-") ? liveIDs.contains(key) : true
        }
        categoryOverrides = categoryOverrides.filter { key, _ in
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
        steps = snap.steps ?? [:]
        categoryOverrides = snap.categoryOverrides ?? [:]
    }

    private func save() {
        let snap = Snapshot(planBlocks: planBlocks, overrides: overrides, steps: steps, categoryOverrides: categoryOverrides)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
