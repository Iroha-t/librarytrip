import CoreLocation

/// 現在地を1回だけ取得して返す。位置情報が許可されていない・時間切れのときはエラーにする。
@MainActor
final class CurrentLocationProvider {
    /// 現在地が取れなかった理由。
    enum LocationError: LocalizedError {
        case denied
        case timeout

        var errorDescription: String? {
            switch self {
            case .denied:
                return "位置情報の利用が許可されていません。設定アプリの「プライバシーとセキュリティ」→「位置情報サービス」から、としょたびを許可してください"
            case .timeout:
                return "現在地を取得できませんでした。もう一度試してください"
            }
        }
    }

    private let manager = LocationManager()
    private let timeoutSeconds = 30

    /// 位置情報の許可を求めて現在地を取得する（最大30秒待つ）。
    func fetch() async throws -> CLLocationCoordinate2D {
        let startCount = manager.updateCount
        manager.requestAndLocate()
        for _ in 0..<(timeoutSeconds * 4) {
            if manager.updateCount != startCount, let coordinate = manager.coordinate {
                return coordinate
            }
            if manager.isAuthorizationDenied {
                throw LocationError.denied
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        throw LocationError.timeout
    }
}
