# 他アプリの Dock 情報を取り込む方法の調査

調査日は 2026-10-17 になる。対象は GitHub issue #26、#27、#29、#41、#42、#43、#45 の7件で、いずれも「標準 Dock が持つアプリ連携を、DockStudio が他アプリに対して再現できるか」を調べる。

## この調査の範囲と限界

- 公開 API の実在は、Xcode の SDK ヘッダ（`MacOSX26.5.sdk`、ホスト macOS 26.5.2）で確認した。SDK は `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk` にある。
- Apple の公式ページ（`support.apple.com`）は WebFetch で本文を確認した。`developer.apple.com` の API ページは JavaScript で描画されるため取得せず、同じ内容が書かれている SDK ヘッダを一次情報とした。
- **専用ヘッドレス VM での観察は、今回できなかった。** VM の排他ロック（`/private/tmp/dockstudio-vm.lock`）を別のエージェントが 22:04 から 22:11 以降ずっと保持しており、約35分待っても取得できなかった。依頼の規定（最大30分）に従い、VM が必要な項目は「未確認」として記録した。ロックは取得していないので、解放もしていない。VM の設定には触れていない。
- ホスト上では、画面を表示しないコマンドライン検証だけを行った。ホストのデスクトップに検証用アプリや Dock は表示していない。
- 標準 Dock や他アプリの Dock 上の見た目、バッジ、バウンドの観察は、すべて未確認になる。本文中の「VM で確認する」は、実施していない作業を指す。
- 画像は撮影していない。`docs/media/research-app-integration/` は作っていない。

### VM で確認する予定だった内容（次の担当者向け）

検証用のソースは、スクラッチ領域に作成した。リポジトリには含めていない。ここに内容を記す。

| 検証物 | 内容 |
| --- | --- |
| DockAX | Dock プロセスの Accessibility ツリーを走査し、各 Dock 項目の role、subrole、`AXStatusLabel`、`AXURL`、`AXIsApplicationRunning`、全属性名、アクション名を出力する。`menu <タイトル>` で `AXShowMenu` を送り、現れたメニューを再帰的に出力して `AXCancel` で閉じる |
| ProbeApp | `PROBE` 環境変数で動作を選ぶ GUI アプリ。`badge`、`draw`（独自の contentView 描画）、`attention`、`recent`、`progress`、`applicationDockMenu` を持つ |
| ProgSub / ProgPub | `NSProgress` の購読側と公開側のコマンドライン。ホストで実行済み（#43 を参照） |

VM のゲストでは、`sshd-keygen-wrapper` に Accessibility と Screen Recording が許可されている（`/private/tmp/dockstudio-vm-tools/guest-capture-permissions.sql`）。そのため、ssh 経由で DockAX を実行できる見込みになる。ただし、ssh セッションが GUI セッションの Dock に接続できるかは、実行していないので未確認になる。

## 結論の一覧

| issue | 項目 | 結論 | 根拠の要点 |
| --- | --- | --- | --- |
| #26 | 最近使った書類 | 条件付きで可能（公開 API では不可、`.sfl4` の直接読みは非公開形式） | `recentDocumentURLs` は自アプリ分だけ。他アプリ分は `~/Library/Application Support/com.apple.sharedfilelist/` の `.sfl4` に保存されており、ホストの shell から読めた。形式は非公開で、サンドボックスでは読めない見込み |
| #27 | アプリ固有の Dock メニュー | 条件付きで可能（Accessibility 権限が必要） | `applicationDockMenu(_:)` は自アプリのためのデリゲート。他アプリからは Dock の AX ツリーに `AXShowMenu` を送る経路だけが現実的。未実測 |
| #29 | Open at Login | 条件付きで可能（状態の読み取りと変更で経路が違う） | `SMAppService.mainApp` は自アプリ専用。別アプリの登録 API は SDK に無い。設定画面を開く `openSystemSettingsLoginItems()` は公開 |
| #41 | 通知バッジ | 条件付きで可能（Accessibility 権限が必要、未実測） | `NSDockTile.badgeLabel` は自アプリ専用。他アプリ分は Dock の AX 項目の `AXStatusLabel` を読む経路になる。この属性名は SDK ヘッダに無い |
| #42 | 動的アイコン | 公開 API では不可（画面キャプチャで近似できる可能性あり） | `NSDockTile.contentView` は自アプリ専用。Calendar は `Calendar.docktileplugin` を使い、Dock 側のプロセスが描画する |
| #43 | ファイル進捗 | 実装可能（公開された進捗に限る） | `Progress.addSubscriber(forFileURL:)` が SDK に実在し、ホストで別プロセスの更新、完了、キャンセルを受信できた |
| #45 | 注意要求のバウンド | 未確認（公開 API では取得経路を確認できていない） | `requestUserAttention` は送信側だけ。取得側の API は SDK に無い。Dock の AX 属性に出るかは未実測 |

実装可能と分かった項目は #43 だけになる（公開された進捗に限る）。#26、#27、#29、#41 は、Accessibility などの追加許可を前提に条件付きで可能になる。

## 共通の前提

### 自アプリ向け API と他アプリの取得は別物

この7件の標準 Dock の機能は、どれも「アプリが Dock に情報を渡す API」と「Dock がその情報を表示する」という二段で動く。公開されているのは前者だけになる。DockStudio は後者の置き換えなので、他アプリが Dock に渡した情報を DockStudio が受け取る公開 API は、#43 の `Progress` を除いて SDK に存在しない。

### Accessibility 権限

Dock 自身の Accessibility ツリーを読む方法は、公開 API（`AXUIElement`）だけで書ける。ただし、次の制約がある。

- `AXIsProcessTrustedWithOptions` が true になる必要があり、利用者がシステム設定でアプリを許可する。許可は手動で、アプリ側から自動付与できない（`AXUIElement.h`）。
- Mac App Store のサンドボックスアプリは、Accessibility の許可を得られない。配布は Developer ID の公証付きになる。
- Accessibility は、全アプリの画面上の要素を読める強い権限になる。許可を求める時点で、読む対象（Dock だけ）と、読んだ情報を端末の外へ送らないことを利用者に説明する必要がある。
- Dock の AX ツリーの構造と属性は、Apple が文書化していない部分を含み、OS の更新で変わる可能性がある。ヘッダに定義があるのは、role（`kAXDockItemRole`）と subrole（`kAXApplicationDockItemSubrole` など）、`kAXIsApplicationRunningAttribute`、`kAXURLAttribute` までになる。
- 標準 Dock と自作 Dock が並ぶと、同じアプリの情報を二重に表示する。DockStudio が標準 Dock を隠す方針と両立するかは、別途決める必要がある。

SDK ヘッダで確認したコマンドを示す。

```
$ grep -n "kAXDockItemRole\|kAXApplicationDockItemSubrole\|kAXIsApplicationRunningAttribute\|kAXShowMenuAction" \
    .../HIServices.framework/Versions/A/Headers/AX*Constants.h
AXAttributeConstants.h:177:	kAXIsApplicationRunningAttribute
AXActionConstants.h:114:#define kAXShowMenuAction				CFSTR("AXShowMenu")
AXRoleConstants.h:381:#define kAXDockItemRole					CFSTR("AXDockItem")
AXRoleConstants.h:435:#define kAXApplicationDockItemSubrole		CFSTR("AXApplicationDockItem")
$ grep -rn "AXStatusLabel" .../ApplicationServices.framework   # 出力なし
```

### Dock に表示する必要があるアプリの情報は NSRunningApplication では取れない

`NSRunningApplication.h` の公開プロパティは、`isHidden`、`isActive`、`activationPolicy`、`localizedName`、`bundleIdentifier`、`icon`、`launchDate` などで、バッジ、注意要求、進捗、メニューに相当するものは無い（`NSRunningApplication.h` の `@property` を全件確認した）。

## #26 最近使った書類をアプリメニューから開く方法

### 結論

条件付きで可能。公開 API では他アプリの最近の書類を取得できない。

### 根拠

- `NSDocumentController.recentDocumentURLs` と `noteNewRecentDocumentURL(_:)` は SDK に実在する（`NSDocumentController.h` 237、241 行）。ヘッダの説明は「Open Recent メニューに現れる項目の URL を返す」で、対象は呼び出したアプリ自身になる。
- ホストで、コマンドラインプロセスから `NSDocumentController.shared.recentDocumentURLs` を呼ぶと、自プロセスの分だけが返り、他アプリの分は返らない。

```
$ ./Recent
own recentDocumentURLs: 0 max: 10
```

- 他アプリの最近の書類は、`~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/<bundle id>.sfl4` に保存されている。ホストでは84件のファイルがあり、`com.apple.TextEdit.sfl4` を読み取れた。構造は `NSKeyedArchiver` の plist で、`$objects` にブックマークを含む形になっている（キー名だけを確認し、中身は表示していない）。
- この `.sfl4` を扱う公開 API は見つからなかった。`LSSharedFileList` は SDK の `SharedFileList.framework/Headers/LSSharedFileList.h` に残るが、`kLSSharedFileListRecentDocumentItems` と関連関数は `API_DEPRECATED("No longer supported", macos(10.5, 10.11))`（96〜107 行）で、サポートされない。
- 標準 Dock のメニューに最近の書類が出ることは、Apple の説明で「Show Recents」というメニュー操作が書かれていることまでは確認した（`support.apple.com/en-gb/guide/mac-help/mh35859/26/mac/26`）。書類の一覧そのものを説明する記述はページに無かった。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| アプリごとの提供有無と取得経路を実測する | 一部のみ。`.sfl4` が存在し読めることと、`recentDocumentURLs` が自アプリ限定であることは実測した。アプリごとの提供有無（どのアプリが `.sfl4` を作るか）は、ホストの84件を数えただけで、アプリ別の検証は未実施 |
| 公開された共有手段と取得できない情報を区別する | 公開は自アプリの `recentDocumentURLs` のみ。他アプリ分は非公開形式（`.sfl4`）か、Accessibility で Dock のメニューを読む経路になる |
| 開く対象を検証し、文書履歴を無断で外部へ送らない | 方針のみ。履歴は端末内だけで使い、ネットワークへ送る実装を持たない。開く前に、ファイルの存在とバンドル内の関連付けを確認する（実装していない） |

### リスクと制約

- `.sfl4` の形式は非公開で、macOS の更新で変わる。実際に `.sfl3` から `.sfl4` に変わった形跡が、同じフォルダに残る `FavoriteVolumes.sfl3` と `.sfl4` の併存から読み取れる。
- 最近の書類の一覧は、利用者の文書名とパスを含むプライバシー情報になる。読み取りには、サンドボックスを外した配布が前提になる。ホストでは、shell から読めたが、そのプロセスが Full Disk Access を持っているかは確認していない。TCC の許可が要るかは未確認になる。
- 代替として、Dock のメニューを Accessibility で開き、標準 Dock が出す最近の書類を読む経路がある（#27 と同じ）。

### 残る未確認

- VM での標準 Dock の「最近の書類」表示の観察。
- TextEdit など、特定アプリで書類を開いたときの `.sfl4` の更新と、Dock メニューの一致。
- TCC の許可が無い状態での `.sfl4` の読み取り可否。

### 実装する場合の方針と工数の見立て

方針は、第一に自アプリの履歴（DockStudio が開いた書類）だけを `recentDocumentURLs` で出す。第二に、他アプリは Accessibility を許可した利用者だけに、Dock のメニューから取得する。工数は、第一が1日未満、第二は #27 の基盤を共有して2〜3日と見込む。

## #27 アプリ固有の Dock メニューを扱う方法

### 結論

条件付きで可能。他アプリの Dock メニューを読む公開 API は無く、Accessibility で標準 Dock に `AXShowMenu` を送る経路が候補になる。未実測。

### 根拠

- `applicationDockMenu(_:)` は `NSApplicationDelegate` のメソッドで、自アプリが Dock に出すメニューを返す（`NSApplication.h` 424 行）。他アプリのメニューを読む手段ではない。
- アプリが起動していない状態の Dock メニューは、`NSDockTilePlugIn` プロトコルの `dockMenu` で返す。プラグインは、システムのプロセスにログイン時または Dock への追加時に読み込まれる（`NSDockTile.h` 53〜66 行）。メニューの提供元はアプリまたはそのプラグインで、DockStudio には渡されない。
- Dock の項目には `AXShowMenu` アクションを送れる（`AXActionConstants.h` 114 行）。Dock 自身のプロセスが、メニューを描画して AX の子要素として公開するかどうかは、VM で未確認になる。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| Safari の新規ウィンドウと、メディアアプリの固有操作を代表例として確認する | 未確認。VM を使えなかった。issue 本文の観察（Finder の New Finder Window、Safari の New Window と New Private Window）を引用しているだけで、今回再確認していない |
| 自アプリがメニューを提供する API と、別アプリから読む手段を混同しない | 区別した。前者は `applicationDockMenu(_:)` と `NSDockTilePlugIn.dockMenu`、後者は Accessibility の `AXShowMenu` になる |
| 公開手段・権限・OS 差分と、取得できない場合の代替を記録する | 公開手段は `AXUIElement` と Accessibility 権限。OS 差分は未確認（macOS 15 から 26 の AX ツリー比較をしていない）。取得できない場合は、自作 Dock の固定メニュー（新規ウィンドウ、終了、Dock に残す）にする |

### リスクと制約

- メニューを読むには、標準 Dock の上にメニューを一度表示させる必要があり、画面に標準のメニューが見える。自作 Dock のメニューとして使うには、メニューを開いてすぐ閉じる処理が必要で、画面がちらつく可能性がある。
- メニュー項目の実行は、AX の `AXPress` を標準 Dock の項目に送る形になる。実行の対象が標準 Dock に存在することが前提で、標準 Dock から外したアプリは対象外になる。
- Accessibility の制約は「共通の前提」を参照する。

### 残る未確認

標準 Dock の項目に `AXShowMenu` を送ると、メニューが AX の子要素として読めるか。Options の下位メニューも読めるか。`AXCancel` で閉じられるか。macOS 15 から 26 の差分。

### 実装する場合の方針と工数の見立て

標準 Dock を隠す方針のため、`AXShowMenu` の可否を最初に確認する。可能なら、メニュー項目をキャッシュして自作 Dock で再描画する。工数は検証に1日、実装に3〜4日と見込む。不可なら、固定メニューを維持する。

## #29 アプリの Open at Login を扱う方法

### 結論

条件付きで可能。ただし、状態の確認と変更で必要な手段が異なる。公開 API で別アプリを登録できるものは確認できなかった。

### 根拠

- `SMAppService.mainApp` は、呼び出したアプリ自身をログイン時に起動する登録用で、`SMAppService.h` 87〜91 行に「main application as a LoginItem」と書かれている。
- `SMAppService.loginItem(identifier:)` は、自アプリのバンドル内にあるヘルパーを登録する（同ヘッダ 72〜81 行）。別アプリの登録には使えない。
- `statusForLegacyURL(_:)` が受け付ける URL は、`/Library/LaunchDaemons`、`/Library/LaunchAgents`、`/Users/$USER/Library/LaunchAgents` の下にある plist に限られる（同ヘッダ 251〜270 行）。アプリのログイン項目の状態は読めない。
- `SMAppService.openSystemSettingsLoginItems()` は、システム設定のログイン項目パネルを開く公開 API になる（同ヘッダ 273〜283 行）。
- `LSSharedFileList` のログイン項目の API（`kLSSharedFileListSessionLoginItems`）は `API_DEPRECATED_WITH_REPLACEMENT("Use a LaunchAgent, XPCService or the ServiceManagement APIs instead.", macos(10.5, 10.11))`（`LSSharedFileList.h` 129 行）で、サポートされない。
- ホストで `sfltool dumpbtm` を実行すると、バックグラウンドタスク管理（BTM）のレコードが出力される。標準 Dock の Open at Login は、このデータベースに記録される見込みだが、Dock が何を書くかは未確認になる。`dumpbtm` は診断用のコマンドで、読み取りの公開 API ではない。
- Apple の Mac ユーザガイド「Open items automatically when you log in」には、Dock の Options 経由の設定の記載が無く、システム設定の「ログイン項目」で追加する手順（Add ボタン）だけが書かれていた。標準 Dock の Options > Open at Login は、issue 本文の観察が根拠になる。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 標準 Dock での Open at Login の条件を確認する | 未確認。Apple の文書に記載が無く、VM も使えなかった。条件（Dock に残すアプリのみ対象か、など）は不明 |
| 自アプリの登録 API を、別アプリを登録できる API と混同しない | 区別した。`SMAppService` は自アプリとその同梱ヘルパー限定で、別アプリを登録する公開 API は SDK に無かった |
| 登録状態の確認・変更に使える経路と権限、設定への案内を記録する | 設定への案内は `SMAppService.openSystemSettingsLoginItems()`（公開）。別アプリの状態確認は、`sfltool dumpbtm`（診断用、書式は非公開）か、System Events の AppleScript（Automation 権限、未検証）か、Dock の AX メニュー（未検証）になる。別アプリの変更は、公開 API では確認できなかった |

### リスクと制約

- 別アプリのログイン項目を、利用者の操作なしに変更する手段を実装するのは避ける。設定の変更は、システム設定への案内にとどめるのが安全になる。
- Dock の AX メニューで Open at Login を押す方法は、標準 Dock の操作を代行する形で、利用者の許可（Accessibility）を前提とする。ログイン時に起動するアプリが増えるのは、利用者のセキュリティとプライバシーに影響するため、実行前の確認表示が必要になる。

### 残る未確認

- 標準 Dock の Open at Login が出る条件と、書き込む先。
- System Events の `login items` が使えるか、Automation の許可ダイアログが出るか。
- AX 経由で Options > Open at Login を読み、状態を取得できるか。

### 実装する場合の方針と工数の見立て

方針は、DockStudio 自身のログイン時起動を `SMAppService.mainApp` で提供し、他アプリは「システム設定を開く」メニュー項目を出す。工数は、自アプリ分が0.5日、案内メニューが0.5日と見込む。別アプリの状態表示は、AX の検証結果に依存し、検証に1日が必要になる。

## #41 アプリの通知バッジを取得して表示する方法

### 結論

条件付きで可能。Accessibility で標準 Dock の項目を読む経路が候補になるが、未実測である。公開 API で他アプリのバッジを取得する手段は、確認できなかった。

### 根拠

- `NSDockTile.badgeLabel` は、アプリ自身が Dock アイコンに表示する文字列を設定するプロパティになる。ヘッダの説明は「Badge the dock icon with a localized string ... often used to show an unread count」（`NSDockTile.h` 41 行）。読み取りは自アプリの `NSApp.dockTile` だけになる。
- `UNUserNotificationCenter.setBadgeCount(_:)` も、自アプリのバッジを設定する API である（`UNUserNotificationCenter.h` 77 行、macOS 13 以降）。
- Apple の説明では、赤いバッジは「you need to take one or more actions in an app or System Settings」を示す（`support.apple.com/en-gb/guide/mac-help/mh35859/26/mac/26`）。
- Dock の AX 項目に `AXStatusLabel` 属性があり、バッジの文字列が入ることは、広く使われている実装知識になるが、`ApplicationServices.framework` のヘッダには定義が無い（`grep -rn AXStatusLabel` の出力なし）。VM で実測するまで、この属性の存在は未確認とする。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 標準 Dock での文字列・数字・点の代表例を確認する | 未確認。VM を使えなかった。点は、DockStudio 自身の「起動中の点」が現状あるが、通知バッジの点とは別になる |
| NSDockTile の自アプリ向け API と、他アプリのバッジ取得を区別する | 区別した。`NSDockTile.badgeLabel` は自アプリ専用で、他アプリ分は Dock の AX 項目を読む経路になる（未実測） |
| 公開手段、権限、更新頻度、表示できない条件と代替を記録する | 公開手段は `AXUIElement`（Accessibility 権限）。更新頻度は、`AXObserver` の通知が Dock から届くか、ポーリングが必要か未確認。表示できない条件は、アプリが Dock に無い場合、権限が無い場合、Dock が自動非表示の場合（AX の値は読めるかもしれないが未確認）。代替は、バッジなしの起動中の点のみ表示 |

### リスクと制約

- バッジの文字列は、メールの未読数など、利用者のプライバシーに関わる情報になる。DockStudio 内の表示にとどめ、保存とログ出力をしない。
- 通知センターのデータベース（`~/Library/Group Containers/group.com.apple.usernoted/` 以下）を読む方法は、Full Disk Access が必要で、Apple が保護している領域のため、採らない。
- Accessibility の制約は「共通の前提」を参照する。

### 残る未確認

標準 Dock の `AXStatusLabel` の存在と値の形式（数字、文字列、点）。`AXObserver` で変更を購読できるか。標準 Dock を隠した場合に値が更新されるか。

### 実装する場合の方針と工数の見立て

方針は、Accessibility を許可した利用者に限り、Dock の項目を読んでバッジを表示する。許可が無い場合は、バッジなしで動作する。工数は検証に0.5日、実装に2〜3日と見込む。優先度は P1 のため、最初に `AXStatusLabel` を VM で確認する。

## #42 動的なアプリアイコンの更新を反映する方法

### 結論

公開 API では不可。画面キャプチャによる近似が可能な場合があるが、権限とプライバシーの制約が大きい。

### 根拠

- `NSDockTile.contentView` と `display()` は、アプリ自身の Dock タイルを描画する API で、他アプリの描画を取得する手段は無い（`NSDockTile.h` 27〜33 行）。
- Calendar は、実行していないときの日付表示を `NSDockTilePlugIn` のプラグインで行う。`Info.plist` の `NSDockTilePlugIn` は `Calendar.docktileplugin`、実体は `/System/Applications/Calendar.app/Contents/Resources/Calendar.docktileplugin` にあることを確認した。時計アプリにも `/System/Applications/Clock.app/Contents/PlugIns/ClockDockTile.docktileplugin` がある。

```
$ /usr/libexec/PlistBuddy -c "Print :NSDockTilePlugIn" /System/Applications/Calendar.app/Contents/Info.plist
Calendar.docktileplugin
$ find /System/Applications/Calendar.app -name "Calendar.docktileplugin" -maxdepth 4
/System/Applications/Calendar.app/Contents/Resources/Calendar.docktileplugin
$ ls /System/Applications/Clock.app/Contents/PlugIns
AppKitBridge.bundle  ClockDockTile.docktileplugin  WorldClockWidget.appex
```

- `NSDockTile.h` の説明では、このプラグインは「システムのプロセスにログイン時または Dock への追加時に読み込まれる」。つまり、描画はアプリのプロセスではなく Dock 側の環境で行われ、DockStudio からプロセス間通信で取得する公開経路は無い。
- 画面キャプチャの経路は、`CGWindowListCopyWindowInfo`（`kCGWindowOwnerName`）と `CGPreflightScreenCaptureAccess`、`CGRequestScreenCaptureAccess` が SDK に実在する（`CGWindow.h`）。Dock のウィンドウを撮影して、標準 Dock の描画を切り出すことは技術的に考えられる。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| Calendar 等と独自描画する検証アプリで、静的アイコンとの差を確認する | 未確認。検証アプリ（ProbeApp の `draw`）は作成したが、VM を使えず実行していない。Calendar のプラグインが存在する事実は、ホストで確認した |
| 別アプリの描画を受け取れる公開手段と制約を整理する | 公開手段は無し。近似として、画面収録の許可を得て標準 Dock のタイル領域を撮影する方法がある。権限は Screen Recording で、画面全体の内容を読める強い権限になる |
| 取得不可時の静的表示を明示し、外観加工と情報更新の関係を決める | 方針案として、取得できない場合はインストール先の静的アイコンに外観加工を適用して表示し、バッジなどの情報は #41 の経路で別に重ねる。動的アイコンを取得できた場合、外観加工は取得画像に適用できないため、加工を適用せず原画のまま表示するか、加工を諦めるかを決める必要がある |

### リスクと制約

- 画面キャプチャは、標準 Dock を画面に表示し続ける必要がある。標準 Dock を隠す DockStudio の方針と衝突する可能性が高い。
- Screen Recording の許可は、ほかのウィンドウの内容も読める。利用者の同意の画面と、Dock の領域以外を保存しない実装が必須になる。
- 描画されたタイルは、バッジを含むかどうかが未確認で、バッジと二重に表示されるおそれがある。

### 残る未確認

- 標準 Dock のウィンドウが `CGWindowList` に現れるか。
- Calendar など、プラグイン描画のタイルが、標準 Dock の Accessibility や画面キャプチャで取れるか。
- 標準 Dock を隠した状態でも、キャプチャが可能か。

### 実装する場合の方針と工数の見立て

実装は推奨しない。情報の更新は #41（バッジ）に絞り、動的アイコンは静的表示にする案を、仮の方針とする。画面キャプチャの検証だけに1〜2日が必要になる。

## #43 ファイル転送などの進捗表示を連携する方法

### 結論

実装可能。ただし対象は、`Progress` を `publish()` しているファイル操作に限る。他アプリが公開していない進捗は、取得できない。

### 根拠

- `Progress.addSubscriber(forFileURL:withPublishingHandler:)` が SDK に実在する（`NSProgress.h` 231 行、macOS 10.9 以降）。ヘッダの説明は「ファイルの進捗の通知を受け取る。`NSProgressFileURLKey` が購読した URL と同じ項目、または直下の項目を指す `NSProgress` に `publish()` が呼ばれたときにブロックが呼ばれる」。
- `isOld`（`NSProgress.h` 241 行）は、購読前に公開された進捗かを示す。ヘッダに「Dock does not animate file icon flying when this method returns YES」とあり、標準 Dock が同じ仕組みを使っていることが書かれている。
- `fileOperationKind` に、`downloading`、`decompressingAfterDownloading`、`receiving`、`copying`、`uploading`、`duplicating` の6種類がある（`NSProgress.h` 273〜278 行）。
- Apple のドキュメント `Progress.isOld` のページを、issue の根拠として参照する。API ページの本文は取得できなかったため、ヘッダの記述を一次情報とした。

ホストで、購読側（`ProgSub`）と公開側（`ProgPub`）を別プロセスのコマンドラインとして実行し、完了、失敗相当、キャンセルを確認した。画面は表示していない。

```
##### finish
PUB: published ... PUB: 100%  PUB: unpublish (finish)
253.90 subscribed to .../dl
253.94 PUBLISHED kind=nil url=nil old=true total=100 frac=0.7 desc=Downloading “file.bin”…
254.36   fraction=0.8 completed=80 cancelled=false
255.38   fraction=1.0 completed=100 cancelled=false
255.38 UNPUBLISHED completed=100/100 fraction=1.0 cancelled=false
##### fail
PUB: published ... PUB: 50%  PUB: unpublish (fail)
269.49 PUBLISHED kind=nil url=nil old=false total=100 frac=0.0 desc=Downloading “file.bin”…
270.33   fraction=0.5 completed=50 cancelled=false
270.33 UNPUBLISHED completed=50/100 fraction=0.5 cancelled=false
##### cancel
PUB: published ... PUB: cancellationHandler called  PUB: 50%  PUB: isCancelled
277.07 PUBLISHED kind=nil url=nil old=false total=100 frac=0.0 desc=Downloading “file.bin”…
279.17 calling cancel()
279.53   fraction=0.5 completed=50 cancelled=true
279.53 UNPUBLISHED completed=50/100 fraction=0.5 cancelled=true
```

この出力から分かったことは次のとおりになる。

- 別プロセスの更新が、購読側に `fractionCompleted` の変化として届く。
- 完了（100% で unpublish）は、`UNPUBLISHED` ブロックが `fraction=1.0` で呼ばれる。
- 失敗は、公開側が途中で `unpublish()` するだけの場合、購読側は `fraction=0.5` の `UNPUBLISHED` を受け取る。完了との区別は、最終の割合でしかつかず、エラー情報は届かない。
- キャンセルは、購読側が `cancel()` を呼ぶと、公開側の `cancellationHandler` が呼ばれ、購読側の `isCancelled` が true になる。
- 購読側のプロキシでは、`fileOperationKind` と `fileURL` が nil になっていた。`localizedDescription`（「Downloading “file.bin”…」）には種類が反映される。種類で処理を分けたい場合は、`localizedDescription` ではなく別の手段が必要になる。ここは測定上の制約として残る。
- 最初の実行では `old=true` かつ `frac=0.7` で届いた。購読開始の前に公開が始まっていた場合は、途中の状態から始まる（レベルトリガー）。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| Apple のファイル進捗の公開機構と、アプリ独自の進捗表示を区別する | 区別した。公開機構は `Progress.publish()` と `addSubscriber(forFileURL:)`。独自の進捗表示は、各アプリが `NSDockTile` の `contentView` に描く方法で、他アプリからは取得できない |
| 取得可能な進捗について更新・完了・失敗・キャンセルを確認する | 確認した（ホスト上の自作の公開側との間）。更新、完了、キャンセルは取得できた。失敗は完了と区別できない（上記） |
| 他アプリが公開していない進捗を取得できると約束せず、対応範囲を示す | 約束しない。対象は `Progress.publish()` を使う操作に限る。Finder のコピーや Safari のダウンロードが公開しているかは、VM で未確認 |

### リスクと制約

- 購読には、監視する URL（フォルダ）の指定が必要になる。全体を一括で監視する API は無い。ダウンロードフォルダ、デスクトップ、ホームなど、監視対象を DockStudio が決める必要がある。
- サンドボックス下のアプリが、ユーザーのフォルダの進捗を購読できるかは未確認になる。
- 進捗の元のアプリと、Dock のどの項目に表示するかの対応付けは、`Progress` に提供元アプリの情報が無いため、公開 API では確定できない。進捗はダウンロードフォルダなどの項目として表示するか、アプリとの対応は付けない設計になる。
- 購読は、ファイル名を含む情報を受け取る。表示以外に保存しない。

### 残る未確認

- Finder のコピー、Safari のダウンロード、Mail の添付保存で、`Progress` が公開されるか。
- 実際の標準 Dock の進捗アニメーション（アイコン上のリング）の観察。
- サンドボックス下のアプリでの購読の可否。

### 実装する場合の方針と工数の見立て

方針は、設定で選んだフォルダ（既定はダウンロード）を購読し、進捗をダウンロードフォルダの項目に重ねて表示する。完了とキャンセルは、`UNPUBLISHED` の割合と `isCancelled` で判定する。工数は、購読の実装に1〜2日、表示に2日と見込む。実装前に、Finder と Safari の公開有無を VM で1日かけて確認する。

## #45 注意要求によるアイコンのバウンドを連携する方法

### 結論

未確認。SDK で確認できる公開 API には、他アプリの注意要求を取得する手段が無い。標準 Dock の AX 項目に属性が現れるかは、未実測になる。

### 根拠

- `NSApplication.requestUserAttention(_:)` と `cancelUserAttentionRequest(_:)` は、自アプリが Dock に注意を引く要求を送り、解除する API になる（`NSApplication.h` 269〜276 行）。種類は `NSCriticalRequest = 0` と `NSInformationalRequest = 10` の2つ。ヘッダの説明は「call this method only if your application is not already active」で、アプリがアクティブなときは効かない。
- `NSRunningApplication.h` の公開プロパティに、注意要求の状態は無い（前述のとおり全件確認）。
- Dock の AX 項目の属性名は、ヘッダに定義が無い（バッジの `AXStatusLabel` と同じ事情）。注意要求中の状態が属性に出るかは、VM で実測する必要がある。
- 他アプリの注意要求を観察する唯一の公開に近い手段は、画面キャプチャで標準 Dock のバウンドを検出する方法になるが、確実さに欠け、#42 と同じ権限の問題を持つ。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 起動時のバウンドと情報・重大な注意要求を区別して確認する | 未確認。VM を使えなかった。API 上は、`NSCriticalRequest`（解除されるまでバウンド）と `NSInformationalRequest`（1回バウンド）が区別される。この挙動は、Apple の API ドキュメントの記述に基づくが、今回は取得できず、実測していない |
| 別アプリの要求を取得できる公開経路と取得不可の範囲を記録する | 公開経路は見つからなかった。取得不可の範囲は、公開 API 全般。AX 経由は未実測 |
| Reduce Motion、通知の抑制、要求解除、頻度制限の方針を決める | 方針案として、Reduce Motion が有効なときはバウンドを避け、色やリングによる静止した表示にする。集中モードなどで通知が抑制されているときは、表示も抑える。要求の解除は、対象アプリがアクティブになった時点で消す。バウンドの頻度は、同じアプリに対して一定間隔（例 10 秒）に1回までとする。いずれも案であり、実装も検証もしていない |

### リスクと制約

- 注意要求の取得方法が確認できない以上、取得できるとは約束しない。
- 標準 Dock がバウンドを行うため、DockStudio が標準 Dock を隠す場合は、自作 Dock の上で同等の注意の表現が必要になる。

### 残る未確認

標準 Dock の AX 項目に、注意要求中を示す属性や子要素があるか。`AXObserver` で変化を受け取れるか。`NSCriticalRequest` と `NSInformationalRequest` の見た目の差。Reduce Motion 有効時の標準 Dock の挙動。

### 実装する場合の方針と工数の見立て

取得経路が見つかるまで、実装は始めない。VM の検証で AX に現れることが分かった場合は、#41 と同じ基盤（Dock の AX を観察する仕組み）に載せて、1〜2日で追加できる見込みになる。

## 横断の所見

- #26、#27、#29、#41、#45 は、いずれも標準 Dock の Accessibility ツリーが読めるかどうかに依存する。最初に VM で `DockAX` を実行し、属性とメニューが取れるかを確認すると、5件の判断を一度に進められる。
- Accessibility と Screen Recording は、どちらも利用者に強い許可を求める。標準 Dock の情報の再表示のためにこれらを求めることが、DockStudio の価値に見合うかは、本体の判断が必要になる。
- #43 は、追加許可なしで実装できる唯一の項目で、先に着手しやすい。

## 検証の再現手順

`DockAX`、`ProbeApp`、`ProgSub`、`ProgPub` のソースは、スクラッチ領域（リポジトリの外）に作成した。次回の担当者が必要なら、この文書の「VM で確認する予定だった内容」の表を元に作り直す。ホストで実行した #43 の出力は、本文に掲載したものがすべてになる。
