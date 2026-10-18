# 終了要求後に確認シートがあるアプリを前面に表示する

GitHub issue #89 の実装になる。

## 仕様

Dock からアプリへ通常終了を要求したとき、確認シートを表示したまま動作中のアプリを前面にする。確認シートがなく動作中のアプリは前面にしない。

- `ApplicationQuitter` は `terminate()` が true を返したとき、750ミリ秒後に対象の状態を再確認する。
- その時点で対象がまだ動作中で、Accessibility が対象アプリの `AXSheet` を検出した場合に前面化する。
- Accessibility の許可がない場合は、従来どおり、対象が動作中なら前面化する。
- 終了していれば前面化しない。同じ bundle identifier の複数インスタンスは、終了要求を送れた各インスタンスを個別に再確認する。
- 強制終了では前面化しない。強制終了は保存確認を出さない別の操作になる。
- 終了の結果表示と起動中一覧の更新は、既存の仕様を維持する。

`NSRunningApplication.terminate()` の true は、終了要求を送れたことを示す。対象アプリが終了を受理したかどうかは示さない。検出処理は `QuitPromptDetecting` で差し替えられ、Accessibility の許可がない場合や AX 情報を取得できない場合は従来の前面化に戻る。

実装は `DockStudio/Services/ApplicationQuitter.swift` にある。アプリの要求と前面化は、`DockStore.quitApplication` からメインスレッド上で呼び出される。

## 自動テスト

ホストでは `swift test`、Release ビルド、Debug の `build-for-testing` を実行する。GUI は起動しない。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 382件すべて成功した |
| Release ビルド | 成功した |
| Debug の `build-for-testing` | 成功した |

確認時の出力:

```text
Executed 5 tests, with 0 failures (0 unexpected) in 0.007 (0.007) seconds
Executed 10 tests, with 0 failures (0 unexpected) in 0.251 (0.252) seconds
Executed 3 tests, with 0 failures (0 unexpected) in 0.001 (0.001) seconds
Executed 382 tests, with 0 failures (0 unexpected) in 4.645 (4.680) seconds
Executed 382 tests, with 0 failures (0 unexpected) in 4.645 (4.682) seconds
** BUILD SUCCEEDED **
** TEST BUILD SUCCEEDED **
```

`ApplicationQuitTests` では、確認シートを検出したときは前面化し、検出しないときは前面化しないこと、Accessibility が利用できないときは従来どおり前面化すること、遅延中に終了した対象と強制終了では前面化しないことを確認する。

## 未検証

- AXSheet の検出と、通常終了後にアプリが終了した場合の実画面での挙動は、専用 VM で確認していない。
- AX 情報から取得できない形式の確認パネルや、AXSheet 以外の確認 UI は検出しない可能性がある。
- Accessibility の許可がない場合や AX 情報を取得できない場合は、従来どおり、動作中の対象を前面化する。
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
5. 終了要求を拒否するアプリにも「終了」を選び、確認 UI がなければ前面化されないことを確認する。
6. Accessibility の許可を外して終了を要求し、動作中なら従来どおり前面化することを確認する。

### 撮るもの

| 種類 | 内容 |
| --- | --- |
| 画像 | 標準 Dock からの終了要求で、前面に出た保存確認 |
| 画像 | Dock Studio からの終了要求で、前面に出た保存確認 |
| 画像 | 保存確認をキャンセルした後、アプリが起動中の画面 |
| 動画 | 標準 Dock の終了要求から保存確認をキャンセルするまで |
| 動画 | Dock Studio の終了要求から保存確認をキャンセルするまで |
| 動画 | 保存確認のないアプリへ終了を要求し、終了するまで |

実画面の撮影は行っていない。上記の操作は今後の検証手順として残す。

## 実画面の確認

この変更後の AXSheet 検出、終了拒否アプリの扱い、Accessibility 許可なしのフォールバックは、実画面で確認していない。以前の実画面確認は PR #108 の一律前面化実装を対象にしており、今回の挙動を裏付けない。
