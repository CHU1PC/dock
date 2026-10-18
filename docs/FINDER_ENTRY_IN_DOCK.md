# Dock に Finder の入口を固定する

## 変更内容

Dock の設定に「Finder を先頭に固定」を追加した。有効にすると、各プロファイルの Dock 表示に Finder が先頭に入り、プロファイルに保存した Finder と重複しない。Finder のメニューには「新規 Finder ウインドウ」と「Finder を表示」を用意し、通常アプリの終了や強制終了、Dock からの取り外しのメニューを出さない。

設定は既定で無効にした。従来の自由配置と、実行中アプリの「Dock に保持」「Dock から取り外す」を保つためになる。有効にした場合は Finder を先頭に固定する。無効に戻すと、Finder は通常のプロファイル項目として追加、削除、並べ替えができる。

既存の設定ファイルに新しいキーがない場合は無効として読み込む。Finder の終了・強制終了除外は既存の `ApplicationQuitter` の規則を維持した。

## 仕様判断

- 固定表示は `DockSettings.finderEntryEnabled` で切り替える。既定を無効にして、既存の自由配置を変えない。
- 固定時は保存済みの Finder 項目を再利用し、複数あれば表示上は1項目にまとめて先頭へ移す。保存済みプロファイルは自動で書き換えない。
- 固定時のFinderメニューでは、通常アプリの終了、強制終了、保持、取り外しを表示しない。
- 「新規 Finder ウインドウ」はホームフォルダを Finder で開く。「Finder を表示」は Finder を前面にし、ウインドウをアクティブにする。

## 受け入れ条件との対応

| 条件 | 状況 | 根拠 |
| --- | --- | --- |
| Apple Dock互換の設定でFinderへの入口を保持する | 満たした | 固定設定が有効なら、全プロファイルの表示先頭にFinderを補い、既存Finderとの重複を除く。`DockStoreTests` が順序と重複を確認する |
| クリックとFinder専用メニューを通常アプリから区別する | 一部のみ | Finder用メニュー項目とFinderを前面にする処理を実装した。ホストとVMでの画面操作は未検証で、撮影担当による実測が必要になる |
| 自由配置の設定、削除、並べ替えを妨げない | 満たした | 固定は設定で無効にできる。既定と旧設定の移行値も無効にし、無効時の表示リストはプロファイルをそのまま返す。既存の保持・取り外しテストも成功した |

## 自動テスト結果

指定スクリプトで確認した。GUIアプリは起動していない。

```text
$ /private/tmp/cw/run-check.sh 57 test
	 Executed 27 tests, with 0 failures (0 unexpected) in 0.969 (0.972) seconds
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.005 (0.006) seconds
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.282 (0.284) seconds
	 Executed 259 tests, with 0 failures (0 unexpected) in 4.581 (4.615) seconds
	 Executed 259 tests, with 0 failures (0 unexpected) in 4.581 (4.616) seconds
exit=0

$ /private/tmp/cw/run-check.sh 57 release
** BUILD SUCCEEDED **
exit=0

$ /private/tmp/cw/run-check.sh 57 testbuild
** TEST BUILD SUCCEEDED **
exit=0
```

## 未検証

- 専用macOS VMでのFinderクリック、メニュー操作、設定切替と再起動後の固定状態。
- Apple標準Dockとのアイコン位置、サイズ、Finder専用メニュー、ウインドウ表示の比較。
- Finderの「新規 Finder ウインドウ」が、すでに同じフォルダのウインドウがあるときにも新しいウインドウを作るかどうか。
- macOS 15以降の動作差。

## 撮影の手順

専用ヘッドレスmacOS VMのゲスト内で撮影する。ホストのデスクトップではアプリを起動しない。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-57` を作り、下記を `profiles.json` として保存する。既存のFinder項目を末尾に置くことで、表示上で先頭に移動し、二重表示されないことも確認できる。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000057",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 52,
    "autoHide": false,
    "showRunningApps": false,
    "finderEntryEnabled": true
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000057",
      "name": "Finder demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-000000000058",
          "name": "Mail",
          "kind": "application",
          "target": "file:///System/Applications/Mail.app/",
          "bundleIdentifier": "com.apple.mail"
        },
        {
          "id": "00000000-0000-0000-0000-000000000059",
          "name": "Finder",
          "kind": "application",
          "target": "file:///System/Library/CoreServices/Finder.app/",
          "bundleIdentifier": "com.apple.finder"
        }
      ]
    }
  ]
}
```

ゲストにビルド済みの `DockStudio.app` を置き、次のコマンドで起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-57 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待する結果

1. Dock Studioを起動し、Custom Dockを表示する。FinderがDockの先頭に1つだけ表示され、Mailより前にある。
2. Finderをクリックする。Finderが前面になり、ウインドウを表示する。
3. Finderを右クリックする。専用メニューに「新規 Finder ウインドウ」と「Finder を表示」が出て、「終了」「強制終了…」「Dock から取り外す」は出ない。
4. 「新規 Finder ウインドウ」を選ぶ。Finderでホームフォルダが開く。
5. 「Finder を表示」を選ぶ。Finderとそのウインドウが前面になる。
6. Dock Studioの設定で「Finder を先頭に固定」を無効にする。プロファイル編集でFinderを削除または並べ替えできる。
7. 設定を再度有効にする。Dock上のFinderは再び先頭に1つだけ表示される。

### 標準macOS Dockとの比較で記録する項目

- Finderアイコンの画面上の位置と、アプリ側の区切り線との距離。
- Finderアイコンの見かけの大きさと、隣のアプリとの間隔。
- クリック後にFinderが前面になることと、Finderウインドウの表示。
- Finderを右クリックした標準Dockのメニュー名と並び。特に新規ウインドウ、ウインドウ表示、固定・削除に関する項目。
- Custom Dockで撮影した同じ情報と、標準Dockとの差。

### 撮影するもの

- 画像: Finderが先頭に一つだけあるCustom Dock。
- 画像: Finderの専用メニュー全体。
- 画像: Finderをクリックした後のウインドウ。
- 画像: 固定設定を切ったプロファイル編集画面で、Finderを選択して削除と並べ替えの操作が可能な状態。
- 動画: Finderのクリック、新規ウインドウ、Finder表示の操作。
- 動画: 固定設定を切り替えたときの表示と、標準macOS Dockでの比較。

## 撮影後の確認

撮影担当は、VMで実測した結果をこの文書の「未検証」と「受け入れ条件との対応」に追記する。
