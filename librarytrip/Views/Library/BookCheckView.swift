import SwiftUI

struct BookCheckView: View {
    let library: Library
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var titleInput = ""
    @State private var viewState: CheckViewState = .idle

    enum CheckViewState {
        case idle
        case searching
        case bookList([BookSearchResult])
        case checking(BookSearchResult)
        case result(CalilCheckResponse, isbn: String)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    libraryHeader
                    inputSection
                    stateContent
                }
                .padding(16)
            }
            .background(Color.toshoCream)
            .navigationTitle("蔵書確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(.toshoGreen)
                }
            }
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private var stateContent: some View {
        switch viewState {
        case .idle:
            EmptyView()
        case .searching:
            loadingCard(message: "本を検索中...")
        case .bookList(let books):
            bookListSection(books)
        case .checking(let book):
            VStack(spacing: 12) {
                selectedBookCard(book)
                loadingCard(message: "図書館に問い合わせ中...\nカーリルAPIにより照会しています（最大数秒かかることがあります）")
            }
        case .result(let response, let isbn):
            resultSection(response, isbn: isbn)
        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - Header

    private var libraryHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.toshoGreen)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(library.name)
                    .font(.headline)
                    .foregroundColor(.toshoText)
                Text("\(library.prefecture) \(library.city)")
                    .font(.caption)
                    .foregroundColor(.toshoSubtext)
            }
        }
        .padding(14)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 6, y: 2)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本のタイトルで検索")
                .font(.headline)
                .foregroundColor(.toshoText)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.toshoSubtext)
                    TextField("例: 吾輩は猫である", text: $titleInput)
                        .font(.subheadline)
                        .submitLabel(.search)
                        .onSubmit { Task { await runSearch() } }
                }
                .padding(12)
                .background(Color.toshoCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.toshoGreen.opacity(0.4), lineWidth: 1))

                Button {
                    Task { await runSearch() }
                } label: {
                    Text("検索")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(titleInput.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.gray.opacity(0.4) : Color.toshoGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(titleInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Text("タイトルで本を検索し、蔵書状況を確認したい本を選んでください")
                .font(.caption)
                .foregroundColor(.toshoSubtext)
        }
    }

    // MARK: - Book List

    private func bookListSection(_ books: [BookSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("検索結果 \(books.count)件")
                .font(.headline)
                .foregroundColor(.toshoText)

            if books.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundColor(.toshoSubtext)
                    Text("該当する本が見つかりませんでした")
                        .font(.subheadline)
                        .foregroundColor(.toshoSubtext)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color.toshoCard)
                .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            } else {
                ForEach(books) { book in
                    Button {
                        Task { await runCheck(for: book) }
                    } label: {
                        bookRow(book)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func bookRow(_ book: BookSearchResult) -> some View {
        HStack(spacing: 12) {
            bookCoverView(book, width: 44, height: 60)

            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.toshoText)
                    .lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                        .lineLimit(1)
                }
                if !book.publisher.isEmpty {
                    Text(book.publisher)
                        .font(.caption)
                        .foregroundColor(.toshoSubtext.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.toshoSubtext)
        }
        .padding(12)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 4, y: 1)
    }

    private func selectedBookCard(_ book: BookSearchResult) -> some View {
        HStack(spacing: 12) {
            bookCoverView(book, width: 44, height: 60)
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.toshoText)
                    .lineLimit(2)
                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 4, y: 1)
    }

    @ViewBuilder
    private func bookCoverView(_ book: BookSearchResult, width: CGFloat, height: CGFloat) -> some View {
        if let raw = book.coverURL,
           let url = URL(string: raw.replacingOccurrences(of: "http://", with: "https://")) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    coverPlaceholder
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            coverPlaceholder
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var coverPlaceholder: some View {
        ZStack {
            Color.toshoGreen.opacity(0.8)
            Image(systemName: "book.closed.fill")
                .font(.title3)
                .foregroundColor(.white)
        }
    }

    // MARK: - Result

    private func resultSection(_ result: CalilCheckResponse, isbn: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("確認結果")
                    .font(.headline)
                    .foregroundColor(.toshoText)
                Spacer()
                Button {
                    Task { await runSearch() }
                } label: {
                    Label("別の本を選ぶ", systemImage: "arrow.left")
                        .font(.caption)
                        .foregroundColor(.toshoGreen)
                }
            }

            let availabilities = result.availabilities(for: isbn)
            if availabilities.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundColor(.toshoSubtext)
                    Text("この図書館では蔵書が見つかりませんでした")
                        .font(.subheadline)
                        .foregroundColor(.toshoSubtext)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color.toshoCard)
                .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            } else {
                ForEach(availabilities) { avail in
                    availabilityCard(avail)
                }
            }
        }
    }

    private func availabilityCard(_ avail: LibraryAvailability) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                statusBadge(avail.status)
                Spacer()
                if let url = avail.reserveURL, let parsedURL = URL(string: url) {
                    Link(destination: parsedURL) {
                        Label("予約する", systemImage: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.toshoGreen)
                    }
                }
            }
            if avail.availability.isEmpty {
                Text("蔵書なし")
                    .font(.subheadline)
                    .foregroundColor(.toshoSubtext)
            } else {
                ForEach(avail.availability.sorted(by: { $0.key < $1.key }), id: \.key) { libName, status in
                    HStack {
                        Text(libName)
                            .font(.subheadline)
                            .foregroundColor(.toshoText)
                        Spacer()
                        loanStatusBadge(status)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 6, y: 2)
    }

    // MARK: - Badges

    private func statusBadge(_ status: LibraryAvailability.CheckStatus) -> some View {
        let (label, color): (String, Color) = switch status {
        case .ok:      ("確認完了", .toshoGreen)
        case .cache:   ("キャッシュ", .toshoGreen.opacity(0.7))
        case .running: ("照会中", .orange)
        case .error:   ("エラー", .red)
        }
        return Text(label)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func loanStatusBadge(_ status: String) -> some View {
        let color: Color = switch status {
        case "貸出可":   .toshoGreen
        case "蔵書あり": .toshoGreen.opacity(0.7)
        case "館内のみ": .blue
        case "貸出中":   .orange
        case "予約中":   .orange
        case "準備中":   .orange
        case "休館中":   .gray
        default:         .gray
        }
        return Text(status)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Common

    private func loadingCard(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.toshoGreen)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.toshoText)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
    }

    // MARK: - Logic

    private func runSearch() async {
        let query = titleInput.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        viewState = .searching
        do {
            let books = try await CalilAPIService.shared.searchBooks(title: query)
            viewState = .bookList(books)
        } catch {
            viewState = .error("書籍の検索に失敗しました: \(error.localizedDescription)")
        }
    }

    private func runCheck(for book: BookSearchResult) async {
        guard let systemId = library.systemId else {
            viewState = .error("この図書館はカーリル蔵書確認に対応していません")
            return
        }
        viewState = .checking(book)
        let result = await appState.checkBookAvailability(isbn: book.isbn, systemIds: [systemId])
        if let result {
            viewState = .result(result, isbn: book.isbn)
        } else {
            viewState = .error(appState.apiError ?? "蔵書の確認に失敗しました")
        }
    }
}

#Preview {
    BookCheckView(library: Library(
        name: "東京都立中央図書館",
        prefecture: "東京都",
        city: "港区",
        address: "港区南麻布5-7-13",
        latitude: 35.6497,
        longitude: 139.7284,
        openingHours: "9:00〜20:00",
        closedDays: "月曜日",
        collectionCount: 1_800_000,
        systemId: "Tokyo_Pref"
    ))
    .environmentObject(AppState())
}
