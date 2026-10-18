# 初期プロファイルの Downloads 項目

## 変更内容

保存データがない初回起動時に生成する「仕事」プロファイルへ、Downloads フォルダ項目を追加した。項目は実行時に FileManager の Downloads ディレクトリ URL を解決する識別子を保持し、ホームフォルダのパスを保存しない。

Downloads の場所を移動した場合も、項目の URL を参照するたびに現在の場所を解決する。フォルダが存在しない場合やアクセスできない場合も項目を残し、既存の `ItemAvailability` の判定に任せる。

## 仕様の判断

- Downloads を追加するのは、保存データがなく初期ドキュメントを作るときだけにした。
- 既存のプロファイル、意図的に削除された項目、保存済みの設定は変更しない。
- 保存先にはホームパスでなく専用のシステム位置識別子を使い、FileManager の `.downloadsDirectory` を使って都度 URL を解決する。
- Downloads が解決できない場合も、項目を削除せず参照切れとして扱う。

## 受け入れ条件との対応

| 条件 | 状況 |
| --- | --- |
| 初期構成に Downloads への入口を追加する | 満たした。初期「仕事」プロファイルの生成テストで、Downloads がフォルダ項目として追加されることを確認する |
| ホームパスを固定せず、移動・権限拒否・フォルダ不在を扱う | 一部のみ。ホームパスを保存せず、Downloads URL を都度解決するテストを追加した。権限拒否と不在時は既存の `ItemAvailability` を使うが、GUI での動作は未確認 |
| 既存プロファイルや意図的な削除を上書きしない | 満たした。既存プロファイルに Downloads を追加せず、読込内容を維持するテストを追加した |

## 自動テスト結果

以下は `/private/tmp/cw/run-check.sh 65` の実出力に基づく。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 240 件すべて成功。`exit=0` |
| Release ビルド | `** BUILD SUCCEEDED **`。`exit=0` |
| Debug の `build-for-testing` | `** TEST BUILD SUCCEEDED **`。`exit=0` |

## 未検証

- 専用 macOS VM での実画面と Downloads フォルダを開く動作。
- Downloads の場所を移動した実環境での再解決。
- Downloads フォルダが存在しない場合と、権限拒否時の表示。
- macOS 15 以降のバージョン差。

## 撮影の手順

撮影は専用ヘッドレス macOS VM または検証用 Mac のゲスト内で行う。ホスト上ではアプリを起動しない。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-65` を作る。`profiles.json` が存在しない空のディレクトリにする。初回起動時にアプリが初期プロファイルを生成するため、撮影用の `profiles.json` は作らない。

### 起動と操作

ゲストに Release ビルドの `DockStudio.app` を置き、次の環境変数を付けて実行する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-65 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

1. 初回起動後、「仕事」プロファイルの Dock に Downloads フォルダが表示されることを確認する。
2. Downloads をクリックし、Finder で現在の Downloads フォルダが開くことを確認する。
3. 設定タブを選んだ状態でデスクトップ用パネルの Dock を撮影する。ウィンドウ内のプレビューが重ならない状態にする。
4. Downloads の場所を移動できる検証環境では移動後にアプリを再起動し、新しい Downloads フォルダが解決されることを確認する。移動できない場合は未確認として記録する。

### 期待結果と撮影物

- 起動直後の「仕事」プロファイルに Downloads のフォルダ項目がある。
- Downloads をクリックすると、その時点で FileManager が返す Downloads フォルダが Finder で開く。
- `first-launch-downloads.jpg` に起動後の Dock を写す。
- `open-downloads.mp4` に Downloads をクリックして Finder が開くまでを記録する。
- 実環境で場所を移動できた場合は、`downloads-after-move.jpg` と移動後に開く操作を記録した `downloads-after-move.mp4` も保存する。
