# 検証中の失敗記録

以下は修正前のコマンドと出力を、そのまま残したものである。出力に含まれないスタックトレースは生成していない。最終的な検証の結果は [検証記録](VERIFICATION.md) に記載した。

## tests-review-fixes.log

Objective-C のメソッド実装の型指定を修正した。

```sh
cargo test --manifest-path gpui/Cargo.toml --locked -j 2
```

```text
   Compiling objc2 v0.6.5
   Compiling ring v0.17.14
   Compiling objc2-core-foundation v0.3.2
   Compiling rustls-webpki v0.103.15
   Compiling block2 v0.6.2
   Compiling rustls v0.23.46
   Compiling objc2-foundation v0.3.2
   Compiling tokio-rustls v0.26.6
   Compiling hyper-rustls v0.27.10
   Compiling psm v0.1.32
   Compiling zed-reqwest v0.12.15-zed
   Compiling stacker v0.1.25
   Compiling stacksafe v0.1.4
   Compiling gpui_http_client v0.2.2
   Compiling objc2-cloud-kit v0.3.2
   Compiling objc2-core-data v0.3.2
   Compiling objc2-quartz-core v0.3.2
   Compiling objc2-core-image v0.3.2
   Compiling objc2-core-text v0.3.2
   Compiling objc2-core-video v0.3.2
   Compiling objc2-core-graphics v0.3.2
   Compiling gpui v0.2.2
   Compiling objc2-app-kit v0.3.2
   Compiling dockstudio-gpui v0.1.0 (/Users/chu1mac/orca/projects/dock/gpui)
error: implementation of `MethodImplementation` is not general enough
  --> src/native_menu.rs:41:13
   |
41 | /             builder.add_method(
42 | |                 sel!(selected:),
43 | |                 selected as extern "C" fn(&AnyObject, Sel, &AnyObject),
44 | |             );
   | |_____________^ implementation of `MethodImplementation` is not general enough
   |
   = note: `MethodImplementation` would have to be implemented for the type `for<'a, 'b> extern "C" fn(&'a AnyObject, objc2::runtime::Sel, &'b AnyObject)`
   = note: ...but `MethodImplementation` is actually implemented for the type `extern "C" fn(&'0 AnyObject, objc2::runtime::Sel, &AnyObject)`, for some specific lifetime `'0`

error: implementation of `MethodImplementation` is not general enough
  --> src/native_menu.rs:41:13
   |
41 | /             builder.add_method(
42 | |                 sel!(selected:),
43 | |                 selected as extern "C" fn(&AnyObject, Sel, &AnyObject),
44 | |             );
   | |_____________^ implementation of `MethodImplementation` is not general enough
   |
   = note: `MethodImplementation` would have to be implemented for the type `for<'a, 'b> extern "C" fn(&'a AnyObject, objc2::runtime::Sel, &'b AnyObject)`
   = note: ...but `MethodImplementation` is actually implemented for the type `extern "C" fn(&AnyObject, objc2::runtime::Sel, &'0 AnyObject)`, for some specific lifetime `'0`

error: could not compile `dockstudio-gpui` (bin "dockstudio-gpui" test) due to 2 previous errors

```

## tests-review-fixes2.log

GPUI 0.2.2 にある border のスタイル指定へ修正した。

```sh
cargo test --manifest-path gpui/Cargo.toml --locked -j 2
```

```text
   Compiling dockstudio-gpui v0.1.0 (/Users/chu1mac/orca/projects/dock/gpui)
error[E0599]: no method named `outline_2` found for struct `StyleRefinement` in the current scope
  --> src/ui.rs:24:22
   |
24 |         .focus(|s| s.outline_2().outline_color(rgb(0x9cc8ff)))
   |                      ^^^^^^^^^ method not found in `StyleRefinement`

For more information about this error, try `rustc --explain E0599`.
error: could not compile `dockstudio-gpui` (bin "dockstudio-gpui" test) due to 1 previous error

```

## tests-review-fixes3.log

runningItemIDs の JSON 名を明示した。修正後の 17 テストは成功した。

```sh
cargo test --manifest-path gpui/Cargo.toml --locked -j 2
```

```text
   Compiling dockstudio-gpui v0.1.0 (/Users/chu1mac/orca/projects/dock/gpui)
warning: fields `running_identities` and `running_items` are never read
  --> src/model.rs:74:9
   |
58 | pub struct Snapshot {
   |            -------- fields in this struct
...
74 |     pub running_identities: Vec<String>,
   |         ^^^^^^^^^^^^^^^^^^
75 |     pub running_items: Vec<Item>,
   |         ^^^^^^^^^^^^^
   |
   = note: `Snapshot` has derived impls for the traits `Debug` and `Clone`, but these are intentionally ignored during dead code analysis
   = note: `#[warn(dead_code)]` (part of `#[warn(unused)]`) on by default

warning: `dockstudio-gpui` (bin "dockstudio-gpui" test) generated 1 warning
    Finished `test` profile [unoptimized + debuginfo] target(s) in 12.99s
warning: the following packages contain code that will be rejected by a future version of Rust: block v0.1.6, proc-macro-error2 v2.0.1
note: to see what the problems were, use the option `--future-incompat-report`, or run `cargo report future-incompatibilities --id 1`
     Running unittests src/main.rs (gpui/target/debug/deps/dockstudio_gpui-8734cbc065be0d06)

running 14 tests
test icons::tests::glass_retains_a_visible_silhouette ... ok
test dock::tests::magnification_falls_off_symmetrically ... ok
test icons::tests::monochrome_preserves_alpha_and_uses_equal_channels ... ok
test icons::tests::styles_preserve_transparent_pixels ... ok
test appearance::tests::malformed_values_are_rejected ... ok
test layout::tests::autohide_respects_reveal_and_interaction ... ok
test layout::tests::hit_region_excludes_empty_viewport ... ok
test layout::tests::viewport_is_bounded_and_reserves_magnification ... ok
test state::tests::focus_timer_recovers_after_sleep_and_restarts ... ok
test appearance::tests::missing_fields_use_compatible_defaults ... ok
test bridge::session_tests::two_helpers_cannot_edit_the_same_directory ... FAILED
test bridge::tests::corrupt_data_is_preserved_and_cannot_be_saved ... FAILED
test bridge::tests::native_bridge_preserves_profiles_drafts_settings_and_reload ... FAILED
test bridge::tests::undo_removal_preserves_identity_and_order ... FAILED

failures:

---- bridge::session_tests::two_helpers_cannot_edit_the_same_directory stdout ----

thread 'bridge::session_tests::two_helpers_cannot_edit_the_same_directory' (299502490) panicked at src/bridge.rs:192:74:
called `Result::unwrap()` on an `Err` value: "Invalid bridge response: missing field `runningItemIds` at line 1 column 12629"

---- bridge::tests::corrupt_data_is_preserved_and_cannot_be_saved stdout ----

thread 'bridge::tests::corrupt_data_is_preserved_and_cannot_be_saved' (299502491) panicked at src/bridge.rs:164:69:
called `Result::unwrap()` on an `Err` value: "Invalid bridge response: missing field `runningItemIds` at line 1 column 13027"
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace

---- bridge::tests::native_bridge_preserves_profiles_drafts_settings_and_reload stdout ----

thread 'bridge::tests::native_bridge_preserves_profiles_drafts_settings_and_reload' (299502492) panicked at src/bridge.rs:131:68:
called `Result::unwrap()` on an `Err` value: "Invalid bridge response: missing field `runningItemIds` at line 1 column 12677"

---- bridge::tests::undo_removal_preserves_identity_and_order stdout ----

thread 'bridge::tests::undo_removal_preserves_identity_and_order' (299502493) panicked at src/bridge.rs:174:68:
called `Result::unwrap()` on an `Err` value: "Invalid bridge response: missing field `runningItemIds` at line 1 column 12677"


failures:
    bridge::session_tests::two_helpers_cannot_edit_the_same_directory
    bridge::tests::corrupt_data_is_preserved_and_cannot_be_saved
    bridge::tests::native_bridge_preserves_profiles_drafts_settings_and_reload
    bridge::tests::undo_removal_preserves_identity_and_order

test result: FAILED. 10 passed; 4 failed; 0 ignored; 0 measured; 0 filtered out; finished in 1.90s

error: test failed, to rerun pass `--bin dockstudio-gpui`

```

## capture-reviewed.log

NSWindow の titlebar を含む寸法と比較していたため、NSView の寸法との比較へ修正した。

```sh
bash gpui/scripts/capture.sh /tmp/dockstudio-gpui-capture-reviewed
```

```text
   Compiling dockstudio-gpui v0.1.0 (/Users/chu1mac/orca/projects/dock/gpui)
    Finished `dev` profile [unoptimized + debuginfo] target(s) in 11.57s
warning: the following packages contain code that will be rejected by a future version of Rust: block v0.1.6, proc-macro-error2 v2.0.1
note: to see what the problems were, use the option `--future-incompat-report`, or run `cargo report future-incompatibilities --id 1`
Viewport mismatch: native=1160x852, GPUI=1160x820
[in#0 @ 0xbf6810000] Could find no file or sequence with path '/tmp/dockstudio-gpui-capture-reviewed/frames/frame-%03d.png' and index in the range 0-4
[in#0 @ 0xbf6808000] Error opening input: No such file or directory
Error opening input file /tmp/dockstudio-gpui-capture-reviewed/frames/frame-%03d.png.
Error opening input files: No such file or directory

```

## capture-retry3.log

旧ビルドでも撮影が失敗した。システム情報で画面ロックを確認した。ロック中は撮影を開始せず、理由を表示するようにした。

```sh
DOCKSTUDIO_DATA_DIR=/tmp/dockstudio-gpui-data-retry3 DOCKSTUDIO_CAPTURE_DIR=/tmp/dockstudio-gpui-capture-retry3 gpui/target/debug/dockstudio-gpui --capture
```

```text
Screenshot failed for window 217888 (visible=true, frame=CGRect { origin: CGPoint { x: 0.0, y: 198.0 }, size: CGSize { width: 1160.0, height: 852.0 } }): could not create image from window


```
