import SwiftUI

/// カーリルAPIを使った蔵書確認シート
struct BookCheckView: View {
    let library: Library
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var isbnInput = ""
    @State private var checkResult: CalilCheckResponse?
    @State private var isChecking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    libraryHeader
                    inputSection
                    if isChecking {
                        checkingView
                    } else if let result = checkResult {
                        resultSection(result)
                    } else if let error = errorMessage {
                        errorView(error)
                    }
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

    // MARK: - Views

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

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ISBN で蔵書を検索")
                .font(.headline)
                .foregroundColor(.toshoText)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "barcode")
                        .foregroundColor(.toshoSubtext)
                    TextField("例: 9784062748681", text: $isbnInput)
                        .keyboardType(.numberPad)
                        .font(.subheadline)
                }
                .padding(12)
                .background(Color.toshoCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.toshoGreen.opacity(0.4), lineWidth: 1)
                )

                Button {
                    Task { await runCheck() }
                } label: {
                    Text("確認")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(isbnInput.isEmpty ? Color.gray.opacity(0.4) : Color.toshoGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isbnInput.isEmpty || isChecking)
            }

            Text("ISBNは本の裏表紙のバーコード下に記載されている13桁の番号です")
                .font(.caption)
                .foregroundColor(.toshoSubtext)
        }
    }

    private var checkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.toshoGreen)
            Text("図書館に問い合わせ中...")
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
            Text("カーリルAPIにより照会しています（最大数秒かかることがあります）")
                .font(.caption)
                .foregroundColor(.toshoSubtext)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
    }

    private func resultSection(_ result: CalilCheckResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("確認結果")
                .font(.headline)
                .foregroundColor(.toshoText)

            let cleanIsbn = normalizedISBN
            let availabilities = result.availabilities(for: cleanIsbn)

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

    private var normalizedISBN: String {
        isbnInput.filter { $0.isNumber }
    }

    private func runCheck() async {
        guard let systemId = library.systemId else { return }
        let isbn = normalizedISBN
        guard isbn.count == 13 || isbn.count == 10 else {
            errorMessage = "ISBNは10桁または13桁で入力してください"
            return
        }
        isChecking = true
        checkResult = nil
        errorMessage = nil

        let result = await appState.checkBookAvailability(isbn: isbn, systemIds: [systemId])
        if let result {
            checkResult = result
        } else {
            errorMessage = appState.apiError ?? "蔵書の確認に失敗しました"
        }
        isChecking = false
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
