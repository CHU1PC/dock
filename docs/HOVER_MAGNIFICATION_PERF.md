# ホバー拡大中の Dock の動きが重い（#226）

## 症状

実機の画面収録（`report/Recording 2026-10-22 at 13.06.08.mp4`）で、ポインタを動かしても拡大が約1秒遅れて追従する。標準 Dock では起きない。

## 原因

`DockBar.body`（`DockStudio/CustomDockPreview.swift:136`）は、ホバーする項目が変わるたびに再評価される。`hovered` は `@State` で、`.animation(motion, value: hovered)`（同 206行）が付いている。

この再評価の中で、メインスレッド上の次の計算が毎回走っていた。

| 場所 | 内容 |
| --- | --- |
| `DockStore.swift` の `displayedLayout` | 固定項目、実行中アプリ、最近使ったアプリを毎回組み直す。各項目で `applicationIdentity` を2〜3回呼ぶ |
| `DockDocument.swift` の `DockItem.applicationIdentity` | 呼ぶたびに `standardizedFileURL.resolvingSymlinksInPath()` と `Bundle(url:)` を実行する |
| `CustomDockPreview.swift:140` | 実行中アプリ全件の `applicationIdentity` で Set を毎回作る |
| `CustomDockPreview.swift:116-123`、`1273-1297` | 背景の長さの計算が `displayedLayout` と `displayedItems` をさらに呼ぶ |
| `CustomDockPreview.swift:345`、`349` | 項目ごとに `applicationIdentity` を呼ぶ |

`displayedLayout` と `displayedItems` は1回の再評価で約10回呼ばれる。項目が増えるほど（固定20件、実行中30件など）、メインスレッドが数ms から10ms 近く塞がる。スプリングアニメーションは再評価のたびに目標値が変わるため、メインスレッドが遅れると拡大が後追いになる。

次の候補は、読んで原因ではないと判断した。

| 候補 | 判断 |
| --- | --- |
| ホバーごとのウィンドウのリサイズ | しない。`CustomDockWindowController.update()`（同 367行）は store の変更だけで呼ばれ、`hovered` は store にない。`DockMetrics.length` と `thickness` は拡大の最大値で固定の予約幅を取り、ホバー位置に依存しない |
| 背景の長さ（`backdropLength`）の二重評価 | `maxWidth` と `maxHeight` の三項演算で片方だけが評価される。1回のみ |
| アイコン画像の生成 | `DockIconRenderer.image` は `NSCache` で保持する。原寸のスタイルは再生成しない |
| AX の読み取り | `NotificationBadgeReader` は `Task.detached` で2秒ごと。メインスレッドを塞がない |

## 修正

| ファイル | 内容 |
| --- | --- |
| `DockStudio/Services/DisplayedLayoutCache.swift`（新規） | 入力（固定項目、実行中、最近、関連設定）が等しく、1秒未満なら前回の結果を返す |
| `DockStudio/Store/DockStore.swift` | `displayedLayout` が上のキャッシュを通る。入力を毎回読むので、Observation の依存は変わらない |
| `DockStudio/Services/ApplicationIdentityCache.swift`（新規） | `applicationIdentity` の結果を、target と bundleIdentifier ごとに1秒保持する。512件で全消去する |
| `DockStudio/Models/DockDocument.swift` | `applicationIdentity` がキャッシュを通る。解決ロジックは `resolveApplicationIdentity()` に移しただけで変更なし |

見た目、アニメーション、ウィンドウの大きさは変えていない。`CustomDockPreview.swift` は変更していない。

## 計測

ホストでの純粋な計算の計測になる。GUI は使っていない。`DockStudioTests/HoverPerformanceTests.swift` の `testReportHoverRecomputeCost` が、`DockBar.body` が1回のホバーで呼ぶ計算（`displayedLayout`、実行中の Set、`DockMetrics` の長さと背景、項目ごとの `applicationIdentity` 2回）を、同じ呼び出し回数で再現する。固定20件、実行中30件（`/Applications` の実アプリ）、下配置、拡大1.8倍。

```
swift test --filter testReportHoverRecomputeCost
```

| 項目 | 修正前（3回） | 修正後（3回） |
| --- | --- | --- |
| ホバー1回の再計算 | 7.65、7.95、7.06 ms | 0.52、0.26、0.25 ms |
| `displayedLayout` 1回 | 0.74、0.88、0.78 ms | 0.0085、0.0007、0.0007 ms |
| `applicationIdentity` 1回 | 0.010、0.009、0.010 ms | 0.0008、0.0004、0.0003 ms |

修正前の別の1回では、ホバー1回の再計算が10.1 ms だった。これは60fps の1フレーム（16.7 ms）の半分以上にあたる。修正後は約0.3 ms になった（約25〜30倍）。

## VM でのプロファイル（修正前）

VM で、60 Hz のポインタ往復中に Dock Studio のメインスレッドを計測した（生データは `/private/tmp/cw/m226/profile/` の `an-mag-on.txt`、`an-mag-off.txt`、`an-idle-mag-on.txt`、`mag-on-app.txt`）。

| 項目 | 結果 |
| --- | --- |
| Dock Studio のメインスレッド | 約99% 稼働 |
| 標準 Dock の CPU | 約3〜5% |
| 拡大をオフにした場合 | 同じく約80% CPU。拡大そのものは原因ではない |
| 支配的な処理 | ホバー変更のたびに `DockBar.body` が約23項目すべてで再評価される（`NSHostingView.layout`、`ViewGraphRootValueUpdater.render`、`GraphHost.flushTransactions` 73%、`ViewGraph.updateOutputs` 21%） |

ホットスポットは次の3つ。

| 場所 | 内容 |
| --- | --- |
| `.accessibilityActions`（`CustomDockPreview.swift`） | 項目ごとの body で `store.applicationWindowListing(for:)` を実行。`NSRunningApplication.runningApplications(withBundleIdentifier:)`、`isTerminated`（LaunchServices への同期 XPC）、`AXIsProcessTrustedWithOptions`（プロンプト付き）が毎回走る。566 サンプル（メインの17%）。`actions(for:)` も 157 サンプル |
| `DockItem.targetURL` | 既定引数 `Self.downloadsDirectoryURL()` が毎回評価される。89 サンプル |
| `DockBar` 全体 | ホバー位置が変わるたび、全項目の内容が再構築される |

## 第2段の修正

| 項目 | 内容 |
| --- | --- |
| アクセシビリティアクションとコンテキストメニュー | 内容を `DockItemAccessibilityActionsContent`、`DockItemContextMenuContent`（`DockStudio/DockItemMenuViews.swift`、新規）に移した。`actions(for:)` とウィンドウ一覧の取得は、これらの body の中でだけ実行される。`DockBar.body` は構造体を作るだけになる |
| ウィンドウ一覧のプロンプト | `ApplicationWindowProviding.windows(for:promptForAccess:)` を追加。アクセシビリティアクション側は `promptForAccess: false`（描画経路でプロンプトを出さない）。コンテキストメニューと NSMenu は従来どおり `true` |
| `DockItem.resolvedTargetURL` | `downloadsDirectory` を `@autoclosure` にし、Downloads の項目のときだけ `FileManager` を呼ぶ。引数に値を渡す既存の呼び出しは変更なし |
| 2秒ごとの更新 | `refreshNotificationBadges()` は値が等しければ代入しない。`MinimizedWindowController.refresh()` は `MinimizedWindowState.isEquivalent(to:)` で同じなら代入しない（比較は id、アプリ識別子、タイトル、アプリ名。アイコンは比較しない）。ゴミ箱は `refreshTrash()` が既に `!=` で守っていたので変更なし |

項目 (c)（ホバーが小さなラッパーだけを動かし、重い内容は項目データだけに依存するサブビューにする）は、アクセシビリティとコンテキストメニューの分離までにとどめた。アイコン、バッジ、ドラッグ修飾子は `dockItem` の中に残している。`fix/remove-running-dot`（#227）が同じ `dockItem` の VStack を編集するため、衝突を避けた。

## 自動テスト

```
swift test --scratch-path /tmp/dockstudio-226-scratch   # 489 tests, 0 failures
xcodebuild ... -configuration Release build              # BUILD SUCCEEDED
xcodebuild ... build-for-testing                         # TEST BUILD SUCCEEDED
```

追加したテスト: `testDownloadsDirectoryIsEvaluatedOnlyForTheDownloadsLocation`（Downloads 以外では評価されない）、`testAccessibilityListingNeverPromptsForPermission`（`promptForAccess` の伝達）、`MinimizedWindowStateTests`（同値判定）。

## 未検証の項目

- **第2段の修正で CPU 使用率とフレーム時間が下がったかは未検証。** VM で再プロファイルするまで分からない。
- **SwiftUI が `.accessibilityActions` の内容（サブビュー）を、VoiceOver が無効のときに評価しないかは未検証。** 評価する場合は、効果が小さい（ただしプロンプトは出なくなった）。
- VoiceOver が有効なときに、アクションの一覧とウィンドウの切り替えが従来どおり出るかは未検証。サブビューを `.accessibilityActions` に入れた場合に SwiftUI が展開するかの確認が要る。
- コンテキストメニューが従来どおり出るか、ウィンドウ一覧が出るかは未検証（GUI を使っていない）。
- 項目 (c) の本体（ホバーで動く部分の局所化）は未着手。再プロファイルで `DockBar.body` の再評価が残っていれば、次に行う。
- 第1段のキャッシュの寿命は1秒。アプリのバンドル識別子がディスク上で変わると、最大1秒遅れて反映される。
- グローバルのマウス監視（`CustomDockWindowController.swift:254`）は、マウスイベントごとに `selectedScreen` を数回評価する。実測していない。

## 撮影の手順

この修正は見た目を変えない。確認する場合は、修正前後のビルドで次を撮る。

1. `DOCKSTUDIO_DATA_DIR` に、固定のアプリ20件以上、実行中のアプリ20件以上、拡大を有効にした検証用データを渡して起動する。
2. ゲストで、Dock の上をポインタで左右に素早く往復させる。
3. 期待する見え方: 拡大がポインタの下のアイコンに遅れず追従する。
4. 撮るもの: 修正前後それぞれ、往復の動画（10秒程度）と、可能なら Activity Monitor の CPU 使用率。
