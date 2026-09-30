import SwiftUI
import WidgetKit

// GitHub-style "blocks done" heatmap widgets: Small (7 weeks), Medium (5 months),
// Large (12 months in two rows), Lock Screen rectangular (16 weeks, white).

struct HeatEntry: TimelineEntry {
    let date: Date
    let data: HeatData?
}

struct HeatProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeatEntry { HeatEntry(date: .now, data: .sample) }

    func getSnapshot(in context: Context, completion: @escaping (HeatEntry) -> Void) {
        completion(HeatEntry(date: .now, data: WidgetShared.loadHeat() ?? (context.isPreview ? .sample : nil)))
    }

    /// The app reloads this when a block is done; otherwise refresh just after midnight for the new day.
    func getTimeline(in context: Context, completion: @escaping (Timeline<HeatEntry>) -> Void) {
        let cal = Calendar.current
        let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now))?.addingTimeInterval(60) ?? .now
        completion(Timeline(entries: [HeatEntry(date: .now, data: WidgetShared.loadHeat())], policy: .after(midnight)))
    }
}

struct HyperdayHeatWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.heatKind, provider: HeatProvider()) { entry in
            HeatWidgetView(entry: entry)
        }
        .configurationDisplayName("Blocks done")
        .description("Your GitHub-style grid of blocks done each day, with your streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct HeatWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HeatEntry

    var body: some View {
        let data = entry.data ?? HeatData(counts: [:])
        Group {
            switch family {
            case .accessoryRectangular: lock(data)
            case .systemMedium: medium(data)
            case .systemLarge: large(data)
            default: small(data)
            }
        }
        .containerBackground(for: .widget) {
            if family == .accessoryRectangular { AccessoryWidgetBackground() } else { Color(UIColor.systemBackground) }
        }
    }

    private func caps(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 9, weight: .bold))
            .kerning(1.1)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func small(_ d: HeatData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                caps("Streak")
                Spacer()
                Text("\(d.streak()) days")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: "#1F8A3B"))
            }
            Spacer(minLength: 0)
            HeatGrid(data: d, weeks: 7, cell: 13, gap: 3, showMonths: false, now: entry.date)
            Spacer(minLength: 0)
        }
    }

    private func medium(_ d: HeatData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                caps("Blocks done · 5 months")
                Spacer()
                Text("\(d.streak())-day streak")
                    .font(.system(size: 11, weight: .semibold))
            }
            HeatGrid(data: d, weeks: 22, cell: 10.5, gap: 3, now: entry.date)
            Spacer(minLength: 0)
        }
    }

    private func large(_ d: HeatData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                caps("Blocks done · 12 months")
                Spacer()
                Text("\(d.total()) total").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HeatGrid(data: d, weeks: 27, endWeekOffset: 26, cell: 8.5, gap: 2.5, now: entry.date)
            HeatGrid(data: d, weeks: 26, cell: 8.5, gap: 2.5, now: entry.date)
            Spacer(minLength: 0)
            Divider()
            HStack {
                stat("Streak", "\(d.streak())d")
                stat("Best", "\(d.best())d")
                stat("This week", "\(d.thisWeek())")
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            caps(label)
            Text(value).font(.system(size: 20, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lock(_ d: HeatData) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(d.streak())-DAY STREAK")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            HeatGrid(data: d, weeks: 16, cell: 5.6, gap: 1.8, style: .white, showMonths: false, now: entry.date)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetAccentable()
    }
}
