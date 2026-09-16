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
                        endsAt: context.state.endsAt
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
                        GameLiveActivityStatusCaption(
                            startsAt: context.state.startsAt,
                            endsAt: context.state.endsAt
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
                    endsAt: context.state.endsAt
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
    let endsAt: Date

    @ViewBuilder
    var body: some View {
        let now = Date.now
        switch GameLiveActivityPresentation.phase(startsAt: startsAt, endsAt: endsAt, now: now) {
        case .preSession:
            Text(
                timerInterval: GameLiveActivityPresentation.countdownInterval(
                    startsAt: startsAt,
                    now: now
                ),
                pauseTime: startsAt,
                countsDown: true
            )
        case .live:
            Text("LIVE")
        case .ended:
            Text("ENDED")
        }
    }
}

private struct GameLiveActivityStatusCaption: View {
    let startsAt: Date
    let endsAt: Date

    var body: some View {
        switch GameLiveActivityPresentation.phase(startsAt: startsAt, endsAt: endsAt) {
        case .preSession:
            Text("Starts in")
        case .live:
            Text("In progress")
        case .ended:
            Text("Ended")
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

    private var phase: GameLiveActivityPresentation.Phase {
        GameLiveActivityPresentation.phase(
            startsAt: context.state.startsAt,
            endsAt: context.state.endsAt
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
                    endsAt: context.state.endsAt
                )
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(LiveActivityTheme.gold)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.8)
                Text(statusCaption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusCaption: String {
        switch phase {
        case .preSession: return "Starts in"
        case .live: return "In progress"
        case .ended: return "Ended"
        }
    }
}
