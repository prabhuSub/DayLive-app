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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top row (like Tesla's card): [app icon] 26:10 left ······ Next: Standup 10:30 PM
            HStack(spacing: 7) {
                AppMark(size: 20)
                if let end = state.currentEnd, end > Date.now {
                    HStack(spacing: 3) {
                        Text(timerInterval: Date.now...end, countsDown: true)
                            .monospacedDigit()
                            .frame(maxWidth: 52, alignment: .leading)
                        Text("left")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .fixedSize()
                }
                Spacer(minLength: 6)
                Text(nextText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.title)
                        .font(.system(size: 23, weight: .bold))
                        .lineLimit(1)
                    if let also = state.also {
                        if state.alsoIsStep == true {
                            // Next step: grey pill, white text
                            Text(also)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(white: 0.45).opacity(0.55), in: Capsule())
                        } else {
                            Text(also)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                SourceIcon(source: state.source, size: 44, tint: state.source == .free ? nil : state.accentColor)
            }
            .padding(.top, 2)

            HStack(spacing: 12) {
                SegmentBar(segments: state.segments, accent: state.accentColor, height: 6)
                BlockActionButton(state: state)   // Step n/N is always yellow, never the category color
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

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(tint ?? background)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .accessibilityLabel(label)
    }

    private var symbol: String {
        switch source {
        case .calendar: return "calendar"
        case .plan:     return "pencil"
        case .free:     return "clock"
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

struct BlockActionButton: View {
    let state: DayActivityAttributes.ContentState

    var body: some View {
        if let id = state.actionBlockID, let action = state.action {
            Button(intent: BlockActionIntent(blockID: id, action: action)) {
                HStack(spacing: 5) {
                    Image(systemName: buttonSymbol(action))
                        .foregroundStyle(action == .checkStep ? Color(white: 0.3) : Color.white)
                    Text(buttonTitle(action))
                        .foregroundStyle(action == .checkStep ? Color.black : Color.white)
                }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(action == .checkStep ? AnyShapeStyle(DayLiveStyle.stepYellow)
                                                     : AnyShapeStyle(Color.white.opacity(0.22)),
                                in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
    }

    private func buttonTitle(_ action: BlockAction) -> String {
        switch action {
        case .done:      return "Done"
        case .startNext: return "Start next"
        case .checkStep: return "Step \((state.stepsDone ?? 0) + 1)/\(state.stepsTotal ?? 0)"
        }
    }

    private func buttonSymbol(_ action: BlockAction) -> String {
        switch action {
        case .done:      return "checkmark"
        case .startNext: return "forward.fill"
        case .checkStep: return "checkmark.circle"
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
                if let end = state.currentEnd, end > Date.now {
                    Text(timerInterval: Date.now...end, countsDown: true)
                        .monospacedDigit()
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: 46, alignment: .leading)
                }
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
                SegmentBar(segments: state.segments, accent: state.accentColor, height: 4)
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
        switch family {
        case .small: WatchCard(state: state, isStale: isStale)
        default: LockScreenCard(state: state, isStale: isStale)
        }
    }
}
