import Foundation
import CoreLocation
import Combine
import Supabase

@MainActor
class AppState: ObservableObject {

    // MARK: - State
    @Published var libraries: [Library] = AppState.curatedLibraries
    @Published var books: [Book] = []
    @Published var visitedLibraryIds: Set<UUID> = []
    @Published var wishlistLibraryIds: Set<UUID> = []
    @Published var myReviews: [String: ReviewRow] = [:]

    @Published var apiLibraries: [Library] = []
    @Published var isLoadingLibraries = false
    @Published var apiError: String?
    @Published var lastSearchResults: [Library] = []
    @Published var isPresentingDetailSheet = false

    private var isFetchingAll = false

    private var visitedStableKeys: Set<String> = []

    private var deviceId: String {
        if let id = UserDefaults.standard.string(forKey: "librarytrip_device_id") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "librarytrip_device_id")
        return id
    }

    private func stableKey(for library: Library) -> String {
        library.libId ?? "\(library.name)_\(library.prefecture)_\(library.city)"
    }

    // MARK: - Computed

    var allLibraries: [Library] {
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

    // MARK: - Review Cache Access

    func review(for library: Library) -> ReviewRow? {
        myReviews[stableKey(for: library)]
    }

    // MARK: - Actions

    func toggleVisited(_ library: Library) {
        let key = stableKey(for: library)
        if visitedLibraryIds.contains(library.id) {
            visitedLibraryIds.remove(library.id)
            visitedStableKeys.remove(key)
            Task {
                do {
                    try await supabase
                        .from("visited_libraries")
                        .delete()
                        .eq("device_id", value: deviceId)
                        .eq("stable_key", value: key)
                        .execute()
                } catch {
                    print("[AppState] ❌ toggleVisited delete: \(error)")
                }
            }
        } else {
            visitedLibraryIds.insert(library.id)
            visitedStableKeys.insert(key)
            Task {
                do {
                    let row = VisitedLibraryRow(
                        deviceId: deviceId,
                        stableKey: key,
                        libraryName: library.name,
                        prefecture: library.prefecture,
                        city: library.city,
                        address: library.address
                    )
                    try await supabase
                        .from("visited_libraries")
                        .upsert(row, onConflict: "device_id,stable_key")
                        .execute()
                } catch {
                    print("[AppState] ❌ toggleVisited insert: \(error)")
                }
            }
        }
    }

    func toggleWishlist(_ library: Library) {
        if wishlistLibraryIds.contains(library.id) {
            wishlistLibraryIds.remove(library.id)
        } else {
            wishlistLibraryIds.insert(library.id)
        }
    }

    // MARK: - Supabase: 起動時読み込み

    func loadVisitedLibraries() async {
        do {
            let rows: [VisitedLibraryRow] = try await supabase
                .from("visited_libraries")
                .select()
                .eq("device_id", value: deviceId)
                .execute()
                .value
            visitedStableKeys = Set(rows.map { $0.stableKey })
            syncVisitedIds()
            print("[AppState] ✅ loadVisitedLibraries: \(visitedStableKeys.count)件")
        } catch {
            print("[AppState] ❌ loadVisitedLibraries: \(error)")
        }
        do {
            let reviews: [ReviewRow] = try await supabase
                .from("reviews")
                .select()
                .eq("device_id", value: deviceId)
                .execute()
                .value
            myReviews = Dictionary(uniqueKeysWithValues: reviews.map { ($0.stableKey, $0) })
            print("[AppState] ✅ loadMyReviews: \(myReviews.count)件")
        } catch {
            print("[AppState] ❌ loadMyReviews: \(error)")
        }
    }

    private func syncVisitedIds() {
        let matched = allLibraries
            .filter { visitedStableKeys.contains(stableKey(for: $0)) }
            .map { $0.id }
        visitedLibraryIds = Set(matched)
    }

    // MARK: - Supabase: レビュー保存

    func saveReview(
        for library: Library,
        rating: Int,
        comment: String,
        tags: [LibraryTag],
        isPublic: Bool,
        visitedAt: Date
    ) async {
        let key = stableKey(for: library)

        // Mark visited if not already
        if !visitedLibraryIds.contains(library.id) {
            visitedLibraryIds.insert(library.id)
            visitedStableKeys.insert(key)
            Task {
                do {
                    let row = VisitedLibraryRow(
                        deviceId: deviceId,
                        stableKey: key,
                        libraryName: library.name,
                        prefecture: library.prefecture,
                        city: library.city,
                        address: library.address
                    )
                    try await supabase
                        .from("visited_libraries")
                        .upsert(row, onConflict: "device_id,stable_key")
                        .execute()
                } catch {
                    print("[AppState] ❌ saveReview visited upsert: \(error)")
                }
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let insert = ReviewInsert(
            deviceId: deviceId,
            stableKey: key,
            libraryName: library.name,
            prefecture: library.prefecture,
            city: library.city,
            rating: rating,
            comment: comment,
            tags: tags.map { $0.rawValue },
            isPublic: isPublic,
            visitedAt: formatter.string(from: visitedAt)
        )

        do {
            try await supabase
                .from("reviews")
                .upsert(insert, onConflict: "device_id,stable_key")
                .execute()
            // Reload to get the server-generated id into cache
            let rows: [ReviewRow] = try await supabase
                .from("reviews")
                .select()
                .eq("device_id", value: deviceId)
                .eq("stable_key", value: key)
                .limit(1)
                .execute()
                .value
            if let row = rows.first { myReviews[key] = row }
            print("[AppState] ✅ saveReview: \(library.name)")
        } catch {
            print("[AppState] ❌ saveReview: \(error)")
        }
    }

    func loadPublicReviews(for library: Library) async -> [ReviewRow] {
        let key = stableKey(for: library)
        do {
            return try await supabase
                .from("reviews")
                .select()
                .eq("stable_key", value: key)
                .eq("is_public", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            print("[AppState] ❌ loadPublicReviews: \(error)")
            return []
        }
    }

    func loadMyReview(for library: Library) async -> ReviewRow? {
        let key = stableKey(for: library)
        if let cached = myReviews[key] { return cached }
        do {
            let rows: [ReviewRow] = try await supabase
                .from("reviews")
                .select()
                .eq("device_id", value: deviceId)
                .eq("stable_key", value: key)
                .limit(1)
                .execute()
                .value
            if let row = rows.first { myReviews[key] = row }
            return rows.first
        } catch {
            print("[AppState] ❌ loadMyReview: \(error)")
            return nil
        }
    }

    func deleteVisit(for library: Library) async {
        let key = stableKey(for: library)
        visitedLibraryIds.remove(library.id)
        visitedStableKeys.remove(key)
        myReviews.removeValue(forKey: key)
        do {
            try await supabase
                .from("visited_libraries")
                .delete()
                .eq("device_id", value: deviceId)
                .eq("stable_key", value: key)
                .execute()
            try await supabase
                .from("reviews")
                .delete()
                .eq("device_id", value: deviceId)
                .eq("stable_key", value: key)
                .execute()
            print("[AppState] ✅ deleteVisit: \(library.name)")
        } catch {
            print("[AppState] ❌ deleteVisit: \(error)")
        }
    }

    // MARK: - API: 近隣図書館取得

    func fetchNearbyLibraries(latitude: Double, longitude: Double) async {
        print("[AppState] 📍 fetchNearbyLibraries(lat:\(latitude), lon:\(longitude))")
        isLoadingLibraries = true
        apiError = nil
        do {
            let dtos = try await CalilAPIService.shared.fetchNearbyLibraries(
                latitude: latitude,
                longitude: longitude,
                limit: 100
            )
            print("[AppState] DTO受信 \(dtos.count)件")
            let newLibraries = dtos.map { $0.toLibrary() }
            mergeIntoApiLibraries(newLibraries)
            lastSearchResults = newLibraries
            print("[AppState] lastSearchResults = \(lastSearchResults.count)件 / apiLibraries = \(apiLibraries.count)件")
        } catch {
            print("[AppState] ❌ fetchNearbyLibraries error: \(error)")
            apiError = error.localizedDescription
        }
        isLoadingLibraries = false
    }

    func fetchLibraries(pref: String, city: String? = nil) async {
        print("[AppState] 🏛 fetchLibraries(pref:\(pref), city:\(city ?? "nil"))")
        isLoadingLibraries = true
        apiError = nil
        do {
            let dtos = try await CalilAPIService.shared.fetchLibraries(pref: pref, city: city)
            print("[AppState] DTO受信 \(dtos.count)件")
            let newLibraries = dtos.map { $0.toLibrary() }
            mergeIntoApiLibraries(newLibraries)
            lastSearchResults = newLibraries
            print("[AppState] lastSearchResults = \(lastSearchResults.count)件 / apiLibraries = \(apiLibraries.count)件")
        } catch {
            print("[AppState] ❌ fetchLibraries error: \(error)")
            apiError = error.localizedDescription
        }
        isLoadingLibraries = false
    }

    // MARK: - API: 全国図書館一括取得

    func fetchAllLibraries() async {
        guard !isFetchingAll else { return }
        isFetchingAll = true
        isLoadingLibraries = true

        let prefectures = [
            "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
            "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
            "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県",
            "岐阜県", "静岡県", "愛知県", "三重県",
            "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
            "鳥取県", "島根県", "岡山県", "広島県", "山口県",
            "徳島県", "香川県", "愛媛県", "高知県",
            "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
        ]
        print("[AppState] 🗾 全国図書館フェッチ開始 (\(prefectures.count)都道府県)")

        // 5件ずつ並列フェッチ（レートリミット対策）
        let batchSize = 5
        for batchStart in stride(from: 0, to: prefectures.count, by: batchSize) {
            let end = min(batchStart + batchSize, prefectures.count)
            let batch = Array(prefectures[batchStart..<end])

            await withTaskGroup(of: [CalilLibraryDTO].self) { group in
                for pref in batch {
                    group.addTask {
                        (try? await CalilAPIService.shared.fetchLibraries(pref: pref)) ?? []
                    }
                }
                for await dtos in group {
                    mergeIntoApiLibraries(dtos.map { $0.toLibrary() })
                }
            }
            print("[AppState] 🗾 進捗: \(apiLibraries.count)件読み込み済み")
        }

        isLoadingLibraries = false
        isFetchingAll = false
        print("[AppState] 🗾 全国図書館フェッチ完了: \(apiLibraries.count)件")
    }

    private func mergeIntoApiLibraries(_ newLibraries: [Library]) {
        let before = apiLibraries.count
        var byLibId = Dictionary(
            apiLibraries.compactMap { l -> (String, Library)? in
                guard let lid = l.libId else { return nil }
                return (lid, l)
            },
            uniquingKeysWith: { _, new in new }
        )
        for lib in newLibraries {
            if let lid = lib.libId { byLibId[lid] = lib }
        }
        apiLibraries = Array(byLibId.values)
        syncVisitedIds()
        print("[AppState] merge: \(before)件 → \(apiLibraries.count)件 (新規\(newLibraries.count)件追加)")
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

// MARK: - Curated Ranking Data

private enum Curated {
    static let ishikawa = Library(
        name: "石川県立図書館", prefecture: "石川県", city: "金沢市",
        address: "金沢市小立野2-43-1", latitude: 36.5578, longitude: 136.6580,
        openingHours: "9:00〜19:00", closedDays: "月曜日", collectionCount: 700000,
        tags: [.beautiful, .largeCollection, .modern]
    )
    static let sendaiMediatheque = Library(
        name: "せんだいメディアテーク", prefecture: "宮城県", city: "仙台市",
        address: "仙台市青葉区春日町2-1", latitude: 38.2567, longitude: 140.8735,
        openingHours: "9:00〜22:00", closedDays: "月曜日", collectionCount: 280000,
        tags: [.beautiful, .modern, .accessible]
    )
    static let aiu = Library(
        name: "国際教養大学中嶋記念図書館", prefecture: "秋田県", city: "秋田市",
        address: "秋田市雄和椿川字奥椿岱193-2", latitude: 39.7070, longitude: 140.1750,
        openingHours: "8:00〜24:00", closedDays: "年中無休", collectionCount: 180000,
        hasStudyRoom: true,
        tags: [.beautiful, .study, .historic]
    )
    static let takeo = Library(
        name: "武雄市図書館", prefecture: "佐賀県", city: "武雄市",
        address: "武雄市武雄町大字武雄5304-1", latitude: 33.1952, longitude: 130.0148,
        openingHours: "9:00〜21:00", closedDays: "年中無休", collectionCount: 200000,
        hasCafe: true,
        tags: [.beautiful, .cafe, .modern]
    )
    static let matsubara = Library(
        name: "松原市民松原図書館", prefecture: "大阪府", city: "松原市",
        address: "松原市阿保3-5-37", latitude: 34.5737, longitude: 135.5491,
        openingHours: "9:30〜19:00", closedDays: "月曜日", collectionCount: 120000,
        tags: [.beautiful]
    )
    static let ndl = Library(
        name: "国立国会図書館", prefecture: "東京都", city: "千代田区",
        address: "千代田区永田町1-10-1", latitude: 35.6813, longitude: 139.7441,
        openingHours: "9:30〜17:00", closedDays: "日曜・祝日", collectionCount: 48110000,
        hasStudyRoom: true,
        tags: [.study, .largeCollection, .historic]
    )
    static let osakaPref = Library(
        name: "大阪府立中央図書館", prefecture: "大阪府", city: "東大阪市",
        address: "東大阪市荒本北1-2-1", latitude: 34.6682, longitude: 135.5980,
        openingHours: "9:00〜20:00", closedDays: "火曜日", collectionCount: 2500000,
        hasStudyRoom: true, hasWifi: true,
        tags: [.study, .largeCollection]
    )
    static let tokyoMetro = Library(
        name: "東京都立中央図書館", prefecture: "東京都", city: "港区",
        address: "港区南麻布5-7-13", latitude: 35.6426, longitude: 139.7249,
        openingHours: "9:30〜20:00", closedDays: "第3木曜日", collectionCount: 1900000,
        hasStudyRoom: true, hasWifi: true,
        tags: [.study, .largeCollection]
    )
    static let kanagawa = Library(
        name: "神奈川県立図書館", prefecture: "神奈川県", city: "横浜市",
        address: "横浜市西区紅葉ケ丘9-2", latitude: 35.4540, longitude: 139.6318,
        openingHours: "9:00〜19:00", closedDays: "月曜日", collectionCount: 1500000,
        hasStudyRoom: true,
        tags: [.study, .largeCollection, .historic]
    )
    static let tokyoUniv = Library(
        name: "東京大学附属図書館", prefecture: "東京都", city: "文京区",
        address: "文京区本郷7-3-1", latitude: 35.7126, longitude: 139.7628,
        openingHours: "9:00〜21:00", closedDays: "日曜・祝日", collectionCount: 10000000,
        hasStudyRoom: true,
        tags: [.largeCollection, .historic], category: .univ
    )
    static let kyotoUniv = Library(
        name: "京都大学附属図書館", prefecture: "京都府", city: "京都市",
        address: "京都市左京区吉田本町", latitude: 35.0275, longitude: 135.7815,
        openingHours: "9:00〜21:00", closedDays: "日曜・祝日", collectionCount: 7400000,
        hasStudyRoom: true,
        tags: [.largeCollection, .historic], category: .univ
    )
    static let wasedaUniv = Library(
        name: "早稲田大学図書館", prefecture: "東京都", city: "新宿区",
        address: "新宿区西早稲田1-6-1", latitude: 35.7095, longitude: 139.7198,
        openingHours: "9:00〜21:00", closedDays: "日曜・祝日", collectionCount: 5900000,
        hasStudyRoom: true,
        tags: [.largeCollection], category: .univ
    )
    static let nihonUniv = Library(
        name: "日本大学図書館", prefecture: "東京都", city: "千代田区",
        address: "千代田区九段南4-8-24", latitude: 35.6962, longitude: 139.7534,
        openingHours: "9:00〜20:00", closedDays: "日曜・祝日", collectionCount: 5500000,
        hasStudyRoom: true,
        tags: [.largeCollection], category: .univ
    )
    static let keioUniv = Library(
        name: "慶應義塾大学メディアセンター", prefecture: "東京都", city: "港区",
        address: "港区三田2-15-45", latitude: 35.6464, longitude: 139.7262,
        openingHours: "9:00〜21:00", closedDays: "日曜・祝日", collectionCount: 5340000,
        hasStudyRoom: true,
        tags: [.largeCollection, .historic], category: .univ
    )
    static let kyushuUniv = Library(
        name: "九州大学附属図書館", prefecture: "福岡県", city: "福岡市",
        address: "福岡市西区元岡744", latitude: 33.5951, longitude: 130.2178,
        openingHours: "9:00〜21:00", closedDays: "日曜・祝日", collectionCount: 4500000,
        hasStudyRoom: true,
        tags: [.largeCollection], category: .univ
    )
    static let tohokuUniv = Library(
        name: "東北大学附属図書館", prefecture: "宮城県", city: "仙台市",
        address: "仙台市青葉区片平2-1-1", latitude: 38.2555, longitude: 140.8699,
        openingHours: "9:00〜21:00", closedDays: "日曜・祝日", collectionCount: 4220000,
        hasStudyRoom: true,
        tags: [.largeCollection, .historic], category: .univ
    )
    static let osakaUniv = Library(
        name: "大阪大学附属図書館", prefecture: "大阪府", city: "吹田市",
        address: "吹田市山田丘1-1", latitude: 34.8238, longitude: 135.5243,
        openingHours: "9:00〜21:00", closedDays: "日曜・祝日", collectionCount: 4000000,
        hasStudyRoom: true,
        tags: [.largeCollection], category: .univ
    )
    static let hokkaidoUniv = Library(
        name: "北海道大学附属図書館", prefecture: "北海道", city: "札幌市",
        address: "札幌市北区北8条西5丁目", latitude: 43.0718, longitude: 141.3409,
        openingHours: "9:00〜21:00", closedDays: "日曜・祝日", collectionCount: 3800000,
        hasStudyRoom: true,
        tags: [.largeCollection, .historic], category: .univ
    )
    static let tagajo = Library(
        name: "多賀城市立図書館", prefecture: "宮城県", city: "多賀城市",
        address: "多賀城市中央2-3-1", latitude: 38.2935, longitude: 141.0076,
        openingHours: "9:00〜22:00", closedDays: "年中無休", collectionCount: 150000,
        hasWifi: true, hasCafe: true,
        tags: [.cafe, .modern, .accessible]
    )
    static let ebina = Library(
        name: "海老名市立中央図書館", prefecture: "神奈川県", city: "海老名市",
        address: "海老名市めぐみ町4-1", latitude: 35.4440, longitude: 139.3889,
        openingHours: "9:00〜22:00", closedDays: "年中無休", collectionCount: 180000,
        hasWifi: true, hasCafe: true,
        tags: [.cafe, .modern, .accessible]
    )
    static let shunan = Library(
        name: "周南市立徳山図書館", prefecture: "山口県", city: "周南市",
        address: "周南市速玉町8-47", latitude: 34.0590, longitude: 131.8030,
        openingHours: "10:00〜22:00", closedDays: "年中無休", collectionCount: 130000,
        hasWifi: true, hasCafe: true,
        tags: [.cafe, .modern]
    )
    static let okazaki = Library(
        name: "岡崎市立中央図書館", prefecture: "愛知県", city: "岡崎市",
        address: "岡崎市明大寺町茶園11-1", latitude: 34.9494, longitude: 137.1753,
        openingHours: "9:30〜19:00", closedDays: "月曜日", collectionCount: 400000,
        hasCafe: true,
        tags: [.cafe]
    )
}

extension AppState {
    static let beautifulRanking: [Library] = [
        Curated.ishikawa, Curated.sendaiMediatheque, Curated.aiu, Curated.takeo, Curated.matsubara
    ]
    static let studyRanking: [Library] = [
        Curated.aiu, Curated.ndl, Curated.osakaPref, Curated.tokyoMetro, Curated.kanagawa
    ]
    static let cafeRanking: [Library] = [
        Curated.takeo, Curated.tagajo, Curated.ebina, Curated.shunan, Curated.okazaki
    ]
    static let collectionRanking: [Library] = [
        Curated.ndl, Curated.tokyoUniv, Curated.kyotoUniv, Curated.wasedaUniv, Curated.nihonUniv,
        Curated.keioUniv, Curated.kyushuUniv, Curated.tohokuUniv, Curated.osakaUniv, Curated.hokkaidoUniv
    ]
    static let curatedLibraries: [Library] = [
        Curated.ishikawa, Curated.sendaiMediatheque, Curated.aiu, Curated.takeo, Curated.matsubara,
        Curated.ndl, Curated.osakaPref, Curated.tokyoMetro, Curated.kanagawa,
        Curated.tokyoUniv, Curated.kyotoUniv, Curated.wasedaUniv, Curated.nihonUniv,
        Curated.keioUniv, Curated.kyushuUniv, Curated.tohokuUniv, Curated.osakaUniv, Curated.hokkaidoUniv,
        Curated.tagajo, Curated.ebina, Curated.shunan, Curated.okazaki
    ]
}
