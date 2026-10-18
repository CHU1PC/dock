# Full Disk Access を使わないゴミ箱の状態表示

## 仕様

ゴミ箱の状態は、まず Finder に Apple Events で問い合わせる。`count items of trash` の結果が0なら空、1以上なら内容ありとして、Full Disk Access を付けていない利用者にも `trash` と `trash.fill` を表示する。

Dock Studio の `Info.plist` に Apple Events の利用目的を追加した。初回の問い合わせ時に macOS が Finder の操作許可を求める。許可されない場合や Finder の応答を数値として読めない場合は、従来の FileManager による確認を試す。こちらも読めなければ `unknown` を維持し、空とは表示しない。

状態が不明な場合は `trash.slash` と、Finder の項目数を読み取れない理由を表示する。VoiceOver の値とホバー時の説明に、システム設定の「プライバシーとセキュリティ」から Dock Studio の Finder 操作を許可する方法を示す。右クリックメニューの「状態の確認方法」からも同じ案内を表示する。

## 仕様判断

Full Disk Access を要求する案内だけに頼らず、Finder に状態を尋ねる方法を採用した。Finder は自身のゴミ箱の内容を数えられるため、Dock Studio が保護された `.Trash` を直接列挙せずに状態を取得できる。Apple Events が許可されず、ファイルシステムからも確認できない場合は、誤った空表示を避けて不明を示す。

外部ボリュームのゴミ箱は Finder のユーザーゴミ箱件数に含まれる場合に反映される。FileManager による従来の全ゴミ箱ディレクトリ走査もフォールバックとして残る。

## 自動テスト結果

ホストでは `/private/tmp/cw/run-check.sh 95 test`、`release`、`testbuild` を実行した。いずれも成功した。

```text
Executed 258 tests, with 0 failures (0 unexpected)
exit=0
** BUILD SUCCEEDED **
exit=0
** TEST BUILD SUCCEEDED **
exit=0
```

## 未検証

- 専用 VM での Apple Events 許可プロンプトと、許可後の実際の Finder 件数取得。
- 専用 VM での空と内容ありのアイコン表示。
- Apple Events を拒否した後の説明表示と、FileManager フォールバックの TCC 挙動。
- macOS 15 以降の各バージョンでの挙動。

## 撮影の手順

撮影担当は、専用ヘッドレス macOS VM のゲストで Release ビルドを起動する。VM のデスクトップや VNC 画面をホストに表示しない。Dock Studio 用の検証データとして、空の一時ディレクトリを用意し、既定のプロファイルを使う。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-trash-state /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

1. Finder のゴミ箱を空にし、Dock Studio を起動する。初回に Finder 操作の許可を求められたら許可する。
2. Custom Dock のゴミ箱が `trash` になることを確認し、Finder のゴミ箱が空であることと合わせて撮影する。
3. ゲストで `touch ~/.Trash/trash-state-sample.txt` を実行する。次のポーリング後に Custom Dock が `trash.fill` になることを確認し、Finder の内容と合わせて撮影する。
4. Finder の操作を許可しない別の検証プロファイルで起動し、FileManager でも状態を読めない場合に `trash.slash` が表示されることを確認する。右クリックの「状態の確認方法」で案内を撮影する。
5. 同じ空と内容ありの状態を、標準 macOS Dock のゴミ箱でも撮影する。各状態で標準 Dock と Custom Dock のアイコン、Finder の実際の内容、状態変化が表示されるまでの時間を記録し、見え方と更新間隔を比較する。
6. ゲストで `mv ~/.Trash/trash-state-sample.txt /tmp/trash-state-sample.txt` を実行して、検証用のファイルを片付ける。

撮る画像は、空の Custom Dock と標準 Dock、内容ありの Custom Dock と標準 Dock、不明状態の案内になる。状態変化を示す動画も撮り、Finder の内容数と Dock Studio のアイコン切り替え時刻が分かるようにする。
