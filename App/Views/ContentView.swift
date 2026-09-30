import Combine
import SwiftUI
import UIKit

/// Today tab: big title, info row, Add / Go Live, today's timeline.
struct TodayView: View {
    @EnvironmentObject private var store: BlockStore
    @EnvironmentObject private var activity: LiveActivityManager
    @EnvironmentObject private var categories: CategoryStore

    @State private var showingAdd = false
    @State private var editing: Block?
    @State private var now = Date.now
    @State private var calendarGranted = CalendarService.shared.hasAccess

    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let snap = activity.snapshot(now: now)

        VStack(spacing: 0) {
            HeaderBar(section: "Today")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero(snap: snap)
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                        .padding(.bottom, 22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.bg)

                    VStack(alignment: .leading, spacing: 14) {
                        if !calendarGranted { calendarBanner }
                        Text("Today")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.text)
                        timeline(snap: snap)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Theme.section)
            // LIVE NOW sits top-right, under the theme button.
            .overlay(alignment: .topTrailing) {
                livePill(snap: snap)
                    .padding(.top, 10)
                    .padding(.trailing, 16)
            }
        }
        .sheet(isPresented: $showingAdd) {
            QuickAddSheet()
                .presentationDetents([.large])
        }
        .sheet(item: $editing) { block in
            BlockEditorSheet(
                block: block,
                steps: store.steps(for: block.id),
                categoryIDs: store.manualCategoryIDs(for: block.id)
            ) {
                store.delete(id: block.id)
                Task { await activity.refresh() }
            }
            .presentationDetents([.large])
        }
        .onReceive(tick) { now = $0 }
        .task {
            if CalendarService.shared.needsPrompt {
                calendarGranted = await CalendarService.shared.requestAccess()
            }
            await activity.refresh()
        }
    }

    // MARK: Hero

    private func hero(snap: DaySnapshot) -> some View {
        let title: String
        let subtitle: String
        if let c = snap.current, snap.overtime {
            title = c.title
            subtitle = "Over time since \(c.end.shortTime) · tap Done on the Lock Screen"
        } else if let c = snap.current {
            title = c.title
            subtitle = "\(c.source == .calendar ? (c.calendarName ?? "Calendar") : "My plan") · until \(c.end.shortTime)"
        } else if let n = snap.next {
            title = "Free"
            subtitle = "Next: \(n.title) at \(n.start.shortTime)"
        } else {
            title = snap.all.isEmpty ? "Nothing planned" : "Day complete"
            subtitle = snap.all.isEmpty ? "Tap Add block to plan your day" : "Nothing else today"
        }

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Caps(now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                Text(title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.trailing, 120)   // room for the LIVE NOW pill

            InfoRow(items: todayNumbers(snap))

            HStack(spacing: 10) {
                Button("Add block") { showingAdd = true }
                    .buttonStyle(PrimaryButtonStyle())
                Button(activity.isRunning ? "Stop Live" : "Go Live") {
                    Task {
                        if activity.isRunning { await activity.stop() } else { await activity.start() }
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }

            if !activity.isRunning || activity.lastError != nil {
                Text(activity.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(activity.lastError == nil ? Theme.muted : Theme.red)
            }
        }
    }

    /// FOCUSED (Work + Deep Work so far) · STEPS · MEETINGS LEFT
    private func todayNumbers(_ snap: DaySnapshot) -> [InfoItem] {
        var focused: TimeInterval = 0
        var stepsDone = 0, stepsTotal = 0, meetingsLeft = 0
        for b in snap.all {
            let cats = categories.categories(for: b).map(\.id)
            let share = 1 / Double(max(cats.count, 1))
            let focusCount = cats.filter { $0 == "work" || $0 == "deepwork" }.count
            focused += max(0, min(b.end, now).timeIntervalSince(b.start)) * share * Double(focusCount)
            if cats.contains("meetings") && b.end > now { meetingsLeft += 1 }
            let st = store.steps(for: b.id)
            stepsDone += st.filter(\.done).count
            stepsTotal += st.count
        }
        return [
            InfoItem(label: "Focused", value: focused.hoursMinutes),
            InfoItem(label: "Steps", value: stepsTotal == 0 ? "—" : "\(stepsDone) / \(stepsTotal)"),
            InfoItem(label: "Meetings left", value: "\(meetingsLeft)"),
        ]
    }

    // MARK: LIVE NOW pill

    @ViewBuilder
    private func livePill(snap: DaySnapshot) -> some View {
        if activity.isRunning, let c = snap.current {
            let color = categories.displayColor(for: c)
            Button { editing = c } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(color).frame(width: 20, height: 20)
                    Circle().fill(Color.white).frame(width: 7, height: 7)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Caps("Live now", color: color)
                    Text(snap.overtime ? "\(now.timeIntervalSince(c.end).hoursMinutes) over"
                                       : "\(c.end.timeIntervalSince(now).hoursMinutes) left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.text)
                }
            }
            .padding(.vertical, 7)
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Live now: \(c.title). Open steps.")
        }
    }

    // MARK: Timeline

    private func timeline(snap: DaySnapshot) -> some View {
        VStack(spacing: 0) {
            if snap.all.isEmpty {
                Text("Nothing planned. Tap Add block, or load sample data in Settings.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(Array(snap.all.enumerated()), id: \.element.id) { index, block in
                if index > 0 { Rectangle().fill(Theme.border).frame(height: 1) }
                SwipeRow(leading: leadingActions(block), trailing: trailingActions(block)) {
                    Button {
                        editing = block
                    } label: {
                        BlockRow(block: block, now: now,
                                 color: categories.displayColor(for: block),
                                 steps: store.steps(for: block.id))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardBox(padding: 0)
    }

    /// Swipe right: Start (timer from now). Any block that hasn't ended.
    private func leadingActions(_ block: Block) -> [SwipeAction] {
        guard block.end > now else { return [] }
        return [SwipeAction(title: "Start", icon: "play.fill", color: DayLiveStyle.planGreen) {
            store.start(blockID: block.id, at: .now)
            Task { await activity.refresh() }
        }]
    }

    /// Swipe left: Tomorrow + Delete. Only blocks you planned; calendar events stay read-only.
    private func trailingActions(_ block: Block) -> [SwipeAction] {
        guard block.source == .plan else { return [] }
        return [
            SwipeAction(title: "Tomorrow", icon: "calendar.badge.clock", color: Theme.blue) {
                store.move(id: block.id, byDays: 1)
                Task { await activity.refresh() }
            },
            SwipeAction(title: "Delete", icon: "trash", color: Theme.red) {
                store.delete(id: block.id)
                Task { await activity.refresh() }
            },
        ]
    }

    private var calendarBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caps("Calendar access is off")
            Text("Turn it on so your Tesla and personal events show up.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
            Button("Allow access") {
                Task {
                    calendarGranted = await CalendarService.shared.requestAccess()
                    if !calendarGranted, let url = URL(string: UIApplication.openSettingsURLString) {
                        await UIApplication.shared.open(url)
                    }
                    await activity.refresh()
                }
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .cardBox()
    }
}
