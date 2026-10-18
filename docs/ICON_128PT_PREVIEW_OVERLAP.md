# 128 pt の画面内プレビューで周囲の部品に重なる問題

## 変更内容

Custom Dock の管理画面内プレビューが、DockBar の内容サイズに引っ張られて画面枠からはみ出す問題を修正した。プレビューの表示枠を管理画面の大きさに合わせて制限し、枠の外をクリップする。下配置では下部の操作ボタン用の余白を確保し、左右配置では上部と下部に操作部品用の余白を確保する。表示枠より Dock の内容が大きい場合は、Dock 内をスクロールして操作できる。

配置別の表示枠サイズは `DockPreviewLayout.frameSize` で計算する。横配置では幅を項目数に応じた Dock の長さと利用可能幅の小さい方にし、高さを Dock の厚みと利用可能高さの小さい方にする。左右配置では幅を 190 pt と利用可能幅の小さい方にし、高さを Dock の長さと利用可能高さの小さい方にする。利用可能幅は画面幅から 50 pt、利用可能高さは画面高から 188 pt を引き、負の値は 0 に丸める。

## 仕様判断

- Dock の内容サイズの計算や実ウィンドウのレイアウトは変更しない。管理画面内プレビューの表示枠だけを制限する。
- 128 pt と拡大率最大の組み合わせでは、Dock の内容が表示枠を超える。超えた部分を周囲へ描画せず、表示枠内をスクロールして見られるようにする。
- 小さい画面では表示枠の幅と高さを 0 以上の利用可能寸法に制限する。
- プレビューの既存のボタン配置を避ける余白として、下配置には下部 90 pt、左右配置には上下各 70 pt を確保する。

## 自動テスト

`DockPreviewLayoutTests` で次を確認する。

- 下配置で Dock の長さが画面幅を超えるとき、利用可能幅に枠を収める。
- 左右配置で Dock の長さが画面高を超えるとき、利用可能高さに枠を収める。
- 小さい画面では幅と高さを 0 に丸める。

2026-10-18 にホストで指定の `run-check.sh` を実行した。アプリの GUI は起動していない。

| 項目 | 結果 |
| --- | --- |
| `run-check.sh 75 test` | 259 件成功、0 件失敗 |
| `run-check.sh 75 release` | BUILD SUCCEEDED |
| `run-check.sh 75 testbuild` | TEST BUILD SUCCEEDED |

## 未検証

- 専用 macOS VM での実画面、操作性、スクロール動作。撮影担当が下記手順で確認する。
- macOS 15 以降の各バージョンにおける描画差。
- 標準 macOS Dock との実寸比較。撮影時に同じ解像度で比較値を記録する。

## 撮影の手順

撮影は専用のヘッドレス macOS VM のゲストで行う。ホストの画面や入力機器は使わない。ビルド済みの Dock Studio をゲストに配置し、アプリを起動する前に次の `profiles.json` を `DOCKSTUDIO_DATA_DIR` のディレクトリに置く。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 128,
    "autoHide": false,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Preview overlap check",
      "items": [
        { "id": "00000000-0000-0000-0000-000000000011", "name": "Finder", "kind": "application", "target": "file:///System/Library/CoreServices/Finder.app/" },
        { "id": "00000000-0000-0000-0000-000000000012", "name": "Safari", "kind": "application", "target": "file:///Applications/Safari.app/" },
        { "id": "00000000-0000-0000-0000-000000000013", "name": "Mail", "kind": "application", "target": "file:///System/Applications/Mail.app/" },
        { "id": "00000000-0000-0000-0000-000000000014", "name": "Calendar", "kind": "application", "target": "file:///System/Applications/Calendar.app/" },
        { "id": "00000000-0000-0000-0000-000000000015", "name": "Notes", "kind": "application", "target": "file:///System/Applications/Notes.app/" },
        { "id": "00000000-0000-0000-0000-000000000016", "name": "Reminders", "kind": "application", "target": "file:///System/Applications/Reminders.app/" },
        { "id": "00000000-0000-0000-0000-000000000017", "name": "Maps", "kind": "application", "target": "file:///System/Applications/Maps.app/" },
        { "id": "00000000-0000-0000-0000-000000000018", "name": "Photos", "kind": "application", "target": "file:///System/Applications/Photos.app/" },
        { "id": "00000000-0000-0000-0000-000000000019", "name": "Music", "kind": "application", "target": "file:///System/Applications/Music.app/" },
        { "id": "00000000-0000-0000-0000-000000000020", "name": "TV", "kind": "application", "target": "file:///System/Applications/TV.app/" },
        { "id": "00000000-0000-0000-0000-000000000021", "name": "Podcasts", "kind": "application", "target": "file:///System/Applications/Podcasts.app/" },
        { "id": "00000000-0000-0000-0000-000000000022", "name": "News", "kind": "application", "target": "file:///System/Applications/News.app/" },
        { "id": "00000000-0000-0000-0000-000000000023", "name": "System Settings", "kind": "application", "target": "file:///System/Applications/System%20Settings.app/" }
      ]
    }
  ]
}
```

ゲストのデータディレクトリを `/Users/Shared/dockstudio-75` とした場合、次のように起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-75 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待結果

1. 解像度 1600×1000 のゲストでアプリを起動し、管理画面の Custom Dock を開く。
2. 設定でアイコンサイズを 128 pt、拡大率を最大にする。多数の項目を表示した状態で、下配置のプレビューを確認する。Dock は「デスクトップに Dock を表示」ボタンや右上の切替ボタンに重ならず、内容が枠を超える場合は枠内をスクロールできる。
3. Dock の配置を左にし、プレビューがウィンドウ内容と右上の切替ボタンに重ならず、縦方向にスクロールできることを確認する。
4. 右配置でも同じ確認を行う。
5. 管理ウィンドウを小さくして、プレビューが管理画面の部品に重ならず、表示枠内をスクロールできるか確認する。
6. 比較用に、同じ解像度のゲストで標準 macOS Dock を表示する。標準 Dock のサイズと拡大を最大にして、下配置と左右配置のそれぞれで大きさと周辺へのはみ出しを確認する。

### 撮影するものと比較時に記録する値

- 画像: 128 pt、拡大率最大、多数項目の下配置プレビュー。ボタンと切替部品が同じ画面に入り、重なっていないことが分かるもの。
- 画像: 左配置および右配置のプレビュー。ウィンドウ内容と右上の切替ボタンとの間隔が分かるもの。
- 動画: 各配置の Dock を端から端までスクロールし、項目と操作ボタンを押せることが分かるもの。
- 画像: 小さい管理ウィンドウでのプレビューとスクロールバーまたはスクロール位置。
- 画像: 標準 macOS Dock を同じ解像度、最大サイズ、最大拡大率で表示した比較用画面。
- 記録: ゲストの macOS バージョンと解像度、アイコンサイズ、拡大率、Dock 配置、項目数。
- 記録: 標準 Dock とプレビューそれぞれの Dock 外枠の幅と高さ、通常時と最大拡大時のアイコンの幅と高さ、Dock と画面端の余白、Dock と隣接 UI 部品との最小距離。

標準 macOS Dock と Dock Studio は項目や描画仕様が異なるため、比較値は同一条件で測った寸法として記録し、同等表示であるとは判断しない。

## VM 検証

2026-10-18 に専用 VM（macOS 26.6.2、解像度 1600×1000）で、コミット 14ee79d の Release ビルドを確認した。ホストとゲストの実行ファイルの SHA-256 は一致した（eea6ad46a9664f0049882e3b4378c1e614c2f3c5e4c5bd34a7823048c5d8f287）。設定は 128 pt、拡大率 2.0、13 項目、既定の管理ウィンドウ（1080×850）。

| 確認 | 結果 |
| --- | --- |
| 下配置で Dock が「デスクトップに Dock を表示」ボタンや右上の切替ボタンに重ならない | 満たした |
| 拡大したアイコンが管理画面の部品に重ならない | 満たした（拡大した Mail は Dock の枠の上へ約 90 pt はみ出すが、空き領域に収まる） |
| 左配置と右配置で、ウィンドウ内容と切替ボタンに重ならない | 満たした |
| 枠を超える内容がスクロールできる | 一部のみ（AX の座標で、項目が枠の外の x=2437 まで並ぶことと、VNC のスクロールで項目が左へ動くことは確認した。端まで動かした画像は、VNC の取得が遅れて得られなかった） |
| 小さい管理ウィンドウ、標準 Dock との比較 | 未確認 |

下配置の初期表示では、Dock の左端から Finder までに約 210 pt の空きがある（内容が枠より広いとき、中央を基準に配置されている疑い）。

media: [docs/media/icon-128pt-preview-overlap/](media/icon-128pt-preview-overlap/)
