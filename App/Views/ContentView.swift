import Combine
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: BlockStore
    @EnvironmentObject private var activity: LiveActivityManager

    @State private var showingAdd = false
    @State private var now = Date.now
    @State private var calendarGranted = CalendarService.shared.hasAccess

    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        // Re-renders whenever BlockStore publishes (add/delete/Done) or the 30s tick fires.
        let snap = activity.snapshot(now: now)

        NavigationStack {
            List {
                Section {
                    PreviewCard(state: snap.contentState())
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } footer: {
                    Text(activity.isRunning ? "Live on your Lock Screen." : "Not live. Tap Start Live.")
                }

                if !calendarGranted {
                    Section {
                        Button("Allow calendar access") {
                            Task {
                                calendarGranted = await CalendarService.shared.requestAccess()
                                await activity.refresh()
                            }
                        }
                    } footer: {
                        Text("If you denied it before, turn it on in Settings › DayLive › Calendars.")
                    }
                }

                if let error = activity.lastError {
                    Section { Text(error).foregroundStyle(.red) }
                }

                Section("Today") {
                    if snap.all.isEmpty {
                        Text("Nothing planned. Tap + to add a block.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(snap.all) { block in
                        BlockRow(block: block, now: now)
                            .swipeActions {
                                if block.source == .plan {
                                    Button("Delete", role: .destructive) {
                                        store.delete(id: block.id)
                                        Task { await activity.refresh() }
                                    }
                                }
                            }
                    }
                }
            }
            .navigationTitle(now.formatted(.dateTime.weekday(.wide).month().day()))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(activity.isRunning ? "Stop Live" : "Start Live") {
                        Task {
                            if activity.isRunning { await activity.stop() } else { await activity.start() }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add block")
                }
            }
            .sheet(isPresented: $showingAdd) {
                QuickAddSheet()
                    .presentationDetents([.medium])
            }
            .onReceive(tick) { now = $0 }
            .task {
                if CalendarService.shared.needsPrompt {
                    calendarGranted = await CalendarService.shared.requestAccess()
                }
                await activity.refresh()
            }
        }
    }
}

/// The same card the Lock Screen shows, on a glass-like background, for checking without locking the phone.
private struct PreviewCard: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        LockScreenCard(state: state)
            .background(
                LinearGradient(colors: [Color(red: 0.37, green: 0.5, blue: 0.7), Color(red: 0.91, green: 0.55, blue: 0.5)],
                               startPoint: .top, endPoint: .bottom)
                    .overlay(DayLiveStyle.cardTint.opacity(DayLiveStyle.glassOpacity + 0.2))
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.vertical, 4)
    }
}

private struct BlockRow: View {
    let block: Block
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            SourceIcon(source: block.source, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.title).font(.body.weight(.semibold))
                Text("\(block.start.shortTime) – \(block.end.shortTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if block.contains(now) {
                Text("Now").font(.caption.bold()).foregroundStyle(DayLiveStyle.planGreen)
            }
        }
        .opacity(block.end <= now ? 0.45 : 1)
    }
}
