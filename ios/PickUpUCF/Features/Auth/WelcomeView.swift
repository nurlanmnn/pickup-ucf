import SwiftUI

struct WelcomeView: View {
    @State private var showSignIn = false
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.12, green: 0.12, blue: 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    Spacer()

                    VStack(spacing: Spacing.s) {
                        Text("PickUp")
                            .font(AppFont.largeTitle(.bold))
                            .foregroundStyle(AppColor.gold)
                        Text("UCF pickup sports")
                            .font(AppFont.body())
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    VStack(spacing: Spacing.m) {
                        PrimaryButton(title: "Sign Up") {
                            showSignUp = true
                        }
                        SecondaryButton(title: "Sign In") {
                            showSignIn = true
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .navigationDestination(isPresented: $showSignIn) {
                SignInView()
            }
        }
    }
}

#Preview {
    WelcomeView()
}
