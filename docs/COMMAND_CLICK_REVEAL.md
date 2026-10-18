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

- 管理画面内の Dock で Command クリックが Finder に表示されることは、実画面で確認した。パネルでは確認できず、上の「所見」を参照
- 修正後のパネルでの Command クリック。ボタンの action 内で `NSApp.currentEvent?.modifierFlags` を優先し、無ければ `NSEvent.modifierFlags` を使うようにした。さらに、`activateFileViewerSelecting` のあとに Finder の `NSRunningApplication.activate()` を加えた。どちらが原因だったか、効いたかは VM で未確認で、撮影担当は、パネルで Finder が前面に出て対象が選択されることを再確認する。
- macOS 15 以降での差異（VM が 26.6.2 のみ）

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `356ac94` の Release ビルドを macOS 26.6.2 の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `972c4a635c6eb4ded690d08b4066106e35bbc961669814443bea9bb752557fd2` と一致した。Command の押下は、ゲスト内の CGEvent で、クリックのイベントに `.maskCommand` を付けて合成した。

確認できたこと:

- 管理画面内（Dock Studio のウィンドウ）の Dock で、Finder が前面のとき（ウィンドウは非アクティブ）に Calculator を Command クリックすると、Calculator は起動せず、Finder の「Applications」が開いて Calculator.app が選択された（[window-dock-cmd-click-calculator-finder.jpg](media/command-click-reveal/window-dock-cmd-click-calculator-finder.jpg)）。

**所見（コードは直していない）**: デスクトップ用パネル（非アクティブ）では、Command クリックで Finder の表示にならなかった。

- TextEdit が前面の状態で、パネルの Calculator と Demo File を Command クリックした。Calculator は起動しなかったが、Finder は前面に出ず、前面は TextEdit のままだった（[panel-cmd-click-calculator-inactive.jpg](media/command-click-reveal/panel-cmd-click-calculator-inactive.jpg)、[panel-cmd-click-file-inactive.jpg](media/command-click-reveal/panel-cmd-click-file-inactive.jpg)）。
- Finder のウィンドウが背後に残っている様子はあるが、前面化も選択も確認できなかった。起動しなかったことは確認できたため、「通常の起動」にはなっていない。Command の修飾が `NSEvent.modifierFlags` で取れていない（未検証だった懸念）か、Finder 表示が前面化されていない可能性がある。切り分けは未実施。
- 1 回目の Command クリックは、他の入力と同じく、環境の入力欠落の可能性もある。各ボタンを 1 回ずつしか試していない。

確認できなかったこと:

- パネルでの Command クリックの再試行による切り分け、Demo Folder、Demo File（ウィンドウ側）、Removed Folder のアラート、Example Link、修飾キーなしのクリックの回帰、Command+Option。
- 動画。

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
