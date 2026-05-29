import Foundation

struct Book: Identifiable {
    let id: UUID
    var title: String
    var author: String
    var isbn: String?
    var coverImageURL: String?
    var genre: BookGenre
    var borrowedFrom: UUID?
    var borrowDate: Date?
    var returnDueDate: Date?
    var returnedDate: Date?
    var status: BookStatus
    var rating: Int?
    var memo: String
    var isPersonal: Bool

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        isbn: String? = nil,
        coverImageURL: String? = nil,
        genre: BookGenre = .other,
        borrowedFrom: UUID? = nil,
        borrowDate: Date? = nil,
        returnDueDate: Date? = nil,
        returnedDate: Date? = nil,
        status: BookStatus = .reading,
        rating: Int? = nil,
        memo: String = "",
        isPersonal: Bool = false
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.isbn = isbn
        self.coverImageURL = coverImageURL
        self.genre = genre
        self.borrowedFrom = borrowedFrom
        self.borrowDate = borrowDate
        self.returnDueDate = returnDueDate
        self.returnedDate = returnedDate
        self.status = status
        self.rating = rating
        self.memo = memo
        self.isPersonal = isPersonal
    }

    var isOverdue: Bool {
        guard let due = returnDueDate, returnedDate == nil else { return false }
        return Date() > due
    }

    var daysUntilDue: Int? {
        guard let due = returnDueDate, returnedDate == nil else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: due).day
    }
}

enum BookStatus: String, CaseIterable {
    case reading = "読書中"
    case borrowed = "借り中"
    case returned = "返却済み"
    case read = "読了"
    case wantToRead = "読みたい"
}

enum BookGenre: String, CaseIterable {
    case novel = "小説"
    case manga = "漫画"
    case science = "科学・理工"
    case history = "歴史"
    case art = "芸術"
    case children = "絵本・児童書"
    case travel = "旅行"
    case business = "ビジネス"
    case selfHelp = "自己啓発"
    case photo = "写真集"
    case reference = "辞典・参考書"
    case other = "その他"

    var color: String {
        switch self {
        case .novel: return "genreNovel"
        case .manga: return "genreManga"
        case .science: return "genreScience"
        case .history: return "genreHistory"
        case .art: return "genreArt"
        case .children: return "genreChildren"
        case .travel: return "genreTravel"
        case .business: return "genreBusiness"
        case .selfHelp: return "genreSelf"
        case .photo: return "genrePhoto"
        case .reference: return "genreRef"
        case .other: return "genreOther"
        }
    }
}

extension Book {
    static let sampleBooks: [Book] = [
        Book(
            title: "ノルウェイの森",
            author: "村上春樹",
            genre: .novel,
            borrowDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            returnDueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            status: .borrowed,
            memo: "石川県立図書館で借りた"
        ),
        Book(
            title: "建築の解体",
            author: "磯崎新",
            genre: .art,
            borrowDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            returnDueDate: Calendar.current.date(byAdding: .day, value: 11, to: Date()),
            status: .borrowed
        ),
        Book(
            title: "羊をめぐる冒険",
            author: "村上春樹",
            genre: .novel,
            returnedDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            status: .read,
            rating: 5,
            memo: "不思議な世界観。続きが読みたい。"
        ),
        Book(
            title: "旅する図書館",
            author: "ゆずき真生",
            genre: .travel,
            status: .wantToRead
        ),
    ]
}
