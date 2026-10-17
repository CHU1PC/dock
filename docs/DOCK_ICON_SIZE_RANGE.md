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
