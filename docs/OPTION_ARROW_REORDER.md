# Option+矢印による Dock 項目の並べ替え

GitHub issue #63 の実装になる。

## 仕様

Dock にキーボードフォーカスがあるとき、Option+矢印で保持項目を1つずつ移動する。

| Dock の配置 | 前の項目へ | 次の項目へ |
| --- | --- | --- |
| 下 | Option+左 | Option+右 |
| 左または右 | Option+上 | Option+下 |

- 並び順の端にある項目は、その方向へ移動しない。移動できないキーは処理せず、OS に渡す。
- Dock の並びと直交する Option+矢印、保持されていない実行中アプリへの Option+矢印も処理しない。
- 項目の移動はアクティブなプロファイルに保存する。読み上げには、項目名と移動後の順番を通知する。
- Option 単独の矢印だけを認識する。Command、Control などの修飾キーを含む入力は既存のキー処理で無視する。

## 実装

- `DockKeyboardNavigation.reorderOffset` が配置と矢印から移動方向を返す。
- `DockStore.moveActiveItem` がアクティブなプロファイル内の項目を交換して保存し、ステータスを更新する。
- `DockBar` は移動に成功した場合だけキーを処理済みにし、VoiceOver に新しい順番を通知する。
- `DockKeyboardNavigationTests` が配置ごとの方向と直交方向を確認し、`DockStoreTests` が移動後の保存を確認する。

## 受け入れ条件との対応

| 条件 | 状況 |
| --- | --- |
| Dock にフォーカスがあるときに項目を一つずつ移動できる | 満たした。Option+矢印を並び順の前後に対応させ、Dock 項目を隣と交換する実装を追加した。自動テストは通過したが、実画面では未確認になる |
| 左右と下の配置で移動方向と境界を定義し、変更を保存する | 満たした。左右と下の配置を `reorderOffset` で定義し、ストアで保存する。項目が端にある場合は移動関数が変更を行わない |
| VoiceOver で移動後の順番を通知し、OS や他アプリのキーを奪わない | 満たした。移動成功時だけ通知し、対象外の方向、対象外の項目、境界ではイベントを処理しない。VoiceOver と他アプリへの実入力は未確認になる |

## 自動テスト結果

各コマンドは `/private/tmp/cw/run-check.sh` で実行した。

```text
$ /private/tmp/cw/run-check.sh 63 test
	 Executed 6 tests, with 0 failures (0 unexpected) in 0.130 (0.131) seconds
	 Executed 27 tests, with 0 failures (0 unexpected) in 0.840 (0.843) seconds
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.287 (0.288) seconds
	 Executed 239 tests, with 0 failures (0 unexpected) in 4.388 (4.412) seconds
	 Executed 239 tests, with 0 failures (0 unexpected) in 4.388 (4.413) seconds
exit=0

$ /private/tmp/cw/run-check.sh 63 release
** BUILD SUCCEEDED **
exit=0

$ /private/tmp/cw/run-check.sh 63 testbuild
** TEST BUILD SUCCEEDED **
exit=0
```

## 未検証

- 専用 VM での Option+矢印操作と VoiceOver の読み上げ。
- 下、左、右の配置それぞれで、端の移動が OS に渡ること。
- macOS 15 から 25 でのキー入力と VoiceOver の動作。

## 撮影の手順

画面の確認と撮影は専用のヘッドレス macOS VM または検証用 Mac のゲストで行う。普段使いのホストでアプリを起動しない。アプリをゲストに置き、以下のコマンドで起動する。

```text
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-63 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

ゲストの `/Users/Shared/dockstudio-63/profiles.json` に次の内容を置く。アイコンを順番が分かる状態で並べる。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Option arrow demo",
      "items": [
        { "id": "00000000-0000-0000-0000-0000000000a1", "name": "Finder", "kind": "application", "target": "file:///System/Library/CoreServices/Finder.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a2", "name": "Calculator", "kind": "application", "target": "file:///System/Applications/Calculator.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a3", "name": "Safari", "kind": "application", "target": "file:///Applications/Safari.app/" }
      ]
    }
  ]
}
```

### 操作

1. Dock の設定でキーボード操作を有効にし、Dock にフォーカスを移す。
2. 下配置では中央の Calculator を Option+左へ動かし、続けて Option+右へ戻す。
3. 最初の項目で Option+左、最後の項目で Option+右を押し、順番が変わらないことを確認する。
4. 配置を左にして Option+上と Option+下を行い、同じ移動を確認する。右配置でも繰り返す。
5. VoiceOver を有効にして同じ操作を行い、移動後の名前と順番の通知を確認する。
6. Dock の外へフォーカスを移して、同じ Option+矢印が Dock の並べ替えに使われないことを確認する。
7. アプリを終了して再起動し、並べ替えた順序が保存されていることを確認する。

### 期待する見え方

- 対応方向のキーを押すと、フォーカス中の項目が隣の項目と入れ替わる。
- 境界では順序が変わらず、移動後は項目名と1始まりの位置が VoiceOver に通知される。
- 再起動後も新しい順序が残る。

### 撮るもの

- 画像: 下配置で移動前と移動後の Dock。
- 画像: 左配置と右配置でそれぞれ移動した後の Dock。
- 画像: VoiceOver による移動後の通知が確認できる画面または記録。
- 動画: 項目の移動、両端でのキー入力、VoiceOver の通知、再起動後に順序が保たれる様子。
