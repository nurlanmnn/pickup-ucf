import SwiftUI

/// Compact brand header shown at the top of every pushed auth screen.
/// Displays a sport icon strip, the page title in display font, and an optional subtitle.
struct AuthHeaderView: View {
    let title: String
    var subtitle: String? = nil

    private let sports: [SportType] = [.basketball, .soccer, .volleyball]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Spacing.m) {
            // Sport icon strip
            HStack(spacing: Spacing.s) {
                ForEach(sports) { sport in
                    Image(systemName: sport.systemImage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColor.sportAccent(sport))
                        .frame(width: 32, height: 32)
                        .background(AppColor.sportAccent(sport).opacity(0.10))
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(AppColor.sportAccent(sport).opacity(0.25), lineWidth: 1)
                        }
                }

                // PickUp badge
                Text("PickUp")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppColor.gold.opacity(0.10))
                    .overlay {
                        Capsule().stroke(AppColor.gold.opacity(0.30), lineWidth: 1)
                    }
                    .clipShape(Capsule())
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(AppFont.display(.bold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))

                if let subtitle {
                    Text(subtitle)
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.xs)
    }
}

#Preview {
    VStack(spacing: 32) {
        AuthHeaderView(title: "Sign In")
        AuthHeaderView(title: "Verify Email", subtitle: "We sent a code to your UCF address.")
    }
    .padding()
}
