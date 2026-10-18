# Dock の外へドラッグして参照を取り外す

## 仕様

Custom Dock の保持されている項目を、Dock の外までドラッグして離すと、使用中のプロファイルから参照を取り除く。保存処理は、右クリックメニューと同じ `DockStore.removeFromActiveProfile(_:)`（`removeSavedItem(_:fromProfile:)`）を使う。新しい保存処理は作っていない。

ドラッグ中の項目は、ポインタに追従する。見える背景の矩形から12pt以上外に出ると、項目が半透明になり、元の項目の位置に「取り外す」の予告が出る。この状態で離すと取り外す。

判定に使う矩形は、`DockBar` 全体ではなく、見える背景（`DockMetrics.barThickness`）の寸法にそろえた。下配置では `DockBar` の高さが `icon+65` で、見える背景は `icon+30` になる。差の約35ptは、ホバー時のラベル用の透明な領域になる。左右配置では、プレビューの幅190のなかに、`barThickness` の背景が中央にある。この幾何は `DockDragOutRemoval.visibleBounds(barSize:vertical:thickness:)` にした。

予告は、ドラッグ中の項目には追従させず、元の項目の位置に固定した。下配置では項目の26pt上（`DockBar` の内側の透明な領域で、パネルの窓に収まる）、左右配置では項目の中央に出す。ポインタに追従する項目の描画は、パネルの窓の外で切れる可能性がある（未検証の節を参照）。

次の場合は取り外さない。

- 見える背景、または背景から12pt未満の範囲で離した。
- 外に出た後、内側へ戻して離した。予告は戻ると消える。
- 項目を6pt動かす前に離した。通常のクリックとして項目を開く。

Esc によるキャンセルは、この変更の範囲外で #87 として扱う。ジェスチャが `onEnded` なしで終わった場合は、取り外さずに表示を戻すが、Esc で確実にそうなるかは確認していない。

元のアプリやファイルには触れない。「実行中のアプリを表示」で一時的に出ている項目は、保持されていないため（`store.isPinned`）ドラッグの対象にしない。保存先が読み取り専用のときも対象にしない。

標準 Dock の煙のアニメーションは、受け入れ条件にないため実装していない。

実装は `DockStudio/DockDragOutRemoval.swift` に置いた。`DockBar` には、枠の寸法の取得と、`dockItem` への修飾の追加だけを足している。ドラッグには `onDrag` ではなく `DragGesture` を使った。`onDrag` は離した場所と終了を知らせないため。

## 自動テスト

2026-10-18 に、ホストでビルドとテストだけを行った（GUI は起動していない）。`grep -E "BUILD SUCCEEDED|TEST BUILD SUCCEEDED|Executed [0-9]+ tests"` の出力は次のとおり。

```
swift test:            Executed 114 tests, with 0 failures (0 unexpected)
Release build:         ** BUILD SUCCEEDED **
Debug build-for-testing: ** TEST BUILD SUCCEEDED **
```

- `DockDragOutRemovalTests` は9件。見える背景の矩形（下配置のパネル、左右配置のプレビューとパネル、厚みが枠より大きい場合、未計測）、配置ごとの判定、右端 x = 412 と下端 y = 92 の境界、`margin:` 引数を渡す経路を縛っている。
- 取り外しの保存、元ファイルの保持、下書きの扱いは、既存の `RemoveDockItemTests` が縛っている。
- `xcodebuild test` は実行していない。

## 未検証

実際のドラッグ操作は、下の「実画面の確認」で確認した。確認できなかった項目は、そこに書いた。以下は、撮影前に挙げた確認の観点になる。

- `highPriorityGesture` のドラッグが、`Button` のクリックと競合しないか。ドラッグ後に離した位置が元の項目の上でも、項目が開かないか。
- デスクトップ用パネルの Dock で、窓の外まで追従し、離した位置が正しく判定されるか。項目の表示は窓の範囲で切れる可能性がある。
- 「使用していないときに隠す」が有効なとき、外に出た時点でパネルが畳まれ、ジェスチャが途切れる可能性がある。#88 で扱う。この変更では対応していない。
- Esc によるキャンセルは #87 で扱う。この変更では対応していない。
- 左右配置、複数プロファイル、macOS 15〜25。

## 撮影の手順

撮影の専任の担当が、この節だけで実施する。

### 起動するアプリ

この変更のブランチ `feat/drag-out-to-remove` を Release でビルドし、できた `DockStudio.app` を VM に送る。

```
xcodebuild -project DockStudio.xcodeproj -scheme DockStudio -configuration Release \
  -derivedDataPath /tmp/dockstudio-shoot-derived CODE_SIGNING_ALLOWED=NO build
# 成果物: /tmp/dockstudio-shoot-derived/Build/Products/Release/DockStudio.app
```

ゲスト内の置き場所は `~/DockStudio.app` とする。以降、`<app>` はこの場所を指す。

### 検証用データ

ゲストに `~/verify-data/profiles.json` を作る。内容は次のとおり。アプリは、ゲストの macOS 標準のアプリを指す。Downloads は、ゲストに `/Users/Shared/Downloads` のフォルダを作っておく（`mkdir -p /Users/Shared/Downloads`）。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "11111111-1111-1111-1111-111111111111",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 52, "autoHide": false,
                "revealAnimationDuration": 0.22, "launchBounce": true, "showRunningApps": true },
  "profiles": [ { "id": "11111111-1111-1111-1111-111111111111", "name": "Verify", "items": [
    { "id": "00000000-0000-0000-0000-000000000001", "name": "Finder", "kind": "application", "target": "file:///System/Library/CoreServices/Finder.app/" },
    { "id": "00000000-0000-0000-0000-000000000002", "name": "Safari", "kind": "application", "target": "file:///Applications/Safari.app/" },
    { "id": "00000000-0000-0000-0000-000000000003", "name": "Mail", "kind": "application", "target": "file:///System/Applications/Mail.app/" },
    { "id": "00000000-0000-0000-0000-000000000004", "name": "Terminal", "kind": "application", "target": "file:///System/Applications/Utilities/Terminal.app/" },
    { "id": "00000000-0000-0000-0000-000000000005", "name": "Calendar", "kind": "application", "target": "file:///System/Applications/Calendar.app/" },
    { "id": "00000000-0000-0000-0000-000000000006", "name": "Downloads", "kind": "folder", "target": "file:///Users/Shared/Downloads/" }
  ] } ]
}
```

この JSON は、`ProfilePersistence.load()` で6項目として読めることを、ホストの単体テストで確認した。Safari がゲストにない場合は、`/System/Cryptexes/App/System/Applications/Safari.app/` に置き換える。

左右配置の撮影では、`"position"` を `"left"` に変えた別のデータ（`~/verify-data-left/`）を使う。

### 起動方法

`DOCKSTUDIO_DATA_DIR=<dir> open -a` は、LaunchServices 経由でアプリに環境変数が渡らない可能性が高い。次のどちらかで起動する。

```
open -n --env DOCKSTUDIO_DATA_DIR=$HOME/verify-data <app>
# または、バイナリの直接実行
DOCKSTUDIO_DATA_DIR=$HOME/verify-data <app>/Contents/MacOS/DockStudio
```

起動直後に、`profiles.json` の6項目が Dock に出ることを確認する。モードが「Custom Dock」なので、デスクトップ用パネルの Dock が画面下に出る。スタジオの窓（プレビュー）にも同じ Dock が出る。

### 操作（プレビュー、パネルの両方で行う）

1. Mail を、Dock の上側へ、背景の上端から50pt以上離れた位置までドラッグし、離さずに止める。「取り外す」の予告と半透明の項目を撮る。パネルでは、予告が窓に切られず見えるかを記録する。
2. そのまま Dock の内側へ戻す。予告が消えることを撮る。離しても Mail が残る。
3. もう一度外までドラッグして、離す。Mail が消え、Dock が詰まる。プレビューでは「Mail を Dock から取り外しました」が出る。
4. アプリを再起動し、Mail が戻らないことと、ゲストの `/System/Applications/Mail.app` が残ることを確認する。
5. 実行中の Calculator など、保持されていない項目をドラッグして外で離す。何も起きない。
6. Terminal を、動かさずにクリックする。通常どおり起動する。
7. 外までドラッグした状態で、別のアプリをアクティブにしてから離す。取り外されるか、残るかを記録する。Esc での取り消しは未対応（#87）なので、Esc は試さなくてよい。
8. 左右配置のデータで、手順1から3をプレビューとパネルで1回ずつ行う。

手順の途中で消えた項目を戻すには、`~/verify-data/profiles.json` を元の内容に書き戻して再起動する。

### 撮るもの

保存先は `docs/media/drag-out-to-remove/` にする。プレビューは `preview-`、パネルは `panel-` を先頭に付ける。

| ファイル名 | 内容 |
| --- | --- |
| `preview-before.png`、`panel-before.png` | 操作前の6項目の Dock |
| `preview-outside.png`、`panel-outside.png` | 手順1。予告と半透明の項目 |
| `preview-returned.png`、`panel-returned.png` | 手順2。戻した後 |
| `preview-after.png`、`panel-after.png` | 手順3。取り外し後 |
| `after-relaunch.png` | 手順4 |
| `preview-drag-out-remove.mp4`、`panel-drag-out-remove.mp4` | 手順1から3を続けた動画 |
| `preview-drag-return.mp4`、`panel-drag-return.mp4` | 外に出て内側へ戻して離し、取り外されない動画 |
| `panel-deactivate.txt` | 手順7の結果の記録 |
| `left-outside.png`（プレビュー、パネル） | 手順8。左配置の予告 |
| `profiles-after.txt` | 取り外し後の `profiles.json` の項目名 |

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `14b7649` の Release ビルドを macOS 26.6.2、1600×1000の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストで `125ff26c54732745a5bcc7a583eab064ffd716a1aaffc3714b2b83ccabcccf7c` で、ゲストの値と一致した。ドラッグは、ゲスト内で CGEvent を使う小さなツールで合成した（ボタン押下、30段階の移動、保持、離す）。検証用データは上の手順の内容で、起動には `DOCKSTUDIO_DATA_DIR` を付けたバイナリの直接実行を使った。確認は、デスクトップ用パネルで行った。管理画面内のプレビューでは、ドラッグ操作を撮影していない。

下配置のパネル:

- Mail を Dock の外へドラッグすると、元の位置に「取り外す」の予告が出て、ドラッグ中の項目は半透明になった（[panel-outside.jpg](media/drag-out-to-remove/panel-outside.jpg)）。予告は、パネルの窓に切られずに見えた。
- 外で離すと、Mail が Dock から消えて Dock が詰まった。保存ファイルから Mail が消え、Finder、Safari、Terminal、Calendar、Downloads が残った（[panel-after.jpg](media/drag-out-to-remove/panel-after.jpg)、[panel-profiles-after.txt](media/drag-out-to-remove/panel-profiles-after.txt)、[動画](media/drag-out-to-remove/panel-drag-out-remove.mp4)）。
- Calendar を外までドラッグして1.5秒保持し、Dock の内側の元の項目の上へ戻して離すと、予告が消え、Calendar は残った。Calendar は起動しなかった（`pgrep -x Calendar` が空）。ドラッグ後に元の項目の上で離しても、項目は開かなかった（[panel-returned.jpg](media/drag-out-to-remove/panel-returned.jpg)、[動画](media/drag-out-to-remove/panel-drag-return.mp4)）。`highPriorityGesture` と `Button` の競合は、この確認では起きなかった。
- 動かさずに Terminal をクリックすると、通常どおり Terminal が起動した（左配置のパネルで確認）。
- 外までドラッグして保持している途中で、別のアプリ（Calculator）をアクティブにしてから離すと、項目は取り外された（[panel-deactivate.txt](media/drag-out-to-remove/panel-deactivate.txt)、[panel-deactivate-left.jpg](media/drag-out-to-remove/panel-deactivate-left.jpg)）。

左配置のパネル:

- Mail を外までドラッグすると、元の位置に「取り外す」の予告が出た（[left-outside.jpg](media/drag-out-to-remove/left-outside.jpg)）。離すと Mail が消え、保存ファイルから Mail が消えた（[left-after.jpg](media/drag-out-to-remove/left-after.jpg)、[left-profiles-after.txt](media/drag-out-to-remove/left-profiles-after.txt)、[動画](media/drag-out-to-remove/left-drag-out-remove.mp4)）。離した直後の数フレームは、予告が残り、Dock が詰まっていなかった。数秒後の画面では詰まっていた。VNC の取得の遅れか、描画の遅れかは区別できていない。

動画は撮影時刻の間隔を維持して12fps に変換し、倍速にはしていない。画面の一部に切り出している。VNC の取得に依存するため、描画性能の測定ではない。

確認できなかったこと:

- 管理画面内のプレビューでのドラッグ（手順1から3）。
- 手順4（再起動後に Mail が戻らないこと）、手順5（保持されていない項目の外へのドラッグ）。
- 「使用していないときに隠す」が有効な場合（#88）、Esc によるキャンセル（#87）。
- 左配置のパネルで、ドラッグ中の項目が窓の外へ追従するかは、画像では判別できなかった。ドラッグ中の項目は、パネルの窓の端の近くまで見えた。左配置では、管理画面内のプレビューの Mail も同時に半透明に見えるフレームがあった。原因は未確認。

撮影手順との違い: メニュー項目や画面の切り替えは使っていない。デスクトップ用パネルは、`デスクトップに Dock を表示` を AX で押して表示した。ゲストに残っていた Finder の「Documents」ウインドウが、管理画面の上に重なった。
