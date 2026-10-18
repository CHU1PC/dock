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

- この作業環境ではアプリを起動しない制約があるため、macOS VM での実画面、初回の矢印移動、2 回目以降の動作、Tab の停止順を未確認。
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
