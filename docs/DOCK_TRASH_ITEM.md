# 常設のゴミ箱

## 仕様

Dock の末尾に、区切り線に続けて、常設のゴミ箱を表示する。プロファイルの項目ではないため、保存データの形式は変えていない。取り外しや並べ替えの対象にならず、バックアップにも含まれない。通常の参照項目とは、専用の表示と、区切り線で区別する。

クリックまたは右クリックメニューの「開く」で、`NSWorkspace` から `~/.Trash` を開く。開けなかった場合は、エラーを表示する。ゴミ箱を空にする操作と、ドロップでの投入は含まない。

状態の確認は、`DockStore` が1本だけ持つ2秒間隔の処理で行う。Dock が表示されている間（`isDockEffectivelyVisible` が true）だけ読み、`DockBar` ごとには走らせない。自動非表示で隠れている間も、この条件は true のままなので確認は続く。管理画面のプレビューは、デスクトップの Dock を隠している間は更新されず、最後に読んだ状態のままになる。FSEvents での監視は、この issue の範囲外にした。

空は `trash`、内容ありは `trash.fill` で表示する。VoiceOver には「空」「項目あり」を値として伝える。

- ホームの `~/.Trash` と、ローカルの外部ボリュームの `.Trashes/<uid>` を、すべて確認する。
- `.DS_Store` だけの場合は空として扱う。ドットで始まる削除済みファイルは、項目として扱う。
- どれかに項目があれば、内容ありにする。
- 権限拒否などで読めない場所があり、他に項目がない場合は、空ではなく「確認できない」とし、`trash.slash` を表示する。
- 存在しない場所は空として扱う。

### 既知の懸念

- `~/.Trash` は、macOS の TCC で保護されている。Full Disk Access がないプロセスでは、一覧の取得が EPERM で失敗し、常に「確認できない」（`trash.slash`）になる疑いがある。ホストでは確認できておらず、未検証になる。ゲストで確認する手順は「撮影の手順」に入れた。
- 外部ボリュームが1本でも読めない場合は、他の場所がすべて空でも「確認できない」になる。外部ボリュームの挙動は未検証になる。
- 合成した `DockItem`（`DockStore.trashItem`）は、`kind: .folder` を使う。将来、`.folder` を前提にする処理（ドロップ先や右クリックメニューの共通化、#38 のドロップなど）に、誤って拾われないよう注意が要る。バーは `DockStore.hoverableItems(_:)` で、ホバーとラベルの対象にだけ加えている。
- 幅の計算は、既存の項目と同じ規則にした（区切り線は `10 + 11`、ゴミ箱は `10 + アイコンサイズ`）。縦配置でも、ゴミ箱のタイルは既存の項目と同じ構造（アイコン、5pt の間隔、4pt の Circle、上下5ptの余白）で、既存の項目と同じ数え方になる。

## 検証

2026-10-18 に、ホストでビルドと自動テストを実行した。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 113件すべて成功した（追加は `TrashItemTests` の8件） |
| Release ビルド | 成功した |
| `build-for-testing`（Debug） | 成功した |

自動テストで確認した内容は、空、`.DS_Store` のみ、存在しない場所、複数の場所のどれかに項目がある場合、隠しファイル、読み取り権限がない場所（空にならず、他に項目があれば内容ありになる）、変更への追従、開く処理の呼び出しと失敗時のエラー、プロファイルの項目に含まれないことになる。

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `b64491c` の Release ビルドを macOS 26.6.2、1600×1000の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `87c6d34fff224e99a26ceeea27b5dcf770ddcdb3327f932a7eab7ae73e332387` と一致した。検証用データは、ゲストにあった `payload/data`（Glass 検証）を使った。ホストの画面には何も表示していない。

TCC の確認（撮影手順 3）:

- GUI の Terminal から `open -a Terminal` で `probe.command` を実行すると、`ls -la ~/.Trash` は `Operation not permitted` で失敗した（[tcc-probe.txt](media/dock-trash-item/tcc-probe.txt)）。SSH 経由のシェルでは、同じ `ls` が成功した。したがって、SSH の結果はアプリの状態の証拠にならない。懸念のとおり、Full Disk Access を持たない GUI のプロセスは `~/.Trash` を読めない。
- Full Disk Access を付けない Dock Studio では、ゴミ箱は常に `trash.slash`（確認できない）で表示された。VoiceOver の値は「状態を確認できません」だった（[unknown-hover.jpg](media/dock-trash-item/unknown-hover.jpg)、[unknown-no-hover.jpg](media/dock-trash-item/unknown-no-hover.jpg)）。ゲストの `~/.Trash` は空だったが、空の表示にはならなかった。**現在の実装では、Full Disk Access を与えない通常の利用者に、ゴミ箱の状態が表示されない可能性が高い。** これは不具合の疑いとして報告する。

確認できたこと:

- Dock の末尾に、区切り線に続けてゴミ箱が出た。ホバーで名前「ゴミ箱」が出た（[unknown-hover.jpg](media/dock-trash-item/unknown-hover.jpg)）。
- ゴミ箱を押す（AX の `AXPress`）と、Finder の「Trash」ウインドウが開いた。ゴミ箱は空だった（[finder-open.jpg](media/dock-trash-item/finder-open.jpg)、[動画](media/dock-trash-item/click-opens-finder-trash.mp4)）。動画は撮影時刻の間隔を維持して12fps に変換し、倍速にはしていない。VNC の取得に依存するため、描画性能の測定ではない。開く処理は、確認できないの状態でも動いた。

確認できなかったこと:

- 空の `trash` と内容ありの `trash.fill` の実表示。ゲストのシステム設定で Dock Studio に Full Disk Access を付ける操作は、行っていない（SIP が有効で、TCC のデータベースを直接変更できない。設定画面での操作は認証が要るため、共有 VM では試していない）。このため `empty.png`、`has-items.png`、`trash-demo.mp4` は撮れていない。`HOME` を差し替えたプロセスでも、`FileManager` のゴミ箱の場所は変わらず、確認できないのままだった。
- 各配置（左右）、外観の違い、外部ボリュームの `.Trashes/<uid>`（ゲストには外部ボリュームがない）。

ゲストの状態: `~/.Trash` は空のまま（変更していない）。`probe.command` と出力は削除した。撮影中に開いた Finder の「Trash」ウインドウは、AppleEvents の許可がなく閉じられなかったため、ゲストに開いたまま残っている。

## 未検証

上の「実画面の確認」で確認できなかった項目は、次のとおり。

- 空と内容ありの実表示（Full Disk Access を付けた状態）、各配置（左右）、外観の違い
- 実際の外部ボリュームの `.Trashes/<uid>` の確認
- macOS 15〜25 での動作

## 撮影の手順

専任の撮影担当が、専用ヘッドレス VM で行う。ホストには、アプリも VM の画面も表示しない。`/private/tmp/dockstudio-vm.lock` を取り、10分以内に終えて解放する。ゲストで `python3` は実行しない（コマンドラインツールのインストールダイアログが出る）。

1. ビルド: ホストで Release ビルドし、`DockStudio.app` を zip にして、ゲストの `~/DockStudioVerification/` へ渡す。検証用データは `payload/data` を使う。内容は、プロファイル「Glass 検証」（Finder、Safari、Mail、Terminal、Calendar、Downloads）、モードは「両方」、位置は下、自動非表示は無効、外観はガラス調の画像背景になる。
2. 起動: ゲストで `killall DockStudio || true` の後に、次を実行する。

```
open -n --env DOCKSTUDIO_DATA_DIR=/Users/admin/DockStudioVerification/data /Users/admin/DockStudioVerification/current/DockStudio.app
```

3. TCC の確認（先に行う）: SSH 経由のシェルは、sshd の権限（Full Disk Access を持つ場合がある）を引き継ぐため、`ls ~/.Trash` を SSH で実行しても、アプリの状態の証拠にならない。次の2つで確認する。
   - プローブ: ゲストに `probe.command`（内容は `ls -la ~/.Trash > /tmp/trash-probe.out 2>&1`、実行権限あり）を置き、`open -a Terminal ~/probe.command` で GUI のターミナルから実行する。その後、SSH で `cat /tmp/trash-probe.out` を読む。`Operation not permitted` なら、GUI から起動したプロセスは `~/.Trash` を読めない。結果は、出力のまま報告する。確認後に `probe.command` と出力を消す。
   - アプリ: Full Disk Access を付けない Dock Studio で、ゴミ箱の表示を見る。`trash.slash`（確認できない）のまま変わらなければ、疑いどおりになる。この場合は、「確認できない」表示が恒常的に出ることを `unknown.png` に残す。
   - 空と内容ありの撮影は、ゲストのシステム設定で Dock Studio に Full Disk Access を付けてから行う。付けた事実を、報告に書く。付けられない場合は、撮影できなかったと報告する。
4. 空の状態: ゲストで `rm -rf ~/.Trash/* ~/.Trash/.[!.]*`（ゲストの `~/.Trash` だけ）を実行し、約3秒待つ。Dock の末尾に、区切り線と `trash`（空）が出ることを撮る。
5. 内容ありの状態: ゲストで `touch ~/.Trash/sample.txt` を実行し、約3秒待つ。`trash.fill` に変わることを撮る。
6. ホバー: ゴミ箱の上にポインタを置き、名前「ゴミ箱」が出ることを撮る。
7. 開く: ゲストで、アプリの PID を `pgrep -x DockStudio` で調べ、`~/DockStudioVerification/guest-ax <PID> ゴミ箱` を実行する。Finder にゴミ箱のウィンドウが開き、`sample.txt` が見えることを撮る。VNC のクリックは、反応しないことがある。
8. 片付け: ゲストで `rm -f ~/.Trash/sample.txt` を実行して元に戻し、Finder のウィンドウを閉じ、`killall DockStudio` を実行する。トンネルは、自分で張ったものの PID だけを kill する。

撮る画像と動画は、次のとおり。保存先は `docs/media/dock-trash-item/` にする。画像は1枚500KB程度、動画は2MB程度に縮める。

| ファイル | 内容 |
| --- | --- |
| `empty.png` | 空のゴミ箱 |
| `has-items.png` | `sample.txt` を入れた状態 |
| `hover.png` | ホバー名「ゴミ箱」 |
| `finder-open.png` | Finder のゴミ箱が開いた状態 |
| `unknown.png` | 権限がなく確認できない表示（手順3で再現した場合のみ） |
| `trash-demo.mp4` | 空、ファイル追加、内容あり、クリックで Finder が開く、までの動画。撮影時刻の間隔を保つ |
