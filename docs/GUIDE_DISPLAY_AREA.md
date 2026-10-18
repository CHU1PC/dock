# Dock の表示領域について

## 仕様

標準 Dock と Custom Dock では、ほかのアプリのウィンドウが使える画面領域の扱いが異なる。標準 Dock は macOS が管理し、表示中は Dock の幅または高さをウィンドウの表示領域から差し引く。Custom Dock は通常のパネルとして表示され、ほかのアプリのための画面領域を予約しない。そのため、最大化やタイル配置をしたウィンドウが Custom Dock の上に重なることがある。

| Dock の状態 | ウィンドウの表示領域 | Custom Dock との関係 |
| --- | --- | --- |
| 標準 Dock を常時表示 | 標準 Dock の分を除いた領域になる | Custom Dock も表示している場合、標準 Dock は避けても Custom Dock には重なることがある |
| 標準 Dock を自動非表示 | Dock が隠れている間は、より広い領域を使う | Custom Dock が表示されていても、その領域は避けない |

この違いは、macOS が画面領域を管理するために公開している API の範囲による。`NSScreen.visibleFrame` は現在の利用可能領域を読み取る API で、他のアプリのウィンドウ向けに領域を予約する API ではない。Dock Studio は標準 Dock の設定を読み書きして自動変更しない。併用時に領域を確保したい場合は、標準 Dock を表示したままにする設定を利用者が選ぶ。Custom Dock の重なりを避ける必要がある場合は、ウィンドウのサイズや位置を調整する。

表示領域の調査では、標準 Dock が画面下部に常時表示された場合、Fill と左側タイルのウィンドウは Dock の高さ分を避けた。自動非表示の場合は、より広い高さで配置された。標準 Dock を自動非表示にして Custom Dock を表示した場合、Fill したウィンドウは Custom Dock のパネルに重なり、パネルが前面に描画された。この観察は `docs/research/WINDOWS_SPACES.md` の Issue #55 に記録されている。今回の変更時には画面を再観察していない。

## 仕様上の判断

- Custom Dock の表示領域は macOS に登録せず、他アプリのウィンドウを動かして避けさせない。
- 標準 Dock を併用し、必要であれば標準 Dock を常時表示する方法を案内する。
- Dock Studio は標準 Dock の自動表示、位置、サイズなどのシステム設定を変更しない。
- Dock の左右配置、複数ディスプレイ、タイルの余白設定、macOS 15 での差は未確認とする。

## 自動テスト結果

この変更は案内文書の追加のみで、アプリのコードとテストは変更していない。ホストではビルドと単体テストだけを実行し、アプリは起動していない。

| 項目 | 結果 |
| --- | --- |
| `swift test` | 336件すべて成功（失敗0） |
| Release ビルド | 成功（`BUILD SUCCEEDED`） |
| Debug の `build-for-testing` | 成功（`TEST BUILD SUCCEEDED`） |

## 未検証

- 今回のブランチでの実画面の挙動は未確認になる。過去の調査記録を今回の検証結果として扱わない。
- 標準 Dock の左右配置、複数ディスプレイ、タイルの余白設定、macOS 15 での挙動は未確認になる。
- Dock Studio が標準 Dock のシステム設定を変更しないことは、今回の画面操作では確認していない。コード上で設定変更を追加していない。

## 撮影の手順

専用のヘッドレス macOS VM または検証用 Mac で撮影する。ホストではアプリを起動しない。ゲストに Release ビルドの `DockStudio.app` を置き、次のプロファイルを `/Users/Shared/dockstudio-display-area/profiles.json` として保存する。

```json
{
  "schemaVersion": 1,
  "activeProfileID": "00000000-0000-0000-0000-000000000121",
  "settings": {
    "mode": "custom",
    "position": "bottom",
    "iconSize": 64,
    "autoHide": false,
    "showRunningApps": false
  },
  "profiles": [
    {
      "id": "00000000-0000-0000-0000-000000000121",
      "name": "Display area guide",
      "items": [
        {
          "id": "00000000-0000-0000-0000-000000000122",
          "name": "Safari",
          "kind": "application",
          "target": "file:///System/Applications/Safari.app/"
        },
        {
          "id": "00000000-0000-0000-0000-000000000123",
          "name": "System Settings",
          "kind": "application",
          "target": "file:///System/Applications/System%20Settings.app/"
        }
      ]
    }
  ]
}
```

ゲストで、アプリを `DOCKSTUDIO_DATA_DIR=/Users/Shared/dockstudio-display-area /path/to/DockStudio.app/Contents/MacOS/DockStudio` として起動する。画面解像度、macOS の版、標準 Dock の位置・表示状態を記録し、Dock Studio 起動前の標準 Dock 設定も控える。

1. Dock Studio の「設定」タブを選び、管理画面内のプレビューがデスクトップ上の Dock と重なって見えないようにする。
2. 標準 Dock を下側で常時表示し、Safari などのウィンドウで Window > Fill と Window > Move & Resize > Left を行う。標準 Dock を避けるウィンドウの位置を記録する。
3. Custom Dock を表示した状態で、Dock Studio の「Custom Dock」タブのプレビューではなくデスクトップ上のパネルを確認する。標準 Dock を常時表示したままの状態と、自動非表示にした状態で Fill と Left を繰り返し、Custom Dock との重なりを記録する。
4. Dock Studio を終了し、標準 Dock の設定が起動前の値から変わっていないか確認する。変更があれば記録し、検証後に元の値へ戻す。
5. 左右に置いた標準 Dock、タイル余白設定の切り替え、複数ディスプレイでも確認する場合は、それぞれ条件と結果を別に記録する。

### 期待する結果

- 標準 Dock が常時表示なら、macOS のウィンドウ配置は標準 Dock の領域を避ける。
- 標準 Dock が自動非表示なら、Dock が隠れた状態でウィンドウがより広い領域を使う。
- Custom Dock はウィンドウの表示領域を予約しないため、Fill やタイル配置したウィンドウと重なることがある。
- Dock Studio の起動と終了によって、標準 Dock のシステム設定が変わらない。

### 撮るもの

| 種類 | 内容 |
| --- | --- |
| 画像 | 標準 Dock 常時表示時の Fill ウィンドウと Dock の位置関係 |
| 画像 | 標準 Dock 自動非表示時の Fill ウィンドウと Custom Dock の重なり |
| 画像 | Custom Dock と左側タイル配置したウィンドウの位置関係 |
| 画像またはログ | Dock Studio 起動前後の標準 Dock 設定と、画面・OS・Dock 配置の記録 |
