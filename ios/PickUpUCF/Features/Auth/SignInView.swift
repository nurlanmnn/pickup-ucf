import SwiftUI

struct SignInView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState
    @State private var viewModel: SignInViewModel
    let onSignUp: (String) -> Void
    @State private var showFieldHints = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case email, password }

    init(email: String = "", onSignUp: @escaping (String) -> Void) {
        let model = SignInViewModel()
        model.email = email
        _viewModel = State(initialValue: model)
        self.onSignUp = onSignUp
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                AuthHeaderView(title: "Sign In")

                InlineFeedbackSection(error: viewModel.errorMessage)

                FormCard(footer: emailFooter) {
                    FormFieldRow {
                        TextField("UCF email", text: $viewModel.email, prompt: Text("UCF email").foregroundColor(AppColor.textSecondary(colorScheme)))
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }
                    if showFieldHints, let hint = EmailDomainValidator.validationMessage(for: viewModel.email) {
                        FieldErrorLabel(message: hint).formCardInset()
                    }
                    Divider().padding(.leading, Spacing.m)
                    FormFieldRow {
                        SecureField("Password", text: $viewModel.password, prompt: Text("Password").foregroundColor(AppColor.textSecondary(colorScheme)))
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await submit() } }
                    }
                    if showFieldHints, viewModel.password.isEmpty {
                        FieldErrorLabel(message: "Password is required").formCardInset()
                    }
                }
                .disabled(viewModel.isLoading)

                PrimaryButton(
                    title: "Sign In",
                    isLoading: viewModel.isLoading,
                    isEnabled: !viewModel.isLoading
                ) {
                    Task { await submit() }
                }

                NavigationLink { ForgotPasswordView(email: viewModel.email) } label: {
                    Text("Forgot password?")
                        .font(AppFont.caption(.semibold))
                        .foregroundStyle(AppColor.accent(colorScheme))
                        .frame(minHeight: AccessibilityLayout.minimumTouchTarget)
                }
                .disabled(viewModel.isLoading)

                AuthSwitchLink(prompt: "New to PickUp?", title: "Create an account") {
                    focusedField = nil
                    onSignUp(viewModel.email)
                }
                .disabled(viewModel.isLoading)
                .accessibilityIdentifier("sign-in-switch-to-sign-up")
            }
            .padding(Spacing.m)
        }
        .appScreenBackground()
        .toolbarBackground(.hidden, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnBackgroundTap()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .formKeyboardAccessory(
            isPresented: focusedField != nil,
            canGoPrevious: focusedField == .password,
            canGoNext: focusedField == .email,
            onPrevious: { focusedField = .email },
            onNext: { focusedField = .password },
            onDone: { focusedField = nil }
        )
        .navigationDestination(isPresented: Binding(
            get: { viewModel.needsEmailVerification },
            set: { viewModel.needsEmailVerification = $0 }
        )) {
            VerifyEmailView(email: viewModel.email)
        }
    }

    private var emailFooter: String? {
        showFieldHints && EmailDomainValidator.validationMessage(for: viewModel.email) != nil
            ? nil
            : "Use your @knights.ucf.edu or @ucf.edu address."
    }

    @MainActor
    private func submit() async {
        showFieldHints = true
        focusedField = nil
        await viewModel.signIn(appState: appState)
    }
}

#Preview {
    NavigationStack {
        SignInView(onSignUp: { _ in })
            .environment(AppState())
    }
}
