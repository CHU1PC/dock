mod appearance;
mod bridge;
mod capture;
mod dock;
mod icons;
mod layout;
mod model;
mod native;
mod native_menu;
mod state;
mod text_input;
mod ui;

use gpui::{prelude::*, *};
use serde_json::json;
use state::StudioState;
use std::time::Duration;
use ui::Workspace;

actions!(dockstudio, [Quit, ToggleDock, ShowSettings]);
#[derive(Clone, PartialEq, Action)]
#[action(namespace = dockstudio, no_json)]
struct SelectProfile {
    id: String,
}
fn menus(snapshot: &model::Snapshot, visible: bool) -> Vec<Menu> {
    vec![
        Menu {
            name: "Dock Studio".into(),
            items: vec![
                MenuItem::action("設定…", ShowSettings),
                MenuItem::action(
                    if visible {
                        "Dock を隠す"
                    } else {
                        "Dock を表示"
                    },
                    ToggleDock,
                ),
                MenuItem::action("終了", Quit),
            ],
        },
        Menu {
            name: "プロファイル".into(),
            items: snapshot
                .document
                .profiles
                .iter()
                .map(|profile| {
                    MenuItem::action(
                        format!(
                            "{}{}",
                            if profile.id == snapshot.document.active_profile_id {
                                "✓ "
                            } else {
                                ""
                            },
                            profile.name
                        ),
                        SelectProfile {
                            id: profile.id.clone(),
                        },
                    )
                })
                .collect(),
        },
    ]
}

fn main() {
    if std::env::args().any(|a| a == "--native-menu-check") {
        native::capture_mode();
        match native_menu::self_check() {
            Ok(()) => println!("Native menu actions passed"),
            Err(error) => {
                eprintln!("{error}");
                std::process::exit(1);
            }
        }
        return;
    }
    if std::env::args().any(|a| a == "--bridge-check") {
        let result = bridge::Bridge::start()
            .and_then(|mut bridge| bridge.request(json!({"action":"snapshot"})));
        match result {
            Ok(snapshot) => println!(
                "Loaded {} profiles; read_only={}",
                snapshot.document.profiles.len(),
                snapshot.read_only
            ),
            Err(error) => {
                eprintln!("{error}");
                std::process::exit(1);
            }
        }
        return;
    }
    let capture = std::env::args().any(|a| a == "--capture");
    if capture {
        if let Err(error) = native::capture_session_ready() {
            eprintln!("{error}");
            std::process::exit(1);
        }
    }
    if capture && std::env::var_os("DOCKSTUDIO_DATA_DIR").is_none() {
        let directory =
            std::env::temp_dir().join(format!("dockstudio-gpui-capture-{}", uuid::Uuid::new_v4()));
        unsafe {
            std::env::set_var("DOCKSTUDIO_DATA_DIR", directory);
        }
    }
    let startup = bridge::Bridge::start().and_then(|mut bridge| {
        let snapshot = bridge.request(json!({"action":"snapshot"}))?;
        Ok((bridge, snapshot))
    });
    let (bridge, snapshot) = match startup {
        Ok(value) => value,
        Err(error) => {
            eprintln!("{error}");
            if !capture {
                native::startup_error(&error);
            }
            std::process::exit(1);
        }
    };
    let capture_failed = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
    let failed = capture_failed.clone();
    Application::new().run(move |cx: &mut App| {
        if capture {
            native::capture_mode();
        }
        text_input::bind_keys(cx);
        let state = cx.new(|cx| StudioState::new(snapshot, bridge, cx));
        let bounds = if capture {
            Bounds::new(point(px(-20000.), px(-20000.)), size(px(1160.), px(820.)))
        } else {
            Bounds::centered(None, size(px(1160.), px(820.)), cx)
        };
        let window = cx
            .open_window(
                WindowOptions {
                    window_bounds: Some(WindowBounds::Windowed(bounds)),
                    focus: !capture,
                    show: !capture,
                    titlebar: Some(TitlebarOptions {
                        title: Some("Dock Studio".into()),
                        ..Default::default()
                    }),
                    window_min_size: Some(size(px(980.), px(720.))),
                    ..Default::default()
                },
                |window, cx| {
                    window.on_window_should_close(cx, move |window, _| {
                        let _ = native::order(window, false);
                        false
                    });
                    cx.new(|cx| Workspace::new(state.clone(), cx))
                },
            )
            .expect("Unable to open the management window");
        state.update(cx, |state, _| state.manager = Some(window.into()));
        let dock = cx
            .open_window(
                WindowOptions {
                    window_bounds: Some(WindowBounds::Windowed(Bounds::new(
                        point(px(-20000.), px(-20000.)),
                        size(px(900.), px(160.)),
                    ))),
                    titlebar: None,
                    focus: false,
                    show: false,
                    kind: WindowKind::PopUp,
                    is_movable: false,
                    is_resizable: false,
                    is_minimizable: false,
                    window_background: WindowBackgroundAppearance::Transparent,
                    ..Default::default()
                },
                |_, cx| cx.new(|cx| dock::DockView::new(state.clone(), false, cx)),
            )
            .expect("Unable to create the Dock panel");
        let status_menu = std::rc::Rc::new(std::cell::RefCell::new(if capture {
            None
        } else {
            Some(native_menu::StatusMenu::new())
        }));
        let initial_entries = native_menu::entries(&state.read(cx).snapshot, false);
        if let Some(status) = status_menu.borrow_mut().as_mut() {
            status.update(&initial_entries);
        }
        let menu_owner = status_menu.clone();
        let mut menu_signature = String::new();
        cx.observe(&state, move |state, cx| {
            let visible = state.read(cx).dock_visible
                && state.read(cx).snapshot.document.settings.mode != "native";
            let snapshot = &state.read(cx).snapshot;
            let signature = format!(
                "{}:{}:{:?}",
                visible,
                snapshot.document.active_profile_id,
                snapshot
                    .document
                    .profiles
                    .iter()
                    .map(|p| (&p.id, &p.name))
                    .collect::<Vec<_>>()
            );
            if menu_signature != signature {
                menu_signature = signature;
                cx.set_menus(menus(snapshot, visible));
                if let Some(status) = menu_owner.borrow_mut().as_mut() {
                    status.update(&native_menu::entries(snapshot, visible));
                }
            }
            let bounds = dock::panel_bounds(snapshot, &state.read(cx).appearance, capture);
            let _ = dock.update(cx, |_, window, _| {
                if let Some(bounds) = bounds {
                    let _ = native::set_frame(window, bounds);
                }
                let _ = native::order(window, visible && bounds.is_some());
                window.refresh();
            });
        })
        .detach();
        let quit_state = state.clone();
        cx.on_action(move |_: &Quit, cx| {
            quit_state.update(cx, |s, cx| {
                s.ask_quit(cx);
            });
        });
        let toggle_state = state.clone();
        cx.on_action(move |_: &ToggleDock, cx| {
            toggle_state.update(cx, |s, cx| {
                s.toggle_dock(cx);
            })
        });
        let settings_state = state.clone();
        cx.on_action(move |_: &ShowSettings, cx| {
            settings_state.update(cx, |s, cx| {
                s.section = 1;
                s.show_manager(cx);
                cx.notify();
            })
        });
        let profile_state = state.clone();
        cx.on_action(move |action: &SelectProfile, cx| {
            profile_state.update(cx, |s, cx| {
                s.request(json!({"action":"activate","id":action.id}), cx)
            })
        });
        cx.bind_keys([KeyBinding::new("cmd-q", Quit, None)]);
        cx.set_menus(menus(&state.read(cx).snapshot, false));
        let poll = state.clone();
        cx.spawn(async move |cx| {
            loop {
                Timer::after(Duration::from_secs(1)).await;
                if poll
                    .update(cx, |s, cx| s.request(json!({"action":"running"}), cx))
                    .is_err()
                {
                    break;
                }
            }
        })
        .detach();
        let command_state = state.clone();
        cx.spawn(async move |cx| {
            let _status_owner = status_menu;
            loop {
                Timer::after(Duration::from_millis(100)).await;
                for command in native_menu::drain() {
                    let _ = command_state.update(cx, |s, cx| match command.as_str() {
                        "settings" => {
                            s.section = 1;
                            s.show_manager(cx);
                            cx.notify();
                        }
                        "toggle" => s.toggle_dock(cx),
                        "quit" => s.ask_quit(cx),
                        value if value.starts_with("profile:") => {
                            s.request(json!({"action":"activate","id":&value[8..]}), cx)
                        }
                        value if value.starts_with("reset:") => {
                            s.sessions.remove(&value[6..]);
                            cx.notify();
                        }
                        _ => (),
                    });
                }
            }
        })
        .detach();
        if capture {
            let capture_state = state.clone();
            cx.spawn(async move |cx| {
                if let Err(error) = capture::run(window, dock, capture_state, cx).await {
                    eprintln!("{error}");
                    failed.store(true, std::sync::atomic::Ordering::Relaxed);
                }
                let _ = cx.update(|cx| cx.quit());
            })
            .detach();
        } else {
            cx.activate(true);
        }
    });
    if capture_failed.load(std::sync::atomic::Ordering::Relaxed) {
        std::process::exit(1);
    }
}
