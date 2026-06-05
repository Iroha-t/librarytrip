import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://usebrljffvmseeborgzx.supabase.co")!,
    supabaseKey: "sb_publishable_-pcbl0xNmCflbGCCPiZqZw_0ldG2j6I",
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            emitLocalSessionAsInitialSession: true
        )
    )
)

struct VisitedLibraryRow: Codable {
    var deviceId: String
    var stableKey: String
    var libraryName: String
    var prefecture: String
    var city: String
    var address: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case stableKey = "stable_key"
        case libraryName = "library_name"
        case prefecture
        case city
        case address
    }
}

/// Used when inserting/upserting (no id — Supabase generates it)
struct ReviewInsert: Codable {
    var deviceId: String
    var stableKey: String
    var libraryName: String
    var prefecture: String
    var city: String
    var rating: Int
    var comment: String
    var tags: [String]
    var isPublic: Bool
    var visitedAt: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case stableKey = "stable_key"
        case libraryName = "library_name"
        case prefecture
        case city
        case rating
        case comment
        case tags
        case isPublic = "is_public"
        case visitedAt = "visited_at"
    }
}

/// Used when reading from Supabase (includes server-generated id)
struct ReviewRow: Codable, Identifiable {
    var id: UUID
    var deviceId: String
    var stableKey: String
    var libraryName: String
    var prefecture: String
    var city: String
    var rating: Int
    var comment: String
    var tags: [String]
    var isPublic: Bool
    var visitedAt: String
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case stableKey = "stable_key"
        case libraryName = "library_name"
        case prefecture
        case city
        case rating
        case comment
        case tags
        case isPublic = "is_public"
        case visitedAt = "visited_at"
        case createdAt = "created_at"
    }
}
