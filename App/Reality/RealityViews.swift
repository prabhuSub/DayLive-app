import CoreLocation
import SwiftUI

/// #3 on Today: planned blocks (left) vs what actually happened (right), 6 AM – 10 PM.
struct RealityCard: View {
    let blocks: [Block]
    let now: Date
    @EnvironmentObject private var categories: CategoryStore
    @ObservedObject private var reality = RealityStore.shared

    private let hourHeight: CGFloat = 30

    var body: some View {
        let segs = reality.segments(on: now)
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: now)
        let all = blocks.map(\.start) + segs.map(\.start)
        let firstHour = min(7, all.map { cal.component(.hour, from: $0) }.min() ?? 7)
        let lastHour = max(21, (blocks.map(\.end) + segs.map(\.end)).map { cal.component(.hour, from: $0) + 1 }.max() ?? 21)
        let top = dayStart.addingTimeInterval(TimeInterval(firstHour * 3600))
        let y: (Date) -> CGFloat = { CGFloat($0.timeIntervalSince(top) / 3600) * hourHeight }
        let height = CGFloat(lastHour - firstHour) * hourHeight

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Caps("Planned")
                Spacer()
                Caps("What happened")
                    .frame(width: 130, alignment: .leading)
            }
            .padding(.leading, 30)
            GeometryReader { geo in
                let laneW = (geo.size.width - 30 - 8) / 2
                ZStack(alignment: .topLeading) {
                    ForEach(firstHour...lastHour, id: \.self) { h in
                        let yy = CGFloat(h - firstHour) * hourHeight
                        Rectangle().fill(Theme.border).frame(height: 1).offset(y: yy)
                        Text(h % 12 == 0 ? "12\(h < 12 ? "a" : "p")" : "\(h % 12)\(h < 12 ? "a" : "p")")
                            .font(.system(size: 9)).foregroundStyle(Theme.faint)
                            .offset(y: yy - 6)
                    }
                    ForEach(blocks) { b in
                        lane(b.title, color: categories.displayColor(for: b), from: y(b.start), to: y(b.end))
                            .frame(width: laneW)
                            .offset(x: 30)
                    }
                    ForEach(segs) { s in
                        lane(s.label, color: color(s.kind), from: y(s.start), to: y(s.end))
                            .frame(width: laneW)
                            .offset(x: 30 + laneW + 8)
                    }
                    if now > top && y(now) < height {
                        Rectangle().fill(Theme.red).frame(height: 2).offset(x: 26, y: y(now))
                    }
                }
            }
            .frame(height: height)
            if segs.isEmpty {
                Text("Nothing recorded yet today. Set Home and Office in Settings › Reality line, and add the car automation.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
        }
        .cardBox(padding: 12)
    }

    private func color(_ k: RealitySegment.Kind) -> Color {
        switch k {
        case .drive: return DayLiveStyle.calendarBlue
        case .place: return Color(white: 0.56)
        case .workout: return DayLiveStyle.doneGreen
        }
    }

    private func lane(_ title: String, color: Color, from: CGFloat, to: CGFloat) -> some View {
        let h = max(12, to - from - 2)
        return Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.text)
            .lineLimit(h > 24 ? 2 : 1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: h, alignment: .topLeading)
            .background(color.opacity(0.18))
            .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 3) }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .offset(y: from + 1)
    }
}

/// Settings › Reality line: places, the car automation, Health workouts.
struct RealitySettingsCard: View {
    @ObservedObject private var reality = RealityStore.shared
    @State private var busy: String?
    @AppStorage("realityTickWorkouts") private var tickWorkouts = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caps("Reality line · places")
            placeRow("home", "Home", "Used to see when you leave")
            placeRow("office", "Office",
                     DayCloseSettings.learnedCommuteMinutes.map { "Arrivals learn your commute: \($0) min avg" }
                        ?? "Arrivals learn your commute")
            placeRow("gym", "Gym", "Optional")

            Rectangle().fill(Theme.border).frame(height: 1)
            Caps("Your car")
            Text("iPhone doesn't let apps watch Bluetooth in the background. Add two Shortcuts automations once:")
                .font(.system(size: 12.5)).foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Shortcuts › Automation › New › Bluetooth (or CarPlay)")
                Text("2. Pick your car › Is Connected › Run Immediately")
                Text("3. Action: Hyperday › I'm driving")
                Text("4. Same for Is Disconnected › Hyperday › Arrived")
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.text)
            Button("Open Shortcuts") {
                if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
            }
            .buttonStyle(PrimaryButtonStyle())

            Rectangle().fill(Theme.border).frame(height: 1)
            Toggle("Workouts tick Fitness blocks", isOn: $tickWorkouts).font(.system(size: 14))
            Text("Reads workouts from Health. Everything stays on your iPhone.")
                .font(.system(size: 11)).foregroundStyle(Theme.muted)
        }
        .cardBox()
    }

    private func placeRow(_ id: String, _ name: String, _ sub: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 14)).foregroundStyle(Theme.text)
                Text(sub).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button(busy == id ? "Locating…" : (reality.place(id) != nil ? "Saved ✓ · Reset" : "Set to here")) {
                busy = id
                LocationService.shared.currentLocation { loc in
                    Task { @MainActor in
                        if let loc { RealityStore.shared.setPlace(id, name: name, at: loc) }
                        busy = nil
                    }
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .disabled(busy != nil)
        }
    }
}
