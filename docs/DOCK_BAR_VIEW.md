# Dock バーの Core Animation 版（DockBarView）

Core Animation 移行（親 issue #229）の PR D1 になる。下配置の Dock バーを、SwiftUI の `DockBar` の代わりにレイヤー描画の `DockBarView` で出せるようにする。既定は旧バーのままで、フラグを入れたときだけ切り替わる。

## 設計

```
DockStore ── withObservationTracking（CustomDockWindowController.update()）
   │
   ▼
DockBarSnapshotBuilder.make ── DockBarSnapshot（不変）
   │
   ▼
DockBarView.apply(snapshot:minimizedSlots:) ── 構造が変わったときだけレイヤーを作り直す
   ▲
   └ hoveredIndex はこのビューの中だけに持つ。store にも SwiftUI の状態にも出さない
```

| ファイル | 役割 |
|---|---|
| `DockStudio/Services/DockBarRenderer.swift` | フラグの読み取り。下配置のときだけレイヤー版を使うという判定 |
| `DockStudio/Services/DockBarLayout.swift` | 純粋関数。タイル、ホバー判定用の矩形、背景の矩形を求める。背景の見た目（`DockBarBackdropStyle`）とレイヤーを作り直す条件（`DockBarStructure`）もここにある |
| `DockStudio/Services/DockBarView.swift` | レイヤーを持つ `NSView`。タイルごとに `CALayer` を 1 枚持ち、ホバーで `CASpringAnimation` を追加する |
| `DockStudio/Services/CustomDockWindowController.swift` | `update()` の末尾でスナップショットを作って渡す。フラグが無いとき、または下配置でないときは、これまでどおり `NSHostingView` を使う |

寸法は `DockMetrics`（`DockMetricsInput` 経由）、`DockBackdropFit`、`DockAppearance.scale` をそのまま呼ぶ。SwiftUI のバーと同じ式を使うので、アイコンの大きさ、背景の長さと厚みが一致する。

- ホバーの判定は、現在のホバーでの目標レイアウト上のタイルの矩形で行う（補間中の実フレームでは判定しない）。どのタイルの上でもないときは、直前のホバーを保つ。ポインタがビューを出たらホバーを外す。
- バネは SwiftUI の `.spring(response: 0.24, dampingFraction: 0.82)` と同じ値で、質量 1 の `CASpringAnimation`（stiffness 約 685、damping 約 43）にしている。背景の `bounds.size`、`position`、`shadowPath` と、タイルの `bounds.size`、`position` を動かす。
- バーは下端に固定し、ホバーでウィンドウの大きさは変えない。パネルの大きさは、これまでどおり `DockPanelSizing` が最大拡大を含めて決める。
- 透明度低減は `snapshot.reduceMotion`（アプリの設定とシステム設定の和）で見る。有効なときは、アニメーションを付けずに配置する。
- アイコンは `DockIconRenderer.image` の画像を、最大拡大サイズ × 画面の倍率で 1 回だけ `CGImage` にして `layer.contents` に入れる。ホバーでは再描画しない。キャッシュは、画面の倍率、ライトとダーク、アプリの起動と終了で捨てる。
- クリックは、同じタイルで押して離したときに `DockStore.clickItem(_:modifiers:)` を呼ぶ（SwiftUI のバーの `Button` と同じ入口）。修飾キーは離したイベントの `modifierFlags` を渡す。
- アクセシビリティは、タイルごとに `NSAccessibilityElement`（role は button、label は項目名、identifier は `dockbar-tile-<項目の位置>`）を返す。フレームは表示中のレイヤー（presentation layer）に追従する。AX のプレスはクリックと同じ処理を呼ぶ。

## フラグ

保存する設定（`profiles.json`、`appearance.json`）には入れない。`DockAppearance.init(from:)` が未知のキーで失敗するためである。

| 方法 | 値 |
|---|---|
| UserDefaults | キー `dockstudio.useLayerDockBar`（Bool）。`defaults write app.dockstudio.preview dockstudio.useLayerDockBar -bool true` |
| 環境変数 | `DOCKSTUDIO_LAYER_DOCK_BAR=1` |

どちらかが有効ならレイヤー版になる。どちらも無ければ、旧バーのままで挙動は変わらない。フラグはコントローラーの生成時に 1 度だけ読むので、切り替えるにはアプリの再起動が要る。

## 対応する範囲

| 項目 | 状態 |
|---|---|
| 配置 | 下のみ。左と右は旧 SwiftUI バーに戻る |
| 背景 | 透明は塗りと枠線なし。その他は単色の塗り（色 × 不透明度）、白 0.22 × 不透明度の枠線 1pt、影（appleDock は影なし）。角丸 22 の continuous |
| アイコン | `DockIconRenderer` の画像。ファイルの URL を持たない項目、使えない項目は、角丸の下地つきの SF Symbol |
| ホバー拡大 | `DockAppearance.scale` と同じ。Ctrl+Shift の一時拡大は、コントローラーが渡す倍率の有無で反映する |
| クリック | 左クリックのみ |
| アクセシビリティ | タイルの要素のみ |
| 折りたたみ | 自動非表示で畳むときはビューを隠すだけで、スライドと不透明度のアニメーションはない |

## 旧バーに戻らず、描かないもの

次は、後続の PR まで描かない。場所だけは旧バーと同じ幅を確保し、タイルの位置はずれない。

- 実行中の点、バッジ、起動バウンス、注意枠。
- ラベル、区切り線、スペーサーの線、ゴミ箱、リサイズハンドル、最小化ウインドウ、時計、集中タイマー。
- フォルダの Stack 表示（フォルダは通常のフォルダのアイコンになる）。フォルダのクリックは、ポップオーバーではなく `clickItem` の動作になる。
- ドラッグ、ドロップ、コンテキストメニュー、キーボード操作、VoiceOver の細かい対応。
- アクセシビリティ許可の案内のボタン。案内がある間も、旧バーと同じ高さを確保するが、ボタンは出ない。

### 背景の代用

次の背景は、D1 では平らな単色の塗りで代用する。ぼかしやガラスの再現は入れていない。

- `appleDock`（macOS 26 の clear glass）。
- `system` のぼかし（`blur` が有効なときの `NSVisualEffectView` 相当）。
- `image`（画像とそのぼかし）。
- `color` は単色なので、SwiftUI と同じ見た目になる想定（未確認）。

## 自動テスト

`DockStudioTests/DockBarLayoutTests.swift`。

- アイコンの大きさ 16、52、128、拡大の有無、先頭、中央、末尾、ゴミ箱の位置へのホバーで、背景の長さと厚み、タイルの大きさと間隔が、`DockMetrics`（store 版）の値と一致する。
- ホバーで並びが広がる量と、パネルの中央から左右対称に広がること。
- マウスの x 座標からホバーの位置を求める関数（隙間では直前のホバーを保つ）。
- レイヤーを作り直す条件が、項目の識別子の並びとアイコンのキーの変化でだけ変わること。
- バネの係数、背景の見た目、フラグの読み取り。
- `DockBarView` に対するマウスイベントで、ホバー、クリック（修飾キー付き）、別のタイルで離したときはクリックにならないこと、AX の identifier。

## VM での確認（すべて未検証）

この PR では VM を使っていない。次の項目は未検証で、別の担当が確かめる。

- レイヤー版の見た目が SwiftUI 版と一致するか（拡大の前後、背景、枠線、影）。
- ホバー中に背景とアイコンがバネで滑らかに動くか。
- クリックで、アプリが起動または前面化するか。非アクティブなパネルへの最初のクリックが通るか。
- AX で `dockbar-tile-<N>` が見つかり、拡大中にフレームが追従するか。
- 自動非表示、複数ディスプレイ、Ctrl+Shift の一時拡大での挙動。
- macOS 15 での動作（VM は macOS 26）。

### 起動

ゲストに、アプリ項目を含む `profiles.json` を置いたディレクトリ（例 `/Users/Shared/dock-234`）を用意し、位置は下、アイコンサイズは 52 にする。

```
# 旧バー（比較用）
DOCKSTUDIO_DATA_DIR=/Users/Shared/dock-234 /path/to/DockStudio.app/Contents/MacOS/DockStudio

# レイヤー版（環境変数）
DOCKSTUDIO_LAYER_DOCK_BAR=1 DOCKSTUDIO_DATA_DIR=/Users/Shared/dock-234 /path/to/DockStudio.app/Contents/MacOS/DockStudio

# レイヤー版（UserDefaults。解除は defaults delete）
defaults write app.dockstudio.preview dockstudio.useLayerDockBar -bool true
```

### CPU の測り方

spike（`spikes/002-core-animation-dock`）と同じ条件にそろえる。spike の数値は、24 タイル、アイコン 52、拡大 1.8 のスイープで、レイヤー版が約 5%（メインスレッドが 2〜4%）、SwiftUI 版が約 20% である。

1. 同じゲストで、旧バーとレイヤー版を、それぞれ起動する。両者の間でアイコンの数、大きさ、拡大を同じにする。アイテムは 24 個にそろえる。
2. 起動して 10 秒待ち、ポインタをバーから離したまま 30 秒の CPU 時間の増分を取る（待機時の CPU）。
3. ポインタを、バーの左端から右端まで一定の速さで往復させる（spike のスイープと同じ速さと往復数。ゲストのポインタ操作ツールを使う）。60 秒続ける。
4. スイープ中の CPU を測る。プロセスの CPU 時間の増分（`proc_pidinfo` の `PROC_PIDTASKINFO`、spike の `--selftest` と同じ方法）か、`top -pid <pid> -l 60 -s 1` の `%CPU` の平均を使う。メインスレッドの使用率は、`sample <pid> 10` のメインスレッドのうち、アイドル以外の割合で見る。
5. 旧バーとレイヤー版で、待機時、スイープ時の CPU とメインスレッドの使用率を表にし、spike の値と並べる。
6. 同じ条件で `sample` の上位スタックも残す。レイヤー版で `applicationIdentity` や SwiftUI のグラフ更新が見えるなら、ホバーの経路に store が残っている。

結果の目標は、レイヤー版のスイープ CPU が 5% 台であること（spike と同程度）。これはまだ測っておらず、未検証である。
