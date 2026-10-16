レビューは終わりました。調べ方と判定をまとめます。ファイルは編集していません。

## 判定
**重大・高の問題はありませんでした。** ただし、受け入れ条件に直接かかわる「中」が2件あります。Dock タイル表示、メモリ専用ストア、標準 Dock 設定に触れない点には問題を見つけていません。

## 観測した問題（コードと生成物から確認）

**[中] 通常起動でも Dock タイルが有効になる**
- `DockAppDelegate.swift:8-13` は `tileOnly` を見ずに `NativeDockTileController` を起動します。
- 再現条件は、`--native-dock-tile` なしで通常起動することです。アプリアイコンが描画タイルに置き換わり、Dock メニューも差し替わります。
- さらに 1 秒ごとの `tile.display()`（`NativeDockTileController.swift:119-123`）が常時走ります。
- 「通常起動は既存の管理 UI の挙動を保つ」という目標とは、管理ウィンドウについては整合しています。Dock アイコンまで変わる点が意図どおりかは確認が必要です。
- 意図でなければ `tileOnly` で有効化を絞ってください。
- 通常起動では永続ストアなので、タイルメニューからのプロファイル切替が `profiles.json` を書き換えます。これは意図どおりか確認してください。

**[中] `--native-dock-tile` では「既存プロファイルの選択」が成立していない**
- `DockStudioApp.swift:15` は `persistence: nil` を渡します。ストアは `DockStore.initialDocument()`（`DockStore.swift:423`）の仮データ（仕事・プライベート）になり、ユーザーの既存プロファイルは出ません。
- `NativeDockTileController.swift:137-141` のサブメニューにも、その仮データが並びます。
- 項目の選択は `activateProfile` でメモリ上の `activeProfileID` を変えるだけです。
- `CustomDockWindowController` は `DockStudioApp.swift:26-29` の `.task` でしか生成されません。ウィンドウを suppress すると `.task` は走らないはずなので、選んでも Custom Dock に何も起きない可能性が高いです。
- この `.task` の件は仮説です。ライブ確認が必要です。
- 「メモリ専用」と「既存プロファイルを選ぶ」は、現在の実装では両立していません。

**[低] 古い `errorMessage` で誤ったアラートが出る**
- `NativeDockTileController.swift:166-172` は切替後に `store.errorMessage` が非 nil ならアラートを出します。切替前にクリアしていません。
- 再現条件は、事前にアプリ起動失敗などで `errorMessage` が残っている状態で、プロファイル切替に成功することです。成功したのに無関係なエラーが表示されます。
- アラート後も `errorMessage` を消さないため、メイン UI 側と二重表示になる可能性があります。この二重表示は仮説です。
- 切替前に nil にするか、`activateProfile` の戻り値や状態で判定する形が安全です。

**[低] 「一時停止」が未開始の 25:00 にも出る**
- `NativeDockTileController.swift:16` は、未開始のとき `deadline == nil && seconds > 0` で「一時停止」を返します。
- 再現条件は、起動直後に集中タイマー表示へ切り替えることです。「待機」などが適切です。

**[低] スクリーンショットが実際のタイル形状ではない**
- `Capture.swift:12-22` は `window.contentView = view` で 128×128 のビューを 320×290 に引き伸ばします。
- 実測で `clock.png` と `timer.png` は 640×580 でした。実機の正方形タイルではなく、約 2.27 倍に拡大され、中央に置かれています。
- 画像の見た目は良好です。ただし実機の Dock での縮小時の可読性は証明できません。
- プロジェクトの `CLAUDE.md` は、変更後の実画面の撮影を PR に求めています。オフスクリーン描画は代替になりません。ライブ Dock での撮影が必要です。

**[低] `capture.sh` の堅牢性**
- `capture.sh` は `rg` に依存しています。未導入だと `source_files` が空になり、swiftc のエラーが分かりにくくなります。`find` か glob で足ります。
- `mktemp -d` のビルドディレクトリは削除されません。
- 既定の出力先がリポジトリ内の `docs/media/` なので、実行するだけで追跡対象を書き換えます。
- `spikes/001-native-dock-tile/README.md` の進捗は「実装中」のままです。

## 仮説（ライブテストが必要）
- **タイマーの遅延**: アプリが背景のとき、App Nap やタイマー合体で 1 秒更新が遅れる、または止まる可能性があります。`Timer` は `.common` モードで登録済みなので、メニュー表示中の更新は問題ないはずです。
- **メニューの古い表示**: `makeMenu()` は表示時点のスナップショットです（`NativeDockTileController.swift:125-150`）。メニューを開いている間にタイマーが完了すると、「一時停止」などのラベルが古いままになります。
- **メニューバー項目の残存**: `MenuBarExtra`（`DockStudioApp.swift:34`）は tile-only でも表示されます。意図どおりか確認してください。
- **ウィンドウの強参照**: `NativeDockTileController` が `detailWindow` を、その `NSHostingView` が controller を強参照します。解除は `stop()` のみです。終了時のみなので実害は小さいです。
- **API の非推奨**: `activate(ignoringOtherApps:)`（`NativeDockTileController.swift:187`）は macOS 14 以降で非推奨です。警告のみで、動作には影響しません。

## テストの穴
- 追加テスト 4 件は `NativeDockTileState` の状態遷移だけです。
- 次の 4 点は未検証です。
  - `--native-dock-tile` でメモリ専用になること。
  - `makeMenu` の内容。
  - `stop()` の後始末。
  - プロファイル切替のエラー経路。
- 試作の範囲としては許容できます。ただし上の 2 件の「中」は、ここが検証されていないことが原因です。

## セキュリティ
問題はありません。追加コードは標準 Dock の plist も `defaults` も書きません。tile-only では `persistence == nil` なので `commit` が何も保存しません。`restoreDrafts` と `saveDrafts` も `persistence?` ガード済みで、ディスクには触れません。
