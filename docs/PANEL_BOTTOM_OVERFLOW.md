# Custom Dock パネルの下端位置

## 仕様

下配置の `NSPanel` は、8pt の内側余白を持つ。ウィンドウ枠を画面下端より3pt下げることで、Dock 本体の見える領域を下端から5pt離す。既存の3ptのはみ出しは、Dock 本体のはみ出しではなく、内側余白を含む透明なウィンドウ枠の位置である。

左、右、下の配置では、Dock 本体の見える領域が画面内に収まる。下配置の原点は、画面の下端、5pt の間隔、8pt の内側余白から算出する。画面原点が負または非ゼロの場合も同じ計算になる。

## 受け入れ条件との対応

| 条件 | 状況 |
| --- | --- |
| 複数の画面サイズと下、左、右の配置で画面内に収まることを確認する | 満たした。純粋なジオメトリ関数を3画面サイズ、3配置で検証し、内側余白を除いた Dock 本体が画面内にあることを確認した |
| はみ出しが意図したものか判断し、必要なら修正または理由を記録する | 満たした。下配置のウィンドウ枠が3pt下がるのは、8ptの余白を保ち、Dock 本体を下端から5pt離すためである。理由をコードコメントと本書に記録した |

## 自動テストとビルド

2026-10-18 にホストで、GUIを起動せずビルドと単体テストを実行した。

| コマンド | 結果 |
| --- | --- |
| `/private/tmp/cw/run-check.sh 100 test` | `Executed 258 tests, with 0 failures`、`exit=0` |
| `/private/tmp/cw/run-check.sh 100 release` | `BUILD SUCCEEDED`、`exit=0` |
| `/private/tmp/cw/run-check.sh 100 testbuild` | `TEST BUILD SUCCEEDED`、`exit=0` |

`PanelFrameGeometryTests` は、3種類の画面サイズと下、左、右の各配置で、パディングを除く Dock 本体が画面の内側にあることを検証する。下配置では、Dock 本体と画面下端の間隔が5ptになることも検証する。

## 未検証

- 専用 macOS VM で実際にパネルを表示し、Apple Dock と見た目を比較する作業は未実施である。撮影担当が次の手順で確認する。
- Retina を含む実画面のスケールごとの描画は未確認である。自動テストは AppKit のポイント座標を検証する。

## 撮影の手順

撮影担当は専用ヘッドレス macOS VM のゲストで行う。ホストにアプリや VM 画面を表示せず、マウスやキーボードを自動操作しない。撮影中は「設定」タブを開き、ウィンドウ内のプレビューとデスクトップ用パネルが重ならないようにする。

### 検証用データと起動

ゲストで `/Users/Shared/panel-bottom-overflow` を作り、次の `profiles.json` を置く。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": false,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Panel frame check",
      "items": [
        {
          "id": "00000000-0000-0000-0000-0000000000a1",
          "name": "Calculator",
          "kind": "application",
          "target": "file:///System/Applications/Calculator.app/"
        },
        {
          "id": "00000000-0000-0000-0000-0000000000a2",
          "name": "Finder",
          "kind": "application",
          "target": "file:///System/Library/CoreServices/Finder.app/"
        }
      ]
    }
  ]
}
```

게스트に Release 版の `DockStudio.app` を置き、次で起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/panel-bottom-overflow /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と記録

1. 「設定」タブを開き、デスクトップ用 Custom Dock が表示されていることを確認する。
2. 「Dock」設定で下、左、右の位置を順に選び、それぞれの表示を撮影する。画面サイズとスケールは変えず、設定変更後にパネルが落ち着いてから撮影する。
3. Apple Dock を画面下側に設定して表示し、同じ画面で Custom Dock と比較する。必要なら撮影後に Apple Dock を左右にも配置し、それぞれ記録する。
4. 各配置で、画面全体の解像度とスケール、`NSScreen.frame` と `visibleFrame`、Custom Dock の `CGWindowListCopyWindowInfo` の枠を記録する。
5. 画像上で Dock 本体の見える端から画面端までの間隔を測る。下配置では Apple Dock にも同じ測定を行い、Custom Dock の外枠と見える本体の差も記録する。

### 期待する結果と撮影物

- 下配置は Dock 本体が画面内にあり、下端から5pt離れる。透明な余白を含む Custom Dock のウィンドウ枠は画面下端より3pt下がる。
- 左右配置も Dock 本体の見える領域が画面内に収まる。
- Apple Dock と Custom Dock の外枠および見える端の位置関係を測定結果で比較できる。

| 種類 | 内容 |
| --- | --- |
| 画像 | 設定タブを開いた下配置の Custom Dock と Apple Dock |
| 画像 | 左配置と右配置の Custom Dock |
| 画像 | 下配置の Dock 本体と画面下端の間隔が読める拡大画像 |
| 記録 | 各配置の画面サイズ、スケール、画面枠、Custom Dock と Apple Dock のウィンドウ枠、見える端までの距離 |
