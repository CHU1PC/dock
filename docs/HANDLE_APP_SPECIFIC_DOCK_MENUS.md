# 他アプリの Dock 固有メニューを扱う

GitHub issue #129 に対応する。Accessibility を許可した利用者が、標準 Dock に登録されたアプリの固有メニューを Custom Dock から読み、選んだ項目を実行できるようにした。

## 仕様の判断

- 標準 Dock の Accessibility 要素に `AXShowMenu` を送り、`AXShownMenuUIElement` から項目を読む。アプリが Dock に提供する `applicationDockMenu(_:)` を直接呼ぶ方法は使わない。
- `Options` より前にある項目をアプリ固有項目として扱う。Dock のメニュー全体を再現することはせず、標準の Options、終了、起動などは既存の Custom Dock メニューに任せる。
- 既存の右クリックメニューに「アプリ固有メニュー…」を加えた。選ぶと取得項目が別メニューに表示され、選択時に Dock の該当項目を再表示して `AXPress` を送る。
- アプリが標準 Dock に無い、権限が無い、または AX の取得や実行に失敗した場合はエラーを知らせる。既存の固定メニューは引き続き利用できる。
- AX メニューを読むために標準 Dock のメニューを開閉するので、ちらつく可能性がある。調査で実行の実現性は未確認だったため、この実装の実画面動作も未確認として扱う。

## 自動テスト

`ApplicationDockMenuAccessTests` で、メニュー項目の受け渡し、取得失敗時の空状態、選択項目 ID の実行要求を確認した。実装直後の `swift test` は 339 件、失敗 0 件だった。main 取り込み後の `swift test` は 342 件、失敗 0 件だった。main 取り込み後の Release ビルドは `BUILD SUCCEEDED`、事前の build-for-testing は `TEST BUILD SUCCEEDED` だった。

## 受け入れ条件

| 条件 | 状況 | 根拠 |
|---|---|---|
| Accessibility を許可した利用者に限り、標準 Dock から対象アプリのメニュー項目を読み取り、Custom Dock に表示する | 一部のみ | AX 取得処理とメニュー表示のコードを追加した。画面と OS 権限の動作は未確認 |
| 選んだ項目を標準 Dock のメニューに対して実行し、結果と失敗を扱う | 一部のみ | AXPress と失敗通知を追加した。実アプリへの実行は未確認 |
| 権限が無い場合や取得に失敗した場合は、既存の固定メニューを使える | 一部のみ | 固定メニューを残し、取得失敗をエラーにするコードを追加した。権限ダイアログを含む画面は未確認 |
| Safari の起動中・未起動状態を含む代表例で確認し、メニュー表示のちらつきと対応 OS を記録する | 未確認 | Safari の画面確認、ちらつき、macOS 15 以降の差は確認していない |

## 未検証

- Safari の起動中と未起動で表示される固有項目、および Music など他アプリの項目。
- AXShowMenu で標準 Dock に現れるメニューのちらつきと、標準 Dock を隠した状態での動作。
- AXPress の実アプリへの作用、権限ダイアログ、メニュー取得失敗後の画面表示。
- macOS 15 から 25 の差。調査での確認環境は macOS 26.6.2 だった。

## 撮影の手順

専用のヘッドレス macOS VM で確認する。ホストではアプリを起動しない。ゲストに `/Users/Shared/dockstudio-129` を作り、`profiles.json` に Safari をアプリ項目として登録した Custom Dock プロファイルを置く。Dock Studio は `DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-129` で起動する。

1. Safari を終了した状態と起動した状態をそれぞれ用意し、Safari が標準 Dock に登録されていることを確認する。
2. Dock Studio の Custom Dock で Safari を右クリックし、「アプリ固有メニュー…」を選ぶ。
3. 標準 Dock が一時的に表示するメニューと、Custom Dock 側に出るアプリ固有項目を観察する。Safari の「新規ウインドウ」などがあれば選び、動作を確認する。
4. システム設定で Dock Studio の Accessibility を許可しない状態でも試し、既存の固定メニューが利用できることを確認する。
5. Safari の起動中と未起動で、取得項目とメニュー表示のちらつきを比較する。

撮影するもの:

- 画像: Safari 未起動時と起動時の Custom Dock メニュー。
- 画像: Accessibility を許可しない状態で、固定メニューが利用できる画面。
- 動画: Safari のアプリ固有メニューを開き、新規ウインドウ項目を実行する操作。標準 Dock のメニューが一時表示される様子も含める。
