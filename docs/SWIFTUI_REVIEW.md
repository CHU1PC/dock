# DockStudio 外観機能レビュー（読み取り専用）

指定の7ファイルは全文を読み、補助として `DockVisibilityState.swift`、`ProfilePersistence.swift`、`DockStudioApp.swift` も読みました。ビルドとテストの実行、実機での目視はしていません。「確度」は、コードから確定できるものを **確定**、実行して確認が要るものを **要実機**、推測を **推測** と表記します。

**件数注記: レビュー原文は Blocking 3、Non-blocking 20、合計 23 と記載していたが、見出しは B1〜B3 と N1〜N23 の計26項目ある。以下は全項目を掲載する。** 読み書きの保護と、アトミック保存の失敗時に表示中の設定が変わらない点は、検証した範囲では問題ありませんでした。

---

## Blocking

### B1. 自動非表示からの復帰が、画面端のジェスチャで反応しない（確定）
`CustomDockWindowController.swift:128, 135-139, 155-157`

- `visible` は `visibleFrame` を 10pt 内側へ縮めたものです（128）。パネルの frame もその内側に置かれます（135-139）。
- 折りたたみ時の判定領域は `frame.minY` から高さ 8pt、左右は `frame.minX` 起点または `frame.maxX - 8` です（155-157）。画面の実際の端から 10pt 内側にあり、幅も 100pt しかありません。
- Dock の復帰は、ポインタを画面の端に押し付ける動作が普通です。その位置は領域の外なので、反応しません。
- 修正: `selectedScreen.frame` の端まで領域を伸ばします。例: `y: screen.frame.minY, height: inset + 8`。長さ方向も 100pt 固定をやめ、辺全体か `frame` の幅に合わせます。判定を純粋関数に切り出すと、テストも書けます。

### B2. 折りたたまれた Dock を、VoiceOver とキーボードでは出せない（確定）
`CustomDockWindowController.swift:46, 118, 151-159, 212-215`

- 復帰の唯一の契機は `NSEvent.mouseLocation` です。
- `Color.clear` のラベル「ポインタを重ねます」（214）には、操作できる accessibility action がありません。
- パネルは `.borderless` + `.nonactivatingPanel` です（46）。標準では `canBecomeKey == false` なので、展開中でも Tab や Space で操作できません。
- 修正案:
  - 折りたたみ要素に `.accessibilityAddTraits(.isButton)` と `.accessibilityAction` を付け、展開する経路を作ります。
  - `NSWorkspace.shared.isVoiceOverEnabled` のときは自動非表示を抑止します（`interacting` に混ぜれば足ります）。
  - キーボード操作が要件なら、`canBecomeKey` を true にする NSPanel サブクラスと、メニューバーからの項目起動を用意します。
- `DockMenu` が項目を列挙しているかは未確認です。列挙していれば、それが代替経路になります。

### B3. ポインタが項目の隙間を通るたびに、全アイコンの倍率が一度 1 に戻る（要実機）
`CustomDockPreview.swift:81, 108, 136-139`

- 項目間の spacing は 10pt（81）で、`onHover` は各項目の VStack だけにあります（136）。隙間にポインタがあると `hovered == nil` になります（138）。
- 全項目が `.spring` で縮み（108）、次の項目に入ると再拡大します。HStack の幅も揺れ、横方向のレイアウトが安定しません。
- 修正案: コンテナ全体の `onContinuousHover` で、x 座標から最近傍の項目を決めます。小さな修正なら、各項目に `contentShape(Rectangle())` と `padding(.horizontal, 5)` を付け、spacing を 0 にして隙間を無くします。
- 実機で、項目間をゆっくり動かして確認してください。

---

## Non-blocking

### 画像の読み込みとキャッシュ

**N1. 背景画像ファイルが増え続ける（確定）** `DockStore.swift:120-125`
選び直すたびに `backgrounds/<UUID>.png` が増え、置き換えられた旧ファイルは削除されません。成功後に、旧 `appearance.image` が `backgrounds/` 配下のときだけ消してください。

**N2. 背景の失敗が記憶されず、描画のたびに stat と decode が走る（確定）** `DockAppearanceRendering.swift:44-58, 106`
- `body` の中で同期的に `resourceValues` を呼びます。
- 読めない画像は `nil` を返しますが、その結果を覚えません（48, 49-54）。hover のたびに再試行します。
- 破損した巨大画像だと、メインスレッドで繰り返し decode します。
- 対策: `updateAppearance` 時に一度だけ読み込む、または失敗キーを記憶します。選択時の thumbnail 生成（`DockStore.swift:106-112`）も `runModal` 後のメインスレッドです。

**N3. アイコンのキャッシュが毎回 stat とキー文字列生成を伴う（確定、影響は中）** `DockAppearanceRendering.swift:14-17`
- 倍率アニメーション中は、約5項目が毎フレーム `url.resourceValues` とキー文字列の生成を行います。
- `totalCostLimit` 16MB ÷ 256KB で、実効は約64件です（9, 38）。件数が多いとキャッシュが入れ替わり、再ラスタライズが走ります。
- 修正: mtime を `refreshRunningApps` などの更新時にまとめて取る、またはキーを (URL, style) にします。上限は実際のアイコン数に合わせます。

**N4. 画質と色空間（一部確定）** `DockAppearanceRendering.swift:19, 21, 29`
- 256px は、最大サイズ 76pt × 倍率 2.0 × Retina 2x = 304px に足りません（確定）。
- `.original` でも毎回ラスタライズし、NSImage の多解像度表現を失います（29）。`.original` は元の画像をそのまま返せます。
- `CGColorSpaceCreateDeviceRGB()` は色管理されません。P3 のアイコンで色味がずれる可能性があります（要実機）。`CGColorSpace(name: .sRGB)` を推奨します。

**N5. 変換に失敗すると、スタイルが黙って無効になる（確定）** `DockAppearanceRendering.swift:23, 36`
`CGContext` や `makeImage` の失敗時は、スタイル未適用の `original` を返し、キャッシュもしません。白黒を選んでもカラーで出ます。ログを残すか、フォールバックの有無が分かるようにしてください。

**N6. premultiplied alpha の扱いは正しい（確認済み）** `DockAppearanceRendering.swift:60-72`
- 白黒は `min(alpha, luminance)` で、出力は `v ≤ alpha` です。
- ガラスは `newAlpha * shade` で、`v ≤ newAlpha` です。
- `UInt8()` のトラップ条件にも当たりません。
- 非ブロッキングの指摘として、テスト（`DockAppearanceTests.swift:82-93`）は純関数だけを検証しています。`CGContext` を通る経路は未検証です。

### 背景の描画

**N7. 背景画像の blur が `clipped()` の後にあり、端が透けてぼやける（確定）** `DockAppearanceRendering.swift:107-111`
内容を clip してから blur するため、端が透明に溶けます。blur を先に適用して clip するか、少し拡大してください。

**N8. 背景モードの見え方に懸念がある（要実機）** `DockAppearanceRendering.swift:79, 101, 103`
- `.system` で `blur=false` にすると、見える層は `Color.white.opacity(0.06×opacity)` だけです。実質ほぼ透明になります。仕様意図の確認が要ります。
- `NSViewRepresentable` に付けた `.opacity` は、behind-window の `NSVisualEffectView` と `NSGlassEffectView` で期待どおり効かない可能性があります。
- macOS 26 では、`.clipShape` が `NSGlassEffectView` に効くかも、実機で見てください。
- `cornerRadius = 22` は、`DockBackdrop` 側の 22 と二重に定義されています。

**N9. 実行中ドットとスペーサーが白固定で、明るい背景では見えない（確定）** `CustomDockPreview.swift:89, 133`
単色や画像の背景が明るいと、ドットと区切り線が消えます。背景の輝度から色を選ぶか、影を付けてください。

**N10. `iconStyle` が、ファイル以外の項目に効かない（確定）** `CustomDockPreview.swift:159-168`
URL や SF Symbols の項目は、白黒やガラスを選んでも変わりません。仕様として許容するなら、設定画面に一言あると親切です。

### パネルとレイアウト

**N11. 端の項目で、ツールチップと拡大アイコンがパネル境界に切られる（確定）** `CustomDockWindowController.swift:130`、`CustomDockPreview.swift:101, 142-145`
パネル幅は `length` ちょうどです。端の項目のツールチップは、パネル境界で切られます。`.help(item.name)`（148）も同じ名前を出すため、二重表示になります。左右に余白を足し、`.help` は外すのが安全です。

**N12. 縦配置で、最大拡大のアイコンが 2pt はみ出す（確定、境界値）** `CustomDockPreview.swift:100, 250-256`
アイコン 76 × 2.0 = 152pt に左右 padding 24 を足すと 176pt です。バー幅は 174pt なので、切れます。バー幅を `iconSize × maximum + 24 + α` から求めてください。

**N13. 影がパネル境界で切れる（確定、要目視）** `CustomDockPreview.swift:79`
バーはパネル下端に接しています。`shadow(radius: 12, y: 4)` は下へ約 16pt 伸びる設計ですが、ウインドウ外には描けません。余白を足すか、影の向きを見直してください。

**N14. タイマーが常時 10Hz で回る（確定、電力）** `CustomDockWindowController.swift:84-87`
Dock が非表示でも、自動非表示が無効でも、毎回 `updateAutoHide` と `updatePointerPassThrough` を実行します。有効条件（パネル表示中かつ自動非表示、またはパススルー判定が必要なとき）だけで回してください。

**N15. 「視差効果を減らす」の変更を購読していない（確定）** `CustomDockWindowController.swift:142`
`layout.reduceMotion` は `update()` の呼び出し時にしか更新されません。`NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` を購読してください。ホバーの拡大は `@Environment(\.accessibilityReduceMotion)` で追従します。折りたたみのアニメーションだけが対象です。

**N16. メニュー追跡カウンタが固着する可能性（推測）** `CustomDockWindowController.swift:72-79`
begin と end が対にならない経路があると、`trackingMenus > 0` のままになります。そうなると、パススルーが効かず、自動非表示も働きません。一定時間後に再同期する保険を勧めます。

**N17. 初回表示の最大 100ms は、全面が穴なしになる（確定、軽微）** `CustomDockWindowController.swift:147-148, 168-169`
`ignoresMouseEvents` を決める処理は `panel.isVisible` を前提にしています（169）。`update()` が `orderFrontRegardless` より前に呼ぶため、表示直後の最初の1回は反映されません。次のタイマー周期までは、パネル全体がクリックを受けます。`orderFront` の後にもう一度呼べば済みます。

### アクセシビリティ

**N18. 細かい AX の改善点（確定、軽微）**
- `.accessibilityValue("")`（`CustomDockPreview.swift:126`）は、空文字ではなく値なしにします。
- `Color.clear` のラベル（`CustomDockWindowController.swift:214`）は、要素として読まれない可能性があります。
- `.accessibilityLabel("時計")`（`CustomDockPreview.swift:190`）は、子の時刻テキストを隠します。既存コードです。

### 保存と互換性

**N19. 外観の保存がスライダの値ごとに同期的に走る（確定）** `DockStore.swift:85-88`、`SettingsPreview.swift:139, 164`
- 不透明度と拡大率のスライダは、ドラッグ中に毎ステップ `createDirectory` と JSON のアトミック書き込みを行います。
- 失敗時は毎回 `errorMessage` が立ち、アラートが出ます。
- 既存の `stageIconSize`（`DockStore.swift:265-285`）と同じデバウンスパターンが使えます。

**N20. 互換性は検証できていない（限界あり、推測を含む）** `DockAppearance.swift:47-52, 67-72`
- 未知キーが1つでもあると、外観全体が読み取り専用になります。「将来版のファイルを壊さない」という意図は妥当です。
- ただし、旧 GPUI が書く実際のキー名と値の型（特に `color` が UInt32 数値か、`iconStyle` の raw 値）は、リポジトリ内に仕様がなく確認できません。`docs/` に該当する記載はありませんでした。
- 逆方向では、新しいキー（`reduceMotion`、`magnificationScale`、`iconStyle`）を書き出します。GPUI が未知キーを拒否する実装なら、GPUI 側で読めなくなります。GPUI の保存形式との突き合わせテストを勧めます。
- `image` は絶対パスで、検証がありません（`validate` に含まれない）。データフォルダの移動で壊れます。任意パスを読めますが、読むのは画像としての decode だけで、リスクは低いです。
- 別プロセスが同時に書く場合は後勝ちです。アトミック書き込み自体は安全です。

**N21. テストの穴と脆さ（確定）** `DockAppearanceTests.swift:74-79, 82-93`
- 浮動小数の `XCTAssertEqual` が、`1.45` と `1.12` を厳密比較しています。`accuracy:` を付けてください。
- 未カバーの範囲は次のとおりです。
  - 背景画像の読み込みと、その失敗時のふるまい
  - `backgrounds/` の掃除
  - 判定領域の幾何（B1 を純関数にすれば書けます）
  - 縦方向のクリップ
  - `CGContext` を通る描画経路

### その他

**N22. 派生計算が毎回走る（推測、現状は軽微）** `CustomDockPreview.swift:69, 83, 87, 109`、`DockStore.swift:131-134, 157-164`
`displayedItems` は計算プロパティで、1回の body で複数回評価されます。`isRunning` は項目ごとに O(n) で、全体は O(n²) です。項目が数十件ならほぼ問題になりません。

**N23. OS API の可用性（確認済み、問題なし）**
macOS 15 以降で使う API はすべて対象内です。`NSGlassEffectView` は `#available(macOS 26.0, *)` で守られています。ビルドには Xcode 26 SDK が要ります。

---

## 限界と未確認事項

- ビルドもテストも、アプリの起動もしていません。B3、N4 の色味、N8、N13 は目視で確認してください。
- NSPanel の `canBecomeKey` や `NSMenu` の追跡通知など、AppKit のふるまいは API の知識にもとづきます。実機で確かめていません。
- GPUI 側のコードと保存形式は参照できず、互換性（N20）は未検証です。
- `DockMenu` と `WorkspaceView` の全文は読んでいません。`errorMessage` のアラート表示だけ grep で確認しました。
- 指摘の取捨はしていません。直すものの選択はお任せします。
