# フォルダ項目の内容一覧

GitHub issue #31 の変更になる。

## 変更内容

Custom Dock のフォルダ項目をクリックすると、フォルダの内容を一覧表示する。項目を選ぶと、既存の起動前検証を通してアプリ、ファイル、またはサブフォルダを開く。ポップオーバーには「Finder で開く」も表示する。

空のフォルダ、読み込み中、アクセス拒否などの読み込みエラーを一覧内に表示する。表示中に項目が削除された場合は、選択時に既存の参照先確認が働き、開く前にエラーを表示する。シンボリックリンクは参照先を調べて種類を決め、元のリンク URL を項目の対象に保つ。壊れたリンクを開く場合は、参照先がない項目として扱う。

## 仕様判断

- 表示は SwiftUI のポップオーバーにし、外側クリックと Escape による閉じ方は標準のポップオーバー動作に任せる。
- ファイルシステムの読み込みは UI タスクから分離する。内容を読み込めない場合は、その理由をポップオーバーに表示する。
- 一覧の順序は読み込み元が返す順序を使う。並べ替え設定は追加しない。
- Grid、Fan、Stack 切替は追加しない。
- 項目を開く処理は `DockStore.openItem` を使い、既存のアクセス可否、ファイル種別、起動確認を維持する。

## 自動テスト結果

| 項目 | 結果 |
| --- | --- |
| `run-check.sh 31 test` | 260件成功、失敗0件 |
| `run-check.sh 31 release` | BUILD SUCCEEDED |
| `run-check.sh 31 testbuild` | TEST BUILD SUCCEEDED |

## 未検証

- 専用 VM 上での実画面と、外側クリックおよび Escape による閉じ方。
- 実際の権限拒否フォルダの表示。
- macOS 15 での見た目。開発環境での GUI 起動は禁止されている。
- macOS 標準 Dock との表示差。撮影担当者が下記手順で比較する。

## 撮影の手順

専用ヘッドレス macOS VM または検証用 Mac のゲストで実行する。普段使いのホストには Dock Studio を表示しない。ゲストで `/Users/Shared/dockstudio-31/Fixture Folder` とその中の `Nested Folder` を作り、`Fixture Folder` 内に `Notes.txt` を作る。続けて `Nested Folder` へのシンボリックリンク `Linked Folder` を作る。

次の `profiles.json` を `/Users/Shared/dockstudio-31/profiles.json` に置く。`Fixture Folder` と項目のファイルパスが一致することを確認する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000031",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": false,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000031",
      "name": "Folder list demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-000000000032",
          "name": "Fixture Folder",
          "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-31/Fixture%20Folder/"
        },
        {
          "id": "00000000-0000-0000-0000-000000000033",
          "name": "Empty Folder",
          "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-31/Empty%20Folder/"
        }
      ]
    }
  ]
}
```

ゲストで次を実行し、ビルドした Dock Studio を起動する。

```sh
mkdir -p "/Users/Shared/dockstudio-31/Fixture Folder/Nested Folder"
mkdir -p "/Users/Shared/dockstudio-31/Empty Folder"
printf 'Folder list fixture\n' > "/Users/Shared/dockstudio-31/Fixture Folder/Notes.txt"
ln -s "Nested Folder" "/Users/Shared/dockstudio-31/Fixture Folder/Linked Folder"
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-31 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作

1. Custom Dock の「Fixture Folder」をクリックし、一覧を表示する。
2. `Notes.txt` を選び、既定のアプリで開くことを確認する。
3. 一覧をもう一度開き、`Nested Folder` を選び、Finder で開くことを確認する。
4. 「Finder で開く」を選び、親フォルダが Finder で表示されることを確認する。
5. 一覧を開いて外側をクリックし、閉じることを確認する。もう一度開き、Escape でも閉じることを確認する。
6. `Linked Folder` がフォルダとして表示され、選ぶと参照先のフォルダが開くことを確認する。
7. 「Empty Folder」を開き、空フォルダの表示を確認する。
8. 標準 macOS Dock に同じ Fixture Folder を追加し、右クリックからフォルダの表示形式を「リスト」に設定して開く。

### 標準 macOS Dock との比較で記録する項目

- 標準 Dock と Dock Studio の一覧に出る子項目の名前、アイコン、および表示順。
- 一覧の幅と高さ、表示できる項目数、長い名前の省略方法。
- ファイル、サブフォルダ、アプリケーション、シンボリックリンクの表示と選択時の動作。
- 外側クリックと Escape で閉じるかどうか。
- Finder で開く操作が見えるか、選択したフォルダが Finder で開くか。

表示順は環境で観察して記録する。Dock Studio 側の並べ替え仕様として扱わない。

### 撮影するもの

| 種類 | 内容 |
| --- | --- |
| 画像 | Dock Studio のフォルダ一覧と、子項目が分かる状態 |
| 画像 | 空フォルダの表示 |
| 画像 | 標準 Dock のリスト表示 |
| 画像 | 子項目を開いた後の Finder |
| 動画 | フォルダをクリックして一覧を開き、子項目を開く操作 |
| 動画 | 外側クリックと Escape で一覧を閉じる操作 |

専用 VM で撮影を終えるまで、実画面と操作は未検証になる。
