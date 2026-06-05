import SwiftUI
import MapKit

struct LibraryDetailView: View {
    let library: Library
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var showVisitReviewSheet = false
    @State private var showBookCheck = false
    @State private var publicReviews: [ReviewRow] = []
    @State private var isLoadingReviews = false
    @State private var appleMapItem: MKMapItem?
    @State private var showAppleMapDetail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                    infoSection
                    if library.hasStudyRoom || library.hasPowerOutlets || library.hasWifi || library.hasCafe {
                        featuresSection
                    }
                    tagsSection
                    if library.systemId != nil {
                        bookCheckBanner
                    }
                    mapPreviewSection
                    reviewsSection
                }
            }
            .background(Color.toshoCream)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            appState.toggleWishlist(library)
                        } label: {
                            Image(systemName: appState.wishlistLibraryIds.contains(library.id) ? "bookmark.fill" : "bookmark")
                                .foregroundColor(.white)
                        }
                        Button {
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showBookCheck) {
            BookCheckView(library: library)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showVisitReviewSheet) {
            VisitReviewSheet(library: library)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showAppleMapDetail) {
            if let appleMapItem {
                MapItemDetailSheet(mapItem: appleMapItem)
            }
        }
        .task {
            isLoadingReviews = true
            publicReviews = await appState.loadPublicReviews(for: library)
            isLoadingReviews = false

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = library.name
            request.region = MKCoordinateRegion(
                center: library.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            request.resultTypes = .pointOfInterest
            if let response = try? await MKLocalSearch(request: request).start() {
                appleMapItem = response.mapItems.first
            }
        }
    }

    // MARK: - 蔵書確認バナー

    private var bookCheckBanner: some View {
        Button {
            showBookCheck = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "books.vertical.circle.fill")
                    .font(.title2)
                    .foregroundColor(.toshoGreen)
                VStack(alignment: .leading, spacing: 3) {
                    Text("この図書館の蔵書を確認")
                        .font(.subheadline.bold())
                        .foregroundColor(.toshoText)
                    Text("ISBNを入力して貸出状況をチェック")
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.toshoSubtext)
            }
            .padding(16)
            .background(Color.toshoCard)
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 6, y: 2)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.toshoGreen.opacity(0.5), Color.toshoGreen.opacity(0.9)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .frame(height: 260)

            VStack(alignment: .center, spacing: 0) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.25))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(library.prefecture)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                    if appState.visitedLibraryIds.contains(library.id) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.caption2)
                            Text("訪問済み")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.toshoAmber.opacity(0.8))
                        .clipShape(Capsule())
                    }
                }

                Text(library.name)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.subheadline)
                        .foregroundColor(.toshoAmber)
                    Text(String(format: "%.1f", library.rating))
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("(\(library.reviewCount)件のレビュー)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Button {
                    showVisitReviewSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: appState.visitedLibraryIds.contains(library.id) ? "pencil.circle.fill" : "plus.circle.fill")
                        Text(appState.visitedLibraryIds.contains(library.id) ? "記録を編集する" : "訪問済みに記録する")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(appState.visitedLibraryIds.contains(library.id) ? .toshoGreen : .white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(appState.visitedLibraryIds.contains(library.id) ? Color.white : Color.toshoAmber)
                    .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var infoSection: some View {
        VStack(spacing: 0) {
            infoRow(icon: "clock", label: "開館時間", value: library.openingHours)
            Divider().padding(.leading, 52)
            infoRow(icon: "calendar.badge.minus", label: "休館日", value: library.closedDays)
            Divider().padding(.leading, 52)
            infoRow(icon: "mappin.and.ellipse", label: "住所", value: library.address)
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 2)
        .padding(16)
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("設備・サービス")
                .font(.headline)
                .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                featureCell(available: library.hasStudyRoom, icon: "pencil.and.ruler.fill", label: "自習室")
                featureCell(available: library.hasPowerOutlets, icon: "bolt.fill", label: "電源コンセント")
                featureCell(available: library.hasWifi, icon: "wifi", label: "Wi-Fi")
                featureCell(available: library.hasCafe, icon: "cup.and.saucer.fill", label: "カフェ併設")
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("この図書館の特徴")
                .font(.headline)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(library.tags, id: \.rawValue) { tag in
                        TagChip(tag: tag)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 8)
    }

    private var mapPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("アクセス")
                .font(.headline)
                .padding(.horizontal, 16)

            Map(initialPosition: .region(MKCoordinateRegion(
                center: library.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Annotation(library.name, coordinate: library.coordinate) {
                    Image(systemName: "building.columns.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.toshoGreen)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
            .padding(.horizontal, 16)

            if appleMapItem != nil {
                Button {
                    showAppleMapDetail = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .foregroundColor(.toshoGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple Mapsで詳細を見る")
                                .font(.subheadline.bold())
                                .foregroundColor(.toshoText)
                            Text("開館時間・電話番号など")
                                .font(.caption)
                                .foregroundColor(.toshoSubtext)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.toshoSubtext)
                    }
                    .padding(14)
                    .background(Color.toshoCard)
                    .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.smallCornerRadius))
                    .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 4, y: 1)
                    .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("レビュー")
                    .font(.headline)
                Spacer()
                Button {
                    showVisitReviewSheet = true
                } label: {
                    Label("書く", systemImage: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.toshoGreen)
                }
            }
            .padding(.horizontal, 16)

            if isLoadingReviews {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if publicReviews.isEmpty {
                Text("まだ公開レビューがありません")
                    .font(.subheadline)
                    .foregroundColor(.toshoSubtext)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(publicReviews) { review in
                    PublicReviewCard(review: review)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Helpers

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 28)
                .foregroundColor(.toshoGreen)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.toshoSubtext)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.toshoText)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func featureCell(available: Bool, icon: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 32)
                .foregroundColor(available ? .toshoGreen : .gray.opacity(0.4))
            Text(label)
                .font(.subheadline)
                .foregroundColor(available ? .toshoText : .gray.opacity(0.5))
            Spacer()
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(available ? .toshoGreen : .gray.opacity(0.3))
        }
        .padding(12)
        .background(available ? Color.toshoGreenLight : Color.gray.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.smallCornerRadius))
    }
}

// MARK: - Public Review Card

struct PublicReviewCard: View {
    let review: ReviewRow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.toshoGreen.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.subheadline)
                            .foregroundColor(.toshoGreen)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: i < review.rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.toshoAmber)
                        }
                    }
                    Text(review.visitedAt)
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                }
                Spacer()
            }

            if !review.comment.isEmpty {
                Text(review.comment)
                    .font(.subheadline)
                    .foregroundColor(.toshoText)
                    .lineLimit(4)
            }

            if !review.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(review.tags.compactMap { LibraryTag(rawValue: $0) }, id: \.rawValue) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 6, y: 2)
    }
}

// MARK: - Apple Maps Detail Sheet

private struct MapItemDetailSheet: UIViewControllerRepresentable {
    let mapItem: MKMapItem
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> MKMapItemDetailViewController {
        let vc = MKMapItemDetailViewController(mapItem: mapItem, displaysMap: false)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MKMapItemDetailViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    class Coordinator: NSObject, MKMapItemDetailViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func mapItemDetailViewControllerDidFinish(_ vc: MKMapItemDetailViewController) { dismiss() }
    }
}

#Preview {
    LibraryDetailView(library: Library(
        name: "東京都立中央図書館",
        prefecture: "東京都",
        city: "港区",
        address: "東京都港区南麻布5-7-13",
        latitude: 35.6497,
        longitude: 139.7247,
        openingHours: "9:00〜20:30",
        closedDays: "第3水曜日",
        collectionCount: 1900000,
        hasStudyRoom: true,
        hasPowerOutlets: true,
        hasWifi: true,
        rating: 4.2,
        reviewCount: 128,
        tags: [.beautiful, .largeCollection],
        description: "東京都立の中央図書館。蔵書数は都内最大級。"
    ))
    .environmentObject(AppState())
}
