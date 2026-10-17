# OS の機能との連携に関する調査（#14、#56、#58、#67、#70）

## 調査の範囲と方法

2026-10-17 に調べた。対象は、標準 Dock の次の5項目になる。

| issue | 項目 |
| --- | --- |
| #14 | OS が提案するアプリの表示方法 |
| #56 | Handoff の継続中アプリの表示と起動 |
| #58 | Launchpad とアプリ一覧への入口 |
| #67 | macOS 27 のバックグラウンド実行表示 |
| #70 | macOS 27 の Stop Running in Background 操作 |

根拠は、Apple のサポート文書、SDK ヘッダ、ホストの読み取り専用の確認、公開されたフォーラムと報道の4種類になる。アプリのコードは変更していない。

SDK は `xcrun --show-sdk-path` の `MacOSX26.5`（`SDKSettings.json` の `Version` が `26.5`）を使った。macOS 27 の SDK は手元になく、macOS 27 の API は確認できていない。ホストは macOS 26.5.2 で、VM は macOS 26.6.2 になる。macOS 27 と macOS 15 の実機は、どちらも手元にない。

結論は「実装可能」「条件付きで可能」「公開 API では不可」「未確認」のいずれかで書く。

### VM を使えなかったこと

VM は他のエージェントと共有しており、ロックを取れなかった。`mkdir /private/tmp/dockstudio-vm.lock` を15秒間隔で30分間試したが、取得できずに打ち切った。そのため、VM 上の画面確認と撮影は行っていない。`docs/media/research-os-features/` に画像はない。

ロックを取る前に、1回だけ `ssh` で `sw_vers -productVersion` と `whoami` を実行した。出力は `26.6.2` と `admin` で、画面にも設定にも触れていない。

標準 Dock の表示条件は、Apple のサポート文書だけを根拠にしている。実機の観察ではない。

## 結論の一覧

| issue | 結論 | 根拠の要点 |
| --- | --- | --- |
| #14 | 公開 API では不可。代替として、自アプリの利用履歴による「最近使った項目」は実装可能 | 提案アプリを返す公開 API が SDK にない。`NSWorkspace.runningApplications` は実行中のアプリだけを返す |
| #56 | 他アプリの継続候補を読むことは公開 API では不可。自アプリが Handoff を受ける側になることは実装可能 | `NSUserActivity` は同じ Team ID のアプリ間でだけ継続できる。他デバイスの活動を列挙する API がない |
| #58 | 条件付きで可能。26 は `com.apple.apps.launcher` を `NSWorkspace` で開ける。15 の Launchpad は未確認 | ホストの `/System/Applications/Apps.app` を確認した。Launchpad の実体は15の実機で確認できていない |
| #67 | 公開 API では不可。ただし、macOS 27 では Dock 側が自動で表示するため、実装は不要の可能性が高い | 26.5 の SDK に該当する API がない。27 の API は未確認 |
| #70 | 未確認。公開 API で他アプリのバックグラウンド実行だけを止める経路は見つかっていない。System Settings への案内は 26 までの API で可能 | `SMAppService.openSystemSettingsLoginItems` は実在する。27 の停止操作の API は確認できていない |

## #14 OS が提案するアプリの表示方法

### 結論

公開 API では不可。ただし「最近使ったアプリ」に近い表示は、DockStudio が自分で記録すれば実装できる。OS の提案そのものとは別物になる。

### 根拠

Apple のサポート文書は、設定項目を次のように説明している。macOS 15 と 26 の「Desktop & Dock settings」の本文は同一だった。

> Show suggested and recently opened apps (if they aren't already included in the Dock) toward one end of the Dock.

- 15: https://support.apple.com/guide/mac-help/mchlp1119/15.0/mac/15.0
- 26: https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26

「Use the Dock」の macOS 26 版は、表示数を次のように書いている。

> The Dock can show up to three recently used apps that aren't already in it

- https://support.apple.com/en-gb/guide/mac-help/mh35859/26/mac/26

macOS 15 版の「Use the Dock」にも、最近使ったアプリの説明がある。取得できた要約では、上限の数は確認できなかった。

SDK 側では、次を確認した。

- `NSRunningApplication.h` の `activationPolicy`（34〜42行）は、Dock に出るアプリを `NSApplicationActivationPolicyRegular` として説明している。
- `NSWorkspace` の `runningApplications`（`NSRunningApplication.h:184`）は、実行中のアプリだけを返す。
- `NSWorkspace.h` に、提案アプリや最近使ったアプリを返すメソッドはない。`launchedApplications`（`NSWorkspace.h:441`）は、非推奨で、実行中のアプリを返す。
- 現在の DockStudio は `CustomDockWindowController.swift:256` で `runningApplications` を使い、`activationPolicy == .regular` のアプリだけを拾っている。

ホストの Dock の設定を、読み取り専用で確認した。

```
$ defaults read com.apple.dock show-recents
0
$ defaults read com.apple.dock recent-apps
(
)
```

OS が最近使ったアプリを `com.apple.dock` の `recent-apps` に保存していることは、このキーの存在から推測できる。ただし、ホストでは `show-recents` が 0 のため、中身は空だった。キーの形式と更新条件は確認できていない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| OS の提案が出る条件を対象 OS で確認する | 一部のみ。サポート文書で、設定項目と上限が3個であること（26）は確認した。提案の選び方（何を基準に選ぶか）は、Apple の公開資料に書かれていない。15 と 26 の実機での確認は、VM を使えなかったため未実施 |
| 公開 API で取得できる範囲と、最近使ったアプリとの違いを記録する | 公開 API で取得できるのは、実行中のアプリまで。提案アプリと最近使ったアプリは、どちらも公開 API で読めない。Apple の文書は、両者を同じ設定項目で扱っている。提案と最近使ったアプリを区別する資料は見つからなかった |
| 取得できない場合は、明示的な制約または同意済みの代替を決める | 制約として明示する。代替は下の「方針」の案になる。実装には加藤さんの同意が要る |

### リスクと制約

- `com.apple.dock` の `recent-apps` を読む方法は、公開 API ではない。形式が変わる可能性がある。サンドボックス化したアプリでは読めない見込みで、これは確認していない。ユーザーの利用履歴を読むため、プライバシー上の同意も要る。この方法は採らないことを推奨する。
- 「提案」の選び方が非公開のため、同じ表示は再現できない。

### 方針と工数の見立て

方針は、DockStudio が `NSWorkspace` の起動通知（`didLaunchApplicationNotification`）で最近起動したアプリを自分で記録し、「最近使った項目」として表示する案になる。OS の提案とは別の機能であることを、設定画面で明記する。通知名は今回、SDK ヘッダで確認していない。実装時に確認する。

工数の見立ては、モデルと保存に1日、表示と設定画面に1日、テストと画面検証に1日で、合計3日ほどになる。見立てであり、測定はしていない。

### 残る未確認

- 15 と 26 の実機での、提案アプリの出現条件。
- 提案と最近使ったアプリが、見た目で区別されるか。
- `recent-apps` の形式と、サンドボックスでの可否。

## #56 Handoff の継続中アプリを表示・起動する方法

### 結論

他アプリの継続候補を読むことは、公開 API では不可。自アプリが Handoff の受け手になることは、実装可能。

### 根拠

Apple の「Hand off tasks between Apple devices」（macOS 26）は、次の内容を書いている。

- Wi-Fi と Bluetooth が両方のデバイスで有効であること。
- 同じ Apple Account でサインインしていること。
- 距離は「30 feet (10 meters)」以内であること。
- Mac では、System Settings の General > AirDrop & Continuity で「Allow Handoff between this Mac and your iCloud devices」を有効にすること。
- アイコンは、Dock が下にあるとき Dock の右端付近に、Dock が横にあるときは Dock の下端に出ること。

https://support.apple.com/guide/mac-help/mchl732d3c0a/26/mac/26

「Use the Dock」の26版と15版は、Handoff のアイコンが Dock の右端付近に出ると書いている。

SDK ヘッダでは、次を確認した。

- `Foundation.framework/Headers/NSUserActivity.h:22` は、活動を継続できるのは「the same developer Team ID as the activity's source application」のアプリで、かつ、Info.plist の `NSUserActivityTypes` にその型があるアプリだけと説明している。
- 同ファイル96行に `eligibleForHandoff` がある。
- `NSApplication.h` に、受け手側のデリゲートがある。`application:willContinueUserActivityWithType:`（465行）、`application:continueUserActivity:restorationHandler:`（476行）、`application:didFailToContinueUserActivityWithType:error:`（481行）になる。
- 他のデバイスで進行中の `NSUserActivity` を列挙する API は、`NSUserActivity.h` と `NSApplication.h` に見つからなかった。

つまり、システムは、同じ Team ID で、対応する型を持つアプリにだけ、継続を渡す。DockStudio が、他社のアプリや Apple のアプリの継続候補を読むことはできない。

macOS の Dock が表示する Handoff アイコンを、DockStudio のカスタム Dock に複製するための公開経路は、見つからなかった。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 対応するアカウント・機器・アプリで、標準 Dock の表示条件を確認する | 条件はサポート文書で確認した（上記）。実機は確認していない。iPhone などの別デバイスと、同じ Apple Account の環境が、この調査の環境にないため。VM は他のデバイスと連携できない見込みで、これも確認していない |
| 自アプリの Handoff 対応と、別アプリの継続候補を読む手段を区別する | 自アプリ: `NSUserActivity` と `NSApplication` のデリゲートで対応できる（実装可能）。別アプリ: 読む公開 API はない（公開 API では不可） |
| 公開経路と制約を記録し、取得できない場合の案内を決める | 上記に記録した。案内の文面は下の「方針」の案になる |

### リスクと制約

非公開の手段として、`useractivityd` などのシステムのデーモンの情報を読む方法が考えられる。この調査では試していない。非公開で、macOS の更新で動かなくなる恐れがあり、ユーザーの他デバイスでの作業内容を読むため、プライバシー上の問題が大きい。採らないことを推奨する。

### 方針と工数の見立て

1. DockStudio 自身の項目は、Handoff の送り手と受け手を、必要になった段階で別の issue として設計する。現時点で DockStudio に継続する活動はない。
2. 他アプリの継続候補は、標準 Dock に任せる。設定画面に「Handoff の継続アイコンは、macOS の Dock にのみ表示されます」という案内を出す。
3. 案内の追加は半日ほどになる。自アプリの Handoff 対応は、対象の活動が決まってから見積もる。

### 残る未確認

- 実機（別デバイスと同じ Apple Account）での、標準 Dock のアイコンの表示条件と位置。
- 15 と 26 の差。
- システムの Dock の Handoff アイコンを、サードパーティが置き換えたときの挙動。

## #58 Launchpad・アプリ一覧への入口

### 結論

条件付きで可能。macOS 26 は、ホストで確認した `com.apple.apps.launcher` の `Apps.app` を、`NSWorkspace` で開ける見込みになる。macOS 15 の Launchpad は、実機で確認できていないため未確認。

### 根拠

macOS 26 の「View and open apps」は、アプリ一覧への入口を次のように書いている。

> On your Mac, click the Apps icon in the Dock.

> click the Spotlight icon in the menu bar and then click the Applications icon.

> and then press ⌘-1.

https://support.apple.com/guide/mac-help/mh35840/26/mac/26

この文書は Launchpad に触れていない。

macOS 15 の「Use the Dock」は、Launchpad を Dock から使える機能の例として挙げている（取得できた要約による）。Launchpad の開き方を書いた文書は、今回は取得できなかった。

ホスト（macOS 26.5.2）で、次を確認した。

```
$ ls /System/Applications | grep -i -E "launchpad|apps"
Apps.app
$ defaults read /System/Applications/Apps.app/Contents/Info CFBundleIdentifier
com.apple.apps.launcher
$ defaults read /System/Applications/Apps.app/Contents/Info LSUIElement
1
```

`Launchpad.app` は、26.5.2 の `/System/Applications` にない。`Apps.app` の `Info.plist` には、`CFBundleDisplayName` が `Apps`、`LSMinimumSystemVersion` が `26.5`、`LSUIElement` が `true` と書かれている。

`NSWorkspace.h:114` の `URLForApplicationWithBundleIdentifier:` は、バンドル ID から URL を引ける。`NSWorkspace.h:46` の `openApplicationAtURL:configuration:completionHandler:` で開ける。どちらも公開 API になる。`Apps.app` に対して実際に開く操作は、ホストの画面を出さないために実行していない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 15 の Launchpad と 26 以降のアプリ一覧への起動方法を、公式資料と実機で確認する | 26: 公式資料と、ホストのバンドルの確認（実際に開く操作は未実行）。15: 公式資料の一部のみ。実機は未確認。VM は 26.6.2 のみで、15 の環境がない。26 の VM の画面確認は、ロックを取れず未実施 |
| 公開された入口があれば専用項目として利用し、OS 別に無効な参照を残さない | 方針あり（下記）。`URLForApplicationWithBundleIdentifier:` が `nil` を返すときは、項目を表示しない。`Apps.app` と Launchpad の実体は、OS で異なる |
| Spotlight や OS のアプリ検索自体を複製しない | 方針に含める。DockStudio は検索画面を持たず、OS の入口を開くだけにする |

### リスクと制約

- 保存済みのプロファイルが、特定の OS のパスを持っていると、別の OS に移したときに無効な参照になる。`DockDocument` が保存するのは、パスではなくバンドル ID にするのが安全になる。現在の保存形式は今回確認していない。
- `com.apple.launchpad.launcher` が 15 の Launchpad のバンドル ID であることは、記憶に基づく推測で、確認していない。実装時に 15 の環境で確認する。
- `Apps.app` は `LSUIElement` が `true` で、`NSApplicationActivationPolicyAccessory` になる。Dock の実行中アプリの一覧（`activationPolicy == .regular`）には出ない。

### 方針と工数の見立て

OS 別の「アプリ一覧」項目を追加する。バンドル ID の候補（26 は `com.apple.apps.launcher`、15 は確認済みのもの）を順に引き、最初に見つかったものを開く。どれも見つからなければ、項目を非表示にする。

工数の見立ては、項目の追加と参照の解決に1日、15 と 26 の環境での確認に1日で、合計2日ほどになる。

### 残る未確認

- macOS 15 の Launchpad のバンドル ID と、`NSWorkspace` で開けること。
- macOS 26 で `Apps.app` を `NSWorkspace` から開いたときの、実際の表示と、フォーカスの挙動。
- 26 より後の OS（27 を含む）での入口の変更。

## #67 macOS 27 のバックグラウンド実行表示との互換性

### 結論

公開 API では不可（26.5 の SDK に該当する API がない）。macOS 27 の SDK は未確認のため、27 で API が追加されたかは未確認になる。この機能は macOS 27 だけのものであり、15 と 26 に存在するものとして扱わない。

### 根拠

Apple のサポート文書（macOS 27 Golden Gate）は、次のように書いている。

> Starting in macOS 27 Golden Gate, your Mac flags apps that keep running after you quit them.

最初に起きたときに通知が出て、Dock のアイコンにポインタを重ねると、アプリ名と「Running in Background」が表示される。

https://support.apple.com/en-my/125671

報道は、通知後の Dock の点が、黒から薄い灰色に変わると伝えている。ただし、これは二次情報になる。

- 9to5Mac、2026-06-09: https://9to5mac.com/?p=1055761

26.5 の SDK では、次を確認した。

- `NSRunningApplication` のプロパティは、`terminated`（67行）、`finishedLaunching`（72行）、`hidden`（76行）、`ownsMenuBar`（84行）、`activationPolicy`（88行）などになる。バックグラウンド実行の状態を表すものはない。
- `AppKit.framework/Headers`、`ServiceManagement.framework/Headers`、`CoreServices.framework` を、`runninginbackground`、`backgroundActivity`、`StopRunning` で検索したが、一致はなかった。
- `activationPolicy` の説明（`NSRunningApplication.h:34〜42`）は、`Regular` が Dock に出るアプリで、`Accessory` と `Prohibited` は Dock に出ないアプリと書いている。

macOS 27 のベータ版の挙動を、開発者フォーラムが伝えている。公式の回答は、確認できた範囲で付いていない。

- 起動中のプロセスがなく、登録された launchd ジョブだけが残るアプリにも、「Running in Background」が出るという報告がある。https://developer.apple.com/forums/thread/832557（返信なし）
- `LSUIElement` や `LSBackgroundOnly` を設定しても、Launch Services 経由で起動したアプリが Dock に出るという報告がある。旧 API のログイン項目を `SMAppService` に変えると解消したという。https://developer.apple.com/forums/thread/847300

これらから、表示の条件は、アプリが Launch Services 経由で起動され、ウィンドウがない状態で動き続けていることに関係する、と推測できる。正確な条件は、公式資料に書かれていない。

DockStudio の現在の実行中アプリの列挙（`CustomDockWindowController.swift:256`）は、`activationPolicy == .regular` のアプリだけを拾う。macOS 27 で、ウィンドウのないバックグラウンドのアプリが、`regular` で `runningApplications` に残るかは未確認になる。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| macOS 27 の代表アプリと公式条件で、標準 Dock の表示を確認する | 公式条件は、サポート文書で確認した。代表アプリの実機での確認は未実施（macOS 27 の環境がない）。報道は Gemini アプリを例に挙げている |
| 別プロセスの稼働状態を公開 API で識別できるか調査し、単なる起動中の点と区別する | 26.5 の SDK には、識別できる公開 API がない。`NSRunningApplication` は、起動中かどうかまでしか分からない。27 の SDK は未確認 |
| 15 と 26 へ存在しない状態を持ち込まず、取得できない情報やプライバシー上の制約を記録する | 15 と 26 には、この状態がないものとして扱う。取得できない情報は、バックグラウンドで実行している理由と、実行中のタスクの内容になる。システム全体のプロセスの調査は、プライバシー上の問題が大きく、サンドボックスでも制限される |

### リスクと制約

- プロセス一覧（`proc_listpids` など）や launchd の状態を読んで、バックグラウンド実行を推測する方法は、標準 Dock の判定と一致する保証がない。誤表示の恐れがある。
- 標準 Dock が表示する以上、DockStudio が同じ表示を重ねる必要性は低い。独自の判定は誤った情報を出す危険がある。

### 方針と工数の見立て

macOS 27 の SDK が公開され、状態を取得する公開 API が確認できるまで、実装しない。それまでは、DockStudio の実行中のドットを「起動中」を表すものとして維持し、バックグラウンド実行を示すとは説明しない。

macOS 27 の API が確認できた場合の工数は、調査に1日、実装に2日、macOS 27 の環境での確認に1日で、合計4日ほどと見立てる。API がなければ工数は発生しない。

### 残る未確認

- macOS 27 の SDK に、バックグラウンド実行の状態を返す API があるか。
- macOS 27 で、`NSWorkspace.runningApplications` と `activationPolicy` が、バックグラウンド実行中のアプリをどう返すか。
- macOS 27 の標準 Dock の実際の表示（点の色、ホバー表示）。

## #70 macOS 27 の Stop Running in Background 操作との連携

### 結論

未確認。公開 API で、他アプリのバックグラウンド実行だけを止める経路は、26.5 の SDK に見つからなかった。System Settings の Login Items へユーザーを案内することは、26 までの公開 API で可能（条件付き）。この機能は macOS 27 だけのものであり、15 と 26 に存在するものとして扱わない。

### 根拠

Apple のサポート文書（macOS 27）は、次のように書いている。

- Dock のアイコンを Control キーを押しながらクリックし、「Stop Running in Background」を選ぶ。
- アプリを再び開くには、Dock のアイコンをクリックする。
- System Settings の General > Login Items & Extensions の「Background App Activity」で、アプリのバックグラウンド実行を、オンまたはオフにできる。
- 止めた後は、自動更新やデータの同期が動かなくなるなど、アプリが想定どおりに動かない場合がある。止める範囲の詳細は、文書に書かれていない。

https://support.apple.com/en-my/125671

9to5Mac は、この操作がプロセスを終了し、アプリを Dock から外すと伝えている。これは二次情報になる。

SDK では、次を確認した。

- `NSRunningApplication` の `terminate`（`NSRunningApplication.h:153`）と `forceTerminate`（158行）がある。これらは通常終了と強制終了であり、「Stop Running in Background」とは別の操作になる。
- `ServiceManagement.framework/Headers/SMAppService.h:283` の `+ openSystemSettingsLoginItems` が、System Settings のログイン項目の画面を開く。ヘッダの説明は、アプリが自分のヘルパーを再び有効にするよう、ユーザーに案内する用途と書いている。他アプリのバックグラウンド実行を操作する用途ではない。
- `SMAppService` の `status`（`SMAppServiceStatus`）は、自アプリのサービスの状態を返す。他アプリの状態は読めない。

公開 API で「Stop Running in Background」を実行できる経路は、確認できなかった。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 対応 OS の標準 Dock で、操作の条件と停止する範囲を確認する | 操作の条件（コンテキストメニュー）は、サポート文書で確認した。停止する範囲は、文書に書かれていない。実機での確認は未実施（macOS 27 の環境がない） |
| 公開経路で停止できるかと、OS の Login Items 設定へ案内できる範囲を調査する | 停止: 公開 API では確認できなかった（未確認）。案内: `SMAppService.openSystemSettingsLoginItems` で、画面を開くまでは可能。特定のアプリの行までは開けない。ヘッダにその指定がない |
| 通常終了や強制終了と混同せず、同期や更新が中断する影響を説明する。無関係なヘルパーを一括で終了しない | 方針に含める。`terminate` と `forceTerminate` を、この操作の代わりに使わない。影響の説明の文面は下記 |

### リスクと制約

- `terminate` で代用すると、通常終了になる。常駐しているアプリは、終了要求を無視するか、すぐ再起動することがある。`forceTerminate` は、保存前のデータを失わせる恐れがある。どちらも、macOS 27 の「Stop Running in Background」とは別物になる。
- バンドル ID が同じプロセスや、関連するヘルパーを検索して終了する方法は、無関係なヘルパーまで終了する恐れがあるため、採らない。
- 他アプリのログイン項目やバックグラウンド項目を、DockStudio が一覧にすると、ユーザーの使用状況に関する情報になる。取得する場合は同意が要る。

### 方針と工数の見立て

macOS 27 の SDK に公開 API が見つかるまでは、停止操作を実装しない。代わりに、メニューに次の案内だけを出す案がある。

- 「バックグラウンド実行は、System Settings の General > Login Items & Extensions で変更できます」と表示し、`SMAppService.openSystemSettingsLoginItems()` を呼ぶ。
- 説明文には、「止めると、自動更新やデータの同期が動かなくなる場合があります。通常の終了や強制終了とは異なります」と書く。

この案内の追加は、macOS 27 の環境で状態を確認できるまで、実装しない。実装する場合の工数は、1日ほどになる。macOS 27 の SDK に公開 API があった場合は、別に見積もる。

### 残る未確認

- macOS 27 の SDK に、バックグラウンド実行を停止する公開 API があるか。
- 「Stop Running in Background」が停止する範囲（アプリ本体だけか、ヘルパーを含むか）。
- macOS 27 の標準 Dock の実際のメニュー項目の位置と、表示される条件。
- 同期や更新が中断される具体的な影響。

## 実装可能と分かった項目

| 項目 | 内容 | 工数の見立て |
| --- | --- | --- |
| #14 の代替 | DockStudio 自身の起動記録による「最近使った項目」。OS の提案とは別物と明記する | 3日 |
| #56 の案内 | 「Handoff の継続アイコンは macOS の Dock にのみ表示される」という設定画面の案内 | 0.5日 |
| #58 | OS 別のアプリ一覧の項目（26 は `Apps.app`）。15 の Launchpad は、15 の環境で確認してから | 2日 |
| #70 の案内 | Login Items の設定を開く案内。macOS 27 の環境で確認してから | 1日 |

## 確認できなかった項目

| 項目 | 理由 |
| --- | --- |
| VM での画面確認と撮影（全5件） | 共有 VM のロックを30分取れなかった |
| macOS 15 の実機での確認（#14、#56、#58） | macOS 15 の環境がない |
| macOS 27 の実機と SDK（#67、#70） | macOS 27 の環境と SDK がない。サポート文書と報道だけを根拠にした |
| Handoff の実機での確認（#56） | 別デバイスと同じ Apple Account の環境がない |
| macOS 15 の Launchpad のバンドル ID（#58） | 15 の環境がない |
| Apple 公式のリリースノート（#67、#70） | 検索で見つからなかった。確認できたのは、サポート文書、報道、開発者フォーラムの投稿だけ |

## 参考にした資料

- Desktop & Dock settings（15）: https://support.apple.com/guide/mac-help/mchlp1119/15.0/mac/15.0
- Desktop & Dock settings（26）: https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26
- Use the Dock（15）: https://support.apple.com/en-gb/guide/mac-help/mh35859/15.0/mac/15.0
- Use the Dock（26）: https://support.apple.com/en-gb/guide/mac-help/mh35859/26/mac/26
- Hand off tasks between Apple devices（26）: https://support.apple.com/guide/mac-help/mchl732d3c0a/26/mac/26
- View and open apps（26）: https://support.apple.com/guide/mac-help/mh35840/26/mac/26
- If an app continues running in the background after you quit it（27）: https://support.apple.com/en-my/125671
- 9to5Mac、macOS 27 のバックグラウンド実行: https://9to5mac.com/?p=1055761
- Apple Developer Forums: https://developer.apple.com/forums/thread/832557 、 https://developer.apple.com/forums/thread/847300
- SDK ヘッダ: `MacOSX26.5.sdk` の `Foundation/NSUserActivity.h`、`AppKit/NSApplication.h`、`AppKit/NSRunningApplication.h`、`AppKit/NSWorkspace.h`、`ServiceManagement/SMAppService.h`
