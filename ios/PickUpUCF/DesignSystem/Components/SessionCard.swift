import SwiftUI

struct SessionCard: View {
    let session: PickupSession
    var isJoining: Bool = false
    /// When set, replaces the default "Join" / "Waitlist" label (e.g. **Leave** on My Games).
    var actionTitle: String?
    var isDestructiveAction: Bool = false
    var onJoin: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card surface
            AppColor.elevatedSurface(colorScheme)

            // Watermark sport icon — large, low-opacity, trailing-bottom
            watermarkIcon

            VStack(alignment: .leading, spacing: 0) {
                // Sport gradient top strip
                sportStrip

                // Main content area
                contentArea
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .appCardStyle(cornerRadius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityHint(onJoin == nil ? "" : "Opens session details; use the action button for quick join or leave")
    }

    // MARK: - Sub-views

    /// 4pt sport-coloured gradient strip across the top of the card.
    private var sportStrip: some View {
        AppTheme.sportCardGradient(session.sport, scheme: colorScheme)
            .frame(height: 4)
    }

    /// Large semi-transparent sport icon watermark at trailing edge.
    private var watermarkIcon: some View {
        Image(systemName: session.sport.systemImage)
            .font(.system(size: 80, weight: .black))
            .foregroundStyle(AppColor.sportAccent(session.sport).opacity(0.10))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 12)
            .padding(.bottom, 8)
    }

    /// Main info + actions.
    private var contentArea: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Sport name + relative badge on same row
                HStack(alignment: .center, spacing: Spacing.s) {
                    Text(session.sportDisplayName)
                        .font(AppFont.headline(.bold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))

                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        relativeBadge(at: context.date)
                    }
                }

                // Location
                Label(session.locationName, systemImage: "mappin.and.ellipse")
                    .font(AppFont.caption(.regular))
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .lineLimit(1)

                // Time line
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    Text(SessionDateFormatter.cardLabel(for: session.startsAt, relativeTo: context.date))
                        .font(AppFont.caption(.regular))
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                }

                Spacer(minLength: Spacing.s)

                // Capacity indicator + skill pill
                HStack(spacing: Spacing.s) {
                    CapacityIndicator(
                        playerCount: session.playerCount,
                        capacity: session.capacity,
                        filledColor: AppColor.sportAccent(session.sport)
                    )

                    SkillPill(skill: session.skillLevel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Join / Leave button
            if let onJoin {
                joinButton(action: onJoin)
            }
        }
        .padding(Spacing.m)
        .padding(.top, Spacing.xs)
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
                        .font(AppFont.caption(.bold))
                }
            }
            .frame(minWidth: 72, minHeight: 36)
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
            .shadow(
                color: (session.isFull || isDestructiveAction)
                    ? Color.clear
                    : AppColor.sportAccent(session.sport).opacity(0.30),
                radius: 6, x: 0, y: 2
            )
        }
        .buttonStyle(.plain)
        .disabled(isJoining)
        .accessibilityLabel(accessibilityActionLabel)
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
