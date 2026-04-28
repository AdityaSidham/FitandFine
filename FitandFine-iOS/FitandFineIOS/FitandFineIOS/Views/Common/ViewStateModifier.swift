import SwiftUI

// MARK: - Loading View

struct LoadingView: View {
    var message: String = "Loading…"
    @State private var rotationAngle: Double = 0
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(DS.Color.accent.opacity(0.15), lineWidth: 3)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(DS.accentGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
                Image(systemName: "leaf.fill")
                    .foregroundStyle(DS.Color.accent)
                    .font(.system(size: 16))
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.92)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(DS.Anim.entrance) { appeared = true }
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)? = nil
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let retry = retryAction {
                Button("Try Again") {
                    Haptics.medium()
                    retry()
                }
                .buttonStyle(.green)
                .frame(maxWidth: 180)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(DS.Anim.entrance) { appeared = true }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(DS.Color.accent.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundStyle(DS.Color.accent.opacity(0.7))
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let title = actionTitle, let action {
                Button(title) {
                    Haptics.light()
                    action()
                }
                .buttonStyle(.green)
                .frame(maxWidth: 200)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Loading") { LoadingView() }
#Preview("Error") { ErrorView(message: "Could not connect to server.", retryAction: {}) }
#Preview("Empty") {
    EmptyStateView(
        icon: "fork.knife.circle",
        title: "Nothing logged yet",
        message: "Start tracking your meals to see them here.",
        actionTitle: "Log Food",
        action: {}
    )
}
