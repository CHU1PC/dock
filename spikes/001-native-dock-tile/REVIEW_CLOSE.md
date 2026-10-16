# レビュー結果

**blocking の指摘はありません。**

Bash が無効だったため `git diff` は実行できず、作業ツリー上の現在のファイルを読んで確認しました。読んだのは `DockAppDelegate.swift`、`NativeDockTileRegressionTests.swift`、`DockStudioApp.swift`、`NativeDockTileController.swift`、`WorkspaceView.swift` です。

## 確認できたこと

- **修正の効果:** `applicationShouldTerminateAfterLastWindowClosed` は、最後のウィンドウを閉じたときの暗黙の終了だけを決めます。`false` を返せば、詳細ウィンドウを閉じてもプロセスは残ります。詳細ウィンドウは `NativeDockTileController.swift:230` で `isReleasedWhenClosed = false` なので、閉じた後に Dock アイコンをクリックすると、`DockAppDelegate.swift:21-25` の `showDetails()` で再表示できます。
- **明示的な終了操作:** Dock メニューの `quit()`（`NativeDockTileController.swift:223`）、メニューバーの「終了」（`WorkspaceView.swift:84`）、Cmd-Q はすべて `NSApplication.terminate` を通ります。したがって `applicationShouldTerminate`（`DockAppDelegate.swift:35-52`）に必ず到達し、保存確認と保存失敗時のキャンセルは変わりません。
- **時計とタイマー:** 終了時の `nativeTile?.stop()` も `applicationWillTerminate` に残っています。

## non-blocking

1. **`DockAppDelegate.swift:27-29`（通常起動への影響）**
   - **根拠:** `tileOnly` を見ずに常に `false` を返すため、通常起動（`--native-dock-tile` なし）でも、Studio ウィンドウを閉じて終了しなくなります。期待動作として確認済みなのは tile-only の詳細ウィンドウだけです。通常起動には `MenuBarExtra` の「終了」と「Dock を管理…」（`DockStudioApp.swift:36`、`WorkspaceView.swift:79-84`）があるので、常駐しても操作に困ることはなさそうです。ただし、頼まれた範囲外の挙動変更であることは確かです。
   - **修正案:** 通常起動でも常駐させるなら、このままで構いません。tile-only だけに限定するなら `tileOnly` を使って分岐させ、テストも2ケースの期待値を分けてください。
2. **`NativeDockTileRegressionTests.swift:8-14`（テストの強さ）**
   - **根拠:** このテストはデリゲートメソッドの戻り値が `false` だと確認するだけで、実際にウィンドウを閉じたときの挙動は検証していません。今回の不具合は AXCloseButton を押す実機操作で見つかったものなので、メソッドが呼ばれなくなる変更や SwiftUI 側の挙動変更は、このテストでは検出できません。
   - **修正案:** 現状でも回帰防止として最低限の役には立つので、このままで構いません。実機での再確認（`windowCount=1, appAliveAfterClose=true`）をテスト結果とは別に記録しておくと確実です。

以上で終了します。
