import Combine
import SwiftUI
import UIKit

/// Tesla-style look: pure black, big type, flat dark cards, round quick controls.
enum Theme {
    static let bg = Color.black
    static let card = Color(white: 0.11)
    static let text = Color.white
    static let dim = Color(white: 0.58)
    static let faint = Color(white: 0.34)
    static let red = Color(red: 0.89, green: 0.19, blue: 0.18)
}

struct ContentView: View {
    @EnvironmentObject private var store: BlockStore
    @EnvironmentObject private var activity: LiveActivityManager
    @Environment(\.openURL) private var openURL

    @State private var showingAdd = false
    @State private var now = Date.now
    @State private var calendarGranted = CalendarService.shared.hasAccess

    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let snap = activity.snapshot(now: now)
        let state = snap.contentState()

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(title: state.title)
                PreviewCard(state: state)
                controls
                if !calendarGranted {
                    calendarBanner
                }
                timeline(snap: snap)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 60)
        }
        .background(Theme.bg.ignoresSafeArea())
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

    // MARK: Header

    private func header(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()).uppercased())
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.dim)
            Text(title)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
            HStack(spacing: 8) {
                Circle()
                    .fill(activity.isRunning ? DayLiveStyle.accent : Theme.faint)
                    .frame(width: 8, height: 8)
                Text(activity.statusText)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.dim)
            }
        }
        .padding(.top, 8)
    }

    // MARK: Quick controls

    private var controls: some View {
        HStack(spacing: 0) {
            ControlButton(
                symbol: activity.isRunning ? "stop.fill" : "bolt.fill",
                label: activity.isRunning ? "Stop Live" : "Go Live",
                active: activity.isRunning
            ) {
                Task {
                    if activity.isRunning { await activity.stop() } else { await activity.start() }
                }
            }
            ControlButton(symbol: "plus", label: "Add") { showingAdd = true }
            ControlButton(symbol: "arrow.clockwise", label: "Refresh") {
                Task { await activity.refresh() }
            }
            ControlButton(symbol: "gearshape", label: "Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        }
    }

    private var calendarBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Calendar access is off")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("Turn it on so your Tesla and personal events show up in your day.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.dim)
            Button("Allow access") {
                Task {
                    calendarGranted = await CalendarService.shared.requestAccess()
                    if !calendarGranted, let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                    await activity.refresh()
                }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }

    // MARK: Timeline

    private func timeline(snap: DaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TODAY")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.dim)
                .padding(.bottom, 4)

            if snap.all.isEmpty {
                Text("Nothing planned. Tap Add to plan a block.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.dim)
                    .padding(.vertical, 14)
            }

            ForEach(snap.all) { block in
                TimelineRow(block: block, now: now)
                    .contextMenu {
                        if block.source == .plan {
                            Button("Delete", role: .destructive) {
                                store.delete(id: block.id)
                                Task { await activity.refresh() }
                            }
                        }
                    }
                Rectangle().fill(Theme.card).frame(height: 1)
            }
        }
    }
}

// MARK: - Pieces

private struct ControlButton: View {
    let symbol: String
    let label: String
    var active: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(active ? Theme.text : Theme.card))
                    .foregroundStyle(active ? Color.black : Theme.text)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.dim)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// The Lock Screen card, drawn on a flat dark card so it can be checked without locking the phone.
private struct PreviewCard: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        LockScreenCard(state: state)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.card))
    }
}

private struct TimelineRow: View {
    let block: Block
    let now: Date

    var body: some View {
        let isNow = block.contains(now)
        let done = block.end <= now

        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(block.start.shortTime)
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundStyle(isNow ? Theme.text : Theme.dim)
                .frame(width: 76, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(block.title)
                    .font(.system(size: 17, weight: isNow ? .semibold : .regular))
                    .foregroundStyle(done ? Theme.faint : Theme.text)
                Text("\(block.start.shortTime) – \(block.end.shortTime) · \(block.source == .calendar ? "Calendar" : "My plan")")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
            }
            Spacer(minLength: 8)
            if isNow {
                Text("NOW")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.red)
            }
        }
        .padding(.vertical, 14)
    }
}
