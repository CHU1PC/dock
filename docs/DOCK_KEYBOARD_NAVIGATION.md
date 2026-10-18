# Dock 内のキーボードナビゲーション

Issue #48 の「補完」の実装になる。調査の結果は [research/INPUT_A11Y.md](research/INPUT_A11Y.md) の #48 の節にある。

## 仕様

メニューバーの「Dock をキーボードで操作」で、パネルの先頭の項目にフォーカスが当たる。そこから次のキーで操作する。標準 Dock で観察した、端で折り返さずフォーカスが外れる動作に合わせた。

| キー | 動作 |
| --- | --- |
| 下配置の左右、左右配置の上下 | 並び順で前後の項目へ移動する。スペーサーは飛ばす。端では折り返さず、フォーカスを外して元のアプリへ戻る |
| Home、End | 先頭、末尾の項目へ移動する |
| 文字、数字 | 名前の先頭が一致する項目へ移動する。同じ文字の連打で次の一致へ進み、1 秒以内に続けた入力は前方一致の文字列になる。端では折り返す |
| 下配置の上、左配置の右、右配置の左 | フォーカス中の項目のメニュー（開く、Finder で表示、終了、Dock に保持、Dock から取り外す。出し分けは右クリック、VoiceOver のアクション、上キーで同じ）を項目の横に開く。Escape ではメニューだけが閉じ、項目のフォーカスは残る |
| Escape | フォーカスを外し、キーボード操作に入る前の前面アプリへ戻る |
| Return、Space | 従来どおり項目を開く |

- Command、Control、Option を伴うキーは処理せず、OS とほかのアプリに任せる。
- 項目を取り外すと、フォーカスは取り外した位置にあった次の項目へ移り、次が無ければひとつ前へ移る。項目が無くなれば、フォーカスを外す。
- Dock を隠した場合も、フォーカスを外して元のアプリへ戻る。
- 時計と集中タイマーは、矢印キーの移動の対象にしていない。Tab では従来どおり止まる。

標準 Dock の左右配置でメニューを開く向きは、観察できていない。画面の端から離れる向き（左配置は右、右配置は左）にした。

### 項目の名前の表示（#60 で外した変更）

キーボードでフォーカスした項目にも名前を出す。次の条件で、#60 の 2 つの問題を避けた。

- 表示するのは、パネルがキーウインドウのときだけにした。起動直後や、パネルがキーでないときは出ない。
- ポインタを重ねている項目を優先する。ホバー中の下配置の表示と拡大は変えていない。
- キーボード操作に入ったとき（メニュー、矢印キー、Tab）に限って、フォーカス中の名前を出す。ポインタが項目に重なると、この状態は解除する。右クリックでパネルがキーになっただけでは出ない。
- パネルがキーでなくなったとき、フォーカスの状態を捨てる。

### Tab の停止位置

項目ごとに Tab が 2 回必要だった原因は、`Button` の外側の `.focusable()` が別の停止位置を作っていたことだった。`Button` 自体のフォーカスを外し、外側の 1 つだけを停止位置にした。Tab は項目ごとに 1 回になった（VM で Finder、Safari、Mail の順に確認した）。

### 実装の構成

- `DockStudio/Models/DockKeyboardNavigation.swift` に、画面から独立した移動の関数を置いた（方向、端、文字での移動、取り外し後の移動先、入力文字列の保持）。`DockStudioTests/DockKeyboardNavigationTests.swift` の 12 件で縛っている。
- `DockBar` は、項目に `.focusable()` と `@FocusState` を持たせ、キーを関数へ渡す。メニューは `NSMenu` で開く。右クリックのメニューと同じ項目の定義を使う。
- `CustomDockWindowController` は、キーボード操作に入る前の前面アプリを保存し、Escape、端での移動、Dock を隠したときに戻す。ほかのキーはパネルがキーのときにしか処理しない。

## 検証

ホストでは、ビルドとテストだけを行った。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 117 件すべて成功した（移動の関数は 12 件） |
| Release ビルド | 成功した |
| `xcodebuild build-for-testing` | 成功した（新しいテストファイルの登録を確認した） |

GUI は、macOS 26.6.2 の専用ヘッドレス VM で確認した。キーはゲスト内の CGEvent で送り、フォーカスはアクセシビリティ API（`AXFocusedUIElement`）で読んだ。ホストのデスクトップには、アプリや VM の画面を表示していない。

### 確認できたこと

| 操作 | 結果 |
| --- | --- |
| 下配置で右、右、End、左、Home、先頭で左 | Safari、Mail、Downloads、Calendar、Finder へ移り、先頭の左ではフォーカスが外れた（[ログ](media/dock-keyboard-navigation/logs/run1-manual-bottom.txt)） |
| 下配置で `m`、`s` | Mail、Safari へ移った |
| 下配置で上 | Safari のメニューが項目の上に出た（[画像](media/dock-keyboard-navigation/bottom-menu-above-item.png)）。Escape でメニューだけが閉じ、フォーカスは Safari に残った |
| メニューから「Dock から取り外す」 | Safari が取り外され、フォーカスが次の Mail へ移った（[画像](media/dock-keyboard-navigation/bottom-after-remove-focus-next.png)）。続けて Space で Mail が開いた |
| 起動直後、パネルにフォーカスが無い状態 | 名前は出なかった（[下](media/dock-keyboard-navigation/bottom-launch-no-label.png)、[左](media/dock-keyboard-navigation/left-launch-no-label.png)）。キーボード操作に入ると、先頭の名前が出た（[画像](media/dock-keyboard-navigation/bottom-focus-first-item.png)） |
| 左配置で下、下、End、`s` | Safari、Mail、Downloads、Safari へ移り、名前が項目の右に出た（[End](media/dock-keyboard-navigation/left-end-label.png)、[文字](media/dock-keyboard-navigation/left-typeahead-label.png)） |
| 右配置で下、下、End | Safari、Mail、Downloads へ移り、名前が項目の左に出た（[画像](media/dock-keyboard-navigation/right-end-label.png)） |
| Tab | 項目ごとに 1 回になった |
| Escape（別のアプリを前面にして入った後。VNC を使わず、ゲスト内の CGEvent だけでキーを送った） | 下、左、右配置で 5 回ずつ（計 15 回）、前面が Safari に戻った（`logs/run4-esc-3positions.log`）。最終のビルドでも、下配置で 5 回戻った（`logs/run4-final-bottom-esc-pointer.log`） |
| 端での移動（下、左、右配置） | 前面が Safari に戻った（`logs/run2-*.log`） |
| 右クリックのメニュー（`ForEach` に置き換えた後） | 「開く」「Finder で表示」「Dock から取り外す」の同じ 3 項目が出た（[画像](media/dock-keyboard-navigation/bottom-right-click-menu.png)） |
| 右クリックのメニューを閉じてポインタを外す、項目をクリックしてポインタを外す（下配置） | どちらも名前は出なかった（[右クリック後](media/dock-keyboard-navigation/bottom-after-menu-pointer-away.png)、[クリック後](media/dock-keyboard-navigation/bottom-after-click-pointer-away.png)） |

[stills-sequence.mp4](media/dock-keyboard-navigation/stills-sequence.mp4) は、上の静止画を 2 秒ずつ並べたスライドで、実時間の動画ではない。

### 確認できなかったこと、不安定だったこと

- **Escape の復帰が戻らなかった回は、検証環境の入力の欠落だった。** `logs/run3-bottom.log` では戻らなかったが、いずれも VNC で静止画を撮った直後のキーだった。VNC を使わずにキーだけを送ると、3 配置で 15 回、最終のビルドで 5 回、すべて戻った。アプリ側の欠陥は見つからなかった。VNC の接続後にゲストのキーが欠落する原因は、特定できていない。`leaveKeyboard()` は、保存したアプリを先に取り出してから `resignKey()` を呼び、`activate(from:)` で戻す。
- **起動直後の初回だけ、フォーカスが先頭の項目に当たらない。未解決（受け入れ条件の 1 つが満たせていない）。** アプリを起動して最初に「Dock をキーボードで操作」を実行すると、パネルはキーウインドウになるが、フォーカスはスクロール領域か、名前の無いグループに当たり、矢印キーが効かない。2 回目以降（別のアプリを前面にして入り直した場合）は、先頭の Finder に当たる。試して直らなかった方法は次のとおり。
  - `focused` の代入に待ち時間を入れる（150ms）。
  - 代入のあとに、50ms 間隔で再試行する。
  - 代入を `nil` に戻してから入れ直す（150ms 間隔、3 回）。最終のビルドにはこの方法が入っているが、効いていない（`logs/run4-esc-3positions.log` の `first-entry`）。
  - `ScrollView` に `.focusable(false)` を付ける。フォーカスは名前の無いグループに当たり、2 回目の確認では Finder に当たった。結果が実行ごとに変わり、Tab も効かなくなったため戻した。
  - `.defaultFocus` を付ける。フォーカスがどの要素にも当たらなくなり、悪化した（`logs/run4-defaultfocus-attempt.log`）。戻した。
  原因は、SwiftUI の `@FocusState` の代入が、ウインドウが初めてキーになった直後は、AppKit 側の最初のレスポンダに反映されないことと見ている。確かめるには、パネルの `firstResponder` を観察する必要がある。
- **Tab が項目ごとに 1 回で止まることは、最終のビルドで再確認できていない。** 先に確認した（Finder、Safari、Mail）のは `.focusable(false)` を `Button` に付けた直後のビルドになる。最終のビルドでは、Tab の確認が、フォーカスが先頭に当たらない状態から始まり、動かなかった（`logs/run4-final-bottom-esc-pointer.log` の `tab#`）。
- **動画は撮影できなかった。** VNC のフレームバッファが、キー操作の数秒後まで更新されず、連続撮影では画面の変化を取れなかった。`stills-sequence.mp4` が静止画のスライドで、実時間の動画でないのは、この理由による。PR の本文にも、同じ理由を書く。キー操作の結果は、アクセシビリティ API のフォーカスのログと静止画で示している。
- **未検証（残す項目）**: 起動直後の 1 回目のフォーカス（未解決。別 issue で扱う）、Tab が項目ごとに 1 回で止まることの最終のビルドでの確認。
- 左配置と右配置でのメニュー（左配置は右キー、右配置は左キー）は、開いた画像を取れていない。位置の計算は下配置でだけ確認した。
- 項目の追加と、Dock の非表示への切替でフォーカスを失わないことは、確認していない。取り外しだけを確認した。
- 左右配置の標準 Dock との照合、macOS 15 から 25、VoiceOver の読み上げ、自動非表示との組合せ、画面外へ出る項目のスクロール、管理画面のプレビューでの矢印操作（パネルだけを対象にした）は、確認していない。
