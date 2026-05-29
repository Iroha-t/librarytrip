import SwiftUI

struct BookRecordsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedSegment = 0
    @State private var showAddBook = false

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
        .sheet(isPresented: $showAddBook) {
            AddBookView()
                .environmentObject(appState)
        }
    }

    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            Color.toshoBrown
            VStack(alignment: .leading, spacing: 12) {
                Text("本の記録")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                if !appState.overdueBooks.isEmpty {
                    overdueBanner
                }

                HStack(spacing: 12) {
                    miniStat(
                        value: "\(appState.borrowedBooks.count)",
                        label: "借り中",
                        icon: "book.circle.fill"
                    )
                    miniStat(
                        value: "\(appState.books.filter { $0.status == .read }.count)",
                        label: "読了",
                        icon: "checkmark.circle.fill"
                    )
                    miniStat(
                        value: "\(appState.books.filter { $0.status == .wantToRead }.count)",
                        label: "読みたい",
                        icon: "star.circle.fill"
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 56)
        }
    }

    private var overdueBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("返却期限を過ぎている本が\(appState.overdueBooks.count)冊あります")
                .font(.caption.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(["借り中", "読了", "読みたい"].indices, id: \.self) { i in
                let labels = ["借り中", "読了", "読みたい"]
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedSegment = i
                    }
                } label: {
                    Text(labels[i])
                        .font(.subheadline)
                        .foregroundColor(selectedSegment == i ? .toshoBrown : .toshoSubtext)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(selectedSegment == i ? .toshoBrown : .clear),
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
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(currentBooks) { book in
                        BookCard(book: book)
                            .padding(.horizontal, 16)
                    }
                    if currentBooks.isEmpty {
                        emptyState
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 80)
            }

            Button {
                showAddBook = true
            } label: {
                Image(systemName: "plus")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.toshoBrown)
                    .clipShape(Circle())
                    .shadow(color: Color.toshoBrown.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 16)
        }
    }

    private var currentBooks: [Book] {
        switch selectedSegment {
        case 0:
            return appState.books.filter { $0.status == .borrowed || $0.status == .reading }
        case 1:
            return appState.books.filter { $0.status == .read || $0.status == .returned }
        case 2:
            return appState.books.filter { $0.status == .wantToRead }
        default:
            return []
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 60)
            Image(systemName: "books.vertical")
                .font(.system(size: 50))
                .foregroundColor(.toshoBrown.opacity(0.3))
            Text("本がありません")
                .font(.headline)
                .foregroundColor(.toshoText)
            Text("右下の＋ボタンから本を登録できます")
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
        }
        .padding(32)
    }

    private func miniStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.white)
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
}

struct BookCard: View {
    let book: Book
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 14) {
            bookCover

            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.subheadline.bold())
                    .foregroundColor(.toshoText)
                    .lineLimit(2)
                Text(book.author)
                    .font(.caption)
                    .foregroundColor(.toshoSubtext)

                GenreChip(genre: book.genre)

                if let dueDate = book.returnDueDate, book.returnedDate == nil {
                    dueDateBadge(dueDate: dueDate, isOverdue: book.isOverdue)
                }

                if !book.memo.isEmpty {
                    Text(book.memo)
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                        .lineLimit(2)
                        .padding(.top, 2)
                }

                if let rating = book.rating {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.toshoAmber)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 6, y: 2)
    }

    private var bookCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [Color.toshoBrown.opacity(0.5), Color.toshoBrown.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 56, height: 80)
            VStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                Text(book.genre.rawValue)
                    .font(.system(size: 7))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func dueDateBadge(dueDate: Date, isOverdue: Bool) -> some View {
        let daysLeft = book.daysUntilDue ?? 0
        let text: String
        if isOverdue {
            text = "返却期限超過"
        } else if daysLeft == 0 {
            text = "今日が返却期限"
        } else {
            text = "返却まで\(daysLeft)日"
        }

        return HStack(spacing: 4) {
            Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "clock")
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundColor(isOverdue ? .red : daysLeft <= 3 ? .orange : .toshoGreen)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((isOverdue ? Color.red : daysLeft <= 3 ? Color.orange : Color.toshoGreen).opacity(0.12))
        .clipShape(Capsule())
    }
}

struct GenreChip: View {
    let genre: BookGenre

    var body: some View {
        Text(genre.rawValue)
            .font(.system(size: 10))
            .foregroundColor(.toshoBrown)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.toshoBrown.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct AddBookView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var author = ""
    @State private var genre: BookGenre = .novel
    @State private var status: BookStatus = .borrowed
    @State private var returnDueDate = Date().addingTimeInterval(60 * 60 * 24 * 14)
    @State private var hasReturnDate = true

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("タイトル", text: $title)
                    TextField("著者名", text: $author)
                    Picker("ジャンル", selection: $genre) {
                        ForEach(BookGenre.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                }
                Section("貸し出し情報") {
                    Picker("状態", selection: $status) {
                        ForEach(BookStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    Toggle("返却期限を設定", isOn: $hasReturnDate)
                    if hasReturnDate {
                        DatePicker("返却期限", selection: $returnDueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("本を登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加") {
                        let book = Book(
                            title: title.isEmpty ? "タイトル未入力" : title,
                            author: author.isEmpty ? "著者未入力" : author,
                            genre: genre,
                            returnDueDate: hasReturnDate ? returnDueDate : nil,
                            status: status
                        )
                        appState.books.append(book)
                        dismiss()
                    }
                    .bold()
                    .foregroundColor(.toshoBrown)
                }
            }
        }
    }
}

#Preview {
    BookRecordsView()
        .environmentObject(AppState())
}
