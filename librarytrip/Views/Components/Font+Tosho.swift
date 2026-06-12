import SwiftUI

extension Font {
    /// Zen Old Mincho フォント（明朝体）
    static func zenMincho(size: CGFloat, weight: ZenMinchoWeight = .regular) -> Font {
        .custom(weight.postScriptName, size: size)
    }

    enum ZenMinchoWeight {
        case regular, medium, semiBold, bold, black

        var postScriptName: String {
            switch self {
            case .regular:  return "ZenOldMincho-Regular"
            case .medium:   return "ZenOldMincho-Medium"
            case .semiBold: return "ZenOldMincho-SemiBold"
            case .bold:     return "ZenOldMincho-Bold"
            case .black:    return "ZenOldMincho-Black"
            }
        }
    }
}
