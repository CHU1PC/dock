import CoreGraphics

/// 背景の厚みを、拡大前のアイコンに合わせて求める。拡大の余白はウィンドウ側が確保する。
enum DockBackdropFit {
    static let bottomContentInset: CGFloat = 10
    static let sideContentInset: CGFloat = 12
    static let runningIndicatorRow: CGFloat = 9
    static let tileHeight: CGFloat = 54
    static let sideTileWidth: CGFloat = 140

    static func bottomThickness(iconSize: Double, hasTile: Bool) -> CGFloat {
        let content = max(CGFloat(iconSize) + runningIndicatorRow, hasTile ? tileHeight : 0)
        return content + bottomContentInset * 2
    }

    static func sideThickness(iconSize: Double, hasTile: Bool) -> CGFloat {
        let content = max(CGFloat(iconSize), hasTile ? sideTileWidth : 0)
        return content + sideContentInset * 2
    }
}
