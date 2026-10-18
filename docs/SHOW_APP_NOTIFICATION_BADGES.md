# 他のアプリの通知バッジを表示する

## 変更内容

Accessibility を許可した場合に、標準 Dock のアプリ項目から `AXURL` と `AXStatusLabel` を読み、対応する Custom Dock のアプリアイコンにバッジを重ねる。データの取得に失敗した場合や属性が無い場合は、バッジを表示しない。

読み取りは2秒間隔でバックグラウンドから行う。Dock の AX ツリー全体を読むため、Accessibility の許可が必要になる。許可されていない場合は Custom Dock に案内を表示し、クリックするとシステム設定の「プライバシーとセキュリティ」が開く。

## 仕様判断

- `AXStatusLabel` は SDK に定義されない属性のため、属性が見つからない場合は通常表示にする。
- `AXURL` の標準化済みファイルパスをキーにし、プロファイル内のアプリ項目と照合する。アプリ以外の項目にはバッジを付けない。
- バッジ情報はメモリ上でのみ保持し、設定、履歴、ログ、外部サービスには保存または送信しない。
- 更新方法は2秒ごとのポーリングとする。更新周期は実装上の設定値であり、実際の更新遅延や OS ごとの差は未測定になる。
- AX 呼び出しに失敗した場合、空のバッジ一覧として扱う。Dock の項目や属性を列挙できない場合も表示を続け、バッジは付けない。
- 対象は macOS 15 以降（プロジェクトの最低対応バージョン）になる。`AXStatusLabel` は非公開属性のため、macOS の将来の更新で取得できなくなる可能性がある。

## 受け入れ条件との対応

| 条件 | 状況 |
|---|---|
| Accessibility を許可した利用者に限り、標準 Dock の `AXStatusLabel` を読み Custom Dock にバッジを表示する | 一部のみ。項目のパス照合とバッジ対象の判定を単体テストで確認した。AX 連携と画面表示は未確認 |
| 属性が無い、読めない、または Accessibility 権限が無い場合はバッジ無しで動作する | 一部のみ。値が無い場合のバッジなしを単体テストで確認した。権限拒否と AX 読み取り失敗時の実動作は未確認 |
| バッジ情報は表示以外に保存・記録・外部送信しない | 満たした。実装と単体テストを確認した |
| 更新方法と更新頻度を測定し、対応 OS と失敗時の動作を記録する | 一部のみ。方法、2秒間隔、macOS 15 以降を記録した。実機での更新頻度と OS ごとの差は未測定 |

## 自動テスト

- `swift test`: 339件すべて成功
- Release ビルド: 成功
- Debug の `build-for-testing`: 成功

## 未検証

- 標準 Dock と Custom Dock での実バッジ表示、および更新遅延
- Accessibility の許可案内、システム設定への移動、許可後の取得
- 点のみのバッジ、文字列バッジ、複数アプリのバッジ
- macOS 15 から現行 OS までの差異
- AX 読み取りに失敗した場合の実環境での動作

## 撮影の手順

専用のヘッドレス macOS VM でのみ確認する。ホストではアプリを起動しない。`DOCKSTUDIO_DATA_DIR` に指定したディレクトリへ次の `profiles.json` を置き、ビルド成果物を起動する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [{
    "id": "00000000-0000-0000-0000-000000000001",
    "name": "Notification badges",
    "items": [
      { "id": "00000000-0000-0000-0000-0000000000a1", "name": "Messages", "kind": "application", "target": "file:///System/Applications/Messages.app/" },
      { "id": "00000000-0000-0000-0000-0000000000a2", "name": "Mail", "kind": "application", "target": "file:///System/Applications/Mail.app/" }
    ]
  }]
}
```

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-131 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

1. Accessibility を許可せずに起動し、Custom Dock に案内が出て、バッジ無しで表示されることを確認する。
2. 案内をクリックし、システム設定で Dock Studio に Accessibility を許可する。必要ならアプリを再起動する。
3. 標準 Dock でバッジが表示されるテスト用アプリ状態を用意し、標準 Dock と Custom Dock の両方で値を比較する。
4. バッジ値を変え、Custom Dock に2秒程度で反映されるかを確認する。反映時間を記録する。
5. テスト用アプリのバッジを消し、Custom Dock のバッジも消えることを確認する。

撮影するものは、許可案内が出た画面、許可後にバッジが表示された Custom Dock、標準 Dock と Custom Dock を同時に見比べられる画面、値の更新と消去が分かる動画になる。点のみのバッジを用意できない場合は未確認と記録する。
