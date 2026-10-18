# 入力と補助技術の調査（#32、#64、#69、#48、#49）

調査日は 2026-10-17 と 2026-10-18 になる。1 回目の調査は main の `3341868`（PR #6 のマージ後）、追加の確認は main の `5d761de`（PR #79 のマージ後、#66、#60、#68、#59、#44 を含む）をビルドして行った。macOS 15 以降を対象にしている。GUI の記録は macOS 26.6.2、1600×1000 の専用ヘッドレス VM で取得した既存の調査結果になる。この更新では VM とアプリを使わず、2026-10-18 時点で確認した main `9c9f340` のコードとマージ済み PR を根拠にした。アプリのコードは変更していない。

## 結論の一覧

| issue | 結論 | 根拠の要点 |
| --- | --- | --- |
| #32 spring-loading | 条件付きで可能（現在のパネル構成のままでは動かない） | 標準 Dock と試験パネルでの観察は、過去の VM 記録になる。現行 main `9c9f340` には並べ替え用の `DockDropDelegate` があるが、`NSSpringLoadingDestination` と spring-loading activation は見つからない |
| #64 Finder の選択を追加 | 条件付きで可能 | Services の登録（`pbs -dump_pboard`）と、`NSPerformService` による複数 URL の受け取りは確認した。Finder のメニューは「No Services Apply」のままで、Finder からの実行は確認できていない |
| #69 自動縮小 | 実装可能（仕様の決定が必要） | 標準 Dock の縮小を実測した。DockStudio は縮小せず、下配置 33 個は最後の項目が x=2049 で画面外、左配置 24 個も画面外になる。拡大率 2.0 の拡大表示は画面内に収まった |
| #48 矢印キー | ナビゲーションは実装済み、受け入れ条件の一部は未確認 | PR #99 で矢印、Home、End、文字入力、メニュー、Escape による復帰を実装し、PR #112 で初回フォーカスを修正した。PR #63 で Option+矢印の並べ替えも追加した。項目追加と非表示切替のフォーカスは未確認 |
| #49 VoiceOver | 一部のみ確認（実際の読み上げは未実施） | コードと過去のアクセシビリティ API 記録でラベルと操作を確認した。実際の VoiceOver 読み上げ、利用不可とウィジェットの状態は未確認。実機または検証用 Mac で手順に沿った確認が必要になる |

実装方法を検討できる項目は #32、#64、#69 になる。#48 の主要なキーボード操作は実装済みだが、受け入れ条件の一部が未確認である。VoiceOver の読み上げは未実施になる。

## 共通の注意

- 標準 Dock のキー操作は、VM へキーイベントを注入して確認した。VNC の接続が Dock のキーボードフォーカスを解除するため、キー操作とアクセシビリティ API の読み取りは同じ SSH セッション内で行った。
- 標準 Dock の Control-Fn-F3 は、`com.apple.symbolichotkeys` の項目 8 を明示して有効にしないと VM では動かなかった。この設定は調査後に削除した。
- 撮影は VM の画面共有を使った。比較動画は撮っていない。静止画だけで示せる項目だけを記録した。
- 2 回目の確認（2026-10-18）では、ロックを 10 分以内に区切って取り直した。

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
- 当初調査の main にはドロップ処理がなかった。現行 main `9c9f340` には並べ替え用の `.onDrop` と `DockDropDelegate` が追加されている（`DockStudio/CustomDockPreview.swift:139-141,534-554`）。検索したコードには `NSSpringLoadingDestination` と spring-loading の activation がなく、並べ替えのドロップと spring-loading は別の動作として扱う。
- Apple のドキュメント（<https://developer.apple.com/documentation/appkit/nsspringloadingdestination>）は、ドラッグ先とスプリングロード先を同じビューに実装でき、カーソル下のビューが優先されると説明している。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 標準 Dock が開く条件を VM で確認する | 確認した。下の「標準 Dock の観察」を参照 |
| 待機、キャンセル、ドロップを実装する | 実装していない（調査の範囲外）。試験パネルで、待機とドロップは確認した。キャンセルは未確認 |
| 通常のホバーと区別し、操作補助設定を尊重する | API 上は可能。`NSSpringLoadingEnabled` がユーザー設定に従う（ヘッダのコメント） |

### 標準 Dock の観察（2026-10-18、VM）

ゲストの CGEvent で、Finder のファイルを標準 Dock の項目へドラッグして保持した（ポインタの動きは保持中に止めた。Pointer Control の既定値は spring-loading が有効、遅延 0.5）。

| 対象 | 結果 |
| --- | --- |
| フォルダの項目（空のフォルダ） | 保持中に、そのフォルダの Finder ウインドウが開いた（`native-springload-folder-hold.png`）。保持したままドロップすると、ファイルがそのフォルダへ移動した（`native-springload-folder-after.png`） |
| アプリの項目（Safari） | 保持中に、ウインドウは開かず、アプリも前面にならなかった（`native-springload-app-hold.png`）。保持時間は約 7 秒 |

フォルダが開くまでの正確な時間は測っていない（保持開始の約 5 秒後の撮影で開いていた）。

### 試験アプリでの観察

scratchpad に作った試験アプリ（`NSSpringLoadingDestination` と `NSDraggingDestination` を実装した 3 枚のタイル）を VM で実行した。タイルの `springLoadingEntered` は `.enabled` を返し、各イベントの時刻をログへ書いた。

| 構成 | 結果 |
| --- | --- |
| タイトル付きウインドウ（通常の前面アプリ） | `draggingEntered`、`springLoadingEntered` の後、約 0.8 秒で `springLoadingActivated true` が呼ばれた |
| ボーダーレスの非アクティブ化パネル（Dock の 1 つ上のレベル、アクセサリアプリ）。DockStudio のパネルに近い構成 | `springLoadingEntered` と highlight 1 までで、約 6 秒保持しても `springLoadingActivated` は呼ばれなかった。ドロップは受けられた |
| 同じパネルで、通常のアプリ（`.regular`）にした場合 | 同じく呼ばれなかった |
| 同じパネルで、レベルも通常にした場合 | 同じく呼ばれなかった |
| ポインタの通過判定（`ignoresMouseEvents` をグローバル監視で切替）を再現した構成 | 他アプリが始めたドラッグ中も `.leftMouseDragged` の監視が届き（26 回）、ポインタがパネルに入った時点で入力を受け、ドロップできた |

注意として、ドラッグは合成した CGEvent で行っており、実際のポインタ操作とは異なる可能性がある。タイトル付きウインドウとの差が、ボーダーレスか、非アクティブ化パネルか、パネルであることか、のどれによるかは切り分けていない。

### 残る未確認

- ボーダーレスの非アクティブ化パネルで activation が呼ばれない原因と、回避策（例えばパネルを `.titled` にしてタイトルバーを隠す、または自前のタイマーで `draggingEntered` から待機する）。
- キャンセル（保持中にタイルの外へ出す）の挙動。
- 標準 Dock のフォルダが開くまでの正確な時間。

### 実装する場合の方針と工数

DockBar の項目に AppKit のビューを重ね、`NSSpringLoadingDestination` と `NSDraggingDestination` を実装する。待機はシステムが管理するため、独自のタイマーは不要になる。ポインタの通過判定は、ドラッグ中も監視が届くため、現在の仕組みのままドロップを受けられる見込みになる。ただし試験では、現在のパネル構成（ボーダーレスの非アクティブ化パネル）で spring-loading の activation が呼ばれなかったため、タイトル付きウインドウへ変える、または独自の待機を実装する必要がある。工数は 2 日から 3 日と見ている。

## #64 Finder の選択項目をキー操作で追加する

### 結論

条件付きで可能とする。Services は公開された経路だが、VM で登録と実行を確認していない。

### 根拠

- Apple の手順に、Control-Shift-Command-T で Finder の選択項目を標準 Dock へ追加する記述がある（<https://support.apple.com/en-us/102650>、<https://support.apple.com/guide/voiceover/vo2695/mac>）。取得した本文は「Add selected Finder item to the Dock」と「Navigate to the item in the Finder or on the desktop, then press Control-Shift-Command-T」になる。このキーは標準 Dock のため、上書きしない。
- Services の定義は Info.plist の `NSServices` になる（<https://developer.apple.com/documentation/bundleresources/information-property-list/nsservices>）。次のキーが公開されている。
  - `NSMenuItem`（メニュー項目名）、`NSMessage`（呼び出すメソッド）、`NSPortName`、`NSSendTypes`、`NSKeyEquivalent`（`default` キーで既定の呼び出しキーを指定できる）。
- SDK ヘッダ `NSApplication.h` に `servicesProvider`（544 行目）と `NSUpdateDynamicServices()`（623 行目）がある。
- 現状の DockStudio には `NSServices` がなく、項目の追加は `NSOpenPanel` の `chooseItems(kind:)` だけになる。`project.yml` は `GENERATE_INFOPLIST_FILE: YES` を使っている。配列の `NSServices` は `INFOPLIST_KEY_` で表せないため、Info.plist のファイルを足す必要がある。

現行 main `9c9f340` のコードと `project.yml` にも `NSServices`、`servicesProvider`、`NSPerformService` の実装は見つからず、Finder 選択の入口は未実装になる。

実装の追跡 issue は #140 になる。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| Finder の選択を公開された Services で受け取れるか | 調査した。経路は公開 API として存在する。VM での登録と実行は未確認 |
| 標準 Dock のキーを上書きせず、自作 Dock への操作を区別する | `NSKeyEquivalent` を設定せず、利用者が「システム設定 > キーボード > キーボードショートカット > サービス」で割り当てる形にすれば、標準のキーとは衝突しない。この割り当て画面の確認は未実施 |
| 複数選択、権限拒否、無効な対象を検証する | `NSPerformService` で確認した。複数の URL（ファイル、フォルダ、アプリ、読み取り権限のないファイル、存在しないパス）が、すべてサービスへ渡った。サービスは URL を受け取るだけで読まないため、権限のないファイルと存在しないパスも渡る。アプリ側で `ItemLaunchPolicy` の分類と存在確認が必要になる。サンドボックスでの権限拒否は未確認（DockStudio は非サンドボックス） |

### 試験アプリでの観察（2026-10-18、VM）

- 試験アプリを `~/Applications` へ置いて起動した後、`pbs -dump_pboard` に `Add to Dock Studio Probe`（`NSSendTypes` は `NSFilenamesPboardType` と `public.file-url`、`NSSendFileTypes` は `public.item`、`NSKeyEquivalent` は空）が登録されていた。
- `NSPerformService("Add to Dock Studio Probe", pasteboard)` で、6 件の URL（`probe-a.txt`、`probe-b.txt`、権限 000 の `locked.txt`、フォルダ、`/System/Applications/Mail.app`、存在しない `/nonexistent/file`）を渡した。サービスは `performed: true` を返し、ログに 6 件すべてが記録された。ペーストボードの型は `public.file-url`、`NSFilenamesPboardType` などだった。存在しないパス 1 件だけの呼び出しも同様に通った。
- Finder で 4 項目を選択（Cmd-A）し、Finder メニューの Services を開いたが、「No Services Apply」と「Services Settings…」だけが表示され、試験項目は出なかった。原因は切り分けていない（Services の有効化状態、VM の制約、選択の検証が AX 経由では走らない、などが考えられる）。

### 残る未確認

- Finder の Services メニューからの実行（上記のとおり表示されなかった）。
- 利用者が割り当てるキーボードショートカットの動作。
- サンドボックス下での権限拒否。
- メニューバーのアプリが未起動のときの挙動。

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

現行 main `9c9f340` でも、アイコン表示は `store.effectiveIconSize` を使い、`DockMetrics.length` は項目のサイズを足して長さを算出する（`DockStudio/CustomDockPreview.swift:241,746-768`）。項目数に応じてアイコンを縮小する処理は見つからない。

自動縮小の実装を追跡する issue は #141 になる。

専用 VM で、アイコン 52 px、プロファイルの項目 24 個を測定した。

| 配置 | パネルの大きさ | 最後の項目の位置 | 結果 |
| --- | --- | --- | --- |
| 下 | 幅 1580 | x=1491（幅 62） | 画面内に収まる |
| 左 | 高さ 950 | y=1691 | 画面の高さ 1000 を超え、画面外になる。スクロールで到達する |

2026-10-18 に、最新の main で追加の測定を行った。

| 条件 | 結果 |
| --- | --- |
| 下配置、33 個 | パネルの幅は 1580。ボタンは 33 個あり、最後の項目（Downloads）は x=2049 で画面幅 1600 の外になる。スクロールで到達する（`dockstudio-bottom-33.png`） |
| 下配置、24 個、拡大 2.0 | パネルの高さは 185 に増えた。右端付近の項目にポインタを置くと、拡大した項目と名前（Weather）が画面内に表示された。拡大した項目の右隣は画面端で切れた（`dockstudio-bottom-24-mag2.png`） |

前回、33 個の測定が失敗した原因は、アプリの起動から約 5 秒後にメニューバーの項目を操作したことだった（メニューバー項目の準備に 9 秒ほどかかり、`menu bar 2` が見つからなかった）。データの問題ではなく、33 個のプロファイルは正常に読み込めた。画像は他に左配置の `dockstudio-left-24.png` を保存している。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 標準 Dock で項目数、画面サイズ、拡大率を変えて記録する | 項目数と拡大の有無は記録した。画面サイズの変更は未確認（VM のディスプレイは 1600×1000 固定で、解像度を変える手段を用意できなかった）。標準 Dock の拡大率の値の変更は未確認。DockStudio の拡大率は 1.45 と 2.0 を確認した |
| 自作 Dock のスクロールとの違いを示し、標準互換モードの動作を決める | 違いを示した。標準 Dock は縮小で全項目を見せ、DockStudio は縦配置でスクロールが必要になる。採る動作の提案は下に書いた |
| 設定サイズを失わず、クリック領域、名前表示、ドラッグが画面内に収まる | 標準 Dock は設定値を保持し、画面内に収まった。DockStudio は縦配置の 24 個と、下配置の 33 個で項目が画面外に出る。名前表示は拡大 2.0 でも画面内に収まった。ドラッグは未確認 |

### 実装する場合の方針と工数

標準互換モードでは、表示用の実効サイズを `min(設定サイズ, 利用可能な長さ ÷ 項目数 から求めた値)` とし、保存する `iconSize` は変えない。`effectiveIconSize` が一時値を扱う仕組みを持つため、縮小用の別の値を足す形が自然になる。通常モードは現在のスクロールを残す案を提案する。縮小の下限は標準 Dock の観察では 24 px 付近まで下がったため、クリック領域の下限を別に決める必要がある。工数は 1 日前後と見ている。

## #48 矢印キーなどの Dock 内ナビゲーション

### 結論

当初調査で見つけた不足は、PR #99、#112、#63 で実装された。#48 の確認条件には、項目追加時や非表示切替時のフォーカス、左右配置での標準 Dock との照合など未確認の点が残るため、issue は完了扱いにしない。

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

### 当初調査時の受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 左右・下の配置で矢印移動、先頭末尾、名前での移動を照合する | 標準 Dock は下配置で照合した。左右配置の標準 Dock は未確認。DockStudio は、下配置と左配置の両方で、矢印（上下左右）、Home、End、文字入力がすべて効かないことを確認した。右配置は未確認（左配置と同じ `DockBar` を使う） |
| 項目の追加、削除、非表示への切替でフォーカスを失わない | 削除は確認した（下の観察）。追加と非表示への切替は未確認 |
| メニューの開閉と元のアプリへの復帰を確認し、不足を補う | 標準 Dock のメニュー（上キー）は確認した。DockStudio は、キーボードで項目メニューを開く手段が見つからず（下の観察）、元のアプリへの復帰も不足として確認した |

### DockStudio の追加観察（2026-10-18、最新の main）

| 操作 | 当時の結果 |
| --- | --- |
| 左配置で Tab、下、上、右、左、End、Home | Tab で先頭の Finder に当たる。それ以外のキーではフォーカスは変わらない。Tab を続けると、項目とグループが交互になる（Finder、グループ、Safari、グループ）。下配置と同じ |
| Control+Return、Control+Space、Shift+F10 | 項目のメニューは開かなかった（メニュー項目の一覧は変わらない） |
| メニューキー（キーコード 110） | 項目のメニューではなく、パネル全体のメニュー（「Dock を隠す」「キーボードで操作」とプロファイル名）が開いた |
| フォーカス中の項目へ `AXShowMenu`（アクセシビリティ API） | 「開く」「Finder で表示」「Dock から取り外す」の項目メニューが開いた。VoiceOver からはこの経路で開ける |
| 上のメニューの「Dock から取り外す」を押す | Safari が取り外された（ボタンは 12 個から 11 個になり、保存された `profiles.json` の項目名からも消えた）。管理画面に「Safari を Dock から取り外しました」と表示された |
| 取り外し直後のフォーカス | アクセシビリティ API が返すフォーカス要素はグループだったが、画面上では、取り外した項目の次の項目（Mail）に枠が表示された |

### マージ後の実装状況（2026-10-18、main `9c9f340`）

調査後、PR #99 で項目間の矢印移動、Home、End、名前による移動、上キーの項目メニュー、Escape によるフォーカス解除と前面アプリへの復帰を実装した。PR #112 は Dock に初めてキーボードフォーカスを移したときの先頭項目へのフォーカスを修正した。さらに PR #63 で Option+矢印によるピン留め項目の並べ替えと位置の読み上げを実装した。

現在のコードでは、配置に応じて移動方向とメニュー方向を分け（`DockStudio/Models/DockKeyboardNavigation.swift:20-27`）、項目の矢印、Home、End、文字入力を処理する（`DockStudio/CustomDockPreview.swift:467-499`）。初回フォーカスはパネルがキーになった後に項目へ設定し（同 `:432-450`、`DockStudio/Services/CustomDockWindowController.swift:157-172`）、Option+矢印では項目を並べ替えて位置を通知する（`DockStudio/CustomDockPreview.swift:470-477`）。PR #99 と #112 の記録では矢印移動を下・左・右配置で確認しているが、今回この更新では画面を再観察していない。

残る確認は、項目追加時と非表示からの復帰時にフォーカスを失わないこと、Home・End・名前による移動と標準 Dock の比較を左右配置でも行うことになる。削除時の次項目へのフォーカスは既存調査とコード（`DockStudio/CustomDockPreview.swift:143-148`）に根拠がある。Tab の一回停止、メニュー、Escape の復帰は PR #99 の最終ビルド記録で確認されているが、PR #112 の記録では Tab の左右配置が未確認とされているため、配置別の確認は完了扱いにしない。

キーボードだけで項目メニューを開く手段は、実装前の調査で試した 4 つの組合せでは見つからなかった。PR #99 で上キーからメニューを開く動作が実装された。

### 当初調査で確認した不足

上記は PR #99 より前の実装に対する不足になる。矢印移動、Tab の一回停止、項目メニュー、Escape による元のアプリへの復帰は PR #99 で実装され、初回フォーカスは PR #112 で修正された。現在残る確認は、項目追加時と非表示からの復帰時のフォーカス、標準 Dock との左右配置での照合になる。

### 実装案の更新

この節は PR #99 より前の実装案になる。矢印、Home、End、名前による移動、メニュー、Escape と Tab の停止回数は PR #99 で実装済みであり、初回フォーカスは #93 の PR #112 で修正された。追加時と非表示切替時のフォーカス維持は、必要性と挙動を改めて確認する。

## #49 VoiceOver の Dock 操作

### 結論

アクセシビリティ API 上のラベルと操作は確認した。VoiceOver の読み上げと VO-D の動作は確認できていない。

### 根拠と観察

Apple の手順では、VO-D で VoiceOver のカーソルを Dock へ移し、VO-Space で開き、VO-Shift-M で項目のメニューを開き、メニューの「オプション > Dock から削除」で取り外す（<https://support.apple.com/guide/voiceover/vo2695/mac>）。VO-D は OS の Dock を指す。

VM で、アクセシビリティ API から DockStudio のパネルを読み取った（`AXWindow` の `Dock Studio — Custom Dock` 配下）。

- 各項目は `AXButton` で、ラベルは項目名になる（Finder、Safari、Mail、Terminal、Calendar、Notes、Maps、Photos、Music、Messages、Preview、Downloads）。
- 起動中の項目は「Finder、起動中」のように読まれる。
- 各ボタンは `AXPress` と `AXShowMenu` を持つ。コードでは、項目ラベルとアクセシビリティアクションを設定している（`DockStudio/CustomDockPreview.swift:267-284`）。過去の API 読み取りでは `AXShowMenu` が項目のコンテキストメニュー（開く、Finder で表示）に対応した。
- Dock が隠れているときは、コードに「Custom Dock を表示」というボタン相当の要素と `accessibilityAction` がある（`CustomDockWindowController.swift`）。この状態の読み取りは、VM では行っていない。
- 時計と集中タイマーは、コードでラベルと値を持つ（`accessibilityLabel`、`accessibilityValue`）。読み取りは行っていない。
- VoiceOver が有効なときは、自動で隠す設定が無効になる（`autoHideEnabled` の `isVoiceOverEnabled` 判定）。

### 受け入れ条件ごとの確認結果

| 条件 | 結果 |
| --- | --- |
| 起動中、利用不可、ウィジェット等を正しく読み上げる | 起動中のラベルは API 上で確認した。利用不可とウィジェットは未確認。実際の VoiceOver 読み上げは未実施で、後述の手順が残る |
| 表示、項目選択、メニュー、起動、取り外しをキーボードだけで確認する | 表示（メニューバー経由）、項目選択（Tab）、起動（Return、Space）、メニュー（上キー）、Escape による復帰は、PR #99 と既存調査で確認されている。取り外しは過去にアクセシビリティ API で確認したが、VoiceOver のみでの一連の操作は未実施 |
| VO-D は OS の Dock を指すため、約束せず、利用可能な入口を案内する | VO-D は OS の Dock を指すと明記し、DockStudio にはメニューバーの「Dock をキーボードで操作」または設定済みの Dock フォーカス用ショートカットを案内する。コードにはメニュー項目（`DockStudio/WorkspaceView.swift:81`）とアクセシビリティアクション付きの表示ボタン（`DockStudio/Services/CustomDockWindowController.swift:431-435`）がある |

### VoiceOver の起動の試行（2026-10-18、VM の過去記録）

Command-F5 で VoiceOver を起動した。Quickstart が起動した後、VoiceOver のプロセスが動いたが、初回の「Welcome to VoiceOver」画面（Learn More、Use VoiceOver、Turn Off VoiceOver）が前面に残り、操作を進められなかった（`voiceover-enabled-dockstudio.png`）。アクセシビリティ API でボタンを押す操作（Quickstart のプロセス向け）は効かなかった。VoiceOver の AppleScript 経由の読み上げ取得は、問い合わせが返らず中断した。読み上げ文は取得できていない。

### 読み上げの確認状況と手順

実際の VoiceOver による読み上げは未実施になる。この更新では VM を使わず、実機の VoiceOver による観察も行っていない。以前の VM では初回の「Welcome to VoiceOver」画面を越えられず、読み上げ文を取得できなかった。

後日、専用の検証用 Mac または実機で次の手順を行う。

1. DockStudio を起動し、Command-F5 で VoiceOver を有効にする。初回の「Welcome to VoiceOver」が出た場合は「Use VoiceOver」を選び、初回設定を完了する。
2. VoiceOver のキャプションパネルを表示する。メニューバーから「Dock をキーボードで操作」を選ぶか、設定済みの Dock フォーカス用ショートカットで DockStudio に移る。
3. VO+右矢印で項目を順に移動し、起動中の項目、利用不可の項目、ウィジェットについて、キャプションパネルに出る読み上げを記録する。
4. 項目上で VO+Shift+M を押してメニューを開く。VO+右矢印で各メニュー項目へ移動し、VO+Space で「開く」または「Dock から取り外す」を選べるか記録する。VO-D は macOS 標準 Dock の操作なので、DockStudio への入口として扱わない。

### 残る未確認

- VoiceOver による読み上げ、VO-Space、VO-Shift-M の動作（上記の実機または検証用 Mac の手順で確認する）。
- 利用不可の項目（対象が存在しない項目）のラベル。

### 今後の確認と判断

読み上げの確認は実際の VoiceOver を使い、キャプション表示で読み上げ文を記録する。利用不可の項目には、「利用できません」のようなラベルの補足が必要か、実際の読み上げを聞いて判断する。キーボードのメニュー入口は #48 の PR #99 で実装済みになる。

## 追加で必要な検証

| 項目 | 内容 |
| --- | --- |
| #32 | ボーダーレスの非アクティブ化パネルで activation が呼ばれない原因と回避策。キャンセルの挙動 |
| #64 | Finder の Services メニューからの実行、サンドボックス下の権限拒否、未起動時の挙動 |
| #69 | 画面サイズの変更、標準 Dock の拡大率の変更、ドラッグ |
| #48 | 標準 Dock の左右配置で矢印、Home、End、名前移動を照合する。DockStudio の左右配置で Tab を確認し、項目追加と非表示からの復帰時のフォーカスを確認する |
| #49 | 実際の VoiceOver で読み上げ、VO-Space と VO-Shift-M を確認する。利用不可とウィジェットの読み上げも記録する |

## 検証後の VM の設定

Dock の設定は、調査前に書き出した内容へ戻した（`autohide` は 1、アプリの項目は 18 個で元のまま）。`AppleKeyboardUIMode` は元の 3 のままにした。追加した `symbolichotkeys` の項目 8 は削除した。2 回目の確認で書いた VoiceOver の 3 つの設定（キャプション、キャプションの位置、AppleScript）は削除した。VoiceOver、DockStudio、試験アプリは終了し、ゲストの作業ディレクトリ、試験用の文書、`~/Applications` の試験アプリは削除した。
