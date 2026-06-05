import Foundation
import CoreLocation

struct Library: Identifiable {
    let id: UUID
    var name: String
    var prefecture: String
    var city: String
    var address: String
    var coordinate: CLLocationCoordinate2D
    var openingHours: String
    var closedDays: String
    var collectionCount: Int
    var hasStudyRoom: Bool
    var hasPowerOutlets: Bool
    var hasWifi: Bool
    var hasCafe: Bool
    var rating: Double
    var reviewCount: Int
    var imageNames: [String]
    var tags: [LibraryTag]
    var description: String

    // カーリルAPI由来フィールド
    var systemId: String?   // 図書館システムID（蔵書検索に使用）
    var libKey: String?     // システム内の図書館キー
    var libId: String?      // カーリル図書館ユニークID
    var urlPC: String?      // 図書館公式サイトURL
    var category: LibraryCategory?

    init(
        id: UUID = UUID(),
        name: String,
        prefecture: String,
        city: String,
        address: String,
        latitude: Double,
        longitude: Double,
        openingHours: String,
        closedDays: String,
        collectionCount: Int,
        hasStudyRoom: Bool = false,
        hasPowerOutlets: Bool = false,
        hasWifi: Bool = false,
        hasCafe: Bool = false,
        rating: Double = 0,
        reviewCount: Int = 0,
        imageNames: [String] = [],
        tags: [LibraryTag] = [],
        description: String = "",
        systemId: String? = nil,
        libKey: String? = nil,
        libId: String? = nil,
        urlPC: String? = nil,
        category: LibraryCategory? = nil
    ) {
        self.id = id
        self.name = name
        self.prefecture = prefecture
        self.city = city
        self.address = address
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.openingHours = openingHours
        self.closedDays = closedDays
        self.collectionCount = collectionCount
        self.hasStudyRoom = hasStudyRoom
        self.hasPowerOutlets = hasPowerOutlets
        self.hasWifi = hasWifi
        self.hasCafe = hasCafe
        self.rating = rating
        self.reviewCount = reviewCount
        self.imageNames = imageNames
        self.tags = tags
        self.description = description
        self.systemId = systemId
        self.libKey = libKey
        self.libId = libId
        self.urlPC = urlPC
        self.category = category
    }
}

enum LibraryCategory: String, CaseIterable {
    case small   = "SMALL"
    case medium  = "MEDIUM"
    case large   = "LARGE"
    case univ    = "UNIV"
    case special = "SPECIAL"
    case bm      = "BM"

    var label: String {
        switch self {
        case .small:   return "図書室"
        case .medium:  return "公共図書館"
        case .large:   return "大規模図書館"
        case .univ:    return "大学図書館"
        case .special: return "専門図書館"
        case .bm:      return "移動図書館"
        }
    }

    var icon: String {
        switch self {
        case .small:   return "books.vertical"
        case .medium:  return "building.columns"
        case .large:   return "building.columns.fill"
        case .univ:    return "graduationcap"
        case .special: return "magnifyingglass"
        case .bm:      return "bus"
        }
    }
}

enum LibraryTag: String, CaseIterable {
    case beautiful = "建築が美しい"
    case study = "勉強向き"
    case largeCollection = "蔵書数が多い"
    case quiet = "静かで落ち着く"
    case childFriendly = "子ども向け充実"
    case cafe = "カフェ併設"
    case historic = "歴史的建造物"
    case viewPoint = "眺望が良い"
    case accessible = "アクセス良好"
    case modern = "モダンな設計"

    var icon: String {
        switch self {
        case .beautiful: return "sparkles"
        case .study: return "pencil"
        case .largeCollection: return "books.vertical"
        case .quiet: return "leaf"
        case .childFriendly: return "figure.play"
        case .cafe: return "cup.and.saucer"
        case .historic: return "building.columns"
        case .viewPoint: return "mountain.2"
        case .accessible: return "tram"
        case .modern: return "cube"
        }
    }
}

extension Library: Equatable {
    static func == (lhs: Library, rhs: Library) -> Bool { lhs.id == rhs.id }
}

struct Review: Identifiable {
    let id: UUID
    let libraryId: UUID
    let userName: String
    let userInitial: String
    let rating: Int
    let comment: String
    let date: Date
    let tags: [LibraryTag]
    let isPublic: Bool
}

struct VisitRecord: Identifiable {
    let id: UUID
    let libraryId: UUID
    let visitDate: Date
    var memo: String
    var isWishlist: Bool
}

