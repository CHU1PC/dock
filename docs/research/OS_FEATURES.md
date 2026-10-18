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

2026-10-18 の issue 更新では、VM やアプリを使った新しい観察は行っていない。下記の VM 結果は、2026-10-18 より前に記録された証拠として残し、この更新で再確認した結果とは扱わない。コードの現状は `origin/main` の履歴とファイルを読み、行番号を付けて追記した。

SDK は `xcrun --show-sdk-path` の `MacOSX26.5`（`SDKSettings.json` の `Version` が `26.5`）を使った。macOS 27 の SDK は手元になく、macOS 27 の API は確認できていない。ホストは macOS 26.5.2 で、VM は macOS 26.6.2 になる。macOS 27 と macOS 15 の実機は、どちらも手元にない。

結論は「実装可能」「条件付きで可能」「公開 API では不可」「未確認」のいずれかで書く。

### VM での確認（2026-10-18）

macOS 26.6.2 のヘッドレス VM で、確認できる範囲だけを確認した。共有 VM のロックは、最初の試み（2026-10-17）では取れなかったが、2回目に取得でき、約3分で解放した。画像は [docs/media/research-os-features/](../media/research-os-features/) に保存した。

| 確認した内容 | 結果 | 画像 |
| --- | --- | --- |
| 「最近使ったアプリを表示」を有効にして Calculator と Stickies を起動、終了した | Dock の区切り線の右側に、Terminal、Calculator、Stickies の3個が並んだ | `03-dock-show-recents-on.png` |
| `defaults read com.apple.dock recent-apps` | 上の3個の `bundle-identifier` が並んだ | なし（出力は #14 に記載） |
| `NSWorkspace` で `com.apple.apps.launcher` を開く | URL は引けた。完了ハンドラの `app` は `nil`、`error` も `nil`。撮影した画面にアプリ一覧は出なかった | `05-apps-view-after-open.png` |
| Dock の Apps アイコンのクリック（VNC） | ホバー表示の「Apps」だけが出て、一覧は出なかった。VNC のクリックが効かなかった可能性があり、結論にしない | `06-dock-apps-icon-click.png` |
| 「AirDrop & Continuity」の画面 | 「Allow Handoff between this Mac and your iCloud devices」のスイッチが存在し、有効だった。Apple Account は未サインイン | `07-handoff-setting.png` |
| 「Login Items & Extensions」の画面 | 「Open at Login」と「Extensions」が表示され、「Background App Activity」は上部に見えなかった（スクロールはしていない） | `08-login-items-26.png` |

VM の状態は、確認前に戻した。Dock の `autohide` は元の 1、`show-recents` は 0 に戻した。確認用のアプリは終了し、ゲストの一時ファイルは削除した。

実施した作業で、次の2点が元と違う。

- 確認前の `recent-apps` には Terminal が1件あったが、戻すときに空にした。バックアップは、片付けで削除してしまった。
- `strings` を実行したことで、`xcode-select` の「Command Line Developer Tools をインストール」ダイアログが VM に出た。プロセスを `kill -9` で終了し、インストールは行われていない。

画面確認には限界がある。画面の撮影は VNC で行い、画面の更新が遅れる場合があった。「Apps」が開かなかったことは、アプリ一覧が存在しないことの証明にはならない。

macOS 15 と macOS 27 は、環境がないため確認できていない。

## 結論の一覧

| issue | 結論 | 根拠の要点 |
| --- | --- | --- |
| #14 | OS の提案は公開 API では取得できない。代替の「最近使ったアプリ」は実装済み | `DockStudio/Services/RecentAppHistory.swift:3`、`DockStudio/Services/CustomDockWindowController.swift:101`、`DockStudio/SettingsPreview.swift:113` |
| #56 | 他アプリの継続候補を読むことは公開 API では不可。自アプリが Handoff を受ける側になることは実装可能 | `NSUserActivity` は同じ Team ID のアプリ間でだけ継続できる。他デバイスの活動を列挙する API がない |
| #58 | 条件付きで可能。OS 別の専用入口は未実装で、26 のアプリ一覧の表示と15の Launchpad は未確認 | 過去の記録では26の `Apps.app` の URL 解決と起動呼び出しまで確認。画面表示は確認できていない |
| #67 | 26.5 SDK では該当 API が見つからず、macOS 27 で利用できる公開 API は未確認 | 27 の SDK と標準 Dock の挙動を確認できていない |
| #70 | 未確認。公開 API で他アプリのバックグラウンド実行だけを止める経路は見つかっていない。System Settings への案内は 26 までの API で可能 | `SMAppService.openSystemSettingsLoginItems` は実在する。27 の停止操作の API は確認できていない |

## #14 OS が提案するアプリの表示方法

### 結論

OS の提案そのものは公開 API で取得できない。「最近使ったアプリ」に近い表示は実装済みだが、DockStudio の利用履歴であり、OS の提案とは別物になる。

### 根拠

Apple のサポート文書は、設定項目を次のように説明している。macOS 15 と 26 の「Desktop & Dock settings」の本文は同一だった。

> Show suggested and recently opened apps (if they aren't already included in the Dock) toward one end of the Dock.

- 15: [Apple Support](https://support.apple.com/guide/mac-help/mchlp1119/15.0/mac/15.0)
- 26: [Apple Support](https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26)

「Use the Dock」の macOS 26 版は、表示数を次のように書いている。

> The Dock can show up to three recently used apps that aren't already in it

- [Apple Support](https://support.apple.com/en-gb/guide/mac-help/mh35859/26/mac/26)

macOS 15 版の「Use the Dock」にも、最近使ったアプリの説明がある。取得できた要約では、上限の数は確認できなかった。

SDK 側では、次を確認した。

- `NSRunningApplication.h` の `activationPolicy`（34〜42行）は、Dock に出るアプリを `NSApplicationActivationPolicyRegular` として説明している。
- `NSWorkspace` の `runningApplications`（`NSRunningApplication.h:184`）は、実行中のアプリだけを返す。
- `NSWorkspace.h` に、提案アプリや最近使ったアプリを返すメソッドはない。`launchedApplications`（`NSWorkspace.h:441`）は、非推奨で、実行中のアプリを返す。
- 調査時の DockStudio は `CustomDockWindowController.swift:351-354` で `runningApplications` を使い、`activationPolicy == .regular` のアプリだけを拾っている。

調査後に、DockStudio 自身の履歴による最近使ったアプリが追加された。`CustomDockWindowController.swift:101-118` は起動とアクティベーション通知を受け、通常のアプリを履歴へ記録する。`RecentAppHistory.swift:3-28` は最大3件を表示し、固定済みと実行中の項目を除外する。`SettingsPreview.swift:113-115` は表示設定と履歴消去の説明を提供する。履歴の復元と保存は `DockStore+RecentApps.swift:4-40` にある。これはOSの提案を取得する実装ではない。

ホストの Dock の設定を、読み取り専用で確認した。

```text
$ defaults read com.apple.dock show-recents
0
$ defaults read com.apple.dock recent-apps
(
)
```

VM（macOS 26.6.2）で、設定を有効にして確認した。

```text
$ defaults write com.apple.dock show-recents -bool true; killall Dock
$ open -a Calculator; (終了); open -a Stickies; (終了)
$ defaults read com.apple.dock recent-apps | grep -E "bundle-identifier|file-label"
"bundle-identifier" = "com.apple.Terminal";   "file-label" = Terminal;
"bundle-identifier" = "com.apple.calculator"; "file-label" = Calculator;
"bundle-identifier" = "com.apple.Stickies";   "file-label" = Stickies;
```

次のことが分かった。画像は `docs/media/research-os-features/03-dock-show-recents-on.png` になる。

- 起動して終了したアプリが、Dock の区切り線の右側に、最近使ったアプリとして並んだ（この VM では3個）。
- `show-recents` が 0 でも、`recent-apps` には Terminal が残っていた。表示の有無とは別に、OS が履歴を保存している。
- この VM では、ユーザーが起動した順に記録され、「提案」と思われるアプリは出なかった。Apple Account が未サインインで、利用履歴もないためで、提案の挙動は確認できていない。
- 履歴は `com.apple.dock` の `recent-apps` に、`tile-data` として入る。形式は非公開で、更新条件は上の観察以上には確認していない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| OS の提案が出る条件を対象 OS で確認する | 一部のみ。前回記録の26.6.2 VMでは最近使ったアプリの表示を確認したが、OSの「提案」の条件は確認できていない。macOS 15も未確認。本更新ではVM観察を行っていない |
| 公開 API で取得できる範囲と、最近使ったアプリとの違いを記録する | 満たした。公開APIでは実行中アプリを取得できるが、OSの提案は取得できない。最近使ったアプリは `RecentAppHistory.swift:3-28` にあるDockStudio独自の履歴である |
| 取得できない場合は、明示的な制約または同意済みの代替を決める | 満たした。制約を明示し、別機能であることを設定画面にも記載した独自履歴を代替として実装済み（`SettingsPreview.swift:113-115`）。OSの提案と同じものとは説明しない |

### リスクと制約

- `com.apple.dock` の `recent-apps` を読む方法は、公開 API ではない。形式が変わる可能性がある。サンドボックス化したアプリでは読めない見込みで、これは確認していない。ユーザーの利用履歴を読むため、プライバシー上の同意も要る。この方法は採らないことを推奨する。
- 「提案」の選び方が非公開のため、同じ表示は再現できない。

### 方針と工数の見立て

この方針は実装済みである。DockStudio は `didLaunchApplicationNotification` と `didActivateApplicationNotification` を使って履歴を記録し、最大3件を表示する。設定画面では最近使ったアプリの表示と、オフにした場合の履歴消去を説明する。OS の提案とは別の機能として扱う。

工数の見立ては、モデルと保存に1日、表示と設定画面に1日、テストと画面検証に1日で、合計3日ほどになる。見立てであり、測定はしていない。

### 残る未確認

- 提案アプリの出現条件（26.6.2 の VM では、利用履歴がなく再現できなかった）。15 の挙動。
- 提案と最近使ったアプリが、見た目で区別されるか。
- `recent-apps` の更新条件と、サンドボックスでの可否。
- この更新では、上記の過去の VM 観察を再実施していない。

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

[Apple Support](https://support.apple.com/guide/mac-help/mchl732d3c0a/26/mac/26)

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
| 対応するアカウント・機器・アプリで、標準 Dock の表示条件を確認する | 一部のみ。Appleのサポート文書で条件を確認した。前回記録の26.6.2 VMでは設定スイッチの存在を確認したが、Apple Account と別デバイスがなく Dock 表示は未確認。macOS 15も未確認。本更新ではVM観察を行っていない |
| 自アプリの Handoff 対応と、別アプリの継続候補を読む手段を区別する | 満たした。自アプリは `NSUserActivity` と `NSApplication` のデリゲートで対応できる。別アプリの継続候補を列挙する公開APIは確認できていない |
| 公開経路と制約を記録し、取得できない場合の案内を決める | 満たした。別アプリの候補は標準Dockに任せ、設定画面で案内する方針を記録した。案内自体は未実装で、対象となるDockStudio内の活動もまだない |

### リスクと制約

非公開の手段として、`useractivityd` などのシステムのデーモンの情報を読む方法が考えられる。この調査では試していない。非公開で、macOS の更新で動かなくなる恐れがあり、ユーザーの他デバイスでの作業内容を読むため、プライバシー上の問題が大きい。採らないことを推奨する。

### 方針と工数の見立て

1. DockStudio 自身の項目は、Handoff の送り手と受け手を、必要になった段階で別の issue として設計する。現時点で DockStudio に継続する活動はない。
2. 他アプリの継続候補は、標準 Dock に任せる。設定画面に「Handoff の継続アイコンは、macOS の Dock にのみ表示されます」という案内を出す。
3. 案内の追加は半日ほどになる。自アプリの Handoff 対応は、対象の活動が決まってから見積もる。

### 残る未確認

- 実機（別デバイスと同じ Apple Account）での、標準 Dock のアイコンの表示条件と位置。VM では、設定のスイッチの存在までを確認した。
- 15 と 26 の差。
- システムの Dock の Handoff アイコンを、サードパーティが置き換えたときの挙動。
- この更新では、VM や別デバイスを使った Handoff の観察を行っていない。

## #58 Launchpad・アプリ一覧への入口

### 結論

条件付きで可能。macOS 26 は、過去の記録で `com.apple.apps.launcher` の `Apps.app` を `NSWorkspace` で引いて開く呼び出しまで確認した。ただし、アプリ一覧の表示は撮影できていない。macOS 15 の Launchpad は未確認で、DockStudio の専用入口も未実装である。本更新ではVM観察を行っていない。

### 根拠

macOS 26 の「View and open apps」は、アプリ一覧への入口を次のように書いている。

> On your Mac, click the Apps icon in the Dock.

> click the Spotlight icon in the menu bar and then click the Applications icon.

> and then press ⌘-1.

[Apple Support](https://support.apple.com/guide/mac-help/mh35840/26/mac/26)

この文書は Launchpad に触れていない。

macOS 15 の「Use the Dock」は、Launchpad を Dock から使える機能の例として挙げている（取得できた要約による）。Launchpad の開き方を書いた文書は、今回は取得できなかった。

ホスト（macOS 26.5.2）で、次を確認した。

```text
$ ls /System/Applications | grep -i -E "launchpad|apps"
Apps.app
$ defaults read /System/Applications/Apps.app/Contents/Info CFBundleIdentifier
com.apple.apps.launcher
$ defaults read /System/Applications/Apps.app/Contents/Info LSUIElement
1
```

`Launchpad.app` は、26.5.2 の `/System/Applications` にない。`Apps.app` の `Info.plist` には、`CFBundleDisplayName` が `Apps`、`LSMinimumSystemVersion` が `26.5`、`LSUIElement` が `true` と書かれている。

`NSWorkspace.h:114` の `URLForApplicationWithBundleIdentifier:` は、バンドル ID から URL を引ける。`NSWorkspace.h:46` の `openApplicationAtURL:configuration:completionHandler:` で開ける。どちらも公開 API になる。VM（macOS 26.6.2）で、次の小さなプログラムを実行した。

```text
$ /tmp/ws-r3
url: /System/Applications/Apps.app
opened: nil policy: -1 error: nil
launchpad url: nil
```

- `urlForApplication(withBundleIdentifier: "com.apple.apps.launcher")` は `/System/Applications/Apps.app` を返した。
- `openApplication(at:configuration:)` は、エラーなしで完了した。ただし、完了ハンドラの `NSRunningApplication` は `nil` で、実行中のアプリにも `com.apple.apps.launcher` は現れなかった。
- 撮影した画面には、アプリ一覧が表示されなかった（`05-apps-view-after-open.png`）。Dock の Apps アイコンを VNC でクリックしても、同様に表示されなかった（`06-dock-apps-icon-click.png`）。クリックが効かなかった可能性があり、これだけで「開けない」とは言えない。
- `com.apple.launchpad.launcher` は、26.6.2 では `nil` になった。
- 26.6.2 の標準 Dock の既定の項目の2番目は `com.apple.apps.launcher` だった（`defaults read com.apple.dock persistent-apps`）。

つまり、`Apps.app` を引いて開く呼び出しは通るが、アプリ一覧が実際に表示されるかは、確認できていない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 15 の Launchpad と 26 以降のアプリ一覧への起動方法を、公式資料と実機で確認する | 一部のみ。26の公式資料と過去のバンドル確認、URL解決と起動呼び出しの記録はあるが、一覧の表示は未確認。15は公式資料の一部のみで、実機未確認。本更新ではVM観察を行っていない |
| 公開された入口があれば専用項目として利用し、OS 別に無効な参照を残さない | 未実施。OS別の項目追加と参照の解決は方針に記録したが、コードには実装していない。実装Issue #133 を作成し、#58 に関連付けた |
| Spotlight や OS のアプリ検索自体を複製しない | 満たした（方針）。DockStudio は検索画面を複製せず、OSのアプリ一覧への入口だけを追加する予定である |

### リスクと制約

- 保存済みのプロファイルが、特定の OS のパスを持っていると、別の OS に移したときに無効な参照になる。`DockDocument` が保存するのは、パスではなくバンドル ID にするのが安全になる。現在の保存形式は今回確認していない。
- `com.apple.launchpad.launcher` が 15 の Launchpad のバンドル ID であることは、記憶に基づく推測で、確認していない。実装時に 15 の環境で確認する。
- `Apps.app` は `LSUIElement` が `true` で、`NSApplicationActivationPolicyAccessory` になる。Dock の実行中アプリの一覧（`activationPolicy == .regular`）には出ない。

### 方針と工数の見立て

OS 別の「アプリ一覧」項目を追加する。バンドル ID の候補（26 は `com.apple.apps.launcher`、15 は確認済みのもの）を順に引き、最初に見つかったものを開く。どれも見つからなければ、項目を非表示にする。

工数の見立ては、項目の追加と参照の解決に1日、15 と 26 の環境での確認に1日で、合計2日ほどになる。

### 残る未確認

- macOS 15 の Launchpad のバンドル ID と、`NSWorkspace` で開けること。
- macOS 26 で `Apps.app` を開いたときの、アプリ一覧の実際の表示。VM では呼び出しは成功したが、画面に出なかった。ssh 経由の起動や、画面更新の遅れが原因の可能性がある（いずれも未切り分け）。
- OS別の専用入口の実装と、その画面表示の検証。
- この更新では、VM や実機での画面観察を行っていない。
- 26 より後の OS（27 を含む）での入口の変更。

## #67 macOS 27 のバックグラウンド実行表示との互換性

### 結論

26.5 の SDK には該当する公開 API が見つからなかった。macOS 27 の SDK は未確認のため、27 で利用できる公開 API は未確認になる。この機能は macOS 27 だけのものであり、15 と 26 に存在するものとして扱わない。

### 根拠

Apple のサポート文書（macOS 27 Golden Gate）は、次のように書いている。

> Starting in macOS 27 Golden Gate, your Mac flags apps that keep running after you quit them.

最初に起きたときに通知が出て、Dock のアイコンにポインタを重ねると、アプリ名と「Running in Background」が表示される。

[Apple Support](https://support.apple.com/en-my/125671)

報道は、通知後の Dock の点が、黒から薄い灰色に変わると伝えている。ただし、これは二次情報になる。

- 9to5Mac、2026-06-09: [9to5Mac](https://9to5mac.com/?p=1055761)

26.5 の SDK では、次を確認した。

- `NSRunningApplication` のプロパティは、`terminated`（67行）、`finishedLaunching`（72行）、`hidden`（76行）、`ownsMenuBar`（84行）、`activationPolicy`（88行）などになる。バックグラウンド実行の状態を表すものはない。
- `AppKit.framework/Headers`、`ServiceManagement.framework/Headers`、`CoreServices.framework` を、`runninginbackground`、`backgroundActivity`、`StopRunning` で検索したが、一致はなかった。
- `activationPolicy` の説明（`NSRunningApplication.h:34〜42`）は、`Regular` が Dock に出るアプリで、`Accessory` と `Prohibited` は Dock に出ないアプリと書いている。

macOS 27 のベータ版の挙動を、開発者フォーラムが伝えている。公式の回答は、確認できた範囲で付いていない。

- 起動中のプロセスがなく、登録された launchd ジョブだけが残るアプリにも、「Running in Background」が出るという報告がある。[Apple Developer Forums](https://developer.apple.com/forums/thread/832557)（返信なし）
- `LSUIElement` や `LSBackgroundOnly` を設定しても、Launch Services 経由で起動したアプリが Dock に出るという報告がある。旧 API のログイン項目を `SMAppService` に変えると解消したという。[Apple Developer Forums](https://developer.apple.com/forums/thread/847300)

これらから、表示の条件は、アプリが Launch Services 経由で起動され、ウィンドウがない状態で動き続けていることに関係する、と推測できる。正確な条件は、公式資料に書かれていない。

VM（macOS 26.6.2）の `Dock.app` の実行ファイルには、「Running in Background」「Stop Running in Background」の文字列がなかった（`grep -c -a` の結果は、どちらも 0）。ただし、文言が別のリソースにある可能性があり、不在の証明にはならない。26.6.2 の標準 Dock にこの機能がないことの、補助的な確認にとどまる。

DockStudio の現在の実行中アプリの列挙（`CustomDockWindowController.swift:351-354`）は、`activationPolicy == .regular` のアプリだけを拾う。macOS 27 で、ウィンドウのないバックグラウンドのアプリが、`regular` で `runningApplications` に残るかは未確認になる。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| macOS 27 の代表アプリと公式条件で、標準 Dock の表示を確認する | 未実施。対象のmacOS 27環境がなく、公式サポート文書の記述までを記録した。過去の26.6.2 VM記録は27の表示確認にはならない。本更新ではVM観察を行っていない |
| 別プロセスの稼働状態を公開 API で識別できるか調査し、単なる起動中の点と区別する | 一部のみ。26.5 SDKの調査では該当APIは見つからなかったが、27 SDKは未確認で、結論を確定できない |
| 15 と 26 へ存在しない状態を持ち込まず、取得できない情報やプライバシー上の制約を記録する | 満たした（調査方針）。15と26では状態を扱わず、取得できない情報とプロセス調査のプライバシー上の制約を記録した |

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
- この更新では、VM や実機での macOS 27 の観察を行っていない。

## #70 macOS 27 の Stop Running in Background 操作との連携

### 結論

未確認。公開 API で、他アプリのバックグラウンド実行だけを止める経路は、26.5 の SDK に見つからなかった。System Settings の Login Items へユーザーを案内することは、26 までの公開 API で可能（条件付き）。この機能は macOS 27 だけのものであり、15 と 26 に存在するものとして扱わない。

### 根拠

Apple のサポート文書（macOS 27）は、次のように書いている。

- Dock のアイコンを Control キーを押しながらクリックし、「Stop Running in Background」を選ぶ。
- アプリを再び開くには、Dock のアイコンをクリックする。
- System Settings の General > Login Items & Extensions の「Background App Activity」で、アプリのバックグラウンド実行を、オンまたはオフにできる。
- 止めた後は、自動更新やデータの同期が動かなくなるなど、アプリが想定どおりに動かない場合がある。止める範囲の詳細は、文書に書かれていない。

[Apple Support](https://support.apple.com/en-my/125671)

9to5Mac は、この操作がプロセスを終了し、アプリを Dock から外すと伝えている。これは二次情報になる。

SDK では、次を確認した。

- `NSRunningApplication` の `terminate`（`NSRunningApplication.h:153`）と `forceTerminate`（158行）がある。これらは通常終了と強制終了であり、「Stop Running in Background」とは別の操作になる。
- `ServiceManagement.framework/Headers/SMAppService.h:283` の `+ openSystemSettingsLoginItems` が、System Settings のログイン項目の画面を開く。ヘッダの説明は、アプリが自分のヘルパーを再び有効にするよう、ユーザーに案内する用途と書いている。他アプリのバックグラウンド実行を操作する用途ではない。
- `SMAppService` の `status`（`SMAppServiceStatus`）は、自アプリのサービスの状態を返す。他アプリの状態は読めない。

公開 API で「Stop Running in Background」を実行できる経路は、確認できなかった。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 対応 OS の標準 Dock で、操作の条件と停止する範囲を確認する | 一部のみ。操作方法と副作用はAppleのサポート文書に記載があるが、対象のmacOS 27環境がなく実機観察は未実施。停止範囲も文書に記載されていない。本更新ではVM観察を行っていない |
| 公開経路で停止できるかと、OS の Login Items 設定へ案内できる範囲を調査する | 一部のみ。26.5 SDKの `SMAppService.openSystemSettingsLoginItems` で設定画面を開く経路は確認した。他アプリの停止APIは見つからず、27 SDKは未確認 |
| 通常終了や強制終了と混同せず、同期や更新が中断する影響を説明する。無関係なヘルパーを一括で終了しない | 一部のみ。`terminate` と `forceTerminate` を代用しない方針と、同期・更新への一般的な影響は記録した。停止範囲と具体的な影響は27環境で未確認で、案内の実装も未実施 |

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
- この更新では、VM や実機での macOS 27 の操作観察を行っていない。

## 実装可能と分かった項目

| 項目 | 内容 | 工数の見立て |
| --- | --- | --- |
| #14 の代替 | DockStudio 自身の起動記録による「最近使った項目」。OS の提案とは別物と明記する（実装済み。`RecentAppHistory.swift`、PR #117） | 完了 |
| #56 の案内 | 「Handoff の継続アイコンは macOS の Dock にのみ表示される」という設定画面の案内 | 0.5日。対象活動が決まってからIssue化する |
| #58 | OS 別のアプリ一覧の項目（26 は `Apps.app`）。15 の Launchpad は、15 の環境で確認してから | 2日。実装Issue #133 を作成済み |
| #70 の案内 | Login Items の設定を開く案内。macOS 27 の環境で確認してから | 1日。実装Issue #134 を作成し、27の確認後に着手する |

## 確認できなかった項目

| 項目 | 理由 |
| --- | --- |
| 過去の VM 観察の一部 | #58 のアプリ一覧の表示は、VNC の更新遅れやクリック不達の可能性があり、撮影できなかった。他の項目は、過去の記録で26.6.2の範囲を確認した。本更新ではVMに触れていない |
| macOS 15 の実機での確認（#14、#56、#58） | macOS 15 の環境がない |
| macOS 27 の実機と SDK（#67、#70） | macOS 27 の環境と SDK がない。サポート文書と報道だけを根拠にした |
| Handoff の実機での確認（#56） | 別デバイスと同じ Apple Account の環境がない |
| macOS 15 の Launchpad のバンドル ID（#58） | 15 の環境がない |
| Apple 公式のリリースノート（#67、#70） | 検索で見つからなかった。確認できたのは、サポート文書、報道、開発者フォーラムの投稿だけ |

## 参考にした資料

- Desktop & Dock settings（15）: [Apple Support](https://support.apple.com/guide/mac-help/mchlp1119/15.0/mac/15.0)
- Desktop & Dock settings（26）: [Apple Support](https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26)
- Use the Dock（15）: [Apple Support](https://support.apple.com/en-gb/guide/mac-help/mh35859/15.0/mac/15.0)
- Use the Dock（26）: [Apple Support](https://support.apple.com/en-gb/guide/mac-help/mh35859/26/mac/26)
- Hand off tasks between Apple devices（26）: [Apple Support](https://support.apple.com/guide/mac-help/mchl732d3c0a/26/mac/26)
- View and open apps（26）: [Apple Support](https://support.apple.com/guide/mac-help/mh35840/26/mac/26)
- If an app continues running in the background after you quit it（27）: [Apple Support](https://support.apple.com/en-my/125671)
- 9to5Mac、macOS 27 のバックグラウンド実行: [9to5Mac](https://9to5mac.com/?p=1055761)
- Apple Developer Forums: [thread 832557](https://developer.apple.com/forums/thread/832557)、[thread 847300](https://developer.apple.com/forums/thread/847300)
- SDK ヘッダ: `MacOSX26.5.sdk` の `Foundation/NSUserActivity.h`、`AppKit/NSApplication.h`、`AppKit/NSRunningApplication.h`、`AppKit/NSWorkspace.h`、`ServiceManagement/SMAppService.h`
