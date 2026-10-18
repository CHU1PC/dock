# ログイン時は Dock だけを表示する

GitHub issue #86 の実装になる。

## 仕様

- `kAEOpenApplication` の Apple event に `keyAELaunchedAsLogInItem` が付いている場合、Studio ウィンドウを自動で開かない。
- 通常起動では、従来どおり Studio ウィンドウを自動で開く。
- Custom Dock のコントローラは、Studio ウィンドウの表示状態に依存せず、アプリの起動時に作る。ログイン起動でも Dock の復元状態を適用して表示する。
- メニューバーから Studio ウィンドウを開く動作と、前回の Dock 表示状態の復元は既存の実装を使う。
- ログイン起動の判定は `LoginLaunchPolicy.isLoginLaunch(eventID:propertyDataCode:)` に集めた。Apple event のイベント ID と `keyAEPropData` の値から Studio ウィンドウを自動で開くか決める純粋な関数になる。

## 自動テスト

`LoginLaunchPolicyTests` で次を確認した。

- ログイン項目の `kAEOpenApplication` だけを、ログイン起動として判定する。
- マーカーがない通常の `kAEOpenApplication` は、通常起動として判定する。
- 別の Apple event にログイン項目のマーカーが付いても、ログイン起動として扱わない。

ホストで GUI を開かずに実行した結果は、259 件すべて成功した。Release ビルドと `build-for-testing` も成功した。

## 未検証

- 専用 VM での実際のログアウトと再ログイン、およびログイン項目からの起動。
- VM 上で、ログイン起動時に Studio ウィンドウが表示されず、Custom Dock が表示されること。
- Finder と Dock からの通常起動、メニューバーからの Studio ウィンドウ表示、前回の表示状態の復元の実画面。
- macOS 15 の実機での起動順序。

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

## 実画面の確認（専用ヘッドレス VM）

2026-10-18 に、コミット `4dc6a62` の Release ビルドを macOS 26.6.2 の専用ヘッドレス VM で確認した。実行ファイルの SHA-256 は、ホストとゲストで `f90f503d5dce3ca71e46f94350a9fe89ecad7ef032815b210743b8955f2c57a2` と一致した。**ログアウトと再ログインは行っていない**（共有 VM のセッションを切らないため）。代わりに、ゲスト内の小さな Swift ツールで、`NSWorkspace.OpenConfiguration.appleEvent` に、`kAEOpenApplication` と `keyAEPropData = keyAELaunchedAsLogInItem` を付けた Apple event を渡して起動した（ログイン項目の起動と同じイベントの形）。実際のログイン項目の自動起動は、**未確認**である。ログは[logs.txt](media/login-launch-dock-only/logs.txt)にある。

```
## 通常起動（初回）: windows: layer=21 onscreen=1（Custom Dock）; layer=0 onscreen=1（Studio ウィンドウ）; launch-state {"dockVisible":true}
## ログイン項目風の起動（dockVisible が true の状態）:
t~2s..15s: layer=0 onscreen=false x0 y0 w0 h0（Studio ウィンドウなし。Custom Dock のパネルも出ない）
メニュー「Dock を管理…」を押した後: layer=21 onscreen=1 x537 y846 w525 h157 / layer=0 onscreen=1 x260 y122 w1080 h850
```
- 通常起動では、Studio ウィンドウと Custom Dock が従来どおり表示された。
- ログイン項目風の起動では、**Studio ウィンドウは開かなかった**（仕様の前半は満たした）。
- **ただし、Custom Dock のパネルも出なかった**（`launch-state.json` は `dockVisible: true`）。仕様は「ログイン起動でも Dock の復元状態を適用して表示する」だが、15 秒後まで、パネルのウィンドウが現れなかった。メニューの「Dock を管理…」でウィンドウを開くと、パネルも同時に現れた（[動画](media/login-launch-dock-only/login-style-launch.mp4)）。**不具合の疑い**: Studio ウィンドウを開かない起動では、Custom Dock のコントローラが作られていない可能性がある。ただし、この再現は、ログイン項目風の Apple event による起動であり、実際のログイン起動では異なる可能性がある。
- 手順 3 のメニューから Studio を開く動作は確認した。手順 4（ログイン項目を無効にした通常起動の対照）は、通常起動の結果で代えた。標準 Dock の比較（手順 5）は、撮影していない。
