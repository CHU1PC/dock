# Dock Studio

Apple Dock の配置管理と、アプリやウィジェットを並べる Custom Dock を開発しています。macOS 15 以降が対象です。

## 現在使える機能

- プロファイルの作成、名前変更、複製、削除、並べ替え、保存ができます。
- アプリ、フォルダ、ファイル、Web リンク、スペーサー、時計、集中タイマーを追加できます。
- デスクトップに独立した Custom Dock を表示できます。メニューバーからもプロファイルを切り替えられます。
- Dock の位置、大きさ、表示先、自動非表示、実行中アプリの表示を設定できます。
- 現在の Apple Dock のピン留めアプリを、Custom Dock のプロファイルとして取り込めます。
- 設定の書き出しと、プロファイルを追加する形での読み込みができます。

プロファイルは「変更を保存」または「保存して使用」で保存します。編集中の内容は、画面やプロファイルを切り替えても残ります。終了時には保存方法を確認し、下書きを残した場合は次回起動時に復元します。設定は変更時に保存し、サイズのスライダーは操作をまとめて保存します。

設定ファイルは `~/Library/Application Support/DockStudio/profiles.json` に保存します。未保存の下書きは、同じ場所の `profiles.json.drafts.json` に保存します。破損したファイルや対応していない形式を読み込んだ場合は、元のファイルを上書きせず保存を停止します。

Apple Dock 自体への配置の適用、集中モード連携、外部サービスのウィジェットは今後実装します。独立した Dock の表示状態と実行中のタイマーは、アプリ終了時にリセットされます。

## Xcode で見る

1. `DockStudio.xcodeproj` を Xcode で開きます。
2. `DockStudio/CustomDockPreview.swift`、`DockStudio/SettingsPreview.swift`、`DockStudio/ProfileEditorPreview.swift` のいずれかを選びます。
3. **Editor > Canvas** を表示します。Canvas が停止中なら **Resume** を押します。
4. 実際のアプリを使うときは、Scheme を **DockStudio > My Mac** にして実行します。
5. 管理画面右上の Dock ボタン、またはメニューバーから、デスクトップに Dock を表示します。

Xcode Preview はメモリ内のデータを使います。Preview 内の編集は実際の設定ファイルに保存されません。

## プロファイルの共有

書き出したファイルには、アプリの識別子、ホームフォルダからの相対パス、Web リンクを保存します。ユーザー名を含む絶対パスは書き出しません。ホームフォルダの外にあるファイルや、移行先にないアプリは、読み込み後に追加し直してください。

読み込み時には対象を一覧で確認します。設定も復元するかどうかを選べます。共有されたプロファイルには、不審なアプリやファイルへの参照が含まれる可能性があります。信頼できるものだけを読み込んでください。読み込んだ項目を開く際も、表示名と実際の対象を確認します。実行ファイルやスクリプトを、通常のファイル項目として起動することはできません。

## ビルドとテスト

Xcode プロジェクトは [project.yml](project.yml)から XcodeGen で生成しています。生成済みの `.xcodeproj` も含めます。

```bash
xcodegen generate
xcodebuild -project DockStudio.xcodeproj -scheme DockStudio -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO build
swift test --scratch-path /tmp/dockstudio-headless-tests
```

Swift Package のテストでは、アプリのエントリーポイントを除いた実コードを読み込みます。管理画面や Dock を表示せず、実際のユーザー設定も読み込まずにテストします。

この設定はローカル開発用です。一般配布するビルドでは Developer ID による署名と公証を行います。

製品の範囲は[要件書](docs/REQUIREMENTS.md)、開発順序は[実装計画](docs/IMPLEMENTATION_PLAN.md)、実施状況は[開発状況](docs/DEVELOPMENT.md)に記載しています。
