# Control+Shift による拡大の一時切替

## 変更内容

表示中の Custom Dock の上で Control と Shift を同時に保持すると、拡大設定を一時的に反転する。両方のキーを離すと、保存されている拡大設定に戻る。設定ファイルは変更しない。

一時切替は、Dock が表示され、ポインタが Dock 内にあり、Dock が自動的に隠れていない間だけ有効になる。ポインタが Dock の外へ出る、アプリが非アクティブになる、Dock が隠れると一時状態を解除する。

拡大倍率と Reduce Motion の扱いは既存設定を使う。左右配置でも既存のアイコン拡大計算を適用する。

## 仕様上の判断

- Control と Shift の同時保持を、保存された拡大設定の反転として扱う。
- 保存設定が有効なら保持中は無効になり、保存設定が無効なら保持中は有効になる。
- 一時状態は表示中のパネルを管理するウィンドウコントローラーに置き、設定の保存経路には渡さない。
- Issue の標準 Dock に関する記述に従い、ポインタが Dock 上にある間に切り替える仕様とした。標準 Dock の実画面とは照合できていない。

## 自動テスト結果

`DockTemporaryMagnification` の単体テストで、保存設定が有効な場合と無効な場合の両方について、キー保持中の反転とキー解放後の復帰を確認する。

| 項目 | 結果 |
| --- | --- |
| `run-check.sh 62 test` | 238件すべて成功 |
| `run-check.sh 62 release` | 成功 |
| `run-check.sh 62 testbuild` | 成功 |

最初の Release ビルドでは新しいソースファイルが Xcode プロジェクトに未登録だったため失敗した。`xcodegen generate` でプロジェクトを更新した後、上記3項目を通した。

## 受け入れ条件との対応

| 条件 | 状況 |
| --- | --- |
| 保存設定を変えず、キー保持中だけ標準 Dock と同じ切替を行う | 実装済み。単体テストで保存設定の両状態の反転を確認した。実画面と標準 Dock との比較は未確認 |
| キーを離す、他アプリへ移る、Dock が隠れる場合に元の状態へ戻す | 実装済み。GUI のキー操作、アプリ切替、Dock 非表示は未確認 |
| Reduce Motion と左右配置で確認する | GUI では未確認。既存の Reduce Motion 設定と左右配置で同じ拡大計算を使う |

## 未検証

- 標準 Dock と同じタイミング、対象範囲、拡大の見え方になるかは、標準 Dock を表示できる専用 VM がないため未確認。
- Control と Shift の押下・解放、アプリ切替、Dock の非表示、自動非表示からの復帰は、GUI で未確認。
- Reduce Motion 有効時と Dock の左右配置での実画面は未確認。
- macOS 15 以降の OS ごとの差分は未確認。

## 撮影の手順

専用のヘッドレス macOS VM または検証用 Mac のゲストで撮影する。ホストには Dock Studio を表示しない。

1. ゲストで `/Users/Shared/dockstudio-62` を作り、次の `profiles.json` を置く。

   ```json
   {
     "schemaVersion": 1,
     "activeProfileID": "00000000-0000-0000-0000-000000000001",
     "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
     "profiles": [{
       "id": "00000000-0000-0000-0000-000000000001",
       "name": "Temporary zoom demo",
       "items": [
         { "id": "00000000-0000-0000-0000-0000000000a1", "name": "Finder", "kind": "application", "target": "file:///System/Library/CoreServices/Finder.app/" },
         { "id": "00000000-0000-0000-0000-0000000000a2", "name": "Calculator", "kind": "application", "target": "file:///System/Applications/Calculator.app/" },
         { "id": "00000000-0000-0000-0000-0000000000a3", "name": "TextEdit", "kind": "application", "target": "file:///System/Applications/TextEdit.app/" }
       ]
     }]
   }
   ```

2. 同じディレクトリに次の `appearance.json` を置き、拡大倍率と Reduce Motion を設定する。

   ```json
   { "magnification": false, "magnificationScale": 1.6, "reduceMotion": false }
   ```

3. Dock Studio を起動する。

   ```sh
   DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-62 /path/to/DockStudio.app/Contents/MacOS/DockStudio
   ```

4. Custom Dock を表示し、ポインタを Dock 上へ移動する。アイコンにポインタを合わせて Control と Shift を同時に押し、拡大が有効になることを確認する。
5. 両方のキーを離し、保存設定の無効状態へ戻ることを確認する。`appearance.json` が変わっていないことも確認する。
6. `/Users/Shared/dockstudio-62/appearance.json` の `magnification` を `true` に変え、再起動する。Control と Shift を保持すると拡大が一時的に無効になり、離すと有効に戻ることを確認する。
7. Dock の位置を左右に変え、Reduce Motion を有効にして、同じキー操作を確認する。
8. Control と Shift を保持したまま別アプリへ切り替える、ポインタを Dock の外へ出す、Dock を隠す操作をそれぞれ行い、一時状態が解除されることを確認する。

撮影する画像は、拡大が一時的に有効な状態と無効な状態、左右配置と Reduce Motion の状態、設定ファイルが変化していないことを示す画面にする。動画は Control と Shift の押下、保持中、解放後の変化が一続きで分かるものにする。
