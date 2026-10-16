# 検証記録

## 実行環境

macOS 26.5.2 の Apple Silicon で実行した。Rust は 1.98.1、GPUI は 0.2.2 に固定している。対象 OS は macOS 15 以降であるが、macOS 15 と Intel Mac での動作は未確認である。

## 自動テスト

```sh
cargo test --manifest-path gpui/Cargo.toml --locked -j 2
```

17 件が通った。実際の Swift ヘルパーを起動し、一時保存先でプロファイルの保存、下書きの復元、設定の更新、削除の取り消し、破損した設定の保護、排他制御、不正リンクの拒否、将来の設定項目の保護、キャンセル要求後のプロトコルを確認した。描画側では、アイコン加工、配置の寸法、当たり判定、自動非表示、集中タイマーを確認した。

```sh
swift test --scratch-path /tmp/dockstudio-headless-tests
```

既存の 44 件が通った。SwiftUI の画面は起動していない。

## ネイティブ連携とアプリ

```sh
gpui/target/debug/dockstudio-gpui --native-menu-check
```

画面を表示せず、NSMenu の項目を実行し、設定とプロファイルのコマンドが返ることを確認した。出力は `Native menu actions passed` だった。ポインタによるメニュー操作は未確認である。

```sh
gpui/scripts/build-app.sh
DOCKSTUDIO_DATA_DIR=/tmp/dockstudio-gpui-bundle-verification 'gpui/target/Dock Studio.app/Contents/MacOS/DockStudio' --bridge-check
```

開発用のアプリバンドルを組み立てた。同梱したヘルパーから、一時保存先の 2 プロファイルを読み込めた。出力は `Loaded 2 profiles; read_only=false` だった。Info.plist の検査も通った。アプリの管理画面と Dock は起動していない。

## 描画

移行途中のビルドで、管理画面の 3 ページ、外観設定の下部、Dock の通常、白黒、ガラス調、透明の状態を画面外で描画し、PNG を取得できた。ホバーと自動非表示の状態を制御した 60 フレームも取得した。実際のマウス操作の録画ではない。

2026-10-17 に画面ロック解除後の再撮影が成功した。コマンドは次のとおりである。

```sh
DOCKSTUDIO_DATA_DIR=/tmp/dockstudio-gpui-unlocked-data DOCKSTUDIO_CAPTURE_DIR=/tmp/dockstudio-gpui-unlocked-images gpui/target/debug/dockstudio-gpui --capture
```

出力は次のとおりだった。終了コードは 0 だった。

```text
Captured GPUI screens and 60 transition frames at /tmp/dockstudio-gpui-unlocked-images
```

共通の寸法計算と非同期 frame 更新を使う撮影が通った。各撮影時に NSView と GPUI の viewport の一致を検査した。画像 8 枚と、状態変化を示す 5 秒の動画を docs/media/gpui に保存した。日本語の表示、入力欄、通常、白黒、ガラス調の描画、ホバー、非表示と再表示のフレームを目視で確認した。

前日の撮影失敗は Mac の画面ロックが原因だった。旧ビルドでも同じ失敗が起きた。現在は、ロック中の撮影を開始せず、理由を表示する。

原因の確認に使ったコマンドは次のとおりである。

```sh
swift -e 'import CoreGraphics; import Foundation; if let session = CGSessionCopyCurrentDictionary() as? [String: Any] { for key in ["CGSSessionScreenIsLocked", "kCGSessionOnConsoleKey", "kCGSessionLoginDoneKey"] { print("\(key)=\(String(describing: session[key]))") } }'
```

出力は次のとおりだった。

```text
CGSSessionScreenIsLocked=Optional(1)
kCGSessionOnConsoleKey=nil
kCGSessionLoginDoneKey=Optional(1)
```

## 未確認の範囲

- 実デスクトップでのポインタ操作、click-through、右クリックメニュー、メニューバー、標準ダイアログとの往復を確認する必要がある。
- Spaces、全画面、ディスプレイの抜き差しを確認する必要がある。
- 日本語 IME と連続操作を確認する必要がある。
- CPU、GPU、メモリとホバー時の応答を測る必要がある。SwiftUI より軽いとは断定しない。
- GPUI の AX ツリーがないため、VoiceOver は未対応である。
- 開発用アプリは一般配布用の署名と公証を済ませていない。
- 依存パッケージの block 0.1.6 と proc-macro-error2 2.0.1 に、将来の Rust との互換性の警告が出る。今回のビルドを失敗させる警告ではない。
