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
                Image(systemName: "envelope.badge")
                    .font(.system(size: 56))
                    .foregroundStyle(AppColor.gold)

                Text("Check your email")
                    .font(AppFont.title())

                Text("We sent a 6-digit code to **\(viewModel.email)**. Enter it below to verify your account.")
                    .font(AppFont.body())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                    .multilineTextAlignment(.center)

                Text("Codes expire after \(AppConfig.emailOTPExpiryDescription).")
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))

                if let errorMessage = viewModel.errorMessage {
                    ErrorBanner(message: errorMessage)
                }

                if let successMessage = viewModel.successMessage {
                    SuccessBanner(message: successMessage)
                }

                TextField("000000", text: $viewModel.otpCode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .multilineTextAlignment(.center)
                    .font(.system(.title, design: .rounded).monospacedDigit().weight(.semibold))
                    .padding(Spacing.m)
                    .background(AppColor.elevatedSurface(colorScheme))
                    .appCardStyle(cornerRadius: 14)
                    .focused($isOTPFocused)
                    .onChange(of: viewModel.otpCode) { _, newValue in
                        viewModel.otpCode = viewModel.normalizeOTP(newValue)
                    }
                    .accessibilityLabel("Verification code")

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
            .padding(Spacing.l)
        }
        .appScreenBackground()
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle("Verify email")
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
