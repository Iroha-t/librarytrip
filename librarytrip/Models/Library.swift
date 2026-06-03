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
        urlPC: String? = nil
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

// MARK: - Sample Data
extension Library {
    static let sampleLibraries: [Library] = [
        Library(
            name: "石川県立図書館",
            prefecture: "石川県",
            city: "金沢市",
            address: "石川県金沢市小立野2丁目43-1",
            latitude: 36.5613,
            longitude: 136.6625,
            openingHours: "9:00 〜 20:00",
            closedDays: "毎月第3木曜日",
            collectionCount: 950000,
            hasStudyRoom: true,
            hasPowerOutlets: true,
            hasWifi: true,
            hasCafe: true,
            rating: 4.8,
            reviewCount: 1243,
            tags: [.beautiful, .modern, .study, .accessible],
            description: "2022年にオープンした新しい図書館。ガラス張りの開放的な空間と、コロッセウムのような円形の階段が特徴的。約110万冊の蔵書を誇る。"
        ),
        Library(
            name: "武雄市図書館",
            prefecture: "佐賀県",
            city: "武雄市",
            address: "佐賀県武雄市武雄町大字武雄5304-1",
            latitude: 33.1993,
            longitude: 130.0161,
            openingHours: "9:00 〜 21:00",
            closedDays: "年中無休",
            collectionCount: 200000,
            hasStudyRoom: true,
            hasPowerOutlets: true,
            hasWifi: true,
            hasCafe: true,
            rating: 4.6,
            reviewCount: 2891,
            tags: [.beautiful, .cafe, .study, .accessible, .modern],
            description: "スターバックスが併設された図書館として話題に。蔦屋書店が運営に参加し、年中無休・夜21時まで開館。カフェで本が読めるスタイルが人気。"
        ),
        Library(
            name: "国際子ども図書館",
            prefecture: "東京都",
            city: "台東区",
            address: "東京都台東区上野公園12-49",
            latitude: 35.7157,
            longitude: 139.7756,
            openingHours: "9:30 〜 17:00",
            closedDays: "月曜日・国民の祝日の翌日",
            collectionCount: 340000,
            hasStudyRoom: false,
            hasPowerOutlets: false,
            hasWifi: true,
            hasCafe: false,
            rating: 4.5,
            reviewCount: 876,
            tags: [.historic, .beautiful, .childFriendly],
            description: "明治時代に建てられたルネサンス様式の建物。国立国会図書館の支部として子ども向け資料を専門に収集・保存する唯一の図書館。"
        ),
        Library(
            name: "仙台市中央図書館",
            prefecture: "宮城県",
            city: "仙台市",
            address: "宮城県仙台市青葉区北根2丁目16-1",
            latitude: 38.2668,
            longitude: 140.8694,
            openingHours: "9:00 〜 20:00",
            closedDays: "毎月第1木曜日",
            collectionCount: 750000,
            hasStudyRoom: true,
            hasPowerOutlets: true,
            hasWifi: true,
            hasCafe: false,
            rating: 4.3,
            reviewCount: 543,
            tags: [.largeCollection, .study, .quiet],
            description: "宮城野の森に囲まれた大型図書館。自然豊かな環境の中で読書に集中できる。"
        ),
        Library(
            name: "梅田 蔦屋書店",
            prefecture: "大阪府",
            city: "大阪市",
            address: "大阪府大阪市北区梅田3丁目1-3",
            latitude: 34.7024,
            longitude: 135.4959,
            openingHours: "7:00 〜 23:00",
            closedDays: "年中無休",
            collectionCount: 150000,
            hasStudyRoom: false,
            hasPowerOutlets: true,
            hasWifi: true,
            hasCafe: true,
            rating: 4.4,
            reviewCount: 3201,
            tags: [.cafe, .accessible, .modern, .study],
            description: "大阪駅直結の蔦屋書店。スターバックス併設で早朝から深夜まで利用可能。雑誌や新刊も豊富。"
        ),
    ]
}
