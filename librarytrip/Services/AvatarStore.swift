import UIKit

/// ユーザーアイコン（プロフィール写真）の保存・読み込みを一箇所に集約する。
/// マイページで変更した写真を、ホームなど他の画面でも同じキーから読めるようにする。
enum AvatarStore {
    private static let key = "avatar_image"

    /// 保存済みアイコン画像を読み込む（未設定なら nil）。
    static func load() -> UIImage? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return UIImage(data: data)
    }

    /// アイコン画像を保存する（JPEG圧縮）。
    @discardableResult
    static func save(_ image: UIImage) -> UIImage? {
        guard let compressed = image.jpegData(compressionQuality: 0.7) else { return nil }
        UserDefaults.standard.set(compressed, forKey: key)
        return UIImage(data: compressed)
    }
}
