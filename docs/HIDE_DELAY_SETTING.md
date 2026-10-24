# Dock を隠すまでの待ち時間

## 仕様

設定画面の「動作」にある「表示アニメーションの時間」の下に、「隠すまでの待ち時間」を追加した。ポインタが Dock から外れ、ほかの操作もなくなってから、Dock を隠すまでの時間を、0〜5秒の範囲で、0.1秒ずつ調整できる。「使用していないときに隠す」が無効のときは、表示アニメーションの時間と同じく操作できない。

従来の待ち時間は1秒で、`DockStudio/Models/DockVisibilityState.swift:20` の `now.timeIntervalSince(lastInteraction) >= 1` に固定されていた。既定値は、この1秒と同じにした（`DockSettings.defaultHideDelay`）。

値は `DockSettings.hideDelay` として保存し、全プロファイルに共通になる。保存データの形式は version 1 のまま、項目を足した。以前の保存データとバックアップに項目がない場合は、1秒で読み込む。保存データの検証では、範囲外の値と非有限値（無限大、NaN）を拒否する。

### 範囲を0〜5秒にした理由

- 0秒は、ポインタが外れたらすぐ隠したい利用に当たる。下限として意味がある。
- 従来の1秒の5倍になる5秒までなら、「しばらく表示したままにしたい」という利用を覆える。それより長いと、自動非表示が働いていないように見えると判断した。
- 範囲の根拠は、上の2点による設計判断であり、ほかのアプリの基準との比較は行っていない。

### 実装の構成

待ち時間が経過したかどうかの判定は、画面から独立した純粋な関数 `DockVisibilityState.hasHideDelayElapsed(since:now:delay:)` に出した。範囲外または非有限の値には、常に「経過していない」を返す（隠さない）。`DockVisibilityState.update` は、`hideDelay` を引数に取る（省略時は既定値）。`CustomDockWindowController.updateVisibility()` は、保存した値を渡すだけにした。

スライダーの操作中は一時値を使い、操作終了時または最後の変更から300ms後に保存する。終了直前に未保存の一時値があれば、保存してから終了する。仕組みは表示アニメーションの時間と同じになる（[DOCK_REVEAL_DURATION.md](DOCK_REVEAL_DURATION.md)）。

## 自動テスト

2026-10-22 に、ホストで実行した。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 481件すべて成功した |
| Release ビルド | `** BUILD SUCCEEDED **` |
| Debug の `build-for-testing` | `** TEST BUILD SUCCEEDED **` |

`DockStudioTests/DockHideDelayTests.swift` で、次を確認している。

- 既定値が1秒で、0.99秒では経過せず、1秒で経過する。
- 0秒では、ただちに経過する。
- 上限の5秒で、4.9秒では経過せず、5秒で経過する。
- -0.1、5.1、無限大、NaN の待ち時間では、いつまでも経過しない。
- `DockVisibilityState` が、設定した3秒の経過後に折り畳まれる。
- `hideDelay` のない古いデータが、1秒で読み込める。
- 0、1、5秒が、保存と再読込で保持される。範囲外と非有限値の保存が拒否される。
- スライダーの値が0.1秒に丸められ、0〜5に収まり、操作終了まで保存値を変えない。

## 撮影の手順

見た目が変わるのは、設定画面の項目になる。待ち時間の動作は、動画で示す。撮影は、専用 VM で専任の担当が行う。ホストでは行わない。

### 検証用データ

ゲストに `/Users/Shared/dockstudio-221` を作り、`profiles.json` を置く。待ち時間を見やすくするため、`hideDelay` は3秒にする。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "11111111-1111-1111-1111-111111111111",
  "profiles": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "Hide delay test",
      "items": [
        { "id": "22222222-2222-2222-2222-222222222222", "name": "Calculator", "kind": "application",
          "target": "file:///System/Applications/Calculator.app", "bundleIdentifier": "com.apple.calculator" },
        { "id": "44444444-4444-4444-4444-444444444444", "name": "TextEdit", "kind": "application",
          "target": "file:///System/Applications/TextEdit.app", "bundleIdentifier": "com.apple.TextEdit" }
      ]
    }
  ],
  "settings": {
    "mode": "custom", "position": "bottom", "iconSize": 52, "autoHide": true,
    "revealAnimationDuration": 0.22, "hideDelay": 3, "launchBounce": true, "showRunningApps": false
  }
}
```

古いデータの確認用に、`hideDelay` を除いた `profiles.json` を `/Users/Shared/dockstudio-221-old` にも置く。

### 起動

```
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-221 /path/to/DockStudio.app/Contents/MacOS/DockStudio &
```

### 操作と期待する見え方

1. 設定画面の「動作」を開く。「隠すまでの待ち時間」のスライダーが「3.0秒」を示し、「表示アニメーションの時間」の下に並ぶ。（画像1: 設定画面の全体）
2. 「使用していないときに隠す」を無効にする。待ち時間のスライダーが操作できなくなる。有効に戻す。（画像2: 無効時）
3. スライダーを左端と右端にする。「0.0秒」と「5.0秒」が表示される。（画像3、4）
4. 3秒に戻し、Dock の上にポインタを置いてから、画面中央へ移す。Dock が、ポインタを外してから約3秒後に隠れる。（動画1: 3秒設定。撮影時刻の間隔を保つ）
5. 0秒にして、同じ操作をする。Dock が、ポインタを外すとすぐ隠れる。（動画2: 0秒設定）
6. 5秒にして、同じ操作をする。約5秒後に隠れる。（動画3: 5秒設定）
7. アプリを終了して再起動する。直前の値が設定画面に表示される。（画像5: 再起動後）
8. `/Users/Shared/dockstudio-221-old` で起動する。待ち時間が「1.0秒」になり、Dock が従来どおり約1秒後に隠れる。（画像6、動画4）

撮る一覧は、画像6枚と動画4本になる。ポインタが外れた時刻と、Dock が隠れた時刻を、動画から読み取れるようにする。

## 未検証

- 実際の画面での表示と操作。設定画面の配置、スライダーの操作、無効時の見え方は、まだ確認していない。
- 待ち時間の実測。単体テストは時刻を与える純粋な関数を確認するもので、実際の Dock が隠れるまでの時間は測っていない。
- ポインタ、メニュー、ポップオーバー、ドラッグ中の操作と、待ち時間の組合せ。これらが操作中とみなされる既存の処理は、変えていない。
- 左右配置と、VoiceOver、「アニメーションを減らす」との組合せ。
