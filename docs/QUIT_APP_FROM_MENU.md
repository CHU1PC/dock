# Dock の右クリックメニューからアプリを通常終了する

GitHub issue #15 の実装になる。

## 仕様

起動中のアプリの項目の右クリックメニューに「終了」を追加した。VoiceOver のアクセシビリティアクションにも同じ「終了」がある。「Dock から取り外す」と同じ書き方で、取り外しとは独立している。

- 通常終了は `NSRunningApplication.terminate()` を使う。強制終了と隠すは扱わない。
- 「終了」は、種別がアプリで、起動中の一覧にあり、終了の対象にできる項目にだけ出る。未起動のアプリ、フォルダ、ファイル、リンク、時計、タイマーには出ない。
- Finder と Dock Studio 自身は対象にしない。Finder は終了を提供せず、自身を終了すると Dock ごと消えるためになる。
- 未保存の書類の確認や拒否は対象アプリに任せる。Dock Studio は終了を要求しただけで、終了したとは表示しない。ステータスは「○○ に終了を要求しました」になる。
- 起動中の表示（点と一覧）は、既存の終了通知（`didTerminateApplication`）で更新する。アプリが拒否した場合やキャンセルされた場合は、起動中のまま残り、誤った状態を出さない。
- `terminate()` が全インスタンスで false を返した場合は、エラーメッセージを表示する。
- `bundle:` 形式の identity を持たない項目（`path:` 形式）は、「終了」の対象外にする。
- 同じ bundle identifier のインスタンスが複数あれば、すべてに要求する。

実装は `DockStudio/Services/ApplicationQuitter.swift` にある。`NSRunningApplication` への依存は `QuittableApplication` で差し替えられる。

## 検証

2026-10-18 に、ホストでビルドと単体テストだけを実行した。GUI は起動しておらず、実際のアプリも終了していない。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 114件すべて成功した（追加分 `ApplicationQuitTests` は11件） |
| Release ビルド | 成功した |
| `build-for-testing` | 成功した |

単体テストが縛る内容は次になる。

- 起動中のアプリに `terminate()` が1回だけ呼ばれる。
- 別のアプリ、終了済みのインスタンスには呼ばれない。
- Finder と自身、アプリ以外の項目は対象外になる。
- 拒否された場合はエラーを返し、要求した場合は「終了した」と表示しない。
- メニューの出し分けの判定（`canQuitApplication`）が、起動中でない項目と対象外の項目で false になる。
- 同じ bundle identifier の複数インスタンスのすべてに要求が届き、1つでも受理されれば `.requested` になる。

実画面の確認は、次の「実画面の確認」に書く。

## 撮影の手順

撮影は専任の担当が、専用のヘッドレス VM のゲストで行う。ホストでは行わない。

1. ゲストで Calculator を起動しておく。TextEdit など、ほかに撮影で使うアプリは、起動しないままにしておく。
2. 検証用データは空のディレクトリでよい（`DOCKSTUDIO_DATA_DIR=<空のディレクトリ>`）。既定のプロファイルで起動する。
3. Dock Studio を起動し、設定の「Dock」にある「実行中のアプリを表示」を有効にする。「起動中のアプリに点を表示」は別のトグルで、既定で有効になっている。
4. 「Custom Dock」の画面を開く。Dock Studio のウィンドウの中の Dock に、Calculator が出て、起動中の点が付いていることを確認する。デスクトップのパネルで撮る場合は、同じ画面の「デスクトップに Dock を表示」を押す。
5. Calculator のアイコンを右クリックする。メニューに「開く」「Finder で表示」「終了」が出る。
6. 「終了」を選ぶ。Calculator が終了し、Dock から消える。ステータス「Calculator に終了を要求しました」は、Custom Dock の画面のタイトル下（「アプリとウィジェットを、使う場面ごとにまとめます。」の下）に出る。ウィンドウの中の Dock を操作したときに確認する。デスクトップのパネルには出ないので、パネルでの撮影ではステータスを確認の対象にしない。
7. 比較として、未起動の対象のメニューを確認する。TextEdit をプロファイルに追加し（起動しない）、そのアイコンを右クリックして、「終了」が出ないことを確認する。または Calculator を終了した後、プロファイルに追加した Calculator を右クリックする。Finder の項目にも「終了」は出ない。
8. 拒否の確認が可能なら、TextEdit を起動して未保存の書類を作り、「終了」を選ぶ。TextEdit の保存確認が出ること、キャンセル後も Dock の点が残ることを確認する。

撮る画像と動画は次になる。

- 画像: 起動中の Calculator のメニュー（「終了」あり）、未起動のアプリのメニュー（「終了」なし）、Finder のメニュー（「終了」なし）、ステータス表示。
- 動画: 手順5から6まで（右クリック、終了、Dock の表示が変わるまで）。可能なら手順8の保存確認とキャンセルも撮る。

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `9e42bfe` の Release ビルドを macOS 26.6.2、1600×1000の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `0c9515167ccd6c72c6cd3e90164ac5b2f0b050dda24d359dc4b71cb4db67f048` と一致した。ホストの画面には何も表示していない。検証用データは、Finder、Safari、TextEdit（保持済みで未起動）を持つ新規プロファイルで、`showRunningApps` を有効にした `profiles.json` を使った。撮影手順の 2〜3 にある、設定画面で「実行中のアプリを表示」を有効にする操作は行っていない。

確認できたこと:

- 起動前の状態は[before.jpg](media/quit-app-from-menu/before.jpg)に保存した。保持済みの Finder、Safari、TextEdit（未起動）と、起動中の Calculator が並ぶ。
- 起動中の Calculator を右クリックすると、「開く」「Finder で表示」「終了」が出た（[menu-running-calculator.jpg](media/quit-app-from-menu/menu-running-calculator.jpg)）。一時表示の項目なので「Dock から取り外す」は出なかった。
- 「終了」を選ぶと、Calculator が終了して Dock から消えた。状態は、Custom Dock の画面のタイトル下に「Calculator に終了を要求しました」と出た（[after-quit-calculator.jpg](media/quit-app-from-menu/after-quit-calculator.jpg)）。操作の動画は[quit-running-app.mp4](media/quit-app-from-menu/quit-running-app.mp4)に保存した。メニューを出す、終了を選ぶ、Calculator が消える、TextEdit のメニュー、Finder のメニューまでを含む。撮影時刻の間隔を維持して15fps に変換し、倍速にはしていない。Dock と状態の表示を含む範囲に切り出している。
- 未起動の対象のメニュー（保持済みの TextEdit）には「終了」が出なかった。「開く」「Finder で表示」「Dock から取り外す」だけだった（[menu-not-running-textedit.jpg](media/quit-app-from-menu/menu-not-running-textedit.jpg)）。
- Finder のメニューにも「終了」は出なかった（[menu-finder.jpg](media/quit-app-from-menu/menu-finder.jpg)）。
- 未保存の書類を持つ TextEdit では、「終了」を選ぶと状態に「TextEdit に終了を要求しました」が出て、TextEdit に保存確認（"Do you want to keep this new document \"Untitled\"?"、ゲストの表示言語は英語）が出た（[textedit-save-sheet.jpg](media/quit-app-from-menu/textedit-save-sheet.jpg)）。キャンセルを選ぶと、TextEdit は起動中のまま残り、Dock の点も残った（[after-cancel-still-running.jpg](media/quit-app-from-menu/after-cancel-still-running.jpg)）。
- VoiceOver 用アクションは、AX API の確認用ツールで確かめた。起動中の Calculator と TextEdit のアクションに「終了」が含まれた。保持済みで未起動の TextEdit と Safari、Finder には含まれなかった（[ax-actions.txt](media/quit-app-from-menu/ax-actions.txt)）。VoiceOver は有効にしていない。

確認できなかったこと:

- `AXPerformAction` で「終了」を実行した結果は、試していない。
- 未保存の書類の確認で「保存しない」を選んで終了する場合と、保存して終了する場合は、撮影していない。
- TextEdit の保存確認のウインドウは、Dock Studio のウインドウの裏に隠れた。TextEdit を前面にするまで見えなかった。終了を要求したアプリを前面にする動作は、実装していない。

撮影手順との違い（結果への影響は小さい）:

- Dock Studio のウインドウの中の Dock で撮影した。デスクトップのパネルでは撮影していない。
- メニュー項目は、ゲスト内の CGEvent のクリックで選んだ。
- 保存確認を撮った TextEdit は、手順 7 で使った保持済みの項目を、右クリックの「Dock から取り外す」で外してから撮影した。取り外し後も起動中の一時表示として残った。
- 動画は、保存確認の場面を含まない。保存確認は静止画で記録した。
