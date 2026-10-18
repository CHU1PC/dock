# Dock メニューから最近使った書類を開く

GitHub issue #128 の実装になる。

## 仕様

アプリ項目のコンテキストメニューに、標準 Dock の「Show Recents」メニューから取得した最近使った書類のサブメニューを追加した。Accessibility が許可され、対象アプリの Dock メニューと書類項目の AX URL を取得できた場合だけ表示する。

- 対象アプリの Dock 項目は、アプリの URL と標準 Dock の AX URL を照合する。名前が一致するだけの別アプリを対象にしない。
- 「Show Recents」を開き、その下位項目のタイトルと file URL を読み取る。書類メニュー項目自身の AX URL を ID に使う。
- 書類を選ぶと、Dock メニューを開き直し、同じ URL を持つ下位項目があることを確かめてから AXPress を送る。表示名から開くパスを組み立てない。
- Accessibility が許可されていない場合、対象アプリが Dock にない場合、またはメニューと URL が読めない場合はサブメニューを出さない。既存の固定コンテキストメニューはそのまま使える。
- 書類履歴を保存、外部送信、ログ出力する処理は追加していない。書類名と URL は、メニュー表示中のメモリ内でだけ扱う。
- 対象はアプリ項目に限る。ファイル、フォルダなどでは最近使った書類を取得しない。

実装は `DockStudio/Services/RecentDocumentAccess.swift` にある。AX の取得処理は `RecentDocumentProviding` で差し替えられる。

## 自動テスト

2026-10-18 にホストで単体テストとビルドを実行した。アプリは起動していない。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 338件すべて成功した（追加分 `RecentDocumentAccessTests` は2件） |
| Release ビルド | `BUILD SUCCEEDED` |
| `build-for-testing` | `TEST BUILD SUCCEEDED` |

追加した単体テストでは、アプリの URL と選択された書類 ID が provider に渡ること、およびアプリ以外の項目では provider を呼ばないことを確認した。

## 未検証

- macOS の Dock AX ツリーで、対象アプリ項目の URL、「Show Recents」サブメニュー、各書類 URL が実際に取得できるか。
- Accessibility 許可の有無による実画面の表示差と、取得した書類を開いた結果。
- 複数の Dock 項目に同じ表示名がある場合、異なる macOS バージョン、または AX URL を公開しないアプリでの動作。
- 履歴が端末内の表示だけに使われることの実行時確認。コード上はネットワーク、保存、ログの経路を追加していない。
- 標準 Dock との表示比較。

今回、画面は撮影していない。上記の実画面と OS 連携は未確認になる。

## 撮影の手順

専用ヘッドレス macOS VM のゲストで行う。ホストで Dock Studio を起動しない。実画面はこの作業では確認していない。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-128` を作り、実際の TextEdit のアプリ URL を使って次の `profiles.json` を置く。macOS のバージョンで TextEdit の配置が異なる場合は、ゲスト上の実際のパスに合わせる。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": false,
    "revealAnimationDuration": 0.22,
    "launchBounce": false,
    "showRunningApps": false,
    "showRecentApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Recent documents demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-0000000000a1",
          "name": "TextEdit",
          "kind": "application",
          "target": "file:///System/Applications/TextEdit.app/",
          "bundleIdentifier": "com.apple.TextEdit"
        }
      ]
    }
  ]
}
```

起動コマンドは次になる。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-128 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待する結果

1. ゲストで Accessibility 設定から Dock Studio を許可する。許可しない場合も確認し、書類のサブメニューが出ず、既存の固定メニューを使えることを記録する。
2. TextEdit で複数のテキスト書類を作成して開き、最近使った書類を登録する。TextEdit が Dock の最近使った項目を表示する設定になっていることを確認する。
3. Dock Studio を上記の `DOCKSTUDIO_DATA_DIR` で起動し、TextEdit の Custom Dock アイコンを右クリックする。
4. 「最近使った書類」サブメニューに TextEdit の履歴が表示されることを確認する。
5. そのうち1つを選び、TextEdit が選択したファイルを開くことを確認する。表示名だけでなく、実際に開いたファイルがメニュー項目の対象と一致することを確認する。
6. TextEdit の履歴が空の場合、対象アプリが Dock にない場合、Accessibility が未許可の場合もそれぞれ確認し、最近使った書類のサブメニューが表示されない一方で固定メニューが使えることを確認する。
7. 標準 Dock でも同じ TextEdit の Dock メニューを開き、項目と Custom Dock の表示を比較する。

撮影する画像は、Accessibility 許可時のサブメニュー、書類選択後に開いたファイル、許可なしまたは取得失敗時の固定メニューにする。操作の動画は、最近使った書類の選択から対象ファイルが開くまでを含める。
