use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum Background {
    #[default]
    System,
    Color,
    Image,
    Transparent,
}
#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq, Hash)]
#[serde(rename_all = "camelCase")]
pub enum IconStyle {
    #[default]
    Original,
    Monochrome,
    Glass,
}
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(default, rename_all = "camelCase")]
pub struct Appearance {
    pub background: Background,
    pub color: u32,
    pub opacity: f32,
    pub blur: bool,
    pub image: Option<String>,
    pub icon_style: IconStyle,
    pub magnification: bool,
    pub magnification_scale: f32,
    pub running_indicators: bool,
    pub reduce_motion: bool,
}
impl Default for Appearance {
    fn default() -> Self {
        Self {
            background: Background::System,
            color: 0x303842,
            opacity: 0.55,
            blur: true,
            image: None,
            icon_style: IconStyle::Original,
            magnification: true,
            magnification_scale: 1.45,
            running_indicators: true,
            reduce_motion: false,
        }
    }
}
impl Appearance {
    pub fn path() -> PathBuf {
        let root = std::env::var_os("DOCKSTUDIO_DATA_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                PathBuf::from(std::env::var_os("HOME").unwrap_or_default())
                    .join("Library/Application Support/DockStudio")
            });
        root.join("appearance.json")
    }
    pub fn load() -> Result<Self, String> {
        let path = Self::path();
        if !path.exists() {
            return Ok(Self::default());
        }
        let value: Self = serde_json::from_slice(&std::fs::read(&path).map_err(|e| e.to_string())?)
            .map_err(|e| format!("Invalid appearance configuration: {e}"))?;
        value.validate()?;
        Ok(value)
    }
    pub fn validate(&self) -> Result<(), String> {
        if !self.opacity.is_finite()
            || !(0.0..=1.0).contains(&self.opacity)
            || !self.magnification_scale.is_finite()
            || !(1.0..=2.0).contains(&self.magnification_scale)
            || self.color > 0xffffff
        {
            return Err("Invalid appearance values".into());
        }
        Ok(())
    }
    pub fn save(&self) -> Result<(), String> {
        self.validate()?;
        let path = Self::path();
        let parent = path.parent().ok_or("Missing appearance directory")?;
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        let temp = parent.join(format!(".appearance-{}.tmp", uuid::Uuid::new_v4()));
        std::fs::write(
            &temp,
            serde_json::to_vec_pretty(self).map_err(|e| e.to_string())?,
        )
        .map_err(|e| e.to_string())?;
        if let Err(e) = std::fs::rename(&temp, &path) {
            let _ = std::fs::remove_file(&temp);
            return Err(e.to_string());
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn malformed_values_are_rejected() {
        let mut appearance = Appearance::default();
        appearance.opacity = f32::NAN;
        assert!(appearance.validate().is_err());
        appearance.opacity = 0.5;
        appearance.magnification_scale = 3.0;
        assert!(appearance.validate().is_err());
    }
    #[test]
    fn missing_fields_use_compatible_defaults() {
        let appearance: Appearance = serde_json::from_str("{}").unwrap();
        assert_eq!(appearance.background, Background::System);
        assert!(appearance.magnification);
    }
}
