import SwiftUI

/// 読み込み中に、くるくるとメッセージを表示するカード。
struct LoadingCard: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(0.9).tint(.toshoRed)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 8, y: 2)
    }
}

/// うまくいかなかったときに、理由と「もう一度試す」ボタンを表示するカード。
struct ErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.toshoText)
            }
            Button("もう一度試す", action: onRetry)
                .font(.caption.bold())
                .foregroundColor(.toshoRed)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
    }
}

/// 「貸出可」「貸出中」などの貸出状況を色つきで表示する小さなバッジ。
struct LoanStatusBadge: View {
    let status: String

    private var color: Color {
        switch status {
        case "貸出可": return .green
        case "蔵書あり", "館内のみ": return .green.opacity(0.7)
        case "貸出中": return .orange
        default: return .gray
        }
    }

    var body: some View {
        Text(status)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 16) {
        LoadingCard(message: "現在地を取得中...")
        ErrorCard(message: "現在地を取得できませんでした。もう一度試してください") {}
        HStack {
            LoanStatusBadge(status: "貸出可")
            LoanStatusBadge(status: "貸出中")
            LoanStatusBadge(status: "館内のみ")
        }
    }
    .padding()
    .background(Color.toshoCream)
}
