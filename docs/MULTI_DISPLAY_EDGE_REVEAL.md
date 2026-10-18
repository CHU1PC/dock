# 複数ディスプレイで画面端から Custom Dock を表示する

GitHub issue #53 の実装になる。

## 変更内容

設定の「Custom Dock の配置」に画面の選び方を追加した。「指定画面」は表示先に選んだ画面に固定し、「画面端に追従」はポインタが各画面の Dock 側の表示領域へ入ると、Custom Dock 1つをその画面へ移す。表示先が未接続になったときは、接続中の先頭画面を使う。

自動で隠す設定を有効にすると、画面端に入ったときにその画面で Dock を表示する。画面端の判定とパネル配置は、画面のフレーム、利用可能なフレーム、パネルの大きさ、Dock の位置から計算する純粋な関数に分けた。

## 仕様判断

- Dock を複数画面へ複製せず、アプリ内のパネルは1つだけにする。
- 「指定画面」を既定値にし、既存の設定ファイルでは従来どおり表示先を維持する。
- 「画面端に追従」では表示先の指定を、画面端から離れているときの戻り先として使う。
- 画面の配置、負の座標、解像度が異なる画面を、グローバル座標のフレームで判定する。
- Apple の「ディスプレイごとに個別の操作スペース」設定がオフの場合、標準 Dock はメイン画面だけに表示される。標準 Dock と複数画面で比較する際はこの設定をオンにする。アプリ自身の画面端追従設定は独立している。

## 自動テスト

`DockDisplayGeometry.targetDisplayID` を、実ディスプレイやポインタを使わずに検証する。

- 異なるサイズの上下配置と負の X 座標から、画面端の画面を選ぶ。
- 画面端追従が無効なら、ポインタ位置に関係なく指定画面を選ぶ。
- 左右配置と異なる画面サイズで、左端・右端を選ぶ。
- 指定画面が見つからない場合、接続中の先頭画面へ戻る。

`/private/tmp/cw/run-check.sh 53 test` は、`Executed 258 tests, with 0 failures`、`exit=0` だった。`/private/tmp/cw/run-check.sh 53 release` は `** BUILD SUCCEEDED **`、`exit=0` だった。`/private/tmp/cw/run-check.sh 53 testbuild` は `** TEST BUILD SUCCEEDED **`、`exit=0` だった。

## 未検証

- 専用 macOS VM の複数画面での実表示と画面遷移。
- Separate Spaces のオン・オフによる標準 Dock の差分。
- 画面の抜き差しと解像度変更後の実表示。
- macOS 15 以降の実機差分。

## 撮影の手順

専用のヘッドレス macOS VM で実施する。ゲストに2台のディスプレイを設定し、片方を他方の上または左へ配置する。サイズは異なるものを使い、少なくとも一方の画面のグローバル原点が負になる配置を含める。ホストのデスクトップでは起動・操作しない。

### 検証用データと起動

ゲストで `/Users/Shared/dockstudio-53` を作成し、次を `profiles.json` として保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 52,
    "autoHide": true,
    "revealAnimationDuration": 0.22,
    "launchBounce": true,
    "showRunningApps": false,
    "displayMode": "edgeFollowing",
    "displayID": null
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Multi display edge reveal",
      "items": [
        {
          "id": "00000000-0000-0000-0000-0000000000a1",
          "name": "Calculator",
          "kind": "application",
          "target": "file:///System/Applications/Calculator.app/"
        }
      ]
    }
  ]
}
```

ゲストで次の環境変数を指定し、ビルドした `DockStudio.app` の実行ファイルを起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-53 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と期待結果

1. システム設定の「デスクトップと Dock」から、Mission Control の「ディスプレイごとに個別の操作スペース」をオンにする。標準 Dock が両方の画面に出ることを確認する。
2. Dock Studio の設定で「画面端に追従」と「使用していないときに隠す」を有効にする。Dock の位置を下にする。
3. Dock を隠し、上または左に配置した画面の下端へポインタを移動する。Custom Dock がその画面に表示され、もう一方の画面には複製が出ないことを確認する。
4. Dock が隠れた後、もう一方の画面の下端でも同じ操作をする。Custom Dock が画面間を移動することを確認する。
5. Dock の位置を左、右に変えて、それぞれの画面で同様に端から表示できることを確認する。
6. 「指定画面」に切り替え、表示先に選んだ画面へ固定されることを確認する。
7. 画面の解像度を変更し、位置を上下または左右に変更する。再起動後も動作を確認する。続けて片方を切断・再接続し、残った画面で表示されることを確認する。
8. Separate Spaces をオフにして標準 Dock の表示先を観察し、Custom Dock の動作との差を記録する。

### 撮るもの

- 画像: 異なるサイズで上下に配置した2画面と、それぞれの画面端に表示された Custom Dock。
- 画像: 負の原点になる左配置で表示した Custom Dock。
- 画像: 「画面端に追従」と「指定画面」の設定。
- 動画: 隠れた状態から各ディスプレイの端で呼び出し、1つの Dock が画面間を移動する様子。
- 比較記録: macOS のバージョン、各画面の解像度と配置、Dock の位置、自動表示設定、Separate Spaces の状態、各画面で標準 Dock が表示されるか、ポインタを置いた画面端と Dock が現れるまでの時間。

## 参考

- [Apple: macOS 15 のデスクトップと Dock 設定](https://support.apple.com/guide/mac-help/mchlp1119/15.0/mac/15.0)
- [Apple: macOS 26 のデスクトップと Dock 設定](https://support.apple.com/guide/mac-help/mchlp1119/26/mac/26)
