# GPUI の画面記録

2026-10-17 に、最新の GPUI ビューを画面外に描画して撮影した。一時保存先を使い、管理画面と Dock を作業中のデスクトップに表示していない。

| ファイル | 内容 |
| --- | --- |
| custom-dock.png | Custom Dock の管理画面 |
| settings.png | 配置と動作の設定 |
| settings-appearance.png | スクロールした背景、アイコン、動きの設定 |
| profiles.png | プロファイル編集 |
| dock-original.png | 通常のアイコン |
| dock-monochrome.png | 白黒のアイコン |
| dock-glass.png | 透けた単色のアイコン |
| dock-transparent.png | 背景を完全透明にした Dock |
| dock-motion.mp4 | ホバー拡大、非表示、再表示の 5 秒の動画 |

動画は、GPUI の状態を制御して撮影した 60 フレームから作った。実マウス操作の録画ではない。撮影中は NSView と GPUI の viewport の一致を検査した。

撮影のコマンドと未確認の範囲は、[検証記録](../../../gpui/VERIFICATION.md) に記載している。
