import SwiftUI

struct SignInView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = SignInViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    var body: some View {
        Form {
            Section {
                TextField("UCF email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        Task { await viewModel.signIn(appState: appState) }
                    }
            }

            InlineFeedbackSection(error: viewModel.errorMessage)

            Section {
                PrimaryButton(
                    title: "Sign In",
                    isLoading: viewModel.isLoading,
                    isEnabled: !viewModel.isLoading
                ) {
                    Task { await viewModel.signIn(appState: appState) }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                NavigationLink("Forgot password?") {
                    ForgotPasswordView()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Sign In")
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
        .background(AppColor.background(colorScheme))
    }
}

#Preview {
    NavigationStack {
        SignInView()
            .environment(AppState())
    }
}
