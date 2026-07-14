import Foundation
import Security

/// Keychain に文字列を保存・取得する軽量ヘルパー。
///
/// UserDefaults と違い、Keychain のアイテムはアプリを削除して入れ直しても
/// （iOS の仕様上）残るため、端末識別子のように「再インストールしても
/// 同じ値であってほしい」データの保存に使う。
enum KeychainHelper {
    /// このアプリ専用の名前空間。他アプリと衝突しないようにする。
    private static let service = "com.librarytrip.identity"

    static func string(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      service,
            kSecAttrAccount as String:      key,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    @discardableResult
    static func set(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let baseQuery: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // 既存があれば更新、なければ追加
        let attributes: [String: Any] = [
            kSecValueData as String:        data,
            // バックアップ復元後などでも読めるよう、この端末でロック解除後にアクセス可能とする
            kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemCopyMatching(baseQuery as CFDictionary, nil)
        if status == errSecSuccess {
            return SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary) == errSecSuccess
        } else {
            var addQuery = baseQuery
            addQuery.merge(attributes) { _, new in new }
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
    }
}
