import SwiftUI
import MapKit

struct LibraryDetailView: View {
    let library: Library
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var showReviewSheet = false

    private let sampleReviews: [Review] = [
        Review(
            id: UUID(),
            libraryId: UUID(),
            userName: "たびびと",
            userInitial: "た",
            rating: 5,
            comment: "圧倒的な建築美！コロッセウムのような吹き抜けが壮大で、思わず何度も見上げてしまいました。蔵書数も多く、一日中いられます。カフェでコーヒーを飲みながら本を読む時間が最高でした。",
            date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            tags: [.beautiful, .study],
            isPublic: true
        ),
        Review(
            id: UUID(),
            libraryId: UUID(),
            userName: "読書好き",
            userInitial: "読",
            rating: 4,
            comment: "Wi-Fiも電源もあって快適に過ごせました。週末は混んでいたので平日がおすすめ。",
            date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            tags: [.study],
            isPublic: true
        ),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                    infoSection
                    featuresSection
                    tagsSection
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
                    appState.toggleVisited(library)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: appState.visitedLibraryIds.contains(library.id) ? "checkmark.circle.fill" : "plus.circle.fill")
                        Text(appState.visitedLibraryIds.contains(library.id) ? "訪問済みに記録済み" : "訪問済みに記録する")
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
            infoRow(icon: "books.vertical", label: "蔵書数", value: "\(library.collectionCount.formatted())冊")
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
                    showReviewSheet = true
                } label: {
                    Label("書く", systemImage: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.toshoGreen)
                }
            }
            .padding(.horizontal, 16)

            ForEach(sampleReviews) { review in
                ReviewCard(review: review)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 32)
    }

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

struct ReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.toshoGreen.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(review.userInitial)
                            .font(.subheadline.bold())
                            .foregroundColor(.toshoGreen)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.userName)
                        .font(.subheadline.bold())
                        .foregroundColor(.toshoText)
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Image(systemName: i < review.rating ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.toshoAmber)
                        }
                        Text(review.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.toshoSubtext)
                            .padding(.leading, 4)
                    }
                }
                Spacer()
            }

            Text(review.comment)
                .font(.subheadline)
                .foregroundColor(.toshoText)
                .lineLimit(4)

            if !review.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(review.tags, id: \.rawValue) { tag in
                        TagChip(tag: tag)
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

#Preview {
    LibraryDetailView(library: Library.sampleLibraries[0])
        .environmentObject(AppState())
}
