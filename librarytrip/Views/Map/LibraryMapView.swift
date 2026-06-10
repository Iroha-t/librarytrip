import SwiftUI
import MapKit

struct LibraryMapView: View {
    @EnvironmentObject var appState: AppState
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
    )
    @State private var currentRegion: MKCoordinateRegion?
    @State private var selectedLibrary: Library?
    @State private var showDetail = false

    // 検索
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var suggestions: [Library] = []
    @State private var isGeocoding = false
    @State private var geocodeError: String?
    @State private var showResultsPanel = false
    @State private var searchLabel = ""   // 検索ラベル（例: "杉並区"）

    // カテゴリーフィルタ
    @State private var selectedCategory: LibraryCategory?

    // 「この周辺を検索」
    @State private var showSearchHereButton = false
    @State private var lastFetchedCenter: CLLocationCoordinate2D?

    // 検索済みフラグ（false=ウィッシュリストのみ表示、true=検索結果を表示）
    @State private var hasSearched = false

    // MARK: - Filtered libraries

    var filteredLibraries: [Library] {
        let base: [Library] = hasSearched
            ? appState.lastSearchResults
            : appState.wishlistLibraries

        return base.filter { lib in
            guard let selectedCategory else { return true }
            return lib.category == selectedCategory
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ZStack(alignment: .top) {
                mapLayer
                overlayLayer
            }
            // ピンが0件かつ読み込み中のときだけ中央にスピナーを表示
            if filteredLibraries.isEmpty && (appState.isLoadingLibraries || isGeocoding) {
                centerLoadingOverlay
            }
        }
        .sheet(isPresented: $showDetail) {
            if let lib = selectedLibrary {
                LibraryDetailView(library: lib).environmentObject(appState)
            }
        }
        .onChange(of: showDetail) { _, new in appState.isPresentingDetailSheet = new }
    }

    private var centerLoadingOverlay: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.toshoRed)
                .scaleEffect(1.4)
            Text(isGeocoding ? "場所を検索中..." : "図書館を読み込み中...")
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 16, y: 6)
    }

    // MARK: - Map

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            ForEach(filteredLibraries) { library in
                Annotation(library.name, coordinate: library.coordinate) {
                    LibraryMapPin(
                        library: library,
                        isSelected: selectedLibrary?.id == library.id,
                        isVisited: appState.visitedLibraryIds.contains(library.id)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3)) {
                            isSearchFocused = false
                            selectedLibrary = library
                        }
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .onMapCameraChange(frequency: .onEnd) { context in
            currentRegion = context.region
            let center = context.region.center
            // 前回取得地点から離れたら「この周辺を検索」ボタンを表示
            if let last = lastFetchedCenter {
                let moved = abs(center.latitude - last.latitude)
                            + abs(center.longitude - last.longitude)
                showSearchHereButton = moved > 0.02  // ≒ 約 2km 以上
            }
        }
        .ignoresSafeArea()
        // 地図タップでサジェスト・結果パネルを閉じる
        .onTapGesture {
            if isSearchFocused {
                isSearchFocused = false
            } else if showResultsPanel {
                withAnimation { showResultsPanel = false }
            } else {
                selectedLibrary = nil
            }
        }
    }

    // MARK: - Overlay

    private var overlayLayer: some View {
        VStack(spacing: 0) {
            // 検索バー + フィルタ
            topBar
                .padding(.top, 8)

            // サジェストリスト（検索フォーカス中）
            if isSearchFocused && !suggestions.isEmpty {
                suggestionList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()

            // 「この周辺を検索」ボタン
            if showSearchHereButton && !appState.isLoadingLibraries && !isSearchFocused {
                searchHereButton
                    .transition(.scale.combined(with: .opacity))
                    .padding(.bottom, 4)
            }

            // ローディング
            if appState.isLoadingLibraries {
                loadingBadge
                    .padding(.bottom, 4)
            }

            // エラー（ジオコーディング失敗 or API失敗）
            if let err = geocodeError ?? appState.apiError {
                errorBadge(err) {
                    geocodeError = nil
                    appState.apiError = nil
                }
                .padding(.bottom, 4)
            }

            // 検索結果リストパネル
            if showResultsPanel && !isSearchFocused && selectedLibrary == nil {
                searchResultsPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // 選択中図書館カード
            if let lib = selectedLibrary, !isSearchFocused {
                libraryPreviewCard(lib)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // タブバー分（高さ60 + bottom padding 10 + 余白8 = 78）だけ底上げ
        .padding(.bottom, 100)
    }

    // MARK: - Top bar

    private var topBar: some View {
        VStack(spacing: 8) {
            // 検索バー
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    if isGeocoding {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(isSearchFocused ? .toshoGreen : .toshoSubtext)
                    }

                    TextField("図書館名・市区町村・都道府県", text: $searchText)
                        .font(.subheadline)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onChange(of: searchText) { _, newValue in
                            updateSuggestions(for: newValue)
                            geocodeError = nil
                        }
                        .onSubmit {
                            Task { await search() }
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            suggestions = []
                            geocodeError = nil
                            hasSearched = false
                            showResultsPanel = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.toshoSubtext)
                        }
                    }
                }
                .padding(12)
                .background(Color.toshoCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)

                // キャンセルボタン（フォーカス時）
                if isSearchFocused {
                    Button("キャンセル") {
                        searchText = ""
                        suggestions = []
                        isSearchFocused = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.toshoGreen)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.2), value: isSearchFocused)

            // カテゴリーフィルタチップ（フォーカス中は非表示）
            if !isSearchFocused {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LibraryCategory.allCases, id: \.self) { cat in
                            categoryChip(cat)
                        }
                        // 件数バッジ
                        Text("\(filteredLibraries.count)件")
                            .font(.caption)
                            .foregroundColor(.toshoSubtext)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.toshoCard)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.07), radius: 4, y: 1)
                    }
                    .padding(.horizontal, 16)
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: - Suggestion list

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(suggestions) { lib in
                Button {
                    selectSuggestion(lib)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "building.columns.fill")
                            .font(.subheadline)
                            .foregroundColor(.toshoGreen)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lib.name)
                                .font(.subheadline)
                                .foregroundColor(.toshoText)
                            Text("\(lib.prefecture) \(lib.city)")
                                .font(.caption)
                                .foregroundColor(.toshoSubtext)
                        }
                        Spacer()
                        Image(systemName: "mappin.circle")
                            .font(.caption)
                            .foregroundColor(.toshoSubtext)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                if lib.id != suggestions.last?.id {
                    Divider().padding(.leading, 56)
                }
            }

            // 地名検索の誘導行
            if !searchText.isEmpty {
                Divider()
                Button {
                    Task { await search() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundColor(.toshoGreen)
                            .frame(width: 28)
                        Text("「\(searchText)」周辺の図書館を地図で検索")
                            .font(.subheadline)
                            .foregroundColor(.toshoGreen)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Search here button

    private var searchHereButton: some View {
        Button {
            Task { await searchCurrentArea() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.bold())
                Text("この周辺を検索")
                    .font(.subheadline.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.toshoGreen)
            .clipShape(Capsule())
            .shadow(color: Color.toshoGreen.opacity(0.4), radius: 8, y: 3)
        }
    }

    // MARK: - Loading / Error badges

    private var loadingBadge: some View {
        HStack(spacing: 8) {
            ProgressView().progressViewStyle(.circular).scaleEffect(0.8)
            Text("図書館情報を取得中...")
                .font(.caption)
                .foregroundColor(.toshoText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.toshoCard)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }

    private func errorBadge(_ message: String, onDismiss: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundColor(.toshoText)
                .lineLimit(2)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.toshoSubtext)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.toshoCard)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    // MARK: - Library preview card

    private func libraryPreviewCard(_ library: Library) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            HStack(spacing: 14) {
                ZStack {
                    let cardColor = library.category?.color ?? .toshoGreen
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [cardColor.opacity(0.7), cardColor],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 70, height: 70)
                    Image(systemName: library.category?.icon ?? "building.columns.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(library.name)
                        .font(.headline).foregroundColor(.toshoText).lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption).foregroundColor(.toshoGreen)
                        Text(library.address)
                            .font(.caption).foregroundColor(.toshoSubtext).lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        if library.rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.caption2).foregroundColor(.toshoAmber)
                                Text(String(format: "%.1f", library.rating))
                                    .font(.caption.bold())
                            }
                            Text("·").foregroundColor(.toshoSubtext)
                        }
                        Text(library.openingHours)
                            .font(.caption).foregroundColor(.toshoSubtext)
                    }

                    HStack(spacing: 8) {
                        miniFeature(show: library.hasStudyRoom,    icon: "pencil",         label: "自習室")
                        miniFeature(show: library.hasPowerOutlets, icon: "bolt",           label: "電源")
                        miniFeature(show: library.hasWifi,         icon: "wifi",           label: "Wi-Fi")
                        miniFeature(show: library.hasCafe,         icon: "cup.and.saucer", label: "カフェ")
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        appState.toggleWishlist(library)
                    } label: {
                        Image(systemName: appState.wishlistLibraryIds.contains(library.id)
                              ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.toshoGreen)
                    }
                    Button { showDetail = true } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundColor(.toshoSubtext)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Sub-views

    private func categoryChip(_ category: LibraryCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            let next = isSelected ? nil : category
            selectedCategory = next
            // 未検索の状態でカテゴリを選んだら現在地周辺を即時取得する
            if next != nil && !hasSearched {
                Task { await searchCurrentArea() }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: category.icon).font(.caption)
                Text(category.label).font(.caption)
            }
            .foregroundColor(isSelected ? .white : category.color)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isSelected ? category.color : Color.toshoCard)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.07), radius: 4, y: 1)
        }
    }

    private func miniFeature(show: Bool, icon: String, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 9))
            Text(label).font(.system(size: 9))
        }
        .foregroundColor(show ? .toshoGreen : Color.gray.opacity(0.3))
    }

    // MARK: - Search logic

    /// 入力テキストからサジェストを更新（既存ロード済みデータを絞り込む）
    private func updateSuggestions(for text: String) {
        guard !text.isEmpty else { suggestions = []; return }
        suggestions = appState.allLibraries
            .filter {
                $0.name.localizedCaseInsensitiveContains(text)
                || $0.prefecture.contains(text)
                || $0.city.localizedCaseInsensitiveContains(text)
                || $0.address.localizedCaseInsensitiveContains(text)
            }
            .prefix(5)
            .map { $0 }
    }

    /// サジェストから図書館を選択 → 地図をその位置へ移動
    private func selectSuggestion(_ library: Library) {
        isSearchFocused = false
        searchText = library.name
        suggestions = []
        selectedLibrary = library
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(
                center: library.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
        }
    }

    /// テキスト送信 → ジオコーディング → API取得 → カメラ移動（データ取得後に移動）→ 結果パネル表示
    ///
    /// カメラを動かす前にデータを取得する理由:
    ///   SwiftUI Map は「カメラ移動アニメーション中に ForEach データが変わっても
    ///   新しい Annotation を描画しない」という挙動がある。
    ///   データが揃った状態でカメラを移動すれば、移動先でピンが即座に表示される。
    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        print("[Search] ▶️ 開始 query='\(query)'")

        isSearchFocused = false
        suggestions = []
        isGeocoding = true
        geocodeError = nil
        showResultsPanel = false

        do {
            // ── STEP 1: ジオコーディング ──────────────────────────────
            guard let request = MKGeocodingRequest(addressString: query + " 日本") else {
                throw SearchError.notFound
            }
            let mapItems: [MKMapItem] = try await withCheckedThrowingContinuation { cont in
                request.getMapItems { items, error in
                    if let error { cont.resume(throwing: error) }
                    else { cont.resume(returning: items ?? []) }
                }
            }
            print("[Search] ジオコーディング結果 \(mapItems.count)件")
            guard let mapItem = mapItems.first else {
                print("[Search] ❌ mapItems 空")
                throw SearchError.notFound
            }

            let coordinate = mapItem.location.coordinate
            let addressReps = mapItem.addressRepresentations
            let locality = addressReps?.cityName
            let administrativeArea = Self.extractPrefecture(
                from: addressReps?.fullAddress(includingRegion: false, singleLine: true)
            )
            print("[Search] address: adminArea='\(administrativeArea ?? "nil")' locality='\(locality ?? "nil")'")
            print("[Search] coordinate: lat=\(coordinate.latitude) lon=\(coordinate.longitude)")

            let (_, _, span) = calilParams(administrativeArea: administrativeArea, locality: locality, query: query)

            lastFetchedCenter    = coordinate
            showSearchHereButton = false

            // ── STEP 2: データ取得（カメラはまだ動かさない）────────────
            // geocode ベースの近隣検索を使うことで全件に座標が付き、ピンが正確な位置に立つ
            print("[Search] → fetchNearbyLibraries(lat:\(coordinate.latitude), lon:\(coordinate.longitude)) を呼ぶ")
            await appState.fetchNearbyLibraries(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            print("[Search] fetch完了 lastSearchResults=\(appState.lastSearchResults.count)件")

            // ── STEP 3: データが揃った状態でカメラを移動 ────────────────
            // ここで移動するとピンが既に filteredLibraries に入っており
            // Map は描画先が決まった時点で全ピンを一度に描画する
            withAnimation(.easeInOut(duration: 0.5)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: span
                ))
            }

            // ── STEP 4: 結果パネル表示 ────────────────────────────────
            if !appState.lastSearchResults.isEmpty {
                hasSearched = true
                searchLabel = query
                withAnimation(.spring(response: 0.4)) {
                    showResultsPanel = true
                }
                print("[Search] ✅ 結果パネル表示 \(appState.lastSearchResults.count)件")
            } else {
                print("[Search] ⚠️ 結果0件 → エラー表示")
                geocodeError = "「\(query)」周辺に図書館が見つかりませんでした"
            }
        } catch {
            print("[Search] ❌ error: \(error)")
            geocodeError = "「\(query)」の場所が見つかりませんでした"
        }
        isGeocoding = false
        print("[Search] ⏹ 終了")
    }

    /// 住所文字列から都道府県名（都/道/府/県で終わる部分）を抽出する
    private static func extractPrefecture(from address: String?) -> String? {
        guard let address else { return nil }
        // 漢字・ひらがな・カタカナ 2〜4 文字 + 都/道/府/県 にマッチ
        guard let regex = try? NSRegularExpression(pattern: "[\\u4e00-\\u9fff\\u3040-\\u30ff]{2,4}[都道府県]"),
              let match = regex.firstMatch(in: address, range: NSRange(address.startIndex..., in: address)),
              let range = Range(match.range, in: address)
        else { return nil }
        return String(address[range])
    }

    /// query の末尾パターンと placemark から Calil API の pref/city を決定する
    ///
    /// ポイント: geocoder の administrativeArea はロケールによって英語になることがあるため、
    /// query 自体が都道府県名・市区町村名のときは query を直接使う。
    ///
    /// | query の末尾 | pref         | city          | 例                      |
    /// |-------------|-------------|---------------|------------------------|
    /// | 都/道/府/県  | query をそのまま | nil（県全体）  | "石川県" → pref=石川県   |
    /// | 市/区/町/村/郡 | geocoder    | query をそのまま | "杉並区" → city=杉並区  |
    /// | それ以外      | geocoder    | geocoder locality | "渋谷" "図書館" など   |
    private func calilParams(
        administrativeArea: String?,
        locality: String?,
        query: String
    ) -> (pref: String?, city: String?, span: MKCoordinateSpan) {

        let isPrefQuery  = ["都", "道", "府", "県"].contains { query.hasSuffix($0) }
        let isCityQuery  = ["市", "区", "町", "村", "郡"].contains { query.hasSuffix($0) }

        let pref: String?
        let city: String?

        if isPrefQuery {
            // "石川県"・"東京都" など → query そのものを pref に、city は不要
            pref = query
            city = nil
        } else if isCityQuery {
            // "杉並区"・"金沢市" など → geocoder で都道府県を取得し、city は query
            pref = administrativeArea
            city = query
        } else {
            // 施設名・住所・略称 → 両方 geocoder に任せる
            pref = administrativeArea
            city = locality
        }

        print("[Search] calilParams決定 isPref=\(isPrefQuery) isCity=\(isCityQuery) pref='\(pref ?? "nil")' city='\(city ?? "nil")'")

        let span: MKCoordinateSpan
        switch (isPrefQuery, isCityQuery) {
        case (true, _):
            // 都道府県全体 → 広いズーム
            span = MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        case (_, true):
            // 市区町村 → 中程度
            span = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        default:
            // 施設・住所 → ピンポイント
            span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        }
        return (pref, city, span)
    }

    /// 現在の地図中心付近を検索
    private func searchCurrentArea() async {
        guard let region = currentRegion else { return }
        let center = region.center
        lastFetchedCenter = center
        showSearchHereButton = false
        await appState.fetchNearbyLibraries(latitude: center.latitude, longitude: center.longitude)
        if !appState.lastSearchResults.isEmpty {
            hasSearched = true
        }
    }

    enum SearchError: Error { case notFound }

    // MARK: - Search Results Panel

    private var searchResultsPanel: some View {
        VStack(spacing: 0) {
            // ハンドル
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            // ヘッダー
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("「\(searchLabel)」の図書館")
                        .font(.headline)
                        .foregroundColor(.toshoText)
                    Text("\(appState.lastSearchResults.count)件見つかりました")
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showResultsPanel = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // リスト
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.lastSearchResults) { library in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showResultsPanel = false
                                selectedLibrary = library
                                cameraPosition = .region(MKCoordinateRegion(
                                    center: library.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                                ))
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: library.category?.icon ?? "building.columns.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        appState.visitedLibraryIds.contains(library.id)
                                            ? Color.toshoAmber : (library.category?.color ?? .toshoGreen)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(library.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.toshoText)
                                        .lineLimit(1)
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.caption2)
                                            .foregroundColor(.toshoGreen)
                                        Text(library.address)
                                            .font(.caption)
                                            .foregroundColor(.toshoSubtext)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.toshoSubtext)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .frame(maxHeight: 340)
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 16, y: -4)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Map Pin

struct LibraryMapPin: View {
    let library: Library
    let isSelected: Bool
    let isVisited: Bool

    private var pinColor: Color {
        isVisited ? .toshoAmber : (library.category?.color ?? .toshoGreen)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(pinColor)
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .shadow(color: pinColor.opacity(0.4), radius: 4)
                Image(systemName: library.category?.icon ?? "building.columns.fill")
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundColor(.white)
            }
            Triangle()
                .fill(pinColor)
                .frame(width: 10, height: 6)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    LibraryMapView()
        .environmentObject(AppState())
}
