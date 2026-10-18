# 起動直後のキーボードフォーカス

## 変更内容

Dock Studio のパネルを起動直後にキーボード操作するとき、パネルがキーになった後も Dock のホストビューが AppKit の first responder に残る場合があった。SwiftUI の `@FocusState` の再設定に加えて、パネルがキーで first responder が Dock コンテナのままなら AppKit の key view を進め、最初の項目へフォーカスを渡す。

2 回目以降の操作では、first responder がすでに Dock 項目へ移っているときに key view を進めない。既存の矢印キー処理と SwiftUI の再試行は維持する。

## 仕様判断

- AppKit の key view 移動は、キーボードフォーカス要求に応じてパネルがキーになったときだけ行う。
- パネルがキーでない場合、または first responder が Dock コンテナでない場合は何もしない。
- 項目がない Dock では、移動先がないためフォーカスされる項目はない。
- 底・左・右の配置に応じた矢印の向きと、項目間の移動仕様は変更しない。

## 自動テスト結果

`DockKeyboardNavigationTests` に、キーになったウィンドウの Dock コンテナが first responder の場合だけ AppKit の key view を進める条件を追加した。修正前は、この条件を表す実装がなくテストがコンパイルエラーで失敗した。

| 実行 | 結果 |
| --- | --- |
| `swift test` | `Executed 238 tests, with 0 failures` |
| Release ビルド | `** BUILD SUCCEEDED **` |
| Debug build-for-testing | `** TEST BUILD SUCCEEDED **` |

## 未検証

- 2 回目以降の動作は、実画面で未確認。初回の矢印移動と下配置の Tab は、「実画面の確認」に記録した。
- key view が実際に SwiftUI の最初の Dock 項目へ到達するかは、専用 VM での確認が必要。
- macOS 15 以降の各バージョンでの差異は未確認。

## 撮影の手順

専用のヘッドレス macOS VM または検証用 Mac のゲストで実行する。ホストの画面にはアプリを表示しない。

1. ゲストに空のデータディレクトリ `/Users/Shared/dockstudio-93` を作る。既定プロファイルを使い、Dock の位置を底に設定する。
2. Finder、Mail、Safari の3項目を含むプロファイルを作る。起動済みのアプリはなく、項目にスペーサーやウィジェットを挟まない。
3. `DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-93 /path/to/DockStudio.app/Contents/MacOS/DockStudio` でアプリを起動する。
4. メニューバーの「Dock をキーボードで操作」を初めて実行する。Finder がフォーカスされることを確認して画像を撮る。項目にフォーカスがある状態で右矢印を押し、Mail に移動することを動画に含める。
5. Dock のフォーカスを離して再び「Dock をキーボードで操作」を実行し、2 回目以降も Finder がフォーカスされることを確認する。
6. Tab を順に押し、各項目で1回ずつ止まることを確認する。項目を飛ばしたり、同じ項目で重複して止まったりしないことを動画に含める。
7. Dock の位置を左、右に変えて、それぞれ起動直後の初回操作で先頭項目がフォーカスされ、下矢印で次の項目へ移動することを確認して撮影する。

撮影するものは、底・左・右それぞれの初回フォーカスが分かる画像と、初回の矢印移動、再入場、Tab 移動が分かる動画である。

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `260394f` の Release ビルドを macOS 26.6.2 の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `a6c143a6c0b3481a3ecab8e1c7da06bfc7d7e0fdd27ae4b2163724a86478518e` と一致した。Finder、Mail、Safari の 3 項目で、起動済みアプリなし。管理ウィンドウは「設定」タブにした。毎回、アプリを終了し、保存状態を消して起動し直し、メニューバーの「Dock をキーボードで操作」を AX で押した。その直後の画面（初回）と、右矢印（左右配置では下矢印）の後の画面を、VNC で撮った。判定は、画面のフォーカス枠による（ログは[ax-focus-log.txt](media/first-keyboard-focus/ax-focus-log.txt)）。

| 配置 | 回数 | 初回に先頭の Finder がフォーカスされたか | 矢印で Mail へ移ったか |
| --- | --- | --- | --- |
| 下 | 5 回 | 5 回すべて Finder | 5 回すべて Mail |
| 左 | 5 回 | 5 回すべて Finder | 5 回すべて Mail |
| 右 | 5 回 | 5 回すべて Finder | 5 回すべて Mail |

回数は、各 15 回の目安に対して 5 回である。1 回の起動に約 30 秒かかったため、時間の制約で 5 回にとどめた。画像: [下](media/first-keyboard-focus/bottom-5runs-first-and-after-arrow.png)、[左](media/first-keyboard-focus/left-5runs-first-and-after-arrow.png)、[右](media/first-keyboard-focus/right-5runs-first-and-after-arrow.png)（各 5 回分の「初回」と「矢印の後」を並べた）、[下の初回の全体](media/first-keyboard-focus/bottom-first-focus-full.jpg)、[左](media/first-keyboard-focus/left-first-focus-full.jpg)、[右](media/first-keyboard-focus/right-first-focus-full.jpg)。

- 下配置の Tab: 初回の入場の後、Tab を 1 回ずつ押すと、Finder から Mail、Safari へ、1 回ごとに 1 項目ずつ止まった（飛ばしも重複もなし。[動画](media/first-keyboard-focus/tab-stops-bottom.mp4)、[コマ](media/first-keyboard-focus/tab-sheet.png)）。4 回目の Tab（ゴミ箱）は、動画の終端で確認が取れていない。
- 所見: **AX の `AXFocusedUIElement` は、画面ではフォーカスが Finder や Mail に当たっていても、すべての試行で `AXScrollArea` を返した**（ログのとおり）。以前の確認（#48）では、AX がボタンを返していた。AX の値は、今回のビルドでは、画面のフォーカス枠と一致しない。VoiceOver が読み上げる対象が、見た目のフォーカスと異なる可能性がある。
- 確認していない: 2 回目以降の入場（Escape の後の再入場）。撮影用のコマンドの記述の誤りで、再入場の部分が実行されなかった。各配置での Tab。
