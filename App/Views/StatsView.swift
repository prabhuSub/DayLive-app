import SwiftUI

/// Stats tab: three big numbers, Week/Month/Year, hours by category, meeting load, blocks.
struct StatsView: View {
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var categories: CategoryStore
    @State private var range: StatsRange = .week
    @State private var showRecap = false

    var body: some View {
        let s = history.summary(range)

        VStack(spacing: 0) {
            HeaderBar(section: "Stats")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Caps(s.subtitle)
                            Text(s.title)
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(Theme.text)
                        }
                        PillNav(options: StatsRange.allCases, selection: $range) { $0.rawValue }
                        InfoRow(items: [
                            InfoItem(label: "Focused", value: hours(s.focusedHours)),
                            InfoItem(label: "Steps done", value: "\(s.stepsDone)"),
                            InfoItem(label: "Streak", value: "\(s.streak) day\(s.streak == 1 ? "" : "s")"),
                        ])
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.bg)

                    VStack(spacing: 12) {
                        HeatmapCard()
                        GoodDayCard()
                        if s.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Caps("No history yet")
                                Text("Stats fill in as you use Hyperday. To preview the look now: Settings › Load sample data.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.muted)
                            }
                            .cardBox()
                        }
                        categoryCard(s)
                        meetingCard(s)
                        blocksCard(s)
                        if !s.isEmpty {
                            Button("See weekly recap") { showRecap = true }
                                .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
            .background(Theme.section)
        }
        .task { await LiveActivityManager.shared.refresh() }
        .fullScreenCover(isPresented: $showRecap) { WeeklyRecapView() }   // records today before showing numbers
    }

    private func hours(_ h: Double) -> String {
        h >= 10 ? "\(Int(h.rounded()))h" : (h * 3600).hoursMinutes
    }

    private func categoryCard(_ s: StatsSummary) -> some View {
        let maxHours = max(s.byCategory.map(\.hours).max() ?? 1, 0.1)
        return VStack(alignment: .leading, spacing: 11) {
            Caps("Hours by category")
            if s.byCategory.isEmpty {
                Text("—").foregroundStyle(Theme.faint)
            }
            ForEach(s.byCategory) { c in
                HStack(spacing: 10) {
                    Text(c.name)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.text)
                        .frame(width: 84, alignment: .leading)
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(Theme.section)
                            RoundedRectangle(cornerRadius: 2).fill(c.color)
                                .frame(width: geo.size.width * c.hours / maxHours)
                        }
                    }
                    .frame(height: 8)
                    Text(String(format: c.hours >= 10 ? "%.0fh" : "%.1fh", c.hours))
                        .font(.system(size: 13).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .cardBox()
    }

    private func meetingCard(_ s: StatsSummary) -> some View {
        let total = max(s.meetingHours + s.planHours, 0.01)
        let meetingsColor = categories.category(id: "meetings")?.color ?? Theme.blue
        return VStack(alignment: .leading, spacing: 10) {
            Caps("Meeting load")
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(meetingsColor).frame(width: geo.size.width * s.meetingHours / total)
                    Rectangle().fill(Theme.section)
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            HStack {
                (Text(hours(s.meetingHours)).bold().foregroundColor(Theme.text) + Text(" meetings"))
                Spacer()
                (Text(hours(s.planHours)).bold().foregroundColor(Theme.text) + Text(" your plan"))
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)
        }
        .cardBox()
    }

    private func blocksCard(_ s: StatsSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Caps("Blocks")
            HStack(alignment: .top, spacing: 12) {
                stat("\(s.blocksDone)", "Done")
                stat("\(s.endedEarly)", "Ended early")
                stat("\(s.missed)", "Missed")
            }
        }
        .cardBox()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 22, weight: .semibold)).foregroundStyle(Theme.text)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
