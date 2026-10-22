# ゴミ箱の左の区切り線を 1 本にする

## 原因

初期のプロファイル（`DockStore.initialDocument()`、`DockStore.swift:1068`）は、項目の末尾にスペーサーを持つ。配置の既定は `.free` なので、`dividerBefore` は空になる。

ゴミ箱の左に並ぶ 2 本は、次の 2 つだった。

| 線 | 場所 | 不透明度 |
| --- | --- | --- |
| 末尾のスペーサーの線 | `CustomDockPreview.swift` の `barElement`（`item.kind == .spacer`） | 0.45 |
| ゴミ箱の前のリサイズ用の線 | `DockIconSizeResize.swift` の `DockIconSizeResizeHandle`、`trashSection` から呼ぶ | 0.55 |

スペーサーは線として描かれ、直後にゴミ箱のリサイズ用の線も必ず描かれるため、隣り合って 2 本になっていた。`dividerBefore` は項目数の位置を含まず、`MinimizedWindowsDockSection` は区切りを描かない。この 2 つは原因ではない。

## 変更内容

- `DockStudio/Services/DockTrashDivider.swift` を追加した。ゴミ箱の直前に出る線の数を決める純粋な関数を持つ。
- 末尾のスペーサーは、線を透明にして描く。幅と高さは変えないので、パネルの寸法計算には影響しない。
- リサイズ用の線とドラッグ操作は変えていない。アプリとフォルダ・ファイルの間の `dividerBefore` の線も変えていない。下配置と左右配置は同じ処理を通る。

## 自動テストの結果

2026-10-22 に実行した。

- `swift test`: `Executed 458 tests, with 0 failures`（`DockTrashDividerTests` は 6 件）
- Release ビルド: `** BUILD SUCCEEDED **`
- `build-for-testing`: `** TEST BUILD SUCCEEDED **`

## 撮影の手順

見た目が変わるため、撮影が必要になる。

1. `DOCKSTUDIO_DATA_DIR` に、空のディレクトリを渡して起動する。初期データが作られ、「仕事」プロファイルが Finder、Safari、メール、ターミナル、Downloads、スペーサーの順になる。
2. 下配置で、ゴミ箱の左を拡大して撮影する。期待する見え方は、線が 1 本になること。
3. 設定で配置を「標準の区分け」にし、同じ場所を撮る。Downloads の前に区切りが 1 本、ゴミ箱の前に 1 本が出る。
4. 位置を左、右に切り替えて、同じ構図で撮る。
5. ゴミ箱の前の線をドラッグして、アイコンサイズが変わる様子を動画で撮る。
6. 撮る画像: 下、左、右の各 1 枚（初期の項目）と、標準の区分けの下配置 1 枚。動画: リサイズ操作 1 本。

## 未検証

- 画面の見た目と、ドラッグ操作は、この担当では確認していない（VM を使っていない）。
- 最小化したウインドウが末尾のスペーサーとゴミ箱の間に並ぶ場合、スペーサーの線は隠れる。この見え方は確認していない。
- 実機の Retina での見え方は確認していない。
