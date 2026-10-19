# ドラッグ取り外し後に自動非表示へ戻る

## 仕様

自動非表示が有効なとき、項目のドラッグ終了後にドラッグ中の抑制を解除し、通常の自動非表示待機を再開する。ドロップ先が Dock 内、Dock 外、Trash、アプリのいずれでも、左クリックアップを受けた時点で残ったドラッグ状態を終了させる。Escape によるキャンセルも終了時に抑制を解除する。

`DockDragOutStateMachine` に開始、キャンセル、終了の状態遷移を集める。SwiftUI のドラッグ終了処理に加え、`CustomDockWindowController` のローカルおよびグローバルな左クリックアップ監視から終了処理を呼ぶ。これにより、ドラッグ対象のビューが取り外しで消えた場合や、Trash またはアプリでドロップした場合にも、パネルの自動非表示とクリック透過を再評価する。

## 仕様判断

Trash とアプリへのドロップは個別の終了通知に依存せず、ドラッグ中の左クリックアップを共通の終了通知として扱う。実際の画面での通知順序と動作は VM で確認していないため、未検証として扱う。

## 受け入れ条件との対応

| 条件 | 状況 | 根拠 |
|---|---|---|
| Dock 内へのドロップ後にドラッグ抑制を解除する | 満たした | 状態機械の単体テストのみ |
| Dock 外へドロップして項目を取り外した後にドラッグ抑制を解除する | 満たした | 状態機械の単体テストのみ |
| Escape でキャンセルした後にドラッグ抑制を解除する | 満たした | キャンセル後の状態機械の単体テストのみ |
| Trash またはアプリへのドロップ後にドラッグ抑制を解除する | 満たした | グローバルマウスアップを使う状態機械の単体テストのみ |
| ドラッグ終了後、通常の自動非表示待機でパネルが隠れる | 未確認 | 状態機械を使った可視状態の単体テストはあるが、実画面の動作は未確認 |

## 検証

| 項目 | 結果 |
|---|---|
| `swift test` | 411 件、失敗 0 件 |
| Release ビルド | 成功 |
| Debug の `build-for-testing` | 成功 |

## 未検証

- 専用 VM で、ドラッグ取り外し後にパネルが通常の待機時間で隠れること。
- Trash、アプリ、Dock 外への実際のドロップ経路で左クリックアップが観測されること。
- macOS の複数バージョンでの実画面動作。

## 撮影の手順

今回、実画面の撮影は行っていない。後日の VM 確認では、ゲストに `/Users/Shared/dockstudio-191/profiles.json` を作成し、次の設定を保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000191",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": true,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000191",
      "name": "Auto-hide after drag out",
      "items": [
        {
          "id": "00000000-0000-0000-0000-000000001911",
          "name": "Calculator",
          "kind": "application",
          "target": "file:///System/Applications/Calculator.app/"
        },
        {
          "id": "00000000-0000-0000-0000-000000001912",
          "name": "TextEdit",
          "kind": "application",
          "target": "file:///System/Applications/TextEdit.app/"
        }
      ]
    }
  ]
}
```

ゲスト上のアプリを次のように起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-191 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

1. `autoHide: true`、下配置、アイコンサイズ 64 の設定で Calculator と TextEdit を登録する。
2. 画面端から Dock を表示し、Calculator を Dock の外へドラッグして離す。
3. 項目が取り外された後、通常の自動非表示待機を経て Dock が隠れることを確認する。
4. 残った TextEdit を Dock 内へ戻すドロップ、Escape キャンセル、Trash とアプリへのドロップでも、ドラッグ終了後に Dock が自動非表示へ戻ることを確認する。

期待結果は、取り外し後に Dock が通常の自動非表示待機を経て隠れ、残った項目を通常どおり操作できること。

撮影する場合は管理ウィンドウの「設定」タブで撮り、ドラッグ開始から Dock が隠れるまでの動画と、取り外し後のプロファイルの画像を残す。
