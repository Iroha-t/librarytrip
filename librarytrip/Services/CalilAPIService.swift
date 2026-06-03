import Foundation
import CoreLocation

// MARK: - API Response Models

struct CalilLibraryDTO: Sendable {
    let systemid: String
    let systemname: String
    let libkey: String
    let libid: String
    let short: String?
    let formal: String
    let url_pc: String?
    let address: String
    let pref: String
    let city: String
    let post: String?
    let tel: String?
    let geocode: String?       // "longitude,latitude" 形式
    let category: String?      // SMALL/MEDIUM/LARGE/UNIV/SPECIAL/BM
    let distance: String?

    /// geocode文字列から座標へ変換（API は "経度,緯度" 順）
    var coordinate: CLLocationCoordinate2D? {
        guard let geocode else { return nil }
        let parts = geocode.split(separator: ",")
        guard parts.count == 2,
              let lon = Double(parts[0]),
              let lat = Double(parts[1]) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func toLibrary() -> Library {
        let coord = coordinate
        return Library(
            name: formal,
            prefecture: pref,
            city: city,
            address: address,
            latitude: coord?.latitude ?? 35.6762,
            longitude: coord?.longitude ?? 139.6503,
            openingHours: "要確認",
            closedDays: "要確認",
            collectionCount: 0,
            systemId: systemid,
            libKey: libkey,
            libId: libid,
            urlPC: url_pc
        )
    }
}

extension CalilLibraryDTO: Decodable {
    private enum CodingKeys: String, CodingKey {
        case systemid, systemname, libkey, libid, short, formal
        case url_pc, address, pref, city, post, tel, geocode, category, distance
    }
    init(from decoder: any Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        systemid   = try c.decode(String.self,  forKey: .systemid)
        systemname = try c.decode(String.self,  forKey: .systemname)
        libkey     = try c.decode(String.self,  forKey: .libkey)
        libid      = try c.decode(String.self,  forKey: .libid)
        short      = try c.decodeIfPresent(String.self, forKey: .short)
        formal     = try c.decode(String.self,  forKey: .formal)
        url_pc     = try c.decodeIfPresent(String.self, forKey: .url_pc)
        address    = try c.decode(String.self,  forKey: .address)
        pref       = try c.decode(String.self,  forKey: .pref)
        city       = try c.decode(String.self,  forKey: .city)
        post       = try c.decodeIfPresent(String.self, forKey: .post)
        tel        = try c.decodeIfPresent(String.self, forKey: .tel)
        geocode    = try c.decodeIfPresent(String.self, forKey: .geocode)
        category   = try c.decodeIfPresent(String.self, forKey: .category)
        distance   = try c.decodeIfPresent(String.self, forKey: .distance)
    }
}

// MARK: - 蔵書確認API

// Codable 合成に頼らず init(from:) を明示実装することで
// Swift 6 の "main actor-isolated conformance" エラーを回避する
struct CalilCheckResponse: Sendable {
    let session: String
    let books: [String: [String: CalilBookSystemStatus]]
    let `continue`: Int
}

extension CalilCheckResponse: Decodable {
    private enum CodingKeys: String, CodingKey {
        case session, books, `continue`
    }
    nonisolated init(from decoder: any Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        session    = try c.decode(String.self, forKey: .session)
        books      = try c.decode([String: [String: CalilBookSystemStatus]].self, forKey: .books)
        `continue` = try c.decode(Int.self, forKey: .continue)
    }
}

struct CalilBookSystemStatus: Sendable {
    let status: String          // "OK" | "Cache" | "Running" | "Error"
    let reserveurl: String?
    let libkey: [String: String]?  // 図書館名 → 貸出状況
}

extension CalilBookSystemStatus: Decodable {
    private enum CodingKeys: String, CodingKey {
        case status, reserveurl, libkey
    }
    nonisolated init(from decoder: any Decoder) throws {
        let c  = try decoder.container(keyedBy: CodingKeys.self)
        status     = try c.decode(String.self, forKey: .status)
        reserveurl = try c.decodeIfPresent(String.self, forKey: .reserveurl)
        libkey     = try c.decodeIfPresent([String: String].self, forKey: .libkey)
    }
}

/// 図書館ごとの蔵書状況（アプリ内で使用）
struct LibraryAvailability: Identifiable {
    let id = UUID()
    let systemId: String
    let status: CheckStatus
    let reserveURL: String?
    let availability: [String: String]  // 図書館名 → 貸出可/貸出中 etc.

    enum CheckStatus: String {
        case ok = "OK"
        case cache = "Cache"
        case running = "Running"
        case error = "Error"
    }
}

// MARK: - Service

actor CalilAPIService {
    static let shared = CalilAPIService()

    /// カーリル API キー
    ///
    /// 読み取り優先順位:
    /// 1. Info.plist の "CalilAPIKey" エントリ（本番ビルド用: Build Settings → $(CALIL_API_KEY)）
    /// 2. Scheme 環境変数 "CALIL_API_KEY"（開発・デバッグ用）
    /// 3. どちらも未設定の場合は空文字（APIリクエストが 400 エラーになります）
    static var appKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "CalilAPIKey") as? String,
           !key.isEmpty, key != "$(CALIL_API_KEY)" {
            return key
        }
        if let key = ProcessInfo.processInfo.environment["CALIL_API_KEY"],
           !key.isEmpty {
            return key
        }
        // キーが未設定のままでも開発中は動くよう "test" にフォールバック
        print("[CalilAPI] ⚠️ APIキー未設定。テストキーで代用します。本番前に CALIL_API_KEY を設定してください。")
        return "test"
    }

    private let baseURL = "https://api.calil.jp"

    // 簡易キャッシュ: geocode文字列 → 図書館リスト
    private var libraryCache: [String: [CalilLibraryDTO]] = [:]

    // MARK: 図書館データベースAPI

    /// 緯度経度から近隣図書館を取得
    func fetchNearbyLibraries(
        latitude: Double,
        longitude: Double,
        limit: Int = 30
    ) async throws -> [CalilLibraryDTO] {
        let geocodeKey = String(format: "%.3f,%.3f", longitude, latitude)
        if let cached = libraryCache[geocodeKey] { return cached }

        var components = URLComponents(string: "\(baseURL)/library")!
        components.queryItems = [
            URLQueryItem(name: "appkey", value: Self.appKey),
            URLQueryItem(name: "geocode", value: "\(longitude),\(latitude)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "format", value: "json"),
            // ⚠️ /library は callback 不要。付けると JSONP 形式で返ってきてデコード失敗する
        ]
        let result = try await fetchDecodable([CalilLibraryDTO].self, from: components.url!)
        libraryCache[geocodeKey] = result
        return result
    }

    /// 都道府県（＋市区町村）で図書館を取得
    func fetchLibraries(pref: String, city: String? = nil) async throws -> [CalilLibraryDTO] {
        let cacheKey = pref + (city ?? "")
        if let cached = libraryCache[cacheKey] { return cached }

        var items: [URLQueryItem] = [
            URLQueryItem(name: "appkey", value: Self.appKey),
            URLQueryItem(name: "pref", value: pref),
            URLQueryItem(name: "format", value: "json"),
            // ⚠️ /library は callback 不要（付けると JSONP になってデコード失敗）
        ]
        if let city {
            items.append(URLQueryItem(name: "city", value: city))
            print("[CalilAPI] 🔍 pref=\(pref) city=\(city)")
        } else {
            print("[CalilAPI] 🔍 pref=\(pref)")
        }

        var components = URLComponents(string: "\(baseURL)/library")!
        components.queryItems = items
        let result = try await fetchDecodable([CalilLibraryDTO].self, from: components.url!)
        libraryCache[cacheKey] = result
        return result
    }

    // MARK: 蔵書確認API（ポーリング）

    /// ISBN × システムIDリストで蔵書・貸出状況を確認する（ポーリング込み）
    /// - Parameters:
    ///   - isbns: ISBNリスト（最大100件/セッション）
    ///   - systemIds: 図書館システムIDリスト
    /// - Returns: 最終的な確認結果
    func checkBooks(isbns: [String], systemIds: [String]) async throws -> CalilCheckResponse {
        // 初回リクエスト
        var components = URLComponents(string: "\(baseURL)/check")!
        components.queryItems = [
            URLQueryItem(name: "appkey", value: Self.appKey),
            URLQueryItem(name: "isbn", value: isbns.joined(separator: ",")),
            URLQueryItem(name: "systemid", value: systemIds.joined(separator: ",")),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "callback", value: "no"),
        ]
        var response = try await fetchDecodable(CalilCheckResponse.self, from: components.url!)

        // continue == 1 の間、2秒ごとにポーリング
        while response.continue == 1 {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            var pollComponents = URLComponents(string: "\(baseURL)/check")!
            pollComponents.queryItems = [
                URLQueryItem(name: "appkey", value: Self.appKey),
                URLQueryItem(name: "session", value: response.session),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "callback", value: "no"),
            ]
            response = try await fetchDecodable(CalilCheckResponse.self, from: pollComponents.url!)
        }
        return response
    }

    // MARK: Private

    private nonisolated func fetchDecodable<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        print("[CalilAPI] GET \(url)")
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            print("[CalilAPI] ❌ HTTP \(code)")
            throw CalilAPIError.badStatus(code)
        }
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            print("[CalilAPI] ✅ decoded \(type)")
            return decoded
        } catch {
            // デコード失敗時はレスポンス先頭 200 文字をログ出力（原因調査用）
            let preview = String(data: data.prefix(200), encoding: .utf8) ?? "(binary)"
            print("[CalilAPI] ❌ decode failed: \(error)\nresponse: \(preview)")
            throw CalilAPIError.decodingFailed(error)
        }
    }
}

// MARK: - Error

enum CalilAPIError: LocalizedError {
    case badStatus(Int)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "API エラー (HTTP \(code))"
        case .decodingFailed(let e): return "データの解析に失敗しました: \(e.localizedDescription)"
        }
    }
}

// MARK: - CalilCheckResponse helpers

extension CalilCheckResponse {
    /// ISBNごとに LibraryAvailability のリストへ変換
    func availabilities(for isbn: String) -> [LibraryAvailability] {
        guard let systemMap = books[isbn] else { return [] }
        return systemMap.map { (systemId, systemStatus) in
            LibraryAvailability(
                systemId: systemId,
                status: .init(rawValue: systemStatus.status) ?? .error,
                reserveURL: systemStatus.reserveurl,
                availability: systemStatus.libkey ?? [:]
            )
        }
    }
}
