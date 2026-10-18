# Dock の右クリックメニューからアプリを強制終了する

GitHub issue #16 の実装になる。通常終了（#15、`docs/QUIT_APP_FROM_MENU.md`）の隣に、強制終了を追加した。

## 仕様

起動中のアプリの項目の右クリックメニューに「強制終了…」を追加した。VoiceOver のアクセシビリティアクションにも同じ「強制終了…」がある。

- 強制終了は `NSRunningApplication.forceTerminate()` を使う。通常終了の `terminate()` とは別のメニュー項目で、別の経路になる。
- 出る条件は「終了」と同じで、`canQuitApplication` が true の項目だけになる。未起動のアプリ、フォルダ、ファイル、リンク、時計、タイマー、Finder、Dock Studio 自身には出ない。
- 選ぶと確認ダイアログを出す。見出しは「「○○」を強制終了しますか？」、本文は「未保存の変更は失われます。通常の終了で終わらない場合にだけ使ってください。」になる。ボタンは「強制終了」と「キャンセル」で、キャンセルすると何もしない。
- 確認後に `forceTerminate()` を呼ぶ。同じ bundle identifier のインスタンスすべてに要求し、1つでも受理されれば「○○ に強制終了を要求しました」を出す。すべて拒否された場合はエラーを出す。
- 終了したとは表示しない。起動中の表示は、既存の終了通知（`didTerminateApplication`）で更新する。

### 応答状態について

標準 Dock は、応答しないアプリに強制終了を出す。macOS には、他アプリの応答状態を調べる公開 API が無い（`NSRunningApplication` に該当するプロパティが無い）。非公開 API は使わないことにした。そのため、応答状態による出し分けは実装していない。起動中のアプリには、応答の有無にかかわらず「強制終了…」を出し、確認ダイアログで未保存データを失うことを明示する。標準 Dock の Option キーによる切替も実装していない。

実装は `DockStudio/Services/ApplicationQuitter.swift`（`forceQuit`）と `DockStudio/Store/DockStore.swift`（`forceQuitApplication`、確認は `confirmForceQuit`）にある。

## 検証

2026-10-18 に、ホストでビルドと単体テストだけを実行した。GUI は起動しておらず、実際のアプリも強制終了していない。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 152件すべて成功した（追加分は `ApplicationQuitTests` の10件） |
| Release ビルド | 成功した |
| `build-for-testing` | 成功した |

単体テストが縛る内容は次になる。

- 強制終了は `forceTerminate()` だけを呼び、`terminate()` は呼ばない。通常終了は `forceTerminate()` を呼ばない。
- Finder と自身は対象外で、別のアプリ、未起動の項目には呼ばれない。
- 拒否された場合はエラーを返す。同じ bundle identifier の全インスタンスに要求する。
- 確認でキャンセルすると呼ばれず、確認後に1回呼ばれる。起動中でない項目では確認自体を出さない。
- 確認の本文に「未保存」が含まれる。

未検証: 実画面でのメニューの見え方、確認ダイアログの表示、実際のアプリが強制終了する挙動、VoiceOver のアクション。

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `e2ba034` の Release ビルドを macOS 26.6.2 の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `6235a06f96033701e64719a1eb2b90c4473c12903a0282a1f2a773edc077cea9` と一致した。強制終了の対象は、ゲストの Calculator と TextEdit（未保存の書類つき）だけにした。メニューは `AXShowMenu` で開き、項目とダイアログのボタンは AX の押下で選んだ。

確認できたこと:

- 起動中の Calculator のメニューに「開く」「Finder で表示」「終了」「強制終了…」「Dock に保持」が出た（[menu-items.txt](media/force-quit-from-menu/menu-items.txt)、[menu-open-calculator.jpg](media/force-quit-from-menu/menu-open-calculator.jpg)）。
- 「強制終了…」を選ぶと、AX に確認のダイアログ（「キャンセル」「強制終了」のボタン）が現れた（[dialog-buttons.txt](media/force-quit-from-menu/dialog-buttons.txt)）。
- 「キャンセル」を選ぶと、Calculator は残った（[force-quit-log.txt](media/force-quit-from-menu/force-quit-log.txt)）。もう一度「強制終了…」から「強制終了」を選ぶと、Calculator は終了して Dock から消え、状態に「Calculator に強制終了を要求しました」が出た（[force-quit-calculator-status.jpg](media/force-quit-from-menu/force-quit-calculator-status.jpg)）。
- TextEdit（未保存の書類つき）は、通常の「終了」ではプロセスが残り、保存確認のシートが出た（AX に確認のボタンがあった）。続けて「強制終了…」を選ぶと、保存確認を経ずに TextEdit が終了し、状態に「TextEdit に強制終了を要求しました」が出た（[force-quit-textedit-status.jpg](media/force-quit-from-menu/force-quit-textedit-status.jpg)）。

確認できなかったこと、見つかったこと:

- **確認ダイアログの画面を撮れなかった。** AX にはダイアログのウィンドウとボタンがあったが、VNC のフレームには映らなかった（マウスを動かしても変わらなかった）。見出しと本文の文言は、画像では確認していない。ダイアログがウィンドウの背後や画面外に出ている可能性があるが、未確認である。
- Finder のメニューに「強制終了…」が出ないことは、確認できていない（Finder のメニューを開けず、直前のメニューが残っていた可能性がある）。未起動のアプリのメニューも、撮っていない。
- 動画は撮っていない。

## 撮影の手順

撮影は専任の担当が、専用のヘッドレス VM のゲストで行う。ホストでは行わない。強制終了そのものは、テスト用のアプリだけを対象にする。

1. ゲストで Calculator を起動しておく。ほかに撮影で使うアプリは、TextEdit を未保存の書類つきで起動する（手順6で使う）。
2. 検証用データは空のディレクトリでよい（`DOCKSTUDIO_DATA_DIR=<空のディレクトリ>`）。既定のプロファイルで起動する。
3. Dock Studio を起動し、設定の「Dock」にある「実行中のアプリを表示」を有効にする。
4. 「Custom Dock」の画面を開き、Calculator が起動中の点つきで出ることを確認する。
5. Calculator を右クリックする。メニューに「開く」「Finder で表示」「終了」「強制終了…」が出る。「強制終了…」を選ぶと確認ダイアログが出る。見出しに「Calculator」の名前、本文に「未保存の変更は失われます」が出ることを確認する。まず「キャンセル」を選び、Calculator が残ることを確認する。もう一度同じ操作で「強制終了」を選ぶと、Calculator が終了して Dock から消え、状態「Calculator に強制終了を要求しました」がタイトル下に出る。
6. TextEdit（未保存の書類つき）で同じ操作をし、保存確認が出ずに TextEdit が終了することを確認する。通常の「終了」では保存確認が出るので、比較として先に「終了」を選んでキャンセルする。
7. 未起動のアプリ（プロファイルに追加した TextEdit を終了した後など）と Finder を右クリックし、「強制終了…」が出ないことを確認する。

撮る画像と動画は次になる。

- 画像: 起動中のアプリのメニュー（「強制終了…」あり）、確認ダイアログ、強制終了後の状態表示、未起動のアプリと Finder のメニュー（「強制終了…」なし）。
- 動画: 手順5（右クリック、確認ダイアログ、キャンセル、再度実行、アプリが消えるまで）。
