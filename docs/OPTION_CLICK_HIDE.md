# Option クリックで現在のアプリを隠す

## 仕様

Custom Dock で、前面にある実行中のアプリのアイコンを Option キーだけを押してクリックすると、そのアプリを隠す。アプリが隠れると、macOS が直前のアプリを前面に戻す。

次の場合は、従来どおりの起動処理になる。

- 通常のクリック。
- 前面ではないアプリへの Option クリック。
- 対象が起動していない場合、または終了済みの場合。ほかのアプリを隠すことはない。
- Option に Command、Control、Shift を加えたクリック。
- アプリ以外の項目（フォルダ、ファイル、URL）。

判定は、`DockStudio/Services/OptionClickHide.swift` の `OptionClickPolicy.action` が行う純粋な関数になる。修飾キーは、`clickItem(_:modifiers:)` が受け取る値（クリックのイベントの修飾キー）を使う。Option のみのときに、この判定へ振り分ける。ホストの Dock の挙動は実測しておらず、前面ではないアプリへの Option クリックで「現在のアプリを隠す」動きは実装していない。

## 検証

自動テストは `DockStudioTests/OptionClickHideTests.swift` にあり、判定の組合せだけを縛る。実際のアプリを隠す動作と画面は、未検証になる。

## 撮影の手順

撮影は専任の担当が、専用のヘッドレス VM のゲストで行う。ホストでは行わない。

1. ゲストで Calculator と TextEdit を起動しておく。Calculator を前面にする。
2. 検証用データは空のディレクトリでよい（`DOCKSTUDIO_DATA_DIR=<空のディレクトリ>`）。既定のプロファイルで起動し、デスクトップに Dock を表示する。Calculator と TextEdit をプロファイルに追加する。
3. Calculator を前面にした状態で、Dock の Calculator を Option を押しながらクリックする。Calculator が隠れ、直前のアプリが前面に戻る。
4. 通常のクリックで Calculator を再び前面にし、Option を押さずにクリックしても隠れないことを確認する。
5. TextEdit が前面のとき、Calculator を Option クリックする。Calculator が通常どおり前面に来て、TextEdit は隠れないことを確認する。
6. Calculator を終了し、前面を TextEdit にしてから Dock の Calculator を Option クリックする。TextEdit が隠れず、Calculator が起動する（または何もしない）ことを確認する。

撮る画像と動画は次になる。

- 画像: 手順3の前後（Calculator が前面、隠れた後）。
- 動画: 手順3から5まで。Option の押下が分かるように、操作のログを添える。
