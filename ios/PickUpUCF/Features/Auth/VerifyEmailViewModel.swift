import Foundation

@Observable
final class VerifyEmailViewModel {
    let email: String

    var otpCode = ""
    var errorMessage: String?
    var successMessage: String?
    var isVerifying = false
    var isResending = false
    var resendCooldown = 0

    private let repository: AuthRepositoryProtocol

    init(email: String, repository: AuthRepositoryProtocol = AuthRepository()) {
        self.email = email
        self.repository = repository
    }

    var canVerify: Bool {
        otpCode.count == 6 && !isVerifying
    }

    var canResend: Bool {
        resendCooldown == 0 && !isResending
    }

    var resendTitle: String {
        if isResending { return "Sending…" }
        if resendCooldown > 0 { return "Resend in \(resendCooldown)s" }
        return "Resend code"
    }

    func normalizeOTP(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(6))
    }

    @MainActor
    func verify() async -> AppSession? {
        errorMessage = nil
        successMessage = nil

        guard otpCode.count == 6 else {
            errorMessage = "Enter the 6-digit code from your email."
            return nil
        }

        isVerifying = true
        defer { isVerifying = false }

        do {
            return try await repository.verifyEmailOTP(email: email, token: otpCode)
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            return nil
        }
    }

    @MainActor
    func resend() async {
        errorMessage = nil
        successMessage = nil
        isResending = true
        defer { isResending = false }

        do {
            try await repository.resendVerificationOTP(email: email)
            successMessage = "We sent a new code to your email."
            resendCooldown = 60
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
        }
    }

    @MainActor
    func tickResendCooldown() {
        if resendCooldown > 0 {
            resendCooldown -= 1
        }
    }
}
