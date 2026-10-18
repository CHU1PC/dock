# ログイン・再起動後の Custom Dock の復元

issue #61 の実装になる。DockStudio 自身のログイン時の起動と、Custom Dock の表示状態の復元に限る。別のアプリをログイン項目へ登録する機能は含まない（公開 API が無い。`research/APP_INTEGRATION.md` の #29 の節を参照）。

## 仕様

設定画面の「一般」に、「ログイン時の起動」を追加した。スイッチを入れると、`SMAppService.mainApp.register()` で DockStudio をログイン項目に登録し、切ると `unregister()` で解除する。登録の状態は OS が持つ。DockStudio は保存せず、設定画面を開くたびに `status` を読み直す。システム設定で利用者が切った場合も、画面に反映される。

Dock の表示状態（`DockStore.isDockVisible`）は、変更のたびに `launch-state.json` へ保存し、起動時に復元する。保存先は `profiles.json` と同じ場所になる。

- 表示中に終了またはログアウトした場合は、次回の起動で表示する。
- 「Dock を隠す」などで隠した場合は、隠した状態を保存し、次回も隠したままにする。
- 自動非表示の設定、アクティブなプロファイル、位置などは、従来どおり `profiles.json` に保存されており、そのまま復元される。
- ファイルが無い場合（以前のバージョンからの更新、初回の起動）は、従来どおり非表示で起動する。`profiles.json` と `appearance.json` の形式は変えていない。
- ファイルが壊れている、または未対応の版の場合は、非表示で起動し、設定画面の「ログイン時の起動」に理由を表示する。次に表示状態を変えた時点で、正しいファイルに置き換わる。
- 保存に失敗した場合も、同じ場所に理由を表示する。

状況の説明は次のとおり。

| 状態 | 画面の表示 |
| --- | --- |
| 登録済み | スイッチが入る。メッセージなし |
| 未登録、またはシステム設定で無効化 | スイッチが切れる。メッセージなし |
| 登録したが、システム設定で未許可（`requiresApproval`） | スイッチが入り、許可が必要な旨と「システム設定を開く」ボタンを表示する |
| ログイン項目として登録できないビルド（`notFound`） | スイッチが切れ、登録できない旨を表示する |
| 登録または解除が失敗 | 失敗した操作と OS のエラー文を表示する |

## 実装

- `Services/LoginItemController.swift`: `LoginItemService`（`SMAppService` と同じ `status`、`register`、`unregister`）を定義し、`SMAppService` を適合させた。`LoginItemController` が状態とメッセージを持つ。
- `Services/LaunchRestorePersistence.swift`: `launch-state.json`（`version`、`dockVisible`）の読み書き。
- `Store/DockStore.swift`: `isDockVisible` の変更時に保存し、`init` で復元する。`loginItem` を `init` の引数で差し替えられる。
- `SettingsPreview.swift`: 「一般」にスイッチとメッセージを追加した。

## 検証

2026-10-18 にホストで実行した。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 116件すべて成功（追加は `LoginRestoreTests` の11件） |
| Release ビルド | 成功した |
| `build-for-testing` | 成功した |

`LoginRestoreTests` は、`SMAppService` の代わりに記録用の偽物を使い、`register` と `unregister` の呼び出し回数、失敗時のメッセージ、`requiresApproval` と `notFound` の扱い、外部変更の反映を確かめる。保存は、再起動後の復元（表示と非表示）、自動非表示とアクティブなプロファイルの保持、ファイルなし、壊れたファイル、未対応の版、書き込めない保存先、`profiles.json` を書き換えないことを確かめる。**ホストでは `register()` を実行していない。**

### 未検証

- 実際のログインと再起動での自動起動と、Dock の表示の復元。
- `SMAppService.mainApp` の実際の登録、解除、`requiresApproval` の表示。署名なしのビルド（`CODE_SIGNING_ALLOWED=NO`）で登録が成功するかは未確認。
- ログインで起動した際に、スタジオのウィンドウが開くこと。Custom Dock のウィンドウ制御は、スタジオのウィンドウの `.task` で作られるため、ウィンドウが開かない起動の形にすると Dock が出ない。現在のウィンドウは自動で開く設定のため、動くはずだが、実機では確認していない。
- macOS 15 から 25 での挙動。

## 撮影の手順

専用のヘッドレス VM で行う。ホストでは行わない。VM では登録を実行してよい。

### 準備

1. 署名の有無で登録が通らない場合に備え、アプリは `/Applications/Dock Studio.app` に置く（Release ビルドを VM にコピーする）。
2. 検証用データを `/tmp/dockstudio-61-data` に作る。`DOCKSTUDIO_DATA_DIR` に渡す。ディレクトリは空でよい（初回の起動で既定のプロファイルが作られる）。

```
DOCKSTUDIO_DATA_DIR=/tmp/dockstudio-61-data open -a "/Applications/Dock Studio.app" --env DOCKSTUDIO_DATA_DIR=/tmp/dockstudio-61-data
```

ログイン時の起動は環境変数を引き継がないため、手順 6 以降は、データの場所を既定（`~/Library/Application Support/DockStudio`）にして行う。

### 操作と期待する見え方

1. 起動し、設定の「一般」を開く。「ログイン時の起動」が切れている。**画像 1**。
2. スイッチを入れる。入ったままになる。システム設定の「ログイン項目」に Dock Studio が現れる。**画像 2**（両方の画面）。
3. 設定の「Dock」で「使用していないときに隠す」を入れ、メニューバーから Custom Dock を表示する。
4. VM からログアウトして、再ログインする（または再起動する）。Dock Studio が自動で起動し、Custom Dock が表示されたままになる。自動非表示の設定とプロファイルも同じ。**動画 1**（ログイン画面から Dock が出るまで）。
5. 「Dock を隠す」で隠してから、再度ログアウトして再ログインする。Dock Studio は起動するが、Dock は隠れたままになる。**動画 2**。
6. システム設定の「ログイン項目」で Dock Studio を切る。Dock Studio の設定画面を開き直すと、スイッチが切れている。**画像 3**。
7. 設定画面でスイッチを入れ、システム設定で許可が要る状態になった場合（`requiresApproval`）は、メッセージとボタンを撮る。**画像 4**。
8. `launch-state.json` に `not json` と書き、起動する。Dock は隠れ、「ログイン時の起動」に理由が表示される。**画像 5**。撮影後に `launch-state.json` を削除する。

### 撮るもの

| 番号 | 内容 |
| --- | --- |
| 画像 1 | 切れた状態の「ログイン時の起動」 |
| 画像 2 | 入れた状態の設定画面と、システム設定のログイン項目 |
| 画像 3 | システム設定で切った後の設定画面 |
| 画像 4 | 未許可のメッセージ（再現できた場合のみ） |
| 画像 5 | 壊れた保存データのメッセージ |
| 動画 1 | 再ログイン後に、Dock が表示されたまま復元される様子 |
| 動画 2 | 隠した状態が、再ログイン後も保たれる様子 |
