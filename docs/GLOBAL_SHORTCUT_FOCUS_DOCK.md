# グローバルショートカットで Custom Dock にフォーカスする

GitHub issue #47 の実装になる。

## 変更内容

ほかのアプリを使っているときも、グローバルショートカットで Custom Dock を表示してキーボードフォーカスを移せるようにした。フォーカス後の矢印キー、文字入力、Return、Escape の操作は既存のキーボードナビゲーションを使う。

## 仕様の判断

- ショートカットには Carbon の `RegisterEventHotKey` を使う。アクセシビリティの許可を求めずにキーを受け取る。
- 初期値は `Control+Option+Command+D` にした。macOS 標準の `Control+F3` は登録しない。
- 設定の「Dock」画面で `Control+Option+Command` と D、K、M、F のいずれかを選べる。選択は `profiles.json` の設定に保存する。
- 登録に失敗した場合は設定画面に理由を表示する。別の組み合わせを選び直せる。
- ショートカットは既存の `DockStore.focusDock()` を呼ぶ。Dock が隠れていれば表示し、キーウインドウにしてフォーカスする。Escape で操作前のアプリへ戻る。
- Dock の項目間を移動する動作は変更していない。

## 自動テスト

ホストではビルドとテストだけを実行した。アプリは起動していない。

- `swift test`: 259 件すべて成功した。追加した `DockFocusShortcutTests` は3件になる。
- Release ビルド: 成功した。
- `build-for-testing`: 成功した。

## 未検証

- 専用 VM で、別アプリからのキー入力、Dock が隠れた状態からの表示、Escape での復帰を確認していない。
- 選択したショートカットが他アプリや macOS の登録と衝突した場合の画面は、まだ撮影していない。
- macOS 15 から 26 までの OS 差分と、Control+Option+Command のキー入力がないキーボードでの動作は確認していない。

## 撮影の手順

専用のヘッドレス VM のゲストで撮影する。ホストにはアプリや VM の画面を表示しない。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-47/profiles.json` を作り、次の内容を保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": false,
    "showRunningApps": false,
    "dockFocusShortcut": "controlOptionCommandD"
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Global shortcut demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-0000000000a1",
          "name": "Finder",
          "kind": "application",
          "target": "file:///System/Library/CoreServices/Finder.app/"
        },
        {
          "id": "00000000-0000-0000-0000-0000000000a2",
          "name": "Calculator",
          "kind": "application",
          "target": "file:///System/Applications/Calculator.app/"
        },
        {
          "id": "00000000-0000-0000-0000-0000000000a3",
          "name": "TextEdit",
          "kind": "application",
          "target": "file:///System/Applications/TextEdit.app/"
        }
      ]
    }
  ]
}
```

ゲストに置いたビルドを、次のように起動する。

```bash
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-47 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作

1. Finder を前面にし、Custom Dock が見えない状態にする。
2. `Control+Option+Command+D` を押す。Custom Dock が現れ、Finder の項目にキーボードフォーカスが当たることを確認する。
3. 右矢印で Calculator へ移動する。Escape を押すと、Dock のフォーカスが外れて Finder に戻ることを確認する。
4. 管理画面の「設定」タブを開く。プレビュー Dock が管理パネルと重ならない状態で、登録中のショートカットを確認する。
5. 設定で K に変更して保存する。`Control+Option+Command+K` で同じ操作ができ、D では起動しなくなることを確認する。
6. 標準 Dock との比較では、同じゲスト、ディスプレイ解像度、Dock の位置、Finder を使う。標準 Dock の「キーボードショートカット」設定に表示されたキーを記録し、標準キー（既定の `Control+F3`）で Dock に移ったときの最初のフォーカス項目、矢印キーの移動順、Escape 後の前面アプリ、Dock が隠れている場合の表示を測る。

### 撮るものと記録する値

- 画像: 設定画面のグローバルショートカットと、別アプリが前面の画面。
- 画像: グローバルショートカットで Dock にフォーカスした状態。
- 画像: Escape 後に Finder が前面へ戻った状態。
- 動画: Finder からショートカットを押して Dock に入り、項目を移動して Escape で戻るまで。
- 画像または動画: K に変更した設定と、K でフォーカスした状態。
- 標準 Dock の比較記録: macOS のバージョン、解像度、Dock の配置と自動非表示設定、設定画面に表示された標準ショートカット、最初にフォーカスされる項目、矢印キーの移動順、Escape 後の前面アプリ、隠れていた Dock が表示されるか。

設定画面を撮るときは、「Custom Dock」タブではなく「設定」タブを使う。プレビュー Dock とデスクトップの Dock が重なって見えるのを避ける。

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `456d9c9` の Release ビルドを macOS 26.6.2 の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `3e51e21a971d200a7135b095b2a1c22d9ce2d9e181e4afaa0019219c6d950754` と一致した。docs の `profiles.json`（Finder、Calculator、TextEdit、下配置、`dockFocusShortcut: controlOptionCommandD`）。キーは本物のキーダウンを先に送った。ログは[logs.txt](media/global-shortcut-focus-dock/logs.txt)にある。

```
before: front=Finder panel onscreen=false
after Ctrl+Opt+Cmd+D: front=DockStudio panel onscreen=1 focused: role=AXScrollArea
Right: focused: role=AXScrollArea
Escape: front=Finder panel onscreen=1 focused: role=AXWindow
(K へ変更後) D: front=Finder（反応なし）
K: front=DockStudio onscreen=1
```
- Finder を前面にし、Dock を隠した状態で `Control+Option+Command+D` を押すと、Custom Dock が現れ、Dock Studio が前面になった。コマで、Finder の項目にフォーカス枠が当たり、右矢印で Calculator へ移った（[コマ](media/global-shortcut-focus-dock/shortcut-focus-escape-frames.png)、[動画](media/global-shortcut-focus-dock/shortcut-focus-escape.mp4)）。Escape で前面が Finder に戻った。
- K への変更: 設定画面からの変更は撮れなかった（設定画面でショートカットの項目に到達できなかった）。代わりに `profiles.json` の `dockFocusShortcut` を `controlOptionCommandK` に書き換えて再起動した。D では反応せず、K で同じようにフォーカスされた（[画像](media/global-shortcut-focus-dock/shortcut-k-focus-full.jpg)）。設定画面のショートカット表示の画像は、撮れていない。
- AX の `AXFocusedUIElement` は `AXScrollArea` を返した（画面の枠とは一致しない。#93 と同じ所見）。
- 標準 Dock（macOS 26.6.2、1600x1000、下配置、自動非表示は無効にした）: Finder を前面にして、Control+F3 に当たるキー（keycode 99 に Control）を送ったが、フォーカス枠は現れず、標準 Dock の最初のフォーカス項目、矢印の順、Escape 後の前面は**確認できなかった**（合成キーが届かなかった可能性）。設定画面に表示された標準ショートカットの記録は撮っていない。撮影後、標準 Dock の設定は元に戻した。
