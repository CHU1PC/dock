# Option キーで強制終了する

GitHub issue #16 の残りの実装になる。

## 仕様

- 起動中で終了可能なアプリのメニューでは、通常時に「終了」と「強制終了…」を表示する。
- Option キーを押した状態でメニューを組み立てると、「終了」の位置に「強制終了…」を表示し、強制終了項目は重複させない。
- Option キーを押していない状態でも、既存の「強制終了…」は利用できる。
- Finder と Dock Studio は終了対象から除外する。強制終了前の確認と未保存データへの警告を維持する。
- アプリの応答状態はメニュー表示に使わない。SDK の `NSRunningApplication` には終了状態や終了要求の API があるが、応答性を示す公開プロパティはない。Accessibility の `AXElementBusy` は読み込みや更新中の状態であり、応答不能を示さない。`kAXErrorCannotComplete` も応答不能のほか、ユーザー入力待ちや通信障害で返るため、強制終了項目を隠す根拠にはしない。
- 「全ウィンドウを表示」は、標準 Dock の Accessibility メニューで「Show All Windows」を押す既存経路を使う。Accessibility 許可が必要で、Dock のメニュー構造と言語に依存する。

## 検証

2026-10-18 に `/private/tmp/cw/run-check.sh 16 test` を実行し、381 件すべて成功した。`/private/tmp/cw/run-check.sh 16 release` は `BUILD SUCCEEDED`、`/private/tmp/cw/run-check.sh 16 testbuild` は `TEST BUILD SUCCEEDED` になった。

単体テストでは、Option キーの状態に応じて終了項目が置き換わること、通常時に強制終了が常に残ることを確認する。既存のテストでは、強制終了が確認後に `forceTerminate()` だけを呼ぶこと、Finder と Dock Studio を除外すること、Show All Windows のタイトル判定と Accessibility 経路を確認する。

## 未検証

- 実画面での Option キーによるメニュー切替と、右クリック時の修飾キーの取り込み。
- アプリが応答しない状態を正確に区別する公開 API または文書化された Accessibility、NSWorkspace 信号。強制終了項目は常時利用できる。
- 標準 Dock の全ウィンドウ表示が、実際のアプリと各 macOS バージョンで開くこと。
- macOS 15 以降の画面と OS 連携。

## 撮影の手順

専用のヘッドレス macOS VM で行う。ホストでは Dock Studio を起動しない。VM では Calculator と TextEdit を起動し、Calculator に未保存データがある状態を用意する。

1. ゲストに `/Users/Shared/dockstudio-16/profiles.json` を置き、Calculator と TextEdit を含む使い捨てプロファイルを使う。各 `target` はゲスト内の実際のアプリ URL に合わせる。
2. `DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-16 /path/to/DockStudio.app/Contents/MacOS/DockStudio` で起動する。
3. Calculator のメニューを Option キーを離した状態と押した状態の両方で開き、「終了」と「強制終了…」の切替を確認する。
4. 通常終了はキャンセルできることを確認する。強制終了は未保存データの警告を確認した後、テスト用アプリだけで実行する。
5. TextEdit のメニューから「全ウィンドウを表示」を選び、標準 Dock の App Exposé が開くことを確認する。

撮影するものは、Option キーを離したメニュー、押したメニュー、未保存データの確認ダイアログ、標準 Dock の App Exposé を示す画像または動画になる。今回の作業では実画面を撮影していない。
