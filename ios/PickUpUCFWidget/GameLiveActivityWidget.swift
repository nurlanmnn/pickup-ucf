import ActivityKit
import SwiftUI
import WidgetKit

private enum LiveActivityTheme {
    static let gold = Color(red: 1.0, green: 0.788, blue: 0.016)
    static let lockScreenBackground = Color(red: 0.07, green: 0.07, blue: 0.08)
}

struct GameLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GameLiveActivityAttributes.self) { context in
            GameLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(LiveActivityTheme.lockScreenBackground)
                .activitySystemActionForegroundColor(LiveActivityTheme.gold)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    GameLiveActivitySportGlyph(systemImage: context.attributes.sportSystemImage, size: 28)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    GameLiveActivityTimerText(
                        startsAt: context.state.startsAt,
                        isStale: context.isStale
                    )
                        .monospacedDigit()
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(LiveActivityTheme.gold)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.sportName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                        Text(context.attributes.locationName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(
                            GameLiveActivityPresentation.isLive(
                                startsAt: context.state.startsAt,
                                isStale: context.isStale
                            ) ? "Live" : "Starts in"
                        )
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(LiveActivityTheme.gold)
                    }
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                GameLiveActivitySportGlyph(systemImage: context.attributes.sportSystemImage, size: 16)
            } compactTrailing: {
                GameLiveActivityTimerText(
                    startsAt: context.state.startsAt,
                    isStale: context.isStale
                )
                    .monospacedDigit()
                    .foregroundStyle(LiveActivityTheme.gold)
                    .frame(maxWidth: 48)
            } minimal: {
                GameLiveActivitySportGlyph(systemImage: context.attributes.sportSystemImage, size: 14)
            }
            .keylineTint(LiveActivityTheme.gold)
        }
    }
}

private struct GameLiveActivityTimerText: View {
    let startsAt: Date
    let isStale: Bool

    @ViewBuilder
    var body: some View {
        let now = Date.now
        if GameLiveActivityPresentation.isLive(
            startsAt: startsAt,
            isStale: isStale,
            now: now
        ) {
            Text("LIVE")
        } else {
            Text(
                timerInterval: GameLiveActivityPresentation.countdownInterval(
                    startsAt: startsAt,
                    now: now
                ),
                pauseTime: startsAt,
                countsDown: true
            )
        }
    }
}

private struct GameLiveActivitySportGlyph: View {
    let systemImage: String
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(LiveActivityTheme.gold)
            .accessibilityHidden(true)
    }
}

private struct GameLiveActivityLockScreenView: View {
    let context: ActivityViewContext<GameLiveActivityAttributes>

    private var hasStarted: Bool {
        GameLiveActivityPresentation.isLive(
            startsAt: context.state.startsAt,
            isStale: context.isStale
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LiveActivityTheme.gold.opacity(0.18))
                    .frame(width: 44, height: 44)
                GameLiveActivitySportGlyph(
                    systemImage: context.attributes.sportSystemImage,
                    size: 20
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.sportName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.attributes.locationName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                GameLiveActivityTimerText(
                    startsAt: context.state.startsAt,
                    isStale: context.isStale
                )
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(LiveActivityTheme.gold)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.8)
                Text(hasStarted ? "In progress" : "Starts in")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
