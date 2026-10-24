# DockMetrics の値入力への分離

Core Animation 移行計画の 3.2 節と PR B（issue #230）にあたる変更である。見た目と挙動は変えない。

## 変更内容

- `DockStudio/Services/DockMetricsInput.swift` に値型 `DockMetricsInput` を追加した。
- `DockMetricsInput(store:)` が、`DockMetrics` の各関数が `DockStore` から読んでいた値を 1 回だけ取り出す。
- `DockStudio/CustomDockPreview.swift` の `DockMetrics` の関数ごとに、`DockMetricsInput` を取る同名のオーバーロードを追加した。
- 既存の `for store:` 版は、入力を作ってオーバーロードを呼ぶだけの薄いラッパーにした。計算式は入力版へそのまま移した。

## DockMetricsInput の項目

| 項目 | 元の読み取り元 |
|---|---|
| kinds | `store.displayedLayout.items` の種別 |
| dividerBefore | `store.displayedLayout.dividerBefore` |
| position | `store.document.settings.position` |
| effectiveIconSize | `store.effectiveIconSize` |
| background | `store.appearance.background` |
| magnification | `store.appearance.magnification` |
| magnificationScale | `store.appearance.magnificationScale` |
| minimizedSlots | `store.minimizedWindowController.state.reservedSlots` |

項目の種別だけが計算に使われるため、`DockItem` 全体ではなく `DockItemKind` の配列を持つ。

## 自動テスト

`DockStudioTests/DockMetricsInputTests.swift` が、次の組み合わせで store 版と入力版の結果が等しいことを確かめる。

- 配置は bottom、left、right。アイコンサイズは 16、52、128。
- 背景は system と appleDock。倍率は有効と無効、倍率の最大値は 1.8。
- 項目は、空、spacer と clock を含む自由配置、区切り線が出る standardSections の 3 通り。
- `magnificationEnabled` の上書きは nil、true、false。`availableLength` と `forceFit` も振る。

既存テストは無改造で通る。

## 未検証

- 画面での確認は行っていない。この変更は値の取り出し方だけを変え、描画には触れていない。
- 入力版を呼ぶ新しい呼び出し元（レイヤー版）は、このPRにはまだ無い。
