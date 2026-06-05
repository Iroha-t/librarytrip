import SwiftUI

struct VisitReviewSheet: View {
    let library: Library
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var rating = 3
    @State private var comment = ""
    @State private var selectedTags: Set<LibraryTag> = []
    @State private var isPublic = true
    @State private var visitedDate = Date()
    @State private var isSaving = false
    @State private var isLoading = true

    private var isAlreadyVisited: Bool {
        appState.visitedLibraryIds.contains(library.id)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.toshoCream)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            libraryHeader
                            dateSection
                            ratingSection
                            tagsSection
                            commentSection
                            publicSection
                            if isAlreadyVisited {
                                deleteSection
                            }
                        }
                        .padding(20)
                    }
                    .background(Color.toshoCream)
                }
            }
            .navigationTitle(isAlreadyVisited ? "記録を編集" : "訪問を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                        .foregroundColor(.toshoSubtext)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(width: 50, height: 28)
                        } else {
                            Text("保存")
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.toshoGreen)
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .task { await loadExisting() }
    }

    // MARK: - Sections

    private var libraryHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "building.columns.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
                .background(Color.toshoGreen)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(library.name)
                    .font(.headline)
                    .foregroundColor(.toshoText)
                Text("\(library.prefecture) \(library.city)")
                    .font(.caption)
                    .foregroundColor(.toshoSubtext)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("訪問日", systemImage: "calendar")
                .font(.subheadline.bold())
                .foregroundColor(.toshoText)
            DatePicker("", selection: $visitedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("評価", systemImage: "star")
                .font(.subheadline.bold())
                .foregroundColor(.toshoText)
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { i in
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundColor(i <= rating ? .toshoAmber : .gray.opacity(0.3))
                        .onTapGesture { rating = i }
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("タグ", systemImage: "tag")
                .font(.subheadline.bold())
                .foregroundColor(.toshoText)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                ForEach(LibraryTag.allCases, id: \.rawValue) { tag in
                    let selected = selectedTags.contains(tag)
                    Button {
                        if selected { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tag.icon).font(.caption2)
                            Text(tag.rawValue).font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(selected ? Color.toshoGreen : Color.gray.opacity(0.1))
                        .foregroundColor(selected ? .white : .toshoSubtext)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("コメント", systemImage: "text.bubble")
                .font(.subheadline.bold())
                .foregroundColor(.toshoText)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $comment)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.toshoCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.2))
                    )
                if comment.isEmpty {
                    Text("感想や気づきを書いてみましょう...")
                        .foregroundColor(.gray.opacity(0.4))
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var publicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("公開設定", systemImage: "globe")
                .font(.subheadline.bold())
                .foregroundColor(.toshoText)
            HStack(spacing: 12) {
                publicOptionButton(label: "公開", icon: "globe", selected: isPublic) { isPublic = true }
                publicOptionButton(label: "非公開", icon: "lock.fill", selected: !isPublic) { isPublic = false }
            }
            Text(isPublic ? "レビューはみんなに公開されます" : "レビューは自分だけが見られます")
                .font(.caption)
                .foregroundColor(.toshoSubtext)
        }
    }

    private var deleteSection: some View {
        Button {
            Task {
                await appState.deleteVisit(for: library)
                dismiss()
            }
        } label: {
            Label("訪問記録を削除", systemImage: "trash")
                .font(.subheadline)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func publicOptionButton(
        label: String, icon: String, selected: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.subheadline)
            .foregroundColor(selected ? .white : .toshoSubtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? Color.toshoGreen : Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Logic

    private func loadExisting() async {
        if let existing = await appState.loadMyReview(for: library) {
            rating = existing.rating
            comment = existing.comment
            selectedTags = Set(existing.tags.compactMap { LibraryTag(rawValue: $0) })
            isPublic = existing.isPublic
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: existing.visitedAt) {
                visitedDate = date
            }
        }
        isLoading = false
    }

    private func save() async {
        isSaving = true
        await appState.saveReview(
            for: library,
            rating: rating,
            comment: comment,
            tags: Array(selectedTags),
            isPublic: isPublic,
            visitedAt: visitedDate
        )
        isSaving = false
        dismiss()
    }
}

#Preview {
    VisitReviewSheet(library: Library(
        name: "中央図書館",
        prefecture: "東京都",
        city: "千代田区",
        address: "千代田1-1",
        latitude: 35.6895,
        longitude: 139.6917,
        openingHours: "9:00〜20:00",
        closedDays: "月曜日",
        collectionCount: 500000
    ))
    .environmentObject(AppState())
}
