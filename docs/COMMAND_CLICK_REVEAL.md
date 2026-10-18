# Command クリックで対象を Finder に表示する

## 仕様

Dock の項目を Command だけを押しながらクリックすると、対象を開かずに、Finder で選択して表示する。

| 項目の種類と状態 | Command クリックの結果 |
| --- | --- |
| アプリ、フォルダ、ファイル（利用可能またはアクセス不可） | 起動せず、Finder で対象を選択して表示する |
| 参照切れ、ボリューム未接続 | Finder は開かず、通常のクリックと同じ文言のエラーを表示する |
| リンク（URL）、対象が未設定の項目 | 何もしない（開きもしない。Finder に表示する対象がないため） |
| 時計、集中タイマー、スペーサー | 従来どおり（この操作の対象外） |

- 修飾キーは Command だけのときに反応する。Option、Control、Shift のどれかを併用したクリックは、Finder 表示にはならず、従来どおり開く。Command+Option は別の機能（issue #20）に使うため、ここでは奪わない。
- 修飾キーなしのクリック、Return、Space は変更していない。
- 管理画面内のプレビュー（`isPreview`）では、何も開かず、ステータスに表示するだけにする。
- 判定は `ItemClickPolicy`（`DockStudio/Services/ItemClickAction.swift`）が行う。画面から独立した純粋な構造体で、単体テストで縛っている。`DockStore.clickItem` がクリックを受け、修飾キーで `openItem` と Finder 表示を振り分ける。
- 右クリックメニューの「Finder で表示」は変更していない。

## 自動テストの結果

ホストで、ビルドと単体テストだけを実行した。GUI は表示していない。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 149件すべて成功（新規7件: `ItemClickActionTests`） |
| Release ビルド | 成功した |
| Debug の `build-for-testing` | 成功した |

### 未検証

- 実際の Command クリックで Finder が前面に出て対象が選択されること
- `NSEvent.modifierFlags` が、非アクティブな Custom Dock パネルのクリックでも Command を返すこと
- macOS 15 以降での差異（VM が 26.6.2 のみ）

## 撮影の手順

撮影は、専用ヘッドレス VM のゲストの中だけで行う。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-18` を作り、次の `profiles.json` を置く。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Reveal demo",
      "items": [
        { "id": "00000000-0000-0000-0000-0000000000a1", "name": "Calculator", "kind": "application",
          "target": "file:///System/Applications/Calculator.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a2", "name": "Demo Folder", "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-18/Demo%20Folder/" },
        { "id": "00000000-0000-0000-0000-0000000000a3", "name": "Demo File", "kind": "file",
          "target": "file:///Users/Shared/dockstudio-18/Demo%20Folder/note.txt" },
        { "id": "00000000-0000-0000-0000-0000000000a4", "name": "Removed Folder", "kind": "folder",
          "target": "file:///Users/Shared/removed-folder/" },
        { "id": "00000000-0000-0000-0000-0000000000a5", "name": "Example Link", "kind": "link",
          "target": "https://example.com/" }
      ]
    }
  ]
}
```

起動前に、ゲストで次を実行する。

```
mkdir -p "/Users/Shared/dockstudio-18/Demo Folder" && echo hello > "/Users/Shared/dockstudio-18/Demo Folder/note.txt"
rm -rf /Users/Shared/removed-folder
```

アプリのビルド成果物をゲストに置き、次で起動する。

```
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-18 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待する見え方

Command のキー押下は、ゲスト内の CGEvent（クリックのイベントに `.maskCommand` を付ける）で合成する。

| 操作 | 期待する見え方 |
| --- | --- |
| Calculator を Command クリック | Calculator は起動せず、Finder が前面に出て `/System/Applications` の Calculator.app が選択される |
| Demo Folder を Command クリック | Finder が前面に出て、`/Users/Shared/dockstudio-18` の中で Demo Folder が選択される |
| Demo File を Command クリック | Finder が前面に出て、Demo Folder の中で note.txt が選択される |
| Removed Folder を Command クリック | Finder は開かず、「Removed Folder は見つかりません。…」のアラートが出る |
| Example Link を Command クリック | ブラウザは起動せず、何も起きない |
| Calculator を修飾キーなしでクリック | 従来どおり Calculator が起動する（回帰の確認） |
| Calculator を Command+Option でクリック | Finder は開かず、従来どおり Calculator を開く |

### 撮るべき画像と動画

- 画像: Calculator を Command クリックした直後の、Finder で Calculator.app が選択された画面
- 画像: Demo File を Command クリックした直後の、note.txt が選択された Finder
- 画像: Removed Folder の Command クリックで出るアラート
- 動画: Dock の項目を Command クリックして Finder で選択され、Calculator が起動していないこと（Dock の起動中表示や、Calculator のウィンドウが出ないこと）が分かるもの
- 動画: 修飾キーなしのクリックで Calculator が起動する場面（比較用）
