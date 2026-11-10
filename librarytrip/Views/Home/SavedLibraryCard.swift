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
            .padding(12)
        }
        .frame(width: 138, height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                .font(.zenMincho(size: 112, weight: .black))
                .foregroundColor(.white.opacity(0.16))
                .offset(x: 14, y: 18)
            LinearGradient(
                colors: [.clear, .black.opacity(0.28)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }

    private var categoryIcon: some View {
        Image(systemName: library.category?.icon ?? "building.columns.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(Color.white.opacity(0.22))
            .clipShape(Circle())
    }

    /// 訪問した図書館に押される、はんこ風のマーク。
    private var visitedStamp: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 36, height: 36)
            Circle()
                .strokeBorder(Color.toshoRed, lineWidth: 1.5)
                .frame(width: 30, height: 30)
            Text("訪問\n済")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.toshoRed)
                .multilineTextAlignment(.center)
                .lineSpacing(0)
        }
        .rotationEffect(.degrees(-14))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(library.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(library.city.isEmpty ? library.prefecture : library.city)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
    }
}

/// 保存した図書館のうち、何館に行けたかを見せる達成バー。
struct SavedLibrariesProgress: View {
    let visitedCount: Int
    let totalCount: Int

    private var isComplete: Bool {
        totalCount > 0 && visitedCount >= totalCount
    }

    private var ratio: Double {
        totalCount == 0 ? 0 : min(1, Double(visitedCount) / Double(totalCount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(visitedCount)")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.toshoRed)
                    Text("/ \(totalCount)館 訪問")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.toshoSubtext)
                }
                Spacer()
                if isComplete {
                    Label("コンプリート！", systemImage: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.toshoAmber)
                } else {
                    Text("あと\(totalCount - visitedCount)館で全部めぐれる")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.toshoSubtext)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.toshoRed.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [.toshoAmber, .toshoRed],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: proxy.size.width * ratio)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 3)
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
        SavedLibrariesProgress(visitedCount: 2, totalCount: 5)
        HStack(spacing: 14) {
            SavedLibraryCard(library: sample, isVisited: true)
            SavedLibraryCard(library: sample, isVisited: false)
        }
    }
    .padding(20)
    .background(Color.toshoCream)
}
