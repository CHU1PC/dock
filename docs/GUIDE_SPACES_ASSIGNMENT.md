# Spaces への割り当て方法を案内する

GitHub issue #120 の対応になる。

## 変更内容

アプリの Dock メニューに「Spaces への割り当て方法」を追加した。選ぶと、標準 Dock のアプリアイコンから「オプション」>「割り当て先」を開く手順を表示する。Spaces が2つ以上必要なことと、対象アプリのアイコンが標準 Dock にない場合は先に追加する必要があることも案内する。

他のアプリの Spaces 割り当てを変更する公開 API は見つかっていないため、Dock Studio から直接変更せず、標準 Dock の設定へ案内する。標準 Dock のメニュー構造に依存する Accessibility 操作や、非公開 API は使わない。

## 自動テスト

main の取り込み後に実行した `/private/tmp/cw/run-check.sh 120 test` は349件すべて成功した。`/private/tmp/cw/run-check.sh 120 release` は `BUILD SUCCEEDED`、初回 push 前の `/private/tmp/cw/run-check.sh 120 testbuild` は `TEST BUILD SUCCEEDED` になった。

追加した `DockItemMenu` の単体テストで、アプリ項目に案内メニューが含まれ、アプリ以外には含まれないことを確認した。

## 未検証

- macOS 15 と macOS 26 の実画面で、表示言語ごとのメニュー名を確認していない。
- 案内アラートの表示と実際の操作は、VM で確認していない。
- 標準 Dock にアイコンがないアプリを追加する手順は、画面で確認していない。

## 撮影の手順

撮影は専用のヘッドレス macOS VM で行う。ホストではアプリを起動しない。

### 検証用データと起動

ゲストで `/Users/Shared/dockstudio-120` を作り、`profiles.json` にアプリ項目を1つ登録する。次の例では TextEdit を案内対象にする。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Spaces assignment guide",
      "items": [
        { "id": "00000000-0000-0000-0000-000000000120", "name": "TextEdit", "kind": "application",
          "target": "file:///System/Applications/TextEdit.app/" }
      ]
    }
  ]
}
```

ゲストで次の環境変数を指定して Dock Studio を起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-120 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待結果

1. Custom Dock に TextEdit が表示される状態にする。
2. TextEdit のアイコンを右クリックし、「Spaces への割り当て方法」を選ぶ。
3. 標準 Dock のアイコンを Control キーを押しながらクリックし、「オプション」>「割り当て先」から設定する説明が表示される。
4. Spaces が2つ以上ある場合に選択肢が表示され、標準 Dock にアイコンがない場合は先に追加する必要があると説明される。

### 撮るもの

- 「Spaces への割り当て方法」が表示されたアプリのメニュー。
- 標準 Dock のアイコンを Control クリックする手順と制約を示す案内。
