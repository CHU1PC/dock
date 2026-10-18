# ログイン・再起動後の Custom Dock の復元

issue #61 の実装になる。DockStudio 自身のログイン時の起動と、Custom Dock の表示状態の復元に限る。別のアプリをログイン項目へ登録する機能は含まない（公開 API が無い。`research/APP_INTEGRATION.md` の #29 の節を参照）。

## 仕様

設定画面の「一般」に、「ログイン時の起動」を追加した。スイッチを入れると、`SMAppService.mainApp.register()` で DockStudio をログイン項目に登録し、切ると `unregister()` で解除する。登録の状態は OS が持つ。DockStudio は保存せず、設定画面を開くたびに `status` を読み直す。システム設定で利用者が切った場合も、画面に反映される。

Dock の表示状態（`DockStore.isDockVisible`）は、変更のたびに `launch-state.json` へ保存し、起動時に復元する。保存先は `profiles.json` と同じ場所になる。

- 表示中に終了またはログアウトした場合は、次回の起動で表示する。
- 「Dock を隠す」などで隠した場合は、隠した状態を保存し、次回も隠したままにする。
- 自動非表示の設定、アクティブなプロファイル、位置などは、従来どおり `profiles.json` に保存されており、そのまま復元される。
- ファイルが無い場合（以前のバージョンからの更新、初回の起動）は、従来どおり非表示で起動する。`profiles.json` と `appearance.json` の形式は変えていない。
- ファイルが壊れている場合は、非表示で起動し、設定画面の「ログイン時の起動」に理由を表示する。次に表示状態を変えた時点で、正しいファイルに置き換わる。
- 保存に失敗した場合も、同じ場所に理由を表示する。

### 制約

- ログインで起動すると、Dock を出すために、スタジオのウィンドウも開く。Custom Dock のウィンドウ制御がスタジオのウィンドウの表示に結び付いているためで、ウィンドウを開かずに Dock だけを出す形は #86 で扱う。
- 「Apple Dock」モード（`DockMode.native`）へ切り替えると、既存の処理が `isDockVisible = false` にするため、非表示が保存される。再起動後に「両方」へ戻しても、Dock は非表示のままになる。表示するには、メニューバーの「Custom Dock を表示」を使う。

状況の説明は次のとおり。

| 状態 | 画面の表示 |
| --- | --- |
| 登録済み | スイッチが入る。メッセージなし |
| 未登録、またはシステム設定で無効化 | スイッチが切れる。メッセージなし |
| 登録したが、システム設定で未許可（`requiresApproval`） | スイッチが入り、許可が必要な旨と「システム設定を開く」ボタンを表示する |
| ログイン項目として登録できないビルド（`notFound`） | スイッチが切れ、登録できない旨を表示する |
| 登録または解除が失敗 | 失敗した操作と OS のエラー文を表示する |

## 実装

- `Services/LoginItemController.swift`: `LoginItemService`（`SMAppService` と同じ `status`、`register`、`unregister`）を定義し、`SMAppService` を適合させた。`LoginItemController` が状態とメッセージを持ち、システム設定を開く操作（`openSystemSettings()`）も持つ。画面は `ServiceManagement` を直接使わない。
- `Services/LaunchRestorePersistence.swift`: `launch-state.json`（`{"dockVisible": true}` の形）の読み書き。
- `Store/DockStore.swift`: `isDockVisible` の変更時に保存し、`init` で復元する。`loginItem` を `init` の引数で差し替えられる。
- `SettingsPreview.swift`: 「一般」にスイッチとメッセージを追加した。

## 検証

2026-10-18 にホストで実行した。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 115件すべて成功（追加は `LoginRestoreTests` の10件） |
| Release ビルド | 成功した |
| `build-for-testing` | 成功した |

`LoginRestoreTests` は、`SMAppService` の代わりに記録用の偽物を使い、`register` と `unregister` の呼び出し回数、失敗時のメッセージ、`requiresApproval` と `notFound` の扱い、外部変更の反映を確かめる。保存は、再起動後の復元（表示と非表示）、自動非表示とアクティブなプロファイルの保持、ファイルなし、壊れたファイル、書き込めない保存先、`profiles.json` を書き換えないことを確かめる。**ホストでは `register()` を実行していない。**

### 未検証

- 実際のログインと再起動での自動起動と、Dock の表示の復元。
- `SMAppService.mainApp` の実際の登録、解除、`requiresApproval` の表示。署名なしのビルド（`CODE_SIGNING_ALLOWED=NO`）で登録が成功するかは未確認。
- ログインで起動した際に、スタジオのウィンドウが開くこと。Custom Dock のウィンドウ制御は、スタジオのウィンドウの `.task` で作られるため、ウィンドウが開かない起動の形にすると Dock が出ない。現在のウィンドウは自動で開く設定のため、動くはずだが、実機では確認していない。
- macOS 15 から 25 での挙動。

## 撮影の手順

専用のヘッドレス VM（ゲストは macOS 26.6.2、1600×1000）で行う。ホストでは行わない。VM では登録を実行してよい。VM を使う前に `/private/tmp/dockstudio-vm.lock` を取り、終えたら解放する。

### 用語

- ssh: `cd /private/tmp/dockstudio-vm-tools && ssh -F ssh-config dockstudio-verification '<コマンド>'`。ゲストのユーザーは `admin`。以降は `GUEST '<コマンド>'` と書く。
- VNC: `127.0.0.1:55900`（パスワードは `~/Library/Application Support/DockStudioVerification/guest-vnc-password`）。画像と動画は VNC 経由で撮る。ssh 経由の `screencapture` は失敗する（`research/APP_INTEGRATION.md`）。
- 画面の表記は `SettingsPreview.swift` と `WorkspaceView.swift` に合わせる。設定画面の左のメニューは「Dock」「外観」「ウィジェット」「一般」。ウィンドウ上部の切替は「Custom Dock」「設定」「プロファイル」。モードの切替は「Apple Dock」「Custom Dock」「両方」。「Dock」の「動作」に「使用していないときに隠す」のスイッチがある。メニューバーのアイコン（`square.stack.3d.up.fill`）のメニューに「Custom Dock を表示」と「Custom Dock を隠す」がある。Dock 上の右クリックには「Dock を隠す」がある。

### 準備

1. ホストで Release ビルドを作り、ゲストの `/Applications` に置く。
   ```
   nice -n 15 xcodebuild -project DockStudio.xcodeproj -scheme DockStudio -configuration Release -derivedDataPath /tmp/dockstudio-61-derived CODE_SIGNING_ALLOWED=NO build
   ditto -c -k --keepParent /tmp/dockstudio-61-derived/Build/Products/Release/DockStudio.app /tmp/dockstudio-61-app.zip
   scp -F /private/tmp/dockstudio-vm-tools/ssh-config /tmp/dockstudio-61-app.zip dockstudio-verification:/tmp/
   GUEST 'cd /tmp && rm -rf DockStudio.app && ditto -x -k dockstudio-61-app.zip . && rm -rf /Applications/DockStudio.app && mv DockStudio.app /Applications/'
   ```
   `/Applications` に置けない場合は `~/Applications` でよい。以降のパスは置いた場所に読み替える。署名は付いていない（`CODE_SIGNING_ALLOWED=NO`）。登録で署名の問題が出たら、`GUEST 'codesign --force --deep -s - /Applications/DockStudio.app'` で ad-hoc 署名してから試す。この場合は、署名したことを撮影の記録に書く。
2. 検証用データを作る。`DOCKSTUDIO_DATA_DIR` は、`profiles.json` を置くディレクトリになる。空でよい（初回の起動で既定のプロファイルが作られる）。`launch-state.json` と `appearance.json` も同じ場所に作られる。
   ```
   GUEST 'rm -rf ~/dock61-data && mkdir -p ~/dock61-data'
   ```
3. 手順 1 から 5 は、検証用データで起動する。環境変数付きで起動する。
   ```
   GUEST 'killall DockStudio 2>/dev/null; sleep 1; open -n --env DOCKSTUDIO_DATA_DIR=/Users/admin/dock61-data /Applications/DockStudio.app'
   ```
4. **ログインで自動起動したアプリは、環境変数を引き継がない**。ログインで起動したアプリは、既定の保存先 `~/Library/Application Support/DockStudio` を使う。そのため、再ログインを撮る手順 4 以降は、既定の保存先で通して行う。切り替えは次の順序にする。
   1. 手順 1 から 3 の確認が終わったら、アプリを終了する（`GUEST 'killall DockStudio'`）。
   2. `GUEST 'rm -rf "$HOME/Library/Application Support/DockStudio"'` で、既定の保存先を空にする。
   3. 環境変数なしで起動する: `GUEST 'open -n /Applications/DockStudio.app'`。
   4. 以降の手順（スイッチを入れる、Dock を表示する、再ログインする）は、この起動から始める。

### 操作と期待する見え方

1. 検証用データで起動し（準備 3）、ウィンドウ上部の「設定」を開き、左のメニューの「一般」を開く。「ログイン時の起動」のスイッチが切れていて、メッセージは出ていない。**画像 1**。
2. 準備 4 の切り替えを行う。「一般」の「ログイン時に Dock Studio を開く」を入れる。スイッチは入ったままになる。ゲストのシステム設定の「一般」の「ログイン項目と機能拡張」に Dock Studio が現れる（開き方: `GUEST 'open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"'`）。**画像 2**（アプリの設定画面と、システム設定の両方）。
   - 登録は、`SMAppService.mainApp.register()` が呼ばれる。署名なしのビルドでは、次のどれかになる。どの結果になったかを、撮影の記録に必ず書く。
     - 成功し、項目が現れる（想定）。
     - 成功するが `requiresApproval` になり、スイッチは入ったまま、「システム設定の『ログイン項目』で Dock Studio を許可してください。」と「システム設定を開く」ボタンが出る。許可する前の状態を **画像 4** に撮り、ボタンを押してシステム設定が開くことも撮る。システム設定で許可して、設定画面を開き直すと、メッセージが消える。
     - 失敗する。スイッチは切れたまま、「ログイン項目の登録に失敗しました。…」と OS のエラー文が出る。**画像 4** の代わりに、この表示を撮る。ad-hoc 署名や `/Applications` への配置で通るかを試し、通った方法を記録する。
   - `requiresApproval` を意図的に再現したい場合は、システム設定のログイン項目で Dock Studio をいったん切ってから、アプリで入れ直す。環境や OS により再現しないことがある。再現しなければ、画像 4 は「未撮影」と記録する。表示は単体テストで確認している。
3. 「Dock」で「使用していないときに隠す」を入れる。メニューバーのアイコンから「Custom Dock を表示」を選ぶ。モードが「Apple Dock」の場合は、「両方」か「Custom Dock」に変える。画面の端に Custom Dock が出る。
4. **再ログインして、復元を確認する。** 次のどれかで、ゲストをログアウトする。
   - 推奨: `GUEST 'osascript -e "tell application \"System Events\" to log out"'`。確認のダイアログが出た場合は、VNC で「ログアウト」を押す（`vncdotool` の `move` と `click 1`）。
   - 代替: `GUEST 'launchctl bootout gui/$(id -u)'`。ssh のセッションが切れる場合がある。
   - ログイン画面が出たら、VNC でゲストのパスワードを入力してログインする（`vncdotool type` と `key enter`）。自動ログインが設定されている場合は、再ログインは自動で行われる。
   ログイン後、Dock Studio が自動で起動し、Custom Dock が表示されたままになる。自動非表示の設定と、プロファイルも同じ。**動画 1**（ログアウトの直前から、Dock が出るまで）。
   - 「アプリを終了して、`open` で再起動する」だけで代えた場合は、保存と復元の確認にはなるが、**ログイン項目による自動起動の確認にはならない**。その場合は、そう書いて、動画 1 の題にも「再起動のみ」と明記する。
5. Custom Dock を右クリックして「Dock を隠す」を選ぶ。もう一度、手順 4 の方法で再ログインする。Dock Studio は起動するが、Dock は隠れたままになる（メニューバーに「Custom Dock を表示」が出る）。**動画 2**。
6. システム設定のログイン項目で Dock Studio を切る。Dock Studio の設定画面の「一般」を開き直す（別の項目を開いてから戻る）と、スイッチが切れている。**画像 3**。
7. 手順 2 の `requiresApproval` または失敗の表示。**画像 4**。
8. 壊れた保存データを撮る。`GUEST 'killall DockStudio; echo "not json" > "$HOME/Library/Application Support/DockStudio/launch-state.json"; open -n /Applications/DockStudio.app'`。Dock は隠れ、「一般」の「ログイン時の起動」に「前回の Dock の表示状態を読み込めなかったため、非表示で起動しました。」が出る。**画像 5**。撮影後に `GUEST 'rm "$HOME/Library/Application Support/DockStudio/launch-state.json"'`。

### 撮影の方法

- 画像: VNC で 1600×1000 の静止画を撮る（`vncdotool -s 127.0.0.1::55900 -p <パスワード> capture <出力.png>`）。設定画面は、ウィンドウが映るように撮る。
- 動画: `vncdotool` の録画（`record`）が使える場合は、15 fps、実時間で撮る。ログアウトとログインの間の画面は、数十秒かかるため、待ち時間を含めてよい。実時間の動画が撮れない場合は、1 秒ごとに `capture` した静止画の連番（`frame-0001.png` から）を、撮影時刻の間隔を保ったまま `ffmpeg -framerate 1 -i frame-%04d.png -vf fps=15 out.mp4` で動画にする。この場合は、連番であることと、1 秒間隔であることを、PR の本文に書く。
- 保存先は `docs/media/restore-dock-after-login/` にする。

### 撮るもの

| 番号 | 内容 |
| --- | --- |
| 画像 1 | 切れた状態の「ログイン時の起動」（「設定」の「一般」） |
| 画像 2 | 入れた状態の設定画面と、システム設定のログイン項目 |
| 画像 3 | システム設定で切った後の設定画面 |
| 画像 4 | 未許可、または登録失敗のメッセージ（再現できた方。両方できなければ未撮影と記録） |
| 画像 5 | 壊れた保存データのメッセージ |
| 動画 1 | 再ログイン後に、Dock が表示されたまま復元される様子 |
| 動画 2 | 隠した状態が、再ログイン後も保たれる様子 |
