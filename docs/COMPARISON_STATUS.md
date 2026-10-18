# Apple Dock 比較 Issue の現在状況

2026-10-18 時点で、Issue #7 の本文が参照する Issue #8〜#71 を確認した。状態は `gh issue list --state all`、関連するマージ済み PR は `gh issue view` の `closedByPullRequestsReferences`、現在の機能は `origin/main` のコードと `git log origin/main --oneline` を根拠にした。OPEN は GitHub 上で未クローズという意味になり、機能の有無は別列に記した。

Issue #7 が基準として挙げる PR #5 と PR #6 は Issue ではないため、下表の対象外になる。両方とも MERGED で、PR #5 は Apple Dock 背景、PR #6 は Dock 表示アニメーション時間の設定を追加した。

| Issue | GitHub の状態 | DockStudio の現在の動作 |
| --- | --- | --- |
| [#8 ドラッグで追加](https://github.com/CHU1PC/dock/issues/8) | CLOSED、PR #92 MERGED | Dock へのドラッグでアプリ、ファイル、フォルダを追加できる。 |
| [#9 Dock 上で並べ替え](https://github.com/CHU1PC/dock/issues/9) | OPEN | ポインタのドラッグによる並べ替えはない。編集画面の操作と Option+矢印による並べ替えは使える。 |
| [#10 ドラッグで取り外し](https://github.com/CHU1PC/dock/issues/10) | CLOSED、PR #96 MERGED | ピン留め項目を Dock の外へドラッグして取り外せる。 |
| [#11 実行中アプリを保持](https://github.com/CHU1PC/dock/issues/11) | CLOSED、PR #91 MERGED | 実行中アプリのメニューからプロファイルへ保持、または保持解除できる。 |
| [#12 種類別に区切る](https://github.com/CHU1PC/dock/issues/12) | OPEN | 項目は単一の並びに表示され、アプリ、最近使った項目、書類の区画はない。 |
| [#13 最近使ったアプリ](https://github.com/CHU1PC/dock/issues/13) | OPEN | 未固定の最近使ったアプリを最大3件表示する実装がある。GitHub Issue は未クローズになる。 |
| [#14 OS の提案項目](https://github.com/CHU1PC/dock/issues/14) | OPEN | OS が提案するアプリの一覧は取得、表示しない。 |
| [#15 通常終了](https://github.com/CHU1PC/dock/issues/15) | CLOSED、PR #90 MERGED | 実行中アプリのメニューから通常終了できる。 |
| [#16 強制終了](https://github.com/CHU1PC/dock/issues/16) | OPEN | 実行中アプリのメニューから確認付きで強制終了できる。Issue は未クローズになる。 |
| [#17 アプリを隠す、再表示する](https://github.com/CHU1PC/dock/issues/17) | OPEN | アプリのメニューから隠す、または再表示できる。Issue は未クローズになる。 |
| [#18 Command クリックで Finder 表示](https://github.com/CHU1PC/dock/issues/18) | OPEN | Command クリックで対象を Finder に表示する実装がある。Issue は未クローズになる。 |
| [#19 Option クリックで隠す](https://github.com/CHU1PC/dock/issues/19) | CLOSED、PR #106 MERGED | Option クリックで現在のアプリを隠して前のアプリへ戻れる。 |
| [#20 Command+Option で他を隠す](https://github.com/CHU1PC/dock/issues/20) | OPEN | 対象アプリ以外を隠すクリック操作とメニュー項目がある。Issue は未クローズになる。 |
| [#21 アプリのウィンドウ一覧](https://github.com/CHU1PC/dock/issues/21) | OPEN | 最小化したウィンドウは別項目で表示できるが、アプリの通常ウィンドウ一覧は出さない。 |
| [#22 Show All Windows](https://github.com/CHU1PC/dock/issues/22) | OPEN | App Exposé を呼び出す実装はない。 |
| [#23 最小化ウィンドウを表示、復元](https://github.com/CHU1PC/dock/issues/23) | OPEN | 最小化ウィンドウを Dock に並べ、クリックで復元する実装がある。Issue は未クローズになる。 |
| [#24 最小化ウィンドウをアプリアイコン内にまとめる](https://github.com/CHU1PC/dock/issues/24) | OPEN | 最小化ウィンドウはアプリアイコン内ではなく、独立した Dock 項目に表示する。 |
| [#25 Genie、Scale 効果との連携](https://github.com/CHU1PC/dock/issues/25) | OPEN | OS の最小化効果を読み取り、DockStudio と連携する実装はない。 |
| [#26 最近使った書類](https://github.com/CHU1PC/dock/issues/26) | OPEN | アプリごとの最近使った書類メニューを表示しない。 |
| [#27 アプリ固有の Dock メニュー](https://github.com/CHU1PC/dock/issues/27) | OPEN | DockStudio 共通の項目メニューを表示し、他アプリ固有の Dock メニューは取得しない。 |
| [#28 Spaces への割当](https://github.com/CHU1PC/dock/issues/28) | OPEN | DockStudio パネルは全 Space に参加するが、個別アプリの Spaces 割当を変更しない。 |
| [#29 アプリごとの Open at Login](https://github.com/CHU1PC/dock/issues/29) | OPEN | 他アプリのログイン起動設定を表示、変更しない。 |
| [#30 ファイルをアプリアイコンへドロップ](https://github.com/CHU1PC/dock/issues/30) | OPEN | 項目追加用のドロップはあるが、既存アプリアイコンへのファイル渡しは実装されていない。 |
| [#31 Dock フォルダの内容を開く](https://github.com/CHU1PC/dock/issues/31) | OPEN | フォルダをリスト形式のポップオーバーで展開し、中の項目を開ける。 |
| [#32 ドラッグ中のホバーで開く](https://github.com/CHU1PC/dock/issues/32) | OPEN | ドラッグ中の項目上で待機してフォルダやアプリを開く spring-loading はない。 |
| [#33 Grid 表示](https://github.com/CHU1PC/dock/issues/33) | OPEN | フォルダ内容はリスト表示で、Grid 表示はない。 |
| [#34 Fan 表示](https://github.com/CHU1PC/dock/issues/34) | OPEN | フォルダ内容はリスト表示で、Fan 表示はない。 |
| [#35 フォルダ項目の並べ替え](https://github.com/CHU1PC/dock/issues/35) | OPEN | フォルダ内項目の表示順を選択する設定はない。 |
| [#36 Folder、Stack の切替](https://github.com/CHU1PC/dock/issues/36) | OPEN | フォルダ内容をリストで開くが、Folder と Stack の表示形式を切り替えない。 |
| [#37 常設のゴミ箱](https://github.com/CHU1PC/dock/issues/37) | OPEN | ゴミ箱を Dock の末尾に常設し、開く操作と空、項目あり、不明の状態を表示する。 |
| [#38 ゴミ箱へドロップ](https://github.com/CHU1PC/dock/issues/38) | OPEN | ファイルをゴミ箱へドロップして移動できる。Issue は未クローズになる。 |
| [#39 ゴミ箱を空にする](https://github.com/CHU1PC/dock/issues/39) | OPEN | ゴミ箱メニューから開く操作はあるが、空にする操作はない。 |
| [#40 外部ディスクを取り出す](https://github.com/CHU1PC/dock/issues/40) | OPEN | 対応するボリュームを Dock の外へドラッグして取り出せる。 |
| [#41 通知バッジ](https://github.com/CHU1PC/dock/issues/41) | OPEN | 他アプリの通知バッジを取得、表示しない。 |
| [#42 動的アプリアイコン](https://github.com/CHU1PC/dock/issues/42) | OPEN | アイコン画像を表示するが、他アプリの Dock 上の動的な描画更新は読み取らない。 |
| [#43 ファイル転送の進捗表示](https://github.com/CHU1PC/dock/issues/43) | CLOSED、PR #80 MERGED | 他アプリの転送進捗を DockStudio に表示する機能はない。調査結果は PR #80 に記録されている。 |
| [#44 起動時のバウンド](https://github.com/CHU1PC/dock/issues/44) | CLOSED、PR #79 MERGED | 起動時のアイコンバウンドを設定できる。 |
| [#45 他アプリの注意要求バウンド](https://github.com/CHU1PC/dock/issues/45) | OPEN | DockStudio 自身の起動アニメーションはあるが、他アプリの注意要求は連携しない。 |
| [#46 参照切れの表示](https://github.com/CHU1PC/dock/issues/46) | CLOSED、PR #94 MERGED | 参照できない項目を利用不可としてアイコン表示に反映する。 |
| [#47 グローバルキーで Dock にフォーカス](https://github.com/CHU1PC/dock/issues/47) | OPEN | 設定可能なグローバルショートカットで Dock にフォーカスできる。 |
| [#48 Dock 内キーボード移動](https://github.com/CHU1PC/dock/issues/48) | OPEN | 矢印、Home、End、名前検索のキーボード移動を実装している。標準 Dock との全条件照合は未完了になる。 |
| [#49 VoiceOver 操作](https://github.com/CHU1PC/dock/issues/49) | OPEN | 項目ラベルとアクセシビリティアクションを用意するが、VoiceOver の一連の操作は未確認になる。 |
| [#50 区切り線でサイズ変更](https://github.com/CHU1PC/dock/issues/50) | OPEN | サイズ変更は設定画面のスライダーで行い、区切り線のドラッグには対応しない。 |
| [#51 区切り線の設定メニュー](https://github.com/CHU1PC/dock/issues/51) | OPEN | Dock 背景のメニューはあるが、標準 Dock の配置、拡大、自動非表示メニューとは一致しない。 |
| [#52 キーボードで表示切替](https://github.com/CHU1PC/dock/issues/52) | CLOSED、PR #110 MERGED | 設定済みショートカットで Dock の表示と非表示を切り替えられる。 |
| [#53 複数ディスプレイで Dock 呼出し](https://github.com/CHU1PC/dock/issues/53) | OPEN | 表示先の画面を選べるが、ポインタがある画面端への自動呼出しはない。 |
| [#54 Full Screen、Spaces、Mission Control](https://github.com/CHU1PC/dock/issues/54) | OPEN | パネルに関連する Space と Full Screen の設定はあるが、OS 操作との組合せは未検証になる。 |
| [#55 ウィンドウ配置との共存](https://github.com/CHU1PC/dock/issues/55) | OPEN | Dock の表示領域を他アプリの最大化、タイル配置用に予約する機能はない。 |
| [#56 Handoff](https://github.com/CHU1PC/dock/issues/56) | OPEN | Handoff の継続中アクティビティを表示、起動しない。 |
| [#57 Finder の常設入口](https://github.com/CHU1PC/dock/issues/57) | OPEN | Finder は通常項目として追加できるが、専用の固定項目ではない。 |
| [#58 Launchpad、アプリ一覧](https://github.com/CHU1PC/dock/issues/58) | OPEN | アプリ一覧や Launchpad 専用の入口はない。 |
| [#59 ライト、ダーク外観](https://github.com/CHU1PC/dock/issues/59) | CLOSED、PR #78 MERGED | システムのライト、ダーク外観に Dock の色を追従させられる。 |
| [#60 左右配置の項目名](https://github.com/CHU1PC/dock/issues/60) | CLOSED、PR #73 MERGED | 左右配置でもホバーした項目名を表示する。 |
| [#61 ログイン後の表示復元](https://github.com/CHU1PC/dock/issues/61) | OPEN | 起動時に Dock の表示状態を復元し、ログイン起動を登録するコードがある。OS ログイン後の実画面確認は別途必要になる。 |
| [#62 Control+Shift で一時拡大](https://github.com/CHU1PC/dock/issues/62) | OPEN | Control+Shift を押している間に拡大状態を一時切替できる。 |
| [#63 Option+矢印で並べ替え](https://github.com/CHU1PC/dock/issues/63) | OPEN | Dock のフォーカス中に Option+矢印で項目を並べ替えられる。 |
| [#64 Finder 選択項目をキーで追加](https://github.com/CHU1PC/dock/issues/64) | OPEN | Finder Services を登録する `NSServices` はなく、選択項目の受取りには対応しない。 |
| [#65 初期構成に Downloads](https://github.com/CHU1PC/dock/issues/65) | OPEN | 新規プロファイルに Downloads 項目を加える実装がある。 |
| [#66 メニューから項目を削除](https://github.com/CHU1PC/dock/issues/66) | CLOSED、PR #72 MERGED | Dock 項目のメニューからプロファイル上の項目を取り外せる。 |
| [#67 macOS 27 のバックグラウンド表示](https://github.com/CHU1PC/dock/issues/67) | OPEN | 実行中アプリは表示するが、終了後のバックグラウンド実行状態は扱わない。 |
| [#68 アイコンサイズ範囲](https://github.com/CHU1PC/dock/issues/68) | CLOSED、PR #77 MERGED | 保存検証と設定スライダーのアイコンサイズ範囲は16〜128になる。 |
| [#69 項目数に応じた縮小](https://github.com/CHU1PC/dock/issues/69) | OPEN | アイコンを自動縮小せず、Dock のスクロール領域で項目を表示する。 |
| [#70 Stop Running in Background](https://github.com/CHU1PC/dock/issues/70) | OPEN | macOS 27 のバックグラウンド実行停止操作は連携しない。 |
| [#71 フォルダの Automatic 表示](https://github.com/CHU1PC/dock/issues/71) | OPEN | フォルダはリストのポップオーバーで開き、Automatic 表示形式の選択はない。 |

## この比較の範囲

比較表は GitHub Issue の状態と `origin/main` の現行コードを並べたものになる。OPEN のまま機能が一部または全部実装されている Issue は、受け入れ条件や実機確認が残る可能性があるため、Issue の状態を独自に CLOSED と読み替えていない。Retina の実画面とクリック領域に関する #76 の未実施事項とコード分析は [`DOCK_ICON_SIZE_RANGE.md`](DOCK_ICON_SIZE_RANGE.md) に記録した。
