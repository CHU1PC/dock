# アクセシビリティ注記と Dock パネルの配置

GitHub issue #182 の注記レイアウトを修正した。

## 変更内容

通知バッジのためのアクセシビリティ許可がなく、プロファイルにアプリが含まれる場合、デスクトップ用 Dock パネルでは注記を Dock 項目の列から分離して表示する。パネルのサイズには注記分の高さを加え、注記がゴミ箱の位置を押し出さないようにする。注記の文言とシステム設定へのリンクは維持した。管理画面のプレビュー表示は従来のままにした。

標準 Dock の「Show All Windows」を開く操作は、既存の `ApplicationExpose` が Accessibility を使って標準 Dock のメニューを開き、対象アプリの「Show All Windows」を選ぶ。調査資料で実行可能と確認された経路を使う既存実装であり、キー入力の合成や非公開 API は追加していない。

## 仕様判断

- パネルの注記は Dock の項目列の外、項目列の上に置く。項目の順序とゴミ箱の位置は変えない。
- パネルのサイズ計算は `DockPanelSizing` にまとめ、許可状態と表示項目から注記の有無を判定する。
- 注記を表示する場合は、パネルに注記の高さと間隔を足す。下配置では Dock の横幅を変えず、左右配置ではパネルの高さに注記分を含める。
- App Exposé は標準 Dock の Accessibility メニュー操作を使う。Accessibility の許可がない場合は既存のメニュー項目を無効表示する。

## 受け入れ条件との対応

| 条件 | 状況 | 根拠 |
|---|---|---|
| Accessibility 許可がなくてもゴミ箱をパネル内に表示する | 一部のみ | 注記分を Dock 項目列から分離し、パネルサイズ計算に加えることを単体テストで確認した。実画面の位置は未確認 |
| Custom Dock から標準 Dock の「Show All Windows」を呼び出す | 一部のみ | 既存の `ApplicationExpose` が標準 Dock のメニュー操作を行い、単体テストで許可状態と呼び出し先 URL の受け渡しを確認した。標準 Dock の操作は未確認 |

## 自動テスト

指定の `/private/tmp/cw/run-check.sh` を使って確認した。

| 項目 | 結果 |
|---|---|
| `swift test` | 400件を実行し、失敗 0 件 |
| Release ビルド | BUILD SUCCEEDED |
| Debug の `build-for-testing` | TEST BUILD SUCCEEDED |

## 未検証

- Accessibility 許可を外した状態で、実画面のゴミ箱がパネル内に表示され、ドロップと右クリックの対象になること。
- 長いプロファイル、左右配置、異なるアイコンサイズでの表示。
- 標準 Dock の「Show All Windows」メニュー操作と、App Exposé の画面表示。
- macOS 15 での描画と Accessibility の差分。

## 撮影の手順

確認を行う場合は、専用ヘッドレス macOS VM のゲストを使う。ホストには Dock Studio を表示しない。

### 検証用データ

ゲストで `/Users/Shared/dock-182` を作り、`profiles.json` に次の内容を保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 52, "autoHide": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Accessibility notice",
      "items": [
        { "id": "00000000-0000-0000-0000-0000000000a1", "name": "TextEdit", "kind": "application", "target": "file:///System/Applications/TextEdit.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a2", "name": "Downloads", "kind": "folder", "target": "file:///Users/Shared/" }
      ]
    }
  ]
}
```

Dock Studio を `DOCKSTUDIO_DATA_DIR=/Users/Shared/dock-182` で起動し、システム設定で Dock Studio の Accessibility 許可を無効にする。

### 操作と期待結果

1. 管理ウィンドウを「設定」タブにし、下配置の Custom Dock パネルを表示する。
2. 注記が項目列の上にあり、ゴミ箱が同じ列の末尾でパネル内に収まることを確認する。
3. ファイルをゴミ箱へドラッグし、ゴミ箱の右クリックメニューも開く。
4. Accessibility 許可を戻し、アプリ項目のメニューから「全ウィンドウを表示」を選ぶ。標準 Dock のメニューと App Exposé の動作を記録する。
5. ゴミ箱と注記が見える静止画、ドラッグの動画、App Exposé を開く動画を保存する。
