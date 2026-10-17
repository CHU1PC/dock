# ウィンドウ・Spaces まわりの Dock 互換の調査

Issue #22、#25、#28、#55、#54 の調査結果をまとめる。調査日は 2026-10-17 で、基準は main の `3341868` になる。

## 調査の範囲と限界

公開 API の有無は、Xcode 同梱の macOS SDK のヘッダと、Apple の公式サポートページで確かめた。ヘッダの確認に使った SDK は次のとおりで、ホストの macOS は 26.5.2 になる。

```
$ xcrun --show-sdk-path
/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
```

次の項目は、今回は実行していない。**実機や VM での挙動は、1つも確認していない。**

- 専用ヘッドレス VM（`dockstudio-verification`）は、他のエージェントが共有ロック `/private/tmp/dockstudio-vm.lock` を保持し続けていた。ロックの取得を約30分（22:05〜22:37 JST）待ったが、取れなかった。
- 指示に従い、VM の操作を伴う項目は「未確認」と記録した。ロックを取らずに VM を操作することはしていない。ホストの画面には何も表示していない。
- そのため、標準 Dock のメニュー項目の実在、最小化アニメーションの実測、フルスクリーンと Mission Control での重なりは、未検証になる。各節の「受け入れ条件ごとの確認結果」に、確認した項目と未確認の項目を分けて書いた。
- 画像と動画は撮影していないので、`docs/media/research-windows-spaces/` は作っていない。

結論の語は、次の4つに限る。

| 結論 | 意味 |
| --- | --- |
| 実装可能 | 公開 API だけで、追加の許可なしに実現できる |
| 条件付きで可能 | 公開 API でも、Accessibility などの追加の許可や、利用者の設定が要る |
| 公開 API では不可 | SDK のヘッダに該当する API がない。非公開 API は使えるかどうかと別に扱う |
| 未確認 | 根拠が足りず、結論を出していない |

## 結論の一覧

| Issue | 結論 | 根拠の要点 |
| --- | --- | --- |
| #22 App Exposé | 公開 API では不可。キー入力の合成による代替は条件付きで可能だが、未検証 | SDK のヘッダに App Exposé を呼ぶ API がない。`CGEventPost` は公開 API だが、イベント送信の許可が要る |
| #25 最小化効果 | 公開 API では不可。OS に委譲する | `NSWindow` のヘッダに、最小化の効果や最小化先を選ぶ API がない。最小化先は標準 Dock になる想定だが、実測していない |
| #28 Spaces への割当 | 公開 API では不可。OS 設定への案内にとどめる | 他のアプリの割当を変える公開 API がヘッダにない。`NSWindow.collectionBehavior` は自分のウィンドウだけに効く |
| #55 表示領域の予約 | 公開 API では不可。標準 Dock の領域に頼る方法は未確認 | `NSScreen` に領域を予約する API がない。`visibleFrame` は読み取り専用になる |
| #54 フルスクリーン・Spaces・Mission Control | 未確認 | 指定した collectionBehavior はヘッダで意味を確認した。OS 操作との組合せは VM で確認できなかった |

## 共通の事実

### Custom Dock の現在の設定

`DockStudio/Services/CustomDockWindowController.swift` の初期化で、パネルを次のように作っている。

```swift
panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
```

配置は `screen.visibleFrame.insetBy(dx: 10, dy: 10)`（同ファイルの207行目）を基準にしている。他のアプリのウィンドウに対して、領域を予約する処理はない。

### collectionBehavior の意味

SDK の `NSWindow.h`（106〜126行目）に、次の説明がある。

```
 * @const NSWindowCollectionBehaviorManaged Participates in spaces, exposé.  Default behavior if `windowLevel == NSNormalWindowLevel`.
 * @const NSWindowCollectionBehaviorTransient Floats in spaces, hidden by exposé.  Default behavior if `windowLevel != NSNormalWindowLevel`.
 * @const NSWindowCollectionBehaviorStationary Unaffected by exposé.  Stays visible and stationary, like desktop window.
 * @const NSWindowCollectionBehaviorFullScreenAuxiliary Windows with this collection behavior can be shown with the fullscreen window.
 * @const NSWindowCollectionBehaviorCanJoinAllApplications Marks a window as able to join all applications, allowing it to join other apps' sets and full screen spaces when eligible. This collection behavior should commonly be used for floating windows and system overlays.
```

次の点が分かる。

- Custom Dock のパネルは、レベルが通常より上なので、既定で Transient になり、Exposé で隠れる側の扱いになる。
- `.fullScreenAuxiliary` は、フルスクリーンのウィンドウと同じ画面に表示できるという意味になる。`NSWindowCollectionBehaviorCanJoinAllApplications`（macOS 13 以降）は、他のアプリのウィンドウ集合とフルスクリーンの Space に入れる、とヘッダに書かれている。現在の設定には含めていない。

### 非公開のシンボルについて

次のシンボルは、SDK の `.tbd` に export されているが、どのヘッダにも宣言がない。非公開で未文書の API として扱う。

```
$ T=$SDK/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices.tbd
$ grep -o "_CoreDock[A-Za-z]*" $T | sort -u   (抜粋)
_CoreDockCopyWorkspacesAppBindings
_CoreDockGetEffect
_CoreDockGetMinimizeInPlace
_CoreDockGetRect
_CoreDockSendNotification
_CoreDockSetEffect
_CoreDockSetMinimizeInPlace
_CoreDockSetWorkspacesAppBindings
$ grep -rn "CoreDock" $SDK/.../HIServices.framework/Headers   (出力なし)

$ grep -o "_CGS[A-Za-z]*" $SDK/System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics.tbd | sort -u   (抜粋)
_CGSAddWindowsToSpaces
_CGSCopyManagedDisplaySpaces
_CGSCopySpacesForWindows
_CGSGetActiveSpace
_CGSMoveWindowsToManagedSpace
```

シンボルが export されていることまでが確認できた事実になる。引数の型、戻り値、macOS 15 と 26 での動作は、確認していない。

## #22 Show All Windows で App Exposé を呼び出す方法

**結論: 公開 API では不可。** キー入力を合成する代替は、条件付きで可能と見込むが、未検証になる。

### 根拠

- Apple の説明では、標準 Dock の操作は「アプリのアイコンを Control を押しながらクリックして、Show All Windows を選ぶ」になる。出典は [What's it called on my Mac?](https://support.apple.com/en-gb/guide/mac-help/cpmh0038/mac) で、Mission Control は Control-Up Arrow と書かれている。
- SDK の `AppKit`、`ApplicationServices`、`CoreGraphics`、`Carbon` のヘッダを "exposé"、"Mission Control"、"Show All Windows" で検索した。該当は `NSWindow.h` の collectionBehavior の説明（上記）と無関係な文だけで、App Exposé を呼び出す API は見つからなかった。
- 呼び出しの手段として、次の3つを検討した。

| 手段 | 公開か | 必要な許可 | 評価 |
| --- | --- | --- | --- |
| Control-Down 相当のキー入力を `CGEventPost` で送る | 公開 API。`CGEvent.h` に `CGEventPost`、`CGPreflightPostEventAccess`、`CGRequestPostEventAccess` がある | イベント送信の許可（macOS 10.15 以降） | 条件付きで可能。App Exposé は前面のアプリを対象にするため、先に対象アプリを前面にする必要がある。ショートカットを利用者が変更または無効にしていると動かない。Control-Down が既定であることは、今回の調査では公式ページで確認できなかった |
| 標準 Dock のアイコンに対して、Accessibility の `AXShowMenu` を実行し、メニューの Show All Windows を押す | 公開 API。`AXActionConstants.h:114` に `kAXShowMenuAction`、`AXRoleConstants.h:435` に `kAXApplicationDockItemSubrole` がある | Accessibility の許可（`AXIsProcessTrustedWithOptions`） | 条件付きで可能と見込むが、未検証。標準 Dock が起動していて、対象アプリのアイコンが標準 Dock に載っている必要がある。メニュー項目の名前は OS の言語に依存する |
| `CoreDockSendNotification` を呼ぶ | 非公開（ヘッダなし） | 不明 | 採用しない。通知名と引数は確認していない |

- 同じ表示にならない場合の代替として、Custom Dock が自前でウィンドウの一覧を出す方法がある。ウィンドウの列挙は、公開 API の `kAXWindowsAttribute`（Accessibility）または `CGWindowListCopyWindowInfo`（`CGWindow.h:170`）で行う。見た目が標準の App Exposé と同じにはならないので、同等と表示してはいけない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 対象アプリを指定して標準の全ウィンドウ表示へ渡せるか確認する | 公開 API は見つからなかった。キー入力の合成と Accessibility の2案を挙げたが、VM で実行しておらず、動作は未確認 |
| 公開 API、必要権限、OS 差分を記録する | 公開 API と必要な許可は上の表に記録した。**OS 差分（macOS 15 と 26）は未確認** |
| 同一動作が利用できない場合の代替表示を明示し、見た目だけを同等としない | 自前のウィンドウ一覧を代替として挙げた。標準の App Exposé とは別の機能として表示する、という方針を記録した |
| 対応トラックパッドの Force click や長押しなどの入口を、標準 Dock での対応を先に確認する | 参照した Apple のページには、Force click や長押しの記述が見つからなかった。標準 Dock での挙動は未確認 |

### 残る未確認

- 標準 Dock のメニューに Show All Windows が出る条件（アプリにウィンドウがない場合、最小化だけの場合）。
- Control-Down の合成で、対象アプリの App Exposé が開くか。ショートカットが無効のときの動作。
- `AXShowMenu` で開いたメニューの項目を、Accessibility で押せるか。
- 標準 Dock を自動非表示にしている場合に、アイコンの要素が取れるか。
- macOS 15 での挙動。
- Force click や長押しなど、トラックパッドからの入口。

### 実装する場合の方針と工数の見立て

- 方針は、Accessibility の許可が得られた場合だけ、「全ウィンドウを表示」を Custom Dock のメニューに出す。許可がない場合は、項目を出さないか、許可の案内を表示する。
- 第一候補は、対象アプリを前面にしてから、キー入力を合成する方法とする。第二候補は `AXShowMenu` とする。どちらも VM で動作を確認してから決める。
- 工数は、VM での検証を含めて2〜4日の見立てになる。許可の案内の画面と、許可がない場合の表示が含まれる。根拠のある見積りではなく、検証後に見直す。

## #25 Genie・Scale 最小化効果との連携可否

**結論: 公開 API では不可。** 最小化の処理と効果は OS に委譲する。標準 Dock を併用するときの最小化先と効果の実測は、未確認になる。

### 根拠

- Apple の [Desktop & Dock settings — macOS 26](https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26) には、最小化の視覚効果を選ぶ設定があると書かれている。ただし、取得したページの本文には Genie と Scale の名前がなく、"Choose the visual effect used when you minimize a window." とだけある。
- `NSWindow.h` の最小化に関する API は、`miniaturize:`（394行目）、`deminiaturize:`（395行目）、`isMiniaturized`（398行目）、`performMiniaturize:`（491行目）と通知だけになる。効果の種類や最小化先を指定する API は見つからなかった。
- Accessibility の `kAXMinimizedAttribute`（`AXAttributeConstants.h:822`）は、書き込み可能で、他のアプリのウィンドウを最小化できる。ヘッダの説明は "Whether a window is currently minimized to the dock." になる。最小化先と効果は OS が決めるため、Custom Dock が指定することはできない。
- 非公開のシンボル `_CoreDockGetEffect`、`_CoreDockSetEffect`、`_CoreDockGetMinimizeInPlace`、`_CoreDockSetMinimizeInPlace` が `HIServices.tbd` に export されている。これらは設定の読み書きに見えるが、非公開で、システム全体の設定を書き換える。採用しない。
- 標準 Dock を `NSApplicationPresentationHideDock` で隠す方法は、自分のアプリが前面のときだけ効く（`NSApplication.h:136-139`）。他のアプリの最小化には影響しない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| OS が管理する最小化処理と Custom Dock が担当できる範囲を区別する | ヘッダの範囲では、最小化の実行は Accessibility で可能だが、効果と最小化先は OS が管理する。Custom Dock が担当できるのは、最小化されたウィンドウの一覧の表示と、復元の操作の呼び出しまでと見込む。復元の操作は未検証 |
| 標準 Dock 非表示・併用時の最小化先と効果を実測する | **未確認。** VM のロックが取れず、実測していない |
| 公開 API で変更できない場合は OS に委譲する方針と制約を記録する | 下の方針に記録した |

### 残る未確認

- 標準 Dock を自動非表示にした状態で、最小化したウィンドウがどこへ吸い込まれるか。
- 標準 Dock を完全に使わない構成が、そもそも可能か。
- Custom Dock から最小化したウィンドウを復元する方法（`kAXMinimizedAttribute` に false を書く方法）が動くか。
- 最小化の効果の設定が、macOS 15 と 26 で同じ名前と挙動か。

### 実装する場合の方針と工数の見立て

- 方針は、最小化の効果を Dock Studio では扱わず、システム設定に委ねる。設定画面に「最小化の効果は、システム設定の Desktop & Dock で変更する」という案内を置く。
- 最小化されたウィンドウの表示と復元を Custom Dock に載せる場合は、別の項目として検討する。これは Accessibility の許可を要する。
- 案内文だけなら半日の見立てになる。実測のために、VM の確認で1日を見込む。

## #28 Options から Spaces へアプリを割り当てる方法

**結論: 公開 API では不可。** 利用者が標準 Dock の Options から行う操作への案内にとどめる。

### 根拠

- Apple の [Work in multiple spaces](https://support.apple.com/guide/mac-help/mh14112/26/mac/26) には、アプリの割当として次の選択肢がある。引用は取得したページからのもの。
  - All Desktops: "The app opens in every space."
  - This Desktop: "The app opens only in the current space."
  - Desktop on Display: "The app opens in the current space on a specific display (if more than one display is available)."
  - None: "The app opens in whichever space you're using at the time."
- Issue の受け入れ条件にある「All Desktops、This Desktop、None」に加えて、ページにはディスプレイ別の「Desktop on Display」がある。
- `NSWindow.collectionBehavior` は、自分のアプリのウィンドウにだけ効く。他のアプリのウィンドウの Space を指定する公開 API は、`NSWindow.h`、`NSScreen.h`、`NSWorkspace.h`、`NSRunningApplication.h` のどれにも見つからなかった。
- `NSScreen.screensHaveSeparateSpaces`（`NSScreen.h:31`）は、ディスプレイごとに Space を持つかどうかを読み取る公開 API になる。割当の変更はできない。
- 非公開のシンボルとして `_CoreDockSetWorkspacesAppBindings`、`_CoreDockCopyWorkspacesAppBindings`（HIServices）、`_CGSAddWindowsToSpaces`、`_CGSMoveWindowsToManagedSpace`（CoreGraphics）が export されている。ヘッダはない。割当を直接書き換える設定として `com.apple.spaces` の `app-bindings` キーを使う方法がコミュニティで知られている、という記憶があるが、今回の検索では確認できなかった。**確認できていないので、根拠にしない。**
- 非公開の API や設定の書き換えは、macOS の更新で壊れる危険がある。標準 Dock の動作を壊す可能性もある。採用しない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| All Desktops、This Desktop、None とディスプレイ別の条件を標準 Dock で確認する | Apple のページの文面までは確認した。標準 Dock での実際の表示と、割当後の挙動は **未確認**。割当を確かめるには、複数の Space を VM に作る必要があり、今回は行っていない |
| 対象アプリの割当を変更できる公開経路を調査する | 見つからなかった。結論は、公開 API では不可 |
| OS 委譲が必要なら安全な設定への案内と制約を記録する | 下の方針に記録した |

### 残る未確認

- 標準 Dock のメニューで、Options の中の割当の項目が、どの条件で表示されるか。
- 標準 Dock の項目を持たないアプリ（Custom Dock のみに載せたアプリ）に対する扱い。
- 割当を案内するときに、システム設定の該当ペインを直接開く方法があるか。
- macOS 15 での割当の選択肢。

### 実装する場合の方針と工数の見立て

- 方針は、Custom Dock のメニューに、割当の変更を直接行う項目は置かない。代わりに「標準 Dock の Options から設定できる」という案内と、現在の割当の説明を置くかどうかを検討する。
- 制約は、標準 Dock が起動していて、そのアプリのアイコンが標準 Dock に出ている場合に限る点になる。
- 案内文だけなら半日の見立てになる。

## #55 Dock 表示領域とウィンドウの最大化・タイル配置の共存

**結論: 公開 API では不可。** 他のアプリの配置のために画面の利用可能領域を予約する公開 API は、見つからなかった。標準 Dock の予約領域に頼る方法の有効性は、未確認になる。

### 根拠

- Apple の [Desktop & Dock settings — macOS 26](https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26) には、次の記述がある。Fill は、メニューバーと Dock の間を埋める。Dock が側面にあるときは、メニューバーより下で、Dock の横を埋める。タイル配置は、画面の端へドラッグして行い、"Tiled windows have margins" の設定がある。
- `NSScreen.h:35` の `visibleFrame` は読み取り専用で、Dock とメニューバーを除いた領域を返す。`NSScreen.h`、`NSWindow.h`、`NSApplication.h` を "strut"、"reserve"、"work area" で検索したが、領域を予約する API は見つからなかった。
- `NSApplicationPresentationOptions`（`NSApplication.h:136-139`）の `AutoHideDock` と `HideDock` は、自分のアプリが前面のときの表示を変えるだけで、他のアプリの配置には使えない。
- 公開の検索結果では、Ghostty などのアプリが、標準 Dock を考慮するために `visibleFrame` と `frame` の差を比較している。Dock の自動非表示は `com.apple.dock` の `autohide` を読んで判断している。公開 API で Dock の表示状態を直接取る方法がない、というコメントもある。出典は [Ghostty の `NSScreen+Extension.swift`（ミラー）](https://git.uoc.run.place/Applied-Software/ghostty/src/branch/main/macos/Sources/Helpers/NSScreen+Extension.swift) になる。公式の記述ではない。
- 結果として、他のアプリのウィンドウが最大化やタイル配置で避ける領域は、標準 Dock が決めている。Custom Dock のパネルは通常のウィンドウとして重なるだけで、領域は予約されない。
- 他のアプリのウィンドウを Accessibility で動かして避けさせる方法は、`kAXPositionAttribute` などで可能と見込むが、OS のウィンドウ管理の再実装になる。受け入れ条件の「OS のウィンドウ管理を再実装せずに利用できる方法」を満たさないので、採用しない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 常時表示と自動非表示それぞれで、ウィンドウが Dock と重なる条件を確認する | Apple のページの文面までを確認した。標準 Dock の常時表示と自動非表示での、Fill とタイルの実際の重なりは **未確認**。Custom Dock のパネルが他のアプリの Fill に影響しないことも、VM で確かめていない |
| 公開 API で画面の利用可能領域を予約できるかを調査する | 見つからなかった。結論は、公開 API では不可 |
| OS のウィンドウ管理を再実装せずに利用できる方法と制約を記録する | 下の方針に記録した |

### 残る未確認

- 標準 Dock を自動非表示にしたとき、Fill とタイルが画面の端まで広がるか。
- 標準 Dock を左右に置き、非常に小さいサイズにした場合の予約領域。
- Custom Dock を常時表示にしたとき、標準 Dock を併用する構成の見た目。
- macOS 15 と 26 のタイルの余白の扱い。
- 複数ディスプレイで、`visibleFrame` が Dock のある画面だけに反映されるか。

### 実装する場合の方針と工数の見立て

- 方針の案は、標準 Dock を併用することを前提にして、Custom Dock の領域を予約しない。Custom Dock は自動非表示を既定とし、重なりは利用者が許容する構成にする。
- もう1つの案は、標準 Dock を残し、サイズを最小にして予約領域を狭く保つ案になる。標準 Dock の設定を Dock Studio が書き換えることはしない。
- どちらの案も、VM での実測が先になる。実測に1日を見込む。実装は、表示と案内だけなら半日の見立てになる。

## #54 フルスクリーン・Spaces・Mission Control での Dock 互換性の検証

**結論: 未確認。** 検証の項目は、ヘッダと Apple のページで確認できた範囲を整理しただけで、実機や VM での挙動は確認していない。

### 確認できた範囲

- Custom Dock のパネルは、`.canJoinAllSpaces`、`.fullScreenAuxiliary`、`.ignoresCycle` を指定している（上の「共通の事実」）。
- `NSWindow.h:118` の説明では、`.fullScreenAuxiliary` を持つウィンドウは、フルスクリーンのウィンドウと一緒に表示できる。
- Apple の [Use apps in full screen](https://support.apple.com/guide/mac-help/mchl9c21d2be/26/mac/26) には、「Dock の位置へポインタを動かす、または離す」という操作がある。取得したページの本文には、フルスクリーン中に Dock がどの画面端から出るかの記述がなかった。Mission Control は Control-Up Arrow で開く、Split View は Mission Control から Spaces バーのフルスクリーンのアプリへウィンドウをドラッグして始める、と書かれている。
- `NSWindowCollectionBehaviorCanJoinAllApplications`（macOS 13 以降）は、フローティングウィンドウやシステムのオーバーレイ向けとヘッダに書かれている。フルスクリーンの Space へ入るために必要になる可能性があるが、必要かどうかは未確認になる。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| フルスクリーンと Split View で、画面端からの表示・退避・起動を確認する | **未確認** |
| Mission Control、Stage Manager、デスクトップ表示、Space 切替時の重なりとクリック透過を確認する | **未確認** |
| macOS 15 と 26、複数画面で確認結果を残し、不足を個別修正へ分ける | **未確認。** 確認していないので、不足の分割もしていない |

### 未確認の理由と、確認する場合の手順

- 理由は、専用ヘッドレス VM の共有ロックを約30分取得できなかったことになる。ホストの画面での確認は、リポジトリの規則（普段使いのデスクトップに検証用の画面を出さない）で禁止されている。
- 確認の手順の案は次のとおり。結果は、Issue ごとに表にする。
  1. VM で Custom Dock を起動し、Safari をフルスクリーンにする。ポインタを Custom Dock の画面端へ動かし、表示、クリック、退避を撮影する。
  2. Split View で同じ操作をする。
  3. Mission Control（Control-Up Arrow）、デスクトップ表示、Stage Manager の有効時に、パネルの重なりとクリックが下のウィンドウへ通るかを確認する。
  4. Space を切り替えたときに、パネルが残るか、位置がずれないかを確認する。
  5. macOS 15 の VM と、複数ディスプレイの構成を用意して、同じ項目を繰り返す。VM が macOS 26.6.2 のみの場合、15 は別の検証用 Mac が要る。

### 実装する場合の方針と工数の見立て

- 検証だけで、2日を見込む。macOS 15 の環境と複数ディスプレイの用意は、別に必要になる。
- 不足が見つかった場合は、`CanJoinAllApplications` の追加、`level` の調整、クリック透過の見直しなどを、個別の Issue に分ける。

## 実装に進める項目

今回の調査では、**公開 API だけで、追加の許可なしに完結する項目は見つからなかった。** 条件付きで進められる候補は次のとおり。

| 項目 | 内容 | 条件 |
| --- | --- | --- |
| #22 | 「全ウィンドウを表示」を、Accessibility またはイベント送信の許可がある場合だけ出す | VM での動作確認が先 |
| #25 | 最小化の効果の案内文 | 実測は未了 |
| #28 | Spaces の割当の案内文 | なし |
| #55 | 標準 Dock 併用を前提にした案内と既定値 | VM での実測が先 |

## 次にやること

1. VM のロックが取れる時間に、#54 の手順と、#22、#25、#28、#55 の未確認の項目を実行する。画像は `docs/media/research-windows-spaces/` に保存する。
2. 結果を本書の各節に反映し、「未確認」の項目を更新する。

## 参考にした資料

- [What's it called on my Mac?](https://support.apple.com/en-gb/guide/mac-help/cpmh0038/mac)
- [Desktop & Dock settings — macOS 26](https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26)
- [Work in multiple spaces](https://support.apple.com/guide/mac-help/mh14112/26/mac/26)
- [Use apps in full screen](https://support.apple.com/guide/mac-help/mchl9c21d2be/26/mac/26)
- [NSWindow.CollectionBehavior（Apple Developer Documentation）](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)。ページが JavaScript で描画されるため本文を取得できず、意味の確認には SDK のヘッダを使った。
- SDK のヘッダ: `AppKit.framework/Headers/NSWindow.h`、`NSScreen.h`、`NSApplication.h`、`CoreGraphics.framework/Headers/CGEvent.h`、`CGWindow.h`、`HIServices.framework/Headers/AXActionConstants.h`、`AXAttributeConstants.h`、`AXRoleConstants.h`、`AXUIElement.h`
