use crate::{
    appearance::{Background, IconStyle},
    dock::DockView,
    model::Item,
    state::StudioState,
};
use gpui::{prelude::*, *};
use serde_json::json;

const BASE: u32 = 0x191b20;
const PANEL: u32 = 0x24272e;
const TEXT: u32 = 0xe9ebef;
const MUTED: u32 = 0x969da9;

pub fn button(
    id: impl Into<SharedString>,
    label: impl Into<SharedString>,
    selected: bool,
    action: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static,
) -> Stateful<Div> {
    div()
        .id(ElementId::Name(id.into()))
        .tab_index(0)
        .border_2()
        .border_color(rgba(0x00000000))
        .focus(|s| s.border_color(rgb(0x9cc8ff)))
        .px_3()
        .py_2()
        .rounded_lg()
        .text_sm()
        .cursor_pointer()
        .bg(rgb(if selected { 0x38557a } else { 0x30343d }))
        .text_color(rgb(TEXT))
        .hover(|s| s.bg(rgb(0x465363)))
        .on_click(action)
        .child(label.into())
}
fn heading(title: &str, subtitle: &str) -> Div {
    div()
        .flex()
        .flex_col()
        .gap_2()
        .mb_5()
        .child(
            div()
                .text_2xl()
                .font_weight(FontWeight::SEMIBOLD)
                .child(title.to_owned()),
        )
        .child(
            div()
                .text_sm()
                .text_color(rgb(MUTED))
                .child(subtitle.to_owned()),
        )
}
fn row(label: &str, controls: impl IntoElement) -> Div {
    div()
        .flex()
        .items_center()
        .justify_between()
        .gap_4()
        .py_3()
        .border_b_1()
        .border_color(rgb(0x353941))
        .child(div().text_sm().child(label.to_owned()))
        .child(controls)
}
fn card(title: &str, content: impl IntoElement) -> Div {
    div()
        .flex()
        .flex_col()
        .gap_3()
        .p_5()
        .rounded_xl()
        .bg(rgb(PANEL))
        .child(
            div()
                .text_base()
                .font_weight(FontWeight::SEMIBOLD)
                .child(title.to_owned()),
        )
        .child(content)
}

pub struct Workspace {
    pub state: Entity<StudioState>,
    preview: Entity<DockView>,
    settings_scroll: ScrollHandle,
    focus_handle: FocusHandle,
}
impl Workspace {
    pub fn new(state: Entity<StudioState>, cx: &mut Context<Self>) -> Self {
        cx.observe(&state, |_, _, cx| cx.notify()).detach();
        let preview = cx.new(|cx| DockView::new(state.clone(), true, cx));
        Self {
            state,
            preview,
            settings_scroll: ScrollHandle::new(),
            focus_handle: cx.focus_handle().tab_index(0).tab_stop(false),
        }
    }
    pub fn capture_scroll(&self, offset: f32) {
        self.settings_scroll.set_offset(point(px(0.), px(offset)));
    }
    pub fn capture_hover(&mut self, index: Option<usize>, cx: &mut Context<Self>) {
        self.preview
            .update(cx, |view, cx| view.capture_hover(index, cx));
        cx.notify();
    }
    fn request_button(&self, id: &str, label: &str, request: serde_json::Value) -> Stateful<Div> {
        let state = self.state.clone();
        button(id.to_owned(), label.to_owned(), false, move |_, _, cx| {
            state.update(cx, |s, cx| s.request(request.clone(), cx))
        })
    }
    fn preview_page(&self, cx: &mut Context<Self>) -> Div {
        let state = self.state.read(cx);
        let visible = state.dock_visible;
        let name = state.snapshot.active_profile().name.clone();
        let entity = self.state.clone();
        div()
            .flex()
            .flex_col()
            .gap_4()
            .size_full()
            .child(heading(
                "Custom Dock",
                "Apple Dock に馴染む外観と、自由に編集できるウィジェット。",
            ))
            .child(
                div()
                    .flex()
                    .items_center()
                    .justify_between()
                    .child(
                        div()
                            .text_sm()
                            .text_color(rgb(MUTED))
                            .child(format!("使用中：{name}")),
                    )
                    .child(button(
                        "visibility",
                        if visible {
                            "Dock を隠す"
                        } else {
                            "Dock を表示"
                        },
                        visible,
                        move |_, _, cx| {
                            entity.update(cx, |s, cx| {
                                s.toggle_dock(cx);
                            })
                        },
                    )),
            )
            .child(
                div()
                    .relative()
                    .flex_1()
                    .rounded_2xl()
                    .overflow_hidden()
                    .bg(rgb(0x314451))
                    .child(self.preview.clone()),
            )
            .child(div().text_sm().text_color(rgb(MUTED)).child(
                "アイコンにポインタを重ねて拡大。右クリックから設定とプロファイルを開けます。",
            ))
    }
    fn settings_page(&self, cx: &mut Context<Self>) -> impl IntoElement {
        let state = self.state.read(cx);
        let settings = state.snapshot.document.settings.clone();
        let appearance = state.appearance.clone();
        let mut modes = div().flex().gap_2();
        for (mode, label) in [
            ("native", "Apple Dock"),
            ("custom", "Custom Dock"),
            ("both", "両方"),
        ] {
            let entity = self.state.clone();
            modes = modes.child(button(
                format!("mode-{mode}"),
                label,
                settings.mode == mode,
                move |_, _, cx| {
                    entity.update(cx, |s, cx| s.change_settings(|v| v.mode = mode.into(), cx))
                },
            ));
        }
        let mut position = div().flex().gap_2();
        for (id, label) in [("left", "左"), ("bottom", "下"), ("right", "右")] {
            let entity = self.state.clone();
            position = position.child(button(
                format!("position-{id}"),
                label,
                settings.position == id,
                move |_, _, cx| {
                    entity.update(cx, |s, cx| {
                        s.change_settings(|v| v.position = id.into(), cx)
                    })
                },
            ));
        }
        let main = self.state.clone();
        let mut displays = div().flex().gap_2().flex_wrap().child(button(
            "display-main",
            "メインに追従",
            settings.display_id.is_none(),
            move |_, _, cx| {
                main.update(cx, |s, cx| s.change_settings(|v| v.display_id = None, cx));
            },
        ));
        if let Some(id) = settings.display_id {
            if !state.snapshot.displays.iter().any(|d| d.id == id) {
                displays = displays.child(
                    div()
                        .text_sm()
                        .child(format!("未接続のディスプレイ ({id})")),
                );
            }
        }
        for display in &state.snapshot.displays {
            let id = display.id;
            let entity = self.state.clone();
            displays = displays.child(button(
                format!("display-{id}"),
                display.name.clone(),
                settings.display_id == Some(id),
                move |_, _, cx| {
                    entity.update(cx, |s, cx| {
                        s.change_settings(|v| v.display_id = Some(id), cx)
                    })
                },
            ));
        }
        let size_value = settings.icon_size;
        let small = self.state.clone();
        let large = self.state.clone();
        let size_controls = div()
            .flex()
            .items_center()
            .gap_3()
            .child(button("size-less", "−", false, move |_, _, cx| {
                small.update(cx, |s, cx| {
                    s.change_settings(|v| v.icon_size = (v.icon_size - 4.0).max(40.0), cx)
                })
            }))
            .child(format!("{size_value:.0} px"))
            .child(button("size-more", "＋", false, move |_, _, cx| {
                large.update(cx, |s, cx| {
                    s.change_settings(|v| v.icon_size = (v.icon_size + 4.0).min(76.0), cx)
                })
            }));
        let auto = self.state.clone();
        let running = self.state.clone();
        let placement = card(
            "配置と動作",
            div()
                .flex()
                .flex_col()
                .child(row("使用する Dock", modes))
                .child(row("画面の位置", position))
                .child(row("表示先", displays))
                .child(row("アイコンの大きさ", size_controls))
                .child(row(
                    "自動的に隠す",
                    button(
                        "auto-hide",
                        if settings.auto_hide {
                            "オン"
                        } else {
                            "オフ"
                        },
                        settings.auto_hide,
                        move |_, _, cx| {
                            auto.update(cx, |s, cx| {
                                s.change_settings(|v| v.auto_hide = !v.auto_hide, cx)
                            })
                        },
                    ),
                ))
                .child(row(
                    "実行中アプリを追加表示",
                    button(
                        "running-apps",
                        if settings.show_running_apps {
                            "オン"
                        } else {
                            "オフ"
                        },
                        settings.show_running_apps,
                        move |_, _, cx| {
                            running.update(cx, |s, cx| {
                                s.change_settings(
                                    |v| v.show_running_apps = !v.show_running_apps,
                                    cx,
                                )
                            })
                        },
                    ),
                )),
        );
        let mut backgrounds = div().flex().gap_2();
        for (mode, label, id) in [
            (Background::System, "システム", "system"),
            (Background::Color, "単色", "color"),
            (Background::Image, "画像", "image"),
            (Background::Transparent, "完全透明", "transparent"),
        ] {
            let entity = self.state.clone();
            backgrounds = backgrounds.child(button(
                format!("background-{id}"),
                label,
                appearance.background == mode,
                move |_, _, cx| {
                    entity.update(cx, |s, cx| {
                        let mut a = s.appearance.clone();
                        a.background = mode;
                        s.save_appearance(a, cx)
                    })
                },
            ));
        }
        let less = self.state.clone();
        let more = self.state.clone();
        let blur = self.state.clone();
        let opacity = div()
            .flex()
            .items_center()
            .gap_3()
            .child(button("opacity-less", "−", false, move |_, _, cx| {
                less.update(cx, |s, cx| {
                    let mut a = s.appearance.clone();
                    a.opacity = (a.opacity - 0.1).max(0.0);
                    s.save_appearance(a, cx)
                })
            }))
            .child(format!("{:.0}%", appearance.opacity * 100.0))
            .child(button("opacity-more", "＋", false, move |_, _, cx| {
                more.update(cx, |s, cx| {
                    let mut a = s.appearance.clone();
                    a.opacity = (a.opacity + 0.1).min(1.0);
                    s.save_appearance(a, cx)
                })
            }));
        let color = self.state.clone();
        let color_input = div()
            .flex()
            .gap_2()
            .w(px(240.))
            .child(state.color_input.clone())
            .child(button("color-apply", "適用", false, move |_, _, cx| {
                color.update(cx, |s, cx| {
                    let text = s.color_input.read(cx).content.to_string();
                    match u32::from_str_radix(text.trim().trim_start_matches('#'), 16) {
                        Ok(value)
                            if value <= 0xffffff
                                && text.trim().trim_start_matches('#').len() == 6
                                && text
                                    .trim()
                                    .trim_start_matches('#')
                                    .bytes()
                                    .all(|b| b.is_ascii_hexdigit()) =>
                        {
                            let mut a = s.appearance.clone();
                            a.color = value;
                            s.save_appearance(a, cx)
                        }
                        _ => {
                            s.error = Some("Enter a six-digit RGB color.".into());
                            cx.notify();
                        }
                    }
                })
            }));
        let background = card(
            "Dock の背景",
            div()
                .flex()
                .flex_col()
                .child(row("背景", backgrounds))
                .child(row("色", color_input))
                .child(row("不透明度", opacity))
                .child(row(
                    "背景をぼかす",
                    button(
                        "blur",
                        if appearance.blur { "オン" } else { "オフ" },
                        appearance.blur,
                        move |_, _, cx| {
                            blur.update(cx, |s, cx| {
                                let mut a = s.appearance.clone();
                                a.blur = !a.blur;
                                s.save_appearance(a, cx)
                            })
                        },
                    ),
                ))
                .child(row(
                    "背景画像",
                    self.request_button(
                        "choose-background",
                        "画像を選ぶ…",
                        json!({"action":"background"}),
                    ),
                ))
                .child(
                    div().pt_3().text_xs().text_color(rgb(MUTED)).child(
                        appearance
                            .image
                            .clone()
                            .unwrap_or_else(|| "画像を選ぶと Dock の背景に適用します。".into()),
                    ),
                ),
        );
        let mut styles = div().flex().gap_2();
        for (style, label, id) in [
            (IconStyle::Original, "通常", "original"),
            (IconStyle::Monochrome, "白黒", "monochrome"),
            (IconStyle::Glass, "ガラス調", "glass"),
        ] {
            let entity = self.state.clone();
            styles = styles.child(button(
                format!("icon-{id}"),
                label,
                appearance.icon_style == style,
                move |_, _, cx| {
                    entity.update(cx, |s, cx| {
                        let mut a = s.appearance.clone();
                        a.icon_style = style;
                        s.save_appearance(a, cx)
                    })
                },
            ));
        }
        let mag = self.state.clone();
        let dots = self.state.clone();
        let motion = self.state.clone();
        let icons = card(
            "アイコンと動き",
            div()
                .flex()
                .flex_col()
                .child(row("アイコンの表現", styles))
                .child(row(
                    "ホバーで拡大",
                    button(
                        "magnify",
                        if appearance.magnification {
                            "オン"
                        } else {
                            "オフ"
                        },
                        appearance.magnification,
                        move |_, _, cx| {
                            mag.update(cx, |s, cx| {
                                let mut a = s.appearance.clone();
                                a.magnification = !a.magnification;
                                s.save_appearance(a, cx)
                            })
                        },
                    ),
                ))
                .child(row(
                    "起動中の点",
                    button(
                        "dots",
                        if appearance.running_indicators {
                            "オン"
                        } else {
                            "オフ"
                        },
                        appearance.running_indicators,
                        move |_, _, cx| {
                            dots.update(cx, |s, cx| {
                                let mut a = s.appearance.clone();
                                a.running_indicators = !a.running_indicators;
                                s.save_appearance(a, cx)
                            })
                        },
                    ),
                ))
                .child(row(
                    "動きを減らす",
                    button(
                        "motion",
                        if appearance.reduce_motion {
                            "オン"
                        } else {
                            "オフ"
                        },
                        appearance.reduce_motion,
                        move |_, _, cx| {
                            motion.update(cx, |s, cx| {
                                let mut a = s.appearance.clone();
                                a.reduce_motion = !a.reduce_motion;
                                s.save_appearance(a, cx)
                            })
                        },
                    ),
                )),
        );
        div()
            .id("settings-scroll")
            .track_scroll(&self.settings_scroll)
            .overflow_y_scroll()
            .flex()
            .flex_col()
            .gap_5()
            .size_full()
            .child(heading(
                "設定",
                "Dock の背景、アイコン、表示方法を調整します。",
            ))
            .child(placement)
            .child(background)
            .child(icons)
            .child(card(
                "バックアップ",
                div()
                    .flex()
                    .gap_3()
                    .child(self.request_button("export", "書き出す…", json!({"action":"export"})))
                    .child(self.request_button("import", "読み込む…", json!({"action":"import"})))
                    .child(self.request_button(
                        "native-import",
                        "Apple Dock から取り込む",
                        json!({"action":"nativeImport"}),
                    )),
            ))
    }
    fn profiles_page(&self, cx: &mut Context<Self>) -> Div {
        let state = self.state.read(cx);
        let snapshot = state.snapshot.clone();
        let dirty = snapshot.has_unsaved_changes
            || state.name_input.read(cx).content.as_ref() != snapshot.editor_profile.name;
        let mut profiles = div().flex().flex_col().gap_2();
        for profile in &snapshot.document.profiles {
            let mut label = profile.name.clone();
            if profile.id == snapshot.document.active_profile_id {
                label.push_str("  ✓");
            }
            let entity = self.state.clone();
            let id = profile.id.clone();
            profiles = profiles.child(button(
                format!("profile-{id}"),
                label,
                id == snapshot.editor_profile.id,
                move |_, _, cx| {
                    entity.update(cx, |s, cx| {
                        s.request(json!({"action":"select","id":id}), cx)
                    })
                },
            ));
        }
        let mut items = div()
            .id("items-scroll")
            .overflow_y_scroll()
            .flex()
            .flex_col()
            .flex_1();
        for item in &snapshot.editor_profile.items {
            let entity = self.state.clone();
            let id = item.id.clone();
            let selected = state.selected_item.as_ref() == Some(&id);
            let icon = snapshot
                .icons
                .get(&id)
                .map(|path| {
                    img(std::path::PathBuf::from(path))
                        .size(px(34.))
                        .into_any_element()
                })
                .unwrap_or_else(|| {
                    div()
                        .size(px(34.))
                        .child(item_symbol(item))
                        .into_any_element()
                });
            items = items.child(
                div()
                    .id(ElementId::Name(format!("item-{id}").into()))
                    .tab_index(0)
                    .focus(|s| s.bg(rgb(0x38557a)))
                    .flex()
                    .items_center()
                    .gap_3()
                    .p_3()
                    .rounded_lg()
                    .bg(rgb(if selected { 0x344966 } else { PANEL }))
                    .cursor_pointer()
                    .on_click(move |_, _, cx| {
                        entity.update(cx, |s, cx| {
                            s.selected_item = Some(id.clone());
                            cx.notify();
                        })
                    })
                    .child(icon)
                    .child(
                        div()
                            .flex()
                            .flex_col()
                            .gap_1()
                            .child(item.name.clone())
                            .child(div().text_xs().text_color(rgb(MUTED)).child(
                                match item.kind.as_str() {
                                    "application" => "アプリ",
                                    "file" => "ファイル",
                                    "folder" => "フォルダ",
                                    "link" => "リンク",
                                    "clock" => "時計",
                                    "focusTimer" => "集中タイマー",
                                    _ => "区切り",
                                },
                            )),
                    ),
            );
        }
        let mut additions = div().flex().gap_2().flex_wrap();
        for (kind, label) in [
            ("application", "アプリ"),
            ("folder", "フォルダ"),
            ("file", "ファイル"),
            ("spacer", "区切り"),
            ("clock", "時計"),
            ("focusTimer", "集中タイマー"),
        ] {
            additions = additions.child(self.request_button(
                &format!("add-{kind}"),
                label,
                json!({"action":"add","kind":kind}),
            ));
        }
        let mut editing = div().flex().gap_2();
        if let Some(id) = &state.selected_item {
            editing = editing
                .child(self.request_button(
                    "move-up",
                    "↑",
                    json!({"action":"move","id":id,"offset":-1}),
                ))
                .child(self.request_button(
                    "move-down",
                    "↓",
                    json!({"action":"move","id":id,"offset":1}),
                ))
                .child(self.request_button("remove", "削除", json!({"action":"remove","id":id})));
        }
        if snapshot.can_undo_removal {
            editing = editing.child(self.request_button(
                "undo",
                "削除を取り消す",
                json!({"action":"undo"}),
            ));
        }
        let name_input = state.name_input.clone();
        let link_name = state.link_name.clone();
        let link_url = state.link_url.clone();
        let entity = self.state.clone();
        div().flex().gap_5().size_full()
            .child(div().flex().flex_col().gap_3().w(px(200.)).flex_shrink_0().child(div().text_lg().child("プロファイル")).child(profiles)
                .child(self.request_button("create","＋ 新規作成",json!({"action":"create"})))
                .child(self.request_button("duplicate","複製",json!({"action":"duplicate"})))
                .child(self.request_button("delete-profile","プロファイルを削除",json!({"action":"delete"}))))
            .child(div().flex().flex_col().gap_4().flex_1().child(heading("プロファイル編集","アプリとウィジェットを並べ、用途ごとに保存します。"))
                .child(name_input).child(div().text_xs().text_color(rgb(MUTED)).child(if dirty{"未保存の変更があります"}else{"保存済み"}))
                .child(items).child(editing).child(additions)
                .child(div().flex().gap_2().child(link_name).child(link_url).child(button("add-link","リンクを追加",false,move |_,_,cx|entity.update(cx,|s,cx|{
                    if s.link_pending {return;}
                    let name=s.link_name.read(cx).content.trim().to_string();let url=s.link_url.read(cx).content.trim().to_string();
                    if name.is_empty() || !(url.starts_with("https://") || url.starts_with("http://")) || url.split_once("://").is_none_or(|(_,host)| host.is_empty() || host.starts_with('/')) {
                        s.error=Some("Enter a name and a valid HTTP or HTTPS URL.".into()); cx.notify(); return;
                    }
                    s.link_pending=true;
                    s.request(json!({"action":"add","kind":"link","name":name,"target":url}),cx)
                }))))
                .child(div().flex().gap_3().justify_end()
                    .child(self.request_button("save","変更を保存",json!({"action":"save"})))
                    .child(self.request_button("save-activate","保存して使用",json!({"action":"save","restoreSettings":true})))))
    }
}

pub fn item_symbol(item: &Item) -> &'static str {
    match item.kind.as_str() {
        "clock" => "◷",
        "focusTimer" => "◴",
        "folder" => "▣",
        "file" => "▤",
        "link" => "↗",
        _ => "▧",
    }
}

impl Render for Workspace {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        if window.focused(cx).is_none() {
            window.focus(&self.focus_handle);
        }
        let state = self.state.read(cx);
        let section = state.section;
        let busy = state.busy;
        let error = state.error.clone();
        let quit_error = error.clone();
        let appearance_read_only = state.appearance_read_only;
        let read_only = state.snapshot.read_only;
        let read_only_reason = state.snapshot.read_only_reason.clone().unwrap_or_else(|| {
            "設定を読み込めないため、保存を停止しています。元のファイルは保護されています。".into()
        });
        let status = state.snapshot.status.clone();
        let pending = state.snapshot.pending_import.clone();
        let quit = state.request_quit;
        let has_drafts = state.snapshot.has_pending_drafts;
        let mut sidebar = div()
            .w(px(190.))
            .h_full()
            .flex_shrink_0()
            .flex()
            .flex_col()
            .gap_2()
            .p_4()
            .bg(rgb(0x14161a))
            .child(
                div()
                    .py_4()
                    .text_lg()
                    .font_weight(FontWeight::SEMIBOLD)
                    .child("Dock Studio"),
            );
        for (index, label) in [(0, "Custom Dock"), (1, "設定"), (2, "プロファイル")] {
            let entity = self.state.clone();
            sidebar = sidebar.child(button(
                format!("section-{index}"),
                label,
                section == index,
                move |_, _, cx| {
                    entity.update(cx, |s, cx| {
                        s.section = index;
                        cx.notify();
                    })
                },
            ));
        }
        sidebar = sidebar.child(div().flex_1());
        let page = match section {
            1 => self.settings_page(cx).into_any_element(),
            2 => self.profiles_page(cx).into_any_element(),
            _ => self.preview_page(cx).into_any_element(),
        };
        let mut content = div()
            .flex()
            .flex_col()
            .flex_1()
            .min_w_0()
            .h_full()
            .p_6()
            .gap_3();
        if read_only {
            content = content.child(
                div()
                    .p_3()
                    .rounded_lg()
                    .bg(rgb(0x55412a))
                    .text_sm()
                    .child(read_only_reason)
                    .child(
                        div()
                            .flex()
                            .gap_2()
                            .mt_2()
                            .child(self.request_button(
                                "retry",
                                "読み込み直す",
                                json!({"action":"retry"}),
                            ))
                            .child(self.request_button(
                                "reveal",
                                "ファイルを表示",
                                json!({"action":"reveal"}),
                            )),
                    ),
            );
        }
        if appearance_read_only {
            let entity = self.state.clone();
            content = content.child(
                div()
                    .p_3()
                    .rounded_lg()
                    .bg(rgb(0x55412a))
                    .text_sm()
                    .child("外観設定を読み込めないため、外観の保存を停止しています。")
                    .child(button(
                        "retry-appearance",
                        "読み込み直す",
                        false,
                        move |_, _, cx| entity.update(cx, |s, cx| s.retry_appearance(cx)),
                    )),
            );
        }
        if let Some(error) = error {
            let entity = self.state.clone();
            content = content.child(
                div()
                    .p_3()
                    .rounded_lg()
                    .bg(rgb(0x543139))
                    .text_sm()
                    .child(error)
                    .child(button(
                        "dismiss-error",
                        "閉じる",
                        false,
                        move |_, _, cx| {
                            entity.update(cx, |s, cx| {
                                s.error = None;
                                cx.notify();
                            })
                        },
                    )),
            );
        }
        if busy {
            let cancel = self.state.clone();
            content = content.child(
                div()
                    .flex()
                    .gap_2()
                    .items_center()
                    .child(div().text_xs().text_color(rgb(MUTED)).child("処理中…"))
                    .child(button(
                        "cancel-native",
                        "ダイアログをキャンセル",
                        false,
                        move |_, _, cx| cancel.update(cx, |s, _| s.cancel_native_dialog()),
                    )),
            );
        }
        content = content.child(page).when(!status.is_empty(), |v| {
            v.child(div().text_xs().text_color(rgb(MUTED)).child(status))
        });
        let mut root = div()
            .id("workspace")
            .track_focus(&self.focus_handle)
            .tab_group()
            .on_key_down(|event, window, cx| {
                if event.keystroke.key == "tab" {
                    if event.keystroke.modifiers.shift {
                        window.focus_prev();
                    } else {
                        window.focus_next();
                    }
                    cx.stop_propagation();
                }
            })
            .relative()
            .flex()
            .size_full()
            .bg(rgb(BASE))
            .text_color(rgb(TEXT))
            .font_family(".AppleSystemUIFont")
            .child(sidebar)
            .child(content);
        if let Some(profiles) = pending {
            let details = profiles
                .iter()
                .flat_map(|p| {
                    p.items.iter().map(move |i| {
                        format!(
                            "{}：{} → {}",
                            p.name,
                            i.name,
                            i.target.as_deref().unwrap_or("再選択が必要")
                        )
                    })
                })
                .collect::<Vec<_>>();
            root = root.child(
                div()
                    .absolute()
                    .inset_0()
                    .bg(rgba(0x000000bb))
                    .flex()
                    .items_center()
                    .justify_center()
                    .child(card(
                        "読み込む対象を確認",
                        div()
                            .flex()
                            .flex_col()
                            .gap_3()
                            .max_w(px(650.))
                            .max_h(px(550.))
                            .child(
                                div()
                                    .id("import-details")
                                    .overflow_y_scroll()
                                    .max_h(px(350.))
                                    .text_sm()
                                    .children(details),
                            )
                            .child(
                                div()
                                    .flex()
                                    .gap_2()
                                    .child(self.request_button(
                                        "import-cancel",
                                        "キャンセル",
                                        json!({"action":"cancelImport"}),
                                    ))
                                    .child(self.request_button(
                                        "import-copies",
                                        "プロファイルだけ追加",
                                        json!({"action":"confirmImport","restoreSettings":false}),
                                    ))
                                    .child(self.request_button(
                                        "import-settings",
                                        "設定も復元",
                                        json!({"action":"confirmImport","restoreSettings":true}),
                                    )),
                            ),
                    )),
            );
        }
        if quit {
            let entity = self.state.clone();
            root = root.child(
                div()
                    .absolute()
                    .inset_0()
                    .bg(rgba(0x000000bb))
                    .flex()
                    .items_center()
                    .justify_center()
                    .child(card(
                        "終了しますか？",
                        div()
                            .flex()
                            .flex_col()
                            .gap_4()
                            .child(if has_drafts {
                                "未保存の編集は、保存するか下書きとして残せます。"
                            } else {
                                "Dock Studio を終了します。"
                            })
                            .when_some(quit_error, |v, error| {
                                v.child(div().text_sm().text_color(rgb(0xffb4b4)).child(error))
                            })
                            .child(
                                div()
                                    .flex()
                                    .gap_2()
                                    .child(button(
                                        "quit-cancel",
                                        "キャンセル",
                                        false,
                                        move |_, _, cx| {
                                            entity.update(cx, |s, cx| {
                                                s.request_quit = false;
                                                cx.notify();
                                            })
                                        },
                                    ))
                                    .child(self.request_button(
                                        "quit-keep",
                                        "下書きを残して終了",
                                        json!({"action":"snapshot","exitAfter":true}),
                                    ))
                                    .child(self.request_button(
                                        "quit-save",
                                        "保存して終了",
                                        json!({"action":"saveAll","exitAfter":true}),
                                    )),
                            ),
                    )),
            );
        }
        root
    }
}
