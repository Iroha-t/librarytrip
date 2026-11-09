import SwiftUI

/// 現在地から近い図書館を、距離つきで一覧にして見せる画面。
struct NearbyLibrariesSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = NearbyLibrariesViewModel()
    @State private var selectedLibrary: Library?

    var body: some View {
        NavigationStack {
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
            }
            .background(Color.toshoCream)
            .navigationTitle("近くの図書館")
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

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading(let message):
            LoadingCard(message: message)

        case .failed(let message):
            ErrorCard(message: message) {
                Task { await viewModel.load() }
            }

        case .loaded(let items):
            if items.isEmpty {
                emptyView
            } else {
                libraryList(items)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.toshoSubtext)
            Text("近くに図書館が見つかりませんでした")
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
    }

    private func libraryList(_ items: [NearbyLibrary]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button { selectedLibrary = item.library } label: {
                    row(item, rank: index + 1)
                }
                .buttonStyle(.plain)
                if index < items.count - 1 {
                    Divider().padding(.leading, 60)
                }
            }
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 8, y: 2)
    }

    private func row(_ item: NearbyLibrary, rank: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.toshoRed.opacity(rank == 1 ? 0.9 : 0.12))
                    .frame(width: 30, height: 30)
                Text("\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(rank == 1 ? .white : .toshoRed)
            }

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
            Text(item.distanceText)
                .font(.caption.bold())
                .foregroundColor(.toshoRed)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.toshoRed.opacity(0.10))
                .clipShape(Capsule())
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.toshoSubtext)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    NearbyLibrariesSheet()
        .environmentObject(AppState())
}
