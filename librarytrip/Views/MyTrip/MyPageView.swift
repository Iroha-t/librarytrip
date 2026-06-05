import SwiftUI

struct MyPageView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showMyTrip = false
    @State private var showBookRecords = false

    private var readCount: Int {
        appState.books.filter { $0.status == .read }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    profileHeader
                        .padding(.top, 16)

                    statsRow
                        .padding(.horizontal, 20)

                    menuSection
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 40)
                }
            }
            .background(Color.toshoCream)
            .navigationTitle("マイページ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundColor(.toshoRed)
                }
            }
        }
        .sheet(isPresented: $showMyTrip) {
            MyTripView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showBookRecords) {
            BookRecordsView()
                .environmentObject(appState)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.toshoRed.opacity(0.10))
                    .frame(width: 76, height: 76)
                Image(systemName: "person.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.toshoRed)
            }
            Text("たびびとさん")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.toshoText)
            Text("図書館をめぐって、本と出会おう")
                .font(.system(size: 12))
                .foregroundColor(.toshoSubtext)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: "\(appState.visitedLibraryIds.count)", label: "訪問")
            divider
            statItem(value: "\(appState.wishlistLibraryIds.count)", label: "保存")
            divider
            statItem(value: "\(readCount)", label: "読了本")
        }
        .padding(.vertical, 16)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 3)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.toshoSubtext.opacity(0.15))
            .frame(width: 1, height: 36)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.toshoRed)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.toshoSubtext)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuRow(
                icon: "checkmark.seal.fill",
                label: "訪問記録",
                description: "訪問した図書館とレビューを見る"
            ) {
                showMyTrip = true
            }
            Divider().padding(.leading, 60)
            menuRow(
                icon: "books.vertical.fill",
                label: "本の記録",
                description: "読んでいる本・読んだ本を管理する"
            ) {
                showBookRecords = true
            }
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 3)
    }

    private func menuRow(icon: String, label: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.toshoRed.opacity(0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(.toshoRed)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.toshoText)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.toshoSubtext)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.toshoSubtext)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
}

#Preview {
    MyPageView()
        .environmentObject(AppState())
}
