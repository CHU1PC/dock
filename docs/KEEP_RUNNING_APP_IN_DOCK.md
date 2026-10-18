# 実行中アプリの Dock への保持

## 仕様

「実行中のアプリを表示」で一時的に出ている項目を右クリックすると、メニューに「Dock に保持」が表示される。選ぶと、使用中のプロファイルへ項目を追加し、すぐに保存する。保存後は「<項目名> を Dock に保持しました」と状態が出る。

保持した項目は、実行中アプリの `bundleIdentifier` と、アプリの場所（`target`）を持つ。保存前に `ItemLaunchPolicy().validate` で、有効なアプリ（`.app`、実行可能）か確かめる。無効なら保存せず、「Dock に保持できませんでした。」に続けて理由を `errorMessage` に出す。

保持済みの項目には「Dock に保持」を出さず、「Dock から取り外す」（#66）を出す。区別には `DockStore.isPinned` を使う。`isPinned` は、使用中のプロファイルに同じ id の項目があるかで判定する。同じアプリ（`applicationIdentity` が一致）が使用中のプロファイルにすでにあれば、何もせず、`status` も `errorMessage` も出さずに `true` を返す。これは API としての仕様であり、メニューは `isPinned` の項目に「Dock に保持」を出さないため、画面からは到達しない。テスト名 `testKeepingAlreadyKeptAppIsSilentNoOpReturningTrue` で縛っている。重複の追加一般は #84 で扱う。

取り外した後も、アプリが実行中で「実行中のアプリを表示」が有効なら、一時表示の項目として残る。

保存処理は `DockStore.keepInActiveProfile(_:)` として、画面から独立した関数にした。プロファイルに未保存の編集（下書き）がある場合は、下書きにも同じ項目を加え、下書きの保存で項目が消えないようにした。VoiceOver のアクションにも、同じ「Dock に保持」を出す。

保存データの形式は変えていない。古い保存データは、そのまま読み込める。

## 検証

2026-10-18 にホストで、ビルドと単体テストを実行した。実画面の確認は次の「実画面の確認」の節に書く。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 110件すべて成功した（新規5件を含む） |
| Release ビルド | 成功した |
| `build-for-testing`（Debug） | 成功した |

新規テストは `DockStudioTests/KeepRunningAppTests.swift` にある。保存と再読込、重複しないこと(何も出さずに true を返す)、取り外し後の一時表示への復帰、無効なアプリと非アプリの拒否、下書きとの整合を確かめる。保存形式は変えていないため、古い保存データの読み込みを縛るテストは置いていない。

## 撮影の手順

確認する OS は、macOS 26.6.2 の専用ヘッドレス VM だけになる。macOS 15 以降の差分は未確認。ホストの画面には何も表示しない。

### 準備

1. ホストで Release ビルドを作る。

```
nice -n 15 xcodebuild -project DockStudio.xcodeproj -scheme DockStudio -configuration Release \
  -derivedDataPath /tmp/dockstudio-11-derived CODE_SIGNING_ALLOWED=NO build
```

2. 成果物 `/tmp/dockstudio-11-derived/Build/Products/Release/DockStudio.app` を、VM へコピーする(例: `scp -r` で `~/DockStudio.app`)。コピー先は撮影担当の既存の VM 手順に従う。コピー後に、ホストとゲストで実行ファイルの SHA-256 が一致することを確かめ、docs に記録する。
3. ゲストに検証用データのディレクトリ `~/keep-data` を作り、`profiles.json` を次の内容で置く。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "11111111-1111-1111-1111-111111111111",
  "profiles": [
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "name": "Keep test",
      "items": [
        { "id": "22222222-2222-2222-2222-222222222222", "name": "Finder", "kind": "application",
          "target": "file:///System/Library/CoreServices/Finder.app", "bundleIdentifier": "com.apple.finder" },
        { "id": "33333333-3333-3333-3333-333333333333", "name": "Safari", "kind": "application",
          "target": "file:///Applications/Safari.app", "bundleIdentifier": "com.apple.Safari" }
      ]
    }
  ],
  "settings": {
    "mode": "custom", "position": "bottom", "iconSize": 52, "autoHide": false,
    "revealAnimationDuration": 0.22, "launchBounce": true, "showRunningApps": true
  }
}
```

Safari の場所がゲストで異なる場合は、`mdfind "kMDItemCFBundleIdentifier == 'com.apple.Safari'"` で確かめて `target` を直す。

4. ゲストで Calculator と Mail を起動する(`open -a Calculator`、`open -a Mail`)。

### 起動と再起動のコマンド

```
DOCKSTUDIO_DATA_DIR=~/keep-data ~/DockStudio.app/Contents/MacOS/DockStudio &
pkill -x DockStudio
```

終了は `pkill -x DockStudio`(ゲスト内だけで実行する)。再起動は、同じ起動コマンドをもう一度実行する。

### 操作

1. 起動して、Dock に保持済みの Finder と Safari、一時表示の Calculator と Mail が並ぶことを撮る(`before.png`)。
2. Calculator を右クリックする。メニューに「開く」「Finder で表示」「Dock に保持」が出ることを撮る(`menu-keep.png`)。Finder を右クリックし、「Dock に保持」は出ず「Dock から取り外す」が出ることを撮る(`menu-pinned.png`)。
3. Calculator で「Dock に保持」を選ぶ。項目が保持済みとして残り、状態に「Calculator を Dock に保持しました」と出ることを撮る(`after-keep.png`)。再度右クリックし、「Dock に保持」が消えて「Dock から取り外す」が出ることを確認する。`~/keep-data/profiles.json` に Calculator の `target` と `bundleIdentifier` が入ったことも、`cat` の出力で記録する。
4. Calculator を終了し、続けて `pkill -x DockStudio` で DockStudio も終了する。`DOCKSTUDIO_DATA_DIR=~/keep-data` を付けて起動し直す。Calculator が実行中でない状態でも、Calculator が Dock に残ることを撮る(`after-relaunch.png`)。
5. Calculator を起動する。「Dock から取り外す」を選ぶ。Calculator が一時表示として残ることを撮る(`after-unkeep.png`)。Calculator を終了すると、項目が消えることも確認する。
6. 手順 1〜3 と 5 を通した動画を撮る(`keep-running-app.mp4`)。撮影時刻の間隔を維持して15fpsに変換し、倍速にはしない。

### VoiceOver 用アクションの確認

VoiceOver は有効にせず、`docs/REMOVE_DOCK_ITEM.md` と同じ AX API の確認用ツールを使う。

- Calculator(一時表示)の項目の `AXUIElementCopyActionNames` に「Dock に保持」が含まれ、「Dock から取り外す」が含まれないこと。
- Finder(保持済み)の項目では逆になること。
- Calculator で `AXUIElementPerformAction` を「Dock に保持」で実行し、`profiles.json` に Calculator が追加されること。
- `AXShowMenu` で右クリックと同じメニューが開き、「Dock に保持」が表示されること(`ax-show-menu.png`)。
- アクション一覧の出力を `ax-actions.txt` に保存する。

### 保存先と撮影一覧

すべて `docs/media/keep-running-app/` に保存する。

`before.jpg`、`menu-keep.jpg`、`menu-pinned.jpg`、`after-keep.jpg`、`after-relaunch.jpg`、`after-unkeep.jpg`、`ax-show-menu.jpg`、`ax-actions.txt`、`profiles-after-keep.txt`、`keep-running-app.mp4`。画像は JPEG で保存する。

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `ae0a3ea` の Release ビルドを macOS 26.6.2、1600×1000の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `a6edef8e855fc7b4b83f43a28e7586190329f263b1788efa9937ecffda314b9f` と一致した。検証用データは `~/keep-data/profiles.json` に上の内容で置いた。ホストの画面には何も表示していない。

確認できたこと:

- 一時表示の Calculator を右クリックすると、メニューに「開く」「Finder で表示」「Dock に保持」が出た（[menu-keep.jpg](media/keep-running-app/menu-keep.jpg)）。保持済みの Finder では「開く」「Finder で表示」「Dock から取り外す」が出て、「Dock に保持」は出なかった（[menu-pinned.jpg](media/keep-running-app/menu-pinned.jpg)）。
- 「Dock に保持」を選ぶと、状態に「Calculator を Dock に保持しました」が出た（[after-keep.jpg](media/keep-running-app/after-keep.jpg)）。保存ファイルには、`bundleIdentifier` が `com.apple.calculator`、`target` が `file:///System/Applications/Calculator.app/` の項目が追加された（[profiles-after-keep.txt](media/keep-running-app/profiles-after-keep.txt)）。保持後に Calculator を右クリックすると、「Dock から取り外す」が出た。
- Calculator と DockStudio を終了し、同じデータで DockStudio を起動し直すと、Calculator が起動していない状態でも Dock に残った。起動中の点は付いていなかった（[after-relaunch.jpg](media/keep-running-app/after-relaunch.jpg)）。
- Calculator を起動して「Dock から取り外す」を選ぶと、状態に「Calculator を Dock から取り外しました」が出て、Calculator は一時表示として残った（[after-unkeep.jpg](media/keep-running-app/after-unkeep.jpg)）。Calculator を終了すると、項目が Dock から消えた。
- 操作の動画は[keep-running-app.mp4](media/keep-running-app/keep-running-app.mp4)に保存した。メニューを出す、保持する、保持済みのメニューを出す、取り外す、Calculator を終了して項目が消えるまでを含む。撮影時刻の間隔を維持して15fps に変換し、倍速にはしていない。画面の一部（Dock と状態の表示）に切り出している。VNC のフレームの取得に依存するため、実時間の描画の滑らかさを示すものではない。
- VoiceOver 用アクションは、AX API の確認用ツールで確かめた。一時表示の Calculator は「Dock に保持」を持ち、「Dock から取り外す」は持たなかった。保持済みの Finder と Safari は逆だった。Calculator に対して `AXUIElementPerformAction` で「Dock に保持」を実行すると、結果が成功になり、保存ファイルに Calculator が追加された。実行後は、Calculator のアクションが「Dock から取り外す」に変わった（[ax-actions.txt](media/keep-running-app/ax-actions.txt)）。VoiceOver は有効にしていない。
- `AXShowMenu` を実行すると、右クリックと同じメニューが開いた（[ax-show-menu.jpg](media/keep-running-app/ax-show-menu.jpg)）。ただしこの時点の Calculator は保持済みだったため、メニューに出たのは「Dock から取り外す」で、一時表示のときの「Dock に保持」は `AXShowMenu` では撮っていない。`AXShowMenu` の戻り値は、メニューが開いたにもかかわらず、`-25204`（cannot complete）だった。

撮影手順との違い（結果への影響は小さい）:

- Mail は、ゲストでアカウント追加のダイアログが前面に出て操作を妨げたため、ダイアログを閉じた時点で終了した。画像と動画に Mail は含まれない。手順 1 の「Calculator と Mail」は、Calculator だけで確認した。
- ゲストに、別の作業で残った「Install Command Line Developer Tools」（python3 の呼び出しで出たインストーラー）が起動中で、一時表示として Dock に並んだ（[before.jpg](media/keep-running-app/before.jpg)）。確認の対象外であり、インストールはしていない。
- メニュー項目は、AX の `AXPress` では押せなかったため、ゲスト内の CGEvent のクリックで選んだ。

## 未検証

| 項目 | 状況 |
| --- | --- |
| VoiceOver のアクション「Dock に保持」 | AX API では確認した。VoiceOver を有効にした実際の読み上げと操作は未検証 |
| `AXShowMenu` で一時表示の項目のメニューを開いた画面 | 保持済みの項目で開いたことだけ撮影した |
| Mail など複数の一時表示を並べた状態 | Calculator だけで確認した |
| macOS 15〜25 | 未確認。VM は macOS 26.6.2 のみ |
| DMG や Gatekeeper の AppTranslocation で起動したアプリ | `bundleURL` が一時的なパスになり、保持した項目が再起動後に無効になる可能性がある。未確認 |
