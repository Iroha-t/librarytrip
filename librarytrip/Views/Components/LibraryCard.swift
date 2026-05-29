import SwiftUI

struct LibraryCard: View {
    let library: Library
    @EnvironmentObject var appState: AppState
    var style: CardStyle = .featured

    enum CardStyle {
        case featured, compact, ranking
    }

    var body: some View {
        switch style {
        case .featured:
            featuredCard
        case .compact:
            compactCard
        case .ranking:
            rankingCard
        }
    }

    private var featuredCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                libraryImagePlaceholder(height: 160)
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                    Text(String(format: "%.1f", library.rating))
                        .font(.caption.bold())
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .clipShape(Capsule())
                .padding(10)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(library.name)
                    .font(.headline)
                    .foregroundColor(.toshoText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.toshoGreen)
                    Text("\(library.prefecture) \(library.city)")
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(library.tags.prefix(3), id: \.rawValue) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }

                HStack(spacing: 12) {
                    featureIcon(show: library.hasStudyRoom, icon: "pencil.and.ruler", label: "自習室")
                    featureIcon(show: library.hasPowerOutlets, icon: "bolt.fill", label: "電源")
                    featureIcon(show: library.hasWifi, icon: "wifi", label: "Wi-Fi")
                    featureIcon(show: library.hasCafe, icon: "cup.and.saucer.fill", label: "カフェ")
                }
            }
            .padding(14)
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cardCornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 3)
    }

    private var compactCard: some View {
        HStack(spacing: 14) {
            libraryImagePlaceholder(size: 70)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(library.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.toshoText)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.toshoGreen)
                    Text("\(library.prefecture) \(library.city)")
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                }
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.toshoAmber)
                    Text(String(format: "%.1f", library.rating))
                        .font(.caption.bold())
                        .foregroundColor(.toshoText)
                    Text("(\(library.reviewCount))")
                        .font(.caption)
                        .foregroundColor(.toshoSubtext)
                }
            }
            Spacer()

            Button {
                appState.toggleWishlist(library)
            } label: {
                Image(systemName: appState.wishlistLibraryIds.contains(library.id) ? "bookmark.fill" : "bookmark")
                    .foregroundColor(.toshoGreen)
            }
        }
        .padding(14)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: 6, y: 2)
    }

    private var rankingCard: some View {
        HStack(spacing: 14) {
            libraryImagePlaceholder(size: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(library.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundColor(.toshoText)
                Text("\(library.prefecture)")
                    .font(.caption)
                    .foregroundColor(.toshoSubtext)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.toshoAmber)
                    Text(String(format: "%.1f", library.rating))
                        .font(.subheadline.bold())
                        .foregroundColor(.toshoText)
                }
                Text("\(library.reviewCount)件")
                    .font(.caption2)
                    .foregroundColor(.toshoSubtext)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private func libraryImagePlaceholder(height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.toshoGreen.opacity(0.6), Color.toshoGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.8))
                Text(library.name)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func libraryImagePlaceholder(size: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color.toshoGreen.opacity(0.6), Color.toshoGreen],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "building.columns.fill")
                .font(.system(size: size * 0.4))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(width: size, height: size)
    }

    private func featureIcon(show: Bool, icon: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
        }
        .foregroundColor(show ? .toshoGreen : Color.gray.opacity(0.3))
        .lineLimit(1)
    }
}

struct TagChip: View {
    let tag: LibraryTag

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: tag.icon)
                .font(.system(size: 9))
            Text(tag.rawValue)
                .font(.system(size: 10))
        }
        .foregroundColor(.toshoGreen)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.toshoGreenLight)
        .clipShape(Capsule())
    }
}
