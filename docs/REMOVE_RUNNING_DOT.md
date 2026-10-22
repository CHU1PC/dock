# 起動中の点の廃止

## 仕様

アプリアイコンの下に出ていた、起動中を示す点を描かなくした。設定画面の「起動中のアプリに点を表示」も削除した。効果のない項目としては残していない。

点のために確保していた余白も外した。背景の厚みと長さは、アイコンだけに合わせる。VoiceOver の「起動中」というラベルは、点とは独立しているので残した。

| 箇所 | 変更 |
| --- | --- |
| `CustomDockPreview.swift` の `dockItem` | 点の `Circle` を削除し、`VStack` の間隔を 0 にした。`running` は VoiceOver のラベルだけに使う |
| `CustomDockPreview.swift` の `trashSection` | 位置を揃えるための透明な点を削除した |
| `DockBackdropFit.runningIndicatorRow`（9） | 削除した。下配置の背景の厚みは、アイコンサイズ + 上下の余白になる |
| `DockBackdropFit.verticalItemExtra`（9） | 削除した。左右配置の項目の長さに、点の分を足さない |
| `DockVerticalFit.itemExtraPadding`（9） | 削除した。左右配置の自動縮小の計算から点の分を外した |
| `DockDividerLine.indicatorRowHeight`（9） | 削除した。下配置の区切り線の下側の余白は 0 になる |
| `SettingsPreview.swift` | トグルと直前の `Divider` を削除した |
| `DockAppearance.runningIndicators` | プロパティを削除した |

背景の厚みは、点の分の 9 だけ減る。アイコンサイズ 16、52、128 の下配置は、45、81、157 から 36、72、148 になる。左右配置の項目は、1 個あたり 9 だけ短くなる。

## 保存データの互換性

`runningIndicators` を含む既存の `appearance.json` は、そのまま読み込める。値は無視する。保存し直すと、このキーは書かれない。`DockAppearance` は未知のキーを拒否するので、`ignoredLegacyKeys` に残して、既知として扱う。このほかの未知のキーは、従来どおり拒否する。

## 検証

2026-10-22 に、ホストで以下を実行した。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 481件すべて成功した |
| Release ビルド | 成功した |
| `build-for-testing`（Debug） | 成功した |

更新したテストは次のとおり。

- `DockBackdropFitTests`: 下配置の厚みと、左右配置の長さを、点のない値に更新した。
- `DockDividerLineTests`: 下配置の線がセルの高さ（アイコンの高さ）と一致し、下側の余白が 0 であることを確認する。
- `DockPreviewLayoutTests`: 左右配置の長さの差が、区切りの長さだけになることを確認する。
- `DockVerticalFitTests`: 測定した長さが、下限 220 を含めて計算と一致することを確認する。点の分が減って、小さいアイコンの長さが下限を下回るようになったため。
- `DockAppearanceTests`: `runningIndicators` を含む保存データを読み込めることと、書き出しにこのキーがないことを確認する（新規）。

## 撮影の手順

画面が変わるので、専用ヘッドレス macOS VM で撮影する。ホストには Dock Studio を表示しない。

### 検証用データ

ゲストで `/Users/Shared/dock-225` を作り、次を置く。

- `profiles.json`: 起動中のアプリ（Finder と、起動済みの Calculator など）、固定のアプリ、スペーサー、ゴミ箱を含む。設定は下配置、アイコンサイズ52とする。
- `appearance.json`: `{"runningIndicators": true, "background": "system"}`。旧形式のキーを含めて、読み込めることを確かめる。

`DOCKSTUDIO_DATA_DIR=/Users/Shared/dock-225` で Dock Studio を起動する。

### 操作と期待結果

1. 起動中のアプリを含む Dock を表示する。どのアイコンの下にも点がなく、背景がアイコンの下端から 10pt 程度の余白で閉じていることを確認する。
2. アイコンサイズ16、52、128で、背景の下側に不自然な空きがないことを確認する。
3. 左配置と右配置にして、項目の間隔が詰まりすぎていないことを確認する。
4. 設定画面の「外観」を開き、「起動中のアプリに点を表示」が無いことを確認する。
5. 区切り線とゴミ箱が、隣のアイコンと下端で揃っていることを確認する。
6. `appearance.json` の `runningIndicators` が残っていても、起動し、設定画面が開くことを確認する。

撮るもの: 下配置の Dock の静止画（アイコンサイズ16、52、128）、左右配置の静止画、設定画面の「外観」の静止画。保存先は `docs/media/remove-running-dot/` とする。操作の変化はないので、動画は要らない。

## 未検証

- 実機と VM の画面での見え方。このブランチでは撮影しておらず、余白の削減は計算とテストだけで確認している。
- 起動中のアプリの有無による見た目の差がなくなることの画面での確認。
- #214 など、背景の長さや厚みを変える別のブランチと結合したときの値。
