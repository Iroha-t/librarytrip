import SwiftUI

/// バーコードで読み取った本（ISBN）。画面を開くための目印として使う。
struct ScannedBook: Identifiable {
    let isbn: String

    var id: String { isbn }
}

/// 読み取った本を扱っている、現在地に近い図書館を一覧にして見せる画面。
struct ReturnBookSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ReturnBookViewModel
    @State private var selectedLibrary: Library?

    init(isbn: String) {
        _viewModel = State(initialValue: ReturnBookViewModel(isbn: isbn))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    bookBanner
                    content
                    Text("※返却できるかどうかは、各図書館の公式サイトなどで確認してください")
                        .font(.caption2)
                        .foregroundColor(.toshoSubtext)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.toshoCream)
            .navigationTitle("本を返す図書館")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(.toshoRed)
                }
            }
        }
        .task { await viewModel.load() }
        .sheet(item: $selectedLibrary) { library in
            LibraryDetailView(library: library)
                .environmentObject(appState)
        }
    }

    /// 読み取った本のタイトルなどを見せる帯。本の情報が取れるまでは ISBN を表示する。
    private var bookBanner: some View {
        HStack(spacing: 12) {
            cover
                .frame(width: 36, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.book?.title ?? "ISBN: \(viewModel.isbn)")
                    .font(.subheadline.bold())
                    .foregroundColor(.toshoText)
                    .lineLimit(2)
                if let author = viewModel.book?.author, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(Color.toshoRedLight)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.smallCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var cover: some View {
        if let raw = viewModel.book?.coverURL,
           let url = URL(string: raw.replacingOccurrences(of: "http://", with: "https://")) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    coverPlaceholder
                }
            }
        } else {
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        ZStack {
            Color.toshoRed.opacity(0.75)
            Image(systemName: "book.closed.fill")
                .font(.footnote)
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading(let message):
            LoadingCard(message: message)

        case .failed(let message):
            ErrorCard(message: message) {
                Task { await viewModel.load() }
            }

        case .loaded(let candidates):
            if candidates.isEmpty {
                emptyView
            } else {
                candidateList(candidates)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.toshoSubtext)
            Text("近くに、この本を扱っている図書館が見つかりませんでした")
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
    }

    private func candidateList(_ candidates: [ReturnBookViewModel.Candidate]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                Button { selectedLibrary = candidate.nearby.library } label: {
                    row(candidate)
                }
                .buttonStyle(.plain)
                if index < candidates.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 8, y: 2)
    }

    private func row(_ candidate: ReturnBookViewModel.Candidate) -> some View {
        let library = candidate.nearby.library
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(library.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.toshoText)
                    .lineLimit(1)
                Text("\(library.prefecture) \(library.city)")
                    .font(.caption)
                    .foregroundColor(.toshoSubtext)
            }
            Spacer()
            Text(candidate.nearby.distanceText)
                .font(.caption.bold())
                .foregroundColor(.toshoRed)
            LoanStatusBadge(status: candidate.status)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.toshoSubtext)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    ReturnBookSheet(isbn: "9784101010014")
        .environmentObject(AppState())
}
