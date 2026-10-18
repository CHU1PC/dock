# ログイン項目がシステム設定で無効になった場合

## 変更内容

利用者がアプリ内でログイン起動を有効にした後、システム設定からログイン項目を無効にした場合に、設定画面でその状態を説明する。アプリ内でログイン起動を解除した場合は、従来どおり通常の無効状態として扱う。

起動時に利用者が有効化した設定を UserDefaults に保存し、`SMAppService.mainApp.status` と組み合わせて状態を判定する。システム設定で無効化された状態と、承認待ちの状態では、システム設定のログイン項目を開くボタンを表示する。

Custom Dock の「全ウィンドウを表示」は既に実装されている。`ApplicationExpose.swift` が調査資料の結論に従い、Accessibility を使って標準 Dock の該当アプリのメニューから「Show All Windows」を選択する。

## 判定

| SMAppService の状態 | 保存した利用者設定 | アプリ内の状態 |
|---|---:|---|
| enabled | 任意 | 有効 |
| requiresApproval | 任意 | 承認待ち |
| notRegistered | 有効 | システム設定で無効 |
| notRegistered | 無効 | 無効 |
| notFound | 任意 | 無効 |

アプリ内の解除操作が成功したときだけ利用者設定を無効にする。登録操作が成功した後にシステム設定で無効化されると、保存値との違いから無効化を判別する。

## 自動テスト

- `LoginRestoreTests.testLoginItemStateDistinguishesIntentionalUnregisterFromSystemDisablement` が、通常の解除、システム設定での無効化、承認待ちを判別する。
- `LoginRestoreTests.testSystemDisablementAfterRegistrationIsPersistedAndExplained` が、有効化後の状態保存と再生成後の案内を確認する。
- `LoginRestoreTests.testIntentionalUnregisterClearsPersistedEnabledPreference` が、アプリ内の解除後に通常の無効状態へ戻ることを確認する。
- `/private/tmp/cw/run-check.sh 61 test` は 382 件成功、失敗 0 件。

## 未検証

画面表示、システム設定からの実際の無効化、macOS のログイン項目設定を開く動作は検証していない。実際のログアウトと再ログインによる自動起動も未確認になる。

## 撮影の手順

専用 macOS VM で確認する場合は、Release ビルドの Dock Studio を起動する。`DOCKSTUDIO_DATA_DIR` に、普段のプロファイルを含む `profiles.json` を置いた一時ディレクトリを指定する。

1. Dock Studio の「設定」タブを開き、「ログイン時に Dock Studio を開く」を有効にする。
2. システム設定の「一般」から「ログイン項目」を開き、Dock Studio を無効にする。
3. Dock Studio の設定タブへ戻り、システム設定で無効になった旨の案内と「システム設定を開く」ボタンが表示されることを確認する。
4. アプリ内でログイン起動を解除し、無効化案内が消えることを確認する。
5. 承認待ち状態を用意できる場合は、同じ設定画面で案内と設定を開くボタンを確認する。

撮影対象は、設定画面でシステム設定による無効化の案内とボタンが見える画像、アプリ内で解除した後の画面、承認待ち画面になる。今回の作業では撮影していない。
