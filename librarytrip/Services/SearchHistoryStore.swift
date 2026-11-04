import Foundation

/// 地名・図書館名の検索履歴を、スマホ本体（UserDefaults）に保存・読み込みする。
/// 他の人と共有するものではなく、本人がすぐ呼び出すための履歴なので端末だけに保存する。
enum SearchHistoryStore {
    private static let key = "search_history_places"
    private static let maxCount = 10

    /// 新しいものが先頭になる順で履歴を読み込む。
    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    /// 検索したキーワードを履歴の先頭に追加する（同じものは重複させず、最大10件まで）。
    static func add(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var history = load().filter { $0 != trimmed }
        history.insert(trimmed, at: 0)
        if history.count > maxCount {
            history = Array(history.prefix(maxCount))
        }
        UserDefaults.standard.set(history, forKey: key)
    }

    /// 指定した1件を履歴から削除する。
    static func remove(_ query: String) {
        let history = load().filter { $0 != query }
        UserDefaults.standard.set(history, forKey: key)
    }

    /// 履歴をすべて消す。
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
