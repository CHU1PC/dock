# 実行中アプリの Dock への保持

## 仕様

「実行中のアプリを表示」で一時的に出ている項目を右クリックすると、メニューに「Dock に保持」が表示される。選ぶと、使用中のプロファイルへ項目を追加し、すぐに保存する。保存後は「<項目名> を Dock に保持しました」と状態が出る。

保持した項目は、実行中アプリの `bundleIdentifier` と、アプリの場所（`target`）を持つ。保存前に `ItemLaunchPolicy().validate` で、有効なアプリ（`.app`、実行可能）か確かめる。無効なら保存せず、エラーを表示する。

保持済みの項目には「Dock に保持」を出さず、「Dock から取り外す」（#66）を出す。区別には `DockStore.isPinned` を使う。同じアプリ（`applicationIdentity` が一致）が使用中のプロファイルにすでにあれば、何もしない。重複の追加一般は #84 で扱う。

取り外した後も、アプリが実行中で「実行中のアプリを表示」が有効なら、一時表示の項目として残る。

保存処理は `DockStore.keepInActiveProfile(_:)` として、画面から独立した関数にした。プロファイルに未保存の編集（下書き）がある場合は、下書きにも同じ項目を加え、下書きの保存で項目が消えないようにした。VoiceOver のアクションにも、同じ「Dock に保持」を出す。

保存データの形式は変えていない。古い保存データは、そのまま読み込める。

## 検証

2026-10-18 にホストで、ビルドと単体テストだけを実行した。GUI は未検証になる。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 111件すべて成功した（新規6件を含む） |
| Release ビルド | 成功した |
| `build-for-testing`（Debug） | 成功した |

新規テストは `DockStudioTests/KeepRunningAppTests.swift` にある。保存と再読込、重複しないこと、取り外し後の一時表示への復帰、無効なアプリと非アプリの拒否、下書きとの整合、古い保存データの読み込みを確かめる。

## 撮影の手順

### 起動

検証用データを `DOCKSTUDIO_DATA_DIR` のディレクトリに `profiles.json` として置く。内容は、使用中のプロファイル1つで項目は Finder と Safari の2つ、設定は `showRunningApps: true`、`mode: custom` にする（既存の検証用データの形式に合わせる）。ゲストで Calculator と Mail を起動しておく。

### 操作

1. Dock に、保持済みの Finder と Safari、一時表示の Calculator と Mail が並ぶことを撮る（`before.png`）。
2. Calculator を右クリックする。メニューに「開く」「Finder で表示」「Dock に保持」が出ることを撮る（`menu-keep.png`）。Finder を右クリックすると、「Dock に保持」は出ず「Dock から取り外す」が出ることも撮る（`menu-pinned.png`）。
3. Calculator で「Dock に保持」を選ぶ。項目が消えずに保持済みとして残り、状態に「Calculator を Dock に保持しました」と出ることを撮る（`after-keep.png`）。再度右クリックし、「Dock に保持」が消え「Dock から取り外す」が出ることも確認する。
4. アプリを終了して再起動する。Calculator を終了した状態でも、Calculator が Dock に残ることを撮る（`after-relaunch.png`）。
5. Calculator を実行中にして、「Dock から取り外す」を選ぶ。Calculator が一時表示として残ることを撮る（`after-unkeep.png`）。
6. 1〜3 と 5 を通した動画を撮る（`keep-running-app.mp4`）。

### 撮影一覧

`before.png`、`menu-keep.png`、`menu-pinned.png`、`after-keep.png`、`after-relaunch.png`、`after-unkeep.png`、`keep-running-app.mp4`。

## 未検証

| 項目 | 状況 |
| --- | --- |
| 画面での右クリックメニューと保持の操作 | 未検証。上の撮影の手順で確認する |
| VoiceOver のアクション「Dock に保持」 | 未検証 |
| アプリ再起動後の保持状態 | 単体テストでは再読込を確認した。実アプリの再起動は未検証 |
