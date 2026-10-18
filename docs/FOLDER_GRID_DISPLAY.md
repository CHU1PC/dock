# フォルダ内容のグリッド表示

## 仕様

Dock のフォルダを開くと、内容を従来のリストまたは新しいグリッドで表示する。上部の切替で表示形式を選び、フォルダごとに選択を保存する。Grid は2列でアイコンと名前を並べ、多数の項目はスクロールして表示する。項目の選択は既存の開く処理を使い、Finder で開く操作も維持する。

Grid の項目はボタンとして操作できる。矢印キーでグリッド内を移動し、Return または Space で選択中の項目を開く。Escape でフォルダを閉じる。

## 設計判断

- 保存先は各 `DockItem` の `folderDisplayMode` とし、プロファイルの一部として永続化する。プロファイルごとの設定と既存の保存経路を使うためになる。
- 保存値は `list` または `grid` にする。既存の `profiles.json` にはこの値がないため、未設定の場合は従来どおり List を表示する。
- グリッドは2列とし、ポップオーバーの高さを320ポイントまでに制限する。項目が多い場合もスクロールできる。
- ポップオーバーを閉じる操作は Escape を受け付ける。画面端と左右配置での実際の位置は専用 VM での撮影時に確認する。

## 受け入れ条件との対応

| 条件 | 状況 |
| --- | --- |
| Grid でアイコンと名前を表示し、フォルダごとに表示形式を保存する | 満たした。2列グリッド、`DockItem.folderDisplayMode`、再起動後の保存を実装し、単体テストで別フォルダに設定が混ざらないことを確認した |
| 多数の項目、画面端、左右配置で操作できる | 一部のみ。遅延表示とスクロールを実装したが、実画面での端配置と左右配置は未確認である |
| 選択して開く、閉じる、キーボード操作を確認する | 一部のみ。ボタン選択、矢印移動、Return または Space、Escape を実装した。実画面の操作は専用 VM での撮影時に確認する |

## 自動テストとビルド

ホストでは指定スクリプトを使い、GUI を開かずに検証した。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 262件、失敗0件 |
| Release ビルド | `BUILD SUCCEEDED` |
| Debug の `build-for-testing` | `TEST BUILD SUCCEEDED` |

## 未検証

- Grid の実際の描画、画面端でのポップオーバー配置、Dock の左右配置。
- 多数の項目のスクロール、Grid と List の切替後の再表示。
- グリッド内の矢印移動、項目を開く操作、Escape による閉じる操作。
- macOS 15 以降のバージョン差。
- Apple の標準 Dock と比べた列数、セル間隔、表示項目数、画面端との距離。

## 撮影の手順

撮影担当は専用のヘッドレス macOS VM または検証用 Mac のゲストで行う。普段使いのホストでは画面を表示しない。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-33` を作り、次の `profiles.json` を置く。`grid` と `list` の2フォルダを別設定にして、保存がフォルダごとに分かれることを確認する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000033",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 52,
    "autoHide": false,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000033",
      "name": "Folder grid demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-0000000000a1",
          "name": "Grid sample",
          "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-33/grid/",
          "folderDisplayMode": "grid"
        },
        {
          "id": "00000000-0000-0000-0000-0000000000a2",
          "name": "List sample",
          "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-33/list/",
          "folderDisplayMode": "list"
        }
      ]
    }
  ]
}
```

ゲストの端末で項目を作る。30個以上にしてスクロールが必要な状態にする。

```sh
mkdir -p /Users/Shared/dockstudio-33/grid /Users/Shared/dockstudio-33/list
for i in $(seq -w 1 36); do
  touch "/Users/Shared/dockstudio-33/grid/Document $i.txt"
done
touch "/Users/Shared/dockstudio-33/grid/This is a longer filename for wrapping.txt"
mkdir "/Users/Shared/dockstudio-33/grid/Projects"
touch "/Users/Shared/dockstudio-33/list/Read Me.txt"
```

Release 成果物のアプリをゲストへ置き、次で起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-33 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待する結果

1. Custom Dock を画面下に表示し、「Grid sample」を開く。アイコンと名前が2列に並び、一覧をスクロールできる。
2. 表示形式を List に切り替えて閉じ、再度開く。List が選ばれていることを確認する。
3. 「List sample」を開く。List で表示されることを確認し、Grid に切り替える。両フォルダの選択が独立していることを確認する。
4. Grid で矢印キーを押し、フォーカスが項目間を移動することを確認する。Return または Space で項目を開く。
5. フォルダをもう一度開き、Escape で閉じる。
6. 設定で Dock の位置を左、次に右へ変更する。それぞれフォルダを開き、ポップオーバーと項目が画面内に収まり、スクロールと選択を行えることを確認する。
7. 左右配置で項目数の多い Grid を開き、上下にスクロールする。最初と最後の項目が選択できることを確認する。

### 標準 Dock との比較で測る項目

ゲストの同じ macOS バージョン、画面解像度、拡大率で、同じ項目を持つフォルダを標準 Dock の Grid 表示でも撮影する。撮影ごとに次を記録する。

- macOS バージョン、画面解像度と拡大率、Dock の位置。
- 表示される列数と行数、アイコンの大きさ、セルの横・縦間隔。
- スクロール前に見える項目数、最終項目までのスクロール操作。
- 画面端に近い状態でのポップオーバーの四辺の座標と画面端までの最小距離。
- 項目名の折り返し、長い名前の省略、選択状態の見え方。
- 矢印キーによる移動、Return または Space による起動、Escape による閉じ方。

### 撮影するもの

- 画像: 画面下の Grid、List、Grid の多項目スクロール中。
- 画像: 画面左と右の Dock で Grid を開いた状態。
- 画像: 長い名前の項目と、フォーカス中の項目。
- 画像: 標準 Dock の同じフォルダと項目配置。
- 動画: 表示形式の切替と再度開いたときの保存状態。
- 動画: キーボードでの移動、項目を開く操作、Escape で閉じる操作。
- 動画: Dock の左と右で項目数の多い Grid を開き、スクロールする操作。

VM で撮影後、実画面の結果と計測値をこの文書に追記し、PR の本文に変更後の画面と操作動画を掲載する。
