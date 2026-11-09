import Foundation

/// 「現在地から図書館を探す」画面の状態を管理する。現在地を取って、近い順に10館を用意する。
@MainActor
@Observable
final class NearbyLibrariesViewModel {
    enum State {
        case loading(String)
        case loaded([NearbyLibrary])
        case failed(String)
    }

    private(set) var state: State = .loading("現在地を取得中...")
    private let locationProvider = CurrentLocationProvider()

    /// 現在地を取得し、近くの図書館を探して結果を state に入れる。
    func load() async {
        state = .loading("現在地を取得中...")
        do {
            let coordinate = try await locationProvider.fetch()
            state = .loading("近くの図書館を探しています...")
            let libraries = try await NearbyLibraryFinder.nearest(to: coordinate, limit: 10)
            state = .loaded(libraries)
        } catch is CancellationError {
            return
        } catch {
            state = .failed(NearbyLibraryFinder.message(for: error))
        }
    }
}
