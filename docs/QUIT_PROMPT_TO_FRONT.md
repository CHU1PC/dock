# 終了時の保存確認を前面に表示する

GitHub issue #89 の実装になる。

## 仕様

Dock からアプリへ通常終了を要求したとき、終了要求後も動作中のアプリを前面にする。未保存の書類がある場合は、対象アプリの保存確認が利用者に見える。

- `ApplicationQuitter` は `terminate()` が true を返したとき、750ミリ秒後に対象の状態を再確認する。
- その時点で対象がまだ動作中なら、`NSWorkspace.openApplication` の `activates` を有効にして前面化する。
- 終了していれば前面化しない。同じ bundle identifier の複数インスタンスは、終了要求を送れた各インスタンスを個別に再確認する。
- 強制終了では前面化しない。強制終了は保存確認を出さない別の操作になる。
- 終了の結果表示と起動中一覧の更新は、既存の仕様を維持する。

`NSRunningApplication.terminate()` の true は、終了要求を送れたことを示す。対象アプリが終了を受理したかどうかは示さない。

実装は `DockStudio/Services/ApplicationQuitter.swift` にある。アプリの要求と前面化は、`DockStore.quitApplication` からメインスレッド上で呼び出される。

## 自動テスト

ホストでは `swift test`、Release ビルド、Debug の `build-for-testing` を実行する。GUI は起動しない。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 241件すべて成功した |
| Release ビルド | 成功した |
| Debug の `build-for-testing` | 成功した |

確認時の出力:

```text
Executed 8 tests, with 0 failures (0 unexpected) in 0.253 (0.253) seconds
Executed 241 tests, with 0 failures (0 unexpected) in 4.273 (4.300) seconds
Executed 241 tests, with 0 failures (0 unexpected) in 4.273 (4.302) seconds
** BUILD SUCCEEDED **
** TEST BUILD SUCCEEDED **
```

`ApplicationQuitTests` では、遅延後も動作中の対象を前面化すること、遅延中に終了した対象は前面化しないこと、強制終了は前面化しないことを確認する。

## 未検証

- 標準 Dock が未保存の書類を持つアプリの終了要求後に前面化するかは、専用 VM で確認する。
- 本実装で保存確認が前面に表示されることと、通常終了後にアプリが終了した場合は前面化しないことは、専用 VM で確認する。
- 終了要求を拒否したアプリと保存確認を表示したアプリは、どちらも動作中のままなので区別できない。このため、拒否したアプリも遅延後に前面化する可能性がある。
- macOS 15 以降の各バージョンでの違いは確認していない。

## 撮影の手順

撮影は専用のヘッドレス macOS VM で行う。ホストではアプリを起動しない。

### 準備

1. ゲストで TextEdit を起動し、新規書類に文字を入力して保存せずに置く。
2. Dock Studio のビルド成果物をゲストへ置く。`/Users/Shared/dockstudio-89` を作り、次の内容を `profiles.json` として保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "11111111-1111-1111-1111-111111111111",
  "profiles": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "Quit prompt test",
      "items": [
        { "id": "22222222-2222-2222-2222-222222222222", "name": "TextEdit", "kind": "application",
          "target": "file:///System/Applications/TextEdit.app", "bundleIdentifier": "com.apple.TextEdit" },
        { "id": "33333333-3333-3333-3333-333333333333", "name": "Calculator", "kind": "application",
          "target": "file:///System/Applications/Calculator.app", "bundleIdentifier": "com.apple.calculator" }
      ]
    }
  ],
  "settings": {
    "mode": "custom", "position": "bottom", "iconSize": 52, "autoHide": false,
    "revealAnimationDuration": 0.22, "launchBounce": true, "showRunningApps": true
  }
}
```

3. ゲストで Dock Studio を起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-89 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

4. 「Custom Dock」画面を開く。

### 標準 Dock の比較

1. Dock の TextEdit アイコンを右クリックして「終了」を選ぶ。
2. 保存確認が表示されたとき、TextEdit と確認が Dock Studio より前面に出ていることを確認する。
3. 保存確認をキャンセルし、標準 Dock の操作と結果を記録する。

### Dock Studio の確認

1. TextEdit を再び起動し、未保存の書類を作る。
2. Dock Studio の TextEdit アイコンを右クリックして「終了」を選ぶ。
3. TextEdit の保存確認が Dock Studio より前面に表示されることを確認する。
4. キャンセルを選び、TextEdit が起動中のまま残ることを確認する。
5. 未保存書類のない Calculator などでも「終了」を選び、遅延後にアプリが終了済みなら前面化されないことを確認する。

### 撮るもの

| 種類 | 内容 |
| --- | --- |
| 画像 | 標準 Dock からの終了要求で、前面に出た保存確認 |
| 画像 | Dock Studio からの終了要求で、前面に出た保存確認 |
| 画像 | 保存確認をキャンセルした後、アプリが起動中の画面 |
| 動画 | 標準 Dock の終了要求から保存確認をキャンセルするまで |
| 動画 | Dock Studio の終了要求から保存確認をキャンセルするまで |
| 動画 | 保存確認のないアプリへ終了を要求し、終了するまで |

PR には変更後の画面と動画を添付する。標準 Dock と Dock Studio の画面を撮り、どちらの操作か分かるように記録する。
