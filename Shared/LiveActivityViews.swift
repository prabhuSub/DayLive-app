import AppIntents
import SwiftUI
import WidgetKit

/// Shared by the widget extension (real Live Activity) and the app (preview card).
enum DayLiveStyle {
    static let accent = Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255)      // #34c759
    static let cardTint = Color(red: 40 / 255, green: 44 / 255, blue: 66 / 255)
    static let glassOpacity = 0.42
    static let calendarBlue = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    static let planGreen = Color(red: 36 / 255, green: 138 / 255, blue: 61 / 255)
    static let stepYellow = Color(red: 255 / 255, green: 214 / 255, blue: 10 / 255)   // #FFD60A
    static let doneGreen = Color(red: 48 / 255, green: 209 / 255, blue: 88 / 255)     // #30D158
}

extension Color {
    /// "#30D158" -> Color
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255,
                  opacity: 1)
    }
}

extension DayActivityAttributes.ContentState {
    /// Category color of the live block (bar + icon); green when nothing is live.
    var accentColor: Color { accentHex.map { Color(hex: $0) } ?? DayLiveStyle.accent }
}

// MARK: - Lock Screen card

struct LockScreenCard: View {
    let state: DayActivityAttributes.ContentState
    var isStale: Bool = false

    /// "Next · Standup at 10:30 PM" -> "Next: Standup 10:30 PM" (fits the top row)
    private var nextText: String {
        if isStale { return "Out of date · tap to refresh" }
        return state.label
            .replacingOccurrences(of: "Next · ", with: "Next: ")
            .replacingOccurrences(of: " at ", with: " ")
    }

    /// "Standup 10:30 AM" from the label "Next · Standup at 10:30 AM".
    private var nextParts: (title: String, time: String)? {
        guard state.label.hasPrefix("Next · "), let r = state.label.range(of: " at ", options: .backwards) else { return nil }
        let title = state.label[state.label.index(state.label.startIndex, offsetBy: 7)..<r.lowerBound]
        return (String(title), String(state.label[r.upperBound...]))
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(white: 0.45).opacity(0.55), in: Capsule())
    }

    /// v13: under the title. Step → [step pill][Next 3:00 pill]; overlap → "also:" text;
    /// otherwise → [Next: Title · 3:00 PM] pill. Free time keeps its own line.
    @ViewBuilder
    private var secondLine: some View {
        if state.alsoIsStep == true, let also = state.also {
            HStack(spacing: 6) {
                pill(also)
                if let n = nextParts { pill("Next \(n.time)").fixedSize() }
            }
        } else if let also = state.also, state.source == .free || also.hasPrefix("also:") {
            Text(also)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        } else if let n = nextParts {
            pill("Next: \(n.title) · \(n.time)")
        } else if let also = state.also {
            Text(also)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top row (like Tesla's card): [app icon] 26:10 left ······ Next: Standup 10:30 PM
            HStack(spacing: 7) {
                AppMark(size: 20)
                TimerLabel(state: state, size: 16)
                    .foregroundStyle(.white)
                    .fixedSize()
                Spacer(minLength: 6)
                if isStale {
                    Text(nextText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    CardTitle(state: state, size: 23)
                    secondLine
                }
                Spacer(minLength: 0)
                SourceIcon(source: state.source, size: 44, tint: state.source == .free ? nil : state.accentColor, iconName: state.iconName)
            }
            .padding(.top, 2)

            HStack(spacing: 12) {
                DayBar(state: state, height: 6)
                BlockActionButton(state: state)   // Done / Step n/N are always yellow, never the category color
            }
            .padding(.top, 6)
        }
        .foregroundStyle(.white)
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 13)
    }
}

/// Small Hyperday app icon (asset "HyperdayMark"), like the Tesla logo on Tesla's card.
struct AppMark: View {
    var size: CGFloat = 20

    var body: some View {
        Image("HyperdayMark")
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityLabel("Hyperday")
    }
}

// MARK: - Pieces

struct SourceIcon: View {
    let source: BlockSource
    var size: CGFloat = 40
    var tint: Color? = nil   // category color; overrides the source color
    var iconName: String? = nil   // category icon; overrides the source icon

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint ?? background)
            .frame(width: size, height: size)
            .overlay(
                HDIcon(iconName ?? symbol, size: size * 0.56)
                    .foregroundStyle(.white)
            )
            .accessibilityLabel(label)
    }

    private var symbol: String {
        switch source {
        case .calendar: return "event"
        case .plan:     return "edit"
        case .free:     return "free"
        }
    }

    private var background: Color {
        switch source {
        case .calendar: return DayLiveStyle.calendarBlue
        case .plan:     return DayLiveStyle.planGreen
        case .free:     return .white.opacity(0.22)
        }
    }

    private var label: String {
        switch source {
        case .calendar: return "Calendar event"
        case .plan:     return "My plan"
        case .free:     return "Free time"
        }
    }
}

struct SegmentBar: View {
    let segments: [Double]
    var accent: Color = DayLiveStyle.accent
    var height: CGFloat = 5

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(.white.opacity(0.28))
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(accent)
                                .frame(width: geo.size.width * min(max(value, 0), 1))
                        }
                    }
                    .frame(height: height)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct DayRing: View {
    let progress: Double
    var accent: Color = DayLiveStyle.accent

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.22), lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(1.5)
        .accessibilityLabel("Day \(Int(progress * 100)) percent complete")
    }
}

struct TimeLeft: View {
    let end: Date?
    var accent: Color = DayLiveStyle.accent

    var body: some View {
        if let end, end > Date.now {
            Text(timerInterval: Date.now...end, countsDown: true)
                .monospacedDigit()
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
        }
    }
}

/// The big title. In free time it's a green "Free" pill.
struct CardTitle: View {
    let state: DayActivityAttributes.ContentState
    var size: CGFloat = 23

    var body: some View {
        if state.source == .free && state.nextStart != nil {
            Text(state.title)
                .font(.system(size: size * 0.8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, size * 0.55)
                .padding(.vertical, size * 0.14)
                .background(DayLiveStyle.doneGreen, in: Capsule())
        } else {
            Text(state.title)
                .font(.system(size: size, weight: .bold))
                .lineLimit(1)
        }
    }
}

/// "1:26:10 left" · "+4:12 over" · "1:40:05 until Standup". Ticks on its own on the Lock Screen.
struct TimerLabel: View {
    let state: DayActivityAttributes.ContentState
    var size: CGFloat = 14

    /// Live timer text stretches to fill its box, so size the box with an invisible sample
    /// ("8:88:88" or "88:88") in the same font, and lay the timer over it.
    private func timer(_ range: ClosedRange<Date>, down: Bool) -> some View {
        let long = abs(range.upperBound.timeIntervalSince(range.lowerBound)) >= 3600 || !down
        return Text(long ? "8:88:88" : "88:88")
            .hidden()
            .overlay(alignment: .leading) {
                Text(timerInterval: range, countsDown: down)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
    }

    var body: some View {
        Group {
            if let over = state.overSince {
                HStack(spacing: 0) {
                    Text("+")
                    timer(over...over.addingTimeInterval(24 * 3600), down: false)
                    Text(" over")
                }
            } else if let end = state.currentEnd, end > Date.now {
                HStack(spacing: 4) {
                    timer(Date.now...end, down: true)
                    Text("left")
                }
            } else if let next = state.nextStart, next > Date.now {
                HStack(spacing: 4) {
                    timer(Date.now...next, down: true)
                    Text("until \(state.nextTitle ?? "next")")
                        .lineLimit(1)
                }
            }
        }
        .font(.system(size: size, weight: .bold).monospacedDigit())
        .lineLimit(1)
    }
}

/// The bar under the title: steps or day segments while a block is on, one filling bar in free time,
/// a full yellow bar in overtime.
struct DayBar: View {
    let state: DayActivityAttributes.ContentState
    var height: CGFloat = 6

    var body: some View {
        if state.overSince != nil {
            Capsule().fill(DayLiveStyle.stepYellow).frame(height: height).frame(maxWidth: .infinity)
        } else if let from = state.freeStart, let to = state.nextStart, from < to {
            ProgressView(timerInterval: from...to, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(.white)
            .frame(maxWidth: .infinity)
        } else {
            SegmentBar(segments: state.segments, accent: state.accentColor, height: height)
        }
    }
}

struct BlockActionButton: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        if let id = state.actionBlockID, let action = state.action {
            Button(intent: BlockActionIntent(blockID: id, action: action)) {
                // Done is always green, Step is yellow, "Start now" in free time stays grey.
                let fill: Color = action == .done ? DayLiveStyle.doneGreen
                    : action == .checkStep ? DayLiveStyle.stepYellow : Color.white.opacity(0.22)
                let ink: Color = action == .checkStep ? .black : .white
                HStack(spacing: 5) {
                    HDIcon(buttonSymbol(action), size: 15)
                        .foregroundStyle(action == .checkStep ? Color(white: 0.3) : Color.white)
                    Text(buttonTitle(action))
                        .foregroundStyle(ink)
                }
                    .font(.system(size: 14, weight: action == .startNext ? .semibold : .bold))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(fill, in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
    }

    private func buttonTitle(_ action: BlockAction) -> String {
        switch action {
        case .done:      return "Done"
        case .startNext: return "Start now"
        case .checkStep: return "Step \((state.stepsDone ?? 0) + 1)/\(state.stepsTotal ?? 0)"
        }
    }

    private func buttonSymbol(_ action: BlockAction) -> String {
        switch action {
        case .done:      return "done"
        case .startNext: return "start"
        case .checkStep: return "step-done"
        }
    }
}

/// Apple Watch Smart Stack (and CarPlay) version of the card: [mark] 26:10 · Next 10:30, title, bar + button.
struct WatchCard: View {
    let state: DayActivityAttributes.ContentState
    var isStale: Bool = false

    private var nextTime: String? {
        guard !isStale, let r = state.label.range(of: " at ") else { return nil }
        return "Next " + state.label[r.upperBound...]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                AppMark(size: 14)
                TimerLabel(state: state, size: 13)
                Spacer(minLength: 2)
                if let nextTime {
                    Text(nextTime)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Text(state.title)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
            HStack(spacing: 6) {
                DayBar(state: state, height: 4)
                BlockActionButton(state: state)
                    .scaleEffect(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

/// Picks the iPhone Lock Screen card or the compact Watch card.
struct ActivityFamilyCard: View {
    @Environment(\.activityFamily) private var family
    let state: DayActivityAttributes.ContentState
    var isStale: Bool = false

    var body: some View {
        if state.closed == true {
            DayClosedCard(state: state, compact: family == .small)
        } else if state.driving == true && family != .small {
            DriveCard(state: state)
        } else {
            switch family {
            case .small: WatchCard(state: state, isStale: isStale)
            default: LockScreenCard(state: state, isStale: isStale)
            }
        }
    }
}

// MARK: - Day Close (v9)

/// After your close time: done today, a Review link, and tomorrow's pre-flight.
struct DayClosedCard: View {
    let state: DayActivityAttributes.ContentState
    var compact = false   // Dynamic Island / Watch

    private var done: Int { state.doneCount ?? 0 }
    private var total: Int { max(state.totalCount ?? 0, done) }

    private func time(_ d: Date?) -> String {
        d.map { $0.formatted(date: .omitted, time: .shortened) } ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 6) {
            if !compact {
                HStack(spacing: 7) {
                    AppMark(size: 20)
                    Text("Day closed").font(.system(size: 14, weight: .bold))
                    Spacer(minLength: 4)
                    Text(Date.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            HStack(alignment: .center, spacing: 10) {
                (Text("\(done)").foregroundColor(DayLiveStyle.doneGreen) + Text(" of \(total) done"))
                    .font(.system(size: compact ? 19 : 22, weight: .heavy))
                    .lineLimit(1)
                Spacer(minLength: 4)
                if let n = state.reviewCount, n > 0, let url = URL(string: "hyperday://close") {
                    Link(destination: url) {
                        Text("Review \(n)")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(Color.white.opacity(0.2), in: Capsule())
                    }
                } else {
                    HStack(spacing: 4) {
                        HDIcon("done", size: 13)
                        Text("Closed")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DayLiveStyle.doneGreen)
                }
            }
            if total > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<min(total, 16), id: \.self) { i in
                        Capsule()
                            .fill(i < done ? DayLiveStyle.doneGreen : DayLiveStyle.stepYellow)
                            .frame(height: 5)
                    }
                }
            }
            Rectangle().fill(.white.opacity(0.15)).frame(height: 1).padding(.vertical, 1)
            if let first = state.tomorrowFirst {
                HStack(alignment: .top, spacing: 8) {
                    stat("Tomorrow", time(first), .white)
                    if state.leaveBy != nil { stat("Leave by", time(state.leaveBy), .white) }
                    stat("Bed by", time(state.bedBy),
                         (state.bedBy ?? .distantFuture) > .now ? DayLiveStyle.doneGreen : Color(red: 1, green: 0.27, blue: 0.23))
                }
                if !compact, let title = state.tomorrowTitle {
                    Text("First up: \(title)")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            } else {
                Text("Nothing planned tomorrow")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 16)
        .padding(.vertical, compact ? 4 : 12)
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: compact ? 14 : 16, weight: .heavy).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Drive card (#9)

struct DriveCard: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        let spare = state.spareMinutes
        let late = (spare ?? 0) < 0
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                AppMark(size: 20)
                if let a = state.arriveAt {
                    Text("Arrive \(a.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 16, weight: .heavy))
                } else {
                    Text("Driving").font(.system(size: 16, weight: .heavy))
                }
                Spacer(minLength: 4)
                if let since = state.driveSince {
                    HStack(spacing: 3) {
                        Text("Driving ·")
                        Text(timerInterval: since...since.addingTimeInterval(6 * 3600), countsDown: false)
                            .monospacedDigit()
                            .frame(width: 48, alignment: .leading)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                }
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title).font(.system(size: 21, weight: .bold)).lineLimit(1)
                    if let spare {
                        Text(late ? "\(-spare) min late" : "\(spare) min to spare")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(late ? Color(red: 1, green: 0.27, blue: 0.23) : DayLiveStyle.doneGreen)
                    }
                }
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DayLiveStyle.calendarBlue)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "car.fill").font(.system(size: 20)).foregroundStyle(.white))
            }
            if let since = state.driveSince, let a = state.arriveAt, a > since {
                ProgressView(timerInterval: since...a, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(DayLiveStyle.calendarBlue)
                    .padding(.top, 4)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
