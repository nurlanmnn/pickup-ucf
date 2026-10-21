import SwiftUI

struct WelcomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("welcomeIntroCompleted") private var introCompleted = false
    @AccessibilityFocusState private var headingFocused: Bool
    @State private var step = 0
    @State private var authPath: [AuthScreen] = []
    @State private var authEmail = ""

    private let steps: [(eyebrow: String, title: String, detail: String, sport: SportType)] = [
        ("LESS SCROLLING. MORE PLAYING.", "Your next game.\nRight here.",
         "Find pickup games around UCF. Pick your sport, find your people, and get out there.", .basketball),
        ("GOOD GAMES. BETTER COMPANY.", "Come for the game.\nFind your people.",
         "A familiar sport. A few new faces. Join campus games at your level and make it a regular thing.", .tennis),
        ("MAKE IT HAPPEN.", "A court. A crew.\nYou're all set.",
         "Choose a spot, set a time, and bring a game together. Your campus is ready to play.", .soccer)
    ]

    var body: some View {
        NavigationStack(path: $authPath) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    topBar
                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.l) {
                            if !dynamicTypeSize.isAccessibilitySize {
                                illustration
                                    .frame(height: min(280, max(180, proxy.size.height * 0.34)))
                            }
                            VStack(alignment: .leading, spacing: Spacing.m) {
                                Text(steps[step].eyebrow)
                                    .font(AppFont.caption2(.bold))
                                    .tracking(1.5)
                                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                                Text(steps[step].title)
                                    .font(AppFont.display())
                                    .tracking(-1.2)
                                    .foregroundStyle(AppColor.textPrimary(colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityAddTraits(.isHeader)
                                    .accessibilityFocused($headingFocused)
                                Text(steps[step].detail)
                                    .font(AppFont.body())
                                    .foregroundStyle(AppColor.textSecondary(colorScheme))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .id(step)
                            .transition(.opacity)
                        }
                        .padding(.horizontal, Spacing.l)
                        .padding(.top, Spacing.m)
                        .padding(.bottom, Spacing.l)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { actions }
            }
            .appScreenBackground()
            .toolbar(authPath.isEmpty ? .hidden : .visible, for: .navigationBar)
            .navigationDestination(for: AuthScreen.self) { screen in
                switch screen {
                case .signUp:
                    SignUpView(email: authEmail) { email in
                        authEmail = email
                        authPath = [.signIn]
                    }
                case .signIn:
                    SignInView(email: authEmail) { email in
                        authEmail = email
                        authPath = [.signUp]
                    }
                }
            }
            .onAppear { if introCompleted { step = steps.count - 1 } }
        }
    }

    private var topBar: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.s))
            : AnyLayout(HStackLayout())
        return layout {
            AppBrandLockup()
            if !dynamicTypeSize.isAccessibilitySize { Spacer() }
            if step < steps.count - 1 {
                Button("Skip intro") { move(to: steps.count - 1) }
                    .font(AppFont.caption(.semibold))
                    .frame(minHeight: AccessibilityLayout.minimumTouchTarget)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
    }

    private var illustration: some View {
        ZStack(alignment: .bottomLeading) {
            CourtArtwork(sport: steps[step].sport)
                .id(step)
                .transition(.opacity)
            VStack(alignment: .leading, spacing: Spacing.s) {
                Spacer()
                Text("SEE YOU OUT THERE")
                    .font(AppFont.caption2(.bold))
                    .tracking(1.5)
                HStack(spacing: Spacing.s) {
                    Image(systemName: steps[step].sport.systemImage)
                    Text(steps[step].sport.displayName)
                    Image(systemName: "arrow.up.right")
                }
                .font(AppFont.headline())
            }
            .foregroundStyle(AppColor.courtLine)
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityHidden(true)
    }

    private var pageIndicator: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(steps.indices, id: \.self) { index in
                Button { move(to: index) } label: {
                    Capsule()
                        .fill(step == index ? AppColor.accent(colorScheme) : AppColor.border(colorScheme))
                        .frame(width: step == index ? 24 : 6, height: 6)
                        .frame(minWidth: AccessibilityLayout.minimumTouchTarget, minHeight: AccessibilityLayout.minimumTouchTarget)
                }
                .accessibilityLabel("Introduction, page \(index + 1) of \(steps.count)")
                .accessibilityAddTraits(step == index ? .isSelected : [])
            }
            Spacer()
            if step > 0 {
                Button("Back") { move(to: step - 1) }
                    .font(AppFont.caption(.semibold))
                    .frame(minHeight: AccessibilityLayout.minimumTouchTarget)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.s) {
            pageIndicator
            PrimaryButton(title: step == steps.count - 1 ? "Get started" : "Continue") {
                if step < steps.count - 1 {
                    move(to: step + 1)
                } else {
                    introCompleted = true
                    authPath = [.signUp]
                }
            }
            .accessibilityIdentifier(step == steps.count - 1 ? "welcome-sign-up" : "welcome-continue")
            Button {
                introCompleted = true
                authPath = [.signIn]
            } label: {
                (Text(dynamicTypeSize.isAccessibilitySize ? "" : "Already part of the crew? ")
                    .foregroundColor(AppColor.textSecondary(colorScheme))
                 + Text("Sign in").bold().underline())
                    .font(AppFont.caption())
                    .frame(maxWidth: .infinity, minHeight: AccessibilityLayout.minimumTouchTarget)
            }
            .accessibilityIdentifier("welcome-sign-in")
            if !dynamicTypeSize.isAccessibilitySize {
                Text("Exclusively for the UCF community")
                    .font(AppFont.caption2())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.m)
        .padding(.bottom, Spacing.s)
        .background(AppColor.background(colorScheme))
    }

    private func move(to index: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { step = index }
        headingFocused = true
    }
}

#Preview { WelcomeView() }

private enum AuthScreen: Hashable {
    case signIn
    case signUp
}
