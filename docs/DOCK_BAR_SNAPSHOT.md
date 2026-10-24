# DockBarSnapshot

Core Animation 移行（計画の PR C）の準備として、Dock バーの描画に必要な値を不変の値型にまとめる。旧 SwiftUI の `DockBar` は変更していない。`DockStore.swift` と `CustomDockPreview.swift` も変更していない。

## 追加したもの

- `DockStudio/Services/DockBarSnapshot.swift`
  - `DockBarSnapshot`（`Equatable`）: 項目の配列、ゴミ箱、配置、外観、表示アイコンサイズ、最大アイコンサイズ、倍率の有効状態、reduceMotion。
  - `DockBarSnapshot.Item`: id、種別、表示名、アイコンキー、`dividerBefore`、実行中、バッジ、可用性、バウンス中、注意要求。
  - `DockBarSnapshot.Trash`: 状態と、ゴミ箱の直前に区切りがあるか。
  - `DockBarSnapshotBuilder.make(store:availableLength:magnificationEnabled:forceFit:systemReduceMotion:)`: `DockStore` を読むだけの `@MainActor` の関数。
- `DockStudioTests/DockBarSnapshotTests.swift`

## 旧 DockBar との対応

| スナップショットの値 | 旧 DockBar の式 |
|---|---|
| 項目の並びと種別 | `store.displayedLayout.items` |
| `dividerBefore` | `displayedLayout.dividerBefore.contains(index)` |
| `isRunning` | `applicationIdentity` が `runningItems` の identity に含まれる |
| `badge` | `NotificationBadgeSnapshot.badge(for:in: store.notificationBadges)` |
| `isBouncing` | `launchBounce` かつ `launchingItemIDs` に含まれ、reduceMotion でない |
| `isAttentionRequested` | `attentionBounce` かつ identity が `attentionRequestingIdentities` に含まれる |
| `iconSize` | `DockMetrics.effectiveIconSize(for:availableLength:magnificationEnabled:forceFit:)` |

## applicationIdentity の計算回数

ビルダーは `layout.items` の各項目に対して `applicationIdentity` を 1 回だけ計算し、実行中と注意要求の両方に使い回す。ただし、次の 2 つは今回触っていない既存の呼び出しで、`applicationIdentity` を別に計算する。

- `store.displayedLayout`（`DockStore` 内部で pinned、running の identity を計算する）
- `Set(store.runningItems.compactMap(\.applicationIdentity))`（実行中アプリの数だけ）

`displayedLayout` 内の重複を除くには `DockStore.swift` の変更が要るため、この PR では行っていない。

## 自動テスト

`swift test --filter DockBarSnapshotTests`: 6 件成功。標準セクション、自由配置、実行中の表示設定、バッジ、実行中アプリの表示、注意要求とサイズの各 fixture で、`displayedLayout` と既存の式に一致することを確かめている。

## 未検証

- 画面への表示と、旧 `DockBar` との見た目の一致（この PR はビルダーだけで、描画に使っていない）。
- ビルダーのコスト測定。
