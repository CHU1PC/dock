use crate::{appearance::Appearance, bridge::Bridge, model::Snapshot, text_input::TextInput};
use gpui::{AppContext, Context, Entity, Task};
use serde_json::{Value, json};
use std::{
    collections::{HashMap, VecDeque},
    sync::{Arc, Mutex},
    time::{Duration, SystemTime},
};

#[derive(Clone)]
pub struct FocusSession {
    pub remaining: u64,
    pub deadline: Option<SystemTime>,
}
impl Default for FocusSession {
    fn default() -> Self {
        Self {
            remaining: 1500,
            deadline: None,
        }
    }
}
impl FocusSession {
    pub fn seconds(&self, now: SystemTime) -> u64 {
        self.deadline
            .map(|end| {
                end.duration_since(now)
                    .map(|d| d.as_secs() + u64::from(d.subsec_nanos() > 0))
                    .unwrap_or(0)
            })
            .unwrap_or(self.remaining)
    }
    pub fn toggle(&mut self, now: SystemTime) {
        if self.deadline.is_some() && self.seconds(now) > 0 {
            self.remaining = self.seconds(now);
            self.deadline = None;
        } else {
            if self.seconds(now) == 0 {
                self.remaining = 1500;
            }
            self.deadline = Some(now + Duration::from_secs(self.remaining));
        }
    }
}

pub struct StudioState {
    pub snapshot: Snapshot,
    pub appearance: Appearance,
    pub appearance_read_only: bool,
    pub error: Option<String>,
    pub busy: bool,
    pub link_pending: bool,
    pub dock_visible: bool,
    pub section: usize,
    pub selected_item: Option<String>,
    pub name_input: Entity<TextInput>,
    pub link_name: Entity<TextInput>,
    pub link_url: Entity<TextInput>,
    pub color_input: Entity<TextInput>,
    pub sessions: HashMap<String, FocusSession>,
    pub request_quit: bool,
    pub manager: Option<gpui::AnyWindowHandle>,
    pub clock_window: Option<gpui::AnyWindowHandle>,
    in_flight: bool,
    native_control: Arc<Mutex<std::process::ChildStdin>>,
    queue: VecDeque<Value>,
    quit_when_idle: bool,
    bridge: Arc<Mutex<Bridge>>,
    job: Option<Task<()>>,
    name_revision: u64,
}

impl StudioState {
    pub fn new(snapshot: Snapshot, bridge: Bridge, cx: &mut Context<Self>) -> Self {
        let (appearance, error, appearance_read_only) = match Appearance::load() {
            Ok(value) => (value, None, false),
            Err(error) => (Appearance::default(), Some(error), true),
        };
        let native_control = bridge.control_handle();
        let name = snapshot.editor_profile.name.clone();
        let editable = !snapshot.read_only;
        let color = format!("{:06X}", appearance.color);
        let error = error.or_else(|| snapshot.error.clone());
        let value = Self {
            snapshot,
            appearance,
            appearance_read_only,
            error,
            busy: false,
            link_pending: false,
            dock_visible: false,
            section: 0,
            selected_item: None,
            sessions: HashMap::new(),
            request_quit: false,
            manager: None,
            clock_window: None,
            in_flight: false,
            native_control,
            queue: VecDeque::new(),
            quit_when_idle: false,
            name_input: cx.new(|cx| {
                let mut input = TextInput::new(&name, "プロファイル名", cx);
                input.enabled = editable;
                input
            }),
            link_name: cx.new(|cx| TextInput::new("", "リンクの名前", cx)),
            link_url: cx.new(|cx| TextInput::new("https://", "https://example.com", cx)),
            color_input: cx.new(|cx| TextInput::new(&color, "RRGGBB", cx)),
            bridge: Arc::new(Mutex::new(bridge)),
            job: None,
            name_revision: 0,
        };
        cx.observe(&value.name_input, |state, input, cx| {
            if !state.snapshot.read_only
                && input.read(cx).content.as_ref() != state.snapshot.editor_profile.name
            {
                state.name_revision += 1;
                let revision = state.name_revision;
                cx.spawn(async move |this, cx| {
                    gpui::Timer::after(Duration::from_millis(300)).await;
                    let _ = this.update(cx, |state, cx| {
                        if state.name_revision == revision {
                            let name = state.name_input.read(cx).content.to_string();
                            if name != state.snapshot.editor_profile.name {
                                state.request(json!({"action":"rename","name":name}), cx);
                            }
                        }
                    });
                })
                .detach();
            }
        })
        .detach();
        value
    }

    pub fn request(&mut self, mut request: Value, cx: &mut Context<Self>) {
        let background = matches!(request["action"].as_str(), Some("poll" | "running"));
        if self.in_flight {
            if !background {
                self.queue.push_back(request);
            }
            return;
        }
        request["editingProfileID"] = json!(self.snapshot.editor_profile.id);
        if !background {
            let name = self.name_input.read(cx).content.to_string();
            if name != self.snapshot.editor_profile.name {
                request["draftName"] = json!(name);
            }
        }
        self.in_flight = true;
        self.busy = !background;
        let revision = self.name_revision;
        let link_request = request["kind"].as_str() == Some("link");
        let bridge = self.bridge.clone();
        let exit_after = request["exitAfter"].as_bool().unwrap_or(false);
        let action = request["action"].as_str().unwrap_or_default().to_owned();
        self.job = Some(cx.spawn(async move |this, cx| {
            let result = cx
                .background_executor()
                .spawn(async move {
                    bridge
                        .lock()
                        .map_err(|_| "Native service lock failed".to_owned())?
                        .request(request)
                })
                .await;
            let _ = this.update(cx, |state, cx| {
                state.busy = false;
                state.in_flight = false;
                match result {
                    Ok(snapshot) => {
                        if let Some(path) = &snapshot.background_path {
                            let mut appearance = state.appearance.clone();
                            appearance.image = Some(path.clone());
                            appearance.background = crate::appearance::Background::Image;
                            state.save_appearance(appearance, cx);
                        }
                        if snapshot.editor_profile.id != state.snapshot.editor_profile.id
                            || (["save", "saveAll", "retry"].contains(&action.as_str())
                                && revision == state.name_revision)
                        {
                            let name = snapshot.editor_profile.name.clone();
                            state
                                .name_input
                                .update(cx, |input, cx| input.set_content(&name, cx));
                            state.selected_item = None;
                        }
                        if action == "remove" {
                            state.selected_item = None;
                        }
                        if action == "add" && link_request {
                            state.link_pending = false;
                        }
                        if action == "add" && link_request && snapshot.error.is_none() {
                            state.link_name.update(cx, |i, cx| i.set_content("", cx));
                            state
                                .link_url
                                .update(cx, |i, cx| i.set_content("https://", cx));
                        }
                        if !background || snapshot.error != state.snapshot.error {
                            state.error = snapshot.error.clone();
                        }
                        let editable = !snapshot.read_only;
                        state.name_input.update(cx, |input, cx| {
                            input.enabled = editable;
                            cx.notify();
                        });
                        let can_exit = snapshot.error.is_none();
                        state.snapshot = snapshot;
                        if state.snapshot.document.settings.mode == "native" {
                            state.dock_visible = false;
                        }
                        if exit_after && can_exit {
                            cx.quit();
                        }
                    }
                    Err(error) => {
                        if link_request {
                            state.link_pending = false;
                        }
                        state.error = Some(error);
                    }
                }
                if let Some(next) = state.queue.pop_front() {
                    state.request(next, cx);
                } else if state.quit_when_idle {
                    state.quit_when_idle = false;
                    state.ask_quit(cx);
                }
                cx.notify();
            });
        }));
        cx.notify();
    }
    pub fn save_appearance(&mut self, appearance: Appearance, cx: &mut Context<Self>) {
        if self.appearance_read_only || self.snapshot.read_only || !self.snapshot.exclusive {
            self.error = Some(
                "Appearance saving is disabled. Check the configuration or close the other Dock Studio session."
                    .into(),
            );
            return;
        }
        match appearance.save() {
            Ok(()) => self.appearance = appearance,
            Err(error) => self.error = Some(error),
        }
        cx.notify();
    }
    pub fn change_settings(
        &mut self,
        change: impl FnOnce(&mut crate::model::Settings),
        cx: &mut Context<Self>,
    ) {
        let mut settings = self.snapshot.document.settings.clone();
        change(&mut settings);
        self.snapshot.document.settings = settings.clone();
        self.request(json!({"action":"settings","settings":settings}), cx);
    }
    pub fn toggle_dock(&mut self, cx: &mut Context<Self>) {
        if self.snapshot.read_only {
            return;
        }
        if self.snapshot.document.settings.mode == "native" && !self.dock_visible {
            self.dock_visible = true;
            self.change_settings(|settings| settings.mode = "both".into(), cx);
        } else {
            self.dock_visible = !self.dock_visible;
            cx.notify();
        }
    }
    pub fn cancel_native_dialog(&self) {
        Bridge::cancel_dialog(&self.native_control);
    }
    pub fn ask_quit(&mut self, cx: &mut Context<Self>) {
        if self.in_flight {
            self.quit_when_idle = true;
            self.show_manager(cx);
            cx.notify();
            return;
        }
        let dirty = self.snapshot.has_pending_drafts
            || self.name_input.read(cx).content.as_ref() != self.snapshot.editor_profile.name;
        if self.snapshot.read_only || (!self.busy && !dirty) {
            cx.quit();
        } else {
            self.request_quit = true;
            self.show_manager(cx);
            cx.notify();
        }
    }
    pub fn retry_appearance(&mut self, cx: &mut Context<Self>) {
        match Appearance::load() {
            Ok(value) => {
                self.appearance = value;
                self.appearance_read_only = false;
                self.error = None;
            }
            Err(error) => self.error = Some(error),
        }
        cx.notify();
    }
    pub fn show_manager(&self, cx: &mut gpui::App) {
        if let Some(manager) = self.manager {
            let _ = manager.update(cx, |_, window, cx| {
                let _ = crate::native::order(window, true);
                window.activate_window();
                cx.activate(true);
            });
        }
    }
    pub fn toggle_focus(&mut self, id: &str, cx: &mut Context<Self>) {
        self.sessions
            .entry(id.to_owned())
            .or_default()
            .toggle(SystemTime::now());
        cx.notify();
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn focus_timer_recovers_after_sleep_and_restarts() {
        let now = SystemTime::UNIX_EPOCH + Duration::from_secs(1000);
        let mut s = FocusSession::default();
        s.toggle(now);
        assert_eq!(s.seconds(now + Duration::from_secs(60)), 1440);
        s.toggle(now + Duration::from_secs(60));
        assert_eq!(s.seconds(now + Duration::from_secs(900)), 1440);
        s.toggle(now + Duration::from_secs(900));
        assert_eq!(s.seconds(now + Duration::from_secs(3000)), 0);
        s.toggle(now + Duration::from_secs(3000));
        assert_eq!(s.seconds(now + Duration::from_secs(3000)), 1500);
    }
}
