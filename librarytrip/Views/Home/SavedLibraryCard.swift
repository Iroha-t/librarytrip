import SwiftUI

/// 保存した図書館1館分のカード。写真の代わりに、図書館の種類の色・県名の大きな文字・訪問済みスタンプで見せる。
struct SavedLibraryCard: View {
    let library: Library
    let isVisited: Bool

    private var baseColor: Color {
        library.category?.color ?? .toshoRed
    }

    /// カードの背景に薄く大きく入れる、都道府県の頭文字。
    private var watermark: String {
        library.prefecture.first.map(String.init) ?? "図"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    categoryIcon
                    Spacer()
                    if isVisited { visitedStamp }
                }
                Spacer(minLength: 8)
                titleBlock
            }
            .padding(10)
        }
        .frame(width: 112, height: 136)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isVisited ? Color.toshoAmber : Color.clear, lineWidth: 2.5)
        )
        .shadow(
            color: (isVisited ? Color.toshoAmber : Color.black).opacity(isVisited ? 0.45 : 0.12),
            radius: isVisited ? 10 : 6,
            y: 3
        )
    }

    /// 種類ごとの色のグラデーションと、県名の大きな透かし文字。
    private var background: some View {
        ZStack(alignment: .bottomTrailing) {
            LinearGradient(
                colors: [baseColor, baseColor.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(watermark)
                .font(.zenMincho(size: 88, weight: .black))
                .foregroundColor(.white.opacity(0.16))
                .offset(x: 10, y: 14)
            LinearGradient(
                colors: [.clear, .black.opacity(0.28)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }

    private var categoryIcon: some View {
        Image(systemName: library.category?.icon ?? "building.columns.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 26, height: 26)
            .background(Color.white.opacity(0.22))
            .clipShape(Circle())
    }

    /// 訪問した図書館に押される、はんこ風のマーク。
    private var visitedStamp: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 32, height: 32)
            Circle()
                .strokeBorder(Color.toshoRed, lineWidth: 1.5)
                .frame(width: 26, height: 26)
            Text("訪問\n済")
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.toshoRed)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
        }
        .rotationEffect(.degrees(-14))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(library.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(library.city.isEmpty ? library.prefecture : library.city)
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
    }
}

#Preview {
    let sample = Library(
        name: "石川県立図書館",
        prefecture: "石川県",
        city: "金沢市",
        address: "",
        latitude: 36.5,
        longitude: 136.6,
        openingHours: "",
        closedDays: "",
        collectionCount: 0,
        category: .large
    )
    return VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 14) {
            SavedLibraryCard(library: sample, isVisited: true)
            SavedLibraryCard(library: sample, isVisited: false)
        }
    }
    .padding(20)
    .background(Color.toshoCream)
}
