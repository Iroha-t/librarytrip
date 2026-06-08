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
            urlPC: url_pc,
            category: category.flatMap { LibraryCategory(rawValue: $0) }
        )
    }
}

extension CalilLibraryDTO {
    /// JSONSerialization で得た辞書から生成する。
    /// as? キャストは型不一致・null でも throw せず nil を返すだけなので完全に安全。
    nonisolated init?(dict: [String: Any]) {
        // systemid / libkey / libid がないエントリは使い物にならないので弾く
        guard
            let sid = dict["systemid"] as? String,
            let lk  = dict["libkey"]   as? String,
            let lid = dict["libid"]    as? String
        else {
            print("[CalilAPI] ⚠️ DTO変換スキップ: systemid/libkey/libid 欠損 dict=\(dict.keys.sorted())")
            return nil
        }

        systemid   = sid
        libkey     = lk
        libid      = lid
        systemname = dict["systemname"] as? String ?? ""
        short      = dict["short"]      as? String
        formal     = dict["formal"]     as? String ?? ""
        url_pc     = dict["url_pc"]     as? String
        address    = dict["address"]    as? String ?? ""
        pref       = dict["pref"]       as? String ?? ""
        city       = dict["city"]       as? String ?? ""
        post       = dict["post"]       as? String
        tel        = dict["tel"]        as? String
        geocode    = dict["geocode"]    as? String
        category   = dict["category"]  as? String
        // distance は geocode 検索時に数値で返ってくる
        if let d = dict["distance"] as? Double {
            distance = String(d)
        } else {
            distance = dict["distance"] as? String
        }
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
        if let cached = libraryCache[geocodeKey] {
            print("[CalilAPI] 💾 キャッシュヒット geocodeKey=\(geocodeKey) (\(cached.count)件)")
            return cached
        }
        print("[CalilAPI] 🌐 geocode検索 key=\(geocodeKey) appkey=\(Self.appKey.prefix(8))...")

        var components = URLComponents(string: "\(baseURL)/library")!
        components.queryItems = [
            URLQueryItem(name: "appkey",  value: Self.appKey),
            URLQueryItem(name: "geocode", value: "\(longitude),\(latitude)"),
            URLQueryItem(name: "limit",   value: "\(limit)"),
            URLQueryItem(name: "format",  value: "json"),
            // callback パラメータなし → API は JSONP callback([...]) を返す
            // fetchLibraryArray 内の stripJSONP がラッパーを除去する
        ]
        guard let url = components.url else {
            print("[CalilAPI] ❌ URL構築失敗")
            return []
        }
        let result = try await fetchLibraryArray(from: url)
        // 空配列はキャッシュしない（エラー時の空結果が次回も返ってしまうのを防ぐ）
        if !result.isEmpty { libraryCache[geocodeKey] = result }
        return result
    }

    /// 都道府県（＋市区町村）で図書館を取得
    func fetchLibraries(pref: String, city: String? = nil) async throws -> [CalilLibraryDTO] {
        let cacheKey = pref + (city ?? "")
        if let cached = libraryCache[cacheKey] {
            print("[CalilAPI] 💾 キャッシュヒット cacheKey=\(cacheKey) (\(cached.count)件)")
            return cached
        }
        print("[CalilAPI] 🌐 pref/city検索 pref=\(pref) city=\(city ?? "nil") appkey=\(Self.appKey.prefix(8))...")

        var items: [URLQueryItem] = [
            URLQueryItem(name: "appkey", value: Self.appKey),
            URLQueryItem(name: "pref",   value: pref),
            URLQueryItem(name: "format", value: "json"),
            // callback パラメータなし → API は JSONP callback([...]) を返す
            // fetchLibraryArray 内の stripJSONP がラッパーを除去する
        ]
        if let city {
            items.append(URLQueryItem(name: "city", value: city))
        }

        var components = URLComponents(string: "\(baseURL)/library")!
        components.queryItems = items
        guard let url = components.url else {
            print("[CalilAPI] ❌ URL構築失敗")
            return []
        }
        let result = try await fetchLibraryArray(from: url)
        // 空配列はキャッシュしない
        if !result.isEmpty { libraryCache[cacheKey] = result }
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

    /// /library エンドポイント専用パーサー（JSONSerialization を使用）
    ///
    /// 本番 API キーでは Calil API がデフォルトで JSONP 形式
    ///   `callback([{...}])`
    /// を返すため、JSON パース前に JSONP ラッパーを除去する。
    private nonisolated func fetchLibraryArray(from url: URL) async throws -> [CalilLibraryDTO] {
        print("[CalilAPI] GET \(url)")
        let (data, resp) = try await URLSession.shared.data(from: url)

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            print("[CalilAPI] ❌ HTTP \(code)")
            throw CalilAPIError.badStatus(code)
        }

        // レスポンスの先頭を常にログ出力（デバッグ用）
        let rawPreview = String(data: data.prefix(80), encoding: .utf8) ?? "(binary)"
        print("[CalilAPI] 📥 raw(\(data.count)B): \(rawPreview)")

        // JSONP ラッパーを除去してから JSON をパース
        let jsonData = stripJSONP(from: data)

        guard let json = try? JSONSerialization.jsonObject(with: jsonData) else {
            let preview = String(data: jsonData.prefix(120), encoding: .utf8) ?? "(binary)"
            print("[CalilAPI] ❌ JSON parse failed after strip. data: \(preview)")
            return []
        }

        guard let array = json as? [[String: Any]] else {
            print("[CalilAPI] ℹ️ Top-level is not an array, returning []")
            return []
        }

        let libraries = array.compactMap { CalilLibraryDTO(dict: $0) }
        print("[CalilAPI] ✅ Parsed \(libraries.count)/\(array.count) libraries")
        return libraries
    }

    /// JSONP ラッパーを除去する
    ///
    /// 対応パターン:
    ///   `callback([...])` `callback([...]);`  → `[...]`
    ///   `no([...])`       `no([...]);`         → `[...]`
    ///   プレーン JSON `[...]` / `{...}`         → そのまま返す
    private nonisolated func stripJSONP(from data: Data) -> Data {
        guard let raw = String(data: data, encoding: .utf8) else { return data }
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // 末尾の `;` を除去（JSONP は `callback([...]);` で終わることがある）
        if s.hasSuffix(";") {
            s = String(s.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // JSONP パターン: 識別子 `(` 中身 `)` の形かチェック
        guard s.last == ")",
              let parenOpen = s.firstIndex(of: "(") else { return data }

        let prefix = s[s.startIndex ..< parenOpen]
        guard !prefix.isEmpty,
              prefix.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" })
        else { return data }

        let innerStart = s.index(after: parenOpen)
        let innerEnd   = s.index(before: s.endIndex)
        let inner      = String(s[innerStart ..< innerEnd])
        print("[CalilAPI] 📦 JSONP stripped '\(prefix)(...)' → \(inner.prefix(60))...")
        return inner.data(using: .utf8) ?? data
    }

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

// MARK: - Book Search (OpenBD)

struct BookSearchResult: Identifiable, Sendable {
    let id = UUID()
    let isbn: String
    let title: String
    let author: String
    let publisher: String
    let coverURL: String?
}

extension CalilAPIService {
    func searchBooks(title: String) async throws -> [BookSearchResult] {
        var components = URLComponents(string: "https://api.openbd.jp/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "limit", value: "20"),
        ]
        guard let url = components.url else { return [] }

        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw CalilAPIError.badStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return json.compactMap { dict -> BookSearchResult? in
            guard let isbn = dict["isbn"] as? String,
                  let title = dict["title"] as? String, !title.isEmpty else { return nil }
            return BookSearchResult(
                isbn: isbn,
                title: title,
                author: dict["author"] as? String ?? "",
                publisher: dict["publisher"] as? String ?? "",
                coverURL: dict["cover"] as? String
            )
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
