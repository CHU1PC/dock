# Option クリックで現在のアプリを隠す

## 仕様

Custom Dock で、実行中のアプリのアイコンを Option キーだけを押してクリックしたときの動作を、標準 Dock の実測に合わせた。

- 前面アプリのアイコン: そのアプリを隠す。macOS が直前のアプリを前面に戻す。
- 前面ではない実行中アプリのアイコン: 対象を前面にし、クリックの時点で前面だったアプリを隠す。前面だったアプリは、クリックの時点の `NSWorkspace.shared.frontmostApplication` で決める。標準 Dock の実測は `docs/media/option-click-hide/standard-dock-option-click-log.txt` の S3 にある。

次の場合は、従来どおりの起動処理になる。

- 通常のクリック。
- 対象が起動していない場合、または終了済みの場合。ほかのアプリを隠すことはない。
- 前面だったアプリが Dock Studio 自身の場合、または前面アプリを取得できない場合。Dock Studio は隠さない。
- Option に Command、Control、Shift を加えたクリック。
- アプリ以外の項目（フォルダ、ファイル、URL）。

前面だったアプリが Finder の場合は、標準 Dock で隠れるか未測定のため、通常のアプリと同じに扱い、隠す。

判定は、`DockStudio/Services/OptionClickHide.swift` の `OptionClickPolicy.action` が行う純粋な関数になる。修飾キーは、`clickItem(_:modifiers:)` が受け取る値（クリックのイベントの修飾キー）を使い、Option のみのときにこの判定へ振り分ける。対象の前面化は、非アクティブなパネルからでも効くように、`activates = true` の `NSWorkspace.openApplication(at:configuration:)` で行う。

## 検証

自動テストは `DockStudioTests/OptionClickHideTests.swift` にあり、判定の組合せだけを縛る。実際に隠す動作と画面の確認結果は、撮影の担当が追記する。

## 実画面の確認（専用ヘッドレス VM）

この節の C1 から C3 は、非前面アプリの Option クリックを修正する前（コミット `bbbcc81`）の結果になる。修正後の VM での再確認は未実施（未検証）。

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

**所見**: 前面アプリを Option クリックしたとき（S2）は、標準 Dock と Dock Studio が一致した。非前面のアプリを Option クリックしたとき（S3）、標準 Dock は、それまで前面だったアプリを隠す。Dock Studio は隠さなかった（C3）。この食い違いは、上の「仕様」のとおり、標準 Dock に合わせて実装を直した。撮影手順の手順 5 も、実測に合わせて直してある。

確認できなかったこと:
- 手順 6（Calculator を終了してから、前面を TextEdit にして、未起動の Calculator を Option クリック）は、撮影していない。
- 標準 Dock のクリックで隠れる対象は、前面だったアプリの 1 つだけを確認した。3 つ以上のアプリでの動作は、撮影していない。
- 標準 Dock の画像は、操作前の 1 枚のみ（[standard-dock-before-crop.jpg](media/option-click-hide/standard-dock-before-crop.jpg)）。結果は、ログと動画による。

### 再撮影: 非前面アプリの Option クリックの修正後（コミット `ac235cf`、2026-10-18）

専用 VM（macOS 26.6.2）で、最新のビルドを撮り直した。実行ファイルの SHA-256 は、ホストとゲストで `b7ac5f218befdc3b48820b300c0ae1c4c693443d20ae70c9fac00d4b6f1f3327` と一致した。パネルだけが写るよう、管理ウィンドウは「設定」タブにした。Option は本物のキー押下で、アイコンの座標は AX で測った。ログは[fixed-panel-option-click-log.txt](media/option-click-hide/fixed-panel-option-click-log.txt)にあり、動画は[panel-option-click-fixed.mp4](media/option-click-hide/panel-option-click-fixed.mp4)（8fps、D1 から D5 の全操作）。

```
D1 Option click on front Calculator (prev TextEdit)
  -> front=TextEdit | TextEdit=true Calculator=false Finder=true
D2 Option click on NON-front Calculator (TextEdit front)  expect TextEdit=false Calculator=true
  -> front=Calculator | TextEdit=false Calculator=true Finder=true
D3 plain click on front Calculator
  -> front=Calculator | TextEdit=true Calculator=true Finder=true
D4 Command click on Calculator (Finder reveal)
  -> front=Finder | TextEdit=true Calculator=true Finder=true
D5 Option click on NOT-running Calculator (TextEdit front)
  -> front=Calculator | TextEdit=true Calculator=true Finder=true   (Calculator が起動。pid は新しい値)
```
- D2: 非前面の Calculator を Option クリックすると、Calculator が前面になり、それまで前面だった TextEdit が隠れた（`TextEdit=false Calculator=true`）。標準 Dock の S3 と一致した。
- D1: 前面アプリの Option クリックは、隠れて直前へ戻る。D3（修飾なし）、D4（Command）は回帰なし。D5: 未起動のアプリの Option クリックは、Calculator を起動し、TextEdit は隠れなかった。プロセスはどれも終了していない（TextEdit の pid は変わらない）。
- 標準 Dock の S3 の再測（Option クリック後の画像）: `front=Calculator | TextEdit=false Calculator=true`（[画像](media/option-click-hide/standard-dock-after-option-click-full.jpg)、[ログ](media/option-click-hide/standard-dock-option-click-log-2.txt)）。画像には、Calculator が前面で、TextEdit のウィンドウが隠れ、Finder のウィンドウが残っている様子が写る。

## 撮影の手順

撮影は専任の担当が、専用のヘッドレス VM のゲストで行う。ホストでは行わない。

1. ゲストで Calculator と TextEdit を起動しておく。Calculator を前面にする。
2. 検証用データは空のディレクトリでよい（`DOCKSTUDIO_DATA_DIR=<空のディレクトリ>`）。既定のプロファイルで起動し、デスクトップに Dock を表示する。Calculator と TextEdit をプロファイルに追加する。
3. Calculator を前面にした状態で、Dock の Calculator を Option を押しながらクリックする。Calculator が隠れ、直前のアプリが前面に戻る。
4. 通常のクリックで Calculator を再び前面にし、Option を押さずにクリックしても隠れないことを確認する。
5. TextEdit が前面のとき、非前面の Calculator を Option クリックする。Calculator が前面になり、TextEdit が隠れることを確認する（標準 Dock と同じ）。
6. Calculator を終了し、前面を TextEdit にしてから Dock の Calculator を Option クリックする。TextEdit が隠れず、Calculator が起動する（または何もしない）ことを確認する。

撮る画像と動画は次になる。

- 画像: 手順3の前後（Calculator が前面、隠れた後）。
- 動画: 手順3から5まで。Option の押下が分かるように、操作のログを添える。
