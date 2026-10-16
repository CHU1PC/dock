# 保存基盤と Custom Dock のコードレビュー

Sonnet による指摘を、選別せず原文のまま記載する。利用者から全件修正の承認を得た。[修正結果](REVIEW_FIXES.md)に対応状況を記載する。

コードを Read で読み、実行はしていません。指摘は 10 件です。重要度が高い順に並べています。

**1. 取り込んだ JSON が任意のローカル実行ファイルを起動できます（中、セキュリティ）。**
`DockDocument.swift:110-114` は、`application`・`folder`・`file` の target が file URL であることしか見ていません。拡張子も、`.app` かどうかも、存在も確認しません。項目名は自由に付けられます。`DockStore.swift:221-229` の取り込みには、内容を見せる確認がありません。細工した共有 JSON を取り込むと、「Safari」のような名前の項目から `file:///…/evil.app` や任意のスクリプトを `openItem`（`DockStore.swift:192-208`）で起動できます。書き出した JSON には `/Users/<name>/…` の絶対パスも入るので、共有するとユーザー名が漏れます。

**2. 未保存の下書きが、確認なしで失われます（中）。**
下書き `drafts`（`DockStore.swift:10`）はメモリにしかありません。メニューバーの「終了」（`DockStudioApp.swift:102`）は、「未保存の変更があります」と表示されていても確認なしで `terminate` します。編集後に保存せず終了または再起動すると、変更が黙って消えます。

**3. Dock の再描画が、開いているポップオーバーやメニューを閉じます（中）。**
`CustomDockWindowController.update()` は呼ばれるたびに `NSHostingView` を作り直します（`:105-107`）。作り直しで `ClockTile.expanded` の状態（`CustomDockPreview.swift:127`）が消え、`.popover`（`:140`）と `.contextMenu`（`CustomDockWindowController.swift:147`）が閉じます。`showRunningApps` が有効なときは、バックグラウンドアプリの起動や終了でも `runningItems` が更新され、再描画されます。さらに自動非表示の判定（`:114`）はパネルの外周 24pt だけを見ます。ポップオーバーやメニューが外周の外に出るか、ポインタが 1 秒以上外れると、開いたまま折りたたまれて閉じます。

**4. 「メインディスプレイ」が `NSScreen.main` に解決されます（中〜低）。**
`CustomDockWindowController.swift:77-81` の `NSScreen.main` は、キーウィンドウのある画面を指します。システムのメインディスプレイ（メニューバーのある画面）ではありません。`SettingsPreview.swift:68` の表示名と実際の挙動が食い違います。複数ディスプレイでスタジオウィンドウを別の画面に移すと、次に `update()` が走った時点で Dock がその画面へ移ります。フォーカス変化では再配置されないので、位置がタイミング次第で決まります。

**5. 自動非表示の状態遷移が不正確です（低）。**
`lastHover`（`:25`）は、自動非表示が有効で `updateAutoHide` が動いている間だけ更新されます。オフの間に古くなるので、有効にした直後に最大 0.2 秒で折りたたまれます（`:118`）。1 秒待ちの仕様と合いません。`isCollapsed` は `isDockVisible` を隠しても保持されます（`:84-87` は `autoHide` が有効なら `isCollapsed` をリセットしません）。メニューから「表示」しても、8pt のカプセルとしてしか現れません。

**6. 読み込み失敗時（read-only）の表示が実態と合いません（低）。**
`DockStore.swift:28-36` では、読み込みに失敗すると `document` が初期シードのままです。UI はそれを通常のプロファイルとして表示します。`SettingsPreview.swift:22` は「変更は自動保存されます」と出し続けます。`exportProfiles`（`DockStore.swift:210-219`）は、ユーザーの本来のデータではなくシードを選択したファイルに書き出します。保護された元ファイルを開き直したり復旧したりする導線もありません。

**7. 固定項目と実行中アプリの重複排除が、文字列の完全一致です（低）。**
`DockStore.swift:59-62` は `target` の `absoluteString` で比べます。末尾スラッシュや `/System/Applications` の違いがあると、固定済みのアプリが実行中として二重に出ます。手編集した JSON の取り込みでも起きます。同一 bundleURL の複数インスタンスが動いているとき、`CustomDockWindowController.swift:129` が同じ既存項目を返すので、ID が重複します。`ForEach` の挙動が不定になります。

**8. 「Apple Dock から取り込む」が同期実行で、エラーも不親切です（低）。**
`NativeDockReader.readItems`（`NativeDockReader.swift:12-15`）は、`@MainActor` の `DockStore` から同期で `Process` を実行し、stdout と stderr を順に読み切ります。UI を止めます。stderr が先にパイプ容量（64KB）を超えると、デッドロックする理論上の危険もあります。`persistent-apps` キーがない状態では `keyNotFound` が、そのままエラーメッセージに出ます（`:23`、`DockStore.swift:189`）。

**9. 「Apple Dock」モードで表示ボタンが無反応です（低）。**
`update()` はモードが `.native` のとき必ず `orderOut` します（`CustomDockWindowController.swift:84`）。ツールバーとメニューの「Dock を表示」（`DockStudioApp.swift:50-56`、`:96`）は `isDockVisible` を切り替えるだけで、何も表示されず、メッセージもありません。

**10. 書き出しと読み込みの対象が非対称です（低）。**
`SettingsPreview.swift:115` は「プロファイルと設定を書き出します」と案内します。`mergeProfiles`（`DockStore.swift:231-241`）は、読み込み時に `settings` を黙って捨てます。設定のバックアップとして復元できる印象を与えます。スライダーも 1 ステップごとに同期保存し、パネルを再生成します（`SettingsPreview.swift:81`、`DockStore.swift:131-135`）。保存が失敗する状態では、ドラッグ中にエラーが繰り返し出ます。

**確認したが問題がなかった点**
- `project.yml`、永続化の原子書き込み、下書きの分離、プロファイルの削除と複製は、読んだ範囲では問題を見つけていません。
- 下書きは保存済み `document` と混ざらず、`commit` も失敗時に `document` を更新しません。
- 17 件のテストが扱うのは `DockStore` だけです。AppKit 側（`CustomDockWindowController`）にテストはありません。

**レビューの限界**
- 静的に読んだだけで、実行も実機確認もしていません。
- 指摘 3 と 4 は AppKit と SwiftUI の挙動の推測を含みます。実機での確認を推奨します。
- 指摘 7 のうち、`NSOpenPanel` が末尾スラッシュ付きの URL を返すかどうかは確かめていません。
- 起動時の `DockStudioApp.init`（`:10-14`）は、テストホストでもユーザーの実データを読みます。書き込みはしません。
