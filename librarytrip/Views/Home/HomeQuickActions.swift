import SwiftUI

/// トップ画面に横並びで置く2つのボタン。現在地から図書館を探す／バーコードで本を返す図書館を探す。
struct HomeQuickActions: View {
    let onNearby: () -> Void
    let onReturn: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            actionButton(
                icon: "location.fill",
                title: "現在地から探す",
                subtitle: "近くの図書館を表示",
                action: onNearby
            )
            actionButton(
                icon: "barcode.viewfinder",
                title: "本を返す",
                subtitle: "バーコードで図書館を探す",
                action: onReturn
            )
        }
    }

    /// アイコンと2行の文字が入った、カード型のボタン1つ分。
    private func actionButton(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.toshoRed.opacity(0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.toshoRed)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.toshoText)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.toshoSubtext)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 3)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeQuickActions(onNearby: {}, onReturn: {})
        .padding(20)
        .background(Color.toshoCream)
}
