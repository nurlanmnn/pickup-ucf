import SwiftUI

struct SignInView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SignInViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.m) {
                AuthHeaderView(title: "Sign In")

                InlineFeedbackSection(error: viewModel.errorMessage)

                FormCard(footer: "Use your @knights.ucf.edu or @ucf.edu address.") {
                    FormFieldRow {
                        TextField("UCF email", text: $viewModel.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }
                    Divider().padding(.leading, Spacing.m)
                    FormFieldRow {
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await viewModel.signIn(appState: appState) } }
                    }
                }

                PrimaryButton(
                    title: "Sign In",
                    isLoading: viewModel.isLoading,
                    isEnabled: !viewModel.isLoading
                ) {
                    Task { await viewModel.signIn(appState: appState) }
                }

                NavigationLink { ForgotPasswordView() } label: {
                    Text("Forgot password?")
                        .font(AppFont.caption(.semibold))
                        .foregroundStyle(AppColor.gold)
                }
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
            FormKeyboardToolbar(
                canGoPrevious: focusedField == .password,
                canGoNext: focusedField == .email,
                onPrevious: { focusedField = .email },
                onNext: { focusedField = .password },
                onDone: { focusedField = nil }
            )
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.needsEmailVerification },
            set: { viewModel.needsEmailVerification = $0 }
        )) {
            VerifyEmailView(email: viewModel.email)
        }
    }
}

#Preview {
    NavigationStack {
        SignInView()
            .environment(AppState())
    }
}
