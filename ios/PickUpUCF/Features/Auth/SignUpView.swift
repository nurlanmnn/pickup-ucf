import SwiftUI

struct SignUpView: View {
    @State private var viewModel = SignUpViewModel()
    @State private var showFieldHints = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case displayName, email, password, confirm
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Form {
            Section {
                TextField("Display name", text: $viewModel.displayName)
                    .textContentType(.name)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .email }

                if showFieldHints, let message = displayNameHint {
                    fieldHint(message)
                }

                TextField("UCF email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }

                if showFieldHints, let message = emailHint {
                    fieldHint(message)
                }

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirm }

                if showFieldHints, let message = passwordHint {
                    fieldHint(message)
                }

                SecureField("Confirm password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
                    .focused($focusedField, equals: .confirm)
                    .submitLabel(.done)
                    .onSubmit {
                        focusedField = nil
                        Task { await submit() }
                    }

                if showFieldHints, let message = confirmHint {
                    fieldHint(message)
                }
            } header: {
                Text("Account")
            } footer: {
                Text("Use @knights.ucf.edu or @ucf.edu. Password must be at least 8 characters.")
            }

            InlineFeedbackSection(error: viewModel.errorMessage)

            Section {
                PrimaryButton(
                    title: "Create account",
                    isLoading: viewModel.isLoading,
                    isEnabled: !viewModel.isLoading
                ) {
                    Task { await submit() }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            FormKeyboardToolbar(
                canGoPrevious: focusedField != .displayName && focusedField != nil,
                canGoNext: focusedField != .confirm,
                onPrevious: { focusPrevious() },
                onNext: { focusNext() },
                onDone: { focusedField = nil }
            )
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.didSignUp },
            set: { viewModel.didSignUp = $0 }
        )) {
            VerifyEmailView(email: viewModel.email)
        }
        .background(AppColor.background(colorScheme))
    }

    private var displayNameHint: String? {
        viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Display name is required"
            : nil
    }

    private var emailHint: String? {
        EmailDomainValidator.validationMessage(for: viewModel.email)
    }

    private var passwordHint: String? {
        PasswordValidator.validationMessage(for: viewModel.password)
    }

    private var confirmHint: String? {
        PasswordValidator.confirmationMessage(
            password: viewModel.password,
            confirm: viewModel.confirmPassword
        )
    }

    private func fieldHint(_ message: String) -> some View {
        Text(message)
            .font(AppFont.caption())
            .foregroundStyle(AppColor.destructive)
    }

    @MainActor
    private func submit() async {
        showFieldHints = true
        focusedField = nil
        await viewModel.signUp()
    }

    private func focusNext() {
        switch focusedField {
        case .displayName: focusedField = .email
        case .email: focusedField = .password
        case .password: focusedField = .confirm
        default: break
        }
    }

    private func focusPrevious() {
        switch focusedField {
        case .confirm: focusedField = .password
        case .password: focusedField = .email
        case .email: focusedField = .displayName
        default: break
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
