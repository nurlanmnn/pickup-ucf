import SwiftUI

struct CommunityRulesView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                rule(
                    icon: "person.2.fill",
                    title: "Respect other players",
                    text: "No harassment, hate, threats, sexual content, impersonation, bullying, or targeted abuse."
                )
                rule(
                    icon: "sportscourt.fill",
                    title: "Keep it about the game",
                    text: "Do not post spam, scams, illegal activity, unsafe meetup instructions, or another person’s private information."
                )
                rule(
                    icon: "exclamationmark.bubble.fill",
                    title: "Report and block",
                    text: "Report a message, user, or session when it breaks these rules. Blocking hides contact and content between both accounts; existing records are retained for integrity and safety review."
                )
                rule(
                    icon: "clock.badge.exclamationmark.fill",
                    title: "Safety response",
                    text: "We aim to acknowledge urgent safety reports within 24 hours and other reports within 72 hours. PickUp UCF is not an emergency service. Call 911 or UCF Police for immediate danger."
                )

                Link(destination: URL(string: "mailto:support.roomateapp@gmail.com?subject=PickUp%20UCF%20Safety")!) {
                    Label("Contact support", systemImage: "envelope.fill")
                        .font(AppFont.body(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.m)
                        .background(AppColor.gold)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityHint("Opens your mail app with a PickUp UCF safety subject")

                Text("When reporting, include the approximate time and what happened. Do not email passwords, verification codes, notification tokens, or other people’s private information.")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .navigationTitle("Community rules")
        .navigationBarTitleDisplayMode(.large)
    }

    private func rule(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(AppColor.gold)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(AppFont.body(.semibold))
                    .foregroundStyle(AppColor.textPrimary(colorScheme))
                Text(text)
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.m)
        .background(AppColor.elevatedSurface(colorScheme))
        .appCardStyle(cornerRadius: 16)
    }
}

#Preview {
    NavigationStack { CommunityRulesView() }
}
