import ActivityKit
import SwiftUI
import WidgetKit

@main
struct DayLiveWidgetBundle: WidgetBundle {
    var body: some Widget {
        DayLiveActivityWidget()
    }
}

struct DayLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DayActivityAttributes.self) { context in
            // Lock Screen / banner
            LockScreenCard(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(DayLiveStyle.cardTint.opacity(DayLiveStyle.glassOpacity))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SourceIcon(source: context.state.source, size: 34)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimeLeft(end: context.state.currentEnd)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.title)
                            .font(.headline)
                            .lineLimit(1)
                        if let also = context.state.also {
                            Text(also)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        SegmentBar(segments: context.state.segments)
                        BlockActionButton(state: context.state)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                SourceIcon(source: context.state.source, size: 22)
            } compactTrailing: {
                DayRing(progress: context.state.dayProgress)
                    .frame(width: 20, height: 20)
            } minimal: {
                DayRing(progress: context.state.dayProgress)
                    .frame(width: 20, height: 20)
            }
            .keylineTint(DayLiveStyle.accent)
        }
    }
}
