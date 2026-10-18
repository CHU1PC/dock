# ドラッグ中のフォルダ表示

## 変更内容

ファイルを Custom Dock のフォルダ項目へドラッグし、約1秒とどまると、既存のフォルダ内容ポップオーバーを開く。項目から離れると待機を取り消す。アプリ項目では待機後もアプリを開かない。調査資料では標準 Dock もアプリ項目を開かないため、この動作に合わせる。

ドロップ先のフォルダを開いた後も、ドロップ自体は既存の処理を通す。アプリ項目へのドロップは対象アプリでファイルを開き、その他の項目へのドロップは Dock への追加を続ける。操作補助設定で spring-loading が無効なら、フォルダを開かない。

「全ウィンドウを表示」は、標準 Dock の Accessibility メニュー操作を使う既存の Custom Dock メニュー項目を維持する。この変更では同機能の実装を変更しない。

## 仕様判断

- spring-loading の待機時間は1秒にする。
- 待機とキャンセルはドロップ先の座標を追跡する独自タイマーで行う。Dock のボーダーレスな非アクティブ化パネルでは、システムの spring-loading activation が通知されないという調査結果に基づく。
- `com.apple.springing.enabled` が明示的に `false` のときは機能を止め、設定がない場合は有効として扱う。
- アプリの起動、Finder でのフォルダ表示、ドロップ先のルーティングは追加しない。

## 自動テスト結果

| 項目 | 結果 |
| --- | --- |
| `/private/tmp/cw/run-check.sh 32 test` | 382件成功、失敗0件 |
| `/private/tmp/cw/run-check.sh 32 release` | `BUILD SUCCEEDED` |
| `/private/tmp/cw/run-check.sh 32 testbuild` | `TEST BUILD SUCCEEDED` |

## 未検証

- 専用 VM または検証用 Mac での実際のドラッグ、表示、離脱時の取消。
- macOS 15 と他の macOS バージョンでの操作補助設定キーの挙動。
- 実画面、標準 Dock との比較、および OS 統合。
- 開いたポップオーバー上へドロップした場合の実際のポインタ経路。

## 撮影の手順

専用ヘッドレス macOS VM または検証用 Mac のゲストで実施する。普段使いのホストには Dock Studio を表示しない。ゲストで `/Users/Shared/dockstudio-32/Fixture Folder` とその中の `Nested Folder` を作り、`Fixture Folder` 内に `Notes.txt` を作る。

次の内容を `/Users/Shared/dockstudio-32/profiles.json` に保存し、`Fixture Folder` のパスが一致することを確認する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000032",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [{
    "id": "00000000-0000-0000-0000-000000000032",
    "name": "Spring loading demo",
    "items": [{
      "id": "00000000-0000-0000-0000-000000000033",
      "name": "Fixture Folder",
      "kind": "folder",
      "target": "file:///Users/Shared/dockstudio-32/Fixture%20Folder/"
    }]
  }]
}
```

ゲストで fixture を作り、ビルドしたアプリを起動する。

```sh
mkdir -p "/Users/Shared/dockstudio-32/Fixture Folder/Nested Folder"
printf 'Spring loading fixture\n' > "/Users/Shared/dockstudio-32/Fixture Folder/Notes.txt"
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-32 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作

1. Finder の `Notes.txt` を Custom Dock の `Fixture Folder` へドラッグし、約1秒保持してフォルダ内容が表示されることを確認する。
2. フォルダ内容が表示された後もドラッグを続け、元のドロップ処理が完了することを確認する。
3. 別のドラッグをフォルダ項目へ移動し、1秒経過前に項目の外へ出す。フォルダ内容が開かないことを確認する。
4. アプリ項目へファイルをドラッグして保持し、アプリが前面にならないことを確認する。
5. 操作補助設定の spring-loading を無効にし、フォルダ項目に保持しても開かないことを確認する。

### 撮影するもの

| 種類 | 内容 |
| --- | --- |
| 画像 | ドラッグ保持後にフォルダ内容が開いた状態 |
| 動画 | フォルダへのドラッグ保持からポップオーバー表示まで |
| 動画 | フォルダ項目から離れて待機を取り消す操作 |
| 動画 | アプリ項目を保持してもアプリが開かない操作 |

この作業では画面検証と撮影を行わない。
