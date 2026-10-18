# アプリアイコンへのファイルドロップ

## 仕様

Dock 上のアプリアイコンへファイルをドロップすると、複数のファイルをまとめてそのアプリへ渡す。アプリが未起動の場合はファイルを渡して起動し、起動済みの場合は起動中のアプリへ渡す。ドロップ位置がアプリアイコンの項目領域内にある場合だけこの動作を行う。

アイコンとアイコンの間へのドロップは、従来どおりファイルやフォルダを Dock の項目として追加する。アプリ以外の項目上へのドロップも、項目追加の扱いを維持する。

渡すアプリは既存の `ItemLaunchPolicy` で検証する。参照先が見つからない場合は開かず、読み込んだ項目に付く起動確認も維持する。起動確認でキャンセルした場合は、ファイルを渡さない。起動要求後のエラーは Dock Studio のエラー表示に出す。

## 受け入れ条件との対応

| 条件 | 状況 |
| --- | --- |
| 複数ファイルを対応アプリへまとめて渡せる | 一部のみ。アプリアイコン領域から複数ファイルを渡す処理と振り分けの単体テストを実装した。実画面の確認は VM 撮影担当に依頼する |
| 起動済み・未起動、非対応形式、起動拒否を確認する | 未確認。撮影手順で4ケースを標準 Dock と比較する |
| 読み込んだ項目の確認と既存の起動ポリシーを迂回しない | 満たした。アプリ項目の参照先確認、`ItemLaunchPolicy`、`requiresLaunchConfirmation` による確認を通す |

## 仕様判断

- Dock 全体のドロップ位置を項目のフレームと照合し、アプリ項目のフレーム内だけをアプリへのファイル渡しとして扱う。
- ファイルがアプリの対応形式かどうかは、受け取ったアプリが判断する。アプリがドロップ要求を受け入れない場合は、NSWorkspace が返す起動要求のエラーを表示する。
- 通常のドロップで追加される項目の判定、順序、挿入位置は既存の処理を使う。

## 自動テスト

| 項目 | 結果 |
| --- | --- |
| swift test | 257件すべて成功 |
| Release ビルド | 成功 |
| Debug の build-for-testing | 成功 |

## 未検証

- 標準 macOS Dock と Dock Studio の実機相当の比較は、専用 VM での撮影待ち。
- アプリが起動要求を受け入れた後、個々のファイル形式を拒否したかどうかは NSWorkspace の完了結果だけでは判定できない場合がある。受取アプリの表示とログで確認する。
- macOS 15 以降の OS 差分は未確認。

## 撮影の手順

撮影は専用のヘッドレス macOS VM のゲストで行う。ホストに検証画面を表示しない。標準 macOS Dock と Dock Studio は同じゲスト、同じファイル、同じアプリで比較する。

### 検証用データ

ゲストで `/Users/Shared/dockstudio-30` を作り、次の `profiles.json` を置く。TextEdit と Calculator の実際の場所はゲストの macOS バージョンに合わせて確認する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000001",
  "settings": { "mode": "custom", "position": "bottom", "iconSize": 64, "autoHide": false, "showRunningApps": false },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000001",
      "name": "File drop demo",
      "items": [
        { "id": "00000000-0000-0000-0000-0000000000a1", "name": "TextEdit", "kind": "application", "target": "file:///System/Applications/TextEdit.app/" },
        { "id": "00000000-0000-0000-0000-0000000000a2", "name": "Calculator", "kind": "application", "target": "file:///System/Applications/Calculator.app/" }
      ]
    }
  ]
}
```

ゲストでテスト書類を作る。`supported-a.txt` と `supported-b.txt` には異なる目印の文章を入れる。非対応形式の候補として `unsupported.bin` を作り、TextEdit が開けるかどうかは比較時に観察する。

```sh
mkdir -p /Users/Shared/dockstudio-30
printf 'Drop test A\n' > /Users/Shared/dockstudio-30/supported-a.txt
printf 'Drop test B\n' > /Users/Shared/dockstudio-30/supported-b.txt
printf '\001\002\003\004' > /Users/Shared/dockstudio-30/unsupported.bin
```

アプリは次の形で起動する。

```sh
DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-30 /path/to/DockStudio.app/Contents/MacOS/DockStudio
```

未起動アプリのケースを撮る前に、TextEdit を終了する。起動済みアプリのケースを撮る前に、TextEdit を起動しておく。

### 操作と標準 Dock との比較

以下の各ケースを最初に Dock Studio で実行し、同じ操作を標準 macOS Dock の TextEdit アイコンでも行う。

1. 未起動の TextEdit のアイコンへ `supported-a.txt` と `supported-b.txt` を同時にドロップする。
2. TextEdit が起動したか、2つの書類が両方開いたか、前面化したか、開いた順序がどうなったかを記録する。
3. 起動済みの TextEdit に、同じ2ファイルを同時にドロップする。新しいウィンドウまたはタブの数と、既存ウィンドウが前面になったかを記録する。
4. TextEdit に `unsupported.bin` をドロップする。起動要求の拒否、アプリのエラー、無反応のどれになるかを記録する。
5. 参照先がないアプリ項目でドロップを試す。アイコンの作り方で再現できる場合だけ行い、アプリが起動しないこと、Dock のエラー表示、項目が残ることを記録する。既存の Dock Studio 項目編集から参照先を一時的に変更してもよい。
6. 2つのアプリ項目の間へ `supported-a.txt` をドロップし、従来どおり Dock 項目として追加されることを確認する。

標準 Dock と Dock Studio のそれぞれで、次を記録する。

- ドロップしたファイル名と数、アプリの起動状態
- 受け取ったファイルの数と順序、アプリが前面化したか
- 非対応形式を渡した際のアプリの表示、Dock Studio のエラー表示
- 起動拒否時にアプリが起動したか、渡したファイルが開いたか、Dock 項目が変化したか
- アイコン間へドロップしたときの項目数、順序、挿入位置
- ゲストの macOS バージョンと撮影対象アプリのバージョン

### 撮るもの

- 画像: Dock Studio の複数ファイルドロップ後に、TextEdit で両方の内容が確認できる状態。
- 画像: 起動済み TextEdit へドロップした後の状態。
- 画像: 非対応形式をドロップした後の結果、またはエラー表示。
- 画像: アイコン間へのドロップでファイル項目が追加された Dock。
- 動画: 標準 Dock と Dock Studio で、未起動と起動済みの TextEdit に複数ファイルを渡す操作。
- 動画: 可能なら、アプリ項目の起動拒否または無効な参照先で、エラーと Dock の状態が分かる操作。

管理画面の撮影では、Dock プレビューと重ならない「設定」タブを使う。
