# ウィンドウ・Spaces まわりの Dock 互換の調査

Issue #22、#25、#28、#55、#54 の調査結果をまとめる。調査日は 2026-10-17 から 18 で、DockStudio の現状は main の `5d761de` を Release ビルドして確認した。

## 調査の範囲と限界

公開 API の有無は、Xcode 同梱の macOS SDK のヘッダと、Apple の公式サポートページで確かめた。ホストの macOS は 26.5.2 になる。

実機に近い挙動は、専用ヘッドレス VM（`dockstudio-verification`）で確認した。ホストの画面には何も表示していない。

| 項目 | 内容 |
| --- | --- |
| ゲスト | macOS 26.6.2、1画面（1600×1000）。Spaces は確認用に一時的に2つへ増やして、元の1つへ戻した |
| 操作の方法 | ssh で入れたゲスト内の小さなツールから、Accessibility の API と `CGEventPost` を使った。VNC のクリックは使っていない。ゲストでは `sshd-keygen-wrapper` に Accessibility とイベント送信の許可が与えられている |
| 撮影 | VNC のスクリーンショットを JPEG に縮小して保存した。動画は撮っていない |
| DockStudio | `5d761de` の Release ビルド（署名なし）。実行ファイルの SHA-256 は `5c83f53e3722056ad7f74faadf69ef6e252fa25a3c24d533cf87fbfcfefabfe8` |

次の項目は、今回の範囲に含まれない。各 issue の「残る未確認」にも書いた。

- macOS 15 での確認（VM は 26.6.2 のみ）。
- 複数ディスプレイ（ゲストは1画面）。
- アニメーションの見た目の比較（動画を撮っていない）。
- トラックパッドの操作（Force click、ジェスチャ）。
- Split View。

結論の語は、次の4つに限る。

| 結論 | 意味 |
| --- | --- |
| 実装可能 | 公開 API だけで、追加の許可なしに実現できる |
| 条件付きで可能 | 公開 API でも、Accessibility などの追加の許可や、利用者の設定が要る |
| 公開 API では不可 | SDK のヘッダに該当する API がない。非公開 API は使えるかどうかと別に扱う |
| 未確認 | 根拠が足りず、結論を出していない |

画像は [docs/media/research-windows-spaces/](../media/research-windows-spaces/) に保存した。

## 結論の一覧

| Issue | 結論 | 根拠の要点 |
| --- | --- | --- |
| #22 App Exposé | 公開 API では不可。標準 Dock のメニュー操作の代行と、キー入力の合成は、条件付きで可能 | ヘッダに専用の API がない。VM で、`AXShowMenu` と `AXPress` による「Show All Windows」が動いた。Control-Down の合成は、`Fn` と `NumericPad` の修飾を付けると動き、Control だけでは動かなかった |
| #25 最小化効果 | 公開 API では不可。OS に委譲する。効果の見た目は未確認 | ヘッダに効果や最小化先を選ぶ API がない。VM で、最小化したウィンドウは標準 Dock の専用タイルになった。Custom Dock は最小化先にならない |
| #28 Spaces への割当 | 公開 API では不可。標準 Dock の操作を Accessibility で代行する方法は条件付きで可能だが、案内にとどめるのが安全 | VM で、Spaces が2つ以上のときだけ Options に Assign To が出た。割当は `com.apple.spaces` の `app-bindings` に保存された。ディスプレイ別は未確認 |
| #55 表示領域の予約 | 公開 API では不可 | ヘッダに予約する API がない。VM で、Fill とタイルは標準 Dock の領域だけを避けた。Custom Dock のパネルは領域を予約せず、Fill した窓の上に重なった |
| #54 フルスクリーン・Spaces・Mission Control | 一部を確認。Split View、クリック透過、デスクトップ表示、macOS 15、複数画面は未確認 | 現在の設定のまま、フルスクリーンの Space、Space の切替、Stage Manager でパネルが表示された。Mission Control の間はパネルが隠れた。`CanJoinAllApplications` は今回のケースでは不要だった |

## 共通の事実

### Custom Dock の現在の設定

`DockStudio/Services/CustomDockWindowController.swift` の初期化で、パネルを次のように作っている。

```swift
panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
```

VM で表示したパネルは、`CGWindowList` で layer 21（Dock のレベル 20 に 1 を足した値）、483×157 になり、画面の下端近くに置かれた。

### collectionBehavior の意味

SDK の `NSWindow.h`（106〜126行目）に、次の説明がある。

```
 * @const NSWindowCollectionBehaviorManaged Participates in spaces, exposé.  Default behavior if `windowLevel == NSNormalWindowLevel`.
 * @const NSWindowCollectionBehaviorTransient Floats in spaces, hidden by exposé.  Default behavior if `windowLevel != NSNormalWindowLevel`.
 * @const NSWindowCollectionBehaviorStationary Unaffected by exposé.  Stays visible and stationary, like desktop window.
 * @const NSWindowCollectionBehaviorFullScreenAuxiliary Windows with this collection behavior can be shown with the fullscreen window.
 * @const NSWindowCollectionBehaviorCanJoinAllApplications Marks a window as able to join all applications, allowing it to join other apps' sets and full screen spaces when eligible. This collection behavior should commonly be used for floating windows and system overlays.
```

Custom Dock のパネルはレベルが通常より上なので、既定で Transient になり、Exposé と Mission Control で隠れる側の扱いになる。VM の結果（#54）もこの説明と合っていた。

### 非公開のシンボルについて

次のシンボルは SDK の `.tbd` に export されているが、どのヘッダにも宣言がない。非公開で未文書の API として扱い、今回は呼んでいない。

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
_CGSMoveWindowsToManagedSpace
```

### 標準 Dock の Accessibility ツリー

ゲストで、標準 Dock（`com.apple.dock`）の Accessibility ツリーを取得した。アプリのアイコンは `AXApplicationDockItem`（`AXRoleConstants.h:435` に定義がある）、最小化したウィンドウは `AXMinimizedWindowDockItem`（同438行目）になる。アイコンに `AXShowMenu`（`AXActionConstants.h:114`）を実行すると、メニューは、アイコンの子ではなく、Dock の `AXList` の子の `AXMenu` として現れた。このツリーの構造は Apple が文書化していないので、macOS の更新で変わる可能性がある。

## #22 Show All Windows で App Exposé を呼び出す方法

**結論: 公開 API では不可。標準 Dock のメニューを Accessibility で操作する方法と、キー入力の合成は、条件付きで可能。**

### 根拠

- Apple の [What's it called on my Mac?](https://support.apple.com/en-gb/guide/mac-help/cpmh0038/mac) では、標準 Dock の操作は「アプリのアイコンを Control を押しながらクリックして、Show All Windows を選ぶ」になる。
- SDK の `AppKit`、`ApplicationServices`、`CoreGraphics`、`Carbon` のヘッダを "exposé"、"Mission Control"、"Show All Windows" で検索した。App Exposé を呼び出す API は見つからなかった。`CoreDockSendNotification` は非公開で、採用しない。
- VM で、次の2つの方法を実行した。

| 方法 | 結果 |
| --- | --- |
| 標準 Dock の Safari のアイコンに `AXShowMenu` を実行し、メニュー項目「Show All Windows」に `AXPress` を実行する | **成功。** Safari の2つのウィンドウが App Exposé で並んだ（[画像](../media/research-windows-spaces/22-show-all-windows-via-ax.jpg)）。許可は Accessibility |
| Control-Down を `CGEventPost` で送る。Safari を前面にして実行した | 修飾に Control だけを付けたときは、2回とも App Exposé が開かなかった。Control に `Fn`（`maskSecondaryFn`）と `NumericPad` を足すと、**開いた**（[画像](../media/research-windows-spaces/22-show-all-windows-via-ctrl-down.jpg)）。許可はイベント送信（`CGPreflightPostEventAccess`） |

- 標準 Dock のメニューの中身（[画像](../media/research-windows-spaces/22-safari-dock-menu.jpg)）は、次のとおりだった。Safari が2つのウィンドウを持つ状態で、メニュー項目は、ウィンドウ名の2項目、New Window、New Private Window、Options（Keep in Dock、Open at Login、Show in Finder）、Show All Windows、Hide、Hide Others、Quit、Force Quit になった。
- 同じ表示にならない場合の代替として、Custom Dock が自前でウィンドウの一覧を出す方法がある。ウィンドウの列挙は、公開 API の `kAXWindowsAttribute`（Accessibility）または `CGWindowListCopyWindowInfo`（`CGWindow.h:170`）で行う。見た目が標準の App Exposé と同じにはならないので、同等と表示してはいけない。

### リスクと制約

- どちらの方法も、利用者の許可が要る（Accessibility またはイベント送信）。許可がない場合は、項目を出さないか、許可の案内を出す。
- メニュー項目の名前（"Show All Windows"）は OS の言語で変わる。Dock のツリーの構造も、macOS の更新で変わる可能性がある。
- キー入力の合成は、修飾の付け方で動作が変わった（Fn と NumericPad が要る）。利用者がショートカットを変更または無効にしていると動かない。ゲストでのショートカットは既定のままと見ているが、設定の値までは確認していない。
- App Exposé は前面のアプリが対象になる。キー入力の合成では、先に対象アプリを前面にする必要がある。`AXShowMenu` の方法は、アイコンごとに指定できる。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 対象アプリを指定して標準の全ウィンドウ表示へ渡せるか確認する | **確認した。** アイコン指定の `AXShowMenu` と、前面化したうえでのキー合成の2つが、VM で動いた |
| 公開 API、必要権限、OS 差分を記録する | 公開 API と必要な許可は上に記録した。**OS 差分（macOS 15）は未確認**（VM が 26.6.2 のみ） |
| 同一動作が利用できない場合の代替表示を明示し、見た目だけを同等としない | 同一動作が利用できたため、代替は不要だった。許可がない場合の代替として、自前のウィンドウ一覧を挙げ、別の機能として表示する方針を記録した |
| 対応トラックパッドの Force click や長押しなどの入口を、標準 Dock での対応を先に確認する | **未確認。** VM はポインタとキーの操作だけで、トラックパッドの入力を送れない。参照した Apple のページにも記述がなかった |

### 残る未確認

- ウィンドウが0個のアプリや、最小化だけのアプリで、Show All Windows が出る条件。
- 標準 Dock を自動非表示にしているときの `AXShowMenu`。
- macOS 15 での挙動。
- トラックパッドからの入口。

### 実装する場合の方針と工数の見立て

- 方針は、Accessibility の許可がある場合だけ「全ウィンドウを表示」を Custom Dock のメニューに出す。実行は `AXShowMenu` と `AXPress` を第一候補、キー合成を第二候補とする。許可がない場合は、許可の案内を出す。
- 工数は2〜3日の見立てになる。許可の案内の画面、メニュー項目の探し方（言語差）、許可がない場合の表示が含まれる。macOS 15 での確認は別になる。

## #25 Genie・Scale 最小化効果との連携可否

**結論: 公開 API では不可。** 最小化の処理と効果は OS に委譲する。効果（Genie と Scale）の見た目の違いは未確認。

### 根拠

- Apple の [Desktop & Dock settings — macOS 26](https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26) には、最小化の視覚効果を選ぶ設定があると書かれている。取得したページの本文には Genie と Scale の名前がなく、"Choose the visual effect used when you minimize a window." とだけある。
- `NSWindow.h` の最小化に関する API は、`miniaturize:`（394行目）、`deminiaturize:`（395行目）、`isMiniaturized`（398行目）、`performMiniaturize:`（491行目）と通知だけになる。効果の種類や最小化先を指定する API は見つからなかった。
- Accessibility の `kAXMinimizedAttribute`（`AXAttributeConstants.h:822`）は書き込み可能で、他のアプリのウィンドウを最小化できる。VM で、Safari のウィンドウの `AXMinimized` を true にすると、ウィンドウは最小化され、`min=1` になった。
- VM で、最小化したウィンドウは、標準 Dock の Accessibility ツリーに `AXMinimizedWindowDockItem`（タイトルは "Start Page"）として現れ、位置は Downloads のフォルダの右、ゴミ箱の左だった（[画像](../media/research-windows-spaces/25-minimized-window-tile-in-standard-dock.jpg)）。Custom Dock のパネルは最小化先にならない。
- 標準 Dock を自動非表示にした状態で、最小化と復元を行うと、同じ `AXMinimizedWindowDockItem` が作られた。最小化先の位置は、自動非表示のときは取得していない。
- 非公開のシンボル `_CoreDockGetEffect`、`_CoreDockSetEffect` などが `HIServices.tbd` に export されている。ヘッダはなく、採用しない。ゲストで `com.apple.dock` の `mineffect` を確認すると未設定だった。実測のために `scale` を書いて Dock を再起動し、確認後に削除した。この書き込みが Dock に反映されたかどうかと、Genie と Scale の見た目の違いは、確認していない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| OS が管理する最小化処理と Custom Dock が担当できる範囲を区別する | 最小化の実行は Accessibility で可能。最小化先（標準 Dock の右側のタイル）と効果は OS が管理する。Custom Dock が担当できるのは、最小化されたウィンドウの一覧と復元の呼び出しまで。復元は `AXMinimized` を false にして、VM で動いた |
| 標準 Dock 非表示・併用時の最小化先と効果を実測する | **一部を確認。** 併用時（標準 Dock を常時表示）の最小化先は、標準 Dock のタイルだった。自動非表示時の位置と、効果の見た目（Genie と Scale）は未確認 |
| 公開 API で変更できない場合は OS に委譲する方針と制約を記録する | 下の方針に記録した |

### 残る未確認

- Genie と Scale の見た目の違い、および Custom Dock のパネルがその上でどう見えるか（動画が必要）。
- 標準 Dock を自動非表示にした状態での、最小化先の位置。
- 標準 Dock を完全に使わない構成が可能か。
- macOS 15 での挙動。

### 実装する場合の方針と工数の見立て

- 方針は、最小化の効果を Dock Studio では扱わず、システム設定に委ねる。設定画面に「最小化の効果は、システム設定の Desktop & Dock で変更する」という案内を置く。
- 最小化されたウィンドウの表示と復元を Custom Dock に載せる場合は、Accessibility の許可を要する。別の項目として検討する。
- 案内文だけなら半日の見立てになる。見た目の確認のために、動画を撮る検証で1日を見込む。

## #28 Options から Spaces へアプリを割り当てる方法

**結論: 公開 API では不可。** 標準 Dock の Options の操作を Accessibility で代行する方法は、条件付きで可能だが、案内にとどめるのが安全。

### 根拠

- Apple の [Work in multiple spaces](https://support.apple.com/guide/mac-help/mh14112/26/mac/26) には、割当の選択肢として、All Desktops（"The app opens in every space."）、This Desktop（"The app opens only in the current space."）、Desktop on Display（"The app opens in the current space on a specific display (if more than one display is available)."）、None（"The app opens in whichever space you're using at the time."）がある。
- `NSWindow.collectionBehavior` は、自分のアプリのウィンドウにだけ効く。他のアプリのウィンドウの Space を指定する公開 API は、`NSWindow.h`、`NSScreen.h`、`NSWorkspace.h`、`NSRunningApplication.h` のどれにも見つからなかった。`NSScreen.screensHaveSeparateSpaces`（`NSScreen.h:31`）は読み取りだけになる。
- 非公開のシンボル `_CoreDockSetWorkspacesAppBindings`、`_CGSAddWindowsToSpaces` などが export されているが、ヘッダはなく、採用しない。
- VM で次を確認した。

| 状態と操作 | 結果 |
| --- | --- |
| Spaces が1つのとき、Safari の Dock メニューの Options | Keep in Dock、Open at Login、Show in Finder だけで、**Assign To はなかった** |
| Mission Control の Accessibility の「add desktop」を押して、Spaces を2つにしたとき | Options に **Assign To** が増え、**All Desktops、This Desktop、None** が出た（[画像](../media/research-windows-spaces/28-dock-menu-with-two-desktops.jpg)）。1画面なので、Desktop on Display は出なかった |
| Desktop 1 で、Assign To の This Desktop を `AXPress` で選ぶ | `defaults read com.apple.spaces app-bindings` が `{"com.apple.safari" = ""}` になった。Ctrl-Right で Desktop 2 へ移ると、Safari のウィンドウは見えなかった（[画像](../media/research-windows-spaces/28-desktop2-after-this-desktop.jpg)） |
| All Desktops を選ぶ | `app-bindings` が `{"com.apple.safari" = AllSpaces;}` になり、Desktop 2 でも Safari のウィンドウが見えた（CGWindowList で2つ） |
| None を選ぶ | `app-bindings` が `{}` になった |

- 割当は、標準 Dock が `com.apple.spaces` の `app-bindings` に保存する。このキーを他のアプリが直接書く方法は、今回は試しておらず、公式の文書もないので、採用しない。Accessibility で標準 Dock の項目を押す方法は、実際に動いたが、Spaces が2つ以上のときにだけ項目があり、標準 Dock のツリーの構造に依存する。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| All Desktops、This Desktop、None とディスプレイ別の条件を標準 Dock で確認する | **All Desktops、This Desktop、None は VM で確認した**（動作と保存値）。ディスプレイ別（Desktop on Display）は、1画面の VM では項目が出ず、**未確認** |
| 対象アプリの割当を変更できる公開経路を調査する | 公開 API は見つからなかった。Accessibility による標準 Dock の操作は動くが、非文書のツリーに依存する |
| OS 委譲が必要なら安全な設定への案内と制約を記録する | 下の方針に記録した |

### 残る未確認

- Desktop on Display（複数ディスプレイ）。
- Assign To の選択後に、アプリを再起動したときの挙動。
- 標準 Dock のアイコンがないアプリ（Custom Dock のみに載るアプリ）の扱い。
- システム設定の該当ペインを直接開く方法。
- macOS 15 での割当の選択肢。

### 実装する場合の方針と工数の見立て

- 方針は、Custom Dock のメニューに割当を直接変える項目は置かず、「標準 Dock のアイコンを Control クリックして、Options > Assign To から設定できる。Spaces が2つ以上のときに表示される」という案内を置く。
- 制約は、標準 Dock が起動していて、そのアプリのアイコンが標準 Dock に出ている場合に限る点になる。
- 案内文だけなら半日の見立てになる。Accessibility で代行する場合は、標準 Dock の構造への依存があるので、別途検討する。

## #55 Dock 表示領域とウィンドウの最大化・タイル配置の共存

**結論: 公開 API では不可。** 他のアプリの配置のために画面の利用可能領域を予約する公開 API は、見つからなかった。標準 Dock が領域を決め、Custom Dock のパネルは領域を予約しない。

### 根拠

- Apple の [Desktop & Dock settings — macOS 26](https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26) では、Fill は、メニューバーと Dock の間を埋める。Dock が側面にあるときは、メニューバーより下で、Dock の横を埋める。
- `NSScreen.h:35` の `visibleFrame` は読み取り専用になる。`NSScreen.h`、`NSWindow.h`、`NSApplication.h` を "strut"、"reserve"、"work area" で検索したが、領域を予約する API は見つからなかった。`NSApplicationPresentationOptions`（`NSApplication.h:136-139`）は、自分のアプリが前面のときだけ効く。
- VM（画面 1600×1000、メニューバー 30）で、Safari の1つのウィンドウに、メニューの Window > Fill と Window > Move & Resize > Left を `AXPress` で実行し、ウィンドウの座標と大きさを読んだ。

| 標準 Dock | Fill の結果 | Left のタイルの結果 |
| --- | --- | --- |
| 常時表示（下、高さ 90） | x=0, y=30, 1600×880 | x=0, y=30, 800×880 |
| 自動非表示 | x=0, y=30, 1600×970 | x=0, y=30, 800×970 |

- `NSScreen.visibleFrame` は、Dock を常時表示にすると `(0, 90, 1600, 880)`、自動非表示にすると `(0, 0, 1600, 970)` になった。Dock を再起動した直後に読むと、自動非表示でも古い値（高さ 880）が返ることがあった。Dock の切替の後は、数秒待ってから読む必要がある。
- Custom Dock のパネル（layer 21、483×157、下端近く）を表示し、標準 Dock を自動非表示にして Fill すると、ウィンドウは 1600×970 になり、パネルの領域と重なった。パネルはウィンドウの上に描画された（[画像](../media/research-windows-spaces/55-fill-with-custom-dock-autohide-on.jpg)）。
- 他のアプリのウィンドウを Accessibility で動かして避けさせる方法は、`kAXPositionAttribute` と `kAXSizeAttribute` を書き込めることが VM で確かめられた。ただし、OS のウィンドウ管理の再実装になり、受け入れ条件を満たさないので、採用しない。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 常時表示と自動非表示それぞれで、ウィンドウが Dock と重なる条件を確認する | **確認した**（下の Dock、1画面）。常時表示は Dock の高さ分を避け、自動非表示は全高になる。Custom Dock のパネルは、どちらでも避けられない。Dock が左右にある場合は未確認 |
| 公開 API で画面の利用可能領域を予約できるかを調査する | 見つからなかった。結論は、公開 API では不可 |
| OS のウィンドウ管理を再実装せずに利用できる方法と制約を記録する | 標準 Dock を併用し、標準 Dock の常時表示と小さいサイズで領域を確保する案を、下の方針に記録した |

### 残る未確認

- Dock が左右にあるときの Fill とタイル。
- "Tiled windows have margins" の設定の影響。
- 複数ディスプレイでの `visibleFrame`。
- macOS 15 での挙動。

### 実装する場合の方針と工数の見立て

- 方針の案は、標準 Dock を併用することを前提にして、Custom Dock の領域を予約しない。Custom Dock は自動非表示を既定とし、重なりは利用者が許容する構成にする。標準 Dock の設定を Dock Studio が書き換えることはしない。
- もう1つの案は、標準 Dock を残してサイズを最小にし、予約領域を狭く保つ案になる。
- 領域の予約そのものは実装できないので、表示と案内だけなら半日の見立てになる。

## #54 フルスクリーン・Spaces・Mission Control での Dock 互換性の検証

**結論: 一部を確認した。** Split View、クリック透過、デスクトップ表示、macOS 15、複数画面は未確認。

### 確認した結果

ゲストで DockStudio を起動し、設定の「デスクトップに Dock を表示」でパネルを出して、次を確認した。標準 Dock は自動非表示のままにした。

| 場面 | 結果 | 画像 |
| --- | --- | --- |
| 通常のデスクトップ | パネルが表示された（`CGWindowList` で layer 21、483×157） | [画像](../media/research-windows-spaces/54-02-panel-on-desktop.jpg) |
| Safari をフルスクリーンにした Space | パネルが画面下に表示された。ポインタを画面の中央に置いても、下端に置いても同じだった | [中央](../media/research-windows-spaces/54-03-fullscreen-pointer-away.jpg)、[下端](../media/research-windows-spaces/54-04-fullscreen-pointer-bottom.jpg) |
| Mission Control を開いたとき | デスクトップのパネルは、`CGWindowList` で 0×0 になり、画面から消えた。管理画面（通常のウィンドウ）の中のプレビューだけが残った。Spaces のバーに「Desktop」と「Safari（フルスクリーン）」が表示された | [画像](../media/research-windows-spaces/54-05-mission-control-fullscreen.jpg) |
| Mission Control からフルスクリーンの Space に戻る | パネルが元の位置（558, 846）に戻った | [画像](../media/research-windows-spaces/54-07-back-in-fullscreen-space.jpg) |
| Mission Control から Desktop の Space に切り替える | パネルが元の位置に表示された。通常のウィンドウより前面に描画された | [画像](../media/research-windows-spaces/54-08-desktop-space.jpg) |
| Stage Manager を有効にしたとき（`com.apple.WindowManager` の `GloballyEnabled` を true にして Dock を再起動した） | パネルは表示されたままだった。DockStudio の管理画面は、左端のストリップへ移った | [画像](../media/research-windows-spaces/54-10-stage-manager.jpg) |

- パネルの設定は、現在の `.canJoinAllSpaces`、`.fullScreenAuxiliary`、`.ignoresCycle` のままで、上の場面すべてで表示された。
- **`CanJoinAllApplications` は、今回のケース（Safari のフルスクリーンの Space）では不要だった。** このフラグを追加した別ビルドとの比較はしていない。ほかのアプリのフルスクリーンの Space と Split View で必要かどうかは、未確認になる。
- Mission Control でパネルが消える挙動は、`Transient`（"hidden by exposé"）の説明と合う。標準 Dock は Mission Control の間も表示された。仕様として許容するかどうかは、別に判断する。
- Ctrl-Left の合成で、フルスクリーンの Space から Desktop の Space への切替は起きなかった（Desktop 1 と Desktop 2 の間では起きた）。そのため、Space の切替は、Mission Control の Accessibility の「exit to Desktop」で行った。ショートカットでの切替の差は、原因を調べていない。
- デスクトップ表示（F11 のキー合成）は、画面に変化が出なかったため、確認できなかった。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| フルスクリーンと Split View で画面端からの表示・退避・起動を確認する | **フルスクリーンの表示は確認した。** 画面端からの退避と起動（ポインタでの操作）、Split View は未確認 |
| Mission Control、Stage Manager、デスクトップ表示、Space 切替時の重なりとクリック透過を確認する | Mission Control、Stage Manager、Space 切替は上の表のとおり確認した。**デスクトップ表示と、クリック透過は未確認** |
| macOS 15 と 26、複数画面で確認結果を残し、不足を個別修正へ分ける | macOS 26.6.2、1画面だけ。macOS 15 と複数画面は未確認。個別修正が要る不足は、今回の範囲では見つからなかった |

### 残る未確認

- Split View。
- クリックが下のウィンドウへ通るか、およびパネル上のクリックの動作。
- デスクトップ表示（ウィンドウを隠す操作）。
- ほかのアプリのフルスクリーンの Space（`CanJoinAllApplications` の要否）。
- フルスクリーンで標準 Dock が画面端から出るときの、パネルとの重なり。VM のポインタ操作では、標準 Dock が現れなかった。
- macOS 15、複数ディスプレイ。

### 実装する場合の方針と工数の見立て

- 現状のコードを変更する必要は、今回確認した範囲では見つからなかった。
- 未確認の項目の検証に、2日を見込む。macOS 15 の環境と複数ディスプレイは、別に用意が要る。
- 不足が見つかったら、`CanJoinAllApplications` の追加、`level` の調整、クリック透過の見直しなどを、個別の Issue に分ける。

## 実装に進める項目

公開 API だけで、追加の許可なしに完結する項目は見つからなかった。条件付きで進められる候補は次のとおり。

| 項目 | 内容 | 条件 |
| --- | --- | --- |
| #22 | 「全ウィンドウを表示」を、Accessibility またはイベント送信の許可がある場合だけ出す | 許可の案内、言語差の対応。macOS 15 は未確認 |
| #25 | 最小化の効果の案内文 | 見た目の確認は未了 |
| #28 | Spaces の割当の案内文 | 標準 Dock が使えるとき |
| #55 | 標準 Dock 併用を前提にした案内と既定値 | なし |
| #54 | 現状の設定のまま | 未確認の項目の追加検証 |

## 検証の記録

- VM の共有ロックは、取得のたびに10分以内で解放した。ゲストの設定（Dock の自動非表示、Spaces、`mineffect`、`app-bindings`、Stage Manager、DockStudio の保存データのパネル表示）は、元に戻した。
- 検証の途中で、ゲストに他の調査の作業の残り（VoiceOver の開始ダイアログと、起動したままの `osascript` と VoiceOver Quickstart）があった。ゲスト内のプロセスだけを個別に終了し、ダイアログを閉じた。今回の結果には影響していないと見ている。
- ビルドしたのは `5d761de` で、その後 main は進んでいる。今回の確認に関わる範囲（Custom Dock のパネルの設定）が変わったかどうかは、確認していない。

## 参考にした資料

- [What's it called on my Mac?](https://support.apple.com/en-gb/guide/mac-help/cpmh0038/mac)
- [Desktop & Dock settings — macOS 26](https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26)
- [Work in multiple spaces](https://support.apple.com/guide/mac-help/mh14112/26/mac/26)
- [Use apps in full screen](https://support.apple.com/guide/mac-help/mchl9c21d2be/26/mac/26)
- [NSWindow.CollectionBehavior（Apple Developer Documentation）](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)。ページが JavaScript で描画されるため本文を取得できず、意味の確認には SDK のヘッダを使った。
- SDK のヘッダ: `AppKit.framework/Headers/NSWindow.h`、`NSScreen.h`、`NSApplication.h`、`CoreGraphics.framework/Headers/CGEvent.h`、`CGWindow.h`、`HIServices.framework/Headers/AXActionConstants.h`、`AXAttributeConstants.h`、`AXRoleConstants.h`、`AXUIElement.h`
