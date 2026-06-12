import SwiftUI
import CoreText

@main
struct librarytripApp: App {
    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func registerCustomFonts() {
        let fontFiles = [
            "ZenOldMincho-Regular",
            "ZenOldMincho-Medium",
            "ZenOldMincho-SemiBold",
            "ZenOldMincho-Bold",
            "ZenOldMincho-Black",
        ]
        for name in fontFiles {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                print("[Font] ⚠️ バンドルに見つかりません: \(name).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                print("[Font] ⚠️ 登録失敗: \(name) — \(error?.takeRetainedValue().localizedDescription ?? "不明なエラー")")
            }
        }
    }
}
