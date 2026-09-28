import SwiftUI

/// Calendar tab: every calendar on the phone + your Hyperday tasks. Agenda (week) and Month.
struct CalendarTabView: View {
    enum Mode: String, CaseIterable, Hashable { case agenda = "Agenda", month = "Month" }

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
                        if mode == .agenda {
                            weekStrip(byDay: byDay)
                        } else {
                            monthGrid(byDay: byDay)
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
                        } else {
                            daySection(selected, items: byDay[selected] ?? [])
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 130)
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
        if mode == .agenda {
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
            Text(mode == .agenda
                 ? selected.formatted(Date.FormatStyle().month(.wide))
                 : selected.formatted(Date.FormatStyle().month(.wide).year()))
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
        let next = mode == .agenda
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
        let colors = Array(items.prefix(3)).map { categories.category(for: $0).color }
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
                                 color: categories.category(for: block).color,
                                 steps: store.steps(for: block.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardBox(padding: 0)
        }
    }
}
