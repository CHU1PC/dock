# キーボードで Custom Dock の表示を切り替える

GitHub issue #52 の実装になる。

## 仕様

Dock Studio のアプリメニューに「Custom Dock」メニューを追加し、「Custom Dock の表示を切り替える」項目から表示状態を切り替えられるようにした。macOS の「システム設定」>「キーボード」>「キーボードショートカット」>「アプリのショートカット」で Dock Studio を選び、この項目名に利用者がショートカットを割り当てる。初期状態ではキーを割り当てないため、標準 Dock の Command+Option+D と衝突しない。割り当てたショートカットは Dock Studio がアクティブな間に使う。

このメニュー項目は既存の `DockStore.toggleDockVisibility()` だけを呼ぶ。Custom Dock の `isDockVisible` を切り替えるため、標準 Dock の表示設定には触れない。読み取り専用の設定データを開いている場合は、メニュー項目を無効にする。

自動非表示と手動の表示状態は別に扱う。自動非表示が有効な場合、ポインタが離れた後に Custom Dock が一時的に折りたたまれる。ショートカットを押すと手動の表示状態が切り替わり、隠れていれば表示され、表示中なら手動で隠れる。自動非表示の設定そのものは変更しない。

## 受け入れ条件との対応

| 条件 | 状況 |
| --- | --- |
| 利用者が設定したキーで Custom Dock の表示を切り替える | 満たした。アプリメニュー項目に macOS のアプリショートカットを割り当てられる。割当後の実キー操作は VM で未確認 |
| 標準 Dock のショートカットとの衝突を避け、別の Dock を誤って変更しない | 満たした。既定ショートカットを設けず、Custom Dock のストア状態だけを切り替える |
| 自動非表示と手動で隠した状態を区別して動作を定義する | 満たした。自動非表示は一時折りたたみで、ショートカットは保存対象の手動表示状態を切り替える。単体テストで設定値が維持されることを確認する |

## 検証

ホストでは `swift test`、Release ビルド、Debug の `build-for-testing` を実行する。GUI は起動しない。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 238 件すべて成功した（0 failures） |
| Release ビルド | 成功した（BUILD SUCCEEDED） |
| Debug の `build-for-testing` | 成功した（TEST BUILD SUCCEEDED） |

### 未検証

- macOS のアプリショートカット設定画面で、メニュー項目にキーを割り当てて実際に切り替わること
- macOS 15 以降でのアプリショートカット設定 UI の差異
- 標準 Dock と Custom Dock を並べた実画面、および自動非表示中の実操作

## 撮影の手順

撮影は専用ヘッドレス VM または検証用 Mac で行う。ホストではアプリを起動しない。

### 検証用データ

ゲストに `/Users/Shared/dockstudio-52` を作り、その中に次の `profiles.json` を置く。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Keyboard toggle demo",
      "items": [
        { "id": "00000000-0000-0000-0000-0000000000a1", "name": "Calculator", "kind": "application",
          "target": "file:///System/Applications/Calculator.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a2", "name": "TextEdit", "kind": "application",
          "target": "file:///System/Applications/TextEdit.app/" }
      ]
    }
  ]
}
```

ビルド成果物の `DockStudio.app` をゲストに置き、次で起動する。

```
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-52 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作

1. macOS のシステム設定で Dock Studio のアプリショートカットを追加し、メニュータイトルに「Custom Dock の表示を切り替える」を入力する。Command+Option+D は標準 Dock 用なので割り当てず、ほかのキーを選ぶ。
2. Dock Studio をアクティブにして Custom Dock を表示する。メニューバーの「Custom Dock」から、切り替え項目と割り当てたキーが確認できる画面を撮る。
3. 割り当てたキーを押す。Custom Dock が隠れることを確認してから、もう一度押して表示されることを確認する。
4. 標準 Dock の Command+Option+D を押し、標準 Dock だけが切り替わることを確認する。
5. Dock Studio の設定で自動非表示を有効にする。Custom Dock が自動で折りたたまれた状態から割り当てたキーを押し、Dock が表示されることを確認する。再度キーを押して手動で隠し、設定の自動非表示が有効のままであることも確認する。

### 期待する見え方

- メニューバーの「Custom Dock」メニューに切り替え項目が表示される。
- 利用者が割り当てたキーで Custom Dock だけが表示または非表示になる。
- 自動非表示は一時的な折りたたみとして動き、手動で隠した状態はショートカットで明示的に切り替わる。
- 標準 Dock 用の Command+Option+D は標準 Dock を切り替える。

### 撮るべきもの

| 種類 | 内容 |
| --- | --- |
| 画像 | メニューバーの Custom Dock メニューと切り替え項目 |
| 画像 | Custom Dock が表示されたデスクトップ |
| 画像 | キー操作で Custom Dock が隠れたデスクトップ |
| 動画 | 割り当てたキーによる表示、非表示の切り替え |
| 動画 | 自動非表示中のキー操作と、手動で隠した状態の切り替え |
| 動画 | 標準 Dock の Command+Option+D が Custom Dock に影響しないこと |

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `77c53d0` の Release ビルドを macOS 26.6.2 の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `69cbc090de97c45c2f2db0c4b6a83da3989a549b24523d03e4c99e969390f3ef` と一致した。Calculator と TextEdit のプロファイル、下配置、アイコン 64。ログは[key-logs.txt](media/keyboard-toggle-dock-visibility/key-logs.txt)にある。

**ショートカットの割当て**: システム設定の画面操作を避け、同じ仕組みの `defaults write app.dockstudio.preview NSUserKeyEquivalents -dict-add "Custom Dock の表示を切り替える" "^~k"`（Control+Option+K）で割り当てた（アプリのバンドル ID は `app.dockstudio.preview`）。割当て後に System Events で読むと、メニュー項目「Custom Dock の表示を切り替える」のキー文字は `K`、修飾キーの値は 14 だった。撮影後に割当ては削除した。

| 確認項目 | 結果 |
| --- | --- |
| メニューバーに「Custom Dock」メニューがあり、切り替え項目が出る | 満たした。AX で「Custom Dock」のメニューバー項目と、項目「Custom Dock の表示を切り替える」を確認した。**メニューを開いた画面は、VNC のフレームに映らず、撮れなかった**（メニューバーのメニューは VNC に出ない）。メニューバーに「Custom Dock」が並んでいる画像は[こちら](media/keyboard-toggle-dock-visibility/menubar-custom-dock-menu-crop.jpg) |
| 割り当てたキー（Control+Option+K）で Custom Dock の表示と非表示が切り替わる | 満たした。パネルのウィンドウの `onscreen` が 1、false、1、false と、押すたびに切り替わった（[動画](media/keyboard-toggle-dock-visibility/toggle-key.mp4)、[コマ](media/keyboard-toggle-dock-visibility/toggle-key-frames.png)） |
| 標準 Dock の Command+Option+D は標準 Dock だけを切り替える | 満たした。標準 Dock の `autohide` が 1、0、1 と変わり、Custom Dock のパネルは影響を受けず `onscreen=1` のままだった。標準 Dock の実測: Command+Option+D で自動非表示が切り替わる（撮影後に元の 1 へ戻した） |
| 自動非表示を有効にしても、ショートカットで切り替わる | 満たした。自動非表示を有効にし（`autoHide: true`）、ポインタを離した状態で、キーを 3 回押すと、`onscreen` が false、1、false となり、設定の `autoHide` は true のままだった（[動画](media/keyboard-toggle-dock-visibility/autohide-toggle-key.mp4)）。なお、自動非表示の折りたたみは、パネルのウィンドウの `onscreen` を変えない（ウィンドウの位置は同じ）ため、折りたたまれた状態そのものは、ウィンドウ情報では確認できなかった |

所見:
- **ショートカットの 1 回目が効かないことがあった。** 2 回の連続実行で、Dock Studio が前面のとき、アイドルの後の最初の Control+Option+K では、パネルの状態が変わらず、2 回目から 1 回ごとに切り替わった（1 回目の記録は `key-logs.txt` の「第 1 回」、「第 2 回」）。3 回目の実行（自動非表示）では、1 回目から切り替わった。キーイベントの合成の取りこぼしの可能性があり、アプリ側の不具合とは断定していない。
- 画像: 動画のコマに、「Custom Dock」タブのウィンドウ内プレビューとパネルが重なって二重に見える場面がある（`Custom Dock` タブで撮ったため）。
