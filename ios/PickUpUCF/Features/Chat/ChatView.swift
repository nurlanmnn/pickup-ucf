import SwiftUI

struct ChatView: View {
    let sessionId: UUID
    let currentUserId: UUID

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: ChatViewModel
    @State private var reportMessage: SessionMessage?
    @State private var userToBlock: UUID?
    @FocusState private var composerFocused: Bool

    init(sessionId: UUID, currentUserId: UUID) {
        self.sessionId = sessionId
        self.currentUserId = currentUserId
        _viewModel = State(initialValue: ChatViewModel(sessionId: sessionId, currentUserId: currentUserId))
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            composer
        }
        .appScreenBackground()
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .formKeyboardAccessory(
            isPresented: composerFocused,
            onDone: { composerFocused = false }
        )
        .dismissKeyboardOnBackgroundTap()
        .task {
            await viewModel.load()
            await withTaskCancellationHandler {
                await viewModel.startRealtime()
            } onCancel: {
                Task { await viewModel.stopRealtime() }
            }
        }
        .onDisappear {
            Task { await viewModel.stopRealtime() }
        }
        .sheet(item: $reportMessage) { message in
            NavigationStack {
                ReportSheet(target: .message(message.id))
            }
            .appSheetChrome(detents: [.medium, .large])
        }
        .confirmationDialog(
            "Block this user?",
            isPresented: Binding(
                get: { userToBlock != nil },
                set: { if !$0 { userToBlock = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block user", role: .destructive) {
                guard let userId = userToBlock else { return }
                Task {
                    _ = await viewModel.block(userId: userId)
                    userToBlock = nil
                }
            }
            Button("Cancel", role: .cancel) { userToBlock = nil }
        } message: {
            Text("You will no longer see each other’s messages, sessions, profiles, or notifications.")
        }
    }

    @ViewBuilder
    private var messageList: some View {
        switch viewModel.messages {
        case .idle, .loading:
            ProgressView("Loading messages…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: Spacing.m) {
                ErrorBanner(message: message)
                PrimaryButton(title: "Try again") {
                    Task { await viewModel.load() }
                }
                .padding(.horizontal, Spacing.m)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let items):
            if items.isEmpty {
                ScrollView {
                    EmptyStateView(
                        symbol: "bubble.left.and.bubble.right",
                        title: "No messages yet",
                        message: "Say hi and coordinate meetup details with your group."
                    )
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Spacing.s) {
                            ForEach(items) { message in
                                ChatBubble(
                                    message: message,
                                    currentUserId: currentUserId,
                                    colorScheme: colorScheme
                                )
                                .id(message.id)
                                .contextMenu {
                                    if message.userId != currentUserId {
                                        Button {
                                            reportMessage = message
                                        } label: {
                                            Label("Report message", systemImage: "exclamationmark.bubble")
                                        }
                                        Button(role: .destructive) {
                                            userToBlock = message.userId
                                        } label: {
                                            Label("Block user", systemImage: "hand.raised")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(Spacing.m)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: items.count) { _, _ in
                        if let last = items.last {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let last = items.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: Spacing.s) {
            if let sendError = viewModel.sendError {
                ErrorBanner(message: sendError)
                    .padding(.horizontal, Spacing.m)
            }

            HStack(alignment: .bottom, spacing: Spacing.s) {
                TextField("Message", text: $viewModel.draftText, axis: .vertical)
                    .lineLimit(1 ... 4)
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(AppColor.surface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .focused($composerFocused)

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, canSend ? AppColor.gold : AppColor.gold.opacity(0.35))
                        .frame(
                            minWidth: AccessibilityLayout.minimumTouchTarget,
                            minHeight: AccessibilityLayout.minimumTouchTarget
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSend || viewModel.isSending)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
        }
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !viewModel.draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isSending
    }
}

private struct ChatBubble: View {
    let message: SessionMessage
    let currentUserId: UUID
    let colorScheme: ColorScheme

    private var isCurrentUser: Bool {
        message.userId == currentUserId
    }

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 48) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.senderLabel(currentUserId: currentUserId))
                        .font(AppFont.caption(.semibold))
                        .foregroundStyle(AppColor.textSecondary(colorScheme))
                }

                Text(message.body)
                    .font(AppFont.body())
                    .foregroundStyle(isCurrentUser ? Color.black : AppColor.textPrimary(colorScheme))
                    .padding(.horizontal, Spacing.m)
                    .padding(.vertical, Spacing.s)
                    .background(bubbleFill)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(ChatDateFormatter.timeLabel(for: message.createdAt))
                    .font(AppFont.caption())
                    .foregroundStyle(AppColor.textSecondary(colorScheme))
            }

            if !isCurrentUser { Spacer(minLength: 48) }
        }
    }

    private var bubbleFill: Color {
        if isCurrentUser {
            return AppColor.gold
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.06)
    }
}

private enum ChatDateFormatter {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static func timeLabel(for date: Date) -> String {
        formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        ChatView(sessionId: UUID(), currentUserId: UUID())
    }
}
