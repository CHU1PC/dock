# Dock のアプリ、最近使ったアプリ、書類を区画に分ける

## 変更内容

Custom Dock の「項目の並び方」で「標準の区画」を選ぶと、アプリ、最近使ったアプリ、書類を分けて表示する。下配置では左から右へ、左右配置では上から下へ、アプリ、最近使ったアプリ、書類の順になる。区画の間に境界線を表示する。

標準の区画では、アプリとウィジェット類、最近使ったアプリ、フォルダ・ファイル・リンクの順に表示する。各区画内では既存の順序を保つ。アプリを Dock にドロップするとアプリ区画の末尾に入り、フォルダやファイルをドロップすると書類区画の末尾に入る。

## 仕様の判断

- 配置設定 `arrangement` に `free` と `standardSections` を追加した。保存済み設定にこのキーがない場合は `free` として読み込み、既存プロファイルの表示順を変えない。
- 「標準の区画」は明示的に選んだ場合だけ適用する。プロファイルに保存された項目配列は並べ替えず、表示時の投影だけを区画別にまとめる。
- 自由配置では、従来どおり保存済み項目、実行中アプリ、最近使ったアプリの順を保ち、境界線を表示しない。
- 縦配置は Dock の先頭を上端として扱い、アプリを上、書類を下に置く。
- ドロップ先は項目の種類で決める。ドロップ位置に関係なく、アプリはアプリ区画、フォルダ・ファイルは書類区画へ追加する。

## 自動テスト

ホストで指定スクリプトを実行した。GUI は起動していない。

| 項目 | 結果 |
| --- | --- |
| `/private/tmp/cw/run-check.sh 12 test` | `Executed 265 tests, with 0 failures (0 unexpected)`、`exit=0` |
| `/private/tmp/cw/run-check.sh 12 release` | `** BUILD SUCCEEDED **`、`exit=0` |
| `/private/tmp/cw/run-check.sh 12 testbuild` | `** TEST BUILD SUCCEEDED **`、`exit=0` |

追加テストは、標準区画の順序と境界位置、自由配置の順序維持、アプリと書類のドロップ先を確認する。

## 未検証

- 専用 VM での区画、境界線、ドラッグ操作の実画面は未確認であり、撮影担当による確認が必要になる。
- macOS 15 以降の各バージョンでの表示差は未確認になる。
- 標準 Dock と Dock Studio の見た目や配置の一致は確認していない。比較時は撮影手順に記載した項目を測る。

## 撮影の手順

専用ヘッドレス macOS VM のゲストで実行し、ホストでは Dock Studio を起動しない。以下の `profiles.json` を置いたディレクトリを `DOCKSTUDIO_DATA_DIR` に指定して起動する。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-sections` を作り、次の内容を `profiles.json` として保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "custom",
    "arrangement": "standardSections",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": false,
    "revealAnimationDuration": 0.22,
    "launchBounce": false,
    "showRunningApps": true,
    "showRecentApps": true
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Dock sections demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-0000000000a1",
          "name": "Finder",
          "kind": "application",
          "target": "file:///System/Library/CoreServices/Finder.app/",
          "bundleIdentifier": "com.apple.finder"
        },
        {
          "id": "00000000-0000-0000-0000-0000000000a2",
          "name": "Downloads",
          "kind": "folder",
          "target": "dockstudio://system-location/downloads"
        }
      ]
    }
  ]
}
```

Dock Studio をゲストで次のように起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-sections /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待する結果

1. 初期状態で Finder と Downloads が区画線で分かれていることを確認する。
2. Calculator、TextEdit、Safari を順に起動し、切替後にアプリと最近使ったアプリが中央の区画に現れることを確認する。固定済み Finder や起動中アプリが重複しないことも確認する。
3. Calculator などの `.app` を Dock にドロップし、アプリ区画に追加されることを確認する。
4. ファイルとフォルダを Dock にドロップし、書類区画に追加されることを確認する。
5. 設定で配置を「自由配置」に切り替える。境界線がなくなり、項目が保存済み順に表示されることを確認する。
6. 「標準の区画」に戻し、下配置では左から右、左または右配置では上から下にアプリ、最近使ったアプリ、書類が並ぶことを確認する。
7. 保存済みプロファイルのファイルを比較し、配置の切替だけでは項目配列が並べ替えられていないことを確認する。
8. 比較対象として、システム設定の「デスクトップと Dock」で標準 Dock を表示し、同じアプリと書類を固定して並べる。

### 標準 Dock と比較して測る項目

- アプリ、最近使ったアプリ、書類の区画の順序と境界の位置。
- 最近使ったアプリの表示数、アプリを再利用した直後の順序、固定済みアプリとの重複。
- `.app` とファイル・フォルダをドロップした位置、および種類ごとの追加先。
- Dock を左右に置いた場合の縦方向の順序と区画境界。
- 標準 Dock の「最近使ったアプリケーションを Dock に表示」を切り替えたときの区画と境界の変化。
- Dock Studio の配置を切り替える前後で、保存されたプロファイルの項目順が変わらないこと。

### 撮るもの

- 画像: 最近使ったアプリが表示され、3つの区画と境界線が見える下配置の Dock。
- 画像: ファイルやフォルダを追加した後の書類区画。
- 画像: 自由配置にした Dock と、標準区画に戻した Dock。
- 画像: 標準 macOS Dock と Dock Studio を同じゲスト上で比較できる状態。
- 画像: 左または右配置で、上から下への区画順が分かる Dock。
- 動画: アプリの切替、アプリと書類のドロップ、配置モード変更による境界と並びの変化。

管理画面を撮るときは、プレビュー Dock と重ならない「設定」タブを使う。
