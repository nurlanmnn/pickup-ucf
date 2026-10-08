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
                    VStack(alignment: .trailing, spacing: 2) {
                        GameLiveActivityTimerText(
                            startsAt: context.state.startsAt,
                            endsAt: context.state.endsAt
                        )
                            .font(.headline.weight(.semibold))
                            .frame(width: 76, alignment: .trailing)
                        GameLiveActivityStatusCaption(
                            startsAt: context.state.startsAt,
                            endsAt: context.state.endsAt
                        )
                            .font(.caption2)
                    }
                    .foregroundStyle(LiveActivityTheme.gold)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.sportName)
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Label(context.attributes.locationName, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.caption2.weight(.semibold))
                    .frame(width: 44, alignment: .trailing)
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
                countsDown: true,
                showsHours: false
            )
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

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
            .frame(width: 76, alignment: .trailing)
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
