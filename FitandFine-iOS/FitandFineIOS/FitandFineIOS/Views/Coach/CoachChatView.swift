import SwiftUI

// MARK: - CoachChatView

struct CoachChatView: View {
    @ObservedObject var viewModel: CoachViewModel
    @FocusState private var inputFocused: Bool
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Purple gradient header ─────────────────────────────────────
            coachHeader

            // ── Message list ──────────────────────────────────────────────
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        if viewModel.messages.isEmpty {
                            emptyState
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                        } else {
                            ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { idx, msg in
                                ChatBubble(message: msg)
                                    .id(msg.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation(DS.Anim.smooth) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.messages.last?.text) { _, _ in
                    if let last = viewModel.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // ── Input bar ─────────────────────────────────────────────────
            inputBar
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.messages.isEmpty {
                    Button {
                        Haptics.light()
                        withAnimation(DS.Anim.smooth) { viewModel.clearConversation() }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(DS.Color.accent)
                    }
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            withAnimation(DS.Anim.entrance) { appeared = true }
            // Send pre-filled quick prompt if any
            if !viewModel.inputText.isEmpty {
                Task { await viewModel.sendMessage() }
            }
        }
    }

    // MARK: - Coach Header

    private var coachHeader: some View {
        ZStack {
            DS.coachGradient

            // Decorative circles
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 120, height: 120)
                .offset(x: 130, y: -30)
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 90, height: 90)
                .offset(x: -80, y: 30)

            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Coach")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Powered by Claude")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.80))

                    HStack(spacing: 5) {
                        Circle()
                            .fill(DS.Color.accentMid)
                            .frame(width: 7, height: 7)
                        Text("Online · Ready to help")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15))
                    .clipShape(Capsule())
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)

            // Avatar
            ZStack {
                Circle()
                    .fill(DS.Color.accent.opacity(0.12))
                    .frame(width: 90, height: 90)
                Circle()
                    .fill(DS.Color.accent.opacity(0.07))
                    .frame(width: 116, height: 116)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundStyle(DS.Color.accent)
            }
            .padding(.bottom, 20)

            Text("FitCoach")
                .font(.title.bold())
                .padding(.bottom, 6)

            Text("Your AI nutrition coach.\nAsk me anything about your diet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

            // Suggestion chips
            VStack(spacing: 8) {
                suggestionChip("Why am I not losing weight?",     icon: "questionmark.circle")
                suggestionChip("What should I eat for more protein?", icon: "fork.knife")
                suggestionChip("How was my diet this week?",      icon: "calendar")
                suggestionChip("Suggest a high-protein lunch",    icon: "sparkles")
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private func suggestionChip(_ text: String, icon: String) -> some View {
        Button {
            Haptics.select()
            viewModel.inputText = text
            Task { await viewModel.sendMessage() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(DS.Color.accent)
                    .font(.subheadline)
                    .frame(width: 20)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask your coach…", text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray5).opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .focused($inputFocused)
                .disabled(viewModel.isStreaming)
                .font(.body)
                .onSubmit {
                    Task { await viewModel.sendMessage() }
                }

            // Send / Stop button
            Button {
                Haptics.medium()
                Task { await viewModel.sendMessage() }
            } label: {
                ZStack {
                    Circle()
                        .fill(canSend ? DS.Color.accent : Color(.systemGray4))
                        .frame(width: 38, height: 38)
                    Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .animation(DS.Anim.springFast, value: canSend)
            }
            .disabled(!canSend && !viewModel.isStreaming)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(
            Rectangle()
                .fill(Color(.separator).opacity(0.5))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isStreaming
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 52)
            } else {
                coachAvatar
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubbleBody
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.74, alignment: isUser ? .trailing : .leading)

            if !isUser {
                Spacer(minLength: 52)
            }
        }
    }

    @ViewBuilder
    private var bubbleBody: some View {
        let isEmpty = message.text.isEmpty && message.role == .coach
        let displayText = isEmpty ? "   " : message.text

        if isUser {
            Text(displayText)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [DS.Color.accent, DS.Color.accentMid],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedCornerBubble(radius: 18, corners: [.topLeft, .topRight, .bottomLeft]))
                .shadow(color: DS.Color.accent.opacity(0.25), radius: 8, y: 3)
        } else {
            ZStack(alignment: .leading) {
                Text(displayText)
                    .font(.body)
                    .foregroundStyle(isEmpty ? .clear : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DS.Color.surface)
                    .clipShape(RoundedCornerBubble(radius: 18, corners: [.topLeft, .topRight, .bottomRight]))
                    .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, y: DS.Shadow.card.y)
                    .animation(DS.Anim.smooth, value: message.text)

                // Typing indicator
                if isEmpty {
                    TypingIndicator()
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
            }
        }
    }

    private var coachAvatar: some View {
        ZStack {
            Circle()
                .fill(DS.Color.coachPurple.opacity(0.14))
                .frame(width: 32, height: 32)
            Image(systemName: "brain.head.profile")
                .font(.system(size: 15))
                .foregroundStyle(DS.Color.coachPurple)
        }
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 7, height: 7)
                    .scaleEffect(1.0 + 0.3 * sin(phase + Double(i) * .pi * 0.6))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Rounded Corner Bubble Shape

private struct RoundedCornerBubble: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
