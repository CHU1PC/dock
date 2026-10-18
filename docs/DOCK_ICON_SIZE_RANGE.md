# Dock のアイコンサイズの範囲

## 標準 Dock の範囲の確認結果

Apple の Dock 設定仕様（[Dock payload](https://developer.apple.com/documentation/devicemanagement/dock)）では、tile size の設定範囲は16〜128になる。

標準 Dock の実際の UI の範囲は、macOS 26.6.2（ビルド 25G83）の専用ヘッドレス VM で、「システム設定 > デスクトップと Dock」の Size スライダーを両端までドラッグし、操作のたびに `defaults read com.apple.dock tilesize` を読んで確認した。

| 操作 | `tilesize` |
| --- | --- |
| 開いた直後 | 64 |
| 左端までドラッグ | 16 |
| 右端までドラッグ | 128 |

標準 Dock の Size スライダーの範囲は、Apple の仕様値と同じ16〜128だった。Magnification スライダーの `largesize` も、`defaults` の読み取りでは16〜128に見えたが、値の記録と画像は残していない。Accessibility API による AXMinValue と AXMaxValue の取得は、VM 内で権限のないバイナリからは値が返らず、行えなかった。画面の画像は [最小](media/dock-icon-size-range/standard-dock-size-min.png) と [最大](media/dock-icon-size-range/standard-dock-size-max.png) になる。最大の画像は撮影時にスライダーが右端へ動く途中の状態で、値は `defaults` の読み取りを根拠にしている。

macOS 26.6.2 以外のバージョンでの範囲は確認していない。

## 変更内容

`DockSettings.iconSizeRange` を16〜128として定義し、次の2か所で共通に使う。

| 箇所 | 変更前 | 変更後 |
| --- | --- | --- |
| 保存データの検証（`DockDocument.validate`） | 40〜76 | 16〜128 |
| 設定画面のスライダー（刻みは2のまま） | 40〜76 | 16〜128 |

白黒とガラス調の変換解像度（`DockIconRenderer`、76pt基準）は変えていない。128 px の設定や拡大率2倍で荒くならないかと、キャッシュ上限との関係は #74 で扱う。

古い保存データとバックアップは、40〜76の値も、`revealAnimationDuration` が欠けた形式もそのまま読み込める。範囲外の値と非有限値は従来どおり拒否する。`iconSize` 自体は従来から必須項目で、この変更でも変えていない。

## 検証

### 自動テスト

2026-10-17 に、origin/main（PR #72 のマージ後）へ rebase した状態で、ホストで以下を確認した。

| 項目 | 結果 |
| --- | --- |
| Release ビルド | 成功した |
| `swift test` | 93件すべて成功した（本変更の新規5件を含む） |
| 16、40、76、128 | 保存、再読込、バックアップ復元で保持された |
| 15.99、128.01、0、負数、無限大、NaN | 保存を置き換えず、エンコードも失敗した |
| 40〜76の値と、`revealAnimationDuration` が欠けたデータ | 値を保ったまま読み込めた |
| スライダーの一時値 | 16と128を一時値に設定し、確定で保存された |

`xcodebuild test` は、アプリをテストホストとして起動するためホストの画面にアプリが表示される。ホストでは実行せず、`build-for-testing` のビルド成功だけを確認した。

### 画面

macOS 26.6.2、1600×1000の専用ヘッドレス VM で、Release ビルドを使って確認した。ホストのデスクトップには、アプリや VM の画面を表示していない。

| 項目 | 結果 | 画像 |
| --- | --- | --- |
| 最小（16 px）の設定画面 | スライダーが左端になり、「16 px」と表示された | [設定画面](media/dock-icon-size-range/settings-16.png) |
| 最小（16 px）のデスクトップの Dock | 6項目が収まった。Terminal の位置（16 px のアイコン）をクリックして、Terminal が前面になった | [Dock](media/dock-icon-size-range/desktop-dock-16.png) |
| 最大（128 px）の設定画面 | スライダーが右端になり、「128 px」と表示された | [設定画面](media/dock-icon-size-range/settings-128.png) |
| 最大（128 px）、拡大率2倍、20項目 | Dock は画面幅に収まり、あふれた項目は端で切れる。スクロール操作は確認していない | [Dock](media/dock-icon-size-range/desktop-dock-128-many-items.png)、[画面内プレビュー](media/dock-icon-size-range/preview-128-many-items.png) |
| 最大（128 px）、左配置、20項目 | 画面の高さに収まり、下端の項目が切れる | [Dock](media/dock-icon-size-range/desktop-dock-128-left.png) |
| 最大（128 px）、右配置、6項目 | 画面の高さに収まり、下端の項目が切れる | [Dock](media/dock-icon-size-range/desktop-dock-128-right.png) |
| スライダーの操作 | 52から16、128、52へ動かし、値と Dock の大きさが追従した | [動画](media/dock-icon-size-range/slider-16-to-128.mp4) |

動画は約23秒で、撮影時刻の間隔を維持して15fpsに変換した。倍速にはしていない。VM の撮影であり、実機での描画性能を示すものではない。

画面内プレビューの確認で、128 px では次の見た目の問題を見つけた。#68 の範囲ではなく、#75 で扱う。

- 下配置の画面内プレビューの Dock が、「デスクトップに Dock を表示」ボタンに重なる。ボタンは右上の切替ボタンから操作できる。
- 左右配置の画面内プレビューの Dock が、ウィンドウの内容や右上の切替ボタンに重なる。

### 未検証

- 変更前（40〜76）のビルドとの比較画像
- macOS 15〜25 での標準 Dock の範囲
- Retina（2倍）の画面。VM の画面は1600×1000で、ピクセル密度は確認していない。#76 で扱う
- 128 px での描画性能
- 16 px と 128 px のアイコンの当たり判定の厳密な範囲。Terminal のクリックを1回だけ確認した
- `xcodebuild test` の件数。テストホストのアプリがホストの画面に表示されるため実行していない。Xcode 側の登録は `xcodebuild build-for-testing` の成功で確認した

## 既知の制約

`iconSize` は保存データの必須項目で、欠けた古いデータは読み込めない。`revealAnimationDuration` のような既定値を持たない。この変更では挙動を変えていない。欠けたデータを読み込めるようにするかは、別に判断する。

## #76 Retina での範囲とクリック領域

### 現在の状況

受け入れ条件のうち、コードと単体テストで確認できる範囲を調べた。Retina 画面の画像撮影と、座標によるクリック領域の確認は未実施になる。今回の作業では検証 VM を使わず、アプリも起動していない。

### コードと単体テストから分かること

| 項目 | 分析 | 根拠 |
| --- | --- | --- |
| サイズの単位 | `iconSizeRange` は 16〜128 の `Double` で、設定画面の表示ラベルは `px` だが、`ItemIcon` と Dock のレイアウトへ SwiftUI の frame 寸法として渡す。コードからは画面上のポイント寸法として扱っていると読める。 | `DockStudio/Models/DockDocument.swift:115-116`、`DockStudio/SettingsPreview.swift:80-85`、`DockStudio/CustomDockPreview.swift:232`、`DockStudio/CustomDockPreview.swift:642-665` |
| 保存と入力範囲 | ドキュメント検証は16〜128の範囲と有限値を要求する。設定スライダーも同じ範囲で2刻みになる。 | `DockStudio/Models/DockDocument.swift:149-150`、`DockStudio/SettingsPreview.swift:82-84` |
| 拡大率 | `magnificationScale` の初期値は1.45、検証範囲は1〜2。ポインタ下のアイコンは設定倍率、隣は倍率差の45%、2つ隣は12%で拡大する。サイズ128、倍率2では対象アイコンのレイアウト寸法は256ポイントになる。 | `DockStudio/Models/DockAppearance.swift:67-68`、`DockStudio/Models/DockAppearance.swift:100-114`、`DockStudio/CustomDockPreview.swift:221-233` |
| 1x と 2x のピクセル数 | backing scale が1なら16/128ポイントは概ね16/128 backing pixels、2なら32/256 backing pixelsに対応する見込みになる。倍率2の最大アイコンは、それぞれ32/256ポイントなので、2xでは概ね64/512 backing pixelsになる。これはポイント寸法と backing scale の乗算からの計算で、実際のスクリーン描画やクリック結果を観察した事実ではない。 | 上記の SwiftUI frame と倍率計算。1x/2x の VM 描画は未確認 |
| ヒット領域 | アイコンは `Button` のラベル内にあり、アイコンと項目コンテナは寸法・padding・`contentShape(Rectangle())` で構成する。ただしコンテナの形状がネストされた `Button` の実際のヒット領域をどこまで広げるかは、ソースと現行テストだけでは確定できない。ポイント座標を backing pixels に変換した端の許容差も未測定になる。 | `DockStudio/CustomDockPreview.swift:227-244`、`DockStudio/CustomDockPreview.swift:278-294`、ヒット領域を測るテストはない |
| 既存テスト | 範囲端16/128の保存、アーカイブ復元、範囲外拒否、スライダー確定を確認する。倍率2での縦パネル寸法を確認するテストもある。Retina スケール、画像の見切れ、クリック位置やヒット領域はテストしていない。 | `DockStudioTests/DockIconSizeRangeTests.swift:6-70`、`DockStudioTests/DockAppearanceTests.swift:303-313` |

`px` という設定ラベルとコード上の SwiftUI レイアウト寸法は意味が異なる。実機の見え方を確認するまでは、このラベルが物理ピクセルを表すとは断定しない。

### 受け入れ条件ごとの状況

| 条件 | 状況 |
| --- | --- |
| Retina で16、128、最大拡大、左右・下配置、多数項目を撮影する | 未実施。VM の Retina backing scale で表示と収まりを観察する必要がある |
| 16 と128のクリック領域を座標または複数位置のクリックで確認する | 未実施。コードから寸法は追えるが、ボタンの実ヒット領域は画面上で測っていない |
| 結果を docs に残し、問題があれば Issue 化する | コード分析と未実施範囲を本節に記録した。画面結果とクリック計測は残作業になる |

### VM で行う手順

1. 専用の Retina 対応 macOS VM を起動し、ゲストの `NSScreen.main?.backingScaleFactor` が2であることを確認して記録する。解像度と macOS バージョンも記録する。
2. DockStudio を起動し、使い捨てプロファイルを選ぶ。表示倍率を最大の2にして、下、左、右の配置をそれぞれ確認する。
3. 下配置では6項目と、多数項目（画面幅を超える数）の両方を用意する。左右配置では画面高を超える数も用意し、16と128の両端で Dock 全体、端の項目、スクロール可能な位置を撮影する。
4. 16と128それぞれについて、倍率オフ時、倍率オン時の対象アイコン中央、四辺の中点、四隅付近をクリックする。各点の画面座標と、項目が起動または開いたかを記録する。隣の項目との境界も両側から試し、誤起動と無反応を記録する。
5. 可能ならアクセシビリティ API から各 Button の frame を画面座標で取得する。frame のポイント寸法と `backingScaleFactor` を掛けた backing pixels を並べ、実クリック結果と照合する。
6. 16/128、倍率、向き、項目数ごとに撮影画像と測定値を保存する。16と128のどちらかで見切れ、誤クリック、反応しない領域があれば、症状と再現条件を別 Issue に記録する。

この手順は未実施で、実機・VM の観察結果を示すものではない。
