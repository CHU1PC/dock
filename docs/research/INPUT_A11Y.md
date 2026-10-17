# 入力と補助技術の調査（#32、#64、#69、#48、#49）

調査日は 2026-10-17 になる。対象は main の `3341868`（PR #6 のマージ後）で、macOS 15 以降を対象にしている。GUI の観察は macOS 26.6.2、1600×1000 の専用ヘッドレス VM で行い、ホストには検証画面を出していない。アプリのコードは変更していない。

## 結論の一覧

| issue | 結論 | 根拠の要点 |
| --- | --- | --- |
| #32 spring-loading | 条件付きで可能 | `NSSpringLoadingDestination` が公開 API として存在する。DockStudio のパネルがドラッグ中に入力を受けるかは未確認 |
| #64 Finder の選択を追加 | 条件付きで可能 | Services（`NSServices` と `servicesProvider`）が公開されている。VM での登録と実行は未確認 |
| #69 自動縮小 | 実装可能（仕様の決定が必要） | 標準 Dock の縮小を実測した。DockStudio は縮小せず、縦配置では項目が画面外へ出ることを確認した |
| #48 矢印キー | 不足を確認（補完は実装可能） | 標準 Dock は左右、Home、End、文字入力、上キーのメニューを確認した。DockStudio は Tab と Return と Space だけ動く |
| #49 VoiceOver | 一部のみ確認（実機の VoiceOver は未確認） | アクセシビリティ API 上のラベルと操作は確認した。読み上げと VO-D は未確認 |

実装可能と分かった項目は #69 と #48 になる。条件付きの項目は #32 と #64 になる。VoiceOver 自体の動作は、この調査では確認できていない。

## 共通の注意

- 標準 Dock のキー操作は、VM へキーイベントを注入して確認した。VNC の接続が Dock のキーボードフォーカスを解除するため、キー操作とアクセシビリティ API の読み取りは同じ SSH セッション内で行った。
- 標準 Dock の Control-Fn-F3 は、`com.apple.symbolichotkeys` の項目 8 を明示して有効にしないと VM では動かなかった。この設定は調査後に削除した。
- 撮影は VM の画面共有を使った。比較動画は撮っていない。静止画だけで示せる項目だけを記録した。
- VM のロックを 35 分以上保持した後で解放を求められたため、一部の項目は未確認として残した。

## #32 ドラッグ中のホバーでアプリやフォルダを開く

### 結論

条件付きで可能とする。公開 API は実在するが、DockStudio のパネル構成で動くかは実験していない。

### 根拠

- Apple の公式手順に、Pointer Control の「Spring-loading」と「Spring-loading speed」がある。フォルダへドラッグして保持すると開く（<https://support.apple.com/guide/mac-help/unac899/mac>）。取得した本文は「drag an item to a folder and hold to open the folder」になる。
- SDK ヘッダ `AppKit.framework/Headers/NSDragging.h` に次の定義がある。
  - 164 行目 `NSSpringLoadingOptions`（`NSSpringLoadingEnabled` はコメントで「hover timeout depending on user preferences」と説明している）。ユーザー設定に従う記述があるため、OS の操作補助設定を尊重できる。
  - 175 行目 `@protocol NSSpringLoadingDestination`（`springLoadingEntered:`、`springLoadingActivated:draggingInfo:`、`springLoadingHighlightChanged:`、`springLoadingExited:`）。
  - 59 行目 `NSSpringLoadingHighlight`（None、Standard、Emphasized）。
- SwiftUI の swiftinterface に `springLoadingBehavior(_:)` がある（macOS 14 以降）。ただし対象は View の動作の指定であり、任意のタイルで待機とキャンセルを自前で扱う用途には、AppKit のプロトコルが向く。
- DockStudio には `onDrop`、`dropDestination`、`registerForDraggedTypes` がない（`grep` で確認した）。
- Apple のドキュメント（<https://developer.apple.com/documentation/appkit/nsspringloadingdestination>）は、ドラッグ先とスプリングロード先を同じビューに実装でき、カーソル下のビューが優先されると説明している。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 標準 Dock が開く条件を VM で確認する | 未確認。VM でのドラッグ操作を行う前にロックの解放を求められた |
| 待機、キャンセル、ドロップを実装する | 実装していない（調査の範囲外）。方針は下に書いた |
| 通常のホバーと区別し、操作補助設定を尊重する | API 上は可能。`NSSpringLoadingEnabled` がユーザー設定に従う（ヘッダのコメント） |

### 残る未確認

- 標準 Dock が、アプリアイコンとフォルダで何を開くか。
- `CustomDockWindowController` は、ポインタが外にあると `panel.ignoresMouseEvents = true` にする。更新のきっかけはグローバルのマウス監視（`.mouseMoved`、`.leftMouseDragged`）で、他アプリが始めたドラッグ中にこの監視が届くかは未確認になる。届かないとドロップを受けられない。
- この確認用に、パネル、`NSSpringLoadingDestination` の実装、ログ出力だけの小さな試験アプリを scratchpad に作ったが、実行していない。再開時はこのアプリを VM へ入れて、Finder から項目を引いて確認する。

### 実装する場合の方針と工数

DockBar の項目に AppKit のビューを重ね、`NSSpringLoadingDestination` と `NSDraggingDestination` を実装する。待機はシステムが管理するため、独自のタイマーは不要になる。ドロップ中はパネルが入力を受けるよう、`updatePointerPassThrough` を、ドラッグ中は常に受ける形へ変える必要があるかもしれない。工数は 2 日前後と見ている。ドラッグ中の入力の可否が決まらないと、見積りは確定しない。

## #64 Finder の選択項目をキー操作で追加する

### 結論

条件付きで可能とする。Services は公開された経路だが、VM で登録と実行を確認していない。

### 根拠

- Apple の手順に、Control-Shift-Command-T で Finder の選択項目を標準 Dock へ追加する記述がある（<https://support.apple.com/en-us/102650>、<https://support.apple.com/guide/voiceover/vo2695/mac>）。取得した本文は「Add selected Finder item to the Dock」と「Navigate to the item in the Finder or on the desktop, then press Control-Shift-Command-T」になる。このキーは標準 Dock のため、上書きしない。
- Services の定義は Info.plist の `NSServices` になる（<https://developer.apple.com/documentation/bundleresources/information-property-list/nsservices>）。次のキーが公開されている。
  - `NSMenuItem`（メニュー項目名）、`NSMessage`（呼び出すメソッド）、`NSPortName`、`NSSendTypes`、`NSKeyEquivalent`（`default` キーで既定の呼び出しキーを指定できる）。
- SDK ヘッダ `NSApplication.h` に `servicesProvider`（544 行目）と `NSUpdateDynamicServices()`（623 行目）がある。
- 現状の DockStudio には `NSServices` がなく、項目の追加は `NSOpenPanel` の `chooseItems(kind:)` だけになる。`project.yml` は `GENERATE_INFOPLIST_FILE: YES` を使っている。配列の `NSServices` は `INFOPLIST_KEY_` で表せないため、Info.plist のファイルを足す必要がある。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| Finder の選択を公開された Services で受け取れるか | 調査した。経路は公開 API として存在する。VM での登録と実行は未確認 |
| 標準 Dock のキーを上書きせず、自作 Dock への操作を区別する | `NSKeyEquivalent` を設定せず、利用者が「システム設定 > キーボード > キーボードショートカット > サービス」で割り当てる形にすれば、標準のキーとは衝突しない。この割り当て画面の確認は未実施 |
| 複数選択、権限拒否、無効な対象を検証する | 未確認。複数選択はペーストボードのファイル URL が複数になる想定。無効な対象は、既存の `ItemLaunchPolicy` の分類（アプリ、フォルダ、ファイル、スクリプトの拒否）を流用できる。権限拒否は、非サンドボックスのため通常は起きない |

### 残る未確認

- Services の試験用の項目（`Add to Dock Studio Probe`）を持つ試験アプリを作ったが、VM で実行していない。Finder の Services メニューへの表示、複数選択、メニューバーのアプリが未起動のときの挙動は未確認になる。

### 実装する場合の方針と工数

Info.plist に `NSServices` を追加し、アプリ起動時に `servicesProvider` を設定する。受け取った URL は、ドロップ（#32）と同じ判定関数で項目の種類へ分類し、既存の `addItem` へ渡す。編集中の下書きを壊さない扱いが要るため、追加先のプロファイルを決める仕様が先に必要になる。工数は 1 日から 1.5 日と見ている。

## #69 項目数が増えたときの自動縮小

### 結論

標準 Dock の挙動は実測した。DockStudio に縮小の実装は可能で、標準互換モードでの採用を決める必要がある。

### 標準 Dock の実測

条件は、下配置、Dock のサイズ設定 64（`tilesize`）、拡大なし、自動で隠さない、1600×1000 になる。アクセシビリティ API で Dock のリストの大きさを読み取った（`list 1` の大きさとアイテムの大きさ）。

| アプリの数 | 要素数 | リストの幅 | リストの高さ | アイテムの幅 |
| --- | --- | --- | --- | --- |
| 8 | 13 | 862 | 84 | 68 |
| 12 | 17 | 1134 | 84 | 68 |
| 16 | 21 | 1406 | 84 | 68 |
| 20 | 25 | 1506 | 77 | 60 |
| 24 | 29 | 1522 | 69 | 52 |
| 28 | 33 | 1524 | 59 | 46 |
| 32 | 37 | 1534 | 54 | 41 |
| 40 | 45 | 1548 | 47 | 34 |
| 60 | 65 | 1576 | 36 | 24 |

- 16 個までは設定したサイズのまま、20 個から幅を保つように縮小した。60 個でも全項目が表示され、スクロールはない（要素数がすべて残っている）。
- 縮小後も設定値の `tilesize` は 64 のままだった。画面の端には、60 個で約 12 px の余白が残る。
- 左配置で 40 個にすると、リストの高さは 952 になり、画面内に収まった。
- 拡大を有効にした 60 個の状態でも、拡大したアイコンと名前の表示は画面内に収まった。

画像は `docs/media/research-input-a11y/` の `native-bottom-8.png`、`native-bottom-20.png`、`native-bottom-32.png`、`native-bottom-60.png`、`native-left-40.png`、`native-bottom-60-magnified.png` になる。

### DockStudio の現状

コードでは、`CustomDockPreview.swift` の `DockMetrics.length` が項目数に比例して長さを決め、パネルの長さは画面幅（縦は可視領域の高さ）に制限される。内容は `ScrollView` に入り、縮小はない。

専用 VM で、アイコン 52 px、プロファイルの項目 24 個を測定した。

| 配置 | パネルの大きさ | 最後の項目の位置 | 結果 |
| --- | --- | --- | --- |
| 下 | 幅 1580 | x=1491（幅 62） | 画面内に収まる |
| 左 | 高さ 950 | y=1691 | 画面の高さ 1000 を超え、画面外になる。スクロールで到達する |

下配置の 33 個は VM でアプリが起動せず、測定できなかった。画像は左配置の `dockstudio-left-24.png` だけを保存した（下配置の撮影は VM の接続が止まって保存できなかった。数値は上の表のとおりアクセシビリティ API から読み取った）。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 標準 Dock で項目数、画面サイズ、拡大率を変えて記録する | 項目数と拡大の有無は記録した。画面サイズの変更と、拡大率スライダーの値の変更は未確認 |
| 自作 Dock のスクロールとの違いを示し、標準互換モードの動作を決める | 違いを示した。標準 Dock は縮小で全項目を見せ、DockStudio は縦配置でスクロールが必要になる。採る動作の提案は下に書いた |
| 設定サイズを失わず、クリック領域、名前表示、ドラッグが画面内に収まる | 標準 Dock は設定値を保持し、画面内に収まった。DockStudio は縦配置で収まらない。名前表示とドラッグは未確認 |

### 実装する場合の方針と工数

標準互換モードでは、表示用の実効サイズを `min(設定サイズ, 利用可能な長さ ÷ 項目数 から求めた値)` とし、保存する `iconSize` は変えない。`effectiveIconSize` が一時値を扱う仕組みを持つため、縮小用の別の値を足す形が自然になる。通常モードは現在のスクロールを残す案を提案する。縮小の下限は標準 Dock の観察では 24 px 付近まで下がったため、クリック領域の下限を別に決める必要がある。工数は 1 日前後と見ている。

## #48 矢印キーなどの Dock 内ナビゲーション

### 結論

不足を確認した。DockStudio は矢印キーによる移動を実装しておらず、補完は実装可能と判断する。

### 標準 Dock の観察

Apple の手順では、Fn-Control-F3 で Dock へ移り、左右の矢印で移動し、Return で開く（<https://support.apple.com/guide/mac-help/mh35859/26/mac/26>）。VoiceOver の手順には、移動、先頭の文字入力、Escape での退出がある。

VM で確認した結果は次のとおりになる（下配置、キーボードフォーカス開始直後は先頭の Finder に当たる）。

| 操作 | 結果 |
| --- | --- |
| Fn-Control-F3 | 先頭の項目にフォーカスが当たり、名前が表示される |
| 右キー | 次の項目へ移動した |
| End | 最後の項目（ゴミ箱）へ移動した |
| End の後に左キー | ひとつ前（Downloads）へ移動した |
| Home | 先頭へ移動した |
| 先頭で左キー | フォーカスが外れた。折り返しはない |
| 末尾で右キー | フォーカスが外れた。折り返しはない |
| 文字（`m`、`s`） | 該当の名前の項目（Mail、Safari）へ移動した |
| 上キー | その項目のメニューが開いた |
| 上キーの後に Escape | メニューが閉じ、項目へのフォーカスは残った。もう一度 Escape で外れた |
| Return | 項目を開いた（アプリが前面になった） |
| Escape（フォーカス中） | フォーカスが外れ、前面のアプリは変わらなかった |

下キーでも、Calendar の項目のメニューに相当する表示が出たが、フォーカスの開始位置が前の操作に影響された可能性があり、確定とは扱わない。画像は `native-keyboard-up-menu.png` と `native-keyboard-typeahead.png` に保存した。

### DockStudio の観察

初回のキー操作が反応しなかった原因は、キー入力が届く前の状態の取り違えだった。最終的に、新規起動、メニューバーの「Dock をキーボードで操作」の実行、キー注入、アクセシビリティ API でのフォーカス要素の取得、の順で確認した。

| 操作 | 結果 |
| --- | --- |
| メニューから「Dock をキーボードで操作」 | パネルがキーウインドウになる。フォーカスは項目ではなくスクロール領域に当たる |
| Tab | 先頭の項目（Finder）へ移動した |
| Tab を続ける | 項目と、項目ではないグループへ交互にフォーカスが当たる（Finder、グループ、Safari、グループ） |
| Shift-Tab | 逆順に戻る。同様にグループが挟まる |
| 右、左、上、下、Home、End、文字 | フォーカスは変わらない（未実装） |
| Return、Space | 項目を開き、アプリが前面になる |
| Escape | パネルがキーでなくなるが、起動前の前面アプリには戻らない（Calendar が前面の状態から実行し、DockStudio のままだった） |

DockStudio のキー操作の撮影は保存していない。キー操作の結果は、アクセシビリティ API の出力から読み取った。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 左右・下の配置で矢印移動、先頭末尾、名前での移動を照合する | 標準 Dock は下配置で照合した。左右配置の標準 Dock は未確認。DockStudio は矢印、先頭末尾、名前での移動がすべて未実装であることを下配置で確認した。左右配置の DockStudio も、同じ `DockBar` のため同様と推定するが、実測していない |
| 項目の追加、削除、非表示への切替でフォーカスを失わない | 未確認。コード上は `onChange(of: items.map(\.id)) { hovered = nil }` がホバーだけを消し、フォーカスは SwiftUI に任せている。実測は残っている |
| メニューの開閉と元のアプリへの復帰を確認し、不足を補う | 標準 Dock のメニュー（上キー）は確認した。DockStudio は、キーボードでの項目メニューの開き方が未確認で、元のアプリへの復帰は不足として確認した |

### 不足と再現手順

1. 矢印キーなどで項目を移動できない。再現手順は、メニューバーの「Dock をキーボードで操作」を実行して Tab を押し、右キーを押す。
2. Tab が項目ごとに 2 回必要になる。再現手順は、同じ状態で Tab を続けて押す。
3. Escape で元のアプリへ戻らない。再現手順は、別のアプリを前面にして「Dock をキーボードで操作」を実行し、Escape を押す。

### 直す方針と工数

`DockBar` に `onMoveCommand`（`CustomDockPreview.swift` の SwiftUI 側、macOS 向けに実在する。swiftinterface の `onMoveCommand(perform:)`）か、フォーカス用の状態を持つ `@FocusState` を足し、左右（縦配置では上下）、Home、End、文字入力で移動する。標準 Dock の観察どおり、端では折り返さずフォーカスを外す。2 回の Tab の原因は、`Button` の外側の `.focusable()` が別の停止位置を作っている可能性が高く、外すかボタン側へ寄せることで直る見込みになる。元のアプリへの復帰は、`focusDock` の前に `NSWorkspace.shared.frontmostApplication` を保存し、Escape で再度前面にする。工数は 1 日前後と見ている。

## #49 VoiceOver の Dock 操作

### 結論

アクセシビリティ API 上のラベルと操作は確認した。VoiceOver の読み上げと VO-D の動作は確認できていない。

### 根拠と観察

Apple の手順では、VO-D で VoiceOver のカーソルを Dock へ移し、VO-Space で開き、VO-Shift-M で項目のメニューを開き、メニューの「オプション > Dock から削除」で取り外す（<https://support.apple.com/guide/voiceover/vo2695/mac>）。VO-D は OS の Dock を指す。

VM で、アクセシビリティ API から DockStudio のパネルを読み取った（`AXWindow` の `Dock Studio — Custom Dock` 配下）。

- 各項目は `AXButton` で、ラベルは項目名になる（Finder、Safari、Mail、Terminal、Calendar、Notes、Maps、Photos、Music、Messages、Preview、Downloads）。
- 起動中の項目は「Finder、起動中」のように読まれる。
- 各ボタンは `AXPress` と `AXShowMenu` を持つ。`AXShowMenu` は項目のコンテキストメニュー（開く、Finder で表示）に当たる。
- Dock が隠れているときは、コードに「Custom Dock を表示」というボタン相当の要素と `accessibilityAction` がある（`CustomDockWindowController.swift`）。この状態の読み取りは、VM では行っていない。
- 時計と集中タイマーは、コードでラベルと値を持つ（`accessibilityLabel`、`accessibilityValue`）。読み取りは行っていない。
- VoiceOver が有効なときは、自動で隠す設定が無効になる（`autoHideEnabled` の `isVoiceOverEnabled` 判定）。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 起動中、利用不可、ウィジェット等を正しく読み上げる | 起動中のラベルは API 上で確認した。利用不可の項目とウィジェットは未確認。読み上げ自体は VoiceOver を起動しておらず未確認 |
| 表示、項目選択、メニュー、起動、取り外しをキーボードだけで確認する | 表示（メニューバー経由）、項目選択（Tab）、起動（Return、Space）は確認した。メニューと取り外しのキーボード操作は未確認 |
| VO-D は OS の Dock を指すため、約束せず、利用可能な入口を案内する | 利用可能な入口として、メニューバーの「Dock をキーボードで操作」があり、アクセシビリティ API から実行できることを確認した。案内の文言は未作成 |

### 残る未確認

- VoiceOver を起動した状態での読み上げ、VO-Space、VO-Shift-M の動作。
- 利用不可の項目（対象が存在しない項目）のラベル。試験用のプロファイルに、存在しないアプリ（`Voice Memos.app` は実際には `VoiceMemos.app`）が入っていたが、その状態の読み取りは保存していない。

### 実装する場合の方針と工数

読み上げの確認は VM で VoiceOver を起動する必要があり、キャプション表示で読み上げ文を撮るのが現実的になる。利用不可の項目には、「利用できません」のようなラベルの補足を足す。メニューの入口は、#48 の矢印移動の補完と合わせて行う。工数は 0.5 日から 1 日と見ている。

## 追加で必要な検証

| 項目 | 内容 |
| --- | --- |
| #32 | 標準 Dock のスプリングロード（アプリ、フォルダ）と、試験アプリでのドラッグ中の入力の確認 |
| #64 | 試験アプリでの Services の登録、複数選択、メニューバーのアプリが未起動のときの挙動 |
| #69 | 33 個の DockStudio の測定、画面サイズと拡大率の変更、名前表示とドラッグ |
| #48 | 左右配置の標準 Dock と DockStudio、項目の追加と削除時のフォーカス |
| #49 | 実際の VoiceOver での読み上げ、利用不可とウィジェットの項目 |

## 検証後の VM の設定

Dock の設定は、調査前に書き出した内容へ戻した。`AppleKeyboardUIMode` は元の 3 へ戻し、追加した `symbolichotkeys` の項目 8 は削除した。DockStudio と試験アプリは終了し、削除した。
