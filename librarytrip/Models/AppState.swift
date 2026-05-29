import Foundation
import Combine

class AppState: ObservableObject {
    @Published var libraries: [Library] = Library.sampleLibraries
    @Published var books: [Book] = Book.sampleBooks
    @Published var visitedLibraryIds: Set<UUID> = []
    @Published var wishlistLibraryIds: Set<UUID> = []
    @Published var selectedTab: Int = 0

    var visitedLibraries: [Library] {
        libraries.filter { visitedLibraryIds.contains($0.id) }
    }

    var wishlistLibraries: [Library] {
        libraries.filter { wishlistLibraryIds.contains($0.id) }
    }

    var borrowedBooks: [Book] {
        books.filter { $0.status == .borrowed || $0.status == .reading }
    }

    var overdueBooks: [Book] {
        books.filter { $0.isOverdue }
    }

    func toggleVisited(_ library: Library) {
        if visitedLibraryIds.contains(library.id) {
            visitedLibraryIds.remove(library.id)
        } else {
            visitedLibraryIds.insert(library.id)
        }
    }

    func toggleWishlist(_ library: Library) {
        if wishlistLibraryIds.contains(library.id) {
            wishlistLibraryIds.remove(library.id)
        } else {
            wishlistLibraryIds.insert(library.id)
        }
    }

    var prefectureStats: [(prefecture: String, visited: Int, total: Int)] {
        let allPrefectures = Set(libraries.map { $0.prefecture })
        return allPrefectures.sorted().map { pref in
            let total = libraries.filter { $0.prefecture == pref }.count
            let visited = libraries.filter { $0.prefecture == pref && visitedLibraryIds.contains($0.id) }.count
            return (prefecture: pref, visited: visited, total: total)
        }
    }
}
