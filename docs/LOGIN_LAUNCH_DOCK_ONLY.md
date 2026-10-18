# ログイン時は Dock だけを表示する

GitHub issue #86 の仕様と実装記録になる。

## 原因と仕様

ログイン起動では SwiftUI の Studio `Window` が抑制される。以前は `DockAppDelegate.applicationDidFinishLaunching` の中で `CustomDockWindowController` を同期的に作り、その初期更新でパネルを前面に出していた。Studio の scene が抑制される起動時に、SwiftUI の scene 初期化と AppKit パネルの表示順序が競合し、パネルが表示されない状態になっていた。Studio をメニューから開くとパネルが現れた再現結果も、この起動時のライフサイクル競合と整合する。

`DockAppDelegate.swift` では最初のイベントループを譲ってからコントローラを作り、SwiftUI が起動時の Window scene を確定した後にパネルの初期表示を行う。Custom Dock のコントローラは Studio ウィンドウの表示に依存せず、Dock の表示状態は `DockStore` が復元した値で決まる。

- `kAEOpenApplication` に `keyAELaunchedAsLogInItem` が付いたログイン起動では、Dock の復元値が `true` なら Dock を表示し、Studio ウィンドウは自動で開かない。
- ログイン起動で Dock の復元値が `false` なら、Dock と Studio ウィンドウのどちらも自動で表示しない。
- 通常起動では、従来どおり Studio ウィンドウを自動で開く。
- メニューバーから Studio ウィンドウを開く動作と、Dock の表示状態の復元を維持する。

## 自動テスト

`LoginLaunchPolicyTests` に次の回帰テストを追加した。

- `testLoginLaunchRestoresVisibleDockWithoutStudioWindow` は、ログイン起動かつ Dock 復元値が `true` のとき `showDock == true` と `showStudio == false` を検証する。修正前は `XCTAssertTrue(decision.showDock)` が失敗した。
- `testLoginLaunchWithHiddenDockShowsNeitherWindow` は、ログイン起動かつ Dock 復元値が `false` のとき両方が `false` であることを検証する。
- `testNormalLaunchShowsStudioWindow` は、通常起動では Dock が非表示でも Studio ウィンドウを開くことを検証する。
- 既存テストは Apple event のログイン判定と通常起動の判定を検証する。

修正後のホスト側検証出力は次のとおり。アプリの GUI は起動していない。

```
/private/tmp/cw/run-check.sh 86 test
	 Executed 27 tests, with 0 failures (0 unexpected) in 1.919 (1.925) seconds
	 Executed 3 tests, with 0 failures (0 unexpected) in 0.032 (0.033) seconds
	 Executed 8 tests, with 0 failures (0 unexpected) in 0.533 (0.534) seconds
	 Executed 262 tests, with 0 failures (0 unexpected) in 10.112 (10.154) seconds
	 Executed 262 tests, with 0 failures (0 unexpected) in 10.112 (10.164) seconds
exit=0

/private/tmp/cw/run-check.sh 86 release
** BUILD SUCCEEDED **
exit=0

/private/tmp/cw/run-check.sh 86 testbuild
** TEST BUILD SUCCEEDED **
exit=0
```

## 未検証

- 修正後の専用 VM でログイン起動し、Dock が表示され Studio ウィンドウが開かないこと。
- 実際のログアウトと再ログインによるログイン項目からの自動起動。
- Finder と Dock からの通常起動、メニューバーからの Studio 表示、Dock の状態復元の実画面。
- macOS 15 の実機での起動順序。

修正前の専用 VM では、通常起動で Dock と Studio の両方が表示され、Apple event を使ったログイン項目風の起動では Studio は抑制された一方、Dock パネルも表示されなかった。`launch-state.json` は `{"dockVisible": true}` で、メニューから Studio を開くと Dock パネルが現れた。詳細ログと動画は `media/login-launch-dock-only/` にある。修正後の VM 撮影は必要になる。

## 撮影の手順

専任の撮影担当が、専用のヘッドレス macOS VM で実施する。ホストでアプリを起動しない。

1. ゲスト内の一時ディレクトリを `DOCKSTUDIO_DATA_DIR` に指定し、`<ディレクトリ>/profiles.json` を使う。初回起動で生成されたプロファイルを使用し、「Dock」の構成を Custom Dock が表示される設定にする。ログイン項目はアプリの「一般」で有効にし、システム設定で許可されていることを確認する。
2. Custom Dock が表示され、Studio ウィンドウも開いている状態でログアウトする。ゲストに再ログインし、Dock Studio が自動起動するまで待つ。
3. ログイン後、Studio ウィンドウが開かず、前回の状態に従って Custom Dock だけが表示されることを確認する。メニューバーの Dock Studio メニューから Studio ウィンドウを開けることも確認する。
4. 通常起動の対照として、ログイン項目を無効にしてから Dock または Finder で Dock Studio を開く。Studio ウィンドウと Custom Dock が従来どおり表示されることを確認する。
5. 比較用に標準 macOS Dock も撮影する。標準 Dock の画面端での位置、表示または自動非表示の状態、アイコン数、アイコンの大きさ、アイコン間隔、ポインタを端に置いた時の表示動作と拡大動作を記録する。ログイン直後に Studio ウィンドウが表示されていないことが分かる画面も撮る。

保存先は `docs/media/login-launch-dock-only/` にする。次の画像と動画を残す。

- 画像 1: ログイン直後のデスクトップと Custom Dock。Studio ウィンドウが無いことを含める。
- 画像 2: 標準 macOS Dock。手順 5 の位置、アイコン数、大きさ、間隔が分かる状態にする。
- 画像 3: メニューバーから Studio ウィンドウを開いた状態。
- 画像 4: Dock または Finder から通常起動した状態。
- 動画 1: ログアウト、再ログイン、自動起動後に Custom Dock だけが表示されるまでの動き。
- 動画 2: 標準 Dock の自動表示と拡大動作。自動非表示が無効なら、その設定と通常表示を記録する。

## VM 検証（再撮影 2）

2026-10-18 に専用 VM（macOS 26.6.2）で、コミット dd9924a の Release ビルドを確認した。ホストとゲストの実行ファイルの SHA-256 は一致した（039e0ecbd149d21d3b24c010c42c9255b8ff6459f56c4a0b530c587873e5373c）。ログアウトと再ログインは行わず、ログイン項目と同じ形の Apple event（keyAELaunchedAsLogInItem 付き）で起動した。ログは [retake2-logs.txt](media/login-launch-dock-only/retake2-logs.txt) にある。

| 条件 | 結果 |
| --- | --- |
| ログイン風の起動、dockVisible=true | 満たしていない。起動後の約 16 秒は、パネルも Studio ウィンドウも出ず、その後、パネル（layer=21、onscreen=1）と Studio ウィンドウ（layer=0、onscreen=1）が同時に出た（3 回再現） |
| ログイン風の起動、dockVisible=false | 一部のみ。パネルは出なかったが、約 16 秒後に Studio ウィンドウが開いた |
| 通常起動（open -n） | 両方出た。ただし、同じく約 16 秒後だった |

前回の「パネルが出ない」は、観察を 15 秒で止めていたため、約 16 秒の遅れを見ていた可能性がある。ログイン風の起動でも通常起動と同じ時刻に Studio ウィンドウが開くため、Apple event によるウィンドウの抑止は、この VM では効いていない。約 16 秒の遅れの原因は未調査（この VM での起動の遅さか、アプリ内の待ちかは区別できていない）。実際のログイン項目の自動起動、標準 Dock の比較は未確認。
