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

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `bbbcc81` の Release ビルドを macOS 26.6.2 の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `ff6e52ea91558c38a79e308197b82899e347c87a000e6548fa10216ad4fc2ee3` と一致した。パネルだけが写るよう、管理ウィンドウは「設定」タブにした（[画像](media/option-click-hide/panel-settings-tab-calculator-front-full.jpg)）。Option は、ゲスト内の CGEvent で、キーダウンを先に送り、押したままクリックし、キーアップした。アプリは Calculator と TextEdit で、`show`（隠れ解除）と `activate` で前面と「直前のアプリ」を整えた。操作の記録は[panel-option-click-log.txt](media/option-click-hide/panel-option-click-log.txt)にある。**最初の 2 回の試行は、クリックが当たらず（修飾なしの通常クリックも反応しなかった）、無効だった。アイコンの座標を AX で測り直した 3 回目が有効で、それだけを結果にした。**

### パネル（Dock Studio）

| 操作 | 結果 |
| --- | --- |
| C1 TextEdit が前面で、非前面の Calculator を修飾なしクリック | Calculator が前面になった |
| C2 前面の Calculator（直前は TextEdit）を Option クリック | **Calculator が隠れ、TextEdit が前面に戻った**（Calculator=false） |
| C3 TextEdit が前面で、非前面の Calculator を Option クリック | Calculator が前面になった。TextEdit は隠れなかった（TextEdit=true） |
| C4 前面の Calculator を修飾なしクリック | 隠れなかった |
| C5 Command クリック | Finder が前面に出た（#18 の動作。回帰なし） |

どのプロセスも終了していない（pid は変わらない）。動画は[panel-option-click.mp4](media/option-click-hide/panel-option-click.mp4)（8fps。無効だった試行を含まず、C1 から C5 の有効な実行の動画）。

### 標準 Dock の実測（issue #19 の要求。パネルは終了して撮影）

ゲストの標準 Dock（自動非表示を無効にして撮影し、撮影後に元へ戻した）。同じ CGEvent の合成クリックは、標準 Dock に受け付けられた。操作の記録は[standard-dock-option-click-log.txt](media/option-click-hide/standard-dock-option-click-log.txt)、動画は[standard-dock-option-click.mp4](media/option-click-hide/standard-dock-option-click.mp4)にある。

| 操作 | 結果 |
| --- | --- |
| S1 前面の Calculator（直前は TextEdit）を修飾なしクリック | 前面は Calculator のまま。何も隠れない |
| S2 前面の Calculator を Option クリック | **Calculator が隠れ、TextEdit が前面に戻った**（Dock Studio のパネルの C2 と同じ） |
| S3 TextEdit が前面で、非前面の Calculator を Option クリック | **Calculator が前面になり、TextEdit が隠れた**（TextEdit=false） |
| S4 TextEdit が前面で、非前面の Calculator を修飾なしクリック | Calculator が前面になり、TextEdit は隠れなかった |

プロセスはどれも終了していない。

**所見（コードは直していない）**: 前面アプリを Option クリックしたときの動作（S2）は、標準 Dock と Dock Studio で一致した。一方、**非前面のアプリを Option クリックしたとき（S3）、標準 Dock は、それまで前面だったアプリを隠す。Dock Studio は隠さない（C3）。** この docs の撮影手順の手順 5（非前面は通常どおり前面に来て、直前の前面アプリは隠れない）は、標準 Dock の実測と食い違う。issue #19 の受け入れ条件と、docs の仕様を、確認してほしい。

確認できなかったこと:
- 手順 6（Calculator を終了してから、前面を TextEdit にして、未起動の Calculator を Option クリック）は、撮影していない。
- 標準 Dock のクリックで隠れる対象は、前面だったアプリの 1 つだけを確認した。3 つ以上のアプリでの動作は、撮影していない。
- 標準 Dock の画像は、操作前の 1 枚のみ（[standard-dock-before-crop.jpg](media/option-click-hide/standard-dock-before-crop.jpg)）。結果は、ログと動画による。

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
