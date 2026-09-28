import SwiftUI

/// Calendar tab: every calendar on the phone + your Hyperday tasks. Agenda (week) and Month.
struct CalendarTabView: View {
    enum Mode: String, CaseIterable, Hashable { case agenda = "Agenda", week = "Week", month = "Month" }

    @EnvironmentObject private var store: BlockStore
    @EnvironmentObject private var categories: CategoryStore

    @State private var mode: Mode = .agenda
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var showTasks = true
    @State private var showDeclined = false
    @State private var editing: Block?

    private let cal = Calendar.current

    var body: some View {
        let range = visibleRange
        let byDay = items(in: range)

        VStack(spacing: 0) {
            HeaderBar(section: "Calendar")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 14) {
                        titleRow
                        PillNav(options: Mode.allCases, selection: $mode) { $0.rawValue }
                        if mode == .month {
                            monthGrid(byDay: byDay)
                        } else {
                            weekStrip(byDay: byDay)
                                .padding(.leading, mode == .week ? WeekGrid.labelWidth : 0)
                        }
                        filters
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.bg)

                    VStack(alignment: .leading, spacing: 10) {
                        if !CalendarService.shared.hasAccess {
                            Text("Calendar access is off. Turn it on in Settings › Hyperday › Calendars.")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.muted)
                        }
                        if mode == .agenda {
                            ForEach(weekDays, id: \.self) { day in
                                daySection(day, items: byDay[day] ?? [])
                            }
                        } else if mode == .week {
                            WeekGrid(days: weekDays, byDay: byDay,
                                     color: { categories.displayColor(for: $0) },
                                     onTap: { editing = $0 })
                                .padding(.vertical, 12)
                                .padding(.trailing, 8)
                                .cardBox(padding: 0)
                        } else {
                            daySection(selected, items: byDay[selected] ?? [])
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Theme.section)
        }
        .sheet(item: $editing) { block in
            BlockEditorSheet(
                block: block,
                steps: store.steps(for: block.id),
                categoryOverride: store.categoryOverrides[block.id]
            ) {
                store.delete(id: block.id)
                Task { await LiveActivityManager.shared.refresh() }
            }
            .presentationDetents([.large])
        }
    }

    // MARK: Data

    private var weekDays: [Date] {
        let start = cal.dateInterval(of: .weekOfYear, for: selected)?.start ?? selected
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var monthDays: [Date?] {
        guard let month = cal.dateInterval(of: .month, for: selected) else { return [] }
        let first = month.start
        let lead = (cal.component(.weekday, from: first) - cal.firstWeekday + 7) % 7
        let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        var cells: [Date?] = Array(repeating: nil, count: lead)
        for i in 0..<count { cells.append(cal.date(byAdding: .day, value: i, to: first)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var visibleRange: DateInterval {
        if mode != .month {
            let start = weekDays.first ?? selected
            return DateInterval(start: start, end: cal.date(byAdding: .day, value: 7, to: start) ?? start)
        }
        return cal.dateInterval(of: .month, for: selected) ?? DateInterval(start: selected, duration: 86400 * 31)
    }

    /// Calendar events + (optionally) planned tasks, grouped by day start.
    private func items(in range: DateInterval) -> [Date: [Block]] {
        var list = CalendarService.shared.events(from: range.start, to: range.end, includeDeclined: showDeclined)
        if showTasks {
            let tasks = store.planBlocks.filter { $0.start >= range.start && $0.start < range.end }
            list += DayEngine.apply(store.overrides, to: tasks)
        }
        return Dictionary(grouping: list.sorted { $0.start < $1.start }) { cal.startOfDay(for: $0.start) }
    }

    // MARK: Header

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleText)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.text)
            Spacer()
            HStack(spacing: 4) {
                navButton("chevron.left") { shift(-1) }
                Button("Today") { selected = cal.startOfDay(for: .now) }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                navButton("chevron.right") { shift(1) }
            }
        }
    }

    private var titleText: String {
        switch mode {
        case .agenda:
            return selected.formatted(Date.FormatStyle().month(.wide))
        case .week:
            let days = weekDays
            guard let first = days.first, let last = days.last else { return "" }
            let f = Date.FormatStyle().month(.abbreviated).day()
            return "\(first.formatted(f)) – \(last.formatted(f))"
        case .month:
            return selected.formatted(Date.FormatStyle().month(.wide).year())
        }
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shift(_ direction: Int) {
        let next = mode != .month
            ? cal.date(byAdding: .day, value: 7 * direction, to: selected)
            : cal.date(byAdding: .month, value: direction, to: selected)
        if let next { selected = cal.startOfDay(for: next) }
    }

    // MARK: Week strip

    private func weekStrip(byDay: [Date: [Block]]) -> some View {
        HStack(spacing: 2) {
            ForEach(weekDays, id: \.self) { day in
                Button { selected = day } label: {
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.muted)
                        dayNumber(day, size: 34)
                        dots(byDay[day] ?? [], faded: false)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Month grid

    private func monthGrid(byDay: [Date: [Block]]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let ordered = Array(symbols[(cal.firstWeekday - 1)...] + symbols[..<(cal.firstWeekday - 1)])
        let today = cal.startOfDay(for: .now)

        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, s in
                    Text(s)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        Button { selected = day } label: {
                            VStack(spacing: 3) {
                                dayNumber(day, size: 28, dimPast: true)
                                dots(byDay[day] ?? [], faded: day < today)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 54)
                    }
                }
            }
        }
    }

    // MARK: Pieces

    private func dayNumber(_ day: Date, size: CGFloat, dimPast: Bool = false) -> some View {
        let isToday = cal.isDateInToday(day)
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let past = day < cal.startOfDay(for: .now)
        return Text(day.formatted(.dateTime.day()))
            .font(.system(size: size > 30 ? 16 : 14, weight: isToday ? .bold : .medium))
            .foregroundStyle(isToday ? Theme.bg : (dimPast && past ? Theme.faint : Theme.text))
            .frame(width: size, height: size)
            .background(Circle().fill(isToday ? Theme.text : Color.clear))
            .overlay(Circle().stroke(isSelected && !isToday ? Theme.text : Color.clear, lineWidth: 1.5))
    }

    private func dots(_ items: [Block], faded: Bool) -> some View {
        let colors = Array(items.prefix(3)).map { categories.displayColor(for: $0) }
        return HStack(spacing: 3) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                Circle().fill(c).frame(width: 5, height: 5).opacity(faded ? 0.45 : 1)
            }
        }
        .frame(height: 5)
    }

    private var filters: some View {
        FlowLayout(spacing: 8) {
            Chip(title: "All calendars", selected: true)
            Chip(title: "Tasks", color: DayLiveStyle.accent, selected: showTasks) { showTasks.toggle() }
            Chip(title: "Declined", selected: showDeclined) { showDeclined.toggle() }
        }
    }

    private func sectionTitle(_ day: Date) -> String {
        let date = day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        if cal.isDateInToday(day) { return "Today · \(date)" }
        if cal.isDateInYesterday(day) { return "Yesterday · \(date)" }
        if cal.isDateInTomorrow(day) { return "Tomorrow · \(date)" }
        return date
    }

    private func daySection(_ day: Date, items: [Block]) -> some View {
        let now = Date.now
        return VStack(alignment: .leading, spacing: 8) {
            Caps("\(sectionTitle(day)) · \(items.count) item\(items.count == 1 ? "" : "s")")
                .padding(.top, 6)
            VStack(spacing: 0) {
                if items.isEmpty {
                    Text("Nothing scheduled")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.faint)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, block in
                    if index > 0 { Rectangle().fill(Theme.border).frame(height: 1) }
                    Button { editing = block } label: {
                        BlockRow(block: block, now: now,
                                 color: categories.displayColor(for: block),
                                 steps: store.steps(for: block.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardBox(padding: 0)
        }
    }
}

// MARK: - Week grid

/// 7 day columns on an hour grid. Overlapping events split their column side by side.
struct WeekGrid: View {
    static let labelWidth: CGFloat = 30
    let days: [Date]
    let byDay: [Date: [Block]]
    let color: (Block) -> Color
    let onTap: (Block) -> Void

    private let hourHeight: CGFloat = 44

    struct Placed {
        let block: Block
        let col: Int
        let cols: Int
    }

    /// Greedy columns inside each cluster of overlapping events.
    static func layout(_ items: [Block]) -> [Placed] {
        var result: [Placed] = []
        var cluster: [(Block, Int)] = []
        var columnEnds: [Date] = []
        var clusterEnd = Date.distantPast

        func flush() {
            let n = (cluster.map { $0.1 }.max() ?? 0) + 1
            result += cluster.map { Placed(block: $0.0, col: $0.1, cols: n) }
            cluster = []
            columnEnds = []
        }

        for b in items.sorted(by: { $0.start < $1.start }) {
            if !cluster.isEmpty && b.start >= clusterEnd { flush() }
            if let i = columnEnds.firstIndex(where: { $0 <= b.start }) {
                columnEnds[i] = b.end
                cluster.append((b, i))
            } else {
                columnEnds.append(b.end)
                cluster.append((b, columnEnds.count - 1))
            }
            clusterEnd = max(clusterEnd, b.end)
        }
        if !cluster.isEmpty { flush() }
        return result
    }

    var body: some View {
        let cal = Calendar.current
        let all = days.flatMap { byDay[$0] ?? [] }
        let earliest = all.map { cal.component(.hour, from: $0.start) }.min() ?? 7
        let latest = all.map { cal.component(.hour, from: $0.end) + 1 }.max() ?? 22
        let startHour = min(7, earliest)
        let endHour = min(24, max(22, latest))
        let totalHeight = CGFloat(endHour - startHour) * hourHeight
        let now = Date.now

        GeometryReader { geo in
            let colW = max(1, (geo.size.width - Self.labelWidth) / 7)
            ZStack(alignment: .topLeading) {
                ForEach(startHour...endHour, id: \.self) { h in
                    let y = CGFloat(h - startHour) * hourHeight
                    Text(hourLabel(h))
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.faint)
                        .frame(width: Self.labelWidth - 6, alignment: .trailing)
                        .offset(y: y - 6)
                    Rectangle()
                        .fill(Theme.border)
                        .frame(width: geo.size.width - Self.labelWidth, height: 1)
                        .offset(x: Self.labelWidth, y: y)
                }
                ForEach(1..<7, id: \.self) { i in
                    Rectangle()
                        .fill(Theme.border.opacity(0.6))
                        .frame(width: 1, height: totalHeight)
                        .offset(x: Self.labelWidth + CGFloat(i) * colW)
                }
                ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, day in
                    ForEach(Self.layout(byDay[day] ?? []), id: \.block.id) { item in
                        eventCell(item, dayIndex: dayIndex, day: day, colW: colW,
                                  startHour: startHour, endHour: endHour, now: now)
                    }
                }
                if let todayIndex = days.firstIndex(where: { cal.isDateInToday($0) }) {
                    let minutes = now.timeIntervalSince(cal.startOfDay(for: now)) / 60
                    if minutes >= Double(startHour * 60) && minutes <= Double(endHour * 60) {
                        let y = CGFloat(minutes / 60 - Double(startHour)) * hourHeight
                        let x = Self.labelWidth + CGFloat(todayIndex) * colW
                        Rectangle().fill(Theme.red).frame(width: colW, height: 2).offset(x: x, y: y)
                        Circle().fill(Theme.red).frame(width: 7, height: 7).offset(x: x - 3.5, y: y - 2.5)
                    }
                }
            }
        }
        .frame(height: totalHeight + 8)
    }

    private func eventCell(_ item: Placed, dayIndex: Int, day: Date, colW: CGFloat,
                           startHour: Int, endHour: Int, now: Date) -> some View {
        let startMin: Double = max(Double(startHour * 60), item.block.start.timeIntervalSince(day) / 60)
        let endMin: Double = min(Double(endHour * 60), item.block.end.timeIntervalSince(day) / 60)
        let top: CGFloat = CGFloat(startMin / 60 - Double(startHour)) * hourHeight
        let height: CGFloat = max(14, CGFloat((endMin - startMin) / 60) * hourHeight - 2)
        let width: CGFloat = colW / CGFloat(item.cols)
        let x: CGFloat = Self.labelWidth + CGFloat(dayIndex) * colW + CGFloat(item.col) * width
        let past: Bool = item.block.end <= now
        let c: Color = color(item.block)
        let lines: Int = max(1, Int(height / 11))

        return Button { onTap(item.block) } label: {
            Text(item.block.title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(past ? Theme.faint : Theme.text)
                .lineLimit(lines)
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
                .frame(width: max(4, width - 3), height: height, alignment: .topLeading)
                .background(c.opacity(past ? 0.12 : 0.22))
                .overlay(alignment: .leading) {
                    Rectangle().fill(c.opacity(past ? 0.5 : 1)).frame(width: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .offset(x: x + 1, y: top + 1)
    }

    private func hourLabel(_ h: Int) -> String {
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return "\(hour12)\(h < 12 || h == 24 ? "a" : "p")"
    }
}
