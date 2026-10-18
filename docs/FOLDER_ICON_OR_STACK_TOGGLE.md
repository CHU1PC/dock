# フォルダ項目のアイコン表示切替

GitHub issue #36 の変更になる。

## 変更内容

Custom Dock のフォルダ項目のメニューから、通常のフォルダアイコンと Stack 形式の内容プレビューを切り替える。選んだ表示形式は、active profile 内のそのフォルダに保存する。既存のプロファイルでは保存値がないため、通常のフォルダ表示を使う。

Stack 表示は、フォルダを読み込んだ順に先頭3項目のアイコンをフォルダアイコンへ重ねる。フォルダの再表示時とポインタがアイコンへ入った時に内容を読み直すため、追加、削除、並び順の変化は次の読み込み後に反映する。表示順は `FolderContentsReader` が返す順序を使い、並べ替え機能は追加しない。

空のフォルダと読み込み中は通常のフォルダアイコンを表示する。読み込みに失敗したときは、フォルダアイコンに警告マークを重ねる。白黒とガラス調は、既存のアイコン表示設定を内容アイコンにも適用する。

## 仕様判断

- 表示形式は `DockItem.folderDisplayStyle` に保存する。省略された値は `.folder` として扱い、既存の `profiles.json` をそのまま読み込める。
- メニューには現在と異なる表示形式だけを出す。Stack 表示中には「フォルダとして表示」、通常表示中には「Stack として表示」を出す。
- Stack アイコンのプレビューには先頭3項目を使う。Dock 内のフォルダ一覧と同じ `FolderContentsReader` を使い、別の並べ替え規則は設けない。
- 再読み込みはアイコンの表示時とホバー時に行う。表示中の継続監視は行わない。
- アイコンの大きさ、位置、クリック動作、フォルダ一覧の動作は既存設定を使う。

## 受け入れ条件との対応

| 条件 | 状況 |
| --- | --- |
| Folder と Stack を選択し、フォルダごとに保存する | 満たした。コンテキストメニューから切り替え、DockItem に保存する。単体テストで再起動後の保持と、別フォルダへの非波及を確認した |
| 内容と並び順の変更を Stack アイコンへ反映する | 満たした。表示時とホバー時に現在の内容を再読込し、読み込み元の順序で先頭3項目を描く。単体テストで内容と順序の更新を確認した |
| 空、読込失敗、白黒、ガラス調の各状態を確認する | 一部のみ。空と読込失敗の状態分岐を単体テストで確認した。白黒とガラス調は既存の描画設定へ接続した。実画面の確認は専用VMで行う |

## 自動テスト結果

| 項目 | 結果 |
| --- | --- |
| `run-check.sh 36 test` | 266件成功、失敗0件 |
| `run-check.sh 36 release` | BUILD SUCCEEDED |
| `run-check.sh 36 testbuild` | TEST BUILD SUCCEEDED |

## 未検証

- 専用VMでの画面と、Stack 表示の追加・削除・並び順変更を未確認。
- 空フォルダ、権限拒否、白黒、ガラス調の実画面を未確認。
- macOS 15 から最新 macOS までの見え方を未確認。
- ファイルシステムが返す一覧順は環境に依存する。Dock Studio は受け取った順を表示するため、標準 Dock と順序が異なる場合がある。
- アイコンを表示したままフォルダが変わった場合、変化は次のホバーまたは再表示まで反映されない。

## 撮影の手順

撮影は専用ヘッドレス macOS VM または検証用 Mac のゲストで行う。ホストには Dock Studio を表示しない。

### 検証データ

ゲストで `/Users/Shared/dockstudio-36` を作り、次の `profiles.json` を置く。`Unreadable Folder` は読み込み失敗を確認するためのフォルダになる。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000036",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": false,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000036",
      "name": "Folder stack demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-000000000037",
          "name": "Preview Folder",
          "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-36/Preview%20Folder/",
          "folderDisplayStyle": "stack"
        },
        {
          "id": "00000000-0000-0000-0000-000000000038",
          "name": "Empty Folder",
          "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-36/Empty%20Folder/",
          "folderDisplayStyle": "stack"
        },
        {
          "id": "00000000-0000-0000-0000-000000000039",
          "name": "Unreadable Folder",
          "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-36/Unreadable%20Folder/",
          "folderDisplayStyle": "stack"
        }
      ]
    }
  ]
}
```

ゲストで以下を実行し、ビルドした Dock Studio を起動する。

```sh
mkdir -p "/Users/Shared/dockstudio-36/Preview Folder/03 Nested Folder"
mkdir -p "/Users/Shared/dockstudio-36/Empty Folder"
mkdir -p "/Users/Shared/dockstudio-36/Unreadable Folder"
printf 'Folder stack fixture\n' > "/Users/Shared/dockstudio-36/Preview Folder/01 Notes.txt"
printf 'Name,Value\nExample,1\n' > "/Users/Shared/dockstudio-36/Preview Folder/02 Data.csv"
printf 'Fourth item\n' > "/Users/Shared/dockstudio-36/Preview Folder/04 Readme.txt"
chmod 000 "/Users/Shared/dockstudio-36/Unreadable Folder"
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-36 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作

1. Custom Dock を表示し、「Preview Folder」が Stack アイコンで表示されることを確認する。
2. アイコンを右クリックし、「フォルダとして表示」を選ぶ。通常のフォルダアイコンに変わることを確認する。もう一度右クリックし、「Stack として表示」を選び、Stack 表示へ戻す。
3. Dock Studio を終了して起動し直す。Preview Folder が Stack 表示で復元することを確認する。
4. `Preview Folder` にファイルを追加し、ポインタを一度アイコンの外へ移してから戻す。内容プレビューが更新することを確認する。ファイルを削除する操作も行い、同じ方法で更新を確認する。
5. `Empty Folder` の Stack アイコンが通常のフォルダアイコンで表示されることを確認する。
6. `Unreadable Folder` の Stack アイコンに警告マークが表示されることを確認する。撮影後はゲストで `chmod 700` を実行して権限を戻す。
7. 設定の「アイコンの外観」を「白黒」にし、Stack 表示を撮影する。同じ手順で「ガラス調」も確認する。
8. 標準 macOS Dock に `Preview Folder` を追加し、右クリックの表示形式を「Stack」にして同じフォルダを表示する。

### 標準 macOS Dock との比較で記録する項目

- 先頭に見えるファイル、サブフォルダの名前と順番、および前面に出るアイコン。
- アイコンの大きさに対する内容アイコンの大きさ、重なり具合、見える項目数。
- ファイルの追加、削除、名前変更後にアイコンが更新するまでの時間。
- 空フォルダと読み込み拒否フォルダの表示。
- Folder と Stack の切り替え操作と、Dock Studio の再起動後に設定が残るかどうか。
- Dock Studio の白黒、ガラス調表示。標準 Dock 側に同じアイコン外観設定がない場合は比較対象外として記録する。

撮影担当は、比較のために選んだ標準 Dock の設定と観察した順序を記録する。表示順の違いがあっても、Dock Studio 側で並べ替えは行わない。

### 撮影するもの

| 種類 | 内容 |
| --- | --- |
| 画像 | 通常表示と Stack 表示の Preview Folder |
| 画像 | 空フォルダの表示と、読み込み失敗時の警告マーク |
| 画像 | 白黒とガラス調の Stack 表示 |
| 画像 | 標準 macOS Dock の Stack 表示 |
| 動画 | Folder と Stack の切り替え、再起動後の復元 |
| 動画 | フォルダ内項目の追加または削除後、ホバーで Stack アイコンが更新する操作 |

専用VMで撮影するまで、実画面と表示差は未検証になる。
