import SwiftUI

struct SessionCard: View {
    let session: PickupSession
    var isJoining: Bool = false
    /// When set, replaces the default "Join" / "Waitlist" label (e.g. **Leave** on My Games).
    var actionTitle: String?
    var isDestructiveAction: Bool = false
    var onJoin: (() -> Void)?
    var onOpen: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let onOpen {
                Button(action: onOpen) { cardContent }
                    .buttonStyle(GameCardButtonStyle(sport: session.sport))
                    .accessibilityLabel("\(session.sportDisplayName) at \(session.locationName)")
                    .accessibilityValue("\(session.startsAt.formatted(date: .abbreviated, time: .shortened)), \(session.playerCount) of \(session.capacity) players, \(session.skillLevel.displayName) skill level")
                    .accessibilityHint("Opens game details")
                    .accessibilityIdentifier("session-open-\(session.id.uuidString)")
            } else {
                cardContent
                    .accessibilityElement(children: .combine)
            }
            if let onJoin {
                joinButton(action: onJoin)
                    .padding(.horizontal, Spacing.m)
                    .padding(.bottom, Spacing.m)
            }
        }
        .background(AppColor.elevatedSurface(colorScheme))
        .appCardStyle(cornerRadius: 20)
        .accessibilityElement(children: .contain)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CourtArtwork(sport: session.sport)
                    .frame(height: 128)
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    relativeBadge(at: context.date)
                }
                .padding(Spacing.m)
            }
            sessionDetails
                .padding(Spacing.m)
        }
        .contentShape(Rectangle())
    }

    private var sessionDetails: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(session.sportDisplayName)
                .font(AppFont.headline(.semibold))
                .foregroundStyle(AppColor.textPrimary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            // Location
            Label(session.locationName, systemImage: "mappin.and.ellipse")
                .font(AppFont.caption(.regular))
                .foregroundStyle(AppColor.textSecondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)

            // Time line
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(SessionDateFormatter.cardLabel(for: session.startsAt, relativeTo: context.date))
                    .font(AppFont.caption(.regular))
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
            }

            Spacer(minLength: Spacing.s)

            // Capacity indicator + skill pill
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s))
                : AnyLayout(HStackLayout(spacing: Spacing.s))
            layout {
                CapacityIndicator(
                    playerCount: session.playerCount,
                    capacity: session.capacity,
                    iconColor: AppColor.accent(colorScheme)
                )

                SkillPill(skill: session.skillLevel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Relative-time badge

    @ViewBuilder
    private func relativeBadge(at now: Date) -> some View {
        let seconds = session.startsAt.timeIntervalSince(now)
        if seconds > 0, seconds <= 7200 {
            let label = badgeLabel(seconds: seconds)
            let isSoon = seconds <= 900
            Text(label)
                .font(AppFont.caption2(.bold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(isSoon ? Color.white : AppTheme.badgeGoldText)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isSoon ? AppTheme.badgeSoon(colorScheme) : AppTheme.badgeGold)
                .clipShape(Capsule())
                .accessibilityLabel(label)
        } else {
            Color.clear.frame(width: 0, height: 0)
        }
    }

    private func badgeLabel(seconds: Double) -> String {
        if seconds < 60 { return "Now" }
        let mins = Int((seconds / 60).rounded(.up))
        if mins <= 60 { return "In \(mins)m" }
        let hrs = Int((seconds / 3600).rounded())
        return "In \(hrs)h"
    }

    // MARK: - Join button

    private func joinButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isJoining {
                    ProgressView()
                        .tint(isDestructiveAction ? AppColor.destructive : .black)
                } else {
                    Text(buttonLabel)
                        .font(AppFont.caption(.semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: AccessibilityLayout.minimumTouchTarget)
            .padding(.horizontal, Spacing.s)
            .foregroundStyle(isDestructiveAction ? AppColor.destructive : buttonForeground)
            .background(buttonBackground)
            .overlay {
                if session.isFull && actionTitle == nil {
                    Capsule()
                        .stroke(AppColor.gold, lineWidth: 1.5)
                } else if isDestructiveAction {
                    Capsule()
                        .stroke(AppColor.destructive.opacity(0.5), lineWidth: 1.5)
                }
            }
            .clipShape(Capsule())
        }
        .buttonStyle(AppPressStyle())
        .disabled(isJoining)
        .accessibilityLabel("\(accessibilityActionLabel), \(session.sportDisplayName) at \(session.locationName)")
        .accessibilityHint("Changes your participation without opening game details")
        .accessibilityIdentifier("session-action-\(session.id.uuidString)")
    }

    private var buttonLabel: String {
        if let actionTitle { return actionTitle }
        return session.isFull ? "Waitlist" : "Join"
    }

    private var buttonForeground: Color {
        session.isFull && actionTitle == nil ? AppColor.textPrimary(colorScheme) : Color.black
    }

    private var buttonBackground: Color {
        if isDestructiveAction { return AppColor.elevatedSurface(colorScheme) }
        if session.isFull && actionTitle == nil { return AppColor.elevatedSurface(colorScheme) }
        return AppColor.gold
    }

    private var accessibilityActionLabel: String {
        if let actionTitle { return actionTitle }
        return session.isFull ? "Join waitlist" : "Join game"
    }
}
