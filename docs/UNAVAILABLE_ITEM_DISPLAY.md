# 参照先が消えた項目の利用不可表示

## 仕様

アプリ、フォルダ、ファイルの項目で、参照先が存在しない場合に、Dock とプロファイル編集の一覧で通常のアイコンの代わりに代替アイコンを表示する。

| 状態 | 判定 | 表示 |
| --- | --- | --- |
| 利用可能 | 参照先を `stat` でき、成功した | 通常のアイコン |
| 参照切れ | `ENOENT` または `ENOTDIR`。壊れたシンボリックリンクと、対象が未設定の項目を含む | 疑問符の代替アイコン |
| ボリューム未接続 | 参照先が `/Volumes/<名前>/` 以下にあり、`/Volumes/<名前>` 自体が存在しない | 外付けドライブに×の代替アイコン |
| アクセス不可 | 権限拒否（`EACCES`、`EPERM`）、I/O エラー、タイムアウトなど | 通常のアイコンのまま（消えたとは判定しない） |

リンク、スペーサー、時計、集中タイマーは、常に利用可能として扱う。

判定は `ItemAvailabilityChecker`（`DockStudio/Services/ItemAvailability.swift`）が行う。画面から独立した純粋な構造体で、`stat` の結果を返す関数を差し替えられる。

### 判定の更新タイミング

描画のたびにファイルシステムを確認しない。`ItemAvailabilityMonitor` が結果を項目 ID ごとにキャッシュし、描画はキャッシュだけを読む。確認はバックグラウンドで実行し、次のタイミングで更新する。

- 項目が最初に表示されたとき、または参照先（`target`）が変わったとき（再選択による回復）
- ボリュームのマウントまたはアンマウントの通知を受けたとき（再接続による回復）
- ポインタが Dock に入ったとき。Custom Dock のパネルは非アクティブのまま操作できるため、アプリのアクティブ化は契機にしない。パネルでは `isDockPointerInside` が true になったとき、ウィンドウ内のプレビューでは hover の開始時に、全項目を再判定する。1秒以内の再実行は省略する
- 項目を開く操作の直前（その場で最新の状態を確認し、キャッシュを更新する）

キャッシュは参照先の文字列と組で保存する。参照先が変わった項目は、古い結果を使わず、新しい確認が終わるまで通常表示になる。

### 開く操作

参照切れとボリューム未接続の項目は、開く前の確認でエラーメッセージを表示して止まり、何も起動しない。メッセージは両者で異なる。既存の起動前の検証（`ItemLaunchPolicy`）は変更しておらず、参照切れを別の対象へ結び付けることはない。

### プロファイルとの関係

利用不可の項目を、プロファイルから自動で削除しない。取り外しは、既存の「Dock から取り外す」操作で利用者が行う。

## 受け入れ条件との対応

| 条件 | 状況 |
| --- | --- |
| 参照切れと一時的なボリューム未接続を区別して表示する | 満たした（アイコンと開く時のメッセージが異なる）。単体テストで判定を確認した。実画面は未検証 |
| 再接続や再選択で状態を回復できる | 満たした（マウント通知と参照先の変更で再判定）。実際のボリュームの着脱は未検証 |
| 起動前の検証を維持し、参照切れを勝手に別の対象へ結び付けない | 満たした（`ItemLaunchPolicy` は未変更。開く前に停止するだけで、参照先は書き換えない） |

VoiceOver のラベルは、受け入れ条件にないため変更していない。

## 制約

- `openItem` の開く前の確認は同期 I/O で、1件の `stat` を呼び出し元のスレッドで行う。応答しないネットワークボリュームでは、そのスレッド（メイン）がブロックしうる。
- 移動した項目は検出できない。ブックマークを持たないため、参照切れとして扱う。
- ポインタが Dock に入る前に起きた変化は、入るまで表示に反映されない（マウント通知による変化を除く）。

## 検証

ホストで、ビルドと単体テストだけを実行した。GUI は表示していない。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 116件すべて成功（新規12件） |
| Release ビルド | 成功した |
| Debug の `build-for-testing` | 成功した（Release 構成では `@testable import` が解決できないため Debug を使用） |

### 未検証

- 実画面での代替アイコンの見え方と、Dock の各アイコンサイズでの表示
- 実際の外付けボリュームの取り外しと再接続による表示の切替
- 移動した項目の検出（ブックマークを持たないため、移動は参照切れとして扱う）
- macOS 15 以降での差異（VM が 26.6.2 のみで、未確認）
- ポインタが Dock に入ったときの再判定の実画面での動作

## 撮影の手順

撮影は、専用ヘッドレス VM のゲストの中だけで行う。**`hdiutil` は、ゲストの中でだけ実行し、ホストでは実行しない。**

### 検証用データ

ゲストで `/Users/Shared/dockstudio-46` を作り、その中に次の `profiles.json` を置く。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Unavailable demo",
      "items": [
        { "id": "00000000-0000-0000-0000-0000000000a1", "name": "Calculator", "kind": "application",
          "target": "file:///System/Applications/Calculator.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a2", "name": "Copied App", "kind": "application",
          "target": "file:///Users/Shared/dockstudio-46/Copied.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a3", "name": "Removed Folder", "kind": "folder",
          "target": "file:///Users/Shared/removed-folder/" },
        { "id": "00000000-0000-0000-0000-0000000000a4", "name": "Disk Project", "kind": "folder",
          "target": "file:///Volumes/Detached%20Disk/Project/" }
      ]
    }
  ]
}
```

アプリのビルド成果物（`DockStudio.app`）をゲストに置き、次で起動する。

```
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-46 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

起動前に、ゲストで次を実行する。

```
cp -R /System/Applications/Calculator.app /Users/Shared/dockstudio-46/Copied.app
hdiutil create -size 10m -fs APFS -volname "Detached Disk" /tmp/detached.dmg
hdiutil attach /tmp/detached.dmg
mkdir "/Volumes/Detached Disk/Project"
```

### 操作

1. 上の状態でアプリを起動し、Custom Dock を表示する。「Removed Folder」だけは最初から疑問符のアイコンになり、ほかの3項目は通常のアイコンで表示される。
2. アプリの削除を撮影する。Dock にポインタを置いた状態で、ゲストの別の端末から `mv /Users/Shared/dockstudio-46/Copied.app /tmp/Copied.app.moved` を実行する（Finder でゴミ箱に移してもよい）。ポインタを一度 Dock の外に出して入れ直すと、「Copied App」が通常のアイコンから疑問符のアイコンに変わる。
3. 「Copied App」をクリックする。「見つかりません」のエラーが表示され、何も起動せず、項目は Dock に残る。
4. `mv /tmp/Copied.app.moved /Users/Shared/dockstudio-46/Copied.app` で戻し、ポインタを Dock に入れ直す。通常のアイコンに戻る。
5. `hdiutil detach "/Volumes/Detached Disk"` を実行する。数秒以内に「Disk Project」が外付けドライブに×のアイコンへ変わる。
6. 「Disk Project」をクリックする。「接続されていません」のエラーが表示される。
7. `hdiutil attach /tmp/detached.dmg` で再接続する。「Disk Project」が通常のアイコンに戻る。
8. プロファイル編集の一覧を開き、同じ表示になっていることを確認する。

### 期待する見え方

- 存在しないアプリとフォルダは、薄い角丸の四角に疑問符が入ったアイコンになる。
- 未接続のボリューム上の項目は、同じ背景に外付けドライブと×のアイコンになる。
- 復旧後は通常のアイコンに戻る。

### 撮るべきもの

| 種類 | 内容 |
| --- | --- |
| 画像 | 通常の項目、参照切れの項目、ボリューム未接続の項目が並ぶ Dock |
| 画像 | 復旧後の Dock |
| 画像 | プロファイル編集の一覧の表示 |
| 画像 | 参照切れの項目を開いたときのエラー表示（2種類） |
| 動画 | アプリの削除から復旧までの、アイコンの切替（手順2から4） |
| 動画 | ボリュームの取り外しから再接続までの、アイコンの切替（手順5から7） |

macOS 15 以降の差異は、VM が 26.6.2 のみなので未確認になる。
