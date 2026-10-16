use crate::model::Snapshot;
use serde_json::Value;
use std::{
    io::{BufRead, BufReader, Write},
    os::fd::AsRawFd,
    path::PathBuf,
    process::{Child, ChildStdin, ChildStdout, Command, Stdio},
    sync::{Arc, Mutex},
};

pub struct Bridge {
    child: Child,
    directory: Option<PathBuf>,
    input: Arc<Mutex<ChildStdin>>,
    output: BufReader<ChildStdout>,
}

impl Bridge {
    pub fn control_handle(&self) -> Arc<Mutex<ChildStdin>> {
        self.input.clone()
    }
    pub fn cancel_dialog(control: &Arc<Mutex<ChildStdin>>) {
        if let Ok(mut input) = control.lock() {
            let _ = input.write_all(b"{\"action\":\"cancel\"}\n");
            let _ = input.flush();
        }
    }
    pub fn start() -> Result<Self, String> {
        Self::start_in(None)
    }
    fn start_in(directory: Option<&std::path::Path>) -> Result<Self, String> {
        let bundled = std::env::current_exe()
            .ok()
            .and_then(|exe| {
                exe.parent()?
                    .parent()
                    .map(|contents| contents.join("Helpers/dockstudio-bridge"))
            })
            .filter(|path| path.is_file());
        let executable = std::env::var_os("DOCKSTUDIO_BRIDGE")
            .map(PathBuf::from)
            .or(bundled)
            .unwrap_or_else(|| {
                PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("target/native/dockstudio-bridge")
            });
        let mut command = Command::new(&executable);
        command.env("DOCKSTUDIO_UI_PID", std::process::id().to_string());
        if let Some(directory) = directory {
            command.env("DOCKSTUDIO_DATA_DIR", directory);
        }
        let mut child = command
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::inherit())
            .spawn()
            .map_err(|e| format!("Unable to start {}: {e}", executable.display()))?;
        let input = child.stdin.take().ok_or("Missing bridge input")?;
        let output = BufReader::new(child.stdout.take().ok_or("Missing bridge output")?);
        Ok(Self {
            child,
            directory: directory.map(|path| path.to_owned()),
            input: Arc::new(Mutex::new(input)),
            output,
        })
    }
    pub fn request(&mut self, request: Value) -> Result<Snapshot, String> {
        if self
            .child
            .try_wait()
            .map_err(|error| error.to_string())?
            .is_some()
        {
            let control = self.input.clone();
            let mut replacement = Self::start_in(self.directory.clone().as_deref())?;
            {
                let mut original = control.lock().map_err(|_| "Native input lock failed")?;
                let mut next = replacement
                    .input
                    .lock()
                    .map_err(|_| "Native input lock failed")?;
                std::mem::swap(&mut *original, &mut *next);
            }
            replacement.input = control;
            *self = replacement;
            return Err("The native service restarted. Retry the operation.".into());
        }
        let interactive = matches!(
            request["action"].as_str(),
            Some("add" | "delete" | "open" | "import" | "export" | "background")
        );
        {
            let mut input = self.input.lock().map_err(|_| "Native input lock failed")?;
            serde_json::to_writer(&mut *input, &request).map_err(|e| e.to_string())?;
            input.write_all(b"\n").map_err(|e| e.to_string())?;
            input.flush().map_err(|e| e.to_string())?;
        }
        if !interactive {
            let mut descriptor = libc::pollfd {
                fd: self.output.get_ref().as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            };
            let ready = unsafe { libc::poll(&mut descriptor, 1, 30_000) };
            if ready <= 0 {
                let _ = self.child.kill();
                return Err(
                    "The native service timed out and was stopped. Retry the operation.".into(),
                );
            }
        }
        let mut line = String::new();
        if self
            .output
            .read_line(&mut line)
            .map_err(|e| e.to_string())?
            == 0
        {
            return Err("The native service stopped unexpectedly.".into());
        }
        serde_json::from_str(&line).map_err(|e| format!("Invalid bridge response: {e}"))
    }
}
impl Drop for Bridge {
    fn drop(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    struct Fixture(PathBuf);
    impl Fixture {
        fn new() -> Self {
            let path = std::env::temp_dir()
                .join(format!("dockstudio-bridge-test-{}", uuid::Uuid::new_v4()));
            std::fs::create_dir_all(&path).unwrap();
            Self(path)
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }
    #[test]
    fn native_bridge_preserves_profiles_drafts_settings_and_reload() {
        let fixture = Fixture::new();
        let mut bridge = Bridge::start_in(Some(&fixture.0)).unwrap();
        let initial = bridge.request(json!({"action":"snapshot"})).unwrap();
        assert_eq!(initial.document.schema_version, 1);
        assert_eq!(initial.document.profiles.len(), 2);
        let new = bridge.request(json!({"action":"create"})).unwrap();
        let id = new.editor_profile.id.clone();
        let draft = bridge
            .request(json!({"action":"rename","name":"GPUI 日本語保存"}))
            .unwrap();
        assert!(draft.has_unsaved_changes);
        drop(bridge);
        let mut bridge = Bridge::start_in(Some(&fixture.0)).unwrap();
        let recovered = bridge.request(json!({"action":"select","id":id})).unwrap();
        assert_eq!(recovered.editor_profile.name, "GPUI 日本語保存");
        let saved = bridge
            .request(json!({"action":"save","restoreSettings":true}))
            .unwrap();
        assert!(!saved.has_unsaved_changes);
        assert_eq!(saved.document.active_profile_id, id);
        let mut settings = saved.document.settings;
        settings.display_id = Some(42);
        settings.position = "right".into();
        let updated = bridge
            .request(json!({"action":"settings","settings":settings}))
            .unwrap();
        assert_eq!(updated.document.settings.display_id, Some(42));
        assert_eq!(updated.document.settings.position, "right");
    }
    #[test]
    fn corrupt_data_is_preserved_and_cannot_be_saved() {
        let fixture = Fixture::new();
        let path = fixture.0.join("profiles.json");
        std::fs::write(&path, b"broken configuration").unwrap();
        let mut bridge = Bridge::start_in(Some(&fixture.0)).unwrap();
        let snapshot = bridge.request(json!({"action":"snapshot"})).unwrap();
        assert!(snapshot.read_only);
        let attempt = bridge.request(json!({"action":"create"})).unwrap();
        assert!(attempt.error.is_some());
        assert_eq!(std::fs::read(&path).unwrap(), b"broken configuration");
    }
    #[test]
    fn dialog_cancellation_without_a_modal_preserves_protocol_order() {
        let fixture = Fixture::new();
        let mut bridge = Bridge::start_in(Some(&fixture.0)).unwrap();
        let before = bridge.request(json!({"action":"snapshot"})).unwrap();
        Bridge::cancel_dialog(&bridge.control_handle());
        let after = bridge.request(json!({"action":"snapshot"})).unwrap();
        assert_eq!(before.editor_profile, after.editor_profile);
        assert!(!after.read_only);
    }
    #[test]
    fn invalid_links_do_not_enter_recovery_drafts() {
        let fixture = Fixture::new();
        let mut bridge = Bridge::start_in(Some(&fixture.0)).unwrap();
        let before = bridge.request(json!({"action":"snapshot"})).unwrap();
        let invalid = bridge
            .request(json!({"action":"add","kind":"link","name":"","target":"https://"}))
            .unwrap();
        assert!(invalid.error.is_some());
        assert_eq!(invalid.editor_profile.items, before.editor_profile.items);
        let valid=bridge.request(json!({"action":"add","kind":"link","name":"  Docs  ","target":"https://example.com"})).unwrap();
        assert!(valid.error.is_none());
        assert_eq!(valid.editor_profile.items.last().unwrap().name, "Docs");
    }
    #[test]
    fn future_settings_are_preserved_without_writes() {
        let fixture = Fixture::new();
        let mut bridge = Bridge::start_in(Some(&fixture.0)).unwrap();
        bridge.request(json!({"action":"snapshot"})).unwrap();
        bridge.request(json!({"action":"save"})).unwrap();
        drop(bridge);
        let path = fixture.0.join("profiles.json");
        let mut data: Value = serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
        data["settings"]["futureOption"] = json!({"value":42});
        let original = serde_json::to_vec(&data).unwrap();
        std::fs::write(&path, &original).unwrap();
        let mut bridge = Bridge::start_in(Some(&fixture.0)).unwrap();
        let snapshot = bridge.request(json!({"action":"snapshot"})).unwrap();
        assert!(snapshot.read_only);
        assert!(!snapshot.exclusive);
        let denied = bridge.request(json!({"action":"create"})).unwrap();
        assert!(denied.error.is_some());
        assert_eq!(std::fs::read(&path).unwrap(), original);
    }
    #[test]
    fn undo_removal_preserves_identity_and_order() {
        let fixture = Fixture::new();
        let mut bridge = Bridge::start_in(Some(&fixture.0)).unwrap();
        let initial = bridge.request(json!({"action":"snapshot"})).unwrap();
        let id = initial.editor_profile.items[0].id.clone();
        let removed = bridge.request(json!({"action":"remove","id":id})).unwrap();
        assert!(removed.can_undo_removal);
        let restored = bridge.request(json!({"action":"undo"})).unwrap();
        assert_eq!(restored.editor_profile.items[0].id, id);
    }
}

#[cfg(test)]
mod session_tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn two_helpers_cannot_edit_the_same_directory() {
        let path =
            std::env::temp_dir().join(format!("dockstudio-lock-test-{}", uuid::Uuid::new_v4()));
        let mut first = Bridge::start_in(Some(&path)).unwrap();
        let first_snapshot = first.request(json!({"action":"snapshot"})).unwrap();
        assert!(!first_snapshot.read_only);
        let mut second = Bridge::start_in(Some(&path)).unwrap();
        let second_snapshot = second.request(json!({"action":"snapshot"})).unwrap();
        assert!(second_snapshot.read_only);
        let denied = second.request(json!({"action":"create"})).unwrap();
        assert!(denied.error.is_some());
        let actual = first.request(json!({"action":"snapshot"})).unwrap();
        assert_eq!(
            actual.document.profiles.len(),
            first_snapshot.document.profiles.len()
        );
        drop(second);
        drop(first);
        let _ = std::fs::remove_dir_all(path);
    }
}
