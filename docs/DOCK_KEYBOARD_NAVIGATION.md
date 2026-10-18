# Dock 内のキーボードナビゲーション

Issue #48 の「補完」の実装になる。調査の結果は [research/INPUT_A11Y.md](research/INPUT_A11Y.md) の #48 の節にある。

## 仕様

メニューバーの「Dock をキーボードで操作」で、パネルの先頭の項目にフォーカスが当たる。そこから次のキーで操作する。標準 Dock で観察した、端で折り返さずフォーカスが外れる動作に合わせた。

| キー | 動作 |
| --- | --- |
| 下配置の左右、左右配置の上下 | 並び順で前後の項目へ移動する。スペーサーは飛ばす。端では折り返さず、フォーカスを外して元のアプリへ戻る |
| Home、End | 先頭、末尾の項目へ移動する |
| 文字、数字 | 名前の先頭が一致する項目へ移動する。同じ文字の連打で次の一致へ進み、1 秒以内に続けた入力は前方一致の文字列になる。端では折り返す |
| 下配置の上、左配置の右、右配置の左 | フォーカス中の項目のメニュー（開く、Finder で表示、Dock から取り外す）を項目の横に開く。Escape ではメニューだけが閉じ、項目のフォーカスは残る |
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
| Escape、端での移動（下、左、右配置。別のアプリを前面にして入った後） | 前面が Safari に戻った。ログは `run2-*.log` の最後の 4 行にある |

[stills-sequence.mp4](media/dock-keyboard-navigation/stills-sequence.mp4) は、上の静止画を 2 秒ずつ並べたスライドで、実時間の動画ではない。

### 確認できなかったこと、不安定だったこと

- **動画は撮影できなかった。** VNC のフレームバッファが、キー操作の数秒後まで更新されず、連続撮影では画面の変化を取れなかった。キー操作の結果は、アクセシビリティ API のフォーカスのログと静止画で示している。
- **キー入力が届かない回がある。** `logs/run2-*.log` と `run3-*.log` では、途中のキー（End、Home、左右配置の上、メニュー関連）が効かない場面が混ざった。いずれも、直前に VNC の接続で静止画を撮った後に起きた。接続の直後にゲストの入力が欠落する既知の現象（検証手順の注意）と同じものかもしれないが、アプリ側の不具合を除外できていない。`run3-bottom.log` では、Escape と端での移動で前面アプリへ戻る動作を観察できなかった（`run2-*.log` では 3 配置とも戻った）。VNC を使わずにキーだけを送った最初の手動の確認（`run1-manual-bottom.txt`）では、すべて期待どおりに動いた。
- **起動直後の初回だけ、フォーカスが先頭の項目に当たらない。** アプリを起動して最初に「Dock をキーボードで操作」を実行すると、フォーカスがスクロール領域に当たり、矢印キーが効かなかった（`run2`、`run3` の `first-entry`）。2 回目の実行では先頭の Finder に当たった。待ち時間を入れる修正では直らなかった。未解決になる。
- 左配置と右配置でのメニュー（左配置は右キー、右配置は左キー）は、開いた画像を取れていない。位置の計算は下配置でだけ確認した。
- 項目の追加と、Dock の非表示への切替でフォーカスを失わないことは、確認していない。取り外しだけを確認した。
- 左右配置の標準 Dock との照合、macOS 15 から 25、VoiceOver の読み上げ、自動非表示との組合せ、画面外へ出る項目のスクロール、管理画面のプレビューでの矢印操作（パネルだけを対象にした）は、確認していない。
