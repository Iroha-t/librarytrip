import SwiftUI

struct LibraryRecordPickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedLibrary: Library?

    private var displayedLibraries: [Library] {
        let all = appState.allLibraries
        guard !searchText.isEmpty else { return all }
        return all.filter {
            $0.name.contains(searchText) ||
            $0.city.contains(searchText) ||
            $0.prefecture.contains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.top, 8)

                if displayedLibraries.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.toshoSubtext.opacity(0.4))
                        Text("図書館が見つかりません")
                            .font(.system(size: 14))
                            .foregroundColor(.toshoSubtext)
                    }
                    Spacer()
                } else {
                    List(displayedLibraries) { library in
                        Button {
                            selectedLibrary = library
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.toshoRed.opacity(0.10))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.toshoRed)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(library.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.toshoText)
                                    Text("\(library.prefecture) \(library.city)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.toshoSubtext)
                                }
                                Spacer()
                                if appState.visitedLibraryIds.contains(library.id) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.toshoRed.opacity(0.6))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.toshoCream)
            .navigationTitle("図書館を選んで記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(.toshoRed)
                }
            }
        }
        .sheet(item: $selectedLibrary) { lib in
            VisitReviewSheet(library: lib)
                .environmentObject(appState)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.toshoSubtext)
            TextField("図書館名・地名で検索", text: $searchText)
                .font(.subheadline)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    LibraryRecordPickerView()
        .environmentObject(AppState())
}
