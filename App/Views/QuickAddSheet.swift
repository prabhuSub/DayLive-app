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
