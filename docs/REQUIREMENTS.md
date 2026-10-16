# macOS Dock アプリの要件

## 目的と前提

Dockset を参考に、Apple Dock の配置を切り替えられ、独立した Custom Dock にアプリとウィジェットを置ける macOS アプリを作る。両方の Dock を同じ優先度で扱う。

- 対象は macOS 15 以降とする。
- ソースコードを公開し、署名と公証を済ませたアプリを GitHub Releases で配布する。
- 設定と資格情報は利用者の Mac に保存する。アプリのアカウントは要求しない。
- Dockset の機能と使用感を参考にする。名称、アイコン、画面素材、文言は独自に作る。

## 機能要件

### Apple Dock

- 現在のピン留めアプリとスペーサーを読み取り、名前付きプロファイルとして保存できる。
- プロファイル内の追加、削除、並べ替え、複製、名前変更ができる。
- プロファイルの適用前に現状を退避し、失敗時には復元できる。
- Apple Dock 上で利用者が行った変更を、明示操作または自動保存で取り込める。
- 切り替えではアプリの終了、ウィンドウの移動、最近使用したアプリの変更を行わない。

### Custom Dock

- Apple Dock とは独立した Dock を表示し、両方を併用できる。
- アプリ、ファイル、フォルダ、Web リンク、スペーサー、ウィジェットを追加し、並べ替えられる。
- アプリの起動と前面化、ファイルとフォルダの表示、リンクの起動ができる。
- 実行中アプリ、最小化ウィンドウ、ゴミ箱の表示を個別に設定できる。
- 左、下、右の配置、表示先ディスプレイ、大きさ、外観、自動非表示を設定できる。
- 複数の Custom Dock プロファイルを保存し、切り替えられる。同時表示は一つとする。
- フルスクリーン、Mission Control、ディスプレイの抜き差しでも操作を妨げない。

### 切り替えと保存

- Apple Dock と Custom Dock のプロファイルを個別に選べる。
- メニューバー、グローバルショートカット、Custom Dock 上の操作から切り替えられる。
- macOS の集中モードにプロファイルを結び付けられる。
- プロファイルと設定をエクスポート、インポートできる。
- 外部サービスの資格情報はエクスポート対象から除外する。

### ウィジェット

完成目標には、[Dockset の製品ページ](https://dockset.app/)に掲載された種類を含める。各ウィジェットは小さな表示と、必要に応じた詳細表示を持つ。

| 分野 | 対象 |
| --- | --- |
| 時間と個人情報 | Clock、World Clock、Stopwatch、Countdown、Alarm、Time Progress、Focus Timer、Calendar、Reminders、Sticky Note、Hydration |
| Mac と操作 | Battery、System Activity、Network Activity、Shortcut、AirDrop、Now Playing |
| 外部情報 | Weather、Stock、Watchlist、AI Usage |
| ビジネス | Stripe、Paddle、Shopify |
| 拡張 | 利用者が API の値を表示できる Custom widget |

外部連携は利用者自身のアカウントと最小権限の資格情報を使う。秘密情報は Keychain に保存する。接続解除でローカルの資格情報を削除できる。通信失敗、認証切れ、権限拒否時には原因と再試行方法を表示する。

## 品質と安全性

- Apple Dock の適用は、開始前のバックアップ、適用結果の確認、失敗時の復元を備える。
- 権限は機能を初めて使うときに要求し、拒否されても他の機能を使えるようにする。
- 秘密情報をログ、プロファイル、Git リポジトリに書き込まない。
- アクセシビリティ設定を尊重し、キーボード操作、VoiceOver、透明度低減に対応する。
- 常駐時の CPU とメモリ、ウィジェットの更新頻度を測定し、受け入れ基準を実装前に定める。
- Apple Silicon と Intel Mac の両方を対象にする。各構成で実機確認する。

## 公開までに決める項目

- ソースコードのライセンスを決める。
- Weather と Stock のデータ提供元、利用規約、API 費用を決める。
- AI Usage が対象とするサービスと認証方式を決める。
- 自動更新の方式を決める。初版は GitHub Releases からの手動更新でもよい。

## 参考資料

- [Dockset の構成](https://dockset.app/manual/choose-your-dock-setup)
- [Apple Dock プロファイルの範囲](https://dockset.app/manual/save-switch-dock-layouts-mac)
- [Custom Dock の操作](https://dockset.app/manual/use-custom-docks)
- [Apple の App Sandbox 制限](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)
- [Apple の直接配布ガイド](https://developer.apple.com/documentation/technologyoverviews/distribution)
