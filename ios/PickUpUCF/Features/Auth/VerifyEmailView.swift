import SwiftUI

struct VerifyEmailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: VerifyEmailViewModel
    @FocusState private var isOTPFocused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(email: String) {
        _viewModel = State(initialValue: VerifyEmailViewModel(email: email))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                // Gold envelope hero
                envelopeHero

                // Body text
                VStack(spacing: Spacing.s) {
                    Text("Check your email")
                        .font(AppFont.display(.bold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))

                    Text("We sent a 6-digit code to")
                        .font(AppFont.body())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))

                    Text(viewModel.email)
                        .font(AppFont.body(.semibold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))

                    Text("Codes expire after \(AppConfig.emailOTPExpiryDescription).")
                        .font(AppFont.caption())
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                        .padding(.top, 2)
                }
                .multilineTextAlignment(.center)

                // Feedback
                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }
                if let successMessage = viewModel.successMessage {
                    SuccessBanner(message: successMessage)
                }

                // OTP field — prominent card
                VStack(spacing: Spacing.s) {
                    Text("Enter code")
                        .font(AppFont.caption(.semibold))
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("000000", text: $viewModel.otpCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 34, design: .rounded).monospacedDigit().weight(.bold))
                        .foregroundStyle(AppColor.textPrimary(colorScheme))
                        .tracking(12)
                        .padding(.vertical, Spacing.m)
                        .frame(maxWidth: .infinity)
                        .background(AppColor.elevatedSurface(colorScheme))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isOTPFocused ? AppColor.gold.opacity(0.60) : Color.clear,
                                    lineWidth: 1.5
                                )
                        }
                        .appCardStyle(cornerRadius: 16)
                        .focused($isOTPFocused)
                        .onChange(of: viewModel.otpCode) { _, newValue in
                            viewModel.otpCode = viewModel.normalizeOTP(newValue)
                        }
                        .accessibilityLabel("Verification code")
                }

                PrimaryButton(
                    title: "Verify",
                    isLoading: viewModel.isVerifying,
                    isEnabled: viewModel.canVerify
                ) {
                    Task { await verify() }
                }

                SecondaryButton(title: viewModel.resendTitle) {
                    Task { await viewModel.resend() }
                }
                .disabled(!viewModel.canResend)
                .opacity(viewModel.canResend ? 1 : 0.5)
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            FormKeyboardToolbar(onDone: { isOTPFocused = false })
        }
        .onAppear {
            isOTPFocused = true
        }
        .onReceive(timer) { _ in
            viewModel.tickResendCooldown()
        }
    }

    private var envelopeHero: some View {
        ZStack {
            // Soft gold glow halo
            Circle()
                .fill(AppColor.gold.opacity(0.12))
                .frame(width: 116, height: 116)

            // Gold gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColor.gold, AppColor.goldDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)

            Image(systemName: "envelope.fill")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.65))
        }
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [AppColor.gold, AppColor.gold.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2.5
                )
                .frame(width: 94, height: 94)
        )
        .padding(.top, Spacing.m)
    }

    @MainActor
    private func verify() async {
        isOTPFocused = false
        guard let session = await viewModel.verify() else { return }
        await AuthenticatedSessionCoordinator.bootstrap(session: session, appState: appState)
    }
}

#Preview {
    NavigationStack {
        VerifyEmailView(email: "student@knights.ucf.edu")
            .environment(AppState())
    }
}
