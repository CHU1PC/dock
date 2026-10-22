# 区切りの線の長さをアイコンサイズに合わせる

## 変更内容

区切りの線の長さが固定値で、アイコンサイズ16では背景の外に出て、128ではアイコンよりずっと短かった。変更前の固定値は次のとおり。

| 場所 | 変更前の固定値 |
| --- | --- |
| `DockStudio/CustomDockPreview.swift:158-160` の `dividerBefore` の線 | 下配置は高さ40、左右配置は幅50 |
| `DockStudio/CustomDockPreview.swift:268-270` の `barElement` のスペーサーの線 | 下配置は高さ40、左右配置は幅50 |
| `DockStudio/DockIconSizeResize.swift` の `DockIconSizeResizeHandle` の線 | 下配置は高さ40、左右配置は幅40。操作領域は54 |

3本とも、`DockDividerLine.size(iconSize:vertical:)`（`DockStudio/Services/DockDividerLine.swift`）で長さを決める。長さは表示中のアイコンサイズ（`displayIconSize`）と同じで、太さは1のままになる。下配置は高さ、左右配置は幅が長さになる。長さはアイコンサイズ以下なので、背景の厚み（アイコンサイズ + 30以上）を超えない。#214 の `DockMetrics.backdropThickness(for:)` に変わっても超えない。

リサイズ用の線は、操作領域の長さを `max(54, 線の長さ)` にした。128でも線全体をドラッグできる。ドラッグの計算（`DockIconSizeResize.size`）は変えていない。

線の長さは並び方向と直交する方向の寸法なので、並び方向の寸法（`DockMetrics.length` の `10 + 11` や、スペーサーの `10 + 11`）は変わらない。そのため、項目の位置と `DockMetrics.length` は変えていない。

## 自動テスト

`DockStudioTests/DockDividerLineTests.swift` で、長さの純粋な関数を確認する。

- アイコンサイズ16、52、128で、長さがアイコンサイズと一致する。
- 下配置は幅1、左右配置は高さ1になる。
- 設定範囲の全体で、長さがアイコンサイズ以下になる。
- NaN と0では、長さが1になる。

| 項目 | 結果 |
| --- | --- |
| `swift test` | `Executed 462 tests, with 0 failures` |
| Release ビルド | `** BUILD SUCCEEDED **` |
| Debug の `build-for-testing` | `** TEST BUILD SUCCEEDED **` |

## 撮影の手順

画面が変わるので、専用ヘッドレス macOS VM で撮影する。ホストには Dock Studio を表示しない。

### 検証用データ

ゲストで `/Users/Shared/dock-217` を作り、アプリ項目、スペーサー、フォルダ項目を含む `profiles.json` を置く。設定は下配置、アイコンサイズ52とする。`DOCKSTUDIO_DATA_DIR=/Users/Shared/dock-217` で Dock Studio を起動する。

### 操作と期待結果

1. アイコンサイズ16、52、128で、デスクトップ用パネルを表示する。線の長さがアイコンの高さに近く、背景の外に出ないことを確認する。
2. 左配置と右配置にして、同じ3つのサイズで、線の長さ（横線の幅）がアイコンの幅に近いことを確認する。
3. ゴミ箱の前の線を上下にドラッグし、アイコンサイズが変わり、線の長さも追従することを確認する。
4. 各サイズの静止画と、ドラッグ操作の動画を保存する。

予定する画像と動画は、`docs/media/divider-line-length/` に保存する。

## 未検証

- 実機と VM の画面での見え方。このブランチでは撮影していない。
- #214 のブランチと合わせたときの背景との関係。計算上は収まるが、結合後の画面では確認していない。
- 左右配置とアイコンの自動縮小（`displayIconSize` が設定値より小さくなる場合）の画面での確認。
