use crate::{
    appearance::Background, icons::IconCache, model::Item, native::DockNative, state::StudioState,
    ui::item_symbol,
};
use chrono::Local;
use gpui::{prelude::*, *};
use objc2_foundation::{NSPoint, NSRect, NSSize};
use serde_json::json;
use std::time::{Duration, Instant, SystemTime};

pub fn magnification(index: usize, hover: Option<usize>, maximum: f32) -> f32 {
    match hover.map(|h| h.abs_diff(index)) {
        Some(0) => maximum,
        Some(1) => 1.0 + (maximum - 1.0) * 0.45,
        Some(2) => 1.0 + (maximum - 1.0) * 0.12,
        _ => 1.0,
    }
}
fn item_width(item: &Item, base: f32, vertical: bool) -> f32 {
    if vertical {
        return if item.kind == "spacer" {
            12.0
        } else if item.kind == "application" {
            base + 10.0
        } else {
            base
        };
    }
    match item.kind.as_str() {
        "spacer" => 12.0,
        "clock" => 108.0,
        "focusTimer" => 96.0,
        _ => base,
    }
}
pub fn panel_bounds(
    snapshot: &crate::model::Snapshot,
    appearance: &crate::appearance::Appearance,
    capture: bool,
) -> Option<Bounds<Pixels>> {
    let settings = &snapshot.document.settings;
    let display = snapshot
        .displays
        .iter()
        .find(|d| Some(d.id) == settings.display_id)
        .or(snapshot.displays.first())?;
    let vertical = settings.position != "bottom";
    let base = settings.icon_size;
    let available = if vertical {
        display.height
    } else {
        display.width
    } - 36.0;
    let unscaled = 24.0
        + snapshot
            .displayed_items
            .iter()
            .map(|i| item_width(i, base, vertical) + 6.0)
            .sum::<f32>();
    let maximum = if appearance.magnification {
        appearance.magnification_scale
    } else {
        1.0
    };
    let metrics = crate::layout::viewport(unscaled, base, maximum, available, vertical);
    let (w, h) = if vertical {
        (metrics.thickness, metrics.length)
    } else {
        (metrics.length, metrics.thickness)
    };
    let (x, y) = if capture {
        (-20000.0, -20000.0)
    } else {
        match settings.position.as_str() {
            "left" => (display.x + 8.0, display.y + (display.height - h) / 2.0),
            "right" => (
                display.x + display.width - w - 8.0,
                display.y + (display.height - h) / 2.0,
            ),
            _ => (
                display.x + (display.width - w) / 2.0,
                display.y + display.height - h - 8.0,
            ),
        }
    };
    Some(Bounds::new(point(px(x), px(y)), size(px(w), px(h))))
}
pub struct DockView {
    state: Entity<StudioState>,
    preview: bool,
    capture_mode: bool,
    was_visible: bool,
    ticks: u8,
    icons: IconCache,
    native: Option<DockNative>,
    hover: Option<usize>,
    hover_from: Option<usize>,
    hover_changed: Instant,
    over: bool,
    last_interaction: Instant,
    hidden: f32,
    hide_target: f32,
    hide_from: f32,
    hide_changed: Instant,
    pub menu_open: bool,
    capture_collapsed: Option<bool>,
}
impl DockView {
    pub fn new(state: Entity<StudioState>, preview: bool, cx: &mut Context<Self>) -> Self {
        cx.observe(&state, |_, _, cx| cx.notify()).detach();
        cx.spawn(async move |this, cx| {
            loop {
                Timer::after(Duration::from_millis(100)).await;
                if this
                    .update(cx, |view, cx| {
                        view.ticks = (view.ticks + 1) % 10;
                        let previous_over = view.over;
                        if !view.preview {
                            if let Some(native) = &view.native {
                                view.over = native.hovered();
                                if view.over {
                                    view.last_interaction = Instant::now();
                                } else {
                                    if !view.capture_mode {
                                        view.set_hover(None, cx);
                                    }
                                }
                                if view.menu_open
                                    && view.last_interaction.elapsed() > Duration::from_secs(2)
                                {
                                    view.menu_open = false;
                                }
                            }
                        }
                        let due_to_hide = !view.preview
                            && view.hide_target == 0.0
                            && crate::layout::should_hide(
                                view.state.read(cx).snapshot.document.settings.auto_hide,
                                view.over,
                                crate::native_menu::tracking(),
                                view.state.read(cx).busy,
                                view.last_interaction.elapsed(),
                            );
                        if view.ticks == 0 || previous_over != view.over || due_to_hide {
                            cx.notify();
                        }
                    })
                    .is_err()
                {
                    break;
                }
            }
        })
        .detach();
        Self {
            state,
            preview,
            capture_mode: std::env::args().any(|a| a == "--capture"),
            was_visible: false,
            ticks: 0,
            icons: IconCache::default(),
            native: None,
            hover: None,
            hover_from: None,
            hover_changed: Instant::now(),
            over: false,
            last_interaction: Instant::now(),
            hidden: 0.0,
            hide_target: 0.0,
            hide_from: 0.0,
            hide_changed: Instant::now(),
            menu_open: false,
            capture_collapsed: None,
        }
    }
    fn set_hover(&mut self, value: Option<usize>, cx: &mut Context<Self>) {
        if value != self.hover {
            self.hover_from = self.hover;
            self.hover = value;
            self.hover_changed = Instant::now();
            cx.notify();
        }
    }
    pub fn capture_hover(&mut self, index: Option<usize>, cx: &mut Context<Self>) {
        self.hover = index;
        self.hover_from = index;
        self.hover_changed = Instant::now() - Duration::from_secs(1);
        cx.notify();
    }
    pub fn capture_animation(
        &mut self,
        from: Option<usize>,
        to: Option<usize>,
        elapsed: Duration,
        hidden: Option<bool>,
        cx: &mut Context<Self>,
    ) {
        self.hover_from = from;
        self.hover = to;
        self.hover_changed = Instant::now() - elapsed;
        self.capture_collapsed = hidden;
        if let Some(hidden) = hidden {
            self.hide_target = if hidden { 1.0 } else { 0.0 };
            self.hide_from = 1.0 - self.hide_target;
            self.hide_changed = Instant::now() - elapsed;
        }
        cx.notify();
    }
}
impl Render for DockView {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let state = self.state.read(cx);
        let snapshot = state.snapshot.clone();
        let mut appearance = state.appearance.clone();
        appearance.reduce_motion |= snapshot.reduce_motion;
        if snapshot.reduce_transparency && appearance.background != Background::Transparent {
            appearance.background = Background::Color;
            appearance.opacity = 1.0;
            appearance.blur = false;
        }
        let visible = state.dock_visible;
        if visible && !self.was_visible {
            self.last_interaction = Instant::now();
            self.hidden = 0.0;
            self.hide_target = 0.0;
        }
        self.was_visible = visible;
        let busy = state.busy;
        let sessions = state.sessions.clone();
        let vertical = snapshot.document.settings.position != "bottom";
        let items = snapshot.displayed_items();
        let available = if self.preview {
            f32::from(window.bounds().size.width) - 300.0
        } else {
            snapshot
                .displays
                .iter()
                .find(|d| Some(d.id) == snapshot.document.settings.display_id)
                .or(snapshot.displays.first())
                .map(|d| if vertical { d.height } else { d.width })
                .unwrap_or(1200.0)
                - 36.0
        };
        let base = snapshot.document.settings.icon_size;
        let from_elapsed = self.hover_changed.elapsed().as_secs_f32() / 0.16;
        let tween = if appearance.reduce_motion {
            1.0
        } else {
            from_elapsed.min(1.0)
        };
        let tween = tween * tween * (3.0 - 2.0 * tween);
        if tween < 1.0 {
            window.request_animation_frame();
        }
        let max = if appearance.magnification {
            appearance.magnification_scale
        } else {
            1.0
        };
        let scales: Vec<f32> = items
            .iter()
            .enumerate()
            .map(|(i, item)| {
                if ["clock", "focusTimer", "spacer"].contains(&item.kind.as_str()) {
                    1.0
                } else {
                    let a = magnification(i, self.hover_from, max);
                    a + (magnification(i, self.hover, max) - a) * tween
                }
            })
            .collect();
        let total = 24.0
            + items
                .iter()
                .enumerate()
                .map(|(i, item)| item_width(item, base, vertical) * scales[i] + 6.0)
                .sum::<f32>();
        let length = total.min(available.max(140.0)).max(120.0);
        let thick = base + 28.0;
        let unscaled = 24.0
            + items
                .iter()
                .map(|i| item_width(i, base, vertical) + 6.0)
                .sum::<f32>();
        let metrics = crate::layout::viewport(unscaled, base, max, available, vertical);
        let root_length = metrics.length;
        let root_thickness = metrics.thickness;
        let collapsed = self.capture_collapsed.unwrap_or(
            !self.preview
                && crate::layout::should_hide(
                    snapshot.document.settings.auto_hide,
                    self.over,
                    crate::native_menu::tracking(),
                    busy,
                    self.last_interaction.elapsed(),
                ),
        );
        let target = if collapsed { 1.0 } else { 0.0 };
        if target != self.hide_target {
            self.hide_from = self.hidden;
            self.hide_target = target;
            self.hide_changed = Instant::now();
        }
        let hide_t = if appearance.reduce_motion {
            1.0
        } else {
            (self.hide_changed.elapsed().as_secs_f32() / 0.22).min(1.0)
        };
        let hide_t = hide_t * hide_t * (3.0 - 2.0 * hide_t);
        self.hidden = self.hide_from + (self.hide_target - self.hide_from) * hide_t;
        if (self.hidden - self.hide_target).abs() > 0.001 {
            window.request_animation_frame();
        }
        let opacity = 1.0 - self.hidden;
        if !self.preview {
            if self.native.is_none() {
                match DockNative::new(window) {
                    Ok(native) => self.native = Some(native),
                    Err(error) => {
                        self.state.update(cx, |s, cx| {
                            s.error = Some(error);
                            cx.notify();
                        });
                    }
                }
            }
            if let Some(bounds) = panel_bounds(&snapshot, &appearance, self.capture_mode) {
                let _ = crate::native::set_frame(window, bounds);
                let _ = crate::native::order(
                    window,
                    visible && snapshot.document.settings.mode != "native",
                );
            }
            if let Some(native) = &mut self.native {
                let (x, y, w, h) = if vertical {
                    let x = if snapshot.document.settings.position == "right" {
                        root_thickness - thick + self.hidden * thick
                    } else {
                        -self.hidden * thick
                    };
                    (x, (root_length - length) / 2.0, thick, length)
                } else {
                    (
                        (root_length - length) / 2.0,
                        -self.hidden * thick,
                        length,
                        thick,
                    )
                };
                let bar = NSRect::new(
                    NSPoint::new(f64::from(x), f64::from(y)),
                    NSSize::new(f64::from(w), f64::from(h)),
                );
                let interactive = if self.menu_open {
                    NSRect::new(
                        NSPoint::new(0.0, 0.0),
                        NSSize::new(
                            f64::from(if vertical {
                                root_thickness
                            } else {
                                root_length
                            }),
                            f64::from(if vertical {
                                root_length
                            } else {
                                root_thickness
                            }),
                        ),
                    )
                } else if collapsed {
                    if vertical {
                        NSRect::new(
                            NSPoint::new(
                                f64::from(if snapshot.document.settings.position == "right" {
                                    root_thickness - 8.0
                                } else {
                                    0.0
                                }),
                                f64::from((root_length - 100.0) / 2.0),
                            ),
                            NSSize::new(8.0, 100.0),
                        )
                    } else {
                        NSRect::new(
                            NSPoint::new(f64::from((root_length - 100.0) / 2.0), 0.0),
                            NSSize::new(100.0, 8.0),
                        )
                    }
                } else {
                    NSRect::new(
                        NSPoint::new(f64::from(x), f64::from(y)),
                        NSSize::new(
                            f64::from(if vertical { root_thickness } else { length }),
                            f64::from(if vertical { length } else { root_thickness }),
                        ),
                    )
                };
                let mut material = appearance.clone();
                material.opacity *= opacity;
                native.update(bar, interactive, &material);
            }
        }
        let mut row = div().relative().flex().gap(px(6.)).items_end();
        if vertical {
            row = row.flex_col().items_center();
        }
        for (index, item) in items.iter().enumerate() {
            let entity = self.state.clone();
            let item_id = item.id.clone();
            let kind = item.kind.clone();
            let width = item_width(item, base, vertical) * scales[index];
            let icon_size = base * scales[index];
            let mut cell = div()
                .id(ElementId::Name(format!("dock-item-{}", item.id).into()))
                .relative()
                .flex()
                .flex_col()
                .items_center()
                .justify_end()
                .w(px(width))
                .h(px(if vertical {
                    item_width(item, base, true) * scales[index]
                } else {
                    icon_size + 14.0
                }));
            if item.kind == "spacer" {
                cell = cell.justify_center().child(
                    div()
                        .bg(rgba(0xffffff38))
                        .w(px(if vertical { base - 8.0 } else { 1.0 }))
                        .h(px(if vertical { 1.0 } else { base - 8.0 })),
                );
            } else {
                let visual = if item.kind == "clock" {
                    div()
                        .flex()
                        .flex_col()
                        .items_center()
                        .justify_center()
                        .gap_1()
                        .w(px(width))
                        .h(px(base))
                        .rounded_lg()
                        .bg(rgba(0xffffff0c))
                        .child(
                            div()
                                .text_size(px(if vertical { 17.0 } else { 23.0 }))
                                .font_weight(FontWeight::MEDIUM)
                                .child(Local::now().format("%H:%M").to_string()),
                        )
                        .when(!vertical, |v| {
                            v.child(
                                div()
                                    .text_xs()
                                    .text_color(rgba(0xffffff99))
                                    .child(Local::now().format("%m/%d %a").to_string()),
                            )
                        })
                        .into_any_element()
                } else if item.kind == "focusTimer" {
                    let session = sessions.get(&item.id).cloned().unwrap_or_default();
                    let seconds = session.seconds(SystemTime::now());
                    div()
                        .flex()
                        .flex_col()
                        .items_center()
                        .justify_center()
                        .gap_1()
                        .w(px(width))
                        .h(px(base))
                        .rounded_lg()
                        .bg(rgba(0xffffff0c))
                        .child(
                            div()
                                .text_size(px(if vertical { 16.0 } else { 22.0 }))
                                .child(format!("{:02}:{:02}", seconds / 60, seconds % 60)),
                        )
                        .when(!vertical, |v| {
                            v.child(div().text_xs().text_color(rgb(0xaac9e9)).child(
                                if seconds == 0 {
                                    "完了"
                                } else if session.deadline.is_some() {
                                    "Ⅱ 一時停止"
                                } else {
                                    "▶ 開始"
                                },
                            ))
                        })
                        .into_any_element()
                } else if let Some(image) = snapshot
                    .icons
                    .get(&item.id)
                    .and_then(|p| self.icons.get(p, appearance.icon_style))
                {
                    img(image).size(px(icon_size)).into_any_element()
                } else {
                    div()
                        .size(px(icon_size))
                        .flex()
                        .items_center()
                        .justify_center()
                        .rounded_lg()
                        .bg(rgba(0xffffff15))
                        .text_size(px(28.))
                        .child(item_symbol(item))
                        .into_any_element()
                };
                cell = cell
                    .cursor_pointer()
                    .on_hover(cx.listener(move |view, hovered, _, cx| {
                        if *hovered {
                            view.over = true;
                            view.last_interaction = Instant::now();
                            view.set_hover(Some(index), cx);
                        } else if view.hover == Some(index) {
                            view.set_hover(None, cx);
                        }
                    }))
                    .on_click(move |_, _, cx| {
                        entity.update(cx, |s, cx| {
                            if kind == "focusTimer" {
                                s.toggle_focus(&item_id, cx);
                            } else if kind == "clock" {
                                if let Some(handle) = s.clock_window {
                                    if handle
                                        .update(cx, |_, w, _| {
                                            w.activate_window();
                                        })
                                        .is_ok()
                                    {
                                        return;
                                    }
                                }
                                let bounds = Bounds::centered(None, size(px(300.), px(180.)), cx);
                                if let Ok(handle) = cx.open_window(
                                    WindowOptions {
                                        window_bounds: Some(WindowBounds::Windowed(bounds)),
                                        titlebar: Some(TitlebarOptions {
                                            title: Some("時計".into()),
                                            ..Default::default()
                                        }),
                                        ..Default::default()
                                    },
                                    |_, cx| cx.new(ClockDetail::new),
                                ) {
                                    s.clock_window = Some(handle.into());
                                }
                            } else {
                                s.request(json!({"action":"open","id":item_id}), cx);
                            }
                        })
                    })
                    .child(visual);
                if appearance.running_indicators && item.kind == "application" {
                    cell = cell.child(div().mt(px(3.)).size(px(4.)).rounded_full().bg(
                        if snapshot.is_running(item) {
                            rgba(0xffffffdd)
                        } else {
                            rgba(0xffffff00)
                        },
                    ));
                }
                if self.hover == Some(index) {
                    cell = cell.child(
                        div()
                            .absolute()
                            .bottom(px(icon_size + 22.0))
                            .px_2()
                            .py_1()
                            .rounded_md()
                            .bg(rgba(0x22262bef))
                            .text_color(rgb(0xf5f6f8))
                            .text_xs()
                            .whitespace_nowrap()
                            .child(item.name.clone()),
                    );
                }
            }
            row = row.child(cell);
        }
        if items.is_empty() {
            row = row.child(
                div()
                    .px_4()
                    .py_3()
                    .text_sm()
                    .child("プロファイルに項目を追加"),
            );
        }
        let (bar_w, bar_h) = if vertical {
            (thick, length)
        } else {
            (length, thick)
        };
        let tint = if appearance.background == Background::Transparent
            || (appearance.background == Background::System && appearance.blur)
        {
            rgba(0x00000000)
        } else {
            let alpha = (appearance.opacity * 255.0) as u32;
            rgba((appearance.color << 8) | alpha)
        };
        let mut background = div()
            .absolute()
            .bottom_0()
            .left_0()
            .w(px(bar_w))
            .h(px(bar_h))
            .rounded(px(22.))
            .bg(tint);
        if appearance.background != Background::Transparent {
            background = background
                .border_1()
                .border_color(rgba(0xffffff35))
                .shadow_md();
        }
        if appearance.background == Background::Image {
            if let Some(path) = &appearance.image {
                background = background.overflow_hidden().child(
                    img(std::path::PathBuf::from(path))
                        .w_full()
                        .h_full()
                        .object_fit(ObjectFit::Cover)
                        .opacity(appearance.opacity),
                );
            }
        }
        let mut bar = div()
            .relative()
            .w(px(bar_w))
            .h(px(if vertical { bar_h } else { root_thickness }))
            .opacity(opacity)
            .child(background)
            .child(
                row.absolute()
                    .bottom(px(12.))
                    .when(
                        vertical && snapshot.document.settings.position == "right",
                        |v| v.right(px(12.)),
                    )
                    .when(
                        !vertical || snapshot.document.settings.position != "right",
                        |v| v.left(px(12.)),
                    ),
            );
        if vertical {
            bar = bar.left(px(if snapshot.document.settings.position == "right" {
                self.hidden * thick
            } else {
                -self.hidden * thick
            }));
        } else {
            bar = bar.top(px(self.hidden * thick));
        }
        let mut root = div()
            .id("dock-root")
            .relative()
            .overflow_hidden()
            .flex()
            .size_full()
            .text_color(rgb(0xf4f5f7))
            .font_family(".AppleSystemUIFont")
            .on_hover(cx.listener(|view, over, _, cx| {
                view.over = *over;
                if *over {
                    view.last_interaction = Instant::now();
                } else {
                    view.set_hover(None, cx);
                }
                cx.notify();
            }))
            .on_mouse_move(cx.listener(|view, _, _, _| {
                if let Some(native) = &view.native {
                    native.update_pointer();
                }
            }))
            .on_mouse_down(
                MouseButton::Right,
                cx.listener(|view, event: &MouseDownEvent, window, cx| {
                    let state = view.state.read(cx);
                    let mut entries =
                        crate::native_menu::entries(&state.snapshot, state.dock_visible);
                    if let Some(item) = view
                        .hover
                        .and_then(|i| state.snapshot.displayed_items.get(i))
                        .filter(|i| i.kind == "focusTimer")
                    {
                        entries.insert(
                            0,
                            crate::native_menu::Entry {
                                label: "タイマーをリセット".into(),
                                command: format!("reset:{}", item.id),
                                checked: false,
                            },
                        );
                    }
                    if let Ok(address) = crate::native::view_address(window) {
                        crate::native_menu::popup(
                            entries,
                            event.position.x.into(),
                            event.position.y.into(),
                            address,
                        );
                    }
                    view.last_interaction = Instant::now();
                    cx.stop_propagation();
                }),
            );
        if vertical {
            root = root
                .items_center()
                .when(snapshot.document.settings.position == "right", |v| {
                    v.justify_end()
                });
        } else {
            root = root.items_end().justify_center();
        }
        if self.preview {
            root = root.p_6();
        }
        root = root.child(bar);
        root
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use core::prelude::v1::test;
    #[test]
    fn magnification_falls_off_symmetrically() {
        assert_eq!(magnification(3, Some(3), 1.5), 1.5);
        assert_eq!(
            magnification(2, Some(3), 1.5),
            magnification(4, Some(3), 1.5)
        );
        assert_eq!(magnification(8, Some(3), 1.5), 1.0);
    }
}

struct ClockDetail;
impl ClockDetail {
    fn new(cx: &mut Context<Self>) -> Self {
        cx.spawn(async move |this, cx| {
            loop {
                Timer::after(Duration::from_secs(1)).await;
                if this.update(cx, |_, cx| cx.notify()).is_err() {
                    break;
                }
            }
        })
        .detach();
        Self
    }
}
impl Render for ClockDetail {
    fn render(&mut self, _: &mut Window, _: &mut Context<Self>) -> impl IntoElement {
        div()
            .flex()
            .flex_col()
            .items_center()
            .justify_center()
            .gap_3()
            .size_full()
            .bg(rgb(0x24272e))
            .text_color(rgb(0xe9ebef))
            .child(
                div()
                    .text_size(px(44.))
                    .child(Local::now().format("%H:%M:%S").to_string()),
            )
            .child(
                div()
                    .text_sm()
                    .child(Local::now().format("%Y/%m/%d %A").to_string()),
            )
    }
}
