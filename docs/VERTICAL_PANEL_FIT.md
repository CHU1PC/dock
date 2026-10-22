# 左右配置のパネルのアイコンサイズ自動縮小

## 変更内容

左右配置のデスクトップ用パネルで、アイコンサイズ 128 にすると、項目がパネルの枠からはみ出す問題を直した（issue #210）。#208 でプレビューに適用した `DockVerticalFit` を、パネルにも使う。

原因は2つあった。

- `CustomDockWindowController.swift` の `updatePanel` が、パネルの高さを縮小前のアイコンサイズで計算していた。高さは画面の表示領域（上下10ptの余白を除く）で頭打ちになるので、内容がそれより長くなる。
- `PanelDockContent` が `DockBar` を `fitsAnyBackground` なしで作っていた。`DockMetrics.effectiveIconSize` は、背景が Apple Dock 風のときにしか縮めないため、ほかの背景では 128 のまま描画され、ゴミ箱が枠の下に出た。

変更は次のとおり。

- `DockPanelSizing.verticalMaximumLength(visibleFrame:)` と `verticalDockAvailableLength(...)` を追加した。画面の表示領域から Dock に使える高さを、純粋な関数として求める。
- `updatePanel` が、左右配置のときだけ `DockMetrics.effectiveIconSize(..., forceFit: true)` で縮小後のサイズを求め、`DockMetrics.length(for:iconSize:)` に渡す。
- `PanelDockContent` が、左右配置のときに `DockBar(fitsAnyBackground: true)` を渡す。パネルの高さから求めた `availableLength` で、描画側のサイズもプレビューと同じ式で決まる。

下配置の計算は変えていない。収まる場合は `DockVerticalFit.iconSize` が最大サイズをそのまま返すため、アイコンサイズは変わらない。プレビューのコードは変えていない。

## 自動テストの結果

`DockStudioTests/DockVerticalFitTests.swift` に4件を追加した。

| テスト | 内容 |
| --- | --- |
| `testPanelAvailableLengthSubtractsScreenInsetPaddingAndNotice` | 表示領域の高さ875から、画面の余白20、パネルの余白16、通知の70を引いた高さ（855、839、769、下限0） |
| `testPanelKeepsIconSizeWhenContentFits` | 項目2件、64、高さ900では縮めない |
| `testPanelShrinksLargestIconWithFiveItemsAndTrashToFit` | 項目5件とゴミ箱、128、高さ900では縮み、縮小後の長さが利用可能な高さ以内になる |
| `testPanelUsesMinimumIconSizeWhenNothingFits` | 40件、128、高さ600では最小の16になる |

```
$ nice -n 15 swift test --scratch-path /tmp/dockstudio-210-scratch
Executed 456 tests, with 0 failures (0 unexpected) in 5.136 (5.190) seconds
$ xcodebuild ... -configuration Release build
** BUILD SUCCEEDED **
$ xcodebuild ... -configuration Debug build-for-testing
** TEST BUILD SUCCEEDED **
```

Release 構成では `@testable import` が解決できないため、`build-for-testing` は Debug 構成で行った。

## 撮影の手順

見た目が変わるため、撮影が必要になる。

### 検証用データ

ゲストに次の内容で `profiles.json` を用意し、`DOCKSTUDIO_DATA_DIR` にそのファイルを含むディレクトリを指定して起動する。`position` を `left` と `right` に切り替えて、それぞれ撮る。`items` を 2件、5件、12件にした3種類を用意する。下の例は 5件（アプリ4件、フォルダ1件）で、ゴミ箱は自動で末尾に付く。2件版は先頭2件だけ、12件版は項目を足して作る。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "left", "iconSize": 128, "autoHide": false, "showRunningApps": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Vertical panel fit",
      "items": [
        { "id": "00000000-0000-0000-0000-0000000000a1", "name": "Calculator", "kind": "application", "target": "file:///System/Applications/Calculator.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a2", "name": "Calendar", "kind": "application", "target": "file:///System/Applications/Calendar.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a3", "name": "Notes", "kind": "application", "target": "file:///System/Applications/Notes.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a4", "name": "Safari", "kind": "application", "target": "file:///Applications/Safari.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a5", "name": "Applications", "kind": "folder", "target": "file:///Applications/" }
      ]
    }
  ]
}
```

起動例:

```
DOCKSTUDIO_DATA_DIR=/Users/Shared/vertical-panel-fit /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待する結果

1. 左配置、アイコンサイズ128、5件で起動する。ゴミ箱を含む全項目がパネルの枠内に収まり、枠の下端が画面の表示領域内に収まる。アイコンは128より小さく表示される。
2. 同じ設定で2件にする。アイコンは128のまま、縮まない。
3. 12件にする。アイコンはさらに小さくなり、全項目が枠内に収まる。
4. 右配置にして、1から3を繰り返す。
5. 下配置、アイコンサイズ128にする。従来と見え方が変わらない。

### 撮るもの

| 種類 | 内容 |
| --- | --- |
| 画像 | 左配置、128、5件。ゴミ箱まで枠内に収まる |
| 画像 | 左配置、128、2件。アイコンが縮んでいない |
| 画像 | 左配置、128、12件 |
| 画像 | 右配置、128、5件と12件 |
| 画像 | 下配置、128（変更前後で同じ見え方） |
| 比較 | 変更前の main（063c093）の左配置、128、5件。ゴミ箱が枠の下に出る |

## 未検証

- 実際のウィンドウとしての表示。ホストでは GUI を表示していないため、画面での確認は撮影担当に任せる。
- アクセシビリティ通知が出ている状態、拡大表示（magnification）が有効な状態、最小化ウィンドウがある状態の実表示。計算は単体テストで確認した。
- 複数ディスプレイ、メニューバーが自動で隠れる設定、Retina 以外の画面。
