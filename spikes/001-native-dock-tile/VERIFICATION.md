# 標準 Dock での実機確認

2026-10-17 に macOS 26.5.2、Apple Silicon、Xcode 26.6 で確認した。専用の一時保存先に、仕事とプライベートのプロファイルを用意した。通常の設定と標準 Dock のピン留め、配置、自動非表示の設定は変更していない。

## 確認結果

- 標準 Dock のアイコン枠に、時計と集中タイマーが表示された。
- Dock のコンテキストメニューから、時計とタイマーを切り替えられた。
- 開始、一時停止、再開、リセットを操作できた。
- 別アプリがアクティブな間も、残り時間が 1500 秒から 1497 秒に進んだ。
- 一時停止した残り時間が、2 秒後も 1496 秒のままだった。
- 再開後にカウントダウンが進み、リセットで 25:00 に戻った。
- プロファイルを選ぶと、詳細画面に選択中の名前が反映された。
- 元の profiles.json の SHA-256 が変わらず、drafts.json も作られなかった。
- Dock のアイコンを押すと、詳細画面が開いた。
- 詳細画面を閉じてもプロセスが残り、Dock から再表示できた。
- Dock のメニューから終了できた。検証用アプリは終了した。

右クリックメニューは、Dock の AXShowMenu とメニュー項目の操作で確認した。詳細画面は実際に起動したアプリのアクセシビリティ情報と、画面の画像で確認した。内部モデルを直接変更して結果を作る方法は使っていない。

## 実機確認で見つかった修正

詳細画面を閉じると、試用アプリまで終了していた。applicationShouldTerminateAfterLastWindowClosed を明示し、試用モードでは終了しないようにした。通常起動も、メニューバーと独立した Dock から操作できる常駐アプリとして扱い、ウィンドウを閉じる操作では終了しない。明示的な終了と保存確認は、従来どおり NSApplication.terminate を通る。

修正前の実出力は `1, false` だった。最初の値はウィンドウ数、次の値は閉じた後にアプリが存在するかを表す。

修正後の実出力は `1, true, 0, 1` だった。順に、閉じる前のウィンドウ数、閉じた後のアプリの存在、閉じた後のウィンドウ数、Dock から再表示した後のウィンドウ数を表す。

Sonnet のレビューを 1 回実施した。[レビュー原文](REVIEW_CLOSE.md)に保存した。通常起動への影響の指摘は確認した。通常起動にも MenuBarExtra と独立した Dock があるため、管理画面を閉じても両方の常駐用途を継続する設計に統一した。両方の起動モードの終了条件をテストした。テストの範囲に関する指摘に対して、上記の実機確認の結果を記録した。修正後の再レビューは実施していない。

## テストとビルド

```sh
swift test --scratch-path /tmp/dockstudio-native-final-tests
xcodebuild -quiet -project DockStudio.xcodeproj -scheme DockStudio -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/dockstudio-native-final-derived CODE_SIGNING_ALLOWED=NO build
```

58 件が成功し、失敗は 0 件だった。ビルドの終了コードは 0 だった。追加したテストでは、閉じた後の終了条件と、復帰通知による残り時間の再計算を確認した。

## 画面と動画

[時計](../../docs/media/native-dock-tile/on-dock-clock.png)、[実行中のタイマー](../../docs/media/native-dock-tile/on-dock-running.png)、[コンテキストメニュー](../../docs/media/native-dock-tile/on-dock-menu.png)、[詳細画面](../../docs/media/native-dock-tile/on-dock-detail.png)を、実際に表示した画面から撮影した。

[5 秒の動画](../../docs/media/native-dock-tile/on-dock-countdown.mp4)は、標準 Dock のアイコン枠を実時間で録画し、タイマーの開始とカウントダウンを示す。状態を注入した描画動画ではない。自動非表示で Dock が隠れた録画は採用せず、アイコンの表示を確認できる区間を使用した。

## 確認範囲の限界

この試作の確認を、上記環境で完了した。Mac 自体をスリープさせる操作は、作業中の利用を妨げるため実施していない。代わりに復帰通知の処理と、長時間経過後の再計算を自動テストで確認した。macOS 15 と Intel Mac での動作、および一般配布用の署名と公証は未確認である。一般配布に向けた互換性の確認は別途必要になる。
