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

    // フィルタ
    @State private var filterStudy = false
    @State private var filterCafe  = false
    @State private var filterWifi  = false
    @State private var filterPower = false

    // 「この周辺を検索」
    @State private var showSearchHereButton = false
    @State private var lastFetchedCenter: CLLocationCoordinate2D?

    // MARK: - Filtered libraries

    var filteredLibraries: [Library] {
        appState.allLibraries.filter { lib in
            let matchesStudy = !filterStudy || lib.hasStudyRoom
            let matchesCafe  = !filterCafe  || lib.hasCafe
            let matchesWifi  = !filterWifi  || lib.hasWifi
            let matchesPower = !filterPower || lib.hasPowerOutlets
            return matchesStudy && matchesCafe && matchesWifi && matchesPower
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
            overlayLayer
        }
        .sheet(isPresented: $showDetail) {
            if let lib = selectedLibrary {
                LibraryDetailView(library: lib).environmentObject(appState)
            }
        }
        .task {
            await appState.fetchNearbyLibraries(latitude: 35.6762, longitude: 139.6503)
        }
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
        // 地図タップでサジェストを閉じる
        .onTapGesture {
            if isSearchFocused {
                isSearchFocused = false
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

            // 選択中図書館カード
            if let lib = selectedLibrary, !isSearchFocused {
                libraryPreviewCard(lib)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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

            // フィルタチップ（フォーカス中は非表示）
            if !isSearchFocused {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(label: "自習室", icon: "pencil",         isOn: $filterStudy)
                        filterChip(label: "カフェ",  icon: "cup.and.saucer", isOn: $filterCafe)
                        filterChip(label: "Wi-Fi",  icon: "wifi",           isOn: $filterWifi)
                        filterChip(label: "電源",    icon: "bolt",           isOn: $filterPower)
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.toshoGreen.opacity(0.7), Color.toshoGreen],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 70, height: 70)
                    Image(systemName: "building.columns.fill")
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

    private func filterChip(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text(label).font(.caption)
            }
            .foregroundColor(isOn.wrappedValue ? .white : .toshoGreen)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(isOn.wrappedValue ? Color.toshoGreen : Color.toshoCard)
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

    /// テキスト送信 → ジオコーディング → 地図移動 → Calil API 取得
    ///
    /// 優先順位:
    ///   1. pref + city が判明 → `fetchLibraries(pref:city:)` でそのエリア全館取得
    ///   2. pref のみ判明      → `fetchLibraries(pref:)` で都道府県全館取得
    ///   3. それ以外           → geocode で近隣検索
    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        isSearchFocused = false
        suggestions = []
        isGeocoding = true
        geocodeError = nil

        do {
            guard let request = MKGeocodingRequest(addressString: query + " 日本") else {
                throw SearchError.notFound
            }
            let mapItems = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[MKMapItem], any Error>) in
                request.getMapItems { items, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: items ?? []) }
                }
            }
            guard let mapItem = mapItems.first else {
                throw SearchError.notFound
            }

            let coordinate = mapItem.location.coordinate
            let (pref, city, span) = calilParams(from: mapItem, query: query)

            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: span
                ))
            }
            lastFetchedCenter = coordinate
            showSearchHereButton = false

            if let pref {
                // 市区町村 or 都道府県が特定できた → Calil の pref+city API で確実に全館取得
                await appState.fetchLibraries(pref: pref, city: city)
            } else {
                // 施設名・住所など → geocode で近隣検索
                await appState.fetchNearbyLibraries(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
            }
        } catch {
            geocodeError = "「\(query)」の場所が見つかりませんでした"
        }
        isGeocoding = false
    }

    /// MKMapItem の fullAddress から (pref, city?, mapSpan) を解決する
    ///
    /// fullAddress ("〒XXX 東京都渋谷区..." など) の先頭から
    /// 都/道/府/県 で終わる都道府県と、その直後の 市/区/町/村/郡 で終わる市区町村を抽出する。
    /// クエリ自体が 市/区/町/村/郡 で終わる場合はそのまま city として優先使用する。
    private func calilParams(
        from mapItem: MKMapItem,
        query: String
    ) -> (pref: String?, city: String?, span: MKCoordinateSpan) {

        // 郵便番号プレフィックス ("〒XXX-XXXX ") を除いた住所部分
        let raw = mapItem.address?.fullAddress ?? ""
        let address: String
        if let spaceIdx = raw.firstIndex(of: " ") {
            address = String(raw[raw.index(after: spaceIdx)...])
        } else {
            address = raw
        }

        // 都道府県: 先頭 2〜5 文字で 都/道/府/県 で終わる部分を検出
        let prefSuffixes: Set<Character> = ["都", "道", "府", "県"]
        var pref: String?
        for len in 2...5 {
            guard len <= address.count else { break }
            let candidate = String(address.prefix(len))
            if let last = candidate.last, prefSuffixes.contains(last) {
                pref = candidate
                break
            }
        }

        // クエリが市区町村パターンなら自身を city として優先使用
        let isCityQuery = ["市", "区", "町", "村", "郡"].contains { query.hasSuffix($0) }
        var city: String?
        if isCityQuery {
            city = query
        } else if let p = pref {
            let afterPref = String(address.dropFirst(p.count))
            let citySuffixes: Set<Character> = ["市", "区", "町", "村", "郡"]
            for len in 1...8 {
                guard len <= afterPref.count else { break }
                let candidate = String(afterPref.prefix(len))
                if let last = candidate.last, citySuffixes.contains(last) {
                    city = candidate
                    break
                }
            }
        }

        // ズームレベルをエリア粒度に合わせる
        let span: MKCoordinateSpan
        switch (pref, city) {
        case (_, .some):
            // 市区町村レベル — やや狭め
            span = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        case (.some, nil):
            // 都道府県レベル — 広め
            span = MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
        default:
            // 施設・住所レベル — ピンポイント
            span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
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
    }

    enum SearchError: Error { case notFound }
}

// MARK: - Map Pin

struct LibraryMapPin: View {
    let library: Library
    let isSelected: Bool
    let isVisited: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isVisited ? Color.toshoAmber : Color.toshoGreen)
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .shadow(color: (isVisited ? Color.toshoAmber : Color.toshoGreen).opacity(0.4), radius: 4)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundColor(.white)
            }
            Triangle()
                .fill(isVisited ? Color.toshoAmber : Color.toshoGreen)
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
