import SwiftUI

struct WelcomeView: View {
    @State private var showSignIn = false
    @State private var showSignUp = false

    private let featuredSports: [SportType] = [.basketball, .soccer, .volleyball, .tennis]

    var body: some View {
        NavigationStack {
            ZStack {
                welcomeBackground

                VStack(spacing: 0) {
                    Spacer(minLength: Spacing.xl)

                    brandHeader

                    Spacer(minLength: Spacing.xl)

                    VStack(spacing: Spacing.m) {
                        PrimaryButton(title: "Sign Up") {
                            showSignUp = true
                        }

                        SecondaryButton(title: "Sign In", variant: .onDark) {
                            showSignIn = true
                        }

                        Text("Use your @ucf.edu or @knights.ucf.edu email")
                            .font(AppFont.caption())
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.top, Spacing.s)
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .preferredColorScheme(.dark)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .navigationDestination(isPresented: $showSignIn) {
                SignInView()
            }
        }
    }

    private var welcomeBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.04, blue: 0.05),
                    Color(red: 0.09, green: 0.085, blue: 0.07),
                    Color(red: 0.05, green: 0.05, blue: 0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    AppColor.gold.opacity(0.22),
                    AppColor.gold.opacity(0.04),
                    Color.clear,
                ],
                center: .top,
                startRadius: 20,
                endRadius: 340
            )

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.45)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var brandHeader: some View {
        VStack(spacing: Spacing.l) {
            sportIconRow

            VStack(spacing: Spacing.s) {
                Text("PickUp")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.gold)

                Text("UCF pickup sports")
                    .font(AppFont.title(.semibold))
                    .foregroundStyle(.white)

                Text("Find games, host sessions, and meet players on campus.")
                    .font(AppFont.body())
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
        }
        .padding(.horizontal, Spacing.l)
    }

    private var sportIconRow: some View {
        HStack(spacing: Spacing.m) {
            ForEach(featuredSports) { sport in
                Image(systemName: sport.systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.sportAccent(sport))
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay {
                        Circle()
                            .stroke(AppColor.gold.opacity(0.35), lineWidth: 1)
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    WelcomeView()
}
