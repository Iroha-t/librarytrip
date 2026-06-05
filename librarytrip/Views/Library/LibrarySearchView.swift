import SwiftUI
import MapKit

struct LibrarySearchView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: Int

    @State private var searchText = ""
    @State private var selectedAxis: RankingAxis = .beautiful
    @State private var selectedLibrary: Library?

    enum RankingAxis: String, CaseIterable {
        case beautiful  = "建築"
        case study      = "勉強向き"
        case cafe       = "カフェ併設"
        case collection = "蔵書数"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    topBar
                    searchBar
                    mapPreviewCard
                    rankingSection
                    Spacer().frame(height: 100)
                }
            }
            .background(Color.toshoCream)
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedLibrary) { lib in
            LibraryDetailView(library: lib)
                .environmentObject(appState)
        }
        .onChange(of: selectedLibrary) { _, new in appState.isPresentingDetailSheet = new != nil }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("図書館を探す")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.toshoText)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 8)
        .background(Color.toshoCream)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.toshoSubtext)
            TextField("図書館名・地名で検索", text: $searchText)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 12, y: 3)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Map Preview Card

    private var mapPreviewCard: some View {
        Button {
            selectedTab = 2
        } label: {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.75, blue: 0.65),
                                Color(red: 0.40, green: 0.62, blue: 0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                    .overlay(
                        HStack(spacing: 16) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.25))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(appState.allLibraries.count)館")
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(.white)
                                Text("全国の図書館")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    )

                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("マップで見る")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.40))
                .clipShape(Capsule())
                .padding(14)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    // MARK: - Ranking Section

    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("図書館ランキング")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.toshoText)
                Spacer()
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RankingAxis.allCases, id: \.rawValue) { axis in
                        Button {
                            selectedAxis = axis
                        } label: {
                            Text(axis.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(selectedAxis == axis ? .white : .toshoRed)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedAxis == axis
                                        ? Color.toshoRed
                                        : Color.toshoRedLight
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(spacing: 0) {
                ForEach(Array(rankedLibraries.prefix(8).enumerated()), id: \.element.id) { index, library in
                    HStack(spacing: 14) {
                        rankBadge(rank: index + 1)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(library.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.toshoText)
                                .lineLimit(1)
                            HStack(spacing: 6) {
                                Text("\(library.prefecture) \(library.city)")
                                    .font(.system(size: 11))
                                    .foregroundColor(.toshoSubtext)
                                Spacer()
                                if selectedAxis == .collection {
                                    Text("\(library.collectionCount / 10000)万冊")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.toshoRed)
                                }
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11))
                            .foregroundColor(.toshoSubtext)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedLibrary = library }

                    if index < min(7, rankedLibraries.count - 1) {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 3)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Helpers

    private var rankedLibraries: [Library] {
        let staticList: [Library]
        switch selectedAxis {
        case .beautiful:  staticList = AppState.beautifulRanking
        case .study:      staticList = AppState.studyRanking
        case .cafe:       staticList = AppState.cafeRanking
        case .collection: staticList = AppState.collectionRanking
        }
        guard !searchText.isEmpty else { return staticList }
        return staticList.filter {
            $0.name.contains(searchText) || $0.city.contains(searchText) || $0.prefecture.contains(searchText)
        }
    }

    private func rankBadge(rank: Int) -> some View {
        ZStack {
            Circle()
                .fill(rankColor(rank))
                .frame(width: 28, height: 28)
            Text("\(rank)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(rank <= 3 ? .white : .toshoSubtext)
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 0.84, green: 0.72, blue: 0.22)
        case 2: return Color(red: 0.66, green: 0.66, blue: 0.70)
        case 3: return Color(red: 0.76, green: 0.49, blue: 0.25)
        default: return Color.gray.opacity(0.10)
        }
    }
}

#Preview {
    LibrarySearchView(selectedTab: .constant(1))
        .environmentObject(AppState())
}
