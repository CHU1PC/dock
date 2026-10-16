# GPUI 移行レビュー（origin/main との差分と gpui/ 全体）

## 総括

判定は **差し戻し（要修正）** です。ビルドとテストは実行していません。読み取り専用のレビューで、結論はコードの静読と GPUI 0.2.2 のソースの突き合わせによるものです。

blocking は 4 件（B1〜B4）です。うち B1〜B3 はどのテストにも通っていない経路にあります。画像キャプチャでは `--capture` 時に `set_frame` を飛ばし（`dock.rs:278`）、実デスクトップでは一度も動かしていません。

以下、各指摘に確度を付けます。

- **確認済み**: コードまたは GPUI ソースで根拠を確認した指摘。
- **仮説**: 実機で再現していない指摘。

レビュー中に `bridge.rs`、`state.rs`、`model.rs`、`BridgeMain.swift` が更新されたため、これらは最新版で再確認しました。`.app` 内の helper を探す処理と、flock と旧アプリの検知は追加済みです。この 2 点は指摘に含めていません。

## Blocking

### B1. render 中の `set_frame` で GPUI の `bounds_changed` が落ちる（高、確認済み。見え方は仮説）

- **場所**: `gpui/src/dock.rs:278-287`、`gpui/src/native.rs:44-75`
- **条件**: 実デスクトップでの通常起動です。`DockView::render` が `native::set_frame` を呼ぶと、`setFrame:display:true` が GPUI の NSView の `setFrameSize` を同期的に呼びます。
- **根拠**:
  - `gpui-0.2.2/src/platform/mac/window.rs:2105-2134` で `resize_callback` が呼ばれます。
  - コールバックは `window.rs:1068-1075` で `handle.update(...).log_err()` を実行します。
  - `app/async_context.rs:83-90` の `update_window` は `try_borrow_mut()?` を使います。render は `window.draw(cx)` の内側で App を借用中なので、この更新は失敗してログに落ちるだけです。
- **結果**: `bounds_changed` が一度も反映されません。viewport とレイアウトが古いサイズのまま固定されます。
- **見え方（仮説）**: `size_full` の root が実ウィンドウとずれます。バーの位置と当たり判定領域がずれる可能性があります。
- **修正案**:
  - frame 更新を draw の外に出します。`cx.observe` や `cx.defer` で App レベルから行い、完了後に `window.refresh()` を呼びます。
  - あるいは、拡大時の最大サイズで固定ウィンドウにして、render 中の frame 変更をなくします。
  - 実画面で確認します。`--capture` 分岐（`dock.rs:207`、`278`）が検証を迂回しているので、検証用の経路ではなく本番経路を撮影してください。

### B2. 右クリックメニューのボタンがクリックできない可能性が高い（高、確認済み。実機未確認）

- **場所**: `gpui/src/dock.rs:618-626`、`648-722`、`gpui/src/ui.rs:15-33`
- **条件**: メニューを開いた状態で、メニュー内のボタンを左クリックします。
- **根拠**:
  - root の `on_mouse_down(Left)` が `menu_open=false` にして `notify` します。
  - ボタンの `on_click` は mouse down を記録するだけで、伝播を止めません（`gpui div.rs:2123-2160`）。
  - 次フレームでメニューの要素が消えます。mouse up の時点では listener が存在しないため、クリックが成立しません。
- **結果**: Dock 上から 設定、プロファイル、リセット、隠す、終了 に到達できません。
- **修正案**:
  - メニュー領域に `on_mouse_down(Left, |_, _, cx| cx.stop_propagation())` を付けます。
  - または root 側でメニュー内の位置を判定して、閉じる処理を飛ばします。
  - あるいは、各ボタンの action 内でメニューを閉じるようにします。

### B3. helper が NSAlert と NSOpenPanel を前面化せず、UI が固まる恐れがある（高、仮説）

- **場所**: `gpui/native/BridgeMain.swift:102-103`（delete）、`126-131`（background）、`140-147`（confirm）。`DockStore.chooseItems`、`exportProfiles`、`importProfiles`、`openItem` の確認 alert も同じです。
- **条件**: helper は `.accessory` で起動し、`NSApp.activate` を一度も呼びません（`gpui/native` に `activate` なし）。`runModal` のパネルが他アプリの背面に出る可能性があります。
- **結果**:
  - 対話系の要求はタイムアウトしません（`bridge.rs:65-68`）。パネルが見えないと `busy` が解除されません。
  - `busy` 中は `request()` が黙って破棄します（`state.rs:126-129`）。「下書きを残して終了」も含みます。
  - この場合、強制終了以外に抜ける手段がなくなります。
  - `requiresLaunchConfirmation` の alert は Dock のクリックから出るので、同じ問題が起きます。
- **修正案**:
  - `runModal` の前に `NSApp.activate(ignoringOtherApps: true)` を呼びます。
  - alert の window level を上げます。
  - busy 中でも終了操作を受け付けるようにします。

### B4. 既存機能の欠落: 常駐性とメニューバー項目（高、確認済み）

- **場所**: `gpui/src/main.rs:128-135`
- **変更前の挙動**:
  - `DockStudioApp.swift:30-34` の `MenuBarExtra` と `WorkspaceView.swift:57-86` の `DockMenu` で、アプリがどの状態でもプロファイル切替、Dock の表示と非表示、管理画面を開く、終了ができました。
  - ウィンドウを閉じても Dock は残りました。
  - Dock の `contextMenu`（`CustomDockPreview.swift:16`、`CustomDockWindowController.swift:155-160`）からプロファイルを直接切り替えられました。
- **変更後の挙動**:
  - 管理ウィンドウを閉じると `ask_quit` を呼び、アプリごと終了します。Dock も消えます。
  - メニューバー項目は消えました。
  - アプリメニューの「プロファイル」は、アプリがアクティブな間しか見えません。Dock パネルは nonactivating なので、Dock を使っているときは到達できません。
  - Dock の右クリックにプロファイル一覧がありません。
- **修正案**:
  - ウィンドウを閉じても終了せず隠す動作にします。
  - NSStatusItem を追加します。
  - Dock の右クリックに、プロファイル一覧と選択済みの印を戻します。

## Medium

### M1. 「システム」背景に単色の tint が乗り、不透明度が二重に掛かる（確認済み）

- **場所**: `dock.rs:538-543`、`native.rs:176-178`
- **条件**: 既定値（System、opacity 0.55、color 0x303842）です。
- **結果**: `Transparent` 以外のすべてで `bg(rgba(color<<8 | alpha))` を塗ります。そこに effect view の `setAlphaValue(opacity)` が重なります。システムの素材が 55%×55% の暗色で覆われ、macOS 26 の glass にも見えません。
- **修正案**: System では tint を塗らないか、極薄にします。opacity は片方にだけ掛けます。

### M2. 起動中判定と重複排除が Swift の識別子とずれる（確認済み）

- **場所**: `model.rs:86-109`、`DockDocument.swift:41-49`
- **条件**: ファイル選択で追加したアプリは `bundleIdentifier` が nil です（`DockStore.chooseItems`、`DockStore.swift:303-304`）。
- **結果**:
  - Swift は `standardizedFileURL` と symlink 解決のうえで `bundle:` または `path:` で比較します。
  - Rust は生の `target` 文字列の一致だけで比較します。`path:` 識別子は無視します。
  - 末尾スラッシュや symlink の差で、起動中の点が消えます。「実行中アプリを追加表示」で同じアプリが二重に出ます。
- **修正案**: `store.displayedItems` の結果と、項目ごとの `isRunning` を helper が返します。

### M3. 自アプリが実行中一覧に出る。更新が 5 秒遅れる（確認済み）

- **場所**: `BridgeMain.swift:152-158`、`main.rs:200-211`
- **変更前の挙動**: `CustomDockWindowController.swift:136` が自アプリを除外しました。同 `37-41` が、起動と終了の通知で即時に更新しました。
- **結果**: GPUI 版の `app.dockstudio.gpui` は regular なので、自分自身が出ます。起動中の点は最大 5 秒遅れます。
- **修正案**: 自アプリの bundle id を除外します。軽量な `running` 専用の要求を 1 秒周期にするか、helper から通知を押し出します。

### M4. Web リンクの検証が消えた（確認済み）

- **場所**: `ui.rs:638-641`、`BridgeMain.swift:111`
- **変更前の挙動**: `ProfileEditorPreview.swift:160-181` の `AddLinkSheet` が、名前の非空と http か https とホスト有りを検査し、名前を trim しました。
- **変更後の挙動**:
  - 既定値 `https://` と空の名前がそのまま下書きに入ります。
  - 保存時に `DockDocument.validate`（`DockDocument.swift:127-131`）が失敗します。
  - 「保存して終了」は失敗が続くので、終了できなくなります。不正な下書きが `drafts.json` に残ります。
  - 追加後に入力欄が空になりません。連打すると重複して入ります。
- **修正案**: Swift の `add` 側で同じ規則を適用して trim します。Rust 側でも事前検査し、成功時に入力欄を初期化します。

### M5. 表示先の選択が退行した（確認済み）

- **場所**: `ui.rs:198-212`
- **変更前の挙動**: `SettingsPreview.swift:61-73` に「メインディスプレイ」（nil）と「未接続のディスプレイ」の選択肢がありました。
- **結果**:
  - 一度ディスプレイを選ぶと、「メインに追従」に戻せません。
  - 保存済みの id が未接続だと、何も選択されていないように見えます。
  - 変更前は `didChangeScreenParameters` で即時に更新しました。新版は 5 秒のポーリングです。切断から最大 5 秒、存在しない画面へ配置します。
- **修正案**: nil の選択肢と、未接続の表示を戻します。

### M6. `status` が一度も表示されない（確認済み）

- **場所**: `ui.rs` に `snapshot.status` の参照がありません。
- **変更前の挙動**: 保存、書き出し、取り込みの成功メッセージを表示しました。
- **結果**:
  - 成功の通知が出ません。
  - 「前回の未保存の編集内容を復元しました」（`DockStore.swift:240`）も出ません。データ復旧の通知が失われます。
- **修正案**: プロファイル編集画面と設定画面の下部に表示します。

### M7. ポーリングが入力欄を無効化し、操作を破棄する（確認済み）

- **場所**: `state.rs:126-139`、`text_input.rs:318`、`343`
- **条件**: 5 秒ごとの `poll` でも `busy=true` になり、名前入力が `enabled=false` になります。
- **結果**:
  - その間の `replace_text_in_range` と `replace_and_mark_text_in_range` は return します。日本語 IME の変換中の文字を落とす恐れがあります。
  - その間のクリックも、`request()` が黙って破棄します。
- **修正案**: ポーリングでは `busy` を立てず、入力欄を無効化しません。ユーザー操作は破棄せず、キューに積みます。

### M8. 自動非表示の初期状態が誤る（確認済み）

- **場所**: `dock.rs:95`、`219-226`
- **条件**: `last_interaction` は `DockView` の生成時刻です。自動非表示がオンで、起動から 1 秒以上経ってから「Dock を表示」を押します。
- **結果**: 直ちに `collapsed` になり、8px の帯しか出ません。
- **変更前の挙動**: `DockVisibilityState.swift:11-12` は、可視化の立ち上がりで折りたたみを解除しました。
- **修正案**: `dock_visible` が false から true になったときに `last_interaction` をリセットします。

### M9. 右クリックメニューの位置と見切れ（確認済み。見え方は仮説）

- **場所**: `dock.rs:659-721`
- **条件**: メニューはウィンドウの右上に固定され、root は `overflow_hidden` です。
- **結果**: 項目が少ないと、ウィンドウ幅や高さが最小 120 に近くなります。ボタン 5 つが見切れます。ポインタ位置にも出ません。
- **修正案**: ポインタ付近に出し、サイズに合わせて向きを変えます。

### M10. ロック、旧アプリ検知時の表示と挙動が不整合

- **確認済み**:
  - `ui.rs:716` のバナーは「設定を読み込めない」の文言のままです。ロックと旧アプリが原因でも同じ文言が出ます。
  - `state.rs:195-200` の外観の保存拒否メッセージも、同じ状況で誤解を招きます。
  - `BridgeMain.swift:79-82` では `retry` が許可リストにありません。「読み込み直す」が効かず、エラーが 5 秒ごとに再表示されます。
- **仮説**: `legacyIsRunning` は bundle id `app.dockstudio.preview` だけを見ます。id を持たない `swift run` 版は検知できません。
- **修正案**: 原因別の文言にします。`retry` を許可します。

### M11. アクセシビリティの喪失

- **変更前の挙動**: 変更前は `accessibilityLabel` が付いていました（`CustomDockPreview.swift`、`ProfileEditorPreview.swift`）。
- **結果**: GPUI 0.2.2 は AX ツリーを出しません。VoiceOver が使えません。`button()` に `track_focus` がなく、キーボードだけでは操作できません。
- **扱い**: 修正が難しいなら、PR 本文と `docs/GPUI_MIGRATION.md` に既知の退行として明記してください。

### M12. 検証とテストの穴

- 本番の render が `std::env::args()` で `--capture` を毎フレーム判定します（`dock.rs:207`、`278`）。キャプチャが本番のジオメトリを通りません。明示的なフィールドに置き換えてください。
- レイアウト計算、当たり判定領域、自動非表示の判定に、単体テストがありません。純関数に切り出して追加してください。
- PR 本文には、実機で未検証の次の項目を明記してください。
  - 実デスクトップでの click-through。
  - Spaces。
  - ディスプレイの抜き差し。
  - ホバー時の実性能。

### M13. ホバー解除の取りこぼしと resize の揺れ（仮説）

- **ホバー解除**:
  - `native.rs:110-118` の global monitor は、自アプリ宛のイベントでは呼ばれません。`ignoresMouseEvents` が切り替わった後は mouse exit が届かない場合があります。
  - その場合、拡大したアイコンとツールチップ（`self.hover`）が残ります。`over` の更新は 1 秒周期です（`dock.rs:60-75`）。
- **resize の揺れ**: `dock.rs:194-206` の `root_length` が `total` を含み、`total` はホバー拡大に連動します。ホバーするたびにウィンドウを resize すると、アイコンがポインタの下で動き、ホバーが振動する恐れがあります。
- **修正案**: ウィンドウは最大拡大時のサイズで固定します。

## Low

- **L1**: 背景画像のパスを `snapshot.status` に載せています（`state.rs:161-166`、`BridgeMain.swift:130-131`）。`respond()` 内でアイコンキャッシュのエラー文が status に入る場合（`BridgeMain.swift:172`）、その文が画像パスとして保存されます。専用のフィールドにしてください。
- **L2**: `state.rs:171` の `let editable` が未使用です。コンパイラ警告になります。
- **L3**: 要素を削除しても `selected_item` が残ります（`state.rs:167-176`、`ui.rs:605`）。変更前は選択を解除しました。
- **L4**: プロファイル削除の確認文言が名前だけです（`BridgeMain.swift:140-147`）。変更前は「項目と未保存の編集が削除される。アプリ本体は消えない」と説明しました。最後の 1 件でも確認が出て、黙って何も起きません（`DockStore.swift:144`）。何が消えるかを書いてください。
- **L5**: `toggle_dock` が read-only でも動きます（`state.rs:215-221`）。変更前は `DockStore.swift:173` のガードがありました。
- **L6**: `Settings` に Swift 側の未知フィールドを保持する仕組みがありません（`model.rs`）。将来フィールドが増えると、丸ごと書き戻して消える恐れがあります。
- **L7**: `cx.set_menus` が、ポーリングごとの通知でも再構築されます（`main.rs:161-170`）。開いているアプリメニューを乱す仮説があります。内容が変わったときだけにしてください。
- **L8**: アイコンキャッシュが無効化されません。
  - `icons[...]` は nil のときだけ作ります（`BridgeMain.swift:160`）。
  - Rust の `IconCache` もパス単位で無効化しません。
  - `icon-cache/` は掃除されません。
- **L9**: reduce transparency のとき、単色と画像の背景ではぼかしが残ります（`dock.rs:144-148`）。
- **L10**: 色コードの入力が先頭の `+` を許容します（`ui.rs:332-336`）。`+12345` が通ります。
- **L11**: 起動失敗時は stderr に出して終了するだけです（`main.rs:99-103`）。GUI では何も表示されません。
- **L12**: 時計の詳細ウィンドウがクリックのたびに新規作成されます（`dock.rs:478-490`）。1 秒周期のタスクも増えます。

## 問題なしと確認した点

- **Spaces と全画面**: GPUI の PopUp が `CanJoinAllSpaces | FullScreenAuxiliary` を設定します（`window.rs:810-812`）。変更前のパネルと同等です。`.ignoresCycle` だけ未設定です。
- **effect view の重なり順**: GPUI の native_view は contentView の subview です（`window.rs:775`）。`native.rs` の effect view は `positioned: -1` で下に入るので、描画順は正しいです。
- **ネイティブオブジェクトの寿命**: `DockNative` が NSWindow を retain します。monitor は Drop で `removeMonitor` します。ブロック内のウィンドウポインタは、この retain が前提で安全です。
- **ファイルとライセンス**:
  - プロファイルと外観の保存先ディレクトリは Swift と Rust で一致します（`ProfilePersistence.swift:8-9`、`appearance.rs:52-60`）。
  - `DisplayOption.swift` の中身は、`CustomDockWindowController` から削除した本体と同一です。
  - `AGENTS.md` と `CLAUDE.md` の追記は同一です。
  - 第三者ライセンスの扱い（`NOTICE.md`、`LICENSE-APACHE-2.0.txt`）に問題はありません。
- **起動時の安全**: 起動項目はすべて Swift の `store` を通ります。`ItemLaunchPolicy` の検証は保持されています。`open` は ID だけを渡します。
- **アルファ処理**: raster 画像の扱いは GPUI 本体と同じです。
- **bridge の基本動作**: JSON Lines の入出力、タイムアウト後の再起動、`exitAfter` の失敗時の扱いに、致命的な問題は見当たりませんでした。

## 修正の優先順

1. B1 から B4 を直し、実デスクトップで確認します。
2. M1、M2、M4、M7、M8 を直します。
3. M3、M5、M6、M9、M10 を直します。
4. M11 は修正するか、PR で既知の退行として明記します。
5. L1 から L12 は、まとめて処理して構いません。

修正後は `cargo test` と `swift test` を再実行し、画面キャプチャを取り直してください。
