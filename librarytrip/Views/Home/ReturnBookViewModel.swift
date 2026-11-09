import Foundation

/// 返す本（ISBN）を扱っている、現在地に近い図書館を探して状態を管理する。
@MainActor
@Observable
final class ReturnBookViewModel {
    /// 返却先の候補1件分（距離つきの図書館と、その本の貸出状況）。
    struct Candidate: Identifiable {
        let nearby: NearbyLibrary
        let status: String

        var id: UUID { nearby.id }
    }

    enum State {
        case loading(String)
        case loaded([Candidate])
        case failed(String)
    }

    let isbn: String
    private(set) var book: BookSearchResult?
    private(set) var state: State = .loading("現在地を取得中...")
    private let locationProvider = CurrentLocationProvider()

    init(isbn: String) {
        self.isbn = isbn
    }

    /// 本の情報を調べ、現在地の近くでその本を扱っている図書館を距離順に探す。
    func load() async {
        state = .loading("現在地を取得中...")
        if book == nil {
            Task { book = try? await CalilAPIService.shared.searchBooks(isbn: isbn).first }
        }
        do {
            let coordinate = try await locationProvider.fetch()
            state = .loading("近くの図書館を探しています...")
            let nearby = try await NearbyLibraryFinder.nearest(to: coordinate, limit: 30)

            var systemIds: [String] = []
            for item in nearby {
                if let systemId = item.library.systemId, !systemIds.contains(systemId) {
                    systemIds.append(systemId)
                }
            }
            let targetIds = Array(systemIds.prefix(10))
            guard !targetIds.isEmpty else {
                state = .loaded([])
                return
            }

            state = .loading("蔵書を確認中...\nしばらくお待ちください")
            let response = try await CalilAPIService.shared.checkBooks(isbns: [isbn], systemIds: targetIds)

            let candidates = nearby.compactMap { item -> Candidate? in
                guard let systemId = item.library.systemId,
                      targetIds.contains(systemId),
                      let libKey = item.library.libKey,
                      let status = response.books[isbn]?[systemId]?.libkey?[libKey]
                else { return nil }
                return Candidate(nearby: item, status: status)
            }
            state = .loaded(Array(candidates.prefix(10)))
        } catch is CancellationError {
            return
        } catch {
            state = .failed(NearbyLibraryFinder.message(for: error))
        }
    }
}
