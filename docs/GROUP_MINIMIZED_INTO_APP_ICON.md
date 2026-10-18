# 最小化ウインドウをアプリアイコン内にまとめる

Custom Dock で、最小化したウインドウを個別に表示するか、アプリのアイコンにまとめるかを選べる。まとめた場合は、アプリアイコンのメニューから復元するウインドウを選ぶ。

## 仕様

- macOS 15 以降を対象にする。
- 「設定」「Dock」の「最小化したウインドウをアプリアイコンにまとめる」で表示方法を切り替える。
- オフの場合は、最小化したウインドウをウインドウごとに表示する。
- オンの場合は、同じアプリの最小化ウインドウをアプリアイコン1つにまとめ、メニューにウインドウタイトルを並べる。選んだウインドウだけを復元する。
- アプリの識別には bundle identifier を使う。同じ bundle identifier のウインドウは、同じアプリのグループとして扱う。
- 選択したウインドウの復元には、issue #23 と同じ Accessibility provider とウインドウ ID を使う。
- 表示方法は `DockSettings` に保存し、再起動後も維持する。既存プロファイルに設定がない場合はオフとして読み込む。
- Apple Dock のシステム設定は読み書きしない。Dock Studio の設定は Custom Dock の表示だけに適用する。

## 自動テスト結果

ホストで `/private/tmp/cw/run-check.sh 24 test`、`/private/tmp/cw/run-check.sh 24 release`、`/private/tmp/cw/run-check.sh 24 testbuild` を実行した。

```text
Executed 260 tests, with 0 failures (0 unexpected)
** BUILD SUCCEEDED **
** TEST BUILD SUCCEEDED **
exit=0
```

## 未検証

- 専用 macOS VM での実画面、実際の最小化ウインドウのグループ化と復元は未検証。
- Apple Dock の「ウインドウをアプリケーションアイコンにしまう」設定をオンまたはオフにした場合の実画面比較は未検証。
- macOS 15 から 26 までの OS ごとの差異は未検証。

## 撮影の手順

専用ヘッドレス macOS VM または検証用 Mac のゲストで行う。ホストではアプリを起動せず、画面も撮影しない。Custom Dock と Apple Dock の両方を表示するため、Dock Studio のモードを「両方」にする。デスクトップパネルの撮影では、Dock のプレビューがパネルと重ならないよう「設定」タブを表示する。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-24/profiles.json` を作成し、次の内容を保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "both",
    "position": "bottom",
    "iconSize": 52,
    "autoHide": false,
    "showRunningApps": false,
    "minimizeWindowsIntoAppIcon": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Grouped minimized windows",
      "items": [
        {
          "id": "00000000-0000-0000-0000-000000000024",
          "name": "TextEdit",
          "kind": "application",
          "target": "file:///System/Applications/TextEdit.app/"
        },
        {
          "id": "00000000-0000-0000-0000-000000000025",
          "name": "Calculator",
          "kind": "application",
          "target": "file:///System/Applications/Calculator.app/"
        }
      ]
    }
  ]
}
```

Release 成果物をゲストに置き、次のように起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-24 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作

1. Dock Studio の「設定」「Dock」で、まとめる設定がオフであることを確認する。
2. TextEdit でタイトルの異なる書類を2つ開き、Calculator も開く。それぞれのウインドウを最小化する。
3. Custom Dock に TextEdit のウインドウが2項目、Calculator が1項目、個別に表示されることを確認する。
4. 設定をオンにする。Custom Dock で TextEdit と Calculator がアプリアイコン1つずつにまとまることを確認する。
5. TextEdit のアイコンのメニューを開き、2つの書類タイトルが表示されることを確認する。片方を選び、選んだウインドウだけが復元されることを確認する。
6. 残った TextEdit のメニューからもう一方を復元する。Calculator のメニューから Calculator のウインドウも復元する。
7. Dock Studio を終了して再起動し、まとめる設定がオンのままであることを確認する。
8. Apple Dock のシステム設定「ウインドウをアプリケーションアイコンにしまう」をオフとオンの両方で確認する。各状態で Dock Studio の設定を切り替え、Custom Dock の表示が Dock Studio の設定に従い、Apple Dock の表示と設定は変更されないことを記録する。

### 標準 Dock との比較で記録する項目

- ゲストの macOS バージョン、画面解像度、Dock の位置とアイコンサイズを記録する。
- Apple Dock の「ウインドウをアプリケーションアイコンにしまう」の状態を記録する。
- 同じアプリで最小化した2ウインドウと、別アプリで最小化した1ウインドウが、それぞれ何個の項目として表示されるかを両方の Dock で記録する。
- 各 Dock でウインドウタイトルを確認する方法と、選択した項目だけが復元されるかを記録する。
- 最小化から表示反映までの時間と、メニューから選択して復元するまでの時間を記録する。
- Dock Studio の設定変更後、再起動後、および Apple Dock の設定変更後の表示を記録する。
- Apple Dock と Custom Dock の位置関係、重なり、操作の妨げがないかを記録する。

### 撮るもの

- 画像: 個別表示が有効なとき、同じアプリの複数ウインドウが別項目になった Custom Dock。
- 画像: グループ表示が有効なとき、TextEdit と Calculator がそれぞれ1アイコンになった Custom Dock。
- 画像: TextEdit のメニューを開き、2つのウインドウタイトルが見える状態。
- 画像: Apple Dock と Custom Dock の位置関係、および Apple Dock のシステム設定。
- 動画: 個別表示からグループ表示へ切り替え、アプリアイコンのメニューから片方ずつウインドウを復元し、再起動後も設定が維持される様子。
