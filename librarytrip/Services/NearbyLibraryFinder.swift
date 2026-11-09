import CoreLocation

/// 現在地からの距離つきの図書館1件分。
struct NearbyLibrary: Identifiable {
    let library: Library
    let distance: Double  // メートル

    var id: UUID { library.id }

    /// 「350m」「1.2km」の形にした距離。
    var distanceText: String {
        distance < 1000
            ? "\(Int(distance))m"
            : String(format: "%.1fkm", distance / 1000)
    }
}

/// 現在地の近くにある図書館を、近い順に探す。
@MainActor
enum NearbyLibraryFinder {
    /// 指定した場所に近い図書館を、近い順に最大 limit 件返す。
    static func nearest(to coordinate: CLLocationCoordinate2D, limit: Int) async throws -> [NearbyLibrary] {
        let dtos = try await CalilAPIService.shared.fetchNearbyLibraries(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            limit: 30
        )
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let sorted = dtos
            .filter { $0.coordinate != nil }
            .map { $0.toLibrary() }
            .map { library -> NearbyLibrary in
                let there = CLLocation(latitude: library.coordinate.latitude,
                                       longitude: library.coordinate.longitude)
                return NearbyLibrary(library: library, distance: there.distance(from: here))
            }
            .sorted { $0.distance < $1.distance }
        return Array(sorted.prefix(limit))
    }

    /// 画面に出す用の、わかりやすいエラーメッセージ。
    static func message(for error: Error) -> String {
        if let locationError = error as? CurrentLocationProvider.LocationError {
            return locationError.localizedDescription
        }
        return "図書館の取得に失敗しました。通信の状態を確認して、もう一度試してください"
    }
}
