import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedLibrary: Library?
    @State private var showMyTrip = false
    @State private var showMyPage = false
    @State private var avatarImage: UIImage?
    @State private var showNearby = false
    @State private var showScanner = false
    @State private var pendingISBN: String?
    @State private var returnBook: ScannedBook?

    /// どれか1つでも画面（シート）が開いているか。
    private var isAnySheetOpen: Bool {
        selectedLibrary != nil || showMyTrip || showMyPage
            || showNearby || showScanner || pendingISBN != nil || returnBook != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    topBar
                    heroSection
                    HomeQuickActions(
                        onNearby: { showNearby = true },
                        onReturn: { showScanner = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    statCards
                    savedLibrariesSection
                    recentVisitsSection
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
        .sheet(isPresented: $showMyTrip) {
            MyTripView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showMyPage, onDismiss: {
            // マイページで変更したアイコン写真をホームにも反映
            avatarImage = AvatarStore.load()
        }) {
            MyPageView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showNearby) {
            NearbyLibrariesSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showScanner, onDismiss: openReturnSheetIfScanned) {
            BarcodeScannerView { isbn in pendingISBN = isbn }
        }
        .sheet(item: $returnBook) { book in
            ReturnBookSheet(isbn: book.isbn)
                .environmentObject(appState)
        }
        .onChange(of: isAnySheetOpen) { _, new in appState.isPresentingDetailSheet = new }
        .onAppear { avatarImage = AvatarStore.load() }
    }

    /// バーコード読み取り画面が閉じたあとに、読み取った本の「返す図書館」画面を開く。
    private func openReturnSheetIfScanned() {
        guard let isbn = pendingISBN else { return }
        pendingISBN = nil
        returnBook = ScannedBook(isbn: isbn)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("としょたび")
                .font(.zenMincho(size: 24, weight: .bold))
                .foregroundColor(.toshoRed)
            Spacer()
            Button {
                showMyPage = true
            } label: {
                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.toshoRed.opacity(0.10))
                            .frame(width: 38, height: 38)
                        Image(systemName: "person.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.toshoRed)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 6)
        .background(Color.toshoCream)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今日は どの図書館へ?")
                .font(.zenMincho(size: 34, weight: .black))
                .foregroundColor(.toshoText)
                .lineSpacing(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 26)
    }

    // MARK: - Stat Cards

    private var statCards: some View {
        HStack(spacing: 12) {
            statCard(number: "\(appState.visitedLibraryIds.count)", label: "訪問した図書館", unit: "館")
            statCard(number: "\(appState.wishlistLibraryIds.count)", label: "保存した図書館", unit: "個")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func statCard(number: String, label: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.toshoSubtext)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(number)
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.toshoRed)
                Text(unit)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.toshoSubtext)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 3)
    }

    // MARK: - Saved Libraries Gallery

    private var savedLibrariesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "保存した図書館", actionLabel: "すべて見る") {
                showMyPage = true
            }

            if appState.wishlistLibraries.isEmpty {
                emptySavedPlaceholder
            } else {
                let saved = appState.wishlistLibraries
                SavedLibrariesProgress(
                    visitedCount: saved.filter { appState.visitedLibraryIds.contains($0.id) }.count,
                    totalCount: saved.count
                )
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(saved.prefix(12)) { library in
                            SavedLibraryCard(
                                library: library,
                                isVisited: appState.visitedLibraryIds.contains(library.id)
                            )
                            .onTapGesture { selectedLibrary = library }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.bottom, 24)
    }

    private var emptySavedPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "bookmark")
                    .font(.system(size: 34))
                    .foregroundColor(.toshoSubtext.opacity(0.4))
                Text("保存した図書館がありません")
                    .font(.system(size: 13))
                    .foregroundColor(.toshoSubtext)
            }
            Spacer()
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
    }

    // MARK: - Recent Visits Section

    private var sortedRecentVisits: [Library] {
        appState.visitedLibraries
            .sorted { a, b in
                let da = visitDate(for: a)
                let db = visitDate(for: b)
                if let da, let db { return da > db }
                return da != nil
            }
            .prefix(6)
            .map { $0 }
    }

    private func visitDate(for library: Library) -> Date? {
        guard let review = appState.review(for: library) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: review.visitedAt)
    }

    private func formattedVisitDate(for library: Library) -> String {
        guard let date = visitDate(for: library) else { return "日付不明" }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "今日" }
        if days == 1 { return "昨日" }
        if days < 7  { return "\(days)日前" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = cal.component(.year, from: date) == cal.component(.year, from: Date())
            ? "M月d日" : "yyyy年M月d日"
        return f.string(from: date)
    }

    private var recentVisitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "最近の訪問", actionLabel: "記録を見る") {
                showMyTrip = true
            }

            if appState.visitedLibraries.isEmpty {
                emptyVisitsPlaceholder
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedRecentVisits.enumerated()), id: \.element.id) { index, library in
                        recentVisitRow(library)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedLibrary = library }
                        if index < sortedRecentVisits.count - 1 {
                            Divider().padding(.leading, 72)
                        }
                    }
                }
                .background(Color.toshoCard)
                .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 3)
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 24)
    }

    private func recentVisitRow(_ library: Library) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((library.category?.color ?? .toshoRed).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: library.category?.icon ?? "building.columns.fill")
                    .font(.system(size: 18))
                    .foregroundColor(library.category?.color ?? .toshoRed)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(library.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.toshoText)
                    .lineLimit(1)
                Text("\(library.prefecture) \(library.city)")
                    .font(.system(size: 11))
                    .foregroundColor(.toshoSubtext)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedVisitDate(for: library))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.toshoSubtext)
                if let review = appState.review(for: library), review.rating > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<review.rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.toshoAmber)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyVisitsPlaceholder: some View {
        HStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 34))
                    .foregroundColor(.toshoSubtext.opacity(0.4))
                Text("まだ訪問した図書館がありません")
                    .font(.system(size: 13))
                    .foregroundColor(.toshoSubtext)
            }
            Spacer()
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, actionLabel: String, onAction: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.zenMincho(size: 17, weight: .semiBold))
                .foregroundColor(.toshoText)
            Spacer()
            Button(action: onAction) {
                Text(actionLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.toshoRed.opacity(0.8))
            }
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
