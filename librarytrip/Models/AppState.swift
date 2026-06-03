import Foundation
import CoreLocation
import Combine

@MainActor
class AppState: ObservableObject {

    // MARK: - State

    @Published var libraries: [Library] = Library.sampleLibraries
    @Published var books: [Book] = Book.sampleBooks
    @Published var visitedLibraryIds: Set<UUID> = []
    @Published var wishlistLibraryIds: Set<UUID> = []

    /// マップ表示用：APIから取得した図書館（サンプルデータとマージ）
    @Published var apiLibraries: [Library] = []
    @Published var isLoadingLibraries = false
    @Published var apiError: String?  // map view から直接クリア可能

    // MARK: - Computed

    var allLibraries: [Library] {
        // API取得結果を優先し、サンプルデータと重複しないものをマージ
        let apiIds = Set(apiLibraries.compactMap { $0.libId })
        let sampleOnly = libraries.filter { lib in
            guard let lid = lib.libId else { return true }
            return !apiIds.contains(lid)
        }
        return apiLibraries + sampleOnly
    }

    var visitedLibraries: [Library] {
        allLibraries.filter { visitedLibraryIds.contains($0.id) }
    }

    var wishlistLibraries: [Library] {
        allLibraries.filter { wishlistLibraryIds.contains($0.id) }
    }

    var borrowedBooks: [Book] {
        books.filter { $0.status == .borrowed || $0.status == .reading }
    }

    var overdueBooks: [Book] {
        books.filter { $0.isOverdue }
    }

    var prefectureStats: [(prefecture: String, visited: Int, total: Int)] {
        let all = allLibraries
        return Set(all.map { $0.prefecture }).sorted().map { pref in
            let total   = all.filter { $0.prefecture == pref }.count
            let visited = all.filter { $0.prefecture == pref && visitedLibraryIds.contains($0.id) }.count
            return (prefecture: pref, visited: visited, total: total)
        }
    }

    // MARK: - Actions

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

    // MARK: - API: 近隣図書館取得

    func fetchNearbyLibraries(latitude: Double, longitude: Double) async {
        isLoadingLibraries = true
        apiError = nil
        do {
            let dtos = try await CalilAPIService.shared.fetchNearbyLibraries(
                latitude: latitude,
                longitude: longitude,
                limit: 50
            )
            // 重複を避けて追加（libId が同じものは上書き）
            var byLibId = Dictionary(apiLibraries.compactMap { l -> (String, Library)? in
                guard let lid = l.libId else { return nil }
                return (lid, l)
            }, uniquingKeysWith: { _, new in new })

            for dto in dtos {
                byLibId[dto.libid] = dto.toLibrary()
            }
            apiLibraries = Array(byLibId.values)
        } catch {
            apiError = error.localizedDescription
        }
        isLoadingLibraries = false
    }

    /// 都道府県 ＋ 任意の市区町村で図書館を取得
    /// - city を指定するとそのエリアの全館を取得（例: pref="東京都" city="杉並区"）
    func fetchLibraries(pref: String, city: String? = nil) async {
        isLoadingLibraries = true
        apiError = nil
        do {
            let dtos = try await CalilAPIService.shared.fetchLibraries(pref: pref, city: city)
            var byLibId = Dictionary(apiLibraries.compactMap { l -> (String, Library)? in
                guard let lid = l.libId else { return nil }
                return (lid, l)
            }, uniquingKeysWith: { _, new in new })
            for dto in dtos { byLibId[dto.libid] = dto.toLibrary() }
            apiLibraries = Array(byLibId.values)
        } catch {
            apiError = error.localizedDescription
        }
        isLoadingLibraries = false
    }

    // MARK: - API: 蔵書確認

    func checkBookAvailability(isbn: String, systemIds: [String]) async -> CalilCheckResponse? {
        guard !systemIds.isEmpty else { return nil }
        do {
            return try await CalilAPIService.shared.checkBooks(
                isbns: [isbn],
                systemIds: systemIds
            )
        } catch {
            apiError = error.localizedDescription
            return nil
        }
    }
}
