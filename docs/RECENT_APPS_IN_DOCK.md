# 最近使った未固定アプリを Dock に表示する

## 変更内容

設定の「最近使ったアプリを表示」を有効にすると、最近使った未固定アプリを最大3件 Dock に表示する。固定済みのアプリと、実行中アプリの表示が有効なときにすでに表示されているアプリは重複しない。

アプリの起動と切替を監視し、最後に使ったアプリが先頭になるように履歴を更新する。表示順を保つため、最大50件のアプリ名と参照先をアプリデータフォルダ内の `recent-apps.json` に保存する。履歴は端末内の Dock Studio のデータに限り、プロファイルの書き出しや読み込みには含めない。

## 仕様の判断

- 表示設定は `profiles.json` の `showRecentApps` に保存する。既存設定にこの値がない場合は無効として読み込む。
- 有効な間は、通常のアプリの起動と切替を記録する。Dock Studio 自身は記録しない。
- 履歴は最大50件を保持し、そのうち固定済みと表示対象の実行中アプリを除いた先頭3件を表示する。
- 表示を無効にすると、その場で履歴を空にする。無効の間は新しいアプリを記録しない。
- 履歴には項目 ID、アプリ名、アプリの URL、Bundle ID を保存する。書類の内容、アプリ内の操作、起動時刻は保存しない。
- 履歴ファイルは `profiles.json` と同じデータフォルダの `recent-apps.json` に置く。`DOCKSTUDIO_DATA_DIR` を指定した場合はそのディレクトリに保存する。

## 自動テスト

ホストでは指定の検証スクリプトで単体テスト、Release ビルド、build-for-testing を実行した。GUI は起動していない。

| 項目 | 結果 |
| --- | --- |
| `run-check.sh 13 test` | 261件実行、失敗0件 |
| `run-check.sh 13 release` | 成功 |
| `run-check.sh 13 testbuild` | 成功 |

## 未検証

- 専用 VM での実画面とアプリ切替時の更新。
- 標準 macOS Dock との実機比較。
- macOS 15 以降での OS ごとの差。

## 撮影の手順

撮影担当は、専用ヘッドレス macOS VM のゲストだけで確認する。ホストでは Dock Studio を起動しない。アプリを起動するときは、`DOCKSTUDIO_DATA_DIR` に下記の `profiles.json` があるディレクトリを指定する。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-recent-apps` を作り、次の内容を `profiles.json` として保存する。

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
    "showRunningApps": true,
    "showRecentApps": true
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Recent apps demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-0000000000a1",
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

アプリを起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-recent-apps /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待する結果

1. Finder が固定項目として一度だけ表示されることを確認する。
2. Calculator、TextEdit、Safari を順に起動して切り替える。実行中アプリのアイコンには実行中の印が出て、最近使った項目には同じアプリが重複しない。
3. Safari、TextEdit、Calculator の順に終了する。終了したアプリが最近使った順で最大3件表示される。最新の Safari が先頭になる。
4. Calculator を再び使う。Calculator が最近使った順の先頭へ移動し、同じ項目が二重にならない。
5. Dock Studio を終了して再起動する。履歴順が保たれていることを確認する。
6. 設定で「最近使ったアプリを表示」をオフにする。最近の項目が消え、その後アプリを使っても記録されないことを確認する。
7. 設定を再びオンにして、アプリを使う。新しい利用分だけが表示されることを確認する。
8. 比較用に、ゲストの「システム設定」>「デスクトップと Dock」で「最近使ったアプリケーションを Dock に表示」をオンにし、標準 Dock を確認する。

### 標準 Dock との比較で測る項目

- 標準 Dock と Dock Studio の最近のアプリ数、および3件を超えた場合に表示される件数。
- 最近使ったアプリの並び順と、アプリを再び使った直後の移動先。
- 固定済みアプリと最近のアプリの境界、および固定済みアプリが重複しないこと。
- 実行中の印と、終了後に最近の一覧へ移るタイミング。
- アプリを Dock に固定または最近使用後に再利用した場合の重複有無。
- Dock Studio の再起動後に履歴が残るかどうか。
- 標準 Dock の最近使ったアプリ表示をオフにしたときの表示と、その後にオンへ戻したときの履歴。

### 撮影するもの

- 画像: 起動中アプリと終了済みの最近使ったアプリが並び、固定済み Finder が一度だけ表示された状態。
- 画像: アプリの再利用後、最近使った順が更新された状態。
- 画像: 設定で最近使ったアプリ表示を無効にした状態。
- 画像: 標準 Dock の最近使ったアプリと Dock Studio の表示を同じゲスト画面で比較できる状態。
- 動画: 3アプリの起動、切替、終了、再利用によるアイコンの追加と並べ替え。
- 動画: 設定のオンとオフ、履歴が消えること、再度オンにした後の新しい履歴。

管理ウィンドウを撮るときは、Dock プレビューが重ならない「設定」タブを使う。
