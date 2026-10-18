# ドラッグ中の Esc で取り外しをキャンセルする

GitHub issue #87 の実装になる。

## 変更内容

Custom Dock の項目を外へドラッグして取り外すとき、ドラッグ中に Esc を押すと取り外しをキャンセルする。Esc を受け取った時点で項目の移動と「取り外す」の予告表示を消し、その後 Dock の外でボタンを離しても項目を残す。

Esc の監視は Dock Studio 内のローカルキーイベントに限る。ドラッグ中以外は Esc を消費せず、従来のキー操作を続ける。標準 Dock のドラッグ処理と OS やほかのアプリのキー入力には介入しない。

## 仕様の決定

- Esc のキーコードを受け取り、Custom Dock のドラッグ状態が有効な場合だけキャンセル状態にする。
- キャンセル状態はドラッグ終了時に解除する。
- 標準 Dock の動作は macOS 側の機能として専用 VM で確認する。アプリから標準 Dock のキー入力を監視しない。
- `DockDragOutCancellation` の状態遷移を単体テストで確認する。

## 自動テスト

実装完了後に、`swift test`、Release ビルド、Debug の `build-for-testing` を実行し、結果を記録する。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 239 件すべて成功した |
| Release ビルド | 成功した（`BUILD SUCCEEDED`） |
| `build-for-testing` | 成功した（`TEST BUILD SUCCEEDED`） |

追加した単体テストは、ドラッグ中でない Esc を無視すること、ドラッグ中の Esc がキャンセル状態となること、Esc なしの終了ではキャンセル扱いにならないことを確認する。

## 未検証

- 標準 Dock でのドラッグと Esc によるキャンセルは、専用ヘッドレス VM で確認する。
- Custom Dock の見た目と実際のドラッグ操作は、専用ヘッドレス VM で撮影して確認する。
- macOS 15 以降のバージョン差は未確認である。

## 撮影の手順

専用ヘッドレス VM のゲストで実行し、ホストではアプリを起動しない。VM のゲストに Release ビルドの `DockStudio.app` を配置し、次の `profiles.json` を `/Users/Shared/dockstudio-87/profiles.json` に保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": false,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Esc cancel demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-0000000000a1",
          "name": "Calculator",
          "kind": "application",
          "target": "file:///System/Applications/Calculator.app/"
        }
      ]
    }
  ]
}
```

ゲストで `DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-87 /path/to/DockStudio.app/Contents/MacOS/DockStudio` を実行して起動する。

### 操作と期待結果

1. Custom Dock の Calculator をつかみ、Dock の外へドラッグする。「取り外す」の予告が出ることを確認する。
2. ドラッグを続けたまま Esc を押す。項目の移動と「取り外す」の予告が消える。
3. Dock の外でドラッグを離す。Calculator が Dock に残る。
4. 比較のため、標準 Dock に Calculator を置いて外へドラッグし、Esc を押してから外で離す。標準 Dock の項目が元の位置に残ることを確認する。
5. Custom Dock でドラッグをせずに Esc を押し、従来どおり元のアプリへ戻る挙動などが変わっていないことを確認する。

### 撮影するもの

- 画像: Custom Dock で、ドラッグ前と Esc 後に Calculator が残っている状態。
- 動画: 取り外し予告が出た状態から Esc で消え、その後外で離しても項目が残るまで。
- 動画: 標準 Dock で Esc により取り外しをキャンセルし、項目が元の位置に残るまで。
- 画像または動画: ドラッグ中でない Esc の挙動。
