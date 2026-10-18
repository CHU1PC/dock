# 外部ディスクをドラッグして取り出す

## 仕様

Custom Dock の保持項目のうち、取り出し可能なボリュームのルートを指すフォルダだけを、Dock の外へドラッグして取り出す。Finder の通常のフォルダやファイル、ボリューム内のサブフォルダは従来どおりプロファイルから取り外す。

- 判定対象は、ファイル URL のフォルダで、ファイルシステムが返すボリューム URL と項目 URL が一致し、`volumeIsEjectable` が true のものに限る。起動ディスクは対象にしない。
- ドラッグ中は、通常項目には従来の「取り外す」を表示する。ディスクにはイジェクト記号と「ディスクを取り出す」を表示する。
- ディスクを外で離すと `NSWorkspace.unmountAndEjectDevice(at:error:)` を呼ぶ。項目をプロファイルから削除せず、元ディスクのファイルにも変更を加えない。
- 取り出しに失敗した場合は強制アンマウントしない。使用中の項目を閉じる案内とシステムのエラー内容を表示する。
- 判定と排出操作は `VolumeEjector` にまとめ、ファイルシステム情報と排出処理をテスト用の関数に差し替えられる。

## 仕様判断

ボリューム内の任意のフォルダからディスク全体を排出すると誤操作になりうるため、ボリュームのルートと一致する項目だけを対象にした。ディスクの排出はアイテム参照の削除とは異なる操作なので、通常項目のドラッグアウト処理と既存の保存動作は変えていない。

## 自動テスト

`VolumeEjectorTests` は、排出可能なボリュームルート、ボリューム内のサブフォルダ、ファイル、起動ボリューム、排出不可または不明なボリュームを偽のメタデータで判定する。また、排出操作の呼び出しと失敗の伝播も偽物で確認する。

2026-10-18 に、ホスト上でビルドと単体テストだけを実行した。GUI アプリは起動していない。

```
/private/tmp/cw/run-check.sh 40 test
Executed 259 tests, with 0 failures (0 unexpected)
exit=0

/private/tmp/cw/run-check.sh 40 release
** BUILD SUCCEEDED **
exit=0

/private/tmp/cw/run-check.sh 40 testbuild
** TEST BUILD SUCCEEDED **
exit=0
```


## 未検証

- 専用 VM での画面とドラッグ動作、実際のディスクイメージの排出、およびイメージ内ファイルが残ることは撮影担当が確認する。
- 使用中のファイルがある場合の OS の具体的なエラー表示と、macOS 15 から 26 の挙動差は未確認になる。
- 物理ディスクやネットワークボリュームの排出動作は未確認になる。

## 撮影の手順

撮影は専用のヘッドレス macOS VM 内で行い、ホストには検証画面を出さない。macOS 15 以降のうち利用できる VM の OS バージョンを記録する。

### 起動と検証データ

このブランチ `feat/eject-volume-by-drag` の Release ビルドを VM に置き、ゲストで直接起動する。ゲスト内に `~/verify-eject` を作り、そこを `DOCKSTUDIO_DATA_DIR` に指定する。`profiles.json` は `docs/DRAG_OUT_TO_REMOVE.md` の「検証用データ」を元にし、`position` は `bottom`、モードは `custom` にする。項目に `file:///Volumes/Eject%20Test/` を target とする `kind: folder` の `Eject Test` を追加し、通常の `Downloads` フォルダも残す。

VM ゲスト内でだけ、`hdiutil` を使って `/Volumes/Eject Test` にマウントする読み書き可能な検証用ディスクイメージを作る。イメージ内に `sentinel.txt` を作り、内容とハッシュを記録してから Dock Studio を起動する。ホストではイメージを作成、マウント、または排出しない。

起動コマンドは次を使う。`<app>` はゲストに置いた `DockStudio.app` を指す。

```
DOCKSTUDIO_DATA_DIR="$HOME/verify-eject" <app>/Contents/MacOS/DockStudio
```

### Dock Studio での操作

1. ディスク項目と `Downloads` が見える状態を撮る。
2. ディスク項目を背景の外へドラッグし、離す前に予告を撮る。「ディスクを取り出す」とイジェクト記号が見えることを記録する。
3. Dock の内側へ戻して離す。ディスクがマウントされたままで、ファイル、項目とも変わらないことを確認する。
4. もう一度ディスクを外へドラッグして離す。Finder からボリュームが消え、Dock のディスク項目は残ることを確認する。
5. ゲスト内でディスクイメージを再マウントし、`sentinel.txt` の内容とハッシュが作成時と一致することを確認する。
6. `Downloads` を外へドラッグし、従来どおり「取り外す」の表示とプロファイルからの削除が行われることを確認する。ディスク内ファイルはこの操作でも変わらないことを確認する。
7. 可能なら、ディスクイメージ内のファイルを開いたまま排出を試す。失敗を報告し、ボリュームが強制的にアンマウントされず、イメージ内データが保たれることを確認する。OS が排出を許可した場合は、その事実と再現条件を記録する。

### 標準 macOS Dock との比較

同じゲスト OS、解像度、Dock 配置、アイコンサイズ、同じディスクイメージと項目を使って標準 Dock でも操作する。次を計測し、条件と結果を文章または動画ログに残す。

- 外へドラッグしたときにゴミ箱のアイコンがどう変わるか、変化が始まる位置、および予告表示の有無。
- ディスクが Dock から離れる位置、ドラッグを始めてから離すまでの時間、および排出完了までの時間。
- ドラッグ中に内側へ戻したときの表示と、離した後のマウント状態。
- 成功後にディスク項目が Dock に残るか、Finder のサイドバーとデスクトップから消えるか。
- 使用中のディスクで拒否されるか、警告やエラーが出るか、強制的なアンマウントが起きるか。
- 排出前後の `sentinel.txt` の存在、内容、ハッシュ。ディスク内のほかのファイルも削除されていないか。

### 撮影するもの

保存先は `docs/media/eject-volume-by-drag/` とする。

| ファイル | 内容 |
| --- | --- |
| `dockstudio-before.png` | Dock Studio の項目とマウント済みディスク |
| `dockstudio-dragging.png` | ドラッグ中の「ディスクを取り出す」とイジェクト記号 |
| `dockstudio-ejected.png` | 排出後も項目が残り、ボリュームが未マウントの状態 |
| `dockstudio-roundtrip.txt` | ディスクイメージ再マウント後の sentinel 内容とハッシュ |
| `dockstudio-drag-eject.mp4` | 内側へ戻す操作と、外へ離して排出する操作 |
| `dockstudio-ordinary-removal.png` | Downloads の通常の「取り外す」予告 |
| `standard-dock-before.png` | 標準 Dock で操作する前の同一条件 |
| `standard-dock-dragging.png` | 標準 Dock のドラッグ中の表示 |
| `standard-dock-ejected.png` | 標準 Dock で排出した後の状態 |
| `standard-dock-drag-eject.mp4` | 標準 Dock のドラッグ操作 |
| `comparison.txt` | 上記の測定値、OS バージョン、拒否時の挙動 |

