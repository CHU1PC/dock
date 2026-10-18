# フォルダ内容の Fan 表示

## 変更内容

フォルダを開いたときの表示形式に Fan を追加した。Fan は画面下側にアイコンを弧状に並べて表示し、項目を選ぶと既存の起動処理で開く。表示形式はフォルダごとに `profiles.json` へ保存する。

## 仕様の判断

Apple の[フォルダを Dock で使う案内](https://support.apple.com/en-gb/guide/mac-help/mchl231f08fb/26/mac/26)は、Fan、Grid、List を選べることを説明している。一方、公開ページには Fan の数値上限や配置ごとの制限が記載されていない。

そのため、DockStudio では次の条件を適用する。下配置で8件までなら Fan を表示する。左または右配置では List に切り替え、9件以上でも全項目を開けるよう List に切り替える。フォルダに保存した Fan の選択は残るため、下配置に戻すか項目数を減らすと Fan に戻る。8件という上限は標準 Dock の上限を再現したものではなく、280ポイント幅の表示領域でアイコンが重ならないようにする DockStudio 側の制約になる。

既存プロファイルで表示形式が保存されていないフォルダは List として扱う。表示形式の変更はプロファイルへすぐ保存する。Fan は静的な配置で表示し、アプリまたは macOS のアニメーション低減が有効な場合はビュー内のアニメーションを無効にする。

## 自動テスト結果

ホスト上で指定スクリプトを実行した。アプリの GUI は起動していない。

| 確認 | 結果 |
| --- | --- |
| `/private/tmp/cw/run-check.sh 34 test` | 263件、失敗0件 |
| `/private/tmp/cw/run-check.sh 34 release` | `BUILD SUCCEEDED` |
| `/private/tmp/cw/run-check.sh 34 testbuild` | `TEST BUILD SUCCEEDED` |

Fan の配置計算と8件を超えた場合の扱い、古いフォルダ項目の読み込み、表示形式の保存と再読み込みを単体テストで確認した。

## 未検証

- 専用 macOS VM での Fan 表示、クリック動作、アニメーション低減時の表示を未確認。
- 標準 Dock で実際に Fan を表示できる項目数と、左右配置での選択可否を未測定。Apple の公開資料にも数値と配置条件は記載されていない。
- macOS 15 以降の各バージョンでの表示差を未確認。

実画面の撮影と標準 Dock の比較が必要になる。以下の手順を VM の撮影担当者が実行する。

## 撮影の手順

撮影は専用のヘッドレス macOS VM または検証用 Mac で行う。ホストにアプリや検証画面を表示しない。Dock のデスクトップパネルを撮るときは、インウィンドウプレビューと重ならないように「設定」タブを開く。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-34/Fan Demo` を作り、子項目を8件用意する。アプリ、フォルダ、ファイルを混ぜる。別途9件の子項目を持つ `Fan Overflow` フォルダも用意し、同じプロフィールに追加する。

`/Users/Shared/dockstudio-34/profiles.json` に次の設定を保存する。各 `target` はゲスト内の実在するパスに合わせる。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 52,
    "autoHide": false,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "Fan demo",
      "items": [
        {
          "id": "00000000-0000-0000-0000-000000000034",
          "name": "Fan Demo",
          "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-34/Fan%20Demo/",
          "folderContentsDisplayStyle": "fan"
        },
        {
          "id": "00000000-0000-0000-0000-000000000035",
          "name": "Fan Overflow",
          "kind": "folder",
          "target": "file:///Users/Shared/dockstudio-34/Fan%20Overflow/",
          "folderContentsDisplayStyle": "fan"
        }
      ]
    }
  ]
}
```

ゲストへビルド成果物を置き、次のコマンドで起動する。

```bash
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-34 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

### 操作と標準 Dock の比較

1. DockStudio の下配置 Dock で「Fan Demo」を開く。表示形式メニューで Fan を選び、8件が弧状に並ぶことを確認する。
2. 8件のうち複数をクリックし、それぞれが開くことを確認する。
3. 「Fan Overflow」を開く。9件では List に切り替わり、すべての項目をスクロールして開けることを確認する。
4. DockStudio を左配置と右配置に切り替え、「Fan Demo」を開く。保存された Fan 選択が残った状態で List に切り替わることを確認する。
5. macOS 標準 Dock に同じフォルダを追加する。フォルダを Control キーを押しながらクリックし、内容の表示形式を Fan にする。
6. 標準 Dock の Fan で、1件、8件、9件のフォルダを順に開く。各件数で実際に表示された項目数、スクロールや省略の有無、表示領域からのはみ出し、クリックで開けるかを記録する。
7. 標準 Dock を左と右に配置し、Fan を選べるか、選べる場合は Fan がどの方向へ展開するかを記録する。
8. DockStudio のアニメーション低減を有効にして Fan を開閉する。続けて macOS の「視覚効果を減らす」を有効にして、同じ操作を確認する。

### 期待する結果

- 下配置で8件までなら、フォルダアイコンの上に子項目が弧状に並ぶ。
- Fan の子項目を選ぶと、その項目が開く。
- 9件以上または左右配置では、全項目を扱える List に切り替わる。
- Fan 選択はフォルダごとに保存され、アプリの再起動後も残る。
- アニメーション低減時は Fan の表示切替で追加のアニメーションが起きない。

### 撮影するもの

| 種類 | 内容 |
| --- | --- |
| 画像 | 下配置で8件を Fan 表示した Dock |
| 画像 | 9件のフォルダを List 表示した状態 |
| 画像 | 左配置と右配置で List に切り替わった状態 |
| 画像 | macOS 標準 Dock で Fan 表示した状態 |
| 動画 | DockStudio で Fan を開き、複数項目を開く操作 |
| 動画 | 標準 Dock で件数ごとの Fan 展開を比べる操作 |
| 記録 | 標準 Dock の1件、8件、9件の表示数、スクロール、省略、画面からのはみ出し |
| 記録 | 標準 Dock を左と右に置いたときの Fan 選択と展開方向 |
