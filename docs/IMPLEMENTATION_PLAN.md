# macOS Dock アプリの実装計画

## 現行の UI 方針

2026-10-16 に、Custom Dock と管理画面の UI を Rust と GPUI に移す方針が承認された。背景とアイコンを自由に編集し、現在の Mac の Apple Dock に近い外観と操作感を目指す。保存形式と macOS の操作は既存の Swift 処理を引き継ぐ。[具体的な移行計画](GPUI_MIGRATION.md)に実装順序と検証条件を記載した。

## 初期の方針と理由

次の SwiftUI による UI 実装の方針は、GPUI への移行決定によって置き換えられた。保存と権限管理、Apple Dock の安全な制御については引き続き適用する。

[要件](REQUIREMENTS.md)を満たすネイティブ macOS アプリを Swift で作る。設定画面と編集画面には SwiftUI を使い、Custom Dock のウィンドウ制御には AppKit を使う。プロファイルはローカルのバージョン付きデータとして保存し、資格情報は Keychain に分離する。Apple Dock の制御方法は、公開 API の範囲と対象 OS での実測に基づいて技術検証後に確定する。

直接配布では App Sandbox が必須ではない。ただし、Sandbox を外しても Apple Dock の内部形式が将来も使える保証はない。Apple Dock 制御は独立したコンポーネントに閉じ込め、OS 更新ごとに検証する。[Apple の配布設定](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution)

## 工程と完了条件

| 工程 | 実施内容 | 完了条件 |
| --- | --- | --- |
| 0. 技術検証 | macOS 15 以降で Apple Dock の読み取り、適用、復元を試す。Custom Dock の画面端表示と集中モード連携も最小構成で試す。 | 実機で成功と失敗を再現し、対応 OS ごとの制約と代替策を記録する。 |
| 1. 基盤 | Xcode プロジェクト、プロファイル形式、保存、移行、Keychain、設定画面を作る。 | 再起動後も設定が残り、旧形式の読み込み失敗でデータを壊さない。 |
| 2. Apple Dock | 現在の配置から作成、編集、切り替え、変更検知、退避と復元を作る。 | 複数プロファイルを往復でき、適用失敗後に元の配置へ戻せる。 |
| 3. Custom Dock | アプリとファイルの起動、項目編集、複数画面、配置、自動非表示を作る。 | Apple Dock と同時に使え、ログアウト後も同じ設定で起動する。 |
| 4. 操作連携 | メニューバー、ショートカット、集中モード、プロファイルのエクスポートとインポートを作る。 | 三つの入口から同じプロファイルを選べ、復元した設定が再起動後も有効になる。 |
| 5. 基本ウィジェット | Clock、World Clock、Stopwatch、Countdown、Alarm、Time Progress、Focus Timer、Sticky Note、Hydration、Battery、System Activity、Calendar、Reminders、Shortcut、Now Playing を作る。 | 許可・拒否・データなしの状態で表示が崩れず、操作できる。 |
| 6. 拡張ウィジェット | Weather、Stock、Watchlist、AI Usage、Network Activity、AirDrop、Custom widget を作る。 | 各サービスの利用条件と資格情報の扱いを満たし、通信失敗から回復できる。 |
| 7. ビジネス連携 | Stripe、Paddle、Shopify の読み取り専用連携を個別に作る。 | テスト環境と実アカウントで表示値を照合し、接続解除で資格情報を消せる。 |
| 8. 配布 | アクセシビリティ、性能、OS 更新時の回帰、署名、公証、Release 手順を整える。 | クリーンな Mac でダウンロードから初回起動、権限設定、更新まで確認できる。 |

Apple Dock と Custom Dock の基礎は、工程 2 と 3 を同じ公開マイルストーンにまとめる。片方だけが完成した状態を製品の初版とはしない。ウィジェットの種類は工程を分けるが、[要件](REQUIREMENTS.md)にある完成目標から削らない。

## 工程 0 で判断すること

1. Apple Dock の配置を安全に読み取り、適用する経路を特定する。適用前後の差分と、Dock プロセスへの影響を記録する。
2. 設定形式や OS の変更で適用できない場合は、変更前に止める条件を決める。失敗した配置を強制的に適用しない。
3. Custom Dock の表示順、画面端の判定、フルスクリーンと Mission Control での挙動を実機で確認する。
4. Focus filter の `SetFocusFilterIntent` から、保存したプロファイルを選択できる最小構成を確認する。[Apple の Focus API](https://developer.apple.com/documentation/appintents/focus)

## 実装上の境界

- `DockProfileStore` はプロファイルの保存と移行を担当する。
- `NativeDockAdapter` は Apple Dock の読み取り、適用、復元だけを担当する。
- `CustomDockWindowController` は画面とウィンドウの状態を管理する。
- `WidgetProvider` はウィジェットごとの更新、権限、エラー状態を共通の表示へ渡す。
- `IntegrationCredentialStore` は Keychain の読み書きと削除を担当する。

この境界は設計上の役割であり、ファイル名や公開 API を現時点で固定するものではない。

## 検証方法

- プロファイルの保存、移行、エクスポート、インポートは自動テストで確認する。
- Apple Dock の適用と復元は、検証用ユーザー環境で実際の Dock を使って確認する。
- Custom Dock は複数ディスプレイ、解像度変更、フルスクリーン、VoiceOver を実機で確認する。
- 外部連携はモック応答で失敗経路を確認し、各サービスのテスト環境で値を照合する。
- 配布物は署名と公証を検証し、開発環境以外の Mac で起動を確認する。[Apple の公証ガイド](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## 着手順序の理由

Apple Dock の制御と Custom Dock の画面端表示が、製品全体の成立を左右する。そのため工程 0 で両方を検証する。プロファイル保存を先に作ると、切り替えとウィジェットが同じ基盤を使える。外部サービス連携は独立して追加できるので、基本操作が安定した後に進める。
