# 展開したフォルダ内容の並べ替え

## 変更内容

フォルダ一覧の上部に並べ替えメニューを追加した。名前、追加日、変更日、作成日、種類から選べる。

選択は Dock 項目ごとに `folderSortOrder` としてプロファイルへ保存する。未設定の既存項目は名前順で表示する。

並べ替えは純粋関数で行う。名前順は数字を含む名前を自然順に比較し、同名は URL で順序を決める。日付順は古い日付から並べ、日付を取得できない項目を末尾に置き、同じ日付は名前順にする。種類順はフォルダ、アプリケーション、ファイルの順にし、各グループ内は名前順にする。

日付はフォルダ一覧を開くたびに URL のリソース値から読む。追加日はファイルシステムが提供する `addedToDirectoryDate` を使う。これが取得できない場合は日付欠落として末尾に表示する。

子項目のメタデータ取得では、ディレクトリ属性に加えて追加日、変更日、作成日の各リソースキーを要求する。これにより、日付順で実際のファイルシステム値を使って並べ替える。

## 仕様判断

既定の並べ方は名前順にした。これにより、設定がない既存プロファイルでも一覧が毎回同じ順に表示される。

日付の昇順と欠落値の末尾表示を選んだ。種類順ではフォルダを先に表示し、アプリケーションを通常のファイルより前に表示する。同名項目の名前比較が同値になった場合は参照先の URL で安定化する。

フォルダごとの設定を Dock 項目に保存する。別のフォルダの並べ替え選択には影響しない。

## 自動テスト

| 項目 | 結果 |
| --- | --- |
| `swift test` | 399件成功、失敗0件 |
| Release ビルド | 成功 |
| Debug の `build-for-testing` | 成功 |

新規テストでは自然な名前順、同名の安定順、日付欠落の末尾配置、日付の同値時の名前順、種類順のフォルダ先行、フォルダごとの保存、および実ファイルの変更日を使う読込後の並べ替えを確認する。

## 未検証

- 専用 macOS VM での表示と操作は未確認。実画面の撮影は行っていない。
- macOS 15 以降の OS ごとの `addedToDirectoryDate` の提供状況は未確認。
- 標準 Dock と Dock Studio の日付順の方向、欠落日時、同名項目、追加後の更新、フォルダ先行の挙動は VM で比較して記録する。

## 撮影の手順

専用のヘッドレス macOS VM のゲスト内で撮影する。ホストではアプリを起動しない。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-35/profiles.json` を作成し、次の内容を保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Folder sort demo",
      "items": [
        { "id": "00000000-0000-0000-0000-000000000035", "name": "Sort Fixture", "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-35/Sort%20Fixture/", "folderSortOrder": "name" },
        { "id": "00000000-0000-0000-0000-000000000036", "name": "Second Fixture", "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-35/Second%20Fixture/", "folderSortOrder": "kind" }
      ]
    }
  ]
}
```

ゲストで項目を作り、ビルドした `DockStudio.app` をゲストに置く。

```sh
mkdir -p "/Users/Shared/dockstudio-35/Sort Fixture/Folder 10"
mkdir -p "/Users/Shared/dockstudio-35/Sort Fixture/Folder 2"
mkdir -p "/Users/Shared/dockstudio-35/Second Fixture/Z Folder"
touch "/Users/Shared/dockstudio-35/Sort Fixture/Beta.txt"
touch "/Users/Shared/dockstudio-35/Sort Fixture/Alpha 10.txt"
touch "/Users/Shared/dockstudio-35/Sort Fixture/Alpha 2.txt"
touch "/Users/Shared/dockstudio-35/Second Fixture/A File.txt"
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-35 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作

1. Custom Dock の「Sort Fixture」を開き、名前、追加日、変更日、作成日、種類を順に選択する。
2. 各選択後の表示順を記録し、選択を変えるたびに一覧が更新されることを確認する。
3. 「Second Fixture」を開き、種類順でフォルダがファイルより前に出ることを確認する。
4. 2つのフォルダの並べ方を異なる値に設定し、両方を閉じて再度開く。各フォルダの選択が保持されることを確認する。
5. `Sort Fixture` に新しいファイルを追加して一覧を閉じ、再度開く。内容と日付順が更新されるかを記録する。
6. 標準 macOS Dock に同じ `Sort Fixture` を追加し、フォルダメニューからリスト表示と各利用可能な並べ替えを選ぶ。
7. 標準 Dock と Dock Studio で、項目名、アイコン、表示順、一覧の幅と高さ、見える項目数、長い名前の省略、日付欠落、同名、追加後の更新、フォルダ先行の設定を比較して記録する。

### 期待する見え方

- 並べ替えメニューに名前、追加日、変更日、作成日、種類が表示される。
- 選んだ並べ方がそのフォルダに保存され、別フォルダには影響しない。
- 名前順では `Alpha 2.txt` が `Alpha 10.txt` より前に出る。
- 種類順ではフォルダが先に出て、名前順のグループ内で表示される。
- 日付順では取得できる項目を先にし、日付欠落の項目を末尾に置く。

### 撮影するもの

| 種類 | 内容 |
| --- | --- |
| 画像 | 各並べ替え値での一覧と選択中のメニュー |
| 画像 | 種類順でフォルダがファイルより前にある一覧 |
| 画像 | 標準 Dock のフォルダ一覧と並べ替えメニュー |
| 動画 | 並べ替え値を切り替え、一覧の順序が更新される操作 |
| 動画 | 別々の並べ方を設定した2つのフォルダを閉じて再度開く操作 |

撮影後、標準 Dock との比較で確認した内容と OS バージョンをこの文書の「未検証」から実測記録へ更新する。
