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
