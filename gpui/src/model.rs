use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Item {
    pub id: String,
    pub name: String,
    pub kind: String,
    pub target: Option<String>,
    pub bundle_identifier: Option<String>,
    pub requires_launch_confirmation: Option<bool>,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
pub struct Profile {
    pub id: String,
    pub name: String,
    pub items: Vec<Item>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Settings {
    #[serde(flatten)]
    pub extra: HashMap<String, serde_json::Value>,
    pub mode: String,
    pub position: String,
    pub icon_size: f32,
    pub auto_hide: bool,
    pub show_running_apps: bool,
    #[serde(rename = "displayID")]
    pub display_id: Option<u32>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Document {
    pub schema_version: u32,
    pub profiles: Vec<Profile>,
    #[serde(rename = "activeProfileID")]
    pub active_profile_id: String,
    pub settings: Settings,
}

#[derive(Clone, Debug, Deserialize)]
pub struct Display {
    pub id: u32,
    pub name: String,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

#[derive(Clone, Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot {
    pub document: Document,
    pub editor_profile: Profile,
    pub has_unsaved_changes: bool,
    pub has_pending_drafts: bool,
    pub can_undo_removal: bool,
    pub read_only: bool,
    #[serde(default)]
    pub exclusive: bool,
    pub error: Option<String>,
    pub status: String,
    pub background_path: Option<String>,
    pub displayed_items: Vec<Item>,
    #[serde(rename = "runningItemIDs")]
    pub running_item_ids: Vec<String>,
    pub read_only_reason: Option<String>,
    pub icons: HashMap<String, String>,
    pub displays: Vec<Display>,
    pub pending_import: Option<Vec<Profile>>,
    #[serde(default)]
    pub reduce_motion: bool,
    #[serde(default)]
    pub reduce_transparency: bool,
}

impl Snapshot {
    pub fn active_profile(&self) -> &Profile {
        self.document
            .profiles
            .iter()
            .find(|p| p.id == self.document.active_profile_id)
            .unwrap_or(&self.editor_profile)
    }
    pub fn displayed_items(&self) -> Vec<Item> {
        self.displayed_items.clone()
    }
    pub fn is_running(&self, item: &Item) -> bool {
        self.running_item_ids.contains(&item.id)
    }
}
