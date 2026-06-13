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

    // MARK: - Featured

    private var featuredCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                // Deep gradient background
                LinearGradient(
                    stops: [
                        .init(color: ToshoTheme.headerDeep, location: 0),
                        .init(color: ToshoTheme.headerMid, location: 1)
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .frame(height: 165)

                // Decorative icon
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.white.opacity(0.10))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 18)
                    .padding(.bottom, 18)

                // Bottom scrim for text legibility
                LinearGradient(
                    colors: [Color.black.opacity(0.52), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 100)

                // Text overlay
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.toshoAmber)
                        Text(String(format: "%.1f", library.rating))
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Text("(\(library.reviewCount))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.65))
                    }
                    Text(library.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(library.prefecture) \(library.city)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.70))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }

            // Info area
            VStack(alignment: .leading, spacing: 9) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if let category = library.category {
                            CategoryChip(category: category)
                        }
                        ForEach(library.tags.prefix(3), id: \.rawValue) { tag in
                            TagChip(tag: tag)
                        }
                    }
                }
                HStack(spacing: 10) {
                    featureIcon(show: library.hasStudyRoom,   icon: "pencil.and.ruler",     label: "自習室")
                    featureIcon(show: library.hasPowerOutlets, icon: "bolt.fill",            label: "電源")
                    featureIcon(show: library.hasWifi,        icon: "wifi",                  label: "Wi-Fi")
                    featureIcon(show: library.hasCafe,        icon: "cup.and.saucer.fill",   label: "カフェ")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cardCornerRadius, style: .continuous))
        .shadow(
            color: ToshoTheme.headerMid.opacity(0.18),
            radius: ToshoTheme.shadowRadius,
            y: 4
        )
    }

    // MARK: - Compact

    private var compactCard: some View {
        HStack(spacing: 14) {
            libraryImagePlaceholder(size: 68)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
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
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(appState.wishlistLibraryIds.contains(library.id) ? .toshoGreen : .toshoSubtext.opacity(0.7))
                    .frame(width: 34, height: 34)
                    .background(Color.toshoGreen.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(14)
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: ToshoTheme.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(ToshoTheme.shadowOpacity), radius: ToshoTheme.shadowRadius, y: 3)
    }

    // MARK: - Ranking

    private var rankingCard: some View {
        HStack(spacing: 12) {
            libraryImagePlaceholder(size: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(library.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .foregroundColor(.toshoText)
                Text(library.prefecture)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func libraryImagePlaceholder(height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: ToshoTheme.headerDeep, location: 0),
                    .init(color: ToshoTheme.headerMid, location: 1)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            Image(systemName: "building.columns.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.18))
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func libraryImagePlaceholder(size: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: ToshoTheme.headerDeep, location: 0),
                    .init(color: ToshoTheme.headerMid, location: 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "building.columns.fill")
                .font(.system(size: size * 0.38))
                .foregroundColor(.white.opacity(0.22))
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
        .foregroundColor(show ? .toshoGreen : Color.gray.opacity(0.28))
        .lineLimit(1)
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: LibraryTag

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: tag.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(tag.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(.toshoGreen)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.toshoGreen.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.toshoGreen.opacity(0.22), lineWidth: 0.5)
        )
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: LibraryCategory

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: category.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(category.label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(category.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(category.color.opacity(0.10))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(category.color.opacity(0.28), lineWidth: 0.5)
        )
    }
}
