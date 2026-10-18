# 他アプリの Dock 情報を取り込む方法の調査

調査日は 2026-10-17（VM の観察は 2026-10-18）になる。対象は GitHub issue #26、#27、#29、#41、#42、#43、#45 の7件で、いずれも「標準 Dock が持つアプリ連携を、DockStudio が他アプリに対して再現できるか」を調べる。2026-10-18 の更新では、issue の現行受け入れ条件と `origin/main` の `9e26408` までの実装を照合した。#43 は CLOSED のため今回の担当対象から除いた。今回の作業では VM を使わず、過去の観察記録とリポジトリのコードだけを確認した。

## この調査の範囲と限界

- 公開 API の実在は、Xcode の SDK ヘッダ（`MacOSX26.5.sdk`、ホスト macOS 26.5.2）で確認した。SDK は `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk` にある。
- Apple の公式ページ（`support.apple.com`）は WebFetch で本文を確認した。`developer.apple.com` の API ページは JavaScript で描画されるため取得せず、同じ内容が書かれている SDK ヘッダを一次情報とした。
- 専用ヘッドレス VM（macOS 26.6.2）での観察は、2回目の作業（2026-10-18）で実施した。1回目は VM のロックを取れず、未確認のまま記録した。観察の記録は次の節「VM での観察結果」に、各 issue の節にはその結果を反映した最終的な結論を書いた。
- ホスト上では、画面を表示しないコマンドライン検証だけを行った。ホストのデスクトップに検証用アプリや Dock は表示していない。
- 画像は保存できなかった。ssh 経由の `screencapture` が `could not create image from display`（および `could not create image from rect`）で失敗した。`docs/media/research-app-integration/` は作っていない。画面の撮影は、既存の VNC 経由の録画ツールで行う必要がある。
- 実行した作業は、ロックを保持した10分以内に収めた。終了後にゲストのアプリと一時ファイル（`~/probe`、`~/Downloads/probe-progress`、`~/probe-recent.txt`）を削除し、ロックを解放した。VM の設定は変更していない。

### 検証物の内容

検証用のソースは、スクラッチ領域に作成した。リポジトリには含めていない。ここに内容を記す。

| 検証物 | 内容 |
| --- | --- |
| DockAX | Dock プロセスの Accessibility ツリーを走査し、各 Dock 項目の role、subrole、`AXStatusLabel`、`AXURL`、`AXIsApplicationRunning`、全属性名、アクション名を出力する。`menu <タイトル>` で `AXShowMenu` を送り、現れたメニューを再帰的に出力して `AXCancel` で閉じる |
| ProbeApp | `PROBE` 環境変数で動作を選ぶ GUI アプリ。`badge`、`draw`（独自の contentView 描画）、`attention`、`recent`、`progress`、`applicationDockMenu` を持つ |
| ProgSub / ProgPub | `NSProgress` の購読側と公開側のコマンドライン。ホストと VM で実行済み（#43 を参照） |

VM のゲストでは、`sshd-keygen-wrapper` に Accessibility と Screen Recording が許可されている（`/private/tmp/dockstudio-vm-tools/guest-capture-permissions.sql`）。ssh 経由で DockAX を実行し、`AXIsProcessTrusted: true` で GUI セッションの Dock の AX を読めることを確認した。

## VM での観察結果（2026-10-18）

ゲストは macOS 26.6.2、1600×1000。ssh 経由で、ホストでビルドした `DockAX` と `Probe.app`（ad-hoc 署名）、`ProgSub` を実行した。

### Dock の AX 項目（#41、#45、#26、#27、#29 の共通基盤）

```
AXIsProcessTrusted: true
ITEM 'Probe' role=AXDockItem subrole=AXApplicationDockItem running=1 statusLabel=42 url=file:///Users/admin/probe/Probe.app/
ATTRS: ["AXRole", "AXRoleDescription", "AXSubrole", "AXTitle", "AXParent", "AXChildren", "AXPosition", "AXSize", "AXFrame",
 "AXTopLevelUIElement", "AXSelected", "AXShownMenuUIElement", "AXStatusLabel", "AXProgressValue", "AXURL", "AXIsApplicationRunning"]
ACTIONS: ["AXPress", "AXShowMenu", "AXShowExpose"]
```

- 標準 Dock の既定のアプリ項目は `AXStatusLabel = nil` だった（バッジなし）。自作アプリが `badgeLabel = "42"` を設定すると `42` になった（#41）。
- `AXProgressValue` という属性が一覧に存在する。ただし `NSProgress` を公開して購読側に更新が届いている間も、Probe 項目の値は nil のままだった。この属性がいつ値を持つかは未確認。
- Dock の項目には、`AXShownMenuUIElement`、`AXURL`、`AXIsApplicationRunning` がある。

### Dock メニュー（#26、#27、#29）

`AXShowMenu` の結果は 0（成功）で、メニューが AX の子要素として読めた。`AXCancel` も 0 で、メニューを閉じられた。

```
=== MENU Probe（自作アプリ。PROBE=recent で最近の書類を登録し、applicationDockMenu を実装）
  - [AXMenuItem] 'probe-recent.txt'
  - [AXMenuItem] 'Probe Custom Action'
  - [AXMenuItem] 'Probe Second Action'
  - [AXMenuItem] 'Options'
    - 'Keep in Dock' / 'Open at Login' / 'Show in Finder'
  - 'Show All Windows' / 'Hide' / 'Hide Others' / 'Quit' / 'Force Quit'
=== MENU Safari と Calendar（起動していない標準アプリ）
  - [AXMenuItem] 'Options' -> 'Remove from Dock' / 'Open at Login' / 'Show in Finder'
  - 'Show Recents' / 'Open' / 'Force Quit'
```

- アプリ固有のメニュー項目（#27）と最近の書類（#26）は、Dock の AX メニューから文字列として取得できた。
- Safari と Calendar のメニューには、固有の操作は出なかった。標準アプリで確認できたのは、`Show Recents` と `Open` である。issue 本文にある Safari の New Window などは、アプリが起動していない状態では出ない。起動後の表示は未確認。
- `Open at Login` はメニュー項目として存在する（#29）。`AXMenuItemMarkChar` は nil で、チェック状態は取得できなかった。ゲストの設定は変更していない。
- `Show Recents` の下位の書類一覧と、アプリ固有メニューの実行（`AXPress`）は、今回は実施していない。

### 注意要求（#45）

`PROBE=attention`（`NSCriticalRequest`、起動の3秒後、アプリは非表示）で、1秒ごとに Probe 項目の `AXFrame` を取った。

```
t=1 AXFrame y:1000.00   t=3 y:987.238   t=4 y:1000.00   t=5 y:919.720
t=6 y:1000.00           t=7 y:908.357   t=8 y:1000.00   t=9 y:927.861   t=10 y:1000.0
```

- 要求中は、y が 1000（静止位置）と、それより小さい値の間を往復した。バウンドが AX の位置として観測できる。
- `AXStatusLabel`、`AXProgressValue` に注意要求を示す値は出なかった。注意要求を直接示す属性は、属性一覧に無い。
- 1秒間隔の標本のため、バウンドの周期と回数は測れていない。`NSInformationalRequest`（1回だけ）と、起動時のバウンドとの区別は、今回は確認していない。

### ファイル進捗（#43）

`PROBE=progress` の GUI アプリ（`Progress` を `publish()`）を `~/Downloads/probe-progress` に対して購読した。

```
542.82 subscribed to /Users/admin/Downloads/probe-progress
543.06 PUBLISHED kind=nil url=nil old=false total=100 frac=0.0 desc=Downloading “file.bin”…
543.55   fraction=0.1 completed=10 cancelled=false
...
548.04   fraction=1.0 completed=100 cancelled=false
548.04 UNPUBLISHED completed=100/100 fraction=1.0 cancelled=false
```

- GUI アプリからの公開も、別プロセスの購読側に届いた。ホストの CLI の結果と一致する。
- 購読は、指定した URL の直下の項目だけを対象にする。最初の試行は、`~/Downloads` を購読して `~/Downloads/probe-progress/file.bin` を公開したため、何も届かなかった。監視対象のフォルダの設計に影響する。
- Finder のコピーと Safari のダウンロードが `Progress` を公開するかは、今回確認していない。

### 動的アイコン（#42）

- Calendar の Dock 項目の AX 属性に画像は無い（`AXRole`、`AXTitle`、`AXFrame`、`AXURL` など）。他アプリの描画内容を取る AX 経路は確認できなかった。
- `draw`（独自 contentView）の描画の取得は、ssh 経由の `screencapture` が失敗したため、検証できなかった。

### 今回も確認できなかったこと

- 画面の撮影（画像と動画）。
- Finder、Safari、Mail の `Progress` 公開。
- `Show Recents` の下位メニューの中身と、メニュー項目の `AXPress` による実行。
- Open at Login の登録状態の読み取り、System Events の AppleScript、`sfltool dumpbtm` との照合。
- macOS 15 から 25 の差。
- `NSInformationalRequest` と Reduce Motion。

## 結論の一覧

| issue | 項目 | 結論（2回目の更新後） | 根拠の要点 |
| --- | --- | --- | --- |
| #26 | 最近使った書類 | 条件付きで可能（Accessibility で Dock メニューを読む。`.sfl4` の直接読みは非公開形式） | VM で、Dock の `AXShowMenu` から開いたメニューに自作アプリの最近の書類（`probe-recent.txt`）が現れた。公開の `recentDocumentURLs` は自アプリ分だけ（実測）。Safari と Calendar は「Show Recents」というサブメニュー相当の項目で、中身の取得は未確認 |
| #27 | アプリ固有の Dock メニュー | 条件付きで可能（Accessibility が必要） | VM で、自作アプリの `applicationDockMenu` の項目（Probe Custom Action、Probe Second Action）が、Dock の AX メニューに読めた。`AXCancel` で閉じられた |
| #29 | Open at Login | 条件付きで可能（状態の読み取りは未確認、変更は設定への案内が公開） | VM で Dock の Options に `Open at Login` があることを AX で確認（Safari、Calendar、自作アプリ）。チェック状態を示す属性は取れず、登録状態の読み取りは未確認。別アプリを登録する公開 API は SDK に無い |
| #41 | 通知バッジ | 条件付きで可能（Accessibility が必要） | VM で、自作アプリが `badgeLabel = "42"` を設定すると、Dock の AX 項目の `AXStatusLabel` が `42` になった（`AXStatusLabel` は SDK ヘッダに無い属性名。Dock の属性一覧には存在する） |
| #42 | 動的アイコン | 公開 API では不可（未検証の近似手段のみ） | 他アプリの描画を取る公開 API は無い。Dock の AX 属性にも画像は無い。画面キャプチャは ssh 経由で失敗し、検証できなかった |
| #43 | ファイル進捗 | 実装可能（公開された進捗に限る） | `Progress.addSubscriber(forFileURL:)` で、ホストと VM の GUI アプリから別プロセスへ更新、完了、キャンセルが届いた。Finder と Safari の公開は未確認 |
| #45 | 注意要求のバウンド | 条件付きで可能（Accessibility で Dock 項目の `AXFrame` を観察。属性としての注意状態は無い） | VM で、`NSCriticalRequest` 中の Dock 項目の `AXFrame` の y が 1000 と 987〜908 の間を往復した。バウンドは AX の位置変化として観測できる。専用の属性は一覧に無い |

実装可能と分かった項目は #43（公開された進捗に限る）。Accessibility を許可した利用者には、#26、#27、#41、#45 を Dock の AX から取得できる見込みが VM で確認できた。#29 は状態の読み取りが残る。

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
$ grep -rn "AXStatusLabel" .../ApplicationServices.framework   # 出力なし（VM の Dock 項目の属性一覧には存在する）
```

### Dock に表示する必要があるアプリの情報は NSRunningApplication では取れない

`NSRunningApplication.h` の公開プロパティは、`isHidden`、`isActive`、`activationPolicy`、`localizedName`、`bundleIdentifier`、`icon`、`launchDate` などで、バッジ、注意要求、進捗、メニューに相当するものは無い（`NSRunningApplication.h` の `@property` を全件確認した）。

## #26 最近使った書類をアプリメニューから開く方法

### 結論

条件付きで可能。公開 API では、他アプリの最近の書類を取得できない。Accessibility を許可した利用者に限り、標準 Dock のメニューから読める。

### 現在の DockStudio（origin/main `9e26408`）

- 最近使った未固定アプリを最大3件表示し、起動したアプリの履歴を保存・復元する（`DockStudio/Store/DockStore.swift:278-289`、`DockStudio/Store/DockStore+RecentApps.swift:18-30`）。これはアプリ履歴であり、最近使った書類の取得・表示ではない。
- 他アプリの書類履歴を読む Dock の AX メニュー連携と、書類を開く操作は実装されていない。この判断はコード確認によるもので、画面上の挙動は今回確認していない。

### 根拠

- `NSDocumentController.recentDocumentURLs` と `noteNewRecentDocumentURL(_:)` は SDK に実在する（`NSDocumentController.h` 237、241 行）。ヘッダの説明は「Open Recent メニューに現れる項目の URL を返す」で、対象は呼び出したアプリ自身になる。ホストでコマンドラインプロセスから呼ぶと、自プロセスの分だけが返った（`own recentDocumentURLs: 0 max: 10`）。
- 他アプリの最近の書類は、`~/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/<bundle id>.sfl4` に保存されている。ホストには84件あり、`com.apple.TextEdit.sfl4` を shell から読めた。`NSKeyedArchiver` の plist で、ブックマークを含む（キー名だけを確認し、中身は表示していない）。この形式を扱う公開 API は無い。`LSSharedFileList` の recent 系は `API_DEPRECATED("No longer supported", macos(10.5, 10.11))`（`LSSharedFileList.h` 96〜107 行）になっている。
- VM で、自作アプリが `noteNewRecentDocumentURL` に登録した `probe-recent.txt` が、Dock の項目に `AXShowMenu` を送って開いたメニューの先頭項目として、AX から文字列で読めた（「VM での観察結果」を参照）。
- 標準アプリの Safari と Calendar（起動していない状態）のメニューには、書類名ではなく `Show Recents` という項目が出た。書類の一覧は、この項目の下位に出ると考えられるが、開いていない。
- Apple の Mac ユーザガイド（`support.apple.com/en-gb/guide/mac-help/mh35859/26/mac/26`）には、Dock のショートカットメニューから「Show Recents」などを選ぶ記述がある。書類の一覧そのものの説明は無かった。

### 受け入れ条件ごとの確認結果

| 受け入れ条件 | 結果 |
| --- | --- |
| アプリごとの提供有無と取得経路を実測する | 一部のみ確認。取得経路は2つ実測した。（1）Dock の AX メニュー（自作アプリで書類名を取得できた）。（2）`.sfl4`（ホストで読める。形式は非公開）。アプリごとの提供有無は、自作アプリ、Safari、Calendar だけを見た。Safari と Calendar は `Show Recents` の項目が出るまでで、下位の書類一覧は取得していない。TextEdit など書類アプリでの比較は未実施 |
| 公開された共有手段と取得できない情報を区別する | 確認した。公開された手段は、自アプリの `recentDocumentURLs` だけ（実測）。他アプリの履歴は、公開 API では取得できない。取得できる経路は、非公開形式の `.sfl4` と、Accessibility による Dock メニューの読み取りになる |
| 開く対象を検証し、利用者の文書履歴を無断で外部へ送らない | 実装していないため、方針のみ。履歴は端末内の表示だけに使い、ネットワークへ送る処理を持たない。開く前に、AX メニューで得た名前と対応する実体（`.sfl4` のブックマークまたはメニュー項目の `AXPress`）を照合する。この方針の検証は未実施 |

### リスクと制約

- `.sfl4` の形式は非公開で、macOS の更新で変わる。同じフォルダに `FavoriteVolumes.sfl3` と `.sfl4` が併存しており、過去に形式が変わった形跡がある。
- 最近の書類の一覧は、文書名とパスを含むプライバシー情報になる。`.sfl4` の読み取りには、サンドボックスを外した配布が前提になる。ホストでは shell から読めたが、そのプロセスが Full Disk Access を持っているかは確認していない。
- Dock メニュー経由の取得は、Accessibility の制約に従う（「共通の前提」を参照）。メニューを開くため、標準 Dock の上にメニューが一瞬表示される。

### 残る未確認

- `Show Recents` の下位メニューの中身と、そこから書類を開く操作（`AXPress`）。
- TextEdit など書類アプリで書類を開いたときの、`.sfl4` と Dock メニューの一致。
- TCC の許可が無い状態での `.sfl4` の読み取り可否。
- macOS 15 から 25 での差。
- 標準 Dock の「最近の書類」表示の画像（撮影できなかった）。

### 実装する場合の方針と工数の見立て

第一に、DockStudio が開いた書類を `recentDocumentURLs` で出す（1日未満）。第二に、Accessibility を許可した利用者に限り、Dock のメニューから他アプリの書類を取得する（#27 と同じ基盤で2〜3日）。`.sfl4` の直接読みは、形式が非公開のため採らない。

他アプリの書類を Dock メニュー経由で表示・実行する実装は、フォローアップ issue #128 で扱う。

## #27 アプリ固有の Dock メニューを扱う方法

### 結論

条件付きで可能。他アプリのメニューを読む公開 API は無い。Accessibility を許可した利用者に限り、標準 Dock の項目へ `AXShowMenu` を送ってメニューを読める。VM で、自作アプリのメニュー項目の取得を確認した。

### 現在の DockStudio（origin/main `9e26408`）

- DockStudio の各項目には、固定の独自コンテキストメニューを表示する（`DockStudio/CustomDockPreview.swift:269-273`）。項目の状態に応じて、開く、Finder で表示、隠す、他を隠す、終了、強制終了、Dock への追加・削除を実行する（同 `399-416`）。
- 別アプリが標準 Dock に提供した固有メニューを読み取る処理は見つからなかった。現行の固定メニューは代替手段に当たる。この判断はコード確認によるもので、メニューの画面表示やちらつきは今回確認していない。

### 根拠

- `applicationDockMenu(_:)` は `NSApplicationDelegate` のメソッドで、自アプリが Dock に出すメニューを返す（`NSApplication.h` 424 行）。起動していないアプリは、`NSDockTilePlugIn` の `dockMenu` で返す（`NSDockTile.h` 53〜66 行）。どちらも提供する側で、DockStudio には渡されない。
- VM で、Dock の項目に `AXShowMenu`（`AXActionConstants.h` 114 行）を送ると、結果は 0（成功）で、メニューが AX の子要素として読めた。自作アプリの `applicationDockMenu` が返した `Probe Custom Action` と `Probe Second Action` を、文字列で取得できた。`AXCancel` も 0 で、メニューを閉じられた。
- 標準のメニュー部分も読めた。`Options`（`Keep in Dock`、`Open at Login`、`Show in Finder`）、`Show All Windows`、`Hide`、`Hide Others`、`Quit`、`Force Quit` が出た。
- 起動していない Safari と Calendar のメニューは、`Options`（`Remove from Dock`、`Open at Login`、`Show in Finder`）、`Show Recents`、`Open`、`Force Quit` だった。issue 本文にある Safari の New Window などは、この状態では出なかった。

### 受け入れ条件ごとの確認結果

| 受け入れ条件 | 結果 |
| --- | --- |
| Safari などの新規ウィンドウと、メディアアプリなどの固有操作を代表例として確認する | 一部のみ確認。起動していない Safari と Calendar のメニューは確認した（固有の操作は出なかった）。起動後の Safari の New Window、New Private Window は未確認。メディアアプリ（Music など）の固有操作も未確認。自作アプリの固有項目の取得は確認した |
| 自アプリがメニューを提供する API と、別アプリから読む手段を混同しない | 確認した。提供する側は `applicationDockMenu(_:)` と `NSDockTilePlugIn.dockMenu`。読む側は Accessibility の `AXShowMenu`。後者で前者の項目が読めることを、自作アプリで確認した |
| 公開手段・権限・OS 差分と、取得できない場合の代替を記録する | 公開手段は `AXUIElement`、権限は Accessibility（ゲストでは `AXIsProcessTrusted: true`）。OS 差分は macOS 26.6.2 でだけ確認し、15 から 25 は未確認。取得できない場合の代替は、自作 Dock の固定メニュー（新規ウィンドウ、終了、Dock に残す）にする |

### リスクと制約

- メニューを読むには、標準 Dock の上にメニューを表示させる必要がある。自作 Dock のメニューにするには、開いてすぐ閉じる処理が要り、ちらつく可能性がある（ちらつきの程度は未測定）。
- 項目の実行は、標準 Dock のメニュー項目への `AXPress` になる。今回は実行していない。標準 Dock から外したアプリは対象外になる。
- Accessibility の制約は「共通の前提」を参照する。

### 残る未確認

- メニュー項目の `AXPress` による実行。
- 起動後の Safari と、メディアアプリの固有操作。
- ちらつきの有無と、標準 Dock を隠した状態での動作。
- macOS 15 から 25 での AX メニューの差。
- 画像（撮影できなかった）。

### 実装する場合の方針と工数の見立て

標準 Dock をアプリ項目ごとに `AXShowMenu` で開き、メニューを読み取ってキャッシュし、自作 Dock で描画する。実行は `AXPress` を標準 Dock に送る。工数は、実行とちらつきの検証に1日、実装に3〜4日と見込む。Accessibility が無い場合は、固定メニューを維持する。

他アプリの固有メニューを取得・実行する実装は、フォローアップ issue #129 で扱う。

## #29 アプリの Open at Login を扱う方法

### 結論

条件付きで可能。ただし、状態の読み取りは確認できていない。別アプリを登録する公開 API は SDK に無く、公開されているのはシステム設定を開く API になる。

### 現在の DockStudio（origin/main `9e26408`）

- `LoginItemController` は `SMAppService.mainApp` の状態を読み、自アプリを登録・解除する（`DockStudio/Services/LoginItemController.swift:27-52`）。他アプリの状態を読み取る処理はない。
- 同コントローラーはシステム設定のログイン項目パネルを開ける（同 `40-42`）。対象アプリの選択状態を読み取ったり、別アプリを登録・解除したりする処理は実装されていない。
- PR #126 では、DockStudio 自身がログイン起動されたときにスタジオ画面を抑制し、Dock だけを表示する挙動が追加された（`DockStudio/DockStudioApp.swift:28-38`、`DockStudio/Services/LoginLaunchPolicy.swift:4-17`）。これは他アプリの `Open at Login` の状態取得や操作ではない。

### 根拠

- `SMAppService.mainApp` は呼び出したアプリ自身の登録用で、`SMAppService.loginItem(identifier:)` は自アプリのバンドル内ヘルパー用になる（`SMAppService.h` 72〜91 行）。別アプリの登録には使えない。
- `statusForLegacyURL(_:)` が受け付ける URL は、`/Library/LaunchDaemons`、`/Library/LaunchAgents`、`/Users/$USER/Library/LaunchAgents` の下の plist に限られる（同 251〜270 行）。アプリのログイン項目の状態は読めない。
- `SMAppService.openSystemSettingsLoginItems()` は、システム設定のログイン項目パネルを開く公開 API になる（同 273〜283 行）。
- `LSSharedFileList` のログイン項目の API は `API_DEPRECATED_WITH_REPLACEMENT(... macos(10.5, 10.11))`（`LSSharedFileList.h` 129 行）で、サポートされない。
- VM で、標準 Dock のメニューの `Options` の下に `Open at Login` があることを AX で確認した（自作アプリ、起動していない Safari と Calendar）。自作アプリでは `Keep in Dock`、標準アプリでは `Remove from Dock` と並ぶ。項目は enabled=1 で、`AXMenuItemMarkChar` は nil だった。登録済みかどうかを示す値は、取得できなかった。ゲストの設定は変更していない。
- ホストの `sfltool dumpbtm` は、バックグラウンドタスク管理（BTM）の記録を出力する診断用のコマンドで、読み取りの公開 API ではない。標準 Dock が `Open at Login` の登録先に何を使うかは確認していない。
- Apple の Mac ユーザガイド（`support.apple.com/guide/mac-help/mh15189/26/mac/26`）には、Dock の Options 経由の設定の記載は無く、システム設定の「ログイン項目」で Add ボタンから追加する手順が書かれている。

### 受け入れ条件ごとの確認結果

| 受け入れ条件 | 結果 |
| --- | --- |
| 標準 Dock での Open at Login の条件を確認する | 一部のみ確認。`Options` の下に項目があること（アプリが Dock に残っているかどうかにかかわらず、起動していない標準アプリと、起動中の自作アプリで出る）を確認した。登録済みのときの表示（チェックの有無）と、Dock に残していないアプリでの表示は未確認 |
| 自アプリの登録 API を、別アプリを登録できる API と混同しない | 確認した。`SMAppService` は自アプリと同梱ヘルパー限定。別アプリを登録できる公開 API は SDK に無かった。 |
| 登録状態の確認・変更に使える経路と権限、設定への案内を記録する | 設定への案内は `SMAppService.openSystemSettingsLoginItems()`（公開、権限不要）。変更の経路は、公開 API では確認できなかった（Dock の AX メニューで `Open at Login` を `AXPress` する案があるが、ゲストの設定を変えないため実行していない）。状態の確認は、AX では取得できず、`sfltool dumpbtm`（診断用、書式は非公開）と System Events の AppleScript（Automation 権限）は照合していない。記録できた権限は、Accessibility（メニュー項目の存在の確認）まで |

### リスクと制約

- 別アプリのログイン項目を、利用者の操作なしに変更しない。変更は、システム設定への案内にとどめるのが安全になる。
- Dock の AX メニューの `Open at Login` を押す方法は、標準 Dock の操作の代行になり、利用者の同意と実行前の確認表示が必要になる。ログイン時に起動するアプリが増えるのは、セキュリティとプライバシーに影響する。

### 残る未確認

- `Open at Login` の登録状態の読み取り（チェック表示）。
- Dock に残していないアプリでの表示。
- AX での `AXPress` による変更と、その結果が `sfltool dumpbtm` にどう記録されるか。
- System Events の `login items` の可否と、Automation の許可ダイアログ。
- macOS 15 から 25 での差。

### 実装する場合の方針と工数の見立て

DockStudio 自身のログイン時起動を `SMAppService.mainApp` で提供する（0.5日）。他アプリは、メニューに「システム設定のログイン項目を開く」を出す（0.5日）。他アプリの状態の表示は、読み取り経路が未確認のため、実装の前に1日の検証が必要になる。

他アプリのログイン項目設定へ案内する実装は、フォローアップ issue #130 で扱う。状態表示は読み取り経路の確認後に別途判断する。

## #41 アプリの通知バッジを取得して表示する方法

### 結論

条件付きで可能。Accessibility を許可した利用者に限り、標準 Dock の項目の `AXStatusLabel` を読める。VM で、自作アプリのバッジ `42` の取得を確認した。

### 現在の DockStudio（origin/main `9e26408`）

- DockStudio に他アプリの `AXStatusLabel` を読む処理や、バッジを Custom Dock に表示する処理は見つからなかった。
- Native Dock Tile の終了処理では、自アプリのタイルに設定したバッジを消去する（`DockStudio/Services/NativeDockTileController.swift:121-134`）。これは他アプリのバッジ取得を示すものではない。この判断はコード確認によるもので、画面表示は今回確認していない。

### 根拠

- `NSDockTile.badgeLabel`（`NSDockTile.h` 41 行）と `UNUserNotificationCenter.setBadgeCount(_:)`（`UNUserNotificationCenter.h` 77 行）は、自アプリのバッジを設定する API で、他アプリの値は読めない。
- 他アプリの値は、標準 Dock の AX 項目の `AXStatusLabel` に出る。`AXStatusLabel` は SDK ヘッダに定義が無い（`grep -rn AXStatusLabel` の出力なし）。一方で VM では、Dock 項目の属性一覧に `AXStatusLabel` があり、自作アプリで `badgeLabel = "42"` を設定すると `statusLabel=42` が取得できた。標準アプリの項目は `nil` だった。
- ヘッダに無い属性のため、将来の macOS で名前や形式が変わる可能性がある。
- Apple の説明では、赤いバッジは「you need to take one or more actions in an app or System Settings」を示す（`support.apple.com/en-gb/guide/mac-help/mh35859/26/mac/26`）。

### 受け入れ条件ごとの確認結果

| 受け入れ条件 | 結果 |
| --- | --- |
| 標準 Dock での文字列・数字・点の代表例を確認する | 一部のみ確認。数字（`42`）と、バッジなし（`nil`）は AX の値で確認した。文字列の例と、点（数なしの要求）は未確認。標準アプリ（Mail、Messages など）の実バッジも、VM に通知が無いため未確認。見た目の画像は撮影できなかった |
| NSDockTile の自アプリ向け API と、他アプリのバッジ取得を区別する | 確認した。`badgeLabel` は自アプリ専用。他アプリ分は、Dock の AX の `AXStatusLabel` から読む |
| 公開手段、権限、更新頻度、表示できない条件と代替を記録する | 公開手段は `AXUIElement`、権限は Accessibility。`AXStatusLabel` は属性名が非公開。更新頻度は未確認（`AXObserver` の通知の有無とポーリング間隔は測っていない）。表示できない条件は、Accessibility が無い場合、アプリが Dock に無い場合、属性の変更。代替は、バッジなしで起動中の点だけを表示する |

### リスクと制約

- バッジの文字列は、メールの未読数など、利用者のプライバシーに関わる情報になる。DockStudio 内の表示にとどめ、保存とログ出力をしない。
- 通知センターのデータベース（`~/Library/Group Containers/group.com.apple.usernoted/` 以下）は、Full Disk Access が必要で、Apple が保護している領域のため、採らない。
- Accessibility の制約は「共通の前提」を参照する。

### 残る未確認

- 文字列のバッジと点（数なし）の AX での値。
- 更新の頻度と、`AXObserver` で変更を購読できるか。
- 標準 Dock を隠した状態で値が更新され続けるか。
- macOS 15 から 25 での差。
- 画像（撮影できなかった）。

### 実装する場合の方針と工数の見立て

Accessibility を許可した利用者に限り、Dock の項目の `AXStatusLabel` を読んで、自作 Dock にバッジを表示する。許可が無い場合は、バッジなしで動作する。属性名が非公開のため、値が取れない場合の表示（バッジなし）を既定にする。工数は、更新方式（ポーリングまたは購読）の確認に0.5日、実装に2日と見込む。優先度は P1 のため、#26、#27、#45 と共通の AX 基盤から先に作る。

他アプリのバッジを取得して表示する実装は、フォローアップ issue #131 で扱う。

## #42 動的なアプリアイコンの更新を反映する方法

### 結論

公開 API では不可。他アプリの描画を取る手段は、公開 API にも Dock の AX 属性にも見つからなかった。画面キャプチャによる近似は、検証できていない。

### 現在の DockStudio（origin/main `9e26408`）

- アイコンは対象アプリのファイル URL から `NSWorkspace.shared.icon(forFile:)` で取得し、選択中の外観に応じて加工・キャッシュする（`DockStudio/Services/DockAppearanceRendering.swift:37-55`）。他アプリの Dock Tile の描画を取り込む処理は見つからなかった。
- 現状は静的なファイルアイコンを使う設計であり、取得不能時の表示方針と整合する。この判断はコード確認によるもので、Calendar などの動的描画との差は今回観察していない。

### 根拠

- `NSDockTile.contentView` と `display()` は、アプリ自身のタイルを描画する API で、他アプリの描画を取得する手段は無い（`NSDockTile.h` 27〜33 行）。
- Calendar は、`Info.plist` の `NSDockTilePlugIn` が `Calendar.docktileplugin` で、実体は `/System/Applications/Calendar.app/Contents/Resources/Calendar.docktileplugin` にある。Clock にも `ClockDockTile.docktileplugin` がある。プラグインは、システムのプロセスに、ログイン時または Dock への追加時に読み込まれる（`NSDockTile.h` 53 行）。描画は、アプリが起動していなくても行われる。
- VM で Calendar の Dock 項目の属性を全件出した。属性は `AXRole`、`AXRoleDescription`、`AXSubrole`、`AXTitle`、`AXParent`、`AXChildren`、`AXPosition`、`AXSize`、`AXFrame`、`AXTopLevelUIElement`、`AXSelected`、`AXShownMenuUIElement`、`AXStatusLabel`、`AXProgressValue`、`AXURL`、`AXIsApplicationRunning` で、画像や描画内容を返すものは無かった。
- 画面キャプチャの公開 API は SDK にある（`CGWindowListCopyWindowInfo`、`CGPreflightScreenCaptureAccess`、`CGRequestScreenCaptureAccess`、`CGWindow.h`）。ただし VM では、ssh 経由の `screencapture` が `could not create image from display` で失敗し、Dock の描画を取れるかを検証できなかった。

### 受け入れ条件ごとの確認結果

| 受け入れ条件 | 結果 |
| --- | --- |
| Calendar 等と独自描画する検証アプリで、静的アイコンとの差を確認する | 未確認。独自描画の検証アプリ（`PROBE=draw`）は VM で起動したが、画面を撮影できなかったため、静的アイコンとの差を確認していない。Calendar のプラグインが存在することと、AX 属性に描画が無いことは確認した |
| 別アプリの描画を受け取れる公開手段と制約を整理する | 確認した。公開 API と Dock の AX 属性に、他アプリの描画を受け取る手段は無い。近似手段は、画面収録の許可（Screen Recording）による Dock のウィンドウの撮影で、全画面を読める強い権限になる。この手段の可否は未検証 |
| 取得不可時の静的表示を明示し、外観加工と情報更新の関係を決める | 方針として決めた。取得できない場合は、インストール先の静的アイコンに外観加工を適用して表示する。情報の更新は、#41 のバッジと #43 の進捗を別に重ねて示し、動的アイコンの代わりにする。動的アイコンの画像が取れた場合は、外観加工を適用せず原画で表示する案があるが、取得経路が無いため実装しない。方針は設計上の判断で、動作の検証はしていない |

### リスクと制約

- 画面キャプチャは、標準 Dock を画面に表示し続ける必要がある。標準 Dock を隠す DockStudio の方針と衝突する可能性が高い。
- Screen Recording の許可は、ほかのウィンドウの内容も読める。Dock の領域以外を保存しない実装と、同意の表示が必須になる。

### 残る未確認

- 画面キャプチャで標準 Dock のタイルを取れるか（ssh 経由は失敗。GUI セッション内のプロセスでの確認が要る）。
- 独自描画アプリと Calendar の、静的アイコンとの見た目の差。
- 標準 Dock を隠した状態でのキャプチャ。
- 画像（撮影できなかった）。

### 実装する場合の方針と工数の見立て

実装しない。動的アイコンは静的表示とし、情報の更新は #41 と #43 で補う。画面キャプチャの検証だけを行う場合は、1〜2日と見込む。

## #43 ファイル転送などの進捗表示を連携する方法

### 結論

実装可能。ただし対象は、`Progress` を `publish()` しているファイル操作に限る。他アプリが公開していない進捗は、取得できない。

### 根拠

- `Progress.addSubscriber(forFileURL:withPublishingHandler:)` が SDK に実在する（`NSProgress.h` 231 行、macOS 10.9 以降）。ヘッダの説明は「`NSProgressFileURLKey` が購読した URL と同じ項目、または直下の項目を指す `NSProgress` に `publish()` が呼ばれたときにブロックが呼ばれる」。
- `isOld`（同 241 行）は、購読前に公開された進捗かを示す。ヘッダに「Dock does not animate file icon flying when this method returns YES」とあり、標準 Dock が同じ仕組みを使っていることが書かれている。
- `fileOperationKind` は、`downloading`、`decompressingAfterDownloading`、`receiving`、`copying`、`uploading`、`duplicating` の6種類（同 273〜278 行）。

ホストで、別プロセスのコマンドライン（`ProgPub` と `ProgSub`）の間の更新、完了、失敗相当、キャンセルを確認した。

```
##### finish
253.94 PUBLISHED kind=nil url=nil old=true total=100 frac=0.7 desc=Downloading “file.bin”…
255.38   fraction=1.0 completed=100 cancelled=false
255.38 UNPUBLISHED completed=100/100 fraction=1.0 cancelled=false
##### fail（公開側が50%で unpublish）
270.33 UNPUBLISHED completed=50/100 fraction=0.5 cancelled=false
##### cancel
279.17 calling cancel()
279.53   fraction=0.5 completed=50 cancelled=true
279.53 UNPUBLISHED completed=50/100 fraction=0.5 cancelled=true
（公開側: PUB: cancellationHandler called ... PUB: isCancelled）
```

VM では、GUI アプリ（`PROBE=progress`）が `Progress` を公開し、別プロセスの購読側が更新と完了を受け取った。

```
543.06 PUBLISHED kind=nil url=nil old=false total=100 frac=0.0 desc=Downloading “file.bin”…
 ... fraction=0.1 ... fraction=1.0 completed=100 cancelled=false
548.04 UNPUBLISHED completed=100/100 fraction=1.0 cancelled=false
```

分かったことは次のとおりになる。

- 別プロセスの更新が、`fractionCompleted` の変化として届く。完了は `UNPUBLISHED` が割合 1.0 で呼ばれる。
- 失敗は、公開側が途中で `unpublish()` するだけの場合、購読側は途中の割合の `UNPUBLISHED` を受け取る。完了とは最終の割合で区別するしかなく、エラー情報は届かない。
- キャンセルは、購読側が `cancel()` を呼ぶと、公開側の `cancellationHandler` が呼ばれ、購読側の `isCancelled` が true になる。
- 購読側のプロキシでは `fileOperationKind` と `fileURL` が nil になる。`localizedDescription`（「Downloading “file.bin”…」）には種類が反映される。種類で処理を分ける場合は、これを手がかりにするか、別の方法が必要になる。
- 購読は、指定した URL と、その直下の項目だけが対象になる。VM で `~/Downloads` を購読して、その下のサブフォルダ内のファイルを公開した最初の試行では、何も届かなかった。監視するフォルダの設計に影響する。
- 購読前に公開された進捗は、途中の割合で届く（`old=true`、`frac=0.7`）。
- 自作の公開側の進捗では、標準 Dock の Probe 項目の `AXProgressValue` と `AXStatusLabel` は nil のままだった。標準 Dock がこの属性に値を入れる条件は不明。

### 受け入れ条件ごとの確認結果

| 受け入れ条件 | 結果 |
| --- | --- |
| Apple のファイル進捗の公開機構と、アプリ独自の進捗表示を区別する | 確認した。公開機構は `Progress.publish()` と `addSubscriber(forFileURL:)`。独自の進捗表示は、各アプリが `NSDockTile` の `contentView` に描く方法で、他アプリからは取得できない |
| 取得可能な進捗について更新・完了・失敗・キャンセルを確認する | 確認した（自作の公開側との間、ホストと VM）。更新、完了、キャンセルは取得できた。失敗は、完了と区別できず、割合とキャンセルの有無でしか判別できない。Finder と Safari の実際の進捗では未確認 |
| 他アプリが公開していない進捗を取得できると約束せず、対応範囲を示す | 確認した。対象は `Progress.publish()` を使う操作に限る。Finder のコピー、Safari のダウンロード、Mail の添付保存が公開しているかは未確認のため、対応するアプリは約束しない |

### リスクと制約

- 購読には、監視する URL（フォルダ）の指定が必要で、全体を一括で監視する API は無い。直下の項目だけが対象のため、監視するフォルダを列挙する必要がある。
- サンドボックス下のアプリが、利用者のフォルダの進捗を購読できるかは未確認。
- `Progress` に提供元アプリの情報が無く、進捗と Dock のアプリ項目の対応付けは確定できない。進捗はフォルダの項目に重ねて表示するか、アプリとの対応を付けない設計になる。
- 購読はファイル名を含む。表示以外に保存しない。

### 残る未確認

- Finder のコピー、Safari のダウンロード、Mail の添付保存が `Progress` を公開するか。
- 標準 Dock の進捗表示（アイコン上のリング）の見た目。画像は撮影できなかった。
- サンドボックス下のアプリでの購読の可否。
- `AXProgressValue` に値が入る条件。

### 実装する場合の方針と工数の見立て

設定で選んだフォルダ（既定はダウンロード）を購読し、進捗をそのフォルダの項目に重ねて表示する。完了とキャンセルは、`UNPUBLISHED` の割合と `isCancelled` で判定する。工数は、購読に1〜2日、表示に2日と見込む。着手前に、Finder と Safari が進捗を公開するかを、1日かけて確認する。

## #45 注意要求によるアイコンのバウンドを連携する方法

### 結論

条件付きで可能。注意要求を示す属性は、Dock の AX 項目に無い。ただし、バウンドは項目の `AXFrame` の位置変化として観測できる。Accessibility が前提で、観測は間接的になる。

### 現在の DockStudio（origin/main `9e26408`）

- Custom Dock は、DockStudio から起動したアプリの起動中だけアイコンをバウンドさせる（`DockStudio/CustomDockPreview.swift:221-238`）。設定画面にはこの動作の切り替えがあり、システムの「アニメーションを減らす」が有効な場合はバウンドしない（`DockStudio/SettingsPreview.swift:107-109`）。
- 他アプリの `requestUserAttention` を検出する処理は見つからなかった。起動バウンドと注意要求の連携は別機能であり、後者は未実装である。この判断はコード確認によるもので、アニメーションは今回確認していない。

### 根拠

- `NSApplication.requestUserAttention(_:)` と `cancelUserAttentionRequest(_:)` は、自アプリが送る側の API（`NSApplication.h` 269〜276 行）。種類は `NSCriticalRequest = 0` と `NSInformationalRequest = 10`。ヘッダに「call this method only if your application is not already active」とある。
- `NSRunningApplication.h` の公開プロパティに、注意要求の状態は無い（`@property` を全件確認した）。
- VM で、自作アプリ（`PROBE=attention`、`NSCriticalRequest`、起動の3秒後、アプリは非表示）の Dock 項目の `AXFrame` を1秒ごとに取った。y が静止位置の 1000 と、それより小さい値の間を往復した。属性一覧に注意要求を示すものは無く、`AXStatusLabel` と `AXProgressValue` も nil だった。

```
t=1 y:1000.00  t=3 y:987.238  t=4 y:1000.00  t=5 y:919.720  t=6 y:1000.00
t=7 y:908.357  t=8 y:1000.00  t=9 y:927.861  t=10 y:1000.0
```

### 受け入れ条件ごとの確認結果

| 受け入れ条件 | 結果 |
| --- | --- |
| 起動時のバウンドと情報・重大な注意要求を区別して確認する | 一部のみ確認。`NSCriticalRequest` の要求中のバウンドは、`AXFrame` の変化で確認した。`NSInformationalRequest`（1回）と、起動時のバウンドは、今回測定していない。1秒間隔の標本のため、バウンドの周期と回数も測れていない。見た目の画像と動画は撮影できなかった |
| 別アプリの要求を取得できる公開経路と取得不可の範囲を記録する | 確認した。要求を直接取得する公開 API は無い。取得経路は、Accessibility による Dock 項目の `AXFrame` の観察のみで、要求の種類（重大か情報か）は判別できない。標準 Dock を隠した状態で位置が変わり続けるかは未確認 |
| Reduce Motion、通知の抑制、要求解除、頻度制限の方針を決める | 方針を決めた（実装と検証は未実施）。Reduce Motion が有効なときは、バウンドせずに静止した強調で示す。集中モードなど通知が抑制されているときは、表示も抑える。要求の解除は、対象アプリがアクティブになった時点で消す（`AXFrame` の変化が止まった時点でも消す）。同じアプリへの表示は、10 秒に1回までとする。標準 Dock が Reduce Motion のときにどう動くかは未確認 |

### リスクと制約

- 位置の変化から要求を推定する方法は、Dock の拡大などによる位置の変化と区別する必要がある。誤検知の頻度は測っていない。
- 標準 Dock を隠す場合は、`AXFrame` が変わらず、観測できなくなる可能性がある。
- Accessibility の制約は「共通の前提」を参照する。

### 残る未確認

- `NSInformationalRequest` と、起動時のバウンドの `AXFrame`。
- バウンドの周期と回数（短い間隔でのサンプリング）。
- 標準 Dock を隠した状態での観測と、Reduce Motion 有効時の挙動。
- 画像と動画（撮影できなかった）。

### 実装する場合の方針と工数の見立て

#41 と同じ Dock の AX の観察基盤に、`AXFrame` の変化の検出を加える。検出の閾値と誤検知の確認に1日、実装に1〜2日と見込む。標準 Dock を隠す設計の場合は、観測の可否を先に確認する。

他アプリの注意要求によるバウンドを検出する実装は、フォローアップ issue #132 で扱う。

## issue の状況（2026-10-18）

| 調査 issue | 状態 | 受け入れ条件 | 実装フォローアップ |
| --- | --- | --- | --- |
| #26 | OPEN | 一部のみ。対象照合と下位メニューの確認が残る | #128 |
| #27 | OPEN | 一部のみ。起動後 Safari とメディアアプリの確認が残る | #129 |
| #29 | OPEN | 一部のみ。登録状態の読み取りと表示が残る | #130（設定画面への案内） |
| #41 | OPEN | 一部のみ。文字列・点の例と更新頻度の測定が残る | #131 |
| #42 | OPEN | 一部のみ。独自描画と静的アイコンの画面比較が残る | なし。取得手段がなく静的表示とする |
| #43 | CLOSED | 今回の担当対象外 | なし |
| #45 | OPEN | 一部のみ。情報要求と起動バウンドの区別が残る | #132 |

## 横断の所見

- #26、#27、#29、#41、#45 は、標準 Dock の Accessibility ツリーを読む共通の基盤に載せられる。VM で、メニュー（`AXShowMenu`）、バッジ（`AXStatusLabel`）、位置（`AXFrame`）が読めることを確認した。基盤を先に作ると、5件を順に追加できる。
- Accessibility と Screen Recording は、どちらも利用者に強い許可を求める。標準 Dock の情報の再表示のためにこれらを求めることが、DockStudio の価値に見合うかは、本体の判断が必要になる。#42 の画面キャプチャは、権限の重さに対して得られる情報が少なく、採らない方針とする。
- #43 は、追加許可なしで実装できる唯一の項目になる。ただし、Finder と Safari が進捗を公開するかを、着手前に確認する。
- 標準 Dock の AX 属性（`AXStatusLabel`、`AXProgressValue`、メニュー項目名）は、SDK ヘッダに定義が無いか、文書化されていない。macOS の更新で変わる可能性があるため、取得できない場合は、バッジやメニューを出さない動作を既定にする。
- 画像と動画は、ssh 経由の `screencapture` が失敗したため、撮影できなかった。画面の記録が必要な場合は、VNC 経由の既存の録画ツールを使う。

## 検証の再現手順

`DockAX`、`ProbeApp`、`ProgSub`、`ProgPub` のソースは、スクラッチ領域（リポジトリの外）に作成した。再現が必要な場合は、「検証物の内容」の表を元に作り直す。本文に掲載した出力は、ホストと VM で実際に得たものになる。
