import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(Color.ffSage)
            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.ffText2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ffWarmWhite)
    }
}

struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.ffFat.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.ffFat)
            }

            Text("Something went wrong")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ffText1)

            Text(message)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Color.ffText2)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let retry = retryAction {
                Button("Try Again", action: retry)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.ffSage)
                    .clipShape(RoundedRectangle(cornerRadius: DS.cornerPill))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ffWarmWhite)
    }
}

#Preview {
    LoadingView()
}
