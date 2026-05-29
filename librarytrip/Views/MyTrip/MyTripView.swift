import SwiftUI

struct MyTripView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSegment = 0
    @State private var selectedLibrary: Library?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                segmentedControl
                content
            }
            .background(Color.toshoCream)
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedLibrary) { lib in
            LibraryDetailView(library: lib)
                .environmentObject(appState)
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            Color.toshoGreen
            VStack(alignment: .leading, spacing: 12) {
                Text("きろく")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    statCard(
                        value: "\(appState.visitedLibraryIds.count)",
                        label: "訪問済み",
                        icon: "checkmark.seal.fill",
                        total: "\(appState.libraries.count)館"
                    )
                    statCard(
                        value: "\(appState.wishlistLibraryIds.count)",
                        label: "行きたい",
                        icon: "bookmark.fill",
                        total: nil
                    )
                    statCard(
                        value: "\(visitedPrefectureCount)",
                        label: "都道府県",
                        icon: "map.fill",
                        total: "/ 47"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 56)
        }
    }

    private var visitedPrefectureCount: Int {
        let visitedLibraries = appState.libraries.filter { appState.visitedLibraryIds.contains($0.id) }
        return Set(visitedLibraries.map { $0.prefecture }).count
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(["訪問済み", "行きたい", "都道府県別"].indices, id: \.self) { i in
                let labels = ["訪問済み", "行きたい", "都道府県別"]
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSegment = i
                    }
                } label: {
                    Text(labels[i])
                        .font(.subheadline)
                        .foregroundColor(selectedSegment == i ? .toshoGreen : .toshoSubtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(selectedSegment == i ? .toshoGreen : .clear),
                            alignment: .bottom
                        )
                }
            }
        }
        .background(Color.toshoCard)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedSegment {
        case 0:
            visitedList
        case 1:
            wishlistContent
        case 2:
            prefectureView
        default:
            EmptyView()
        }
    }

    private var visitedList: some View {
        ScrollView {
            if appState.visitedLibraryIds.isEmpty {
                emptyState(
                    icon: "building.columns",
                    title: "まだ訪問した図書館がありません",
                    subtitle: "図書館を訪れたら記録してみましょう！"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.visitedLibraries) { library in
                        visitCard(library)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    private var wishlistContent: some View {
        ScrollView {
            if appState.wishlistLibraryIds.isEmpty {
                emptyState(
                    icon: "bookmark",
                    title: "行きたい図書館がありません",
                    subtitle: "気になる図書館をブックマークしてみましょう！"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(appState.wishlistLibraries) { library in
                        LibraryCard(library: library, style: .compact)
                            .padding(.horizontal, 16)
                            .onTapGesture {
                                selectedLibrary = library
                            }
                    }
                }
                .padding(.vertical, 16)
            }
        }
    }

    private var prefectureView: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(appState.prefectureStats, id: \.prefecture) { stat in
                    prefectureRow(stat)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 16)
        }
    }

    private func visitCard(_ library: Library) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color.toshoAmber.opacity(0.7), Color.toshoAmber],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 60, height: 60)
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(library.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.toshoText)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.toshoGreen)
                    Text("\(library.prefecture) \(library.city)")
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                }
                HStack(spacing: 2) {
                    ForEach(library.tags.prefix(2), id: \.rawValue) { tag in
                        TagChip(tag: tag)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.toshoSubtext)
        }
        .padding(14)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 6, y: 2)
        .onTapGesture {
            selectedLibrary = library
        }
    }

    private func prefectureRow(_ stat: (prefecture: String, visited: Int, total: Int)) -> some View {
        HStack(spacing: 14) {
            Text(stat.prefecture)
                .font(.subheadline)
                .foregroundColor(.toshoText)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 8)
                    Capsule()
                        .fill(stat.visited > 0 ? Color.toshoGreen : Color.gray.opacity(0.3))
                        .frame(
                            width: stat.total > 0
                                ? geo.size.width * CGFloat(stat.visited) / CGFloat(stat.total)
                                : 0,
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            Text("\(stat.visited)/\(stat.total)")
                .font(.caption.bold())
                .foregroundColor(stat.visited > 0 ? .toshoGreen : .toshoSubtext)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(14)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.smallCornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 4, y: 1)
    }

    private func statCard(value: String, label: String, icon: String, total: String?) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                if let total {
                    Text(total)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.toshoGreen.opacity(0.4))
            Text(title)
                .font(.headline)
                .foregroundColor(.toshoText)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

#Preview {
    MyTripView()
        .environmentObject(AppState())
}
