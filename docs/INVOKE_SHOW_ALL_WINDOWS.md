# 標準 Dock の全ウィンドウ表示を呼び出す

## 仕様

アプリ項目のコンテキストメニューに「全ウィンドウを表示」を追加した。実行時は Accessibility を使い、標準 Dock のアプリ項目から「Show All Windows」を選ぶ。キー入力の合成や非公開 API は使わず、アプリ自身のウィンドウ一覧を App Exposé として表示しない。

- 対象は、ファイル URL を持つアプリ項目になる。標準 Dock の Accessibility ツリーから `AXApplicationDockItem` の項目を探し、`AXURL` のパスが一致する項目だけを使う。
- Accessibility の許可がない場合は、無効な項目に許可が必要なことを表示する。許可が実行直前に失われた場合は、許可の案内をエラーとして表示する。
- Dock 項目、メニュー、またはメニュー項目を特定できない場合は実行しない。失敗した項目は、次にメニューを開いたときから無効にする。
- メニュー項目の名前は、英語と日本語の既知の表記だけを照合する。未対応の言語では候補が見つからず、安全に失敗する。
- 既存の「ウィンドウを前面に表示」は個別ウィンドウを選ぶ機能になる。「全ウィンドウを表示」は標準 Dock の App Exposé を呼び出す機能として、別の項目にする。

## 受け入れ条件との対応

| 条件 | 状況 | 根拠 |
|---|---|---|
| 対象アプリの Dock アイコンから標準 Dock の「Show All Windows」を実行する | 一部のみ | 実装は対象項目の `AXURL` と subrole を照合してから `AXPress` を送る。Dock の実操作は未確認 |
| Accessibility 許可がない場合に許可の案内を表示し、失敗時は項目を安全に無効化する | 一部のみ | 許可なしと失敗後の項目を無効にし、案内文を付ける実装。画面と OS の許可状態は未確認 |
| macOS 15 と 26 で項目の発見と起動を確認する | 未確認 | macOS 15、macOS 26 ともに、この変更の Dock 操作を実機または VM で確認していない |
| 自前のウィンドウ一覧を使う場合は、標準 App Exposé と異なる機能として表示する | 満たした | 単体テストのみ。メニュー項目の名称と実装を分け、「ウィンドウを前面に表示」と「全ウィンドウを表示」を別機能としている |

## 検証

ホストでは指定されたスクリプトで単体テスト、Release ビルド、Debug の build-for-testing を実行する。Dock の GUI 操作やアプリ起動は行わない。

| 項目 | 結果 |
|---|---|
| `swift test` | 339件成功、失敗0 |
| Release ビルド | 成功 |
| `build-for-testing` | 成功 |

## 未検証

- macOS 15 および macOS 26 における Dock の AX ツリー構造と、App Exposé の起動。
- Accessibility 許可を持たない場合の実画面の表示と、許可を与えた後の再試行。
- Dock の自動非表示、起動していないアプリ、複数ウィンドウ、複数ディスプレイ。
- 日本語以外の macOS 言語。未対応言語は実行しない。
- Dock の AX メニューが遅れて現れる場合の動作。

## 撮影の手順

専用ヘッドレス VM または検証用 Mac で行う。ホストでは Dock Studio を起動しない。VM では macOS 15 と 26 の両方を用意し、英語と日本語の言語設定でも確認する。

### 検証用データ

ゲストに `/Users/Shared/dockstudio-118/profiles.json` を置き、次の内容にする。対象アプリの URL は、ゲストに存在するアプリへ合わせる。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Show All Windows demo",
      "items": [
        { "id": "00000000-0000-0000-0000-0000000000a1", "name": "Safari", "kind": "application",
          "target": "file:///Applications/Safari.app/" }
      ]
    }
  ]
}
```

ゲストで Dock Studio を起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-118 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作

1. Safari で複数のウィンドウを開く。標準 Dock に Safari のアイコンがあることを確認する。
2. macOS の「プライバシーとセキュリティ」から Dock Studio に Accessibility を許可する。
3. Custom Dock の Safari アイコンのメニューを開き、「全ウィンドウを表示」を選ぶ。Safari の App Exposé が表示されることを確認する。
4. Dock Studio の Accessibility を許可しない状態でも起動し、メニューに許可の案内が付いた無効な項目が出ることを確認する。
5. Accessibility を許可した状態で、標準 Dock のアプリ項目が存在しないアプリ URL を指定するなどの失敗条件を用意する。操作失敗後、次にメニューを開くと項目が無効になることを確認する。
6. 同じ手順を macOS 15 と 26、日本語と英語の環境で行い、標準 Dock の項目発見と起動結果を記録する。

### 撮るべきもの

| 種類 | 内容 |
|---|---|
| 画像 | Safari のメニューに「全ウィンドウを表示」がある状態 |
| 画像または動画 | メニューを選んで App Exposé が表示されるところ |
| 画像 | Accessibility 許可がない場合の無効な項目と許可案内 |
| 画像 | 実行失敗後に無効化された項目 |
| 記録 | macOS のバージョン、表示言語、Dock の項目発見と実行結果 |
