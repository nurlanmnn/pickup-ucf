import SwiftUI

struct ChatView: View {
    let sessionId: UUID
    let currentUserId: UUID

    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel: ChatViewModel
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
        .background(AppColor.background(colorScheme))
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
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
                EmptyStateView(
                    symbol: "bubble.left.and.bubble.right",
                    title: "No messages yet",
                    message: "Say hi and coordinate meetup details with your group."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                            }
                        }
                        .padding(Spacing.m)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: items.count) { _, _ in
                        if let last = items.last {
                            withAnimation(.easeOut(duration: 0.2)) {
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
