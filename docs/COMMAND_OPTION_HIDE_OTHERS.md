# Command+Option クリックで他のアプリを隠す

## 仕様

カスタム Dock のアプリのアイコンを Command+Option を押しながらクリックすると、そのアプリを前面にして、ほかの通常アプリを隠す。実行中のアプリのコンテキストメニューにも「ほかを隠す」を追加した。

- 修飾キーは Command と Option だけが押されているときに限る。Shift または Control が加わると、通常のクリックと同じく開く。Caps Lock は無視する。
- 隠す対象は、起動中、かつ通常のアプリ（`activationPolicy == .regular`）で、対象と DockStudio 自身を除き、隠れていないものになる。`hide()` を呼ぶだけで、どのプロセスも終了しない。
- 対象が起動していないときは、隠さずに通常どおり開く。起動の成否は非同期のため、起動後に隠す処理は含めない。
- 対象を前面にできなかったときは、何も隠さずにエラーを表示する。
- アプリ以外の項目（フォルダ、URL など）と、バンドル ID を持たない項目は、通常のクリックと同じ処理になる。
- 通常のクリックと、Return、Space キーの動作は変えていない。

修飾キーの判定は `ItemClickPolicy.isHideOthersClick`、隠す処理は `OtherApplicationsHider`（#17 の `ApplicationHider` とは別の型）に分けた。クリック処理は `DockStore.clickItem(_:modifiers:)` を経由する。Command のみは Finder 表示（#18）、Command+Option は他を隠す、Option のみは #19 が扱い、テストで重ならないことを確かめる。コンテキストメニューの「ほかを隠す」は `DockItemMenu.kinds` に載せた。

## 検証

2026-10-18 にホストで確認した。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 149件すべて成功した（新規7件を含む） |
| Release ビルド | 成功した |
| `build-for-testing`（Debug） | 成功した |

新規テストは `DockStudioTests/HideOthersTests.swift` にある。修飾キーの組合せ、対象の前面化と他アプリの非表示、自身と背景アプリと隠れ済みと終了済みの除外、未起動、前面化の失敗、アプリ以外の項目を確かめる。

### 未検証

- 実際のアプリに対する `activate()` と `hide()` の動作（GUI は未確認）。
- macOS 15 以降の差分。
- 実際の Command+Option クリックで `NSEvent.modifierFlags` が期待どおりに取れること。

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `a4e9747` の Release ビルドを macOS 26.6.2 の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `8826bfd9cc02f15be53b631d130ed2452ce41e1e6c5af7ca32874367fd11143b` と一致した。パネルだけが写るよう、管理ウィンドウは「設定」タブにした（[操作前](media/command-option-hide-others/panel-settings-tab-before-full.jpg)）。キーは、ゲスト内の CGEvent で、Command のキーダウン、Option のキーダウンの順に送り、押したままクリックし、キーアップの順に送った。**撮影手順との違い**: Safari は、ゲストで起動すると全画面になり、Dock Studio のウィンドウと別の Space に出てしまったため、使わなかった。代わりに Terminal と TextEdit を起動し、Calculator は未起動のままにした。Safari の項目は、プロファイルにあるが、未起動のままである。操作の記録は[panel-cmd-opt-log.txt](media/command-option-hide-others/panel-cmd-opt-log.txt)にある。

| 操作 | 結果 |
| --- | --- |
| 前面が Terminal の状態で、パネルの TextEdit を Command+Option クリック | **隠れず、TextEdit は前面にならなかった。** 「操作を完了できませんでした。TextEdit を前面にできませんでした。」のアラートが出た。前面は Dock Studio、どのアプリも隠れなかった（[画像](media/command-option-hide-others/panel-cmd-opt-front-other-app-alert-crop.jpg)） |
| 前面が Dock Studio の状態で、パネルの TextEdit を Command+Option クリック | TextEdit が前面になり、Terminal、Calculator、Finder が隠れた。Dock Studio は隠れなかった。アラートなし。どのプロセスも残った（`pgrep` で全 pid を確認） |
| 前面が Terminal の状態で、右クリックメニューの「ほかを隠す」を TextEdit に実行 | 隠れず、同じ「前面にできませんでした」のアラートが出た（前面は Terminal のまま） |
| パネルの未起動の Calculator を Command+Option クリック | Calculator が起動し、ほかのアプリは隠れなかった |
| Command+Option+Shift で Terminal をクリック | Terminal が前面になり、ほかは隠れなかった（通常のクリックと同じ） |
| 修飾なしで TextEdit をクリック | TextEdit が前面になり、ほかは隠れなかった |
| Command のみで TextEdit をクリック | Finder が前面に出た（#18 の動作。回帰なし） |
| TextEdit の右クリックメニュー | 開く、Finder で表示、隠す、ほかを隠す、終了、強制終了…、Dock から取り外す の順に出た |

**所見（コードは直していない）**
- **他のアプリが前面（パネルが非アクティブ）のとき、Command+Option クリックと「ほかを隠す」は、対象を前面にできずに失敗し、何も隠れない。** Dock Studio が前面のときは動く。#18 と同じ、非アクティブなパネルからの前面化の問題と思われる（#18 では LaunchServices 経由に直した）。
- **Finder が隠れた。** 仕様の撮影手順は「Dock Studio 自身と Finder は隠れない」を期待しているが、Finder が隠れた。docs の仕様は、隠す対象を「起動中の通常アプリ（`.regular`）で、対象と Dock Studio 自身を除く」としており、Finder は除外されていない。標準 Dock の Command+Option クリックは Finder を隠すかどうかは、この撮影では確認していない。
- 動画は[panel-cmd-opt-click.mp4](media/command-option-hide-others/panel-cmd-opt-click.mp4)（8fps、第 1 回の操作のみ。アラートが出る場面を含む）。第 2 回（Dock Studio が前面のとき）は動画なし。

## 撮影の手順

確認する OS は、macOS 26.6.2 の専用ヘッドレス VM だけになる。ホストの画面には何も表示しない。

### 準備

1. ホストで Release ビルドを作り、`DockStudio.app` を VM にコピーする。ホストとゲストで実行ファイルの SHA-256 が一致することを確かめる。

```
nice -n 15 xcodebuild -project DockStudio.xcodeproj -scheme DockStudio -configuration Release \
  -derivedDataPath /tmp/dockstudio-20-derived CODE_SIGNING_ALLOWED=NO build
```

2. ゲストに検証用データのディレクトリ `~/hide-data` を作り、`profiles.json` を次の内容で置く。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "11111111-1111-1111-1111-111111111111",
  "profiles": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "Hide others test",
      "items": [
        { "id": "22222222-2222-2222-2222-222222222222", "name": "Calculator", "kind": "application",
          "target": "file:///System/Applications/Calculator.app", "bundleIdentifier": "com.apple.calculator" },
        { "id": "33333333-3333-3333-3333-333333333333", "name": "Safari", "kind": "application",
          "target": "file:///Applications/Safari.app", "bundleIdentifier": "com.apple.Safari" },
        { "id": "44444444-4444-4444-4444-444444444444", "name": "TextEdit", "kind": "application",
          "target": "file:///System/Applications/TextEdit.app", "bundleIdentifier": "com.apple.TextEdit" }
      ]
    }
  ],
  "settings": {
    "mode": "custom", "position": "bottom", "iconSize": 52, "autoHide": false,
    "revealAnimationDuration": 0.22, "launchBounce": true, "showRunningApps": true
  }
}
```

Safari の場所がゲストで異なる場合は、`mdfind "kMDItemCFBundleIdentifier == 'com.apple.Safari'"` で確かめて `target` を直す。

3. ゲストで Safari と TextEdit を起動し、それぞれウィンドウを開いておく（`open -a Safari`、`open -a TextEdit`）。Calculator は起動しない。

### 起動

```
DOCKSTUDIO_DATA_DIR=~/hide-data ~/DockStudio.app/Contents/MacOS/DockStudio &
```

### 操作と期待する見え方

1. Dock の TextEdit を Command+Option を押しながらクリックする。TextEdit が前面になり、Safari のウィンドウが隠れる。DockStudio のウィンドウは隠れない。
2. Safari を通常クリックする。Safari が前面になり、TextEdit は隠れたままになる。ほかのアプリは隠れない。
3. Safari を右クリックして「ほかを隠す」を選ぶ。Safari が前面になり、TextEdit が隠れる。
4. Calculator（未起動）を Command+Option を押しながらクリックする。Calculator が起動し、ほかのアプリは隠れない。
5. Command+Option+Shift を押しながら Safari をクリックする。通常のクリックと同じく Safari が開き、ほかのアプリは隠れない。
6. 1 から 5 のあと、Activity Monitor または `ps` で、どのプロセスも終了していないことを確認する。

### 撮るべき画像と動画

- 手順 1 の前後のデスクトップ（Safari と TextEdit のウィンドウが見える状態と、TextEdit だけが見える状態）の画像。
- 手順 3 のコンテキストメニューの画像（「ほかを隠す」が見える状態）。
- 手順 1 から 5 を通した動画。押している修飾キーが分かるよう、キーの表示を併せて撮る。
