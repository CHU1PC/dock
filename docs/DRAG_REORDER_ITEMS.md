# Dock 上のドラッグで項目を並べ替える

GitHub issue #9 の実装になる。

## 変更内容

Custom Dock の項目をつかんで Dock 内へ動かすと、挿入位置を示す線を表示する。Dock 内で離したときだけ、新しい順序を保存する。Dock の外で離す操作は既存の取り外し処理へ渡し、Esc でキャンセルした場合や保存に失敗した場合は、保存済みの順序を変えない。

新しい順序の計算は `DockItemReordering` の純粋関数で行う。実行中アプリや最近使った項目の位置を保存済みの順序へ取り込まず、区切り線をまたぐ挿入位置は同じ区画内に制限する。

標準 Dock の App Exposé は既存のアプリ項目メニューから呼び出せる。既存の `ApplicationExpose.swift` は調査で実行可能とされた標準 Dock の Accessibility メニュー操作を使う。

## 仕様の決定

- ドラッグ中は Dock の順序を変更せず、ドロップ時に新しい順序を一度だけ保存する。
- 挿入位置はドラッグ元を除いた表示項目を基準に計算し、表示中の区画を越えないようにする。
- 保存は既存の `DockStore.commit` を通す。保存が失敗した場合は候補の順序を反映しない。
- Dock 外へのドラッグ、ファイルの Dock へのドロップ、Option と矢印キーでの並べ替え、Esc キャンセルの既存処理を維持する。
- App Exposé は公開 API やキー入力の合成ではなく、標準 Dock の「Show All Windows」を Accessibility で選ぶ既存経路を使う。

## 受け入れ条件との対応

| 条件 | 状況 | 根拠 |
|---|---|---|
| ドラッグ中に挿入位置を表示し、確定後に順番を保存する | 一部のみ | 挿入インデックスの純粋関数と保存後の再読み込みを単体テストで確認した。インジケーターと実際のドラッグは未確認 |
| 左右と下の配置、スクロール、実行中アプリとの境界で確認する | 一部のみ | 実行中項目の区画を越えず、保存済み項目だけを順序変更に使うことを単体テストで確認した。各配置とスクロールの画面動作は未確認 |
| キャンセル時と保存失敗時に元の順番を保持する | 一部のみ | 保存失敗時に元の順序が残ることを単体テストで確認した。Esc を含む画面上のキャンセル操作は未確認 |

## 自動テスト

ホストでは `/private/tmp/cw/run-check.sh` を使ってテストとビルドを実行した。アプリは起動していない。

| 項目 | 結果 |
|---|---|
| `swift test` | 379件成功、失敗0 |
| Release ビルド | `BUILD SUCCEEDED` |
| `build-for-testing` | `TEST BUILD SUCCEEDED` |

追加した単体テストでは、先頭と末尾への移動、同じ位置へのドロップ、実行中と最近使った項目の区画境界、保存後の再読み込み、保存失敗時に順序を維持することを確認する。

## 未検証

- 実画面の挿入線、左右と下の配置、スクロール中のドラッグ、ドロップ結果。
- Esc キャンセルを含むドラッグ操作と、Dock 外への既存の取り外し操作との画面上の共存。
- macOS 15 での描画と Accessibility の動作。
- 標準 Dock の App Exposé 操作は、今回の変更で再確認していない。

## 撮影の手順

撮影を行う場合は、専用ヘッドレス macOS VM のゲストで実施する。普段使うホストではアプリを起動しない。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-9/profiles.json` に次の内容を保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": false,
    "showRunningApps": true,
    "showRecentApps": true
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Drag reorder demo",
      "items": [
        { "id": "00000000-0000-0000-0000-0000000000a1", "name": "Calculator", "kind": "application", "target": "file:///System/Applications/Calculator.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a2", "name": "TextEdit", "kind": "application", "target": "file:///System/Applications/TextEdit.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a3", "name": "Notes", "kind": "application", "target": "file:///System/Applications/Notes.app/" }
      ]
    }
  ]
}
```

ゲストで Release ビルドを起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-9 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待結果

1. Dock の下配置で Calculator を TextEdit の右へドラッグし、挿入線を確認して離す。順序が変わり、アプリを再起動しても順序が残る。
2. Calculator をドラッグして元の位置で離す。順序は変わらない。
3. 項目をつかんで Dock の外へドラッグする。既存の取り外し表示が出て、離すと従来どおり取り外される。
4. 実行中アプリと最近使った項目が表示される設定にし、挿入線が区画を越えず、保存順に動的項目が入らないことを確認する。
5. Dock の位置を左と右に切り替えて、同じ操作を繰り返す。項目がスクロールする長さまで増やして、スクロール中も挿入線と保存順を確認する。

### 撮影するもの

- 画像: Dock 内でドラッグ中に挿入線が見える状態。
- 動画: 項目を動かして離し、再起動後も順序が保存されているところ。
- 動画: Esc キャンセルと Dock 外へのドラッグで、項目の順序または存在が保たれるところ。
- 画像または動画: 左配置、右配置、スクロール中、実行中アプリとの区画境界。
