import SwiftUI

/// "+" -> title, start, length -> Add. Aim: under 5 seconds.
struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    @State private var title = ""
    @State private var start = QuickAddSheet.nextFiveMinutes()
    @State private var minutes = 60

    private let lengths = [15, 30, 60, 90, 120]

    var body: some View {
        NavigationStack {
            Form {
                TextField("What are you doing?", text: $title)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit(add)

                DatePicker("Start", selection: $start, displayedComponents: [.hourAndMinute])

                Picker("Length", selection: $minutes) {
                    ForEach(lengths, id: \.self) { m in
                        Text(m < 60 ? "\(m)m" : (m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h\(m % 60)"))
                            .tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Text("Ends at \(start.addingTimeInterval(TimeInterval(minutes * 60)).shortTime)")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Add block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: add)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private func add() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        BlockStore.shared.add(title: title, start: start, minutes: minutes)
        Task { await LiveActivityManager.shared.refresh() }
        dismiss()
    }

    private static func nextFiveMinutes() -> Date {
        let t = (Date.now.timeIntervalSinceReferenceDate / 300).rounded(.up) * 300
        return Date(timeIntervalSinceReferenceDate: t)
    }
}

// MARK: - Edit block

/// Tap a block in the timeline -> edit it. Planned blocks: title, start, length, steps.
/// Calendar events: steps only (the event itself is edited in the Calendar app).
struct BlockEditorSheet: View {
    let block: Block
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var start: Date
    @State private var minutes: Int
    @State private var steps: [Step]
    @State private var newStep = ""
    @FocusState private var newStepFocused: Bool

    init(block: Block, steps: [Step], onDelete: @escaping () -> Void = {}) {
        self.block = block
        self.onDelete = onDelete
        _title = State(initialValue: block.title)
        _start = State(initialValue: block.start)
        _minutes = State(initialValue: max(5, Int((block.duration / 60).rounded())))
        _steps = State(initialValue: steps)
    }

    private var isPlan: Bool { block.source == .plan }

    var body: some View {
        NavigationStack {
            Form {
                if isPlan {
                    Section {
                        TextField("Title", text: $title)
                        DatePicker("Start", selection: $start, displayedComponents: [.hourAndMinute])
                        Stepper(value: $minutes, in: 5...720, step: 5) {
                            Text("Length  \(lengthText)")
                        }
                        Text("Ends at \(start.addingTimeInterval(TimeInterval(minutes * 60)).shortTime)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Text(block.title).font(.headline)
                        Text("\(block.start.shortTime) – \(block.end.shortTime)")
                            .foregroundStyle(.secondary)
                    } footer: {
                        Text("From your calendar. Change the time in the Calendar app; steps are saved in Hyperday.")
                    }
                }

                Section {
                    ForEach($steps) { $step in
                        HStack(spacing: 12) {
                            Button {
                                step.done.toggle()
                            } label: {
                                Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(step.done ? DayLiveStyle.accent : Color.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(step.done ? "Mark not done" : "Mark done")
                            TextField("Step", text: $step.title)
                                .strikethrough(step.done)
                        }
                    }
                    .onDelete { steps.remove(atOffsets: $0) }

                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                        TextField("Add a step", text: $newStep)
                            .focused($newStepFocused)
                            .submitLabel(.next)
                            .onSubmit(addStep)
                    }
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Each step is one green segment on your Lock Screen while this block is on. Swipe left to delete.")
                }

                if isPlan {
                    Section {
                        Button("Delete block", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(isPlan ? "Edit block" : "Steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(isPlan && title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var lengthText: String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func addStep() {
        let clean = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        steps.append(Step(title: clean))
        newStep = ""
        newStepFocused = true   // keep typing the next step
    }

    private func save() {
        addStep()   // don't lose a step typed but not submitted
        let store = BlockStore.shared
        if isPlan {
            store.update(id: block.id, title: title, start: start, minutes: minutes)
        }
        store.setSteps(steps, for: block.id)
        Task { await LiveActivityManager.shared.refresh() }
        dismiss()
    }
}
