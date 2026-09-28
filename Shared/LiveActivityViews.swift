import AppIntents
import SwiftUI

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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(isStale ? "Out of date · tap to refresh" : state.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .lineLimit(1)
                    Text(state.title)
                        .font(.system(size: 23, weight: .bold))
                        .lineLimit(1)
                    if let also = state.also {
                        Text(also)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                SourceIcon(source: state.source, size: 44, tint: state.source == .free ? nil : state.accentColor)
            }
            HStack(spacing: 12) {
                SegmentBar(segments: state.segments, accent: state.accentColor, height: 6)
                BlockActionButton(state: state)
            }
            .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .padding(.leading, 16)
        .padding(.trailing, 14)
        .padding(.vertical, 14)
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
                        .foregroundStyle(action == .checkStep ? Color(white: 0.62) : Color.white)
                    Text(buttonTitle(action))
                        .foregroundStyle(action == .checkStep ? DayLiveStyle.stepYellow : Color.white)
                }
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.white.opacity(0.22), in: Capsule())
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
