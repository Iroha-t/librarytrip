import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedCategory: RankingCategory = .topRated
    @State private var selectedLibrary: Library?

    enum RankingCategory: String, CaseIterable {
        case topRated = "評価が高い"
        case beautiful = "建築が美しい"
        case study = "勉強向き"
        case cafe = "カフェ併設"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    searchBar
                    featuredSection
                    rankingSection
                    nearbySection
                }
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
            LinearGradient(
                colors: [Color.toshoGreen, Color.toshoGreen.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("としょたび")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("図書館をめぐって、本と出会おう")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                HStack(spacing: 16) {
                    statBadge(
                        value: "\(appState.visitedLibraryIds.count)",
                        label: "訪問済み",
                        icon: "checkmark.seal.fill"
                    )
                    statBadge(
                        value: "\(appState.wishlistLibraryIds.count)",
                        label: "行きたい",
                        icon: "bookmark.fill"
                    )
                    statBadge(
                        value: "\(appState.borrowedBooks.count)",
                        label: "借り中の本",
                        icon: "book.fill"
                    )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 60)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.toshoSubtext)
                TextField("図書館名・地名で検索", text: $searchText)
                    .font(.subheadline)
            }
            .padding(12)
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 2)

            Button {
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.toshoGreen)
                    .frame(width: 44, height: 44)
                    .background(Color.toshoCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, -20)
        .padding(.bottom, 16)
    }

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "注目の図書館", icon: "sparkles")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(appState.libraries.prefix(4)) { library in
                        LibraryCard(library: library, style: .featured)
                            .frame(width: 260)
                            .onTapGesture {
                                selectedLibrary = library
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            }
        }
        .padding(.bottom, 8)
    }

    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "図書館ランキング", icon: "trophy.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RankingCategory.allCases, id: \.rawValue) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat.rawValue)
                                .font(.subheadline)
                                .foregroundColor(selectedCategory == cat ? .white : .toshoGreen)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == cat
                                        ? Color.toshoGreen
                                        : Color.toshoGreenLight
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(spacing: 0) {
                ForEach(Array(filteredByCategory.prefix(5).enumerated()), id: \.element.id) { index, library in
                    HStack(spacing: 14) {
                        rankBadge(rank: index + 1)
                        LibraryCard(library: library, style: .ranking)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                    .onTapGesture {
                        selectedLibrary = library
                    }
                    if index < 4 {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 2)
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }

    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "最近チェックされた図書館", icon: "clock.fill")
            VStack(spacing: 10) {
                ForEach(appState.libraries.prefix(3)) { library in
                    LibraryCard(library: library, style: .compact)
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            selectedLibrary = library
                        }
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var filteredByCategory: [Library] {
        switch selectedCategory {
        case .topRated:
            return appState.libraries.sorted { $0.rating > $1.rating }
        case .beautiful:
            return appState.libraries.filter { $0.tags.contains(.beautiful) }.sorted { $0.rating > $1.rating }
        case .study:
            return appState.libraries.filter { $0.hasStudyRoom }.sorted { $0.rating > $1.rating }
        case .cafe:
            return appState.libraries.filter { $0.hasCafe }.sorted { $0.rating > $1.rating }
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.toshoGreen)
            Text(title)
                .font(.headline)
                .foregroundColor(.toshoText)
            Spacer()
            Text("すべて見る")
                .font(.caption)
                .foregroundColor(.toshoGreen)
        }
        .padding(.horizontal, 20)
    }

    private func statBadge(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.headline.bold())
            }
            .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(minWidth: 60)
    }

    private func rankBadge(rank: Int) -> some View {
        ZStack {
            Circle()
                .fill(rank <= 3 ? Color.toshoAmber : Color.gray.opacity(0.15))
                .frame(width: 28, height: 28)
            Text("\(rank)")
                .font(.caption.bold())
                .foregroundColor(rank <= 3 ? .white : .toshoSubtext)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
