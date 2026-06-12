import SwiftUI
import MapKit

struct LibrarySearchView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: Int

    @State private var searchText = ""
    @State private var selectedAxis: RankingAxis = .beautiful
    @State private var selectedLibrary: Library?

    // 図書館名・地名 検索
    @State private var libraryNameSearchState: LibraryNameSearchState = .idle

    // 本タイトル → 近くの図書館検索
    @State private var bookTitle = ""
    @State private var bookSearchState: BookSearchState = .idle
    @State private var locationManager = LocationManager()

    enum RankingAxis: String, CaseIterable {
        case beautiful  = "建築"
        case study      = "勉強向き"
        case cafe       = "カフェ併設"
        case collection = "蔵書数"
    }

    enum LibraryNameSearchState {
        case idle
        case loading
        case results([Library])
        case error(String)
    }

    enum BookSearchState {
        case idle
        case loading
        case results([LibraryBookResult])
        case error(String)
    }

    struct LibraryBookResult: Identifiable {
        let id = UUID()
        let library: Library
        let systemId: String
        let status: String      // 貸出可 / 貸出中 / 蔵書あり / 蔵書なし
        let reserveURL: String?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    topBar
                    searchBar
                    if case .idle = libraryNameSearchState { } else {
                        libraryNameSearchResultArea
                    }
                    bookLibrarySearchSection
                        .padding(.bottom, 28)
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
                .font(.zenMincho(size: 22, weight: .bold))
                .foregroundColor(.toshoText)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 8)
        .background(Color.toshoCream)
    }

    // MARK: - Search Bar（図書館名・地名）

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.toshoSubtext)
                TextField("図書館名・地名・都道府県で検索", text: $searchText)
                    .font(.subheadline)
                    .submitLabel(.search)
                    .onSubmit { Task { await searchLibraries() } }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        libraryNameSearchState = .idle
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.toshoSubtext)
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 12, y: 3)

            if !searchText.isEmpty {
                Button { Task { await searchLibraries() } } label: {
                    Text("検索")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .background(Color.toshoRed)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Library Name Search Result Area

    @ViewBuilder
    private var libraryNameSearchResultArea: some View {
        switch libraryNameSearchState {
        case .idle:
            EmptyView()

        case .loading:
            HStack(spacing: 10) {
                ProgressView().scaleEffect(0.9).tint(.toshoRed)
                Text("図書館を検索中...")
                    .font(.subheadline)
                    .foregroundColor(.toshoSubtext)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 8, y: 2)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

        case .results(let libs):
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(libs.isEmpty ? "該当する図書館が見つかりませんでした" : "検索結果 \(libs.count)件")
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, libs.isEmpty ? 12 : 4)

                if libs.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .foregroundColor(.toshoSubtext)
                        Text("都道府県名や市区町村名も試してみてください")
                            .font(.caption)
                            .foregroundColor(.toshoSubtext)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                } else {
                    ForEach(Array(libs.prefix(30).enumerated()), id: \.element.id) { idx, lib in
                        Button { selectedLibrary = lib } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(lib.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.toshoText)
                                        .lineLimit(1)
                                    Text("\(lib.prefecture) \(lib.city)")
                                        .font(.caption)
                                        .foregroundColor(.toshoSubtext)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.toshoSubtext)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        if idx < min(29, libs.count - 1) {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 8, y: 2)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

        case .error(let msg):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(msg).font(.subheadline).foregroundColor(.toshoText)
            }
            .padding(14)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Book Library Search Section

    private var bookLibrarySearchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.toshoRed)
                Text("本のタイトルで近くの図書館を探す")
                    .font(.zenMincho(size: 17, weight: .semiBold))
                    .foregroundColor(.toshoText)
            }
            .padding(.horizontal, 20)

            // 入力欄 + 検索ボタン
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.toshoSubtext)
                        .font(.system(size: 14))
                    TextField("例: 吾輩は猫である", text: $bookTitle)
                        .font(.subheadline)
                        .submitLabel(.search)
                        .onSubmit { Task { await searchBooksInNearbyLibraries() } }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.toshoCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.toshoRed.opacity(0.3), lineWidth: 1))

                Button {
                    Task { await searchBooksInNearbyLibraries() }
                } label: {
                    Text("検索")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(bookTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.gray.opacity(0.35) : Color.toshoRed)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(bookTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)

            // 現在地ヒント
            HStack(spacing: 4) {
                Image(systemName: locationManager.coordinate != nil ? "location.fill" : "location")
                    .font(.caption2)
                    .foregroundColor(locationManager.coordinate != nil ? .blue : .toshoSubtext)
                Text(locationManager.coordinate != nil ? "現在地周辺で検索します" : "現在地ボタンで位置情報を有効にすると精度が上がります")
                    .font(.caption)
                    .foregroundColor(.toshoSubtext)
                Spacer()
                if locationManager.coordinate == nil {
                    Button {
                        locationManager.requestAndLocate()
                    } label: {
                        Text("現在地を使う")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 20)

            // 結果エリア
            bookSearchResultArea
        }
    }

    @ViewBuilder
    private var bookSearchResultArea: some View {
        switch bookSearchState {
        case .idle:
            EmptyView()

        case .loading:
            HStack(spacing: 10) {
                ProgressView().scaleEffect(0.9).tint(.toshoRed)
                Text("図書館を検索中...")
                    .font(.subheadline)
                    .foregroundColor(.toshoSubtext)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 8, y: 2)
            .padding(.horizontal, 20)

        case .results(let items):
            VStack(spacing: 0) {
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.toshoSubtext)
                        Text("近くの図書館に蔵書が見つかりませんでした")
                            .font(.subheadline)
                            .foregroundColor(.toshoSubtext)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        Button { selectedLibrary = item.library } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.library.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.toshoText)
                                        .lineLimit(1)
                                    Text("\(item.library.prefecture) \(item.library.city)")
                                        .font(.caption)
                                        .foregroundColor(.toshoSubtext)
                                }
                                Spacer()
                                loanBadge(item.status)
                                if let url = item.reserveURL, let u = URL(string: url) {
                                    Link(destination: u) {
                                        Image(systemName: "arrow.up.right")
                                            .font(.caption)
                                            .foregroundColor(.toshoRed)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        if idx < items.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 8, y: 2)
            .padding(.horizontal, 20)

        case .error(let msg):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text(msg).font(.subheadline).foregroundColor(.toshoText)
            }
            .padding(14)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            .padding(.horizontal, 20)
        }
    }

    private func loanBadge(_ status: String) -> some View {
        let color: Color = switch status {
        case "貸出可": .green
        case "蔵書あり": .green.opacity(0.7)
        case "貸出中": .orange
        default: .gray
        }
        return Text(status)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Ranking Section

    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("図書館ランキング")
                    .font(.zenMincho(size: 17, weight: .semiBold))
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

    // MARK: - Search Logic

    private func searchBooksInNearbyLibraries() async {
        let query = bookTitle.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        bookSearchState = .loading

        // Step 1: 書籍検索 → ISBNリスト
        let books: [BookSearchResult]
        do {
            books = try await CalilAPIService.shared.searchBooks(title: query)
        } catch {
            bookSearchState = .error("書籍の検索に失敗しました: \(error.localizedDescription)")
            return
        }
        guard !books.isEmpty else {
            bookSearchState = .error("「\(query)」に一致する本が見つかりませんでした")
            return
        }
        let isbns = Array(books.prefix(5).map(\.isbn))

        // Step 2: 近くの図書館を取得
        if let coord = locationManager.coordinate {
            await appState.fetchNearbyLibraries(latitude: coord.latitude, longitude: coord.longitude)
        }
        let nearbyLibs = appState.lastSearchResults.filter { $0.systemId != nil }
        guard !nearbyLibs.isEmpty else {
            bookSearchState = .error("近くの図書館が見つかりません。マップタブで周辺検索か、現在地を有効にしてください")
            return
        }

        // Step 3: systemIdで重複排除し、代表ライブラリをマッピング
        var systemRepresentative: [String: Library] = [:]
        for lib in nearbyLibs {
            guard let sid = lib.systemId, systemRepresentative[sid] == nil else { continue }
            systemRepresentative[sid] = lib
        }
        let uniqueSystemIds = Array(systemRepresentative.keys.prefix(10))

        // Step 4: Calil 蔵書確認
        let response: CalilCheckResponse
        do {
            response = try await CalilAPIService.shared.checkBooks(isbns: isbns, systemIds: uniqueSystemIds)
        } catch {
            bookSearchState = .error("図書館への問い合わせに失敗しました: \(error.localizedDescription)")
            return
        }

        // Step 5: 結果をライブラリにマッピング
        var results: [LibraryBookResult] = []
        for systemId in uniqueSystemIds {
            guard let lib = systemRepresentative[systemId] else { continue }
            var bestStatus = "蔵書なし"
            var reserveURL: String? = nil

            for isbn in isbns {
                guard let sysStatus = response.books[isbn]?[systemId] else { continue }
                if reserveURL == nil { reserveURL = sysStatus.reserveurl }
                for loanStatus in (sysStatus.libkey ?? [:]).values {
                    switch loanStatus {
                    case "貸出可":
                        bestStatus = "貸出可"
                    case "蔵書あり" where bestStatus != "貸出可",
                         "館内のみ" where bestStatus != "貸出可":
                        bestStatus = "蔵書あり"
                    case "貸出中" where bestStatus == "蔵書なし":
                        bestStatus = "貸出中"
                    default:
                        break
                    }
                }
                if bestStatus == "貸出可" { break }
            }
            if bestStatus != "蔵書なし" {
                results.append(LibraryBookResult(
                    library: lib, systemId: systemId,
                    status: bestStatus, reserveURL: reserveURL
                ))
            }
        }

        // 貸出可 → 蔵書あり → 貸出中 の順にソート
        let order = ["貸出可": 0, "蔵書あり": 1, "館内のみ": 1, "貸出中": 2]
        results.sort { (order[$0.status] ?? 3) < (order[$1.status] ?? 3) }
        bookSearchState = .results(results)
    }

    // MARK: - Library Search Logic

    private static let prefectures: [String] = [
        "北海道",
        "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
        "岐阜県", "静岡県", "愛知県", "三重県",
        "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県",
        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ]

    private func extractPrefecture(from query: String) -> String? {
        // フル名前方一致（"東京都" "東京都港区" など）
        if let p = Self.prefectures.first(where: { query == $0 || query.hasPrefix($0) }) { return p }
        // 末尾サフィックスなし（"東京" → "東京都"）
        for p in Self.prefectures where p != "北海道" {
            let short = String(p.dropLast())
            if query == short || query.hasPrefix(short) { return p }
        }
        // 含む検索（"石川県立図書館" など名称中に都道府県が入る場合）
        return Self.prefectures.first { query.contains($0) }
    }

    private func extractCity(from query: String, pref: String) -> String? {
        var q = query
        if q.hasPrefix(pref) {
            q = String(q.dropFirst(pref.count)).trimmingCharacters(in: .whitespaces)
        } else if pref != "北海道" {
            let short = String(pref.dropLast())
            if q.hasPrefix(short) { q = String(q.dropFirst(short.count)).trimmingCharacters(in: .whitespaces) }
        }
        // 残余が市区町村を含む場合のみ city パラメータとして使う
        let hasCityHint = q.contains("市") || q.contains("区") || q.contains("町") || q.contains("村") || q.contains("郡")
        return (hasCityHint && !q.isEmpty) ? q : nil
    }

    private func searchLibraries() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { libraryNameSearchState = .idle; return }
        libraryNameSearchState = .loading

        // ローカルキャッシュを先にフィルタ
        let local = appState.allLibraries.filter {
            $0.name.localizedStandardContains(query) ||
            $0.city.localizedStandardContains(query) ||
            $0.prefecture.localizedStandardContains(query)
        }

        guard let pref = extractPrefecture(from: query) else {
            // 都道府県を検出できない場合はローカル結果のみ
            libraryNameSearchState = .results(local)
            return
        }

        // 都道府県のみ指定の場合は city を渡さない（全件取得）
        let isPrefOnlyQuery = (query == pref || (pref != "北海道" && query == String(pref.dropLast())))
        let cityHint = isPrefOnlyQuery ? nil : extractCity(from: query, pref: pref)

        await appState.fetchLibraries(pref: pref, city: cityHint)
        let apiResults = appState.lastSearchResults

        // 都道府県のみ検索 → 全件、それ以外 → クエリでさらに絞り込む
        let filtered: [Library]
        if isPrefOnlyQuery {
            filtered = apiResults
        } else {
            filtered = apiResults.filter {
                $0.name.localizedStandardContains(query) ||
                $0.city.localizedStandardContains(query) ||
                $0.address.localizedStandardContains(query)
            }
        }

        // ローカル + API を libId で重複排除して結合
        var seen = Set<String>()
        var combined: [Library] = []
        for lib in (filtered + local) {
            let key = lib.libId ?? "\(lib.name)_\(lib.city)"
            if seen.insert(key).inserted { combined.append(lib) }
        }
        libraryNameSearchState = .results(combined)
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
