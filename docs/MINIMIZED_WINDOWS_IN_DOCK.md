# 最小化ウインドウを Custom Dock に表示

issue #23 の実装になる。最小化したウインドウを所有アプリごとに並べ、クリックしたウインドウだけを復元する。アプリのアイコンへまとめる機能は含めない（issue #24）。

## 仕様

- macOS 15 以降を対象にする。
- 最小化中のウインドウを、タイトルと所有アプリ名を持つ独立した項目として Custom Dock の末尾に表示する。アイコンにポインタを置くと、タイトルとアプリ名を確認できる。
- 項目をクリックすると、対応するウインドウの最小化を解除して前面へ出す。ほかのウインドウは操作しない。
- 列挙時点で存在する最小化ウインドウだけを表示する。閉じたウインドウは次の更新で消える。
- ウインドウの列挙と復元には「アクセシビリティ」権限を使う。権限がない場合は Dock に必要な権限を表示し、ボタンからシステム設定を開ける。権限を許可すると、約2秒以内に表示を更新する。
- Custom Dock を Apple Dock と併用する既存の「両方」モードで使える。Apple Dock の設定や表示は変更しない。
- 最小化ウインドウはプロファイルへ保存しない。実行中のウインドウ状態から都度取得する。

## 実装

- `Services/MinimizedWindowController.swift` に列挙状態と `MinimizedWindowProviding` プロトコルを置いた。実装は Accessibility API から各アプリのウインドウ一覧を取得し、最小化中の要素だけを保持する。
- Dock 表示は保存済み項目と分離し、Custom Dock の末尾へウインドウごとに追加した。タイトルとアプリ名はヘルプと VoiceOver ラベルにも含める。
- 復元時は対象 AX 要素の最小化を解除し、Raise アクションを実行する。取得に失敗した対象や閉じられた対象は復元せず、次の列挙で一覧から除く。
- `DockStudioTests/MinimizedWindowControllerTests.swift` では偽物の provider を使い、表示情報、権限拒否、対象ウインドウだけの復元と一覧更新を検証する。

## 自動テスト結果

2026-10-18 にホストで `/private/tmp/cw/run-check.sh 23 test`、`/private/tmp/cw/run-check.sh 23 release`、`/private/tmp/cw/run-check.sh 23 testbuild` を実行した。

```text
Executed 259 tests, with 0 failures (0 unexpected)
** BUILD SUCCEEDED **
** TEST BUILD SUCCEEDED **
exit=0
```

実画面は専用 VM で撮影し、PR の本文へ画像と動画を添付する。

## 未検証

- 専用 macOS VM での実画面、実際の最小化ウインドウの復元、アクセシビリティ権限を拒否した時の表示は未検証。
- 標準 Dock と Custom Dock を並べた時の見え方、macOS 15 から 26 までの差異は未検証。
- 復元動作は自動テストで provider を通して確認した。ホスト上で Accessibility API による他アプリのウインドウ操作は行っていない。

## 撮影の手順

専用ヘッドレス macOS VM または検証用 Mac のゲストで行う。普段使うホストでは起動や画面撮影をしない。標準 Dock と Custom Dock の併用を確認するため、Dock Studio のモードは「両方」にする。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-23/profiles.json` を作り、次の内容を保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "both",
    "position": "bottom",
    "iconSize": 52,
    "autoHide": false,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Minimized windows",
      "items": [
        {
          "id": "00000000-0000-0000-0000-000000000023",
          "name": "TextEdit",
          "kind": "application",
          "target": "file:///System/Applications/TextEdit.app/"
        },
        {
          "id": "00000000-0000-0000-0000-000000000024",
          "name": "Calculator",
          "kind": "application",
          "target": "file:///System/Applications/Calculator.app/"
        }
      ]
    }
  ]
}
```

Release 成果物をゲストへ置き、次のように起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-23 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作

1. 起動後、Custom Dock と標準 Dock の両方が表示されることを確認する。許可されていない場合は Dock の案内ボタンからシステム設定を開き、Dock Studio を許可する。
2. TextEdit でタイトルの異なる書類を2つ作り、Calculator も起動する。それぞれのウインドウを最小化する。
3. Custom Dock に3つのウインドウ項目が個別に現れることを確認する。各項目にポインタを置き、タイトルと所有アプリ名が表示されることを確認する。
4. TextEdit の片方の項目をクリックする。該当書類だけが復元され、もう片方の TextEdit と Calculator は最小化されたままであることを確認する。
5. もう一方のウインドウも復元する。次に一つのウインドウを閉じ、Custom Dock からその項目が消えることを確認する。
6. 権限拒否の状態を撮る場合は、Dock Studio を終了し、システム設定の「プライバシーとセキュリティ」「アクセシビリティ」で Dock Studio を無効にしてから再起動する。Dock に案内が出ることと、ボタンでアクセシビリティ設定を開けることを確認する。撮影後は許可を戻す。

### 標準 Dock との比較で記録する項目

- ゲストの macOS バージョン、画面解像度、Dock の位置とアイコンサイズを記録する。
- システム設定の「ウインドウをアプリケーションアイコンにしまう」の状態を記録する。ウインドウ別タイルを比較する時はオフにする。
- 同じアプリの複数ウインドウが、標準 Dock と Custom Dock のそれぞれで何個の項目として見えるかを記録する。
- 各 Dock で、タイトルと所有アプリ名の確認方法、アイコンまたはサムネイル、項目の並び、復元するウインドウが一致するかを記録する。
- 最小化してから Custom Dock に現れるまでの時間、クリックして復元するまでの時間を記録する。
- 両方の Dock を同時に表示し、重なりや操作の妨げがないかを記録する。

### 撮るもの

- 画像: 権限許可後、複数アプリと同じアプリの複数ウインドウが並んだ Custom Dock。ポインタを置いた項目のタイトルとアプリ名も見せる。
- 画像: 同じ状態の標準 Dock と Custom Dock の位置関係。
- 画像: 権限拒否時の案内と、システム設定のアクセシビリティ画面。
- 動画: 複数のウインドウを最小化し、各 Dock の表示を見せた後、Custom Dock の項目を一つずつクリックして対象だけが復元される様子。最後に別のウインドウを閉じ、その項目が消えるところまで撮る。
