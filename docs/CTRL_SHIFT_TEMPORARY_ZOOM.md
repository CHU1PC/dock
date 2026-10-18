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

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `6c08341` の Release ビルドを macOS 26.6.2 の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `5f1bc84c3b8ee6e721040378c5e469f7c19d37fd2868673c76af0e1d89974169` と一致した。Finder、Calculator、TextEdit のプロファイル、アイコン 64、拡大倍率 1.6。Control と Shift は、本物のキーダウン（Control、Shift の順）を先に送り、押したまま保持し、キーアップした。拡大は、AX のボタンの寸法（幅x高さ）で測った。ログは[logs.txt](media/ctrl-shift-temporary-zoom/logs.txt)にある。

| 条件 | ホバーだけ | Control+Shift 保持中 | 離した後 |
| --- | --- | --- | --- |
| 保存設定 `magnification: false`、下配置 | 全アイコン 74x73 | Calculator 113x111、Finder と TextEdit 91x90（**拡大が有効になった**） | 74x73 に戻った。`appearance.json` は変わらず |
| 保存設定 `magnification: true`、下配置 | Calculator 112x111 など（拡大中） | 全アイコン 74x73（**一時的に無効になった**） | 拡大に戻った。`appearance.json` は変わらず |
| 保存設定 false、左配置、Reduce Motion 有効 | 64x83 | Calculator 102x122、ほか 82x100（拡大が有効） | 64x83 に戻った |
| 保持したままポインタを Dock の外へ出す（左配置） | 保持中に拡大 | 外へ出ると 64x83 に戻った（一時状態が解除された） | — |

画像と動画: [下配置の保持中（画像）](media/ctrl-shift-temporary-zoom/panel-hold-ctrl-shift-bottom-crop.jpg)（全体は[こちら](media/ctrl-shift-temporary-zoom/panel-hold-ctrl-shift-bottom-full.jpg)）、[動画](media/ctrl-shift-temporary-zoom/custom-dock-ctrl-shift-hold.mp4)（8fps。押下、保持、解放まで）。

確認できなかったこと、手順との違い:
- 右配置、別アプリへ切り替えたときの解除、Dock を隠したときの解除は、撮影していない。左配置の撮影は寸法の測定だけで、画像は撮っていない。
- パネルは「設定」タブにしたが、保存設定 true の場合の画像は撮っていない（寸法のログのみ）。

標準 Dock の同じ操作（標準 Dock の `magnification` は無効、アイコンのホバー中に同じ Control+Shift の保持を送った）: [動画](media/ctrl-shift-temporary-zoom/standard-dock-ctrl-shift-hold.mp4)、[コマ](media/ctrl-shift-temporary-zoom/standard-dock-frames.png)のとおり、**アイコンの拡大は観察できなかった**（ラベルは出るが、大きさは変わらない）。ただし、AX による大きさの測定は、標準 Dock の AX の構造に合わず、値が取れなかった。合成したキーが標準 Dock に届いたかは不明で、標準 Dock の挙動としては結論できない。撮影後、標準 Dock の設定は元に戻した。
